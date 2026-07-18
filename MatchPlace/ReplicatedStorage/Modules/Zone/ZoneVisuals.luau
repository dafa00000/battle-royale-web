--[[
	ZoneVisuals - PBR gas wall shader (scrolling texture, neon edges), cylinder mesh, phase transitions
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local ZoneVisuals = {}

export type ZoneVisualConfig = {
	wallHeight: number,
	wallThickness: number,
	scrollSpeed: number,
	edgeGlowIntensity: number,
	phaseTransitionDuration: number,
}

export type ZoneVisualState = {
	center: Vector3,
	radius: number,
	phase: number,
	isTransitioning: boolean,
	transitionStartTime: number,
	targetRadius: number,
	targetCenter: Vector3,
}

-- Configuration
local CONFIG: ZoneVisualConfig = {
	wallHeight = 150,
	wallThickness = 2,
	scrollSpeed = 0.5,
	edgeGlowIntensity = 2,
	phaseTransitionDuration = 2,
}

-- Phase visual settings
local PHASE_SETTINGS = {
	{ color = Color3.fromRGB(0, 150, 255), transparency = 0.6, glow = 0.5 },
	{ color = Color3.fromRGB(50, 200, 100), transparency = 0.55, glow = 0.6 },
	{ color = Color3.fromRGB(255, 220, 0), transparency = 0.5, glow = 0.7 },
	{ color = Color3.fromRGB(255, 160, 0), transparency = 0.45, glow = 0.8 },
	{ color = Color3.fromRGB(255, 100, 0), transparency = 0.4, glow = 0.9 },
	{ color = Color3.fromRGB(255, 50, 50), transparency = 0.35, glow = 1.0 },
}

-- State
local zoneState: ZoneVisualState = {
	center = Vector3.zero,
	radius = Constants.INITIAL_ZONE_RADIUS,
	phase = 0,
	isTransitioning = false,
	transitionStartTime = 0,
	targetRadius = Constants.INITIAL_ZONE_RADIUS,
	targetCenter = Vector3.zero,
}

-- Visual components
local wallParts: { Part } = {}
local edgeParts: { Part } = {}
local textureOffsets: { number } = {}
local isActive = false
local scrollTime = 0

-- Constants
local WALL_SEGMENTS = 24 -- Number of segments to approximate cylinder
local TEXTURE_ID = "rbxassetid://0" -- Scrolling gas texture

function ZoneVisuals.Initialize()
	ZoneVisuals.CreateZoneWall()
	isActive = true

	RunService.Heartbeat:Connect(ZoneVisuals.Update)
	print("[ZoneVisuals] Initialized")
end

function ZoneVisuals.CreateZoneWall()
	-- Clear existing
	ZoneVisuals.ClearWall()

	local segmentAngle = (math.pi * 2) / WALL_SEGMENTS
	local segmentLength = 2 * math.pi * zoneState.radius / WALL_SEGMENTS

	for i = 1, WALL_SEGMENTS do
		local angle = (i - 1) * segmentAngle
		local nextAngle = i * segmentAngle

		-- Calculate segment position
		local x1 = math.cos(angle) * zoneState.radius
		local z1 = math.sin(angle) * zoneState.radius
		local x2 = math.cos(nextAngle) * zoneState.radius
		local z2 = math.sin(nextAngle) * zoneState.radius

		local midX = (x1 + x2) / 2
		local midZ = (z1 + z2) / 2

		-- Create wall segment
		local wall = Instance.new("Part")
		wall.Name = "ZoneWall_" .. i
		wall.Anchored = true
		wall.CanCollide = false
		wall.CanQuery = false
		wall.CanTouch = false
		wall.Transparency = PHASE_SETTINGS[1].transparency
		wall.Material = Enum.Material.ForceField
		wall.Color = PHASE_SETTINGS[1].color

		-- Size and position
		local length = math.sqrt((x2 - x1)^2 + (z2 - z1)^2)
		wall.Size = Vector3.new(CONFIG.wallThickness, CONFIG.wallHeight, length)
		wall.CFrame = CFrame.new(zoneState.center + Vector3.new(midX, CONFIG.wallHeight / 2, midX))
			* CFrame.Angles(0, math.atan2(x2 - x1, z2 - z1), 0)

		wall.Parent = Workspace

		-- Add scrolling texture
		local texture = Instance.new("Texture")
		texture.Texture = TEXTURE_ID
		texture.StudsPerTileU = 4
		texture.StudsPerTileV = CONFIG.wallHeight / 4
		texture.Face = Enum.NormalId.Left
		texture.Parent = wall

		local texture2 = texture:Clone()
		texture2.Face = Enum.NormalId.Right
		texture2.Parent = wall

		table.insert(wallParts, wall)
		table.insert(textureOffsets, 0)

		-- Create edge glow (top and bottom)
		local topEdge = Instance.new("Part")
		topEdge.Name = "ZoneEdgeTop_" .. i
		topEdge.Anchored = true
		topEdge.CanCollide = false
		topEdge.CanQuery = false
		topEdge.CanTouch = false
		topEdge.Transparency = 0.3
		topEdge.Material = Enum.Material.Neon
		topEdge.Color = PHASE_SETTINGS[1].color
		topEdge.Size = Vector3.new(CONFIG.wallThickness * 1.5, 1, length)
		topEdge.CFrame = wall.CFrame * CFrame.new(0, CONFIG.wallHeight / 2, 0)
		topEdge.Parent = Workspace

		local bottomEdge = topEdge:Clone()
		bottomEdge.Name = "ZoneEdgeBottom_" .. i
		bottomEdge.CFrame = wall.CFrame * CFrame.new(0, -CONFIG.wallHeight / 2, 0)
		bottomEdge.Parent = Workspace

		table.insert(edgeParts, topEdge)
		table.insert(edgeParts, bottomEdge)
	end
end

function ZoneVisuals.UpdateZone(center: Vector3, radius: number, phase: number, instant: boolean?)
	local phaseIndex = math.clamp(phase + 1, 1, #PHASE_SETTINGS)
	local settings = PHASE_SETTINGS[phaseIndex]

	if instant then
		zoneState.center = center
		zoneState.radius = radius
		zoneState.phase = phase
		zoneState.targetCenter = center
		zoneState.targetRadius = radius
		zoneState.isTransitioning = false

		ZoneVisuals.RebuildWall()
	else
		zoneState.targetCenter = center
		zoneState.targetRadius = radius
		zoneState.isTransitioning = true
		zoneState.transitionStartTime = os.clock()
	end

	-- Update colors
	for _, wall in ipairs(wallParts) do
		wall.Color = settings.color
		wall.Transparency = settings.transparency
	end

	for _, edge in ipairs(edgeParts) do
		edge.Color = settings.color
		edge.Transparency = 0.3 * (1 - settings.glow * 0.3)
	end
end

function ZoneVisuals.RebuildWall()
	-- Update existing segments or rebuild if radius changed significantly
	local segmentAngle = (math.pi * 2) / WALL_SEGMENTS

	for i = 1, WALL_SEGMENTS do
		local wall = wallParts[i]
		if not wall then continue end

		local angle = (i - 1) * segmentAngle
		local nextAngle = i * segmentAngle

		local x1 = math.cos(angle) * zoneState.radius
		local z1 = math.sin(angle) * zoneState.radius
		local x2 = math.cos(nextAngle) * zoneState.radius
		local z2 = math.sin(nextAngle) * zoneState.radius

		local midX = (x1 + x2) / 2
		local midZ = (z1 + z2) / 2

		local length = math.sqrt((x2 - x1)^2 + (z2 - z1)^2)
		wall.Size = Vector3.new(CONFIG.wallThickness, CONFIG.wallHeight, length)
		wall.CFrame = CFrame.new(zoneState.center + Vector3.new(midX, CONFIG.wallHeight / 2, midZ))
			* CFrame.Angles(0, math.atan2(x2 - x1, z2 - z1), 0)

		-- Update edges
		local topEdge = edgeParts[(i - 1) * 2 + 1]
		local bottomEdge = edgeParts[(i - 1) * 2 + 2]
		if topEdge then
			topEdge.Size = Vector3.new(CONFIG.wallThickness * 1.5, 1, length)
			topEdge.CFrame = wall.CFrame * CFrame.new(0, CONFIG.wallHeight / 2, 0)
		end
		if bottomEdge then
			bottomEdge.Size = Vector3.new(CONFIG.wallThickness * 1.5, 1, length)
			bottomEdge.CFrame = wall.CFrame * CFrame.new(0, -CONFIG.wallHeight / 2, 0)
		end
	end
end

function ZoneVisuals.Update(deltaTime: number)
	if not isActive then return end

	-- Handle phase transitions
	if zoneState.isTransitioning then
		local elapsed = os.clock() - zoneState.transitionStartTime
		local alpha = math.clamp(elapsed / CONFIG.phaseTransitionDuration, 0, 1)

		-- Smooth easing
		alpha = 1 - (1 - alpha) ^ 3

		zoneState.center = zoneState.center:Lerp(zoneState.targetCenter, alpha)
		zoneState.radius = Util.Lerp(zoneState.radius, zoneState.targetRadius, alpha)

		ZoneVisuals.RebuildWall()

		if alpha >= 1 then
			zoneState.isTransitioning = false
		end
	end

	-- Animate scrolling texture
	scrollTime += deltaTime * CONFIG.scrollSpeed
	for i, wall in ipairs(wallParts) do
		textureOffsets[i] = (textureOffsets[i] + deltaTime * CONFIG.scrollSpeed) % 1

		for _, child in ipairs(wall:GetChildren()) do
			if child:IsA("Texture") then
				child.OffsetStudsV = textureOffsets[i] * child.StudsPerTileV
			end
		end
	end

	-- Pulse edge glow
	local phaseIndex = math.clamp(zoneState.phase + 1, 1, #PHASE_SETTINGS)
	local settings = PHASE_SETTINGS[phaseIndex]
	local pulse = math.sin(scrollTime * 3) * 0.2 + 0.8

	for _, edge in ipairs(edgeParts) do
		edge.Transparency = (0.3 * (1 - settings.glow * 0.3)) * pulse
	end
end

function ZoneVisuals.SetActive(active: boolean)
	isActive = active
	for _, wall in ipairs(wallParts) do
		wall.Transparency = active and PHASE_SETTINGS[zoneState.phase + 1].transparency or 1
	end
	for _, edge in ipairs(edgeParts) do
		edge.Transparency = active and 0.3 or 1
	end
end

function ZoneVisuals.GetState(): ZoneVisualState
	return zoneState
end

function ZoneVisuals.ClearWall()
	for _, wall in ipairs(wallParts) do
		wall:Destroy()
	end
	for _, edge in ipairs(edgeParts) do
		edge:Destroy()
	end
	wallParts = {}
	edgeParts = {}
	textureOffsets = {}
end

function ZoneVisuals.Cleanup()
	ZoneVisuals.ClearWall()
	isActive = false
end

return ZoneVisuals
