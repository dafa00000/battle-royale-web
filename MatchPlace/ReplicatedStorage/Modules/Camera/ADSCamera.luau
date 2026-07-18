--[[
	ADSCamera - Aim Down Sights transitions
	Lerp to center, FOV zoom, sensitivity multiplier, sway reduction
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local ADSCamera = {}

-- State
local isADS = false
local adsProgress = 0 -- 0 to 1
local targetFOV = 70
local currentFOV = 70

-- ADS settings per weapon class
local ADS_SETTINGS = {
	AR = { fov = 45, adsTime = 0.15, sensMult = 0.4, swayMult = 0.3 },
	SMG = { fov = 50, adsTime = 0.12, sensMult = 0.5, swayMult = 0.4 },
	SR = { fov = 35, adsTime = 0.2, sensMult = 0.25, swayMult = 0.15 },
	DMR = { fov = 40, adsTime = 0.18, sensMult = 0.35, swayMult = 0.2 },
	SG = { fov = 55, adsTime = 0.15, sensMult = 0.45, swayMult = 0.35 },
	Pistol = { fov = 55, adsTime = 0.1, sensMult = 0.6, swayMult = 0.4 },
	Default = { fov = 45, adsTime = 0.15, sensMult = 0.4, swayMult = 0.3 },
}

local currentSettings = ADS_SETTINGS.Default

-- ==================== PUBLIC API ====================

function ADSCamera.SetWeaponClass(weaponClass: string)
	currentSettings = ADS_SETTINGS[weaponClass] or ADS_SETTINGS.Default
end

function ADSCamera.SetADS(enabled: boolean)
	isADS = enabled
end

function ADSCamera.IsADS(): boolean
	return isADS
end

function ADSCamera.GetProgress(): number
	return adsProgress
end

function ADSCamera.GetSettings()
	return currentSettings
end

function ADSCamera.GetFOV(): number
	return currentFOV
end

function ADSCamera.GetSensitivityMultiplier(): number
	return Util.Lerp(1, currentSettings.sensMult, adsProgress)
end

function ADSCamera.GetSwayMultiplier(): number
	return Util.Lerp(1, currentSettings.swayMult, adsProgress)
end

-- ==================== UPDATE ====================

function ADSCamera.Update(deltaTime: number, camera: Camera)
	local targetProgress = isADS and 1 or 0
	local speed = 1 / currentSettings.adsTime
	
	adsProgress = Util.Clamp(adsProgress + (targetProgress - adsProgress) * speed * deltaTime, 0, 1)
	
	-- FOV lerp
	currentFOV = Util.Lerp(70, currentSettings.fov, adsProgress)
	camera.FieldOfView = currentFOV
	
	return adsProgress
end

-- ==================== OFFSET CALCULATION ====================

-- Returns offset CFrame for ADS (center alignment)
function ADSCamera.GetADSOffset(): CFrame
	if adsProgress <= 0 then return CFrame.identity end
	
	-- Offset from shoulder to center
	local offset = CFrame.new(0, 0, 0) -- Will be combined with OTS camera
	
	-- Slight downward tilt when ADS
	local pitch = -math.rad(1.5) * adsProgress
	
	return offset * CFrame.Angles(pitch, 0, 0)
end

print("[ADSCamera] Initialized")
return ADSCamera