--[[
	OcclusionSystem - Raycast listener->source every 100ms, volume/low-pass by occlusion, max distance culling
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local OcclusionSystem = {}

export type OcclusionData = {
	sound: Sound,
	source: BasePart | Attachment,
	lowPass: LowPassFilter?,
	occlusionLevel: number, -- 0 = clear, 1 = fully occluded
	targetOcclusion: number,
	maxDistance: number,
	lastCheckTime: number,
	isCulled: boolean,
}

export type OcclusionConfig = {
	updateRate: number, -- Seconds between occlusion checks
	maxDistance: number,
	occlusionSmoothing: number, -- How fast occlusion lerps
	cullDistance: number, -- Distance to fully cull sound
	minCutoff: number, -- Low-pass filter minimum cutoff
	maxCutoff: number, -- Low-pass filter maximum cutoff
}

-- Default configuration
local DEFAULT_CONFIG: OcclusionConfig = {
	updateRate = 0.1, -- 100ms
	maxDistance = 500,
	occlusionSmoothing = 8,
	cullDistance = 600,
	minCutoff = 400,
	maxCutoff = 22000,
}

-- Active occlusion tracking
local trackedSounds: { [Sound]: OcclusionData } = {}
local config: OcclusionConfig = DEFAULT_CONFIG

-- Listener reference
local listener: BasePart?

function OcclusionSystem.Initialize(listenerPart: BasePart?)
	listener = listenerPart or Workspace.CurrentCamera

	-- Start update loop
	RunService.Heartbeat:Connect(OcclusionSystem.Update)

	print("[OcclusionSystem] Initialized")
end

function OcclusionSystem.SetListener(listenerPart: BasePart)
	listener = listenerPart
end

function OcclusionSystem.TrackSound(sound: Sound, source: BasePart | Attachment, maxDistance: number?): OcclusionData
	if trackedSounds[sound] then
		return trackedSounds[sound]
	end

	-- Create low-pass filter if not present
	local lowPass = sound:FindFirstChildOfClass("LowPassFilter")
	if not lowPass then
		lowPass = Instance.new("LowPassFilter")
		lowPass.Name = "OcclusionFilter"
		lowPass.CutoffFrequency = config.maxCutoff
		lowPass.Resonance = 0.1
		lowPass.Parent = sound
	end

	local data: OcclusionData = {
		sound = sound,
		source = source,
		lowPass = lowPass,
		occlusionLevel = 0,
		targetOcclusion = 0,
		maxDistance = maxDistance or config.maxDistance,
		lastCheckTime = 0,
		isCulled = false,
	}

	trackedSounds[sound] = data
	return data
end

function OcclusionSystem.UntrackSound(sound: Sound)
	trackedSounds[sound] = nil
end

function OcclusionSystem.Update()
	if not listener then
		local camera = Workspace.CurrentCamera
		if camera then
			listener = camera
		else
			return
		end
	end

	local listenerPos = listener.CFrame.Position
	local now = os.clock()

	for sound, data in pairs(trackedSounds) do
		-- Check if sound is still valid
		if not sound or not sound.Parent then
			trackedSounds[sound] = nil
			continue
		end

		-- Rate limit occlusion checks
		if now - data.lastCheckTime < config.updateRate then
			continue
		end
		data.lastCheckTime = now

		-- Get source position
		local sourcePos: Vector3
		if data.source:IsA("BasePart") then
			sourcePos = data.source.Position
		elseif data.source:IsA("Attachment") then
			sourcePos = data.source.WorldPosition
		else
			continue
		end

		local distance = (sourcePos - listenerPos).Magnitude

		-- Max distance culling
		if distance > config.cullDistance then
			if not data.isCulled then
				data.isCulled = true
				sound.Volume = 0
			end
			continue
		else
			data.isCulled = false
		end

		-- Calculate occlusion
		data.targetOcclusion = OcclusionSystem.CalculateOcclusion(listenerPos, sourcePos, distance)

		-- Smooth occlusion
		data.occlusionLevel = Util.Lerp(data.occlusionLevel, data.targetOcclusion, config.occlusionSmoothing * config.updateRate)

		-- Apply occlusion to sound
		OcclusionSystem.ApplyOcclusion(data, distance)
	end
end

function OcclusionSystem.CalculateOcclusion(listenerPos: Vector3, sourcePos: Vector3, distance: number): number
	if distance > config.maxDistance then
		return 1 -- Fully occluded beyond max distance
	end

	local direction = (sourcePos - listenerPos).Unit
	local rayDistance = math.min(distance, config.maxDistance)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { listener }

	local hit = Workspace:Raycast(listenerPos, direction * rayDistance, raycastParams)

	if not hit then
		return 0 -- Clear line of sight
	end

	-- Calculate occlusion based on hit distance vs total distance
	local occlusion = 1 - (hit.Distance / distance)
	return math.clamp(occlusion, 0, 1)
end

function OcclusionSystem.ApplyOcclusion(data: OcclusionData, distance: number)
	local sound = data.sound
	local occlusion = data.occlusionLevel

	-- Volume attenuation
	local distanceAttenuation = 1 - math.clamp(distance / data.maxDistance, 0, 1)
	local occlusionAttenuation = 1 - occlusion * 0.7 -- Occlusion reduces volume by up to 70%

	-- Apply volume (preserve original volume setting)
	local baseVolume = sound:GetAttribute("BaseVolume") or sound.Volume
	sound.Volume = baseVolume * distanceAttenuation * occlusionAttenuation

	-- Low-pass filter
	if data.lowPass then
		-- More occlusion = lower cutoff frequency (muffled sound)
		local cutoff = Util.Lerp(config.maxCutoff, config.minCutoff, occlusion)
		data.lowPass.CutoffFrequency = cutoff
	end
end

function OcclusionSystem.GetOcclusionLevel(sound: Sound): number
	local data = trackedSounds[sound]
	return data and data.occlusionLevel or 0
end

function OcclusionSystem.IsCulled(sound: Sound): boolean
	local data = trackedSounds[sound]
	return data and data.isCulled or false
end

function OcclusionSystem.SetConfig(newConfig: OcclusionConfig)
	config = newConfig
end

function OcclusionSystem.GetConfig(): OcclusionConfig
	return config
end

function OcclusionSystem.ForceCheck(sound: Sound)
	local data = trackedSounds[sound]
	if data then
		data.lastCheckTime = 0 -- Force immediate check on next update
	end
end

function OcclusionSystem.GetTrackedCount(): number
	local count = 0
	for _ in pairs(trackedSounds) do
		count += 1
	end
	return count
end

function OcclusionSystem.Cleanup()
	trackedSounds = {}
	listener = nil
end

return OcclusionSystem
