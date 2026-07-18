--[[
	EngineAudio - Adaptive engine sound: pitch/volume by RPM, gear shifts, surface type, occlusion
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local EngineAudio = {}

export type EngineSoundConfig = {
	baseSoundId: string,
	idleRPM: number,
	maxRPM: number,
	gearCount: number,
	baseVolume: number,
	pitchRange: NumberRange,
	surfaceModifiers: { [Enum.Material]: number },
}

export type EngineAudioState = {
	vehicle: Model,
	chassis: BasePart,
	engineSound: Sound?,
	gearSound: Sound?,
	surfaceSound: Sound?,
	occlusionFilter: LowPassFilter?,
	currentRPM: number,
	targetPitch: number,
	targetVolume: number,
	currentGear: number,
	surfaceType: Enum.Material,
	isOccluded: boolean,
	lastGearShift: number,
	updateConnection: RBXScriptConnection?,
}

-- Default configuration
local DEFAULT_CONFIG: EngineSoundConfig = {
	baseSoundId = "rbxassetid://0",
	idleRPM = 800,
	maxRPM = 7000,
	gearCount = 5,
	baseVolume = 0.8,
	pitchRange = NumberRange.new(0.5, 2.0),
	surfaceModifiers = {
		[Enum.Material.Asphalt] = 1.0,
		[Enum.Material.Concrete] = 0.9,
		[Enum.Material.Grass] = 0.7,
		[Enum.Material.Dirt] = 0.75,
		[Enum.Material.Sand] = 0.6,
		[Enum.Material.Gravel] = 0.85,
		[Enum.Material.Metal] = 1.1,
		[Enum.Material.Wood] = 0.8,
	},
}

-- Active engine audio states
local engineStates: { [string]: EngineAudioState } = {}

-- Sound IDs (placeholders)
local SOUND_IDS = {
	engine = "rbxassetid://0",
	gearShift = "rbxassetid://0",
	surfaceRoll = "rbxassetid://0",
	skidding = "rbxassetid://0",
}

function EngineAudio.Initialize(vehicle: Model, config: EngineSoundConfig?): EngineAudioState?
	local chassis = vehicle:FindFirstChild("Chassis") or vehicle.PrimaryPart
	if not chassis then
		warn("[EngineAudio] No chassis found for vehicle:", vehicle.Name)
		return nil
	end

	local cfg = config or DEFAULT_CONFIG

	local state: EngineAudioState = {
		vehicle = vehicle,
		chassis = chassis,
		engineSound = nil,
		gearSound = nil,
		surfaceSound = nil,
		occlusionFilter = nil,
		currentRPM = cfg.idleRPM,
		targetPitch = 1.0,
		targetVolume = cfg.baseVolume,
		currentGear = 1,
		surfaceType = Enum.Material.Asphalt,
		isOccluded = false,
		lastGearShift = 0,
		updateConnection = nil,
	}

	-- Create engine sound
	local engineSound = Instance.new("Sound")
	engineSound.Name = "EngineSound"
	engineSound.SoundId = SOUND_IDS.engine
	engineSound.Looped = true
	engineSound.Volume = cfg.baseVolume
	engineSound.RollOffMinDistance = Constants.AUDIO_ROLLOFF.Vehicle.min
	engineSound.RollOffMaxDistance = Constants.AUDIO_ROLLOFF.Vehicle.max
	engineSound.EmitterSize = 5
	engineSound.Parent = chassis

	-- Create low-pass filter for occlusion
	local lowPass = Instance.new("LowPassFilter")
	lowPass.Name = "OcclusionFilter"
	lowPass.CutoffFrequency = 20000 -- Start fully open
	lowPass.Resonance = 0.1
	lowPass.Parent = engineSound

	-- Create gear shift sound
	local gearSound = Instance.new("Sound")
	gearSound.Name = "GearShiftSound"
	gearSound.SoundId = SOUND_IDS.gearShift
	gearSound.Volume = 0.5
	gearSound.RollOffMaxDistance = 50
	gearSound.Parent = chassis

	-- Create surface rolling sound
	local surfaceSound = Instance.new("Sound")
	surfaceSound.Name = "SurfaceSound"
	surfaceSound.SoundId = SOUND_IDS.surfaceRoll
	surfaceSound.Looped = true
	surfaceSound.Volume = 0.3
	surfaceSound.RollOffMaxDistance = 40
	surfaceSound.Parent = chassis

	state.engineSound = engineSound
	state.gearSound = gearSound
	state.surfaceSound = surfaceSound
	state.occlusionFilter = lowPass

	-- Start engine sound
	engineSound:Play()
	surfaceSound:Play()

	-- Store state
	engineStates[vehicle.Name] = state

	-- Start update loop
	state.updateConnection = RunService.Heartbeat:Connect(function(dt)
		EngineAudio.Update(vehicle.Name, dt)
	end)

	return state
end

function EngineAudio.Update(vehicleName: string, deltaTime: number)
	local state = engineStates[vehicleName]
	if not state then return end
	if not state.vehicle or not state.vehicle.Parent then
		EngineAudio.Cleanup(vehicleName)
		return
	end

	-- Get vehicle data from ChassisController if available
	local ChassisController = require(script.Parent.ChassisController)
	local vehicleData = ChassisController.GetVehicle(vehicleName)

	if vehicleData then
		state.currentRPM = vehicleData.state.rpm
		state.currentGear = vehicleData.state.gear
	else
		-- Estimate RPM from speed
		local speed = state.chassis.AssemblyLinearVelocity.Magnitude
		state.currentRPM = DEFAULT_CONFIG.idleRPM + (speed / 100) * (DEFAULT_CONFIG.maxRPM - DEFAULT_CONFIG.idleRPM)
	end

	-- Update pitch based on RPM
	local rpmRatio = (state.currentRPM - DEFAULT_CONFIG.idleRPM) / (DEFAULT_CONFIG.maxRPM - DEFAULT_CONFIG.idleRPM)
	rpmRatio = math.clamp(rpmRatio, 0, 1)
	state.targetPitch = DEFAULT_CONFIG.pitchRange.Min + rpmRatio * (DEFAULT_CONFIG.pitchRange.Max - DEFAULT_CONFIG.pitchRange.Min)

	-- Update volume based on throttle (estimated from RPM change)
	local rpmDelta = math.abs(state.currentRPM - (state.lastRPM or state.currentRPM))
	local throttleIntensity = math.clamp(rpmDelta * 0.01, 0, 1)
	state.targetVolume = DEFAULT_CONFIG.baseVolume * (0.6 + throttleIntensity * 0.4)

	-- Detect surface type
	state.surfaceType = EngineAudio.DetectSurface(state.chassis)

	-- Apply surface modifier
	local surfaceMod = DEFAULT_CONFIG.surfaceModifiers[state.surfaceType] or 1.0
	state.targetVolume *= surfaceMod

	-- Check occlusion
	state.isOccluded = EngineAudio.CheckOcclusion(state.chassis)

	-- Apply occlusion filter
	if state.occlusionFilter then
		local targetCutoff = state.isOccluded and 800 or 20000
		state.occlusionFilter.CutoffFrequency = Util.Lerp(
			state.occlusionFilter.CutoffFrequency,
			targetCutoff,
			deltaTime * 5
		)
	end

	-- Apply sound properties
	if state.engineSound then
		state.engineSound.PlaybackSpeed = Util.Lerp(
			state.engineSound.PlaybackSpeed,
			state.targetPitch,
			deltaTime * 8
		)
		state.engineSound.Volume = Util.Lerp(
			state.engineSound.Volume,
			state.targetVolume,
			deltaTime * 5
		)
	end

	-- Update surface sound
	if state.surfaceSound then
		local speed = state.chassis.AssemblyLinearVelocity.Magnitude
		state.surfaceSound.Volume = Util.Lerp(
			state.surfaceSound.Volume,
			speed > 1 and 0.3 * surfaceMod or 0,
			deltaTime * 3
		)
		state.surfaceSound.PlaybackSpeed = 0.8 + (speed / 100) * 0.4
	end

	-- Detect gear shift
	if vehicleData and state.currentGear ~= state.lastGear then
		EngineAudio.PlayGearShift(state)
		state.lastGear = state.currentGear
	end

	state.lastRPM = state.currentRPM
end

function EngineAudio.DetectSurface(chassis: BasePart): Enum.Material
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { chassis.Parent }

	local result = Workspace:Raycast(
		chassis.Position,
		Vector3.new(0, -5, 0),
		raycastParams
	)

	return result and result.Material or Enum.Material.Asphalt
end

function EngineAudio.CheckOcclusion(chassis: BasePart): boolean
	local camera = Workspace.CurrentCamera
	if not camera then return false end

	local listenerPos = camera.CFrame.Position
	local sourcePos = chassis.Position
	local direction = (sourcePos - listenerPos).Unit
	local distance = (sourcePos - listenerPos).Magnitude

	if distance > Constants.AUDIO_ROLLOFF.Vehicle.max then
		return true -- Too far, treat as occluded
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { chassis.Parent, camera }

	local hit = Workspace:Raycast(listenerPos, direction * distance, raycastParams)
	return hit ~= nil
end

function EngineAudio.PlayGearShift(state: EngineAudioState)
	if not state.gearSound then return end

	-- Only play if not too frequent
	if os.clock() - state.lastGearShift < 0.3 then return end
	state.lastGearShift = os.clock()

	state.gearSound:Play()
end

function EngineAudio.SetRPM(vehicleName: string, rpm: number)
	local state = engineStates[vehicleName]
	if state then
		state.currentRPM = rpm
	end
end

function EngineAudio.SetGear(vehicleName: string, gear: number)
	local state = engineStates[vehicleName]
	if state and state.currentGear ~= gear then
		state.currentGear = gear
		EngineAudio.PlayGearShift(state)
	end
end

function EngineAudio.GetState(vehicleName: string): EngineAudioState?
	return engineStates[vehicleName]
end

function EngineAudio.Stop(vehicleName: string)
	local state = engineStates[vehicleName]
	if not state then return end

	if state.engineSound then
		state.engineSound:Stop()
	end
	if state.surfaceSound then
		state.surfaceSound:Stop()
	end
end

function EngineAudio.Start(vehicleName: string)
	local state = engineStates[vehicleName]
	if not state then return end

	if state.engineSound then
		state.engineSound:Play()
	end
	if state.surfaceSound then
		state.surfaceSound:Play()
	end
end

function EngineAudio.Cleanup(vehicleName: string)
	local state = engineStates[vehicleName]
	if not state then return end

	if state.updateConnection then
		state.updateConnection:Disconnect()
	end

	if state.engineSound then
		state.engineSound:Destroy()
	end
	if state.gearSound then
		state.gearSound:Destroy()
	end
	if state.surfaceSound then
		state.surfaceSound:Destroy()
	end

	engineStates[vehicleName] = nil
end

function EngineAudio.CleanupAll()
	for vehicleName, _ in pairs(engineStates) do
		EngineAudio.Cleanup(vehicleName)
	end
end

return EngineAudio
