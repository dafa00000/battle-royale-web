--[[
	CameraController - Client camera orchestration: OTS camera, ADS, lean, shake, FOV
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local OTSCamera = require(script.Parent.Camera.OTSCamera)

local CameraController = {}

local camera = Workspace.CurrentCamera
local character: Model?
local humanoid: Humanoid?
local rootPart: BasePart?

local isADS = false
local adsAlpha = 0
local leanInput = 0
local baseFOV = 80
local adsFOV = 45
local sprintFOV = 90
local fovTransitionSpeed = 10

-- Recoil recovery state
local recoilOffset = Vector2.zero
local recoilVelocity = Vector2.zero

function CameraController.Initialize(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")

	OTSCamera.Initialize(char)
	CameraController.SetupInput()

	print("[CameraController] Initialized")
end

function CameraController.SetupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Constants.DEFAULT_KEYBINDS.ADS then
			CameraController.SetADS(true)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.LeanLeft then
			CameraController.SetLean(-1)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.LeanRight then
			CameraController.SetLean(1)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Constants.DEFAULT_KEYBINDS.ADS then
			CameraController.SetADS(false)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.LeanLeft or input.KeyCode == Constants.DEFAULT_KEYBINDS.LeanRight then
			CameraController.SetLean(0)
		end
	end)

	RunService.RenderStepped:Connect(CameraController.Update)
end

function CameraController.SetADS(active: boolean)
	isADS = active
	OTSCamera.SetADSState(active)

	-- Notify weapon controller / server
	local weaponId = character and character:GetAttribute("EquippedWeapon")
	if weaponId then
		ReplicatedStorage.Remotes.MatchRemotes.WeaponAds:FireServer({
			weaponId = weaponId,
			isAds = active,
		})
	end
end

function CameraController.SetLean(direction: number)
	leanInput = direction
	OTSCamera.SetLeanTarget(direction)

	-- Replicate lean to server for hitbox adjustment
	ReplicatedStorage.Remotes.MatchRemotes.LeanUpdate:FireServer(direction)
end

function CameraController.Update(deltaTime: number)
	if not character or not rootPart then return end

	-- Smooth ADS FOV transition
	local targetFOV = baseFOV
	if character:GetAttribute("IsSprinting") then
		targetFOV = sprintFOV
	elseif isADS then
		targetFOV = adsFOV
	end

	local currentFOV = camera.FieldOfView
	camera.FieldOfView = Util.Lerp(currentFOV, targetFOV, deltaTime * fovTransitionSpeed)

	-- Recoil recovery
	CameraController.UpdateRecoil(deltaTime)

	-- Apply camera effects from weapon fire, explosions, etc.
	CameraController.ApplyExternalShake()
end

function CameraController.UpdateRecoil(deltaTime: number)
	-- Spring-damper recoil recovery
	local stiffness = 80
	local damping = 12

	local displacement = recoilOffset
	local acceleration = -stiffness * displacement - damping * recoilVelocity

	recoilVelocity += acceleration * deltaTime
	recoilOffset += recoilVelocity * deltaTime

	-- Apply recoil to camera rotation via OTSCamera
	if recoilOffset.Magnitude > 0.001 then
		OTSCamera.AddRotationOffset(recoilOffset.X, recoilOffset.Y)
	end
end

function CameraController.ApplyExternalShake()
	-- External trauma sources (explosions, vehicle, falls)
	-- Handled via AddTrauma calls; OTSCamera decays trauma internally
end

function CameraController.AddRecoil(pitch: number, yaw: number)
	recoilVelocity += Vector2.new(pitch, yaw)
	OTSCamera.AddTrauma(math.clamp(pitch * 0.3, 0, 0.5))
end

function CameraController.AddShake(intensity: number)
	OTSCamera.AddTrauma(intensity)
end

function CameraController.SetBaseFOV(fov: number)
	baseFOV = fov
	OTSCamera.SetTargetFOV(fov)
end

function CameraController.GetADSState(): boolean
	return isADS
end

function CameraController.GetLean(): number
	return leanInput
end

function CameraController.Cleanup()
	OTSCamera.Cleanup()
end

return CameraController
