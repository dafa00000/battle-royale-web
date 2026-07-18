--[[
	MovementController - Client movement prediction, input handling, server reconciliation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local StanceSystem = require(script.Parent.Movement.StanceSystem)
local VaultingSystem = require(script.Parent.Movement.Vaulting)
local SlideSystem = require(script.Parent.Movement.SlideSystem)

local MovementController = {}

local character: Model?
local humanoid: Humanoid?
local rootPart: BasePart?

local inputVector = Vector2.zero
local isSprinting = false
local isParachuting = false
local moveSpeed = Constants.WALK_SPEED

-- Prediction / reconciliation
local serverPosition: Vector3?
local serverVelocity: Vector3?
local lastUpdateTime = 0
local updateRate = Constants.POSITION_UPDATE_RATE
local positionHistory: { { time: number, position: Vector3, velocity: Vector3 } } = {}
local maxHistory = 60

function MovementController.Initialize(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")

	MovementController.SetupInput()
	MovementController.SetupReplication()

	RunService.Heartbeat:Connect(MovementController.Update)

	print("[MovementController] Initialized")
end

function MovementController.SetupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Constants.DEFAULT_KEYBINDS.MoveForward then
			inputVector = Vector2.new(inputVector.X, -1)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.MoveBackward then
			inputVector = Vector2.new(inputVector.X, 1)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.MoveLeft then
			inputVector = Vector2.new(-1, inputVector.Y)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.MoveRight then
			inputVector = Vector2.new(1, inputVector.Y)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Jump then
			MovementController.TryJumpOrVault()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Sprint then
			MovementController.SetSprinting(true)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Slide then
			SlideSystem.StartSlide()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Constants.DEFAULT_KEYBINDS.MoveForward or input.KeyCode == Constants.DEFAULT_KEYBINDS.MoveBackward then
			inputVector = Vector2.new(inputVector.X, 0)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.MoveLeft or input.KeyCode == Constants.DEFAULT_KEYBINDS.MoveRight then
			inputVector = Vector2.new(0, inputVector.Y)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Sprint then
			MovementController.SetSprinting(false)
		end
	end)
end

function MovementController.SetupReplication()
	ReplicatedStorage.Remotes.MatchRemotes.MovementUpdate.OnClientEvent:Connect(function(player, data)
		if player == game.Players.LocalPlayer then
			MovementController.OnServerReconcile(data)
		else
			MovementController.OnRemoteMovementUpdate(player, data)
		end
	end)
end

function MovementController.Update(deltaTime: number)
	if not character or not humanoid or not rootPart then return end
	if humanoid.Health <= 0 then return end

	-- Update stance system
	StanceSystem.Update(deltaTime)

	-- Skip if sliding or vaulting (those systems control movement)
	if SlideSystem.IsSliding() or VaultingSystem.IsVaulting() then
		MovementController.RecordHistory()
		return
	end

	-- Calculate move direction relative to camera
	local camera = Workspace.CurrentCamera
	local lookVector = camera.CFrame.LookVector
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
	local rightVector = camera.CFrame.RightVector
	local flatRight = Vector3.new(rightVector.X, 0, rightVector.Z).Unit

	local moveDir = (flatLook * -inputVector.Y + flatRight * inputVector.X)
	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
	end

	-- Apply stance speed
	local stance = character:GetAttribute("Stance") or "Stand"
	local stanceData = StanceSystem.GetStanceData(stance)
	local targetSpeed = stanceData.walkSpeed

	if isSprinting and stance == "Stand" and inputVector.Y <= 0 then
		targetSpeed = stanceData.sprintSpeed
		character:SetAttribute("IsSprinting", true)
	else
		character:SetAttribute("IsSprinting", false)
	end

	-- Apply movement
	humanoid.WalkSpeed = targetSpeed
	humanoid:Move(moveDir, false)

	-- Auto-vault check when sprinting toward obstacle
	if isSprinting and moveDir.Magnitude > 0.1 then
		local vaultData = VaultingSystem.CheckVault()
		if vaultData then
			VaultingSystem.StartVault(vaultData)
		end
	end

	MovementController.RecordHistory()
	MovementController.SendUpdate()
end

function MovementController.RecordHistory()
	if not rootPart then return end

	table.insert(positionHistory, 1, {
		time = os.clock(),
		position = rootPart.Position,
		velocity = rootPart.AssemblyLinearVelocity,
	})

	if #positionHistory > maxHistory then
		table.remove(positionHistory)
	end
end

function MovementController.SendUpdate()
	if not rootPart or not character then return end

	local now = os.clock()
	if now - lastUpdateTime < updateRate then return end
	lastUpdateTime = now

	local payload = {
		Position = rootPart.Position,
		Velocity = rootPart.AssemblyLinearVelocity,
		Stance = character:GetAttribute("Stance") or "Stand",
		IsMoving = inputVector.Magnitude > 0,
		IsSprinting = isSprinting,
		IsSliding = SlideSystem.IsSliding(),
		Lean = character:GetAttribute("Lean") or 0,
		Timestamp = now,
	}

	ReplicatedStorage.Remotes.MatchRemotes.MovementUpdate:FireServer(payload)
end

function MovementController.OnServerReconcile(data)
	if not rootPart then return end

	serverPosition = data.Position
	serverVelocity = data.Velocity

	-- Find closest historical state
	local closestTime = math.huge
	local closestState = nil
	for _, state in ipairs(positionHistory) do
		local diff = math.abs(state.time - data.Timestamp)
		if diff < closestTime then
			closestTime = diff
			closestState = state
		end
	end

	if not closestState then return end

	-- Check error magnitude
	local errorDist = (serverPosition - closestState.position).Magnitude
	if errorDist > 5 then
		-- Hard snap if too far off
		rootPart.CFrame = CFrame.new(serverPosition)
		rootPart.AssemblyLinearVelocity = serverVelocity
	elseif errorDist > 0.5 then
		-- Soft correct
		local correction = (serverPosition - rootPart.Position) * 0.5
		rootPart.CFrame = rootPart.CFrame + correction
	end
end

function MovementController.OnRemoteMovementUpdate(player: Player, data)
	-- Interpolate remote players (handled by character replication or custom rigs)
	-- This is a hook for custom remote player smoothing
end

function MovementController.TryJumpOrVault()
	if not humanoid then return end

	-- Try vault first
	local vaultData = VaultingSystem.CheckVault()
	if vaultData then
		VaultingSystem.StartVault(vaultData)
		return
	end

	-- Standard jump
	if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
		humanoid.Jump = true
	end
end

function MovementController.SetSprinting(sprinting: boolean)
	isSprinting = sprinting
	if character then
		character:SetAttribute("IsSprinting", sprinting)
	end
end

function MovementController.SetParachuting(parachuting: boolean)
	isParachuting = parachuting
	if humanoid then
		if parachuting then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
			-- Deploy parachute visual / physics here
		else
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		end
	end
end

function MovementController.DeployParachute()
	MovementController.SetParachuting(true)
	-- Trigger parachute animation / slow fall
	if rootPart then
		rootPart.AssemblyLinearVelocity = Vector3.new(0, -20, 0)
	end
end

function MovementController.Cleanup()
	-- Disconnect events if needed
end

return MovementController
