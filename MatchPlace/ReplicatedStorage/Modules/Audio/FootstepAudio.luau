--[[
	FootstepAudio - Material-based footsteps
	Surface detection via raycast, volume by speed/stance, interval by speed
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local FootstepAudio = {}

-- Footstep sound IDs per material (placeholder IDs)
local FOOTSTEP_SOUNDS = {
	Grass = { "rbxassetid://1234567890", "rbxassetid://1234567891", "rbxassetid://1234567892" },
	Sand = { "rbxassetid://1234567893", "rbxassetid://1234567894" },
	Concrete = { "rbxassetid://1234567895", "rbxassetid://1234567896", "rbxassetid://1234567897" },
	Wood = { "rbxassetid://1234567898", "rbxassetid://1234567899" },
	Metal = { "rbxassetid://1234567900", "rbxassetid://1234567901" },
	Gravel = { "rbxassetid://1234567902", "rbxassetid://1234567903" },
	Water = { "rbxassetid://1234567904", "rbxassetid://1234567905" },
	Mud = { "rbxassetid://1234567906", "rbxassetid://1234567907" },
	Snow = { "rbxassetid://1234567908", "rbxassetid://1234567909" },
	Default = { "rbxassetid://1234567910" },
}

-- Material to surface type mapping
local MATERIAL_MAP = {
	[Enum.Material.Grass] = "Grass",
	[Enum.Material.Sand] = "Sand",
	[Enum.Material.Concrete] = "Concrete",
	[Enum.Material.Brick] = "Concrete",
	[Enum.Material.Wood] = "Wood",
	[Enum.Material.WoodPlanks] = "Wood",
	[Enum.Material.Metal] = "Metal",
	[Enum.Material.DiamondPlate] = "Metal",
	[Enum.Material.CorrugatedMetal] = "Metal",
	[Enum.Material.Rock] = "Gravel",
	[Enum.Material.Slate] = "Gravel",
	[Enum.Material.Basalt] = "Gravel",
	[Enum.Material.Pebble] = "Gravel",
	[Enum.Material.Water] = "Water",
	[Enum.Material.Mud] = "Mud",
	[Enum.Material.Ground] = "Mud",
	[Enum.Material.Snow] = "Snow",
	[Enum.Material.Ice] = "Snow",
}

-- Stance volume multipliers
local STANCE_VOLUME = {
	Stand = 1.0,
	Crouch = 0.5,
	Prone = 0.2,
	Slide = 1.2,
	Vault = 1.0,
}

-- State
local lastFootstepTime = 0
local lastMaterial = "Default"
local currentStance = "Stand"
local isMoving = false
local footstepSounds = {}

-- ==================== INIT ====================

function FootstepAudio.Initialize(character)
	-- Pre-load sounds
	for material, ids in pairs(FOOTSTEP_SOUNDS) do
		footstepSounds[material] = {}
		for _, id in ipairs(ids) do
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Volume = 0.5
			sound.RollOffMode = Enum.RollOffMode.Linear
			sound.RollOffMinDistance = 5
			sound.RollOffMaxDistance = 50
			sound.Parent = character.HumanoidRootPart
			table.insert(footstepSounds[material], sound)
		end
	end
	
	-- Listen for stance changes
	local humanoid = character:WaitForChild("Humanoid")
	
	print("[FootstepAudio] Initialized for " .. character.Name)
end

function FootstepAudio.SetStance(stance)
	currentStance = stance
end

function FootstepAudio.SetMoving(moving)
	isMoving = moving
end

-- ==================== SURFACE DETECTION ====================

function FootstepAudio.DetectSurface(character): string
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return "Default" end
	
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false
	
	-- Raycast down from feet
	local origin = hrp.Position + Vector3.new(0, -hrp.Size.Y/2 - 0.5, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -3, 0), params)
	
	if result and result.Material then
		return MATERIAL_MAP[result.Material] or "Default"
	end
	
	return "Default"
end

-- ==================== FOOTSTEP TRIGGER ====================

function FootstepAudio.TryPlayFootstep(character, moveSpeed)
	if not isMoving or moveSpeed < 1 then return end
	
	local now = os.clock()
	
	-- Calculate interval based on speed
	-- Walk: ~0.5s, Run: ~0.35s, Sprint: ~0.25s
	local baseInterval = 0.5
	local speedRatio = moveSpeed / Constants.WALK_SPEED
	local interval = baseInterval / math.max(1, speedRatio)
	
	if now - lastFootstepTime < interval then return end
	
	-- Detect surface
	local material = FootstepAudio.DetectSurface(character)
	lastMaterial = material
	
	-- Play sound
	FootstepAudio.PlaySound(character, material, moveSpeed)
	
	lastFootstepTime = now
end

function FootstepAudio.PlaySound(character, material, moveSpeed)
	local sounds = footstepSounds[material] or footstepSounds.Default
	if #sounds == 0 then return end
	
	-- Pick random sound
	local sound = sounds[math.random(#sounds)]
	
	-- Volume based on speed and stance
	local speedRatio = math.clamp(moveSpeed / Constants.SPRINT_SPEED, 0.3, 1.5)
	local stanceMult = STANCE_VOLUME[currentStance] or 1.0
	local volume = 0.4 * speedRatio * stanceMult
	
	-- Pitch variation
	sound.PlaybackSpeed = 0.9 + math.random() * 0.2
	sound.Volume = volume
	sound:Play()
end

-- ==================== LANDING SOUNDS ====================

function FootstepAudio.PlayLandingSound(character, fallHeight)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local material = FootstepAudio.DetectSurface(character)
	local sounds = footstepSounds[material] or footstepSounds.Default
	
	if #sounds > 0 then
		local sound = sounds[math.random(#sounds)]
		sound.PlaybackSpeed = 0.7
		sound.Volume = math.clamp(fallHeight / 50, 0.3, 1.0)
		sound:Play()
	end
end

print("[FootstepAudio] Module loaded")
return FootstepAudio