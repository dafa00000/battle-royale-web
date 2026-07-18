--[[
	StanceSystem - Stand/Crouch/Prone state machine with smooth transitions
	HipHeight, WalkSpeed, camera offset, headroom check, hitbox scale
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local StanceSystem = {}

export type Stance = "Stand" | "Crouch" | "Prone"

export type StanceData = {
	hipHeight: number,
	walkSpeed: number,
	runSpeed: number,
	sprintSpeed: number,
	cameraHeight: number,
	cameraOffset: Vector3,
	headOffset: Vector3,
	collisionHeight: number,
	collisionRadius: number,
	hitboxScale: Vector3,
	transitionTime: number,
}

-- Stance configuration
local STANCE_DATA: { [Stance]: StanceData } = {
	Stand = {
		hipHeight = 2.0,
		walkSpeed = Constants.WALK_SPEED,
		runSpeed = Constants.RUN_SPEED,
		sprintSpeed = Constants.SPRINT_SPEED,
		cameraHeight = 1.6,
		cameraOffset = Vector3.new(0, 0.1, 0),
		headOffset = Vector3.new(0, 1.5, 0),
		collisionHeight = 5.5,
		collisionRadius = 2,
		hitboxScale = Vector3.new(1, 1, 1),
		transitionTime = Constants.STANCE_TRANSITION_TIME,
	},
	Crouch = {
		hipHeight = 1.2,
		walkSpeed = Constants.CROUCH_SPEED,
		runSpeed = Constants.CROUCH_SPEED * 1.3,
		sprintSpeed = Constants.CROUCH_SPEED * 1.3,
		cameraHeight = 1.0,
		cameraOffset = Vector3.new(0, -0.3, 0),
		headOffset = Vector3.new(0, 0.9, 0),
		collisionHeight = 3.2,
		collisionRadius = 2,
		hitboxScale = Vector3.new(1, 0.65, 1),
		transitionTime = Constants.STANCE_TRANSITION_TIME * 0.8,
	},
	Prone = {
		hipHeight = 0.4,
		walkSpeed = Constants.PRONE_SPEED,
		runSpeed = Constants.PRONE_SPEED,
		sprintSpeed = Constants.PRONE_SPEED,
		cameraHeight = 0.35,
		cameraOffset = Vector3.new(0, -0.8, 0.2),
		headOffset = Vector3.new(0, 0.25, 0),
		collisionHeight = 1.0,
		collisionRadius = 2.5,
		hitboxScale = Vector3.new(1, 0.25, 1.8),
		transitionTime = Constants.STANCE_TRANSITION_TIME * 1.2,
	},
}

-- Current state
local currentStance: Stance = "Stand"
local targetStance: Stance = "Stand"
local previousStance: Stance = "Stand"
local isTransitioning = false
local transitionStartTime = 0
local transitionDuration = Constants.STANCE_TRANSITION_TIME

-- References
local character: Model?
local humanoid: Humanoid?
local rootPart: BasePart?
local animator: Animator?

-- Animation IDs (placeholder)
local stanceAnimations = {
	Stand = "rbxassetid://0",
	Crouch = "rbxassetid://0",
	Prone = "rbxassetid://0",
}

local activeAnimationTrack: AnimationTrack?

function StanceSystem.Initialize(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid") :: Humanoid
	rootPart = char:WaitForChild("HumanoidRootPart") :: BasePart
	animator = humanoid:WaitForChild("Animator") :: Animator

	-- Set initial stance
	StanceSystem.SetStance("Stand", true)

	-- Connect update loop
	RunService.Heartbeat:Connect(StanceSystem.Update)

	print("[StanceSystem] Initialized")
end

function StanceSystem.SetStance(newStance: Stance, instant: boolean?)
	if not STANCE_DATA[newStance] then return end
	if newStance == currentStance and not isTransitioning then return end

	-- Prone requires headroom check
	if newStance == "Prone" then
		if not StanceSystem.CanEnterProne() then
			return
		end
	end

	-- Prone to stand requires headroom check
	if currentStance == "Prone" and newStance == "Stand" then
		if not StanceSystem.CanStandUp() then
			return
		end
	end

	previousStance = currentStance
	targetStance = newStance

	if instant then
		StanceSystem.ApplyStance(newStance)
		currentStance = newStance
		isTransitioning = false
	else
		isTransitioning = true
		transitionStartTime = os.clock()
		transitionDuration = STANCE_DATA[newStance].transitionTime
	end
end

function StanceSystem.CanEnterProne(): boolean
	if not rootPart or not humanoid then return false end
	if humanoid.Health <= 0 then return false end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	-- Check headroom (need at least 1.5 studs above)
	local headRoom = Workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, 1.5, 0),
		raycastParams
	)
	if headRoom then return false end

	-- Check ground below (must be on ground)
	local ground = Workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -3, 0),
		raycastParams
	)
	if not ground then return false end

	-- Check for obstacles in prone position (front and back)
	local proneData = STANCE_DATA.Prone
	local frontCheck = Workspace:Raycast(
		rootPart.Position + Vector3.new(0, 0.5, 0),
		rootPart.CFrame.LookVector * 2,
		raycastParams
	)
	local backCheck = Workspace:Raycast(
		rootPart.Position + Vector3.new(0, 0.5, 0),
		-rootPart.CFrame.LookVector * 2,
		raycastParams
	)

	if frontCheck and frontCheck.Instance.CanCollide then return false end
	if backCheck and backCheck.Instance.CanCollide then return false end

	return true
end

function StanceSystem.CanStandUp(): boolean
	if not rootPart then return false end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	-- Check headroom for standing
	local headRoom = Workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, STANCE_DATA.Stand.collisionHeight, 0),
		raycastParams
	)

	return headRoom == nil
end

function StanceSystem.Update(deltaTime: number)
	if not isTransitioning then return end

	local elapsed = os.clock() - transitionStartTime
	local alpha = math.clamp(elapsed / transitionDuration, 0, 1)

	-- Smooth easing (ease-out)
	alpha = 1 - (1 - alpha) ^ 2

	if alpha >= 1 then
		StanceSystem.ApplyStance(targetStance)
		currentStance = targetStance
		isTransitioning = false
	else
		StanceSystem.InterpolateStance(previousStance, targetStance, alpha)
	end
end

function StanceSystem.ApplyStance(stance: Stance)
	if not humanoid or not rootPart then return end

	local data = STANCE_DATA[stance]

	-- Apply humanoid properties
	humanoid.HipHeight = data.hipHeight
	humanoid.WalkSpeed = data.walkSpeed

	-- Update collision
	StanceSystem.UpdateCollision(stance)

	-- Play animation
	StanceSystem.PlayStanceAnimation(stance)

	-- Set attributes for other systems
	if character then
		character:SetAttribute("Stance", stance)
		character:SetAttribute("StanceTransitioning", false)
	end
end

function StanceSystem.InterpolateStance(from: Stance, to: Stance, alpha: number)
	if not humanoid or not rootPart then return end

	local fromData = STANCE_DATA[from]
	local toData = STANCE_DATA[to]

	-- Interpolate hip height
	humanoid.HipHeight = Util.Lerp(fromData.hipHeight, toData.hipHeight, alpha)

	-- Interpolate walk speed (use target speed immediately for responsiveness)
	humanoid.WalkSpeed = toData.walkSpeed

	-- Interpolate collision
	StanceSystem.InterpolateCollision(from, to, alpha)

	-- Mark as transitioning
	if character then
		character:SetAttribute("StanceTransitioning", true)
	end
end

function StanceSystem.UpdateCollision(stance: Stance)
	if not rootPart then return end

	local data = STANCE_DATA[stance]

	-- Update root part collision
	-- Note: HumanoidRootPart size is typically fixed; use a separate hitbox part
	local hitbox = character and character:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then
		hitbox.Size = Vector3.new(
			data.collisionRadius * 2 * data.hitboxScale.X,
			data.collisionHeight * data.hitboxScale.Y,
			data.collisionRadius * 2 * data.hitboxScale.Z
		)
	end
end

function StanceSystem.InterpolateCollision(from: Stance, to: Stance, alpha: number)
	if not rootPart then return end

	local fromData = STANCE_DATA[from]
	local toData = STANCE_DATA[to]

	local hitbox = character and character:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then
		local height = Util.Lerp(fromData.collisionHeight, toData.collisionHeight, alpha)
		local scaleY = Util.Lerp(fromData.hitboxScale.Y, toData.hitboxScale.Y, alpha)
		hitbox.Size = Vector3.new(
			toData.collisionRadius * 2 * toData.hitboxScale.X,
			height * scaleY,
			toData.collisionRadius * 2 * toData.hitboxScale.Z
		)
	end
end

function StanceSystem.PlayStanceAnimation(stance: Stance)
	if not animator then return end

	if activeAnimationTrack then
		activeAnimationTrack:Stop(0.15)
	end

	local animId = stanceAnimations[stance]
	if animId and animId ~= "" then
		local animation = Instance.new("Animation")
		animation.AnimationId = animId
		activeAnimationTrack = animator:LoadAnimation(animation)
		activeAnimationTrack.Priority = Enum.AnimationPriority.Idle
		activeAnimationTrack:Play(0.2)
	end
end

function StanceSystem.GetCurrentStance(): Stance
	return currentStance
end

function StanceSystem.GetTargetStance(): Stance
	return targetStance
end

function StanceSystem.IsTransitioning(): boolean
	return isTransitioning
end

function StanceSystem.GetStanceData(stance: Stance?): StanceData
	return STANCE_DATA[stance or currentStance]
end

function StanceSystem.GetCameraHeight(): number
	return STANCE_DATA[currentStance].cameraHeight
end

function StanceSystem.GetCameraOffset(): Vector3
	return STANCE_DATA[currentStance].cameraOffset
end

function StanceSystem.GetHeadOffset(): Vector3
	return STANCE_DATA[currentStance].headOffset
end

function StanceSystem.GetHitboxScale(): Vector3
	return STANCE_DATA[currentStance].hitboxScale
end

function StanceSystem.CanSprint(): boolean
	return currentStance == "Stand"
end

function StanceSystem.CanADS(): boolean
	return currentStance ~= "Prone"
end

function StanceSystem.CanVault(): boolean
	return currentStance == "Stand" or currentStance == "Crouch"
end

function StanceSystem.GetSpeedMultiplier(): number
	local data = STANCE_DATA[currentStance]
	return data.walkSpeed / Constants.WALK_SPEED
end

function StanceSystem.Cleanup()
	if activeAnimationTrack then
		activeAnimationTrack:Stop()
		activeAnimationTrack = nil
	end
	character = nil
	humanoid = nil
	rootPart = nil
	animator = nil
end

return StanceSystem
