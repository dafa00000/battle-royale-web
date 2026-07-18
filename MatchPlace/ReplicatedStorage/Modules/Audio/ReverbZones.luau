--[[
	ReverbZones - Indoor/outdoor reverb with crossfade
	Tagged parts as reverb zones, preset support, crossfade 1.5s/2s
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local ReverbZones = {}

-- Reverb presets
local PRESETS = {
	Outdoor = {
		Density = 0.1, Diffusion = 0.1, Gain = 0, GainHF = 0,
		DecayTime = 0.5, DecayHFRatio = 0.5, ReflectionsGain = 0,
		ReflectionsDelay = 0, LateReverbGain = 0, LateReverbDelay = 0,
		AirAbsorptionGainHF = 0, RoomRolloffFactor = 0,
	},
	Indoor_Small = {
		Density = 0.8, Diffusion = 0.8, Gain = 0.5, GainHF = -4,
		DecayTime = 1.2, DecayHFRatio = 0.6, ReflectionsGain = 0.3,
		ReflectionsDelay = 0.02, LateReverbGain = 0.4, LateReverbDelay = 0.04,
		AirAbsorptionGainHF = -8, RoomRolloffFactor = 0.5,
	},
	Indoor_Medium = {
		Density = 0.9, Diffusion = 0.9, Gain = 0.6, GainHF = -2,
		DecayTime = 2.0, DecayHFRatio = 0.5, ReflectionsGain = 0.4,
		ReflectionsDelay = 0.04, LateReverbGain = 0.5, LateReverbDelay = 0.06,
		AirAbsorptionGainHF = -6, RoomRolloffFactor = 0.3,
	},
	Indoor_Large = {
		Density = 1.0, Diffusion = 1.0, Gain = 0.7, GainHF = 0,
		DecayTime = 3.5, DecayHFRatio = 0.4, ReflectionsGain = 0.5,
		ReflectionsDelay = 0.08, LateReverbGain = 0.6, LateReverbDelay = 0.1,
		AirAbsorptionGainHF = -4, RoomRolloffFactor = 0.2,
	},
	Cave = {
		Density = 1.0, Diffusion = 0.9, Gain = 0.8, GainHF = -6,
		DecayTime = 5.0, DecayHFRatio = 0.3, ReflectionsGain = 0.6,
		ReflectionsDelay = 0.1, LateReverbGain = 0.7, LateReverbDelay = 0.15,
		AirAbsorptionGainHF = -10, RoomRolloffFactor = 0.1,
	},
}

-- State
local currentPreset = "Outdoor"
local currentReverb = nil
local targetReverb = nil
local crossfadeProgress = 1
local crossfadeTime = 0
local CROSSFADE_IN = 1.5
local CROSSFADE_OUT = 2.0

-- ==================== INIT ====================

function ReverbZones.Initialize()
	-- Create ReverbSoundEffect in SoundService
	local SoundService = game:GetService("SoundService")
	currentReverb = Instance.new("ReverbSoundEffect")
	currentReverb.Name = "ZoneReverb"
	currentReverb.Parent = SoundService
	ReverbZones.ApplyPreset("Outdoor")
	
	-- Listen for zone tags
	CollectionService:GetInstanceAddedSignal("ReverbZone"):Connect(function(part)
		ReverbZones.OnZoneEntered(part)
	end)
	
	CollectionService:GetInstanceRemovedSignal("ReverbZone"):Connect(function(part)
		ReverbZones.OnZoneLeft(part)
	end)
	
	-- Check initial zones
	for _, part in ipairs(CollectionService:GetTagged("ReverbZone")) do
		ReverbZones.OnZoneEntered(part)
	end
	
	RunService.Heartbeat:Connect(ReverbZones.Update)
	
	print("[ReverbZones] Initialized")
end

-- ==================== ZONE DETECTION ====================

local activeZones = {}

function ReverbZones.OnZoneEntered(part)
	if not part:IsA("BasePart") then return end
	
	local presetName = part:GetAttribute("ReverbPreset") or "Indoor_Medium"
	activeZones[part] = presetName
	ReverbZones.UpdateTargetPreset()
end

function ReverbZones.OnZoneLeft(part)
	activeZones[part] = nil
	ReverbZones.UpdateTargetPreset()
end

function ReverbZones.UpdateTargetPreset()
	-- Find highest priority zone containing player
	local character = game.Players.LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		targetReverb = "Outdoor"
		crossfadeTime = CROSSFADE_OUT
		return
	end
	
	local hrp = character.HumanoidRootPart
	local bestPreset = "Outdoor"
	local bestPriority = -1
	
	for part, preset in pairs(activeZones) do
		if part:IsA("BasePart") then
			-- Simple point-in-part check (for box parts)
			local cf = part.CFrame
			local size = part.Size
			local localPos = cf:PointToObjectSpace(hrp.Position)
			local half = size * 0.5
			
			if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
				-- Inside zone
				local priority = ({Outdoor = 0, Indoor_Small = 1, Indoor_Medium = 2, Indoor_Large = 3, Cave = 4})[preset] or 1
				if priority > bestPriority then
					bestPriority = priority
					bestPreset = preset
				end
			end
		end
	end
	
	if bestPreset ~= currentPreset then
		targetReverb = bestPreset
		crossfadeTime = (bestPreset == "Outdoor") and CROSSFADE_OUT or CROSSFADE_IN
		crossfadeProgress = 0
	end
end

-- ==================== REVERB APPLICATION ====================

function ReverbZones.ApplyPreset(presetName)
	local preset = PRESETS[presetName] or PRESETS.Outdoor
	for prop, value in pairs(preset) do
		currentReverb[prop] = value
	end
	currentPreset = presetName
end

function ReverbZones.Update(deltaTime)
	if targetReverb and crossfadeProgress < 1 then
		crossfadeProgress = Util.Clamp(crossfadeProgress + deltaTime / crossfadeTime, 0, 1)
		
		-- Interpolate reverb properties
		local fromPreset = PRESETS[currentPreset] or PRESETS.Outdoor
		local toPreset = PRESETS[targetReverb] or PRESETS.Outdoor
		
		for prop in pairs(fromPreset) do
			local fromVal = fromPreset[prop]
			local toVal = toPreset[prop]
			currentReverb[prop] = Util.Lerp(fromVal, toVal, crossfadeProgress)
		end
		
		if crossfadeProgress >= 1 then
			currentPreset = targetReverb
			targetReverb = nil
		end
	end
end

print("[ReverbZones] Module loaded")
return ReverbZones