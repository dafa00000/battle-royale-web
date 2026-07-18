--[[
	SafeZoneController - Client-side zone visuals: create/update cylinder part, TweenService shrink, color by phase, warning UI
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local SafeZoneController = {}

export type ZoneVisualState = {
	currentCenter: Vector3,
	currentRadius: number,
	targetCenter: Vector3,
	targetRadius: number,
	phase: number,
	isShrinking: boolean,
	phaseEndTime: number,
	nextCenter: Vector3?,
	nextRadius: number?,
}

export type ZoneVisuals = {
	cylinder: Part?,
	innerCylinder: Part?,
	nextZoneCylinder: Part?,
	warningUI: ScreenGui?,
	isActive: boolean,
}

-- Configuration
local CONFIG = {
	zoneHeight = 200,
	cylinderTransparency = 0.7,
	innerTransparency = 0.85,
	warningDuration = 5,
	updateRate = 0.1,
}

-- Phase colors
local PHASE_COLORS = {
	Color3.fromRGB(0, 180, 255),    -- Phase 1: Blue
	Color3.fromRGB(50, 200, 100),   -- Phase 2: Green
	Color3.fromRGB(255, 200, 0),    -- Phase 3: Yellow
	Color3.fromRGB(255, 140, 0),    -- Phase 4: Orange
	Color3.fromRGB(255, 80, 0),     -- Phase 5: Red-Orange
	Color3.fromRGB(220, 50, 50),    -- Phase 6: Red
}

-- State
local zoneState: ZoneVisualState = {
	currentCenter = Vector3.zero,
	currentRadius = Constants.INITIAL_ZONE_RADIUS,
	targetCenter = Vector3.zero,
	targetRadius = Constants.INITIAL_ZONE_RADIUS,
	phase = 0,
	isShrinking = false,
	phaseEndTime = 0,
	nextCenter = nil,
	nextRadius = nil,
}

local visuals: ZoneVisuals = {
	cylinder = nil,
	innerCylinder = nil,
	nextZoneCylinder = nil,
	warningUI = nil,
	isActive = false,
}

local player = Players.LocalPlayer
local activeTween: Tween?

function SafeZoneController.Initialize()
	-- Create zone cylinder
	SafeZoneController.CreateZoneCylinder()

	-- Create warning UI
	SafeZoneController.CreateWarningUI()

	-- Start update loop
	RunService.Heartbeat:Connect(SafeZoneController.Update)

	print("[SafeZoneController] Initialized")
end

function SafeZoneController.CreateZoneCylinder()
	-- Main zone cylinder
	local cylinder = Instance.new("Part")
	cylinder.Name = "SafeZoneCylinder"
	cylinder.Shape = Enum.PartType.Cylinder
	cylinder.Anchored = true
	cylinder.CanCollide = false
	cylinder.CanQuery = false
	cylinder.CanTouch = false
	cylinder.Transparency = CONFIG.cylinderTransparency
	cylinder.Material = Enum.Material.Neon
	cylinder.Color = PHASE_COLORS[1]
	cylinder.Size = Vector3.new(CONFIG.zoneHeight, Constants.INITIAL_ZONE_RADIUS * 2, Constants.INITIAL_ZONE_RADIUS * 2)
	cylinder.CFrame = CFrame.new(Vector3.zero) * CFrame.Angles(0, 0, math.rad(90))
	cylinder.Parent = Workspace

	-- Inner glow cylinder
	local inner = Instance.new("Part")
	inner.Name = "SafeZoneInner"
	inner.Shape = Enum.PartType.Cylinder
	inner.Anchored = true
	inner.CanCollide = false
	inner.CanQuery = false
	inner.CanTouch = false
	inner.Transparency = CONFIG.innerTransparency
	inner.Material = Enum.Material.Neon
	inner.Color = Color3.fromRGB(255, 255, 255)
	inner.Size = Vector3.new(CONFIG.zoneHeight * 0.9, Constants.INITIAL_ZONE_RADIUS * 2 - 5, Constants.INITIAL_ZONE_RADIUS * 2 - 5)
	inner.CFrame = cylinder.CFrame
	inner.Parent = Workspace

	-- Next zone indicator (smaller, semi-transparent)
	local nextZone = Instance.new("Part")
	nextZone.Name = "NextZoneIndicator"
	nextZone.Shape = Enum.PartType.Cylinder
	nextZone.Anchored = true
	nextZone.CanCollide = false
	nextZone.CanQuery = false
	nextZone.CanTouch = false
	nextZone.Transparency = 0.9
	nextZone.Material = Enum.Material.Neon
	nextZone.Color = Color3.fromRGB(255, 255, 255)
	nextZone.Size = Vector3.new(CONFIG.zoneHeight * 0.5, 10, 10)
	nextZone.CFrame = CFrame.new(Vector3.zero)
	nextZone.Parent = Workspace

	visuals.cylinder = cylinder
	visuals.innerCylinder = inner
	visuals.nextZoneCylinder = nextZone
	visuals.isActive = true
end

function SafeZoneController.CreateWarningUI()
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ZoneWarningUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Warning frame
	local frame = Instance.new("Frame")
	frame.Name = "WarningFrame"
	frame.Size = UDim2.new(0, 400, 0, 80)
	frame.Position = UDim2.new(0.5, -200, 0.1, 0)
	frame.BackgroundColor3 = Constants.UI_THEME.Danger
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.white
	stroke.Thickness = 2
	stroke.Parent = frame

	-- Warning text
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "WarningText"
	textLabel.Size = UDim2.new(1, 0, 0.6, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "ZONE SHRINKING"
	textLabel.TextColor3 = Color3.white
	textLabel.TextSize = 24
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = frame

	-- Timer text
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerText"
	timerLabel.Size = UDim2.new(1, 0, 0.4, 0)
	timerLabel.Position = UDim2.new(0, 0, 0.6, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "0:00"
	timerLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
	timerLabel.TextSize = 18
	timerLabel.Font = Enum.Font.Gotham
	timerLabel.Parent = frame

	visuals.warningUI = screenGui
end

function SafeZoneController.UpdateZone(payload: {
	center: Vector3,
	currentRadius: number,
	targetRadius: number,
	phase: number,
	phaseEndTime: number,
	isShrinking: boolean,
	nextCenter: Vector3?,
	nextRadius: number?,
})
	zoneState.currentCenter = payload.center
	zoneState.currentRadius = payload.currentRadius
	zoneState.targetCenter = payload.center
	zoneState.targetRadius = payload.targetRadius
	zoneState.phase = payload.phase
	zoneState.isShrinking = payload.isShrinking
	zoneState.phaseEndTime = payload.phaseEndTime
	zoneState.nextCenter = payload.nextCenter
	zoneState.nextRadius = payload.nextRadius

	-- Update color based on phase
	local colorIndex = math.clamp(payload.phase + 1, 1, #PHASE_COLORS)
	local color = PHASE_COLORS[colorIndex]

	if visuals.cylinder then
		visuals.cylinder.Color = color
	end

	-- Update size and position
	SafeZoneController.UpdateCylinderVisuals()

	-- Show warning if shrinking
	if payload.isShrinking then
		SafeZoneController.ShowWarning()
	else
		SafeZoneController.HideWarning()
	end

	-- Update next zone indicator
	if payload.nextCenter and payload.nextRadius then
		SafeZoneController.UpdateNextZoneIndicator(payload.nextCenter, payload.nextRadius)
	end
end

function SafeZoneController.UpdateCylinderVisuals()
	if not visuals.cylinder or not visuals.innerCylinder then return end

	-- Cancel existing tween
	if activeTween then
		activeTween:Cancel()
	end

	-- Create tween for smooth transition
	local tweenInfo = TweenInfo.new(
		0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local targetSize = Vector3.new(CONFIG.zoneHeight, zoneState.currentRadius * 2, zoneState.currentRadius * 2)
	local targetCFrame = CFrame.new(zoneState.currentCenter) * CFrame.Angles(0, 0, math.rad(90))

	local goals = {
		Size = targetSize,
		CFrame = targetCFrame,
	}

	activeTween = TweenService:Create(visuals.cylinder, tweenInfo, goals)
	activeTween:Play()

	-- Update inner cylinder
	visuals.innerCylinder.Size = Vector3.new(CONFIG.zoneHeight * 0.9, zoneState.currentRadius * 2 - 5, zoneState.currentRadius * 2 - 5)
	visuals.innerCylinder.CFrame = targetCFrame
end

function SafeZoneController.UpdateNextZoneIndicator(center: Vector3, radius: number)
	if not visuals.nextZoneCylinder then return end

	visuals.nextZoneCylinder.Size = Vector3.new(CONFIG.zoneHeight * 0.5, radius * 2, radius * 2)
	visuals.nextZoneCylinder.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	visuals.nextZoneCylinder.Transparency = 0.85
end

function SafeZoneController.ShowWarning()
	if not visuals.warningUI then return end

	local frame = visuals.warningUI:FindFirstChild("WarningFrame")
	if frame then
		frame.Visible = true
	end
end

function SafeZoneController.HideWarning()
	if not visuals.warningUI then return end

	local frame = visuals.warningUI:FindFirstChild("WarningFrame")
	if frame then
		frame.Visible = false
	end
end

function SafeZoneController.Update()
	if not visuals.isActive then return end

	-- Update warning timer
	if zoneState.isShrinking and visuals.warningUI then
		local frame = visuals.warningUI:FindFirstChild("WarningFrame")
		if frame then
			local timerLabel = frame:FindFirstChild("TimerText")
			if timerLabel then
				local remaining = math.max(0, zoneState.phaseEndTime - os.clock())
				timerLabel.Text = Util.FormatTime(remaining)
			end
		end
	end

	-- Pulse effect on zone
	if visuals.cylinder then
		local pulse = math.sin(os.clock() * 2) * 0.05 + 0.95
		visuals.cylinder.Transparency = CONFIG.cylinderTransparency * pulse
	end
end

function SafeZoneController.GetZoneState(): ZoneVisualState
	return zoneState
end

function SafeZoneController.IsInZone(position: Vector3): boolean
	local distance = (position - zoneState.currentCenter).Magnitude
	return distance <= zoneState.currentRadius
end

function SafeZoneController.GetDistanceToZone(position: Vector3): number
	local distance = (position - zoneState.currentCenter).Magnitude
	return math.max(0, distance - zoneState.currentRadius)
end

function SafeZoneController.GetPhaseColor(phase: number): Color3
	local index = math.clamp(phase + 1, 1, #PHASE_COLORS)
	return PHASE_COLORS[index]
end

function SafeZoneController.SetActive(active: boolean)
	visuals.isActive = active
	if visuals.cylinder then
		visuals.cylinder.Transparency = active and CONFIG.cylinderTransparency or 1
	end
	if visuals.innerCylinder then
		visuals.innerCylinder.Transparency = active and CONFIG.innerTransparency or 1
	end
end

function SafeZoneController.Cleanup()
	if activeTween then
		activeTween:Cancel()
	end

	if visuals.cylinder then
		visuals.cylinder:Destroy()
	end
	if visuals.innerCylinder then
		visuals.innerCylinder:Destroy()
	end
	if visuals.nextZoneCylinder then
		visuals.nextZoneCylinder:Destroy()
	end
	if visuals.warningUI then
		visuals.warningUI:Destroy()
	end

	visuals = {
		cylinder = nil,
		innerCylinder = nil,
		nextZoneCylinder = nil,
		warningUI = nil,
		isActive = false,
	}
end

return SafeZoneController
