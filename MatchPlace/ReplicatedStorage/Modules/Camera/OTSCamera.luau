--[[
	OTSCamera - Over-The-Shoulder Camera with ADS, lean, and procedural effects
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local StanceSystem = require(script.Parent.Movement.StanceSystem)

local OTSCamera = {}

export type CameraState = {
	offset: Vector3,
	rotation: Vector2,
	distance: number,
	fov: number,
	shakeIntensity: number,
	shakeOffset: Vector3,
	leanOffset: Vector3,
	stanceOffset: Vector3,
	isADS: boolean,
	isSprinting: boolean,
	isSliding: boolean,
}

local cameraState: CameraState = {
	offset = Vector3.new(1.5, 1.6, 3), -- Right, Up, Back
	rotation = Vector2.new(0, 0),
	distance = 3,
	fov = 80,
	shakeIntensity = 0,
	shakeOffset = Vector3.zero,
	leanOffset = Vector3.zero,
	stanceOffset = Vector3.zero,
	isADS = false,
	isSprinting = false,
	isSliding = false,
}

local targetFOV = 80
local currentFOV = 80
local cameraShakeTrauma = 0
local cameraShakeDecay = 3
local leanAngle = 0
local targetLean = 0
local leanSpeed = 8

local camera = Workspace.CurrentCamera
local character: Model?
local humanoid: Humanoid?
local rootPart: BasePart?
local head: BasePart?
local lastHeadCFrame: CFrame?

function OTSCamera.Initialize(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")
	head = char:WaitForChild("Head")
	
	-- Set camera type
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil
	
	-- Initialize rotation from character
	local _, y, _ = rootPart.CFrame:ToEulerAnglesYXZ()
	cameraState.rotation = Vector2.new(0, y)
	
	-- Input connections
	UserInputService.InputChanged:Connect(OTSCamera.OnInputChanged)
	
	RunService.RenderStepped:Connect(OTSCamera.Update)
	
	print("[OTSCamera] Initialized")
end

function OTSCamera.OnInputChanged(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
	
	local sensitivity = UserInputService.MouseDeltaSensitivity * 0.5
	cameraState.rotation = cameraState.rotation - Vector2.new(input.Delta.Y, input.Delta.X) * sensitivity * 0.002
	
	-- Clamp pitch
	cameraState.rotation = Vector2.new(
		math.clamp(cameraState.rotation.X, -math.rad(85), math.rad(85)),
		cameraState.rotation.Y
	)
end

function OTSCamera.Update(deltaTime: number)
	if not character or not rootPart or not head then return end
	
	-- Update stance offset
	OTSCamera.UpdateStanceOffset(deltaTime)
	
	-- Update lean
	OTSCamera.UpdateLean(deltaTime)
	
	-- Update ADS
	OTSCamera.UpdateADS(deltaTime)
	
	-- Update sprint/slide
	OTSCamera.UpdateMovementState(deltaTime)
	
	-- Update FOV
	OTSCamera.UpdateFOV(deltaTime)
	
	-- Update camera shake
	OTSCamera.UpdateShake(deltaTime)
	
	-- Calculate final camera CFrame
	local cameraCFrame = OTSCamera.CalculateCameraCFrame()
	
	-- Apply shake
	cameraCFrame = cameraCFrame * CFrame.new(cameraState.shakeOffset)
	
	-- Set camera
	camera.CFrame = cameraCFrame
	camera.FieldOfView = currentFOV
end

function OTSCamera.UpdateStanceOffset(deltaTime: number)
	if not rootPart then return end
	
	local stance = character:GetAttribute("Stance") or "Stand"
	local stanceData = StanceSystem.GetStanceData(stance)
	if not stanceData then return end
	
	local targetOffset = stanceData.cameraHeight and Vector3.new(0, stanceData.cameraHeight - 1.6, 0) or Vector3.zero
	
	cameraState.stanceOffset = cameraState.stanceOffset:Lerp(targetOffset, deltaTime * 10)
end

function OTSCamera.UpdateLean(deltaTime: number)
	-- Smooth lean toward target set by CameraController
	leanAngle = Util.Lerp(leanAngle, targetLean, deltaTime * leanSpeed)

	-- Apply lean offset (horizontal + slight rotation)
	local leanOffsetX = leanAngle * 0.8
	local leanOffsetZ = math.abs(leanAngle) * 0.3

	cameraState.leanOffset = Vector3.new(leanOffsetX, 0, leanOffsetZ)
end

function OTSCamera.UpdateADS(deltaTime: number)
	local isADSInput = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	local equippedWeapon = character:GetAttribute("EquippedWeapon")
	
	if isADSInput and equippedWeapon and not cameraState.isSprinting and not cameraState.isSliding then
		cameraState.isADS = true
	else
		cameraState.isADS = false
	end
	
	-- ADS transitions handled in CalculateCameraCFrame
end

function OTSCamera.UpdateMovementState(deltaTime: number)
	if not humanoid then return end
	
	cameraState.isSprinting = character:GetAttribute("IsSprinting") or false
	cameraState.isSliding = character:GetAttribute("IsSliding") or false
	
	-- Sprint camera effects
	if cameraState.isSprinting then
		targetFOV = 90
	else
		targetFOV = cameraState.isADS and 45 or 80
	end
end

function OTSCamera.UpdateFOV(deltaTime: number)
	currentFOV = Util.Lerp(currentFOV, targetFOV, deltaTime * 10)
end

function OTSCamera.UpdateShake(deltaTime: number)
	-- Decay trauma
	cameraShakeTrauma = math.max(0, cameraShakeTrauma - cameraShakeDecay * deltaTime)
	
	if cameraShakeTrauma > 0 then
		-- Calculate shake intensity (trauma^2 for snappy feel)
		local intensity = cameraShakeTrauma ^ 2 * 5
		
		-- Perlin noise based shake
		local time = os.clock() * 25
		cameraState.shakeOffset = Vector3.new(
			math.noise(time, 0, 0) * intensity,
			math.noise(0, time, 0) * intensity * 0.5,
			math.noise(0, 0, time) * intensity
		)
		
		cameraState.shakeIntensity = intensity
	else
		cameraState.shakeOffset = cameraState.shakeOffset:Lerp(Vector3.zero, deltaTime * 10)
		cameraState.shakeIntensity = 0
	end
end

function OTSCamera.CalculateCameraCFrame(): CFrame
	if not rootPart or not head then return CFrame.new() end
	
	-- Base rotation from camera rotation
	local yaw = cameraState.rotation.Y
	local pitch = cameraState.rotation.X
	
	local baseRotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	
	-- Base position: character pivot + stance offset
	local characterPivot = rootPart.CFrame * CFrame.new(0, 1.5, 0)
	local basePos = characterPivot.Position + cameraState.stanceOffset
	
	-- Camera distance (closer when ADS)
	local distance = cameraState.isADS and 0.5 or cameraState.distance
	
	-- Shoulder offset (right shoulder)
	local shoulderOffset = Vector3.new(
		cameraState.isADS and 0.1 or 1.5, -- Move to center when ADS
		cameraState.isADS and 0.1 or 1.6,
		0
	)
	
	-- Lean offset
	shoulderOffset += cameraState.leanOffset
	
	-- Sprint offset
	if cameraState.isSprinting then
		shoulderOffset += Vector3.new(0, -0.3, 1) -- Lower and back
	end
	
	-- Slide offset
	if cameraState.isSliding then
		shoulderOffset += Vector3.new(0, -1, 0.5)
	end
	
	-- Calculate final position
	local cameraPos = basePos 
		+ baseRotation * shoulderOffset 
		+ baseRotation.LookVector * -distance
	
	-- Collision check (push camera forward if obstructed)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local hit = Workspace:Raycast(basePos, (cameraPos - basePos).Unit * (distance + 1), raycastParams)
	if hit then
		cameraPos = hit.Position + (cameraPos - basePos).Unit * 0.2
	end
	
	-- Lean rotation (tilt camera slightly)
	local leanRotation = CFrame.Angles(0, 0, leanAngle * 0.15)
	
	return CFrame.new(cameraPos) * baseRotation * leanRotation
end

function OTSCamera.AddTrauma(amount: number)
	cameraShakeTrauma = math.clamp(cameraShakeTrauma + amount, 0, 1)
end

function OTSCamera.SetTargetFOV(fov: number)
	targetFOV = fov
end

function OTSCamera.SetLeanTarget(target: number)
	targetLean = target
end

function OTSCamera.AddRotationOffset(pitch: number, yaw: number)
	cameraState.rotation = cameraState.rotation + Vector2.new(pitch, yaw)
end

function OTSCamera.GetState(): CameraState
	return cameraState
end

function OTSCamera.SetADSState(state: boolean)
	cameraState.isADS = state
end

function OTSCamera.Cleanup()
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
end

return OTSCamera