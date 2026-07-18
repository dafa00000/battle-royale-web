--[[
	CameraShake - Trauma-based procedural camera shake
	Add trauma, decays over time, perlin noise offset
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local CameraShake = {}

-- State
local trauma = 0
local maxTrauma = 1
local traumaDecay = 2.5 -- per second

-- Perlin noise seeds
local seedX = math.random() * 1000
local seedY = math.random() * 1000
local seedZ = math.random() * 1000

-- Shake intensity settings
local SHAKE_INTENSITY = {
	Position = Vector3.new(0.5, 0.5, 0.3),
	Rotation = Vector3.new(0.8, 0.8, 0.5),
}

-- Presets
local PRESETS = {
	Small = { trauma = 0.15, desc = "Footstep, light impact" },
	Medium = { trauma = 0.35, desc = "Weapon fire, vault landing" },
	Large = { trauma = 0.6, desc = "Explosion nearby, vehicle crash" },
	Explosion = { trauma = 1.0, desc = "Direct explosion, massive impact" },
}

-- ==================== PERLIN NOISE (simple) ====================

local function PerlinNoise(x: number, y: number, z: number): number
	-- Simple 3D noise approximation
	local n = math.sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453
	return (n - math.floor(n)) * 2 - 1
end

-- ==================== PUBLIC API ====================

function CameraShake.AddTrauma(amount: number)
	trauma = math.clamp(trauma + amount, 0, maxTrauma)
end

function CameraShake.AddTraumaPreset(preset: string)
	local p = PRESETS[preset]
	if p then
		CameraShake.AddTrauma(p.trauma)
	end
end

function CameraShake.SetTrauma(value: number)
	trauma = math.clamp(value, 0, maxTrauma)
end

function CameraShake.GetTrauma(): number
	return trauma
end

function CameraShake.SetDecayRate(rate: number)
	traumaDecay = rate
end

-- ==================== UPDATE ====================

function CameraShake.Update(deltaTime: number): CFrame
	if trauma <= 0 then return CFrame.identity end
	
	-- Decay trauma
	trauma = math.max(0, trauma - traumaDecay * deltaTime)
	
	-- Calculate shake intensity (trauma^2 for sharper falloff)
	local intensity = trauma * trauma
	
	-- Time-based noise
	local t = os.clock() * 25
	
	-- Position offset
	local posOffset = Vector3.new(
		PerlinNoise(seedX + t, 0, 0) * SHAKE_INTENSITY.Position.X,
		PerlinNoise(0, seedY + t, 0) * SHAKE_INTENSITY.Position.Y,
		PerlinNoise(0, 0, seedZ + t) * SHAKE_INTENSITY.Position.Z
	) * intensity
	
	-- Rotation offset (radians)
	local rotOffset = Vector3.new(
		PerlinNoise(seedX + t + 100, 0, 0) * SHAKE_INTENSITY.Rotation.X,
		PerlinNoise(0, seedY + t + 200, 0) * SHAKE_INTENSITY.Rotation.Y,
		PerlinNoise(0, 0, seedZ + t + 300) * SHAKE_INTENSITY.Rotation.Z
	) * intensity
	
	-- Convert to CFrame
	local shakeCFrame = CFrame.new(posOffset) * 
		CFrame.Angles(rotOffset.X, rotOffset.Y, rotOffset.Z)
	
	return shakeCFrame
end

print("[CameraShake] Initialized")
return CameraShake