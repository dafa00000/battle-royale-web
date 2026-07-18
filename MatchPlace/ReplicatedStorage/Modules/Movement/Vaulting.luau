--[[
	Vaulting - Detect vaultable obstacles, raycast over + landing, animation trigger, cooldown
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local Vaulting = {}

export type VaultData = {
	height: number,
	depth: number,
	wallNormal: Vector3,
	wallPosition: Vector3,
	landingPosition: Vector3,
	duration: number,
	startTime: number,
	isVaulting: boolean,
	vaultType: string, -- "Low" | "High" | "Ledge"
}

export type VaultConfig = {
	maxHeight: number,
	minHeight: number,
	maxDepth: number,
	minDepth: number,
	checkDistance: number,
	raycastOffset: number,
	landingOffset: number,
	cooldown: number,
	lowVaultHeight: number,
	highVaultHeight: number,
}

-- Configuration
local CONFIG: VaultConfig = {
	maxHeight = Constants.VAULT_HEIGHT,
	minHeight = 1.0,
	maxDepth = 2.5,
	minDepth = 0.3,
	checkDistance = 4.5,
	raycastOffset = 0.5,
	landingOffset = 1.2,
	cooldown = 0.8,
	lowVaultHeight = 2.0,
	highVaultHeight = 3.5,
}

-- State
local vaultState: VaultData = {
	height = 0,
	depth = 0,
	wallNormal = Vector3.zero,
	wallPosition = Vector3.zero,
	landingPosition = Vector3.zero,
	duration = 0,
	startTime = 0,
	isVaulting = false,
	vaultType = "Low",
}

local lastVaultTime = 0
local character: Model?
local humanoid: Humanoid?
local rootPart: BasePart?
local animator: Animator?

-- Animation IDs
local vaultAnimations = {
	Low = "rbxassetid://0",
	High = "rbxassetid://0",
	Ledge = "rbxassetid://0",
}

function Vaulting.Initialize(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid") :: Humanoid
	rootPart = char:WaitForChild("HumanoidRootPart") :: BasePart
	animator = humanoid:WaitForChild("Animator") :: Animator

	RunService.Heartbeat:Connect(Vaulting.Update)
	print("[Vaulting] Initialized")
end

function Vaulting.CanVault(): boolean
	if not humanoid or not rootPart then return false end
	if humanoid.Health <= 0 then return false end
	if vaultState.isVaulting then return false end
	if os.clock() - lastVaultTime < CONFIG.cooldown then return false end

	-- Must be moving forward
	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude < 0.1 then return false end

	-- Must not be in air
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		return false
	end

	-- Must be in valid stance
	local stance = character and character:GetAttribute("Stance") or "Stand"
	if stance == "Prone" then return false end

	return true
end

function Vaulting.CheckVault(): VaultData?
	if not Vaulting.CanVault() then return nil end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	local moveDir = humanoid.MoveDirection.Unit
	local origin = rootPart.Position + Vector3.new(0, 1, 0)

	-- 1. Detect wall in front
	local wallHit = Workspace:Raycast(origin, moveDir * CONFIG.checkDistance, raycastParams)
	if not wallHit then return nil end

	-- Ignore low obstacles (step height)
	local wallHeight = wallHit.Position.Y - rootPart.Position.Y
	if wallHeight < 0.5 then return nil end

	-- 2. Find top of wall
	local topOrigin = wallHit.Position + Vector3.new(0, CONFIG.maxHeight + 2, 0)
	local topHit = Workspace:Raycast(topOrigin, Vector3.new(0, -CONFIG.maxHeight - 3, 0), raycastParams)
	if not topHit then return nil end

	local vaultHeight = topHit.Position.Y - rootPart.Position.Y
	if vaultHeight < CONFIG.minHeight or vaultHeight > CONFIG.maxHeight then
		return nil
	end

	-- 3. Check depth (space on other side)
	local overWallOrigin = topHit.Position + moveDir * 0.5 + Vector3.new(0, 0.5, 0)
	local depthHit = Workspace:Raycast(overWallOrigin, moveDir * CONFIG.maxDepth, raycastParams)

	local vaultDepth = CONFIG.maxDepth
	if depthHit then
		vaultDepth = (overWallOrigin - depthHit.Position).Magnitude
		if vaultDepth < CONFIG.minDepth then return nil end
	end

	-- 4. Find landing position
	local landingSearchOrigin = topHit.Position + moveDir * (vaultDepth + CONFIG.landingOffset)
	local landingHit = Workspace:Raycast(
		landingSearchOrigin + Vector3.new(0, 5, 0),
		Vector3.new(0, -10, 0),
		raycastParams
	)
	if not landingHit then return nil end

	-- Landing must be flat enough
	if landingHit.Normal.Y < 0.85 then return nil end

	-- Check for obstacles at landing
	local landingClear = Workspace:Raycast(
		landingHit.Position + Vector3.new(0, 0.1, 0),
		Vector3.new(0, 2.5, 0),
		raycastParams
	)
	if landingClear then return nil end

	-- Determine vault type
	local vaultType = "Low"
	if vaultHeight > CONFIG.highVaultHeight then
		vaultType = "High"
	elseif vaultHeight > CONFIG.lowVaultHeight then
		vaultType = "Ledge"
	end

	return {
		height = vaultHeight,
		depth = vaultDepth,
		wallNormal = wallHit.Normal,
		wallPosition = wallHit.Position,
		landingPosition = landingHit.Position,
		duration = Constants.VAULT_DURATION * (vaultType == "High" and 1.3 or vaultType == "Ledge" and 1.1 or 1.0),
		startTime = 0,
		isVaulting = false,
		vaultType = vaultType,
	}
end

function Vaulting.StartVault(vaultData: VaultData): boolean
	if vaultState.isVaulting then return false end

	vaultState = vaultData
	vaultState.startTime = os.clock()
	vaultState.isVaulting = true
	lastVaultTime = os.clock()

	-- Disable movement
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	end

	-- Play animation
	Vaulting.PlayVaultAnimation(vaultData.vaultType)

	-- Set attribute
	if character then
		character:SetAttribute("IsVaulting", true)
	end

	return true
end

function Vaulting.PlayVaultAnimation(vaultType: string)
	if not animator then return end

	local animId = vaultAnimations[vaultType]
	if not animId or animId == "" then return end

	local animation = Instance.new("Animation")
	animation.AnimationId = animId
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.05)

	-- Adjust speed to match vault duration
	track:AdjustSpeed(1 / vaultState.duration)

	-- Animation events
	track:GetMarkerReachedSignal("Apex"):Connect(function()
		Vaulting.OnVaultApex()
	end)

	track:GetMarkerReachedSignal("Land"):Connect(function()
		Vaulting.OnVaultLand()
	end)

	-- Cleanup
	track.Ended:Connect(function()
		track:Destroy()
	end)
end

function Vaulting.OnVaultApex()
	-- Mid-vault: move toward landing with arc
	if not rootPart then return end

	local alpha = 0.5
	local targetPos = vaultState.wallPosition:Lerp(vaultState.landingPosition, alpha)
	targetPos += Vector3.new(0, vaultState.height * 0.6, 0)

	rootPart.CFrame = CFrame.new(targetPos, vaultState.landingPosition)
end

function Vaulting.OnVaultLand()
	if not rootPart or not humanoid then return end

	-- Final position
	local finalPos = vaultState.landingPosition + Vector3.new(0, 2, 0)
	local lookDir = vaultState.landingPosition - vaultState.wallPosition
	rootPart.CFrame = CFrame.new(finalPos, finalPos + lookDir.Unit)

	-- Restore movement
	humanoid.WalkSpeed = Constants.WALK_SPEED
	humanoid.JumpPower = Constants.JUMP_POWER
	humanoid.AutoRotate = true

	vaultState.isVaulting = false

	if character then
		character:SetAttribute("IsVaulting", false)
	end
end

function Vaulting.Update(deltaTime: number)
	if not vaultState.isVaulting then return end
	if not rootPart then return end

	local elapsed = os.clock() - vaultState.startTime
	local alpha = math.clamp(elapsed / vaultState.duration, 0, 1)

	-- Smooth easing
	alpha = Util.Lerp(0, 1, alpha)

	-- Interpolate position with arc
	local currentPos = vaultState.wallPosition:Lerp(vaultState.landingPosition, alpha)
	local arcHeight = math.sin(alpha * math.pi) * vaultState.height * 0.4
	currentPos += Vector3.new(0, arcHeight, 0)

	-- Face landing direction
	local lookDir = (vaultState.landingPosition - vaultState.wallPosition).Unit
	rootPart.CFrame = CFrame.new(currentPos, currentPos + lookDir)

	if alpha >= 1 then
		Vaulting.OnVaultLand()
	end
end

function Vaulting.CancelVault()
	if not vaultState.isVaulting then return end

	vaultState.isVaulting = false

	if humanoid then
		humanoid.WalkSpeed = Constants.WALK_SPEED
		humanoid.JumpPower = Constants.JUMP_POWER
		humanoid.AutoRotate = true
	end

	if character then
		character:SetAttribute("IsVaulting", false)
	end
end

function Vaulting.IsVaulting(): boolean
	return vaultState.isVaulting
end

function Vaulting.GetVaultProgress(): number
	if not vaultState.isVaulting then return 0 end
	return math.clamp((os.clock() - vaultState.startTime) / vaultState.duration, 0, 1)
end

function Vaulting.GetCooldownRemaining(): number
	return math.max(0, CONFIG.cooldown - (os.clock() - lastVaultTime))
end

function Vaulting.GetVaultType(): string?
	if vaultState.isVaulting then
		return vaultState.vaultType
	end
	return nil
end

function Vaulting.Cleanup()
	Vaulting.CancelVault()
	character = nil
	humanoid = nil
	rootPart = nil
	animator = nil
end

return Vaulting
