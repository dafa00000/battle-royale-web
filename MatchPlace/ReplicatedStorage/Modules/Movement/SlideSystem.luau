--[[
	SlideSystem - Sprint + slide key -> slide state, friction decel, duration/cooldown, camera tilt, cancel on jump/hit
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local SlideSystem = {}

export type SlideState = {
	isSliding: boolean,
	startTime: number,
	duration: number,
	startVelocity: Vector3,
	direction: Vector3,
	friction: number,
	cooldownEnd: number,
	currentSpeed: number,
}

export type SlideConfig = {
	slideSpeed: number,
	duration: number,
	cooldown: number,
	friction: number,
	minSpeed: number,
	cameraTilt: number,
	fovBoost: number,
}

-- Configuration
local CONFIG: SlideConfig = {
	slideSpeed = Constants.SLIDE_SPEED,
	duration = Constants.SLIDE_DURATION,
	cooldown = Constants.SLIDE_COOLDOWN,
	friction = Constants.SLIDE_SPEED / Constants.SLIDE_DURATION,
	minSpeed = 3,
	cameraTilt = 0.35,
	fovBoost = 10,
}

-- State
local slideState: SlideState = {
	isSliding = false,
	startTime = 0,
	duration = 0,
	startVelocity = Vector3.zero,
	direction = Vector3.zero,
	friction = 0,
	cooldownEnd = 0,
	currentSpeed = 0,
}

local character: Model?
local humanoid: Humanoid?
local rootPart: BasePart?
local animator: Animator?

-- Animation
local slideAnimationId = "rbxassetid://0"
local activeAnimationTrack: AnimationTrack?

function SlideSystem.Initialize(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid") :: Humanoid
	rootPart = char:WaitForChild("HumanoidRootPart") :: BasePart
	animator = humanoid:WaitForChild("Animator") :: Animator

	RunService.Heartbeat:Connect(SlideSystem.Update)
	print("[SlideSystem] Initialized")
end

function SlideSystem.CanSlide(): boolean
	if not humanoid or not rootPart then return false end
	if humanoid.Health <= 0 then return false end
	if slideState.isSliding then return false end
	if os.clock() < slideState.cooldownEnd then return false end

	-- Must be sprinting
	local isSprinting = character and character:GetAttribute("IsSprinting")
	if not isSprinting then return false end

	-- Must be moving
	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude < 0.1 then return false end

	-- Must be on ground
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		return false
	end

	-- Must not be in prone
	local stance = character and character:GetAttribute("Stance") or "Stand"
	if stance == "Prone" then return false end

	return true
end

function SlideSystem.StartSlide(): boolean
	if not SlideSystem.CanSlide() then return false end

	slideState.isSliding = true
	slideState.startTime = os.clock()
	slideState.duration = CONFIG.duration
	slideState.direction = humanoid.MoveDirection.Unit
	slideState.startVelocity = slideState.direction * CONFIG.slideSpeed
	slideState.friction = CONFIG.friction
	slideState.cooldownEnd = os.clock() + CONFIG.cooldown
	slideState.currentSpeed = CONFIG.slideSpeed

	-- Apply initial velocity
	if rootPart then
		rootPart.AssemblyLinearVelocity = Vector3.new(
			slideState.startVelocity.X,
			rootPart.AssemblyLinearVelocity.Y,
			slideState.startVelocity.Z
		)
	end

	-- Force crouch stance during slide
	if character then
		character:SetAttribute("IsSliding", true)
		character:SetAttribute("Stance", "Crouch")
	end

	if humanoid then
		humanoid.HipHeight = 1.0
		humanoid.WalkSpeed = 0
	end

	-- Play animation
	SlideSystem.PlaySlideAnimation()

	return true
end

function SlideSystem.PlaySlideAnimation()
	if not animator then return end

	if slideAnimationId == "" then return end

	local animation = Instance.new("Animation")
	animation.AnimationId = slideAnimationId
	activeAnimationTrack = animator:LoadAnimation(animation)
	activeAnimationTrack.Priority = Enum.AnimationPriority.Action
	activeAnimationTrack:Play(0.05)
	activeAnimationTrack:AdjustSpeed(1 / CONFIG.duration)
end

function SlideSystem.Update(deltaTime: number)
	if not slideState.isSliding then return end
	if not rootPart or not humanoid then return end

	local elapsed = os.clock() - slideState.startTime
	local alpha = math.clamp(elapsed / slideState.duration, 0, 1)

	-- Calculate current speed with friction
	slideState.currentSpeed = CONFIG.slideSpeed * (1 - alpha)

	-- Apply velocity
	local currentVelocity = slideState.direction * slideState.currentSpeed
	rootPart.AssemblyLinearVelocity = Vector3.new(
		currentVelocity.X,
		rootPart.AssemblyLinearVelocity.Y,
		currentVelocity.Z
	)

	-- Rotate character to slide direction
	local targetCFrame = CFrame.new(rootPart.Position, rootPart.Position + slideState.direction)
	rootPart.CFrame = rootPart.CFrame:Lerp(targetCFrame, 0.12)

	-- End conditions
	if alpha >= 1 or slideState.currentSpeed < CONFIG.minSpeed then
		SlideSystem.EndSlide()
		return
	end

	-- Collision check (front)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local frontHit = Workspace:Raycast(
		rootPart.Position,
		slideState.direction * 2,
		raycastParams
	)
	if frontHit then
		SlideSystem.EndSlide()
		return
	end

	-- Ground check
	local groundHit = Workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -3.5, 0),
		raycastParams
	)
	if not groundHit then
		SlideSystem.EndSlide()
		return
	end
end

function SlideSystem.EndSlide()
	if not slideState.isSliding then return end

	slideState.isSliding = false

	-- Stop animation
	if activeAnimationTrack then
		activeAnimationTrack:Stop(0.1)
		activeAnimationTrack = nil
	end

	-- Restore movement
	if humanoid then
		humanoid.WalkSpeed = Constants.WALK_SPEED
		humanoid.HipHeight = 2.0
	end

	-- Restore stance
	if character then
		character:SetAttribute("IsSliding", false)
		local stance = character:GetAttribute("Stance") or "Stand"
		if stance == "Crouch" then
			humanoid.HipHeight = 1.2
			humanoid.WalkSpeed = Constants.CROUCH_SPEED
		end
	end
end

function SlideSystem.CancelSlide()
	SlideSystem.EndSlide()
end

function SlideSystem.IsSliding(): boolean
	return slideState.isSliding
end

function SlideSystem.GetSlideProgress(): number
	if not slideState.isSliding then return 0 end
	return math.clamp((os.clock() - slideState.startTime) / slideState.duration, 0, 1)
end

function SlideSystem.GetCooldownRemaining(): number
	return math.max(0, slideState.cooldownEnd - os.clock())
end

function SlideSystem.GetCurrentSpeed(): number
	return slideState.currentSpeed
end

function SlideSystem.GetCameraTilt(): number
	if slideState.isSliding then
		return CONFIG.cameraTilt * (1 - SlideSystem.GetSlideProgress())
	end
	return 0
end

function SlideSystem.GetFOVBoost(): number
	if slideState.isSliding then
		return CONFIG.fovBoost * (1 - SlideSystem.GetSlideProgress() * 0.5)
	end
	return 0
end

function SlideSystem.GetDirection(): Vector3
	return slideState.direction
end

function SlideSystem.Cleanup()
	SlideSystem.EndSlide()
	character = nil
	humanoid = nil
	rootPart = nil
	animator = nil
end

return SlideSystem
