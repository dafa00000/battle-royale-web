--[[
	MatchGui - Main ScreenGui container for Match Place
	Responsive, safe area, contains all match UI elements
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local MatchGui = {}

function MatchGui.Create(player)
	local playerGui = player:WaitForChild("PlayerGui")
	
	if playerGui:FindFirstChild("MatchGui") then
		return playerGui.MatchGui
	end
	
	local screenGui = Util.Create("ScreenGui", {
		Name = "MatchGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true, -- Use full screen including top/bottom bars
	})
	screenGui.Parent = playerGui
	
	-- Safe area frame (respects device notches, etc.)
	local safeArea = Util.Create("Frame", {
		Name = "SafeArea",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	})
	safeArea.Parent = screenGui
	
	-- Responsive scale
	local uiScale = Util.Create("UIScale", {
		Name = "ResponsiveScale",
		Scale = 1,
	})
	uiScale.Parent = screenGui
	
	local function UpdateScale()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
		local baseWidth = 1920
		local scale = math.clamp(viewport.X / baseWidth, 0.5, 1.5)
		uiScale.Scale = scale
	end
	
	UpdateScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
	end
	
	-- Main container for all UI
	local container = Util.Create("Frame", {
		Name = "UIContainer",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	})
	container.Parent = safeArea
	
	print("[MatchGui] Created")
	return screenGui
end

return MatchGui