--[[
	LoadingScreen - GTA V style cinematic loading with asset preloading
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local LoadingScreen = {}

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Loading screen GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

-- Background
local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Constants.UI_THEME.Background
background.BorderSizePixel = 0
background.Parent = screenGui

-- Cinematic bars (letterbox)
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0.15, 0)
topBar.Position = UDim2.fromScale(0, 0)
topBar.BackgroundColor3 = Color3.new(0, 0, 0)
topBar.BorderSizePixel = 0
topBar.Parent = background

local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.Size = UDim2.new(1, 0, 0.15, 0)
bottomBar.Position = UDim2.fromScale(0, 0.85)
bottomBar.BackgroundColor3 = Color3.new(0, 0, 0)
bottomBar.BorderSizePixel = 0
bottomBar.Parent = background

-- Map preview viewport
local viewportFrame = Instance.new("ViewportFrame")
viewportFrame.Name = "MapPreview"
viewportFrame.Size = UDim2.fromScale(1, 1)
viewportFrame.Position = UDim2.fromScale(0, 0)
viewportFrame.BackgroundColor3 = Color3.new(0, 0, 0)
viewportFrame.BackgroundTransparency = 0.3
viewportFrame.CurrentCamera = nil
viewportFrame.Parent = background

-- Camera for viewport
local viewportCamera = Instance.new("Camera")
viewportCamera.Parent = viewportFrame
viewportFrame.CurrentCamera = viewportCamera

-- Loading text
local loadingText = Instance.new("TextLabel")
loadingText.Name = "LoadingText"
loadingText.Size = UDim2.new(0.5, 0, 0.05, 0)
loadingText.Position = UDim2.fromScale(0.25, 0.9)
loadingText.BackgroundTransparency = 1
loadingText.Text = "INITIALIZING..."
loadingText.TextColor3 = Constants.UI_THEME.Text
loadingText.TextScaled = true
loadingText.Font = Enum.Font.GothamBold
loadingText.TextXAlignment = Enum.TextXAlignment.Center
loadingText.Parent = background

-- Progress bar
local progressBg = Instance.new("Frame")
progressBg.Name = "ProgressBg"
progressBg.Size = UDim2.new(0.4, 0, 0.01, 0)
progressBg.Position = UDim2.fromScale(0.3, 0.96)
progressBg.BackgroundColor3 = Constants.UI_THEME.Border
progressBg.BorderSizePixel = 0
progressBg.Parent = background

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = Constants.UI_THEME.Primary
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBg

-- Progress text
local progressText = Instance.new("TextLabel")
progressText.Name = "ProgressText"
progressText.Size = UDim2.new(0.2, 0, 0.04, 0)
progressText.Position = UDim2.fromScale(0.72, 0.94)
progressText.BackgroundTransparency = 1
progressText.Text = "0%"
progressText.TextColor3 = Constants.UI_THEME.TextMuted
progressText.TextScaled = true
progressText.Font = Enum.Font.Gotham
progressText.Parent = background

-- Tips
local tipText = Instance.new("TextLabel")
tipText.Name = "TipText"
tipText.Size = UDim2.new(0.6, 0, 0.04, 0)
tipText.Position = UDim2.fromScale(0.2, 0.02)
tipText.BackgroundTransparency = 1
tipText.Text = "TIP: Hold SHIFT to sprint, press C to crouch"
tipText.TextColor3 = Constants.UI_THEME.TextMuted
tipText.TextScaled = true
tipText.Font = Enum.Font.Gotham
tipText.TextXAlignment = Enum.TextXAlignment.Center
tipText.Parent = background

-- Game title
local titleText = Instance.new("TextLabel")
titleText.Name = "TitleText"
titleText.Size = UDim2.new(0.5, 0, 0.08, 0)
titleText.Position = UDim2.fromScale(0.25, 0.1)
titleText.BackgroundTransparency = 1
titleText.Text = "BATTLE ROYALE"
titleText.TextColor3 = Constants.UI_THEME.Primary
titleText.TextScaled = true
titleText.Font = Enum.Font.GothamBlack
titleText.TextStrokeTransparency = 0.5
titleText.Parent = background

-- Version
local versionText = Instance.new("TextLabel")
versionText.Name = "VersionText"
versionText.Size = UDim2.new(0.2, 0, 0.03, 0)
versionText.Position = UDim2.fromScale(0.75, 0.15)
versionText.BackgroundTransparency = 1
versionText.Text = "v" .. Constants.VERSION
versionText.TextColor3 = Constants.UI_THEME.TextMuted
versionText.TextScaled = true
versionText.Font = Enum.Font.Gotham
versionText.Parent = background

-- Loading tips
local LOADING_TIPS = {
	"TIP: Hold SHIFT to sprint, press C to crouch, Z to go prone",
	"TIP: Press Q/E to lean left/right while aiming",
	"TIP: Vehicles take realistic damage - avoid high-speed crashes",
	"TIP: The blue zone deals increasing damage over time",
	"TIP: Headshots deal 2x damage - aim for the head!",
	"TIP: Suppressors hide your muzzle flash and reduce sound",
	"TIP: Vault over obstacles by jumping at them while sprinting",
	"TIP: Slide by pressing C while sprinting",
	"TIP: Armor reduces damage but loses durability",
	"TIP: Use energy drinks and painkillers for boost over time",
	"TIP: The pan can block all melee and projectile damage from behind",
	"TIP: Red dot sights are best for close range, scopes for long range",
	"TIP: Cook grenades by holding the throw button before releasing",
	"TIP: Vehicles have limited fuel - find gas cans to refuel",
	"TIP: Prone makes you harder to hit but slower to move",
}

function LoadingScreen.Show(mapName: string?)
	-- Reset UI
	progressFill.Size = UDim2.fromScale(0, 1)
	progressText.Text = "0%"
	loadingText.Text = "LOADING MAP..."
	
	-- Show random tip
	tipText.Text = LOADING_TIPS[math.random(#LOADING_TIPS)]
	
	-- Start map camera animation
	LoadingScreen.StartMapCamera(mapName)
	
	screenGui.Enabled = true
end

function LoadingScreen.Hide()
	-- Fade out
	local fadeTween = TweenService:Create(background, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	fadeTween:Play()
	
	fadeTween.Completed:Wait()
	screenGui.Enabled = false
	background.BackgroundTransparency = 0
end

function LoadingScreen.StartMapCamera(mapName: string?)
	-- Create a camera that pans over the map
	task.spawn(function()
		local camera = viewportCamera
		local map = Workspace:FindFirstChild(mapName or "Map")
		
		if not map then
			-- Create a simple procedural view
			LoadingScreen.CreateProceduralMapView()
			map = viewportFrame:FindFirstChild("ProceduralMap")
		else
			-- Clone map to viewport
			local clone = map:Clone()
			clone.Parent = viewportFrame
			clone.Name = "MapClone"
		end
		
		-- Camera animation
		local startCFrame = CFrame.new(0, 500, 0) * CFrame.Angles(math.rad(-90), 0, 0)
		local endCFrame = CFrame.new(100, 300, 100) * CFrame.Angles(math.rad(-60), math.rad(45), 0)
		
		camera.CFrame = startCFrame
		
		local tween = TweenService:Create(camera, TweenInfo.new(30, Enum.EasingStyle.Linear), { CFrame = endCFrame })
		tween:Play()
		
		-- Rotate slowly
		task.spawn(function()
			local angle = 0
			while screenGui.Enabled do
				angle += 0.0005
				local center = Vector3.new(0, 0, 0)
				local radius = 400
				local height = 300
				local camPos = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
				camera.CFrame = CFrame.lookAt(camPos, center)
				RunService.RenderStepped:Wait()
			end
		end)
	end)
end

function LoadingScreen.CreateProceduralMapView()
	-- Create simple terrain preview
	local mapModel = Instance.new("Model")
	mapModel.Name = "ProceduralMap"
	mapModel.Parent = viewportFrame
	
	-- Ground
	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Size = Vector3.new(5000, 10, 5000)
	ground.Position = Vector3.new(0, -5, 0)
	ground.Anchored = true
	ground.Color = Color3.fromRGB(60, 80, 50)
	ground.Material = Enum.Material.Grass
	ground.Parent = mapModel
	
	-- Some hills
	for i = 1, 20 do
		local hill = Instance.new("Part")
		hill.Name = "Hill" .. i
		hill.Size = Vector3.new(math.random(200, 500), math.random(50, 150), math.random(200, 500))
		hill.Position = Vector3.new(math.random(-2000, 2000), hill.Size.Y/2 - 5, math.random(-2000, 2000))
		hill.Anchored = true
		hill.Color = Color3.fromRGB(50, 70, 40)
		hill.Material = Enum.Material.Grass
		hill.Shape = Enum.PartType.Block
		hill.Parent = mapModel
	end
	
	-- Buildings
	for i = 1, 50 do
		local building = Instance.new("Part")
		building.Name = "Building" .. i
		building.Size = Vector3.new(math.random(20, 50), math.random(30, 100), math.random(20, 50))
		building.Position = Vector3.new(math.random(-2000, 2000), building.Size.Y/2, math.random(-2000, 2000))
		building.Anchored = true
		building.Color = Color3.fromRGB(120, 100, 80)
		building.Material = Enum.Material.Concrete
		building.Parent = mapModel
	end
end

function LoadingScreen.UpdateProgress(progress: number, status: string?)
	progress = math.clamp(progress, 0, 1)
	
	progressFill.Size = UDim2.fromScale(progress, 1)
	progressText.Text = math.floor(progress * 100) .. "%"
	
	if status then
		loadingText.Text = status
	end
end

function LoadingScreen.PreloadAssets(assetIds: { string }): number
	local total = #assetIds
	local loaded = 0
	
	for i, assetId in ipairs(assetIds) do
		ContentProvider:PreloadAsync({ assetId })
		loaded = i
		LoadingScreen.UpdateProgress(i / total, "LOADING ASSETS... " .. i .. "/" .. total)
	end
	
	return loaded
end

function LoadingScreen.PreloadGameAssets(): ()
	-- Collect all asset IDs from ReplicatedStorage
	local assets = {}
	
	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		if obj:IsA("MeshPart") and obj.MeshId ~= "" then
			table.insert(assets, obj.MeshId)
		elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
			if obj.Image ~= "" then table.insert(assets, obj.Image) end
		elseif obj:IsA("Sound") then
			if obj.SoundId ~= "" then table.insert(assets, obj.SoundId) end
		elseif obj:IsA("Animation") then
			if obj.AnimationId ~= "" then table.insert(assets, obj.AnimationId) end
		end
	end
	
	LoadingScreen.PreloadAssets(assets)
end

return LoadingScreen