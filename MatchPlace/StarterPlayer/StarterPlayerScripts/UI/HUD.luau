--[[
	HUD - GTA V style minimal HUD with smartwatch integration
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local HUD = {}

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Main HUD GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

-- ==================== HEALTH/ARMOR (Bottom Left - Smartwatch) ====================

local smartwatch = Instance.new("Frame")
smartwatch.Name = "Smartwatch"
smartwatch.Size = UDim2.fromOffset(200, 200)
smartwatch.Position = UDim2.new(0, 20, 1, -220)
smartwatch.BackgroundTransparency = 1
smartwatch.Parent = screenGui

-- Watch face
local watchFace = Instance.new("Frame")
watchFace.Name = "Face"
watchFace.Size = UDim2.fromScale(1, 1)
watchFace.BackgroundColor3 = Constants.UI_THEME.Surface
watchFace.BackgroundTransparency = 0.2
watchFace.BorderSizePixel = 0
watchFace.Parent = smartwatch

local faceCorner = Instance.new("UICorner")
faceCorner.CornerRadius = UDim.new(0.5, 0)
faceCorner.Parent = watchFace

local faceStroke = Instance.new("UIStroke")
faceStroke.Color = Constants.UI_THEME.Border
faceStroke.Thickness = 1
faceStroke.Transparency = 0.5
faceStroke.Parent = watchFace

-- Health ring
local healthRing = Instance.new("Frame")
healthRing.Name = "HealthRing"
healthRing.Size = UDim2.fromScale(0.85, 0.85)
healthRing.Position = UDim2.fromScale(0.075, 0.075)
healthRing.BackgroundTransparency = 1
healthRing.Parent = watchFace

local healthCircle = Instance.new("ImageLabel")
healthCircle.Name = "Circle"
healthCircle.Size = UDim2.fromScale(1, 1)
healthCircle.BackgroundTransparency = 1
healthCircle.Image = "rbxassetid://13521458460" -- Ring image
healthCircle.ImageColor3 = Constants.UI_THEME.Success
healthCircle.ImageTransparency = 0
healthCircle.Parent = healthRing

-- Health text
local healthText = Instance.new("TextLabel")
healthText.Name = "HealthText"
healthText.Size = UDim2.fromScale(0.6, 0.3)
healthText.Position = UDim2.fromScale(0.2, 0.35)
healthText.BackgroundTransparency = 1
healthText.Text = "100"
healthText.TextColor3 = Constants.UI_THEME.Text
healthText.TextScaled = true
healthText.Font = Enum.Font.GothamBold
healthText.Parent = healthRing

local healthLabel = Instance.new("TextLabel")
healthLabel.Name = "HealthLabel"
healthLabel.Size = UDim2.fromScale(0.6, 0.15)
healthLabel.Position = UDim2.fromScale(0.2, 0.62)
healthLabel.BackgroundTransparency = 1
healthLabel.Text = "HP"
healthLabel.TextColor3 = Constants.UI_THEME.TextMuted
healthLabel.TextScaled = true
healthLabel.Font = Enum.Font.Gotham
healthLabel.Parent = healthRing

-- Armor ring (smaller, inside health)
local armorRing = Instance.new("Frame")
armorRing.Name = "ArmorRing"
armorRing.Size = UDim2.fromScale(0.55, 0.55)
armorRing.Position = UDim2.fromScale(0.225, 0.225)
armorRing.BackgroundTransparency = 1
armorRing.Parent = watchFace

local armorCircle = Instance.new("ImageLabel")
armorCircle.Name = "Circle"
armorCircle.Size = UDim2.fromScale(1, 1)
armorCircle.BackgroundTransparency = 1
armorCircle.Image = "rbxassetid://13521458460"
armorCircle.ImageColor3 = Constants.UI_THEME.Primary
armorCircle.ImageTransparency = 0
armorCircle.Parent = armorRing

local armorText = Instance.new("TextLabel")
armorText.Name = "ArmorText"
armorText.Size = UDim2.fromScale(0.6, 0.3)
armorText.Position = UDim2.fromScale(0.2, 0.35)
armorText.BackgroundTransparency = 1
armorText.Text = "0"
armorText.TextColor3 = Constants.UI_THEME.Primary
armorText.TextScaled = true
armorText.Font = Enum.Font.GothamBold
armorText.Parent = armorRing

local armorLabel = Instance.new("TextLabel")
armorLabel.Name = "ArmorLabel"
armorLabel.Size = UDim2.fromScale(0.6, 0.15)
armorLabel.Position = UDim2.fromScale(0.2, 0.62)
armorLabel.BackgroundTransparency = 1
armorLabel.Text = "AR"
armorLabel.TextColor3 = Constants.UI_THEME.TextMuted
armorLabel.TextScaled = true
armorLabel.Font = Enum.Font.Gotham
armorLabel.Parent = armorRing

-- Boost meter (thin ring around outside)
local boostRing = Instance.new("Frame")
boostRing.Name = "BoostRing"
boostRing.Size = UDim2.fromScale(1, 1)
boostRing.BackgroundTransparency = 1
boostRing.Parent = watchFace

local boostCircle = Instance.new("ImageLabel")
boostCircle.Name = "Circle"
boostCircle.Size = UDim2.fromScale(1, 1)
boostCircle.BackgroundTransparency = 1
boostCircle.Image = "rbxassetid://13521458460"
boostCircle.ImageColor3 = Constants.UI_THEME.Secondary
boostCircle.ImageTransparency = 0.5
boostCircle.Parent = boostRing

-- ==================== AMMO/WEAPON (Bottom Right) ====================

local ammoPanel = Instance.new("Frame")
ammoPanel.Name = "AmmoPanel"
ammoPanel.Size = UDim2.fromOffset(250, 80)
ammoPanel.Position = UDim2.new(1, -270, 1, -100)
ammoPanel.BackgroundTransparency = 1
ammoPanel.Parent = screenGui
ammoPanel.Visible = false

local weaponName = Instance.new("TextLabel")
weaponName.Name = "WeaponName"
weaponName.Size = UDim2.new(1, 0, 0.3, 0)
weaponName.BackgroundTransparency = 1
weaponName.Text = "AK-74"
weaponName.TextColor3 = Constants.UI_THEME.Text
weaponName.TextScaled = true
weaponName.Font = Enum.Font.GothamBold
weaponName.TextXAlignment = Enum.TextXAlignment.Right
weaponName.Parent = ammoPanel

local ammoCount = Instance.new("TextLabel")
ammoCount.Name = "AmmoCount"
ammoCount.Size = UDim2.new(0.6, 0, 0.5, 0)
ammoCount.Position = UDim2.fromScale(0, 0.3)
ammoCount.BackgroundTransparency = 1
ammoCount.Text = "30"
ammoCount.TextColor3 = Constants.UI_THEME.Text
ammoCount.TextScaled = true
ammoCount.Font = Enum.Font.GothamBold
ammoCount.TextXAlignment = Enum.TextXAlignment.Right
ammoCount.Parent = ammoPanel

local reserveAmmo = Instance.new("TextLabel")
reserveAmmo.Name = "ReserveAmmo"
reserveAmmo.Size = UDim2.new(0.4, 0, 0.5, 0)
reserveAmmo.Position = UDim2.fromScale(0.6, 0.3)
reserveAmmo.BackgroundTransparency = 1
reserveAmmo.Text = "/ 120"
reserveAmmo.TextColor3 = Constants.UI_THEME.TextMuted
reserveAmmo.TextScaled = true
reserveAmmo.Font = Enum.Font.Gotham
reserveAmmo.TextXAlignment = Enum.TextXAlignment.Left
reserveAmmo.Parent = ammoPanel

local fireMode = Instance.new("TextLabel")
fireMode.Name = "FireMode"
fireMode.Size = UDim2.fromOffset(60, 20)
fireMode.Position = UDim2.new(1, -60, 0, 0)
fireMode.BackgroundColor3 = Constants.UI_THEME.Primary
fireMode.BackgroundTransparency = 0.2
fireMode.Text = "AUTO"
fireMode.TextColor3 = Constants.UI_THEME.Text
fireMode.TextScaled = true
fireMode.Font = Enum.Font.GothamBold
fireMode.Parent = ammoPanel

local modeCorner = Instance.new("UICorner")
modeCorner.CornerRadius = UDim.new(0, 4)
modeCorner.Parent = fireMode

-- ==================== MINIMAP (Top Right) ====================

local minimap = Instance.new("Frame")
minimap.Name = "Minimap"
minimap.Size = UDim2.fromOffset(200, 200)
minimap.Position = UDim2.new(1, -220, 0, 20)
minimap.BackgroundColor3 = Constants.UI_THEME.Surface
minimap.BackgroundTransparency = 0.3
minimap.BorderSizePixel = 0
minimap.ClipsDescendants = true
minimap.Parent = screenGui

local mapCorner = Instance.new("UICorner")
mapCorner.CornerRadius = UDim.new(0, 8)
mapCorner.Parent = minimap

local mapStroke = Instance.new("UIStroke")
mapStroke.Color = Constants.UI_THEME.Border
mapStroke.Thickness = 1
mapStroke.Transparency = 0.5
mapStroke.Parent = minimap

-- Map viewport
local mapViewport = Instance.new("ViewportFrame")
mapViewport.Name = "Viewport"
mapViewport.Size = UDim2.fromScale(1, 1)
mapViewport.BackgroundTransparency = 1
mapViewport.Parent = minimap

local mapCamera = Instance.new("Camera")
mapCamera.Parent = mapViewport
mapViewport.CurrentCamera = mapCamera

-- Zone indicator on minimap
local zoneCircle = Instance.new("Frame")
zoneCircle.Name = "ZoneCircle"
zoneCircle.Size = UDim2.fromScale(1, 1)
zoneCircle.BackgroundTransparency = 1
zoneCircle.Parent = minimap

local zoneRing = Instance.new("ImageLabel")
zoneRing.Name = "ZoneRing"
zoneRing.Size = UDim2.fromScale(1, 1)
zoneRing.BackgroundTransparency = 1
zoneRing.Image = "rbxassetid://13521458460"
zoneRing.ImageColor3 = Constants.UI_THEME.Primary
zoneRing.ImageTransparency = 0.3
zoneRing.Parent = zoneCircle

local nextZoneRing = Instance.new("ImageLabel")
nextZoneRing.Name = "NextZoneRing"
nextZoneRing.Size = UDim2.fromScale(0.7, 0.7)
nextZoneRing.Position = UDim2.fromScale(0.15, 0.15)
nextZoneRing.BackgroundTransparency = 1
nextZoneRing.Image = "rbxassetid://13521458460"
nextZoneRing.ImageColor3 = Constants.UI_THEME.Secondary
nextZoneRing.ImageTransparency = 0.5
nextZoneRing.Parent = zoneCircle

-- Player marker
local playerMarker = Instance.new("Frame")
playerMarker.Name = "PlayerMarker"
playerMarker.Size = UDim2.fromOffset(8, 8)
playerMarker.AnchorPoint = Vector2.new(0.5, 0.5)
playerMarker.BackgroundColor3 = Constants.UI_THEME.Text
playerMarker.BorderSizePixel = 0
playerMarker.Parent = minimap

local markerCorner = Instance.new("UICorner")
markerCorner.CornerRadius = UDim.new(0.5, 0)
markerCorner.Parent = playerMarker

-- Compass
local compass = Instance.new("Frame")
compass.Name = "Compass"
compass.Size = UDim2.new(1, 0, 0.15, 0)
compass.Position = UDim2.fromScale(0, 1)
compass.BackgroundTransparency = 1
compass.Parent = minimap

local compassText = Instance.new("TextLabel")
compassText.Name = "Direction"
compassText.Size = UDim2.new(0.3, 0, 1, 0)
compassText.Position = UDim2.fromScale(0.35, 0)
compassText.BackgroundTransparency = 1
compassText.Text = "N"
compassText.TextColor3 = Constants.UI_THEME.Primary
compassText.TextScaled = true
compassText.Font = Enum.Font.GothamBold
compassText.Parent = compass

-- ==================== KILL FEED (Top Right, below minimap) ====================

local killFeed = Instance.new("Frame")
killFeed.Name = "KillFeed"
killFeed.Size = UDim2.fromOffset(350, 300)
killFeed.Position = UDim2.new(1, -370, 0, 240)
killFeed.BackgroundTransparency = 1
killFeed.Parent = screenGui

local killFeedLayout = Instance.new("UIListLayout")
killFeedLayout.SortOrder = Enum.SortOrder.LayoutOrder
killFeedLayout.VerticalAlignment = Enum.VerticalAlignment.Top
killFeedLayout.Padding = UDim.new(0, 4)
killFeedLayout.Parent = killFeed

-- ==================== MATCH INFO (Top Center) ====================

local matchInfo = Instance.new("Frame")
matchInfo.Name = "MatchInfo"
matchInfo.Size = UDim2.fromOffset(400, 50)
matchInfo.Position = UDim2.new(0.5, -200, 0, 20)
matchInfo.BackgroundTransparency = 1
matchInfo.Parent = screenGui

local aliveCount = Instance.new("TextLabel")
aliveCount.Name = "AliveCount"
aliveCount.Size = UDim2.fromScale(0.5, 1)
aliveCount.BackgroundTransparency = 1
aliveCount.Text = "100 ALIVE"
aliveCount.TextColor3 = Constants.UI_THEME.Text
aliveCount.TextScaled = true
aliveCount.Font = Enum.Font.GothamBold
aliveCount.Parent = matchInfo

local zoneTimer = Instance.new("TextLabel")
zoneTimer.Name = "ZoneTimer"
zoneTimer.Size = UDim2.fromScale(0.5, 1)
zoneTimer.Position = UDim2.fromScale(0.5, 0)
zoneTimer.BackgroundTransparency = 1
zoneTimer.Text = "ZONE: 2:30"
zoneTimer.TextColor3 = Constants.UI_THEME.Primary
zoneTimer.TextScaled = true
zoneTimer.Font = Enum.Font.GothamBold
zoneTimer.TextXAlignment = Enum.TextXAlignment.Right
zoneTimer.Parent = matchInfo

-- ==================== CROSSHAIR ====================

local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.Size = UDim2.fromOffset(40, 40)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.BackgroundTransparency = 1
crosshair.Parent = screenGui
crosshair.Visible = false

local crosshairParts = {}
for i = 1, 4 do
	local part = Instance.new("Frame")
	part.Name = "Part" .. i
	part.BackgroundColor3 = Constants.UI_THEME.Text
	part.BorderSizePixel = 0
	part.Parent = crosshair
	table.insert(crosshairParts, part)
end

-- Top
crosshairParts[1].Size = UDim2.fromOffset(2, 10)
crosshairParts[1].Position = UDim2.fromScale(0.5, 0)
crosshairParts[1].AnchorPoint = Vector2.new(0.5, 1)
crosshairParts[1].Position = UDim2.fromScale(0.5, 0.35)

-- Bottom
crosshairParts[2].Size = UDim2.fromOffset(2, 10)
crosshairParts[2].AnchorPoint = Vector2.new(0.5, 0)
crosshairParts[2].Position = UDim2.fromScale(0.5, 0.65)

-- Left
crosshairParts[3].Size = UDim2.fromOffset(10, 2)
crosshairParts[3].AnchorPoint = Vector2.new(1, 0.5)
crosshairParts[3].Position = UDim2.fromScale(0.35, 0.5)

-- Right
crosshairParts[4].Size = UDim2.fromOffset(10, 2)
crosshairParts[4].AnchorPoint = Vector2.new(0, 0.5)
crosshairParts[4].Position = UDim2.fromScale(0.65, 0.5)

-- Crosshair gap (center dot removed for tactical style)
local gap = Instance.new("Frame")
gap.Name = "Gap"
gap.Size = UDim2.fromOffset(8, 8)
gap.Position = UDim2.fromScale(0.5, 0.5)
gap.AnchorPoint = Vector2.new(0.5, 0.5)
gap.BackgroundTransparency = 1
gap.Parent = crosshair

-- ==================== STATE ====================

local currentHealth = 100
local currentArmor = 0
local currentBoost = 0
local currentAmmo = 0
local currentReserve = 0
local currentWeapon = ""
local currentFireMode = "AUTO"
local isADS = false

function HUD.UpdateHealth(health: number, maxHealth: number)
	currentHealth = health
	local pct = health / maxHealth
	
	healthText.Text = tostring(math.floor(health))
	healthCircle.ImageColor3 = pct > 0.5 and Constants.UI_THEME.Success or 
		pct > 0.25 and Constants.UI_THEME.Secondary or Constants.UI_THEME.Danger
	
	-- Animate ring fill (using ImageRectOffset for ring)
	-- This would use a custom ring shader or segmented frames
end

function HUD.UpdateArmor(armor: number, maxArmor: number)
	currentArmor = armor
	armorText.Text = tostring(math.floor(armor))
	armorRing.Visible = armor > 0
end

function HUD.UpdateBoost(boost: number, maxBoost: number)
	currentBoost = boost
	boostCircle.ImageTransparency = boost > 0 and 0.2 or 0.8
	-- Update ring fill based on boost/maxBoost
end

function HUD.UpdateAmmo(ammo: number, reserve: number)
	currentAmmo = ammo
	currentReserve = reserve
	ammoCount.Text = tostring(ammo)
	reserveAmmo.Text = "/ " .. tostring(reserve)
	
	-- Low ammo warning
	if ammo > 0 and ammo <= 5 then
		ammoCount.TextColor3 = Constants.UI_THEME.Danger
	else
		ammoCount.TextColor3 = Constants.UI_THEME.Text
	end
end

function HUD.UpdateWeapon(name: string, fireMode: string)
	currentWeapon = name
	currentFireMode = fireMode
	weaponName.Text = name
	fireMode.Text = fireMode
end

function HUD.SetWeaponVisible(visible: boolean)
	ammoPanel.Visible = visible
	crosshair.Visible = visible
end

function HUD.UpdateAliveCount(count: number)
	aliveCount.Text = count .. " ALIVE"
end

function HUD.UpdateZoneTimer(timeRemaining: number, phase: number)
	local mins = math.floor(timeRemaining / 60)
	local secs = math.floor(timeRemaining % 60)
	zoneTimer.Text = string.format("ZONE %d: %d:%02d", phase, mins, secs)
end

function HUD.UpdateMinimap(playerPos: Vector3, zoneCenter: Vector3, zoneRadius: number, nextZoneCenter: Vector3?, nextZoneRadius: number?)
	-- Update player marker position
	local mapSize = Constants.MAP_RADIUS * 2
	local mapScale = 200 / mapSize -- minimap is 200px
	
	local localPos = (playerPos - zoneCenter) * mapScale
	playerMarker.Position = UDim2.fromOffset(100 + localPos.X, 100 - localPos.Z)
	
	-- Update zone circle
	local zoneScale = (zoneRadius / mapSize) * 200
	zoneRing.Size = UDim2.fromOffset(zoneScale, zoneScale)
	zoneRing.Position = UDim2.fromOffset(100 - zoneScale/2, 100 - zoneScale/2)
	
	if nextZoneCenter and nextZoneRadius then
		local nextScale = (nextZoneRadius / mapSize) * 200
		nextZoneRing.Size = UDim2.fromOffset(nextScale, nextScale)
		local nextLocal = (nextZoneCenter - zoneCenter) * mapScale
		nextZoneRing.Position = UDim2.fromOffset(100 + nextLocal.X - nextScale/2, 100 - nextLocal.Z - nextScale/2)
		nextZoneRing.Visible = true
	else
		nextZoneRing.Visible = false
	end
end

function HUD.UpdateCompass(yaw: number)
	local directions = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
	local index = math.floor((math.deg(yaw) + 22.5) / 45) % 8 + 1
	compassText.Text = directions[index]
end

function HUD.AddKillFeed(killer: string, victim: string, weapon: string, isHeadshot: boolean, distance: number)
	local entry = Instance.new("Frame")
	entry.Size = UDim2.new(1, 0, 0, 28)
	entry.BackgroundTransparency = 1
	entry.Parent = killFeed
	entry.LayoutOrder = -os.clock() -- Newest on top
	
	local killerLabel = Instance.new("TextLabel")
	killerLabel.Size = UDim2.fromScale(0.3, 1)
	killerLabel.BackgroundTransparency = 1
	killerLabel.Text = killer
	killerLabel.TextColor3 = Constants.UI_THEME.Text
	killerLabel.TextScaled = true
	killerLabel.Font = Enum.Font.GothamBold
	killerLabel.TextXAlignment = Enum.TextXAlignment.Right
	killerLabel.Parent = entry
	
	local weaponIcon = Instance.new("ImageLabel")
	weaponIcon.Size = UDim2.fromOffset(24, 24)
	weaponIcon.Position = UDim2.fromScale(0.32, 0.1)
	weaponIcon.BackgroundTransparency = 1
	weaponIcon.Image = "rbxassetid://0" -- Weapon icon
	weaponIcon.Parent = entry
	
	local victimLabel = Instance.new("TextLabel")
	victimLabel.Size = UDim2.fromScale(0.3, 1)
	victimLabel.Position = UDim2.fromScale(0.4, 0)
	victimLabel.BackgroundTransparency = 1
	victimLabel.Text = victim
	victimLabel.TextColor3 = Constants.UI_THEME.Danger
	victimLabel.TextScaled = true
	victimLabel.Font = Enum.Font.Gotham
	victimLabel.TextXAlignment = Enum.TextXAlignment.Left
	victimLabel.Parent = entry
	
	local distLabel = Instance.new("TextLabel")
	distLabel.Size = UDim2.fromScale(0.2, 1)
	distLabel.Position = UDim2.fromScale(0.7, 0)
	distLabel.BackgroundTransparency = 1
	distLabel.Text = math.floor(distance) .. "m"
	distLabel.TextColor3 = Constants.UI_THEME.TextMuted
	distLabel.TextScaled = true
	distLabel.Font = Enum.Font.Gotham
	distLabel.TextXAlignment = Enum.TextXAlignment.Right
	distLabel.Parent = entry
	
	if isHeadshot then
		local hsLabel = Instance.new("TextLabel")
		hsLabel.Size = UDim2.fromOffset(40, 20)
		hsLabel.Position = UDim2.fromScale(1, 0)
		hsLabel.AnchorPoint = Vector2.new(1, 0)
		hsLabel.BackgroundColor3 = Constants.UI_THEME.Danger
		hsLabel.Text = "HEADSHOT"
		hsLabel.TextColor3 = Constants.UI_THEME.Text
		hsLabel.TextScaled = true
		hsLabel.Font = Enum.Font.GothamBold
		hsLabel.Parent = entry
	end
	
	-- Auto remove after 5 seconds
	task.delay(5, function()
		entry:Destroy()
	end)
	
	-- Limit entries
	if #killFeed:GetChildren() > 10 then
		killFeed:GetChildren()[1]:Destroy()
	end
end

function HUD.ShowDamageIndicator(direction: number, damage: number, isHeadshot: boolean)
	-- Create directional damage indicator on screen edge
	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.fromOffset(60, 20)
	indicator.BackgroundColor3 = isHeadshot and Constants.UI_THEME.Danger or Constants.UI_THEME.Secondary
	indicator.BackgroundTransparency = 0.2
	indicator.BorderSizePixel = 0
	indicator.Parent = screenGui
	
	local indCorner = Instance.new("UICorner")
	indCorner.CornerRadius = UDim.new(0, 4)
	indCorner.Parent = indicator
	
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = tostring(math.floor(damage))
	text.TextColor3 = isHeadshot and Constants.UI_THEME.Danger or Constants.UI_THEME.Secondary
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Parent = indicator
	
	-- Position on screen edge based on direction
	local angle = direction
	local dist = 200
	local x = math.sin(angle) * dist
	local y = -math.cos(angle) * dist
	indicator.Position = UDim2.fromScale(0.5, 0.5)
	indicator.AnchorPoint = Vector2.new(0.5, 0.5)
	indicator.Position = UDim2.fromOffset(screenGui.AbsoluteSize.X/2 + x, screenGui.AbsoluteSize.Y/2 + y)
	
	-- Animate
	local tween = TweenService:Create(indicator, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(screenGui.AbsoluteSize.X/2 + x * 1.5, screenGui.AbsoluteSize.Y/2 + y * 1.5),
		BackgroundTransparency = 1,
	})
	tween:Play()
	
	tween.Completed:Wait()
	indicator:Destroy()
end

function HUD.SetCrosshairStyle(style: string)
	-- Update crosshair appearance based on style
	-- "Default", "Dot", "Cross", "T", "Circle"
end

return HUD