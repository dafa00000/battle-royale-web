--[[
	Minimap - GTA V style minimap
	Player arrow, zone circle, squad markers, vehicle icons, compass
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local MatchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes")

local Minimap = {}

-- State
local localPlayer = Players.LocalPlayer
local screenGui = nil
local mapFrame = nil
local playerArrow = nil
local zoneCircle = nil
local zoneWarningCircle = nil
local compassRing = nil
local markers = {} -- squad, vehicles, loot, etc.

local T = Constants.UI_THEME

-- Config
local MAP_SIZE = 5000 -- studs (map radius)
local MINIMAP_SIZE = 200 -- pixels
local ZOOM = 1.0

-- ==================== UI CREATION ====================

local function Create(className, props, children)
	return Util.Create(className, props, children)
end

local function CreateCorner(radius)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Minimap.Initialize()
	-- Create ScreenGui
	screenGui = Create("ScreenGui", {
		Name = "MinimapGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
	
	-- Main map container (bottom right)
	mapFrame = Create("Frame", {
		Name = "MinimapFrame",
		Size = UDim2.new(0, MINIMAP_SIZE, 0, MINIMAP_SIZE),
		Position = UDim2.new(1, -MINIMAP_SIZE - 20, 1, -MINIMAP_SIZE - 20),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, { CreateCorner(12), Create("UIStroke", { Color = T.Border, Thickness = 2 }) })
	mapFrame.Parent = screenGui
	
	-- Compass ring (top of minimap)
	compassRing = Create("Frame", {
		Name = "Compass",
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
	})
	compassRing.Parent = mapFrame
	
	local compassLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	compassLayout.Parent = compassRing
	
	-- Compass directions
	for _, dir in ipairs({"N", "NE", "E", "SE", "S", "SW", "W", "NW"}) do
		local label = Create("TextLabel", {
			Name = dir,
			Size = UDim2.new(0, 30, 1, 0),
			BackgroundTransparency = 1,
			Text = dir,
			TextColor3 = T.TextMuted,
			TextSize = 9,
			Font = Enum.Font.GothamMedium,
		})
		label.Parent = compassRing
	end
	
	-- Zone circle (safe zone)
	zoneCircle = Create("Frame", {
		Name = "ZoneCircle",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	zoneCircle.Parent = mapFrame
	
	local zoneStroke = Create("UIStroke", {
		Color = T.Success,
		Thickness = 2,
		Transparency = 0.3,
	})
	zoneStroke.Parent = zoneCircle
	CreateCorner(100).Parent = zoneCircle -- Circle via large corner radius
	
	-- Zone warning circle (next zone)
	zoneWarningCircle = Create("Frame", {
		Name = "ZoneWarningCircle",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	})
	zoneWarningCircle.Parent = mapFrame
	
	local warningStroke = Create("UIStroke", {
		Color = T.Danger,
		Thickness = 1.5,
		Transparency = 0.5,
	})
	warningStroke.Parent = zoneWarningCircle
	CreateCorner(100).Parent = zoneWarningCircle
	
	-- Player arrow (center)
	playerArrow = Create("ImageLabel", {
		Name = "PlayerArrow",
		Size = UDim2.new(0, 20, 0, 20),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = "rbxassetid://1234567890", -- arrow icon
		ImageColor3 = T.Primary,
		Rotation = 0,
		ZIndex = 10,
	})
	playerArrow.Parent = mapFrame
	
	-- Legend (bottom left of minimap)
	Minimap.CreateLegend()
	
	-- Connect remotes
	Minimap.ConnectRemotes()
	
	-- Start update loop
	RunService.RenderStepped:Connect(Minimap.Update)
	
	print("[Minimap] Initialized")
end

function Minimap.CreateLegend()
	local legend = Create("Frame", {
		Name = "Legend",
		Size = UDim2.new(0, 120, 0, 80),
		Position = UDim2.new(0, 5, 1, -85),
		BackgroundColor3 = T.Surface,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, { CreateCorner(6), Create("UIStroke", { Color = T.Border, Thickness = 1 }) })
	legend.Parent = mapFrame
	
	local layout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 4),
	})
	layout.Parent = legend
	Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 4) }).Parent = legend
	
	local items = {
		{ text = "▲ You", color = T.Primary },
		{ text = "● Squad", color = T.Success },
		{ text = "■ Vehicle", color = T.Secondary },
		{ text = "⬤ Loot", color = T.Secondary },
		{ text = "◯ Zone", color = T.Success },
	}
	
	for _, item in ipairs(items) do
		local label = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Text = item.text,
			TextColor3 = item.color,
			TextSize = 10,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		label.Parent = legend
	end
end

-- ==================== REMOTES ====================

function Minimap.ConnectRemotes()
	-- Zone updates
	MatchRemotes.ZoneUpdate.OnClientEvent:Connect(function(data)
		Minimap.UpdateZone(data)
	end)
	
	-- Squad updates
	MatchRemotes.SquadUpdate.OnClientEvent:Connect(function(data)
		Minimap.UpdateSquadMarkers(data)
	end)
	
	-- Vehicle updates
	MatchRemotes.VehicleUpdate.OnClientEvent:Connect(function(data)
		Minimap.UpdateVehicleMarkers(data)
	end)
	
	-- Loot updates
	MatchRemotes.GroundLootUpdate.OnClientEvent:Connect(function(data)
		Minimap.UpdateLootMarkers(data)
	end)
end

-- ==================== UPDATE FUNCTIONS ====================

function Minimap.UpdateZone(data)
	if not data then return end
	
	local center = data.Center
	local radius = data.CurrentRadius
	local nextCenter = data.NextCenter
	local nextRadius = data.TargetRadius
	local isShrinking = data.IsShrinking
	
	-- Convert world position to minimap position
	local playerPos = Minimap.GetPlayerPosition()
	if not playerPos then return end
	
	-- Current zone
	local zonePos = Minimap.WorldToMinimap(center, playerPos)
	zoneCircle.Position = UDim2.new(0.5, zonePos.X, 0.5, zonePos.Y)
	
	local zoneScale = (radius / MAP_SIZE) * 2 * ZOOM
	zoneCircle.Size = UDim2.new(zoneScale, 0, zoneScale, 0)
	
	-- Next zone warning
	if nextCenter and nextRadius and isShrinking then
		zoneWarningCircle.Visible = true
		local nextPos = Minimap.WorldToMinimap(nextCenter, playerPos)
		zoneWarningCircle.Position = UDim2.new(0.5, nextPos.X, 0.5, nextPos.Y)
		local nextScale = (nextRadius / MAP_SIZE) * 2 * ZOOM
		zoneWarningCircle.Size = UDim2.new(nextScale, 0, nextScale, 0)
	else
		zoneWarningCircle.Visible = false
	end
end

function Minimap.UpdateSquadMarkers(squadData)
	-- Clear old squad markers
	for _, marker in pairs(markers.Squad or {}) do
		marker:Destroy()
	end
	markers.Squad = {}
	
	if not squadData or not squadData.Members then return end
	
	local playerPos = Minimap.GetPlayerPosition()
	if not playerPos then return end
	
	for userId, member in pairs(squadData.Members) do
		if userId == localPlayer.UserId then continue end
		if not member.Character then continue end
		
		local charPos = member.Character:GetPivot().Position
		local mapPos = Minimap.WorldToMinimap(charPos, playerPos)
		
		local marker = Create("Frame", {
			Name = "Squad_" .. userId,
			Size = UDim2.new(0, 10, 0, 10),
			Position = UDim2.new(0.5, mapPos.X, 0.5, mapPos.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = T.Success,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, { CreateCorner(5) })
		marker.Parent = mapFrame
		
		table.insert(markers.Squad, marker)
	end
end

function Minimap.UpdateVehicleMarkers(vehicleData)
	-- Similar to squad markers but with vehicle icon
end

function Minimap.UpdateLootMarkers(lootData)
	-- Show nearby high-tier loot
end

-- ==================== HELPERS ====================

function Minimap.GetPlayerPosition()
	local character = localPlayer.Character
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	return hrp.Position
end

function Minimap.WorldToMinimap(worldPos, playerPos)
	local diff = worldPos - playerPos
	local scale = (MINIMAP_SIZE / 2) / (MAP_SIZE * ZOOM)
	return Vector2.new(diff.X * scale, -diff.Z * scale) -- Z is forward, Y is up
end

function Minimap.GetPlayerRotation()
	local character = localPlayer.Character
	if not character then return 0 end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return 0 end
	return math.deg(math.atan2(-hrp.CFrame.LookVector.X, -hrp.CFrame.LookVector.Z))
end

-- ==================== MAIN UPDATE LOOP ====================

function Minimap.Update(deltaTime)
	-- Update player arrow rotation
	local rotation = Minimap.GetPlayerRotation()
	playerArrow.Rotation = rotation
	
	-- Rotate compass
	compassRing.Rotation = -rotation
	
	-- Update zone circle position (moves opposite to player)
	-- Actually zoneCircle stays fixed on map, playerArrow moves
	-- But we keep zone centered, player moves
	-- Revisit: GTA style has map rotate, player fixed. 
	-- Current: player fixed, map rotates. Let's keep simple.
end

print("[Minimap] Module loaded")
return Minimap