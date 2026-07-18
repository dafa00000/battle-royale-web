--[[
	ZoneClient - Client zone visualization, warnings, gas effects
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local HUD = require(script.Parent.UI.HUD)

local ZoneClient = {}

local zoneData: {
	Center: Vector3,
	CurrentRadius: number,
	TargetRadius: number,
	Phase: number,
	PhaseEndTime: number,
	IsShrinking: boolean,
	NextCenter: Vector3?,
	NextRadius: number?,
}?

local zoneVisual: Part?
local nextZoneVisual: Part?
local gasAtmosphere: Atmosphere?
local gasEffectActive = false
local warningSound: Sound?

function ZoneClient.Initialize(char: Model)
	ZoneClient.SetupReplication()
	ZoneClient.CreateZoneVisuals()

	print("[ZoneClient] Initialized")
end

function ZoneClient.SetupReplication()
	ReplicatedStorage.Remotes.MatchRemotes.ZoneUpdate.OnClientEvent:Connect(function(data)
		ZoneClient.OnZoneUpdate(data)
	end)

	ReplicatedStorage.Remotes.MatchRemotes.GasEffect.OnClientEvent:Connect(function(intensity, damagePerTick)
		ZoneClient.OnGasEffect(intensity, damagePerTick)
	end)

	ReplicatedStorage.Remotes.MatchRemotes.ZoneWarning.OnClientEvent:Connect(function(data)
		ZoneClient.OnZoneWarning(data)
	end)
end

function ZoneClient.CreateZoneVisuals()
	-- Current zone cylinder
	zoneVisual = Instance.new("Part")
	zoneVisual.Name = "ZoneVisual"
	zoneVisual.Shape = Enum.PartType.Cylinder
	zoneVisual.Size = Vector3.new(1, 1, 1)
	zoneVisual.Transparency = 0.8
	zoneVisual.Color = Color3.fromRGB(0, 100, 255)
	zoneVisual.Material = Enum.Material.Neon
	zoneVisual.Anchored = true
	zoneVisual.CanCollide = false
	zoneVisual.Parent = Workspace

	-- Next zone indicator
	nextZoneVisual = Instance.new("Part")
	nextZoneVisual.Name = "NextZoneVisual"
	nextZoneVisual.Shape = Enum.PartType.Cylinder
	nextZoneVisual.Size = Vector3.new(1, 1, 1)
	nextZoneVisual.Transparency = 0.9
	nextZoneVisual.Color = Color3.fromRGB(255, 255, 0)
	nextZoneVisual.Material = Enum.Material.Neon
	nextZoneVisual.Anchored = true
	nextZoneVisual.CanCollide = false
	nextZoneVisual.Parent = Workspace

	-- Gas atmosphere
	gasAtmosphere = Instance.new("Atmosphere")
	gasAtmosphere.Density = 0
	gasAtmosphere.Offset = 0
	gasAtmosphere.Color = Color3.fromRGB(100, 100, 150)
	gasAtmosphere.Decay = Color3.fromRGB(50, 50, 100)
	gasAtmosphere.Glare = 0
	gasAtmosphere.Haze = 0
	gasAtmosphere.Parent = Lighting

	-- Warning sound
	warningSound = Instance.new("Sound")
	warningSound.SoundId = "rbxassetid://0"
	warningSound.Volume = 0.5
	warningSound.Looped = false
	warningSound.Parent = Workspace.CurrentCamera
end

function ZoneClient.OnZoneUpdate(data)
	zoneData = data

	-- Update HUD minimap
	if data.Center and data.CurrentRadius then
		HUD.UpdateMinimap(
			Workspace.CurrentCamera.CFrame.Position,
			data.Center,
			data.CurrentRadius,
			data.NextCenter,
			data.NextRadius
		)
	end

	-- Update zone timer
	if data.PhaseEndTime then
		local remaining = math.max(0, data.PhaseEndTime - os.clock())
		HUD.UpdateZoneTimer(remaining, data.Phase or 1)
	end

	-- Update 3D zone visuals
	ZoneClient.UpdateZoneVisuals()

	-- Show warning if shrinking soon
	if data.IsShrinking and data.PhaseEndTime then
		local remaining = data.PhaseEndTime - os.clock()
		if remaining <= 30 and remaining > 29 then
			HUD.ShowNotification("ZONE SHRINKING IN 30 SECONDS", 3)
			if warningSound then
				warningSound:Play()
			end
		end
	end
end

function ZoneClient.UpdateZoneVisuals()
	if not zoneData then return end

	local height = 500
	local yPos = zoneData.Center.Y + height / 2

	-- Current zone
	if zoneVisual then
		local diameter = zoneData.CurrentRadius * 2
		zoneVisual.Size = Vector3.new(height, diameter, diameter)
		zoneVisual.CFrame = CFrame.new(zoneData.Center.X, yPos, zoneData.Center.Z) * CFrame.Angles(0, 0, math.rad(90))
	end

	-- Next zone
	if nextZoneVisual and zoneData.NextCenter and zoneData.NextRadius then
		local diameter = zoneData.NextRadius * 2
		nextZoneVisual.Size = Vector3.new(height, diameter, diameter)
		nextZoneVisual.CFrame = CFrame.new(zoneData.NextCenter.X, yPos, zoneData.NextCenter.Z) * CFrame.Angles(0, 0, math.rad(90))
		nextZoneVisual.Transparency = 0.9
	else
		nextZoneVisual.Transparency = 1
	end
end

function ZoneClient.OnGasEffect(intensity: number, damagePerTick: number)
	-- Toggle gas visual effects based on intensity
	if intensity > 0 and not gasEffectActive then
		gasEffectActive = true
		ZoneClient.EnableGasEffects(intensity)
	elseif intensity <= 0 and gasEffectActive then
		gasEffectActive = false
		ZoneClient.DisableGasEffects()
	end

	if gasEffectActive and gasAtmosphere then
		gasAtmosphere.Density = 0.3 + intensity * 0.4
		gasAtmosphere.Haze = intensity * 2
	end

	-- Show damage tick on HUD if in gas
	if damagePerTick > 0 then
		HUD.ShowGasWarning(damagePerTick)
	else
		HUD.HideGasWarning()
	end
end

function ZoneClient.EnableGasEffects(intensity: number)
	if gasAtmosphere then
		TweenService:Create(gasAtmosphere, TweenInfo.new(2), {
			Density = 0.3 + intensity * 0.4,
			Haze = intensity * 2,
		}):Play()
	end

	-- Screen edge effect (purple vignette)
	-- Post-processing would go here
end

function ZoneClient.DisableGasEffects()
	if gasAtmosphere then
		TweenService:Create(gasAtmosphere, TweenInfo.new(1), {
			Density = 0,
			Haze = 0,
		}):Play()
	end
end

function ZoneClient.OnZoneWarning(data)
	local message = data.message or "ZONE WARNING"
	local duration = data.duration or 3
	HUD.ShowNotification(message, duration)

	if warningSound then
		warningSound:Play()
	end
end

function ZoneClient.GetZoneData()
	return zoneData
end

function ZoneClient.IsInGas(position: Vector3): boolean
	if not zoneData then return false end
	return (position - zoneData.Center).Magnitude > zoneData.CurrentRadius
end

function ZoneClient.Cleanup()
	if zoneVisual then zoneVisual:Destroy() end
	if nextZoneVisual then nextZoneVisual:Destroy() end
	if gasAtmosphere then gasAtmosphere:Destroy() end
end

return ZoneClient
