--[[
	WorldLootUI - 3D world loot prompt: BillboardGui with item name/rarity/quantity, distance fade, interact key, raycast targeting
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local ItemDefinitions = require(script.Parent.ItemDefinitions)

local WorldLootUI = {}

export type LootPrompt = {
	lootId: string,
	position: Vector3,
	templateId: string,
	quantity: number,
	rarity: string,
	gui: BillboardGui?,
	highlight: Highlight?,
	isVisible: boolean,
	distance: number,
}

export type LootTarget = {
	lootId: string,
	position: Vector3,
	distance: number,
}

-- Configuration
local CONFIG = {
	maxDistance = 15,
	fadeStartDistance = 10,
	guiSize = UDim2.new(0, 200, 0, 60),
	guiOffset = Vector3.new(0, 2, 0),
	interactKey = Constants.DEFAULT_KEYBINDS.Interact,
	updateRate = 0.1, -- 10 Hz
}

-- State
local lootPrompts: { [string]: LootPrompt } = {}
local currentTarget: LootTarget?
local player = Players.LocalPlayer
local character: Model?
local rootPart: BasePart?

-- UI Colors
local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(50, 200, 50),
	Rare = Color3.fromRGB(50, 150, 255),
	Epic = Color3.fromRGB(180, 50, 255),
	Legendary = Color3.fromRGB(255, 180, 0),
	Mythic = Color3.fromRGB(255, 50, 50),
}

function WorldLootUI.Initialize(char: Model)
	character = char
	rootPart = char:WaitForChild("HumanoidRootPart") :: BasePart

	-- Start update loops
	RunService.Heartbeat:Connect(WorldLootUI.Update)
	task.spawn(function()
		while true do
			WorldLootUI.UpdateTargeting()
			task.wait(CONFIG.updateRate)
		end
	end)

	print("[WorldLootUI] Initialized")
end

function WorldLootUI.CreateLootPrompt(lootId: string, templateId: string, quantity: number, position: Vector3, rarity: string)
	-- Remove existing if any
	WorldLootUI.RemoveLootPrompt(lootId)

	local template = ItemDefinitions.Get(templateId)
	if not template then return end

	local prompt: LootPrompt = {
		lootId = lootId,
		position = position,
		templateId = templateId,
		quantity = quantity,
		rarity = rarity,
		gui = nil,
		highlight = nil,
		isVisible = false,
		distance = math.huge,
	}

	-- Create BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "LootPrompt_" .. lootId
	gui.Size = CONFIG.guiSize
	gui.StudsOffset = CONFIG.guiOffset
	gui.AlwaysOnTop = false
	gui.MaxDistance = CONFIG.maxDistance
	gui.Parent = Workspace

	-- Background frame
	local frame = Instance.new("Frame")
	frame.Name = "Background"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Constants.UI_THEME.Background
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	stroke.Thickness = 2
	stroke.Parent = frame

	-- Item name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.Size = UDim2.new(1, -10, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 5, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = template.Name
	nameLabel.TextColor3 = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = frame

	-- Quantity and rarity
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "Info"
	infoLabel.Size = UDim2.new(1, -10, 0.5, 0)
	infoLabel.Position = UDim2.new(0, 5, 0.5, -2)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = string.format("x%d  •  %s", quantity, rarity)
	infoLabel.TextColor3 = Constants.UI_THEME.TextMuted
	infoLabel.TextSize = 12
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = frame

	-- Interact prompt (shown when targeted)
	local interactFrame = Instance.new("Frame")
	interactFrame.Name = "InteractPrompt"
	interactFrame.Size = UDim2.new(0, 40, 0, 40)
	interactFrame.Position = UDim2.new(0.5, -20, 1, 10)
	interactFrame.AnchorPoint = Vector2.new(0.5, 0)
	interactFrame.BackgroundColor3 = Constants.UI_THEME.Primary
	interactFrame.BackgroundTransparency = 0.3
	interactFrame.BorderSizePixel = 0
	interactFrame.Visible = false
	interactFrame.Parent = gui

	local interactCorner = Instance.new("UICorner")
	interactCorner.CornerRadius = UDim.new(0, 8)
	interactCorner.Parent = interactFrame

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "Key"
	keyLabel.Size = UDim2.new(1, 0, 1, 0)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text = "E"
	keyLabel.TextColor3 = Color3.white
	keyLabel.TextSize = 20
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.Parent = interactFrame

	prompt.gui = gui

	-- Create highlight for targeting
	local highlight = Instance.new("Highlight")
	highlight.Name = "LootHighlight_" .. lootId
	highlight.FillColor = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = Workspace

	prompt.highlight = highlight

	lootPrompts[lootId] = prompt
end

function WorldLootUI.RemoveLootPrompt(lootId: string)
	local prompt = lootPrompts[lootId]
	if not prompt then return end

	if prompt.gui then
		prompt.gui:Destroy()
	end
	if prompt.highlight then
		prompt.highlight:Destroy()
	end

	lootPrompts[lootId] = nil

	if currentTarget and currentTarget.lootId == lootId then
		currentTarget = nil
	end
end

function WorldLootUI.Update()
	if not rootPart then return end

	for lootId, prompt in pairs(lootPrompts) do
		-- Update distance
		prompt.distance = (rootPart.Position - prompt.position).Magnitude

		-- Update visibility
		local wasVisible = prompt.isVisible
		prompt.isVisible = prompt.distance <= CONFIG.maxDistance

		if prompt.gui then
			-- Fade based on distance
			local alpha = 1
			if prompt.distance > CONFIG.fadeStartDistance then
				alpha = 1 - (prompt.distance - CONFIG.fadeStartDistance) / (CONFIG.maxDistance - CONFIG.fadeStartDistance)
			end

			local frame = prompt.gui:FindFirstChild("Background")
			if frame then
				frame.BackgroundTransparency = 0.2 + (1 - alpha) * 0.8
				local nameLabel = frame:FindFirstChild("ItemName")
				local infoLabel = frame:FindFirstChild("Info")
				if nameLabel then nameLabel.TextTransparency = 1 - alpha end
				if infoLabel then infoLabel.TextTransparency = 1 - alpha end
			end

			-- Show/hide interact prompt
			local interactPrompt = prompt.gui:FindFirstChild("InteractPrompt")
			if interactPrompt then
				interactPrompt.Visible = currentTarget and currentTarget.lootId == lootId
			end
		end
	end
end

function WorldLootUI.UpdateTargeting()
	if not rootPart or not character then return end

	local camera = Workspace.CurrentCamera
	if not camera then return end

	-- Raycast from camera center
	local rayOrigin = camera.CFrame.Position
	local rayDirection = camera.CFrame.LookVector * CONFIG.maxDistance

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local hit = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	local bestTarget: LootTarget?
	local bestScore = math.huge

	-- Check all loot prompts
	for lootId, prompt in pairs(lootPrompts) do
		if prompt.isVisible then
			-- Score based on distance and angle to camera look
			local toLoot = (prompt.position - rayOrigin).Unit
			local angleDiff = math.deg(math.acos(math.clamp(rayDirection.Unit:Dot(toLoot), -1, 1)))
			local score = prompt.distance + angleDiff * 0.5

			if score < bestScore then
				bestScore = score
				bestTarget = {
					lootId = lootId,
					position = prompt.position,
					distance = prompt.distance,
				}
			end
		end
	end

	-- Update current target
	if bestTarget and bestTarget.distance <= CONFIG.maxDistance then
		if currentTarget and currentTarget.lootId ~= bestTarget.lootId then
			-- Clear old highlight
			local oldPrompt = lootPrompts[currentTarget.lootId]
			if oldPrompt and oldPrompt.highlight then
				oldPrompt.highlight.Enabled = false
			end
		end

		currentTarget = bestTarget

		-- Highlight current target
		local prompt = lootPrompts[currentTarget.lootId]
		if prompt and prompt.highlight then
			prompt.highlight.Enabled = true
			-- Update highlight adornee
			local adornee = Workspace:FindFirstChild("Loot_" .. currentTarget.lootId)
			if adornee then
				prompt.highlight.Adornee = adornee
			end
		end
	else
		if currentTarget then
			local prompt = lootPrompts[currentTarget.lootId]
			if prompt and prompt.highlight then
				prompt.highlight.Enabled = false
			end
			currentTarget = nil
		end
	end
end

function WorldLootUI.GetCurrentTarget(): LootTarget?
	return currentTarget
end

function WorldLootUI.HandleInteract(): boolean
	if not currentTarget then return false end

	-- Fire pickup remote
	local MatchRemotes = ReplicatedStorage.Remotes.MatchRemotes
	MatchRemotes.LootPickup:InvokeServer(currentTarget.lootId)

	return true
end

function WorldLootUI.GetPrompt(lootId: string): LootPrompt?
	return lootPrompts[lootId]
end

function WorldLootUI.GetAllPrompts(): { [string]: LootPrompt }
	return lootPrompts
end

function WorldLootUI.SetLootPosition(lootId: string, position: Vector3)
	local prompt = lootPrompts[lootId]
	if prompt then
		prompt.position = position
	end
end

function WorldLootUI.ClearAll()
	for lootId, _ in pairs(lootPrompts) do
		WorldLootUI.RemoveLootPrompt(lootId)
	end
	currentTarget = nil
end

function WorldLootUI.Cleanup()
	WorldLootUI.ClearAll()
	character = nil
	rootPart = nil
end

return WorldLootUI
