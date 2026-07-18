--[[
	AudioController - Initializes occlusion, reverb, footstep systems
	Handles sound events from server, voice proximity stub
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local MatchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes")

-- Shared modules
local OcclusionSystem = require(ReplicatedStorage.Modules.Audio.OcclusionSystem)
local ReverbZones = require(ReplicatedStorage.Modules.Audio.ReverbZones)
local FootstepAudio = require(ReplicatedStorage.Modules.Audio.FootstepAudio)

local AudioController = {}

-- State
local localPlayer = Players.LocalPlayer
local character = nil

-- ==================== INIT ====================

function AudioController.Initialize()
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	
	-- Initialize subsystems
	OcclusionSystem.Initialize()
	ReverbZones.Initialize()
	FootstepAudio.Initialize(character)
	
	-- Connect remotes
	AudioController.ConnectRemotes()
	
	-- Character respawn
	localPlayer.CharacterAdded:Connect(function(newChar)
		character = newChar
		FootstepAudio.Initialize(newChar)
	end)
	
	print("[AudioController] Initialized")
end

function AudioController.ConnectRemotes()
	-- Damage indicator sound
	MatchRemotes.DamageIndicator.OnClientEvent:Connect(function(data)
		AudioController.PlayDamageSound(data)
	end)
	
	-- Hit marker sound
	MatchRemotes.HitMarker.OnClientEvent:Connect(function(data)
		AudioController.PlayHitMarker(data)
	end)
	
	-- Kill feed sound
	MatchRemotes.KillFeed.OnClientEvent:Connect(function(data)
		AudioController.PlayKillSound()
	end)
	
	-- Zone gas sound
	MatchRemotes.GasEffect.OnClientEvent:Connect(function(data)
		AudioController.UpdateGasAudio(data)
	end)
	
	-- Vehicle sounds
	MatchRemotes.VehicleUpdate.OnClientEvent:Connect(function(data)
		AudioController.HandleVehicleAudio(data)
	end)
end

-- ==================== SOUND PLAYBACK ====================

function AudioController.PlayDamageSound(data)
	-- Play directional damage indicator sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://1234567910" -- placeholder
	sound.Volume = 0.6
	sound.Parent = game:GetService("SoundService")
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 1)
end

function AudioController.PlayHitMarker(data)
	local sound = Instance.new("Sound")
	sound.SoundId = data.IsHeadshot and "rbxassetid://1234567911" or "rbxassetid://1234567912"
	sound.Volume = 0.5
	sound.PlaybackSpeed = data.IsHeadshot and 1.2 or 1.0
	sound.Parent = game:GetService("SoundService")
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 1)
end

function AudioController.PlayKillSound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://1234567913"
	sound.Volume = 0.7
	sound.Parent = game:GetService("SoundService")
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 2)
end

function AudioController.UpdateGasAudio(data)
	-- Handle gas damage vignette audio
	if data.IsInGas then
		-- Low-pass filter, muffled sound
		game:GetService("SoundService").AmbientReverb = Enum.ReverbType.UnderWater
	else
		game:GetService("SoundService").AmbientReverb = Enum.ReverbType.NoReverb
	end
end

function AudioController.HandleVehicleAudio(data)
	-- Vehicle engine sounds handled by EngineAudio module
	-- This could trigger horn, crash sounds, etc.
end

-- ==================== FOOTSTEP INTEGRATION ====================

RunService.Heartbeat:Connect(function(deltaTime)
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		local hrp = character:FindFirstChild("HumanoidRootPart")
		
		if humanoid and hrp then
			local speed = hrp.AssemblyLinearVelocity.Magnitude
			FootstepAudio.TryPlayFootstep(character, speed)
		end
	end
end)

print("[AudioController] Module loaded")
return AudioController