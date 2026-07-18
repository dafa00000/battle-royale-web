--[[
	LobbyGui - Main ScreenGui container for Lobby Place
	Responsive scaling, safe area, container for all lobby UI
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local LobbyGui = {}

function LobbyGui.Create(player)
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Check if already exists
	if playerGui:FindFirstChild("LobbyGui") then
		return playerGui.LobbyGui
	end
	
	local screenGui = Util.Create("ScreenGui", {
		Name = "LobbyGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
	})
	screenGui.Parent = playerGui
	
	-- Safe area container
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
	
	-- Adjust scale based on viewport
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
	
	print("[LobbyGui] Created")
	return screenGui
end

return LobbyGui
