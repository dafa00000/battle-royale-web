--[[
	LoadoutUI - Weapon loadout editor
	Weapon slots, attachment grid, skin selector, save button
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local LobbyRemotes = ReplicatedStorage:WaitForChild("LobbyRemotes")

local LoadoutUI = {}
local localPlayer = nil
local screenGui = nil
local loadoutFrame = nil

local T = Constants.UI_THEME

-- ==================== UI CREATION ====================

local function Create(className, props, children)
	return Util.Create(className, props, children)
end

local function CreateCorner(radius)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

-- ==================== LOADOUT PANEL ====================

function LoadoutUI.Initialize(player)
	localPlayer = player
	
	screenGui = Create("ScreenGui", {
		Name = "LoadoutGui",
		ResetOnSpawn = false,
	})
	screenGui.Parent = player:WaitForChild("PlayerGui")
	
	-- Toggle button
	local toggleBtn = Create("TextButton", {
		Name = "LoadoutToggle",
		Size = UDim2.new(0, 120, 0, 40),
		Position = UDim2.new(1, -130, 0, 60),
		BackgroundColor3 = T.Surface,
		Text = "LOADOUT",
		TextColor3 = T.Text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
	}, { CreateCorner(8) })
	toggleBtn.Parent = screenGui
	
	-- Main panel
	loadoutFrame = Create("Frame", {
		Name = "LoadoutPanel",
		Size = UDim2.new(0, 700, 0, 550),
		Position = UDim2.new(0.5, -350, 0.5, -275),
		BackgroundColor3 = T.Background,
		BorderSizePixel = 0,
		Visible = false,
	}, { CreateCorner(16), Create("UIStroke", { Color = T.Border, Thickness = 2 }) })
	loadoutFrame.Parent = screenGui
	
	toggleBtn.MouseButton1Click:Connect(function()
		loadoutFrame.Visible = not loadoutFrame.Visible
	end)
	
	-- Title
	local title = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Text = "LOADOUT EDITOR",
		TextColor3 = T.Text,
		TextSize = 20,
		Font = Enum.Font.GothamBold,
	})
	title.Parent = loadoutFrame
	
	local closeBtn = Create("TextButton", {
		Size = UDim2.new(0, 30, 0, 30),
		Position = UDim2.new(1, -35, 0, 10),
		BackgroundColor3 = T.Danger,
		Text = "×",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 20,
		Font = Enum.Font.GothamBold,
	}, { CreateCorner(6) })
	closeBtn.Parent = loadoutFrame
	closeBtn.MouseButton1Click:Connect(function()
		loadoutFrame.Visible = false
	end)
	
	-- Weapon slots (left side)
	local slotList = Create("Frame", {
		Name = "SlotList",
		Size = UDim2.new(0, 180, 1, -70),
		Position = UDim2.new(0, 10, 0, 55),
		BackgroundTransparency = 1,
	})
	slotList.Parent = loadoutFrame
	
	local slotLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
	})
	slotLayout.Parent = slotList
	
	local slots = { "Primary", "Secondary", "Melee", "Throw", "Armor", "Backpack" }
	for _, slot in ipairs(slots) do
		local slotBtn = Create("TextButton", {
			Name = slot,
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundColor3 = T.Surface,
			Text = slot,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
		}, { CreateCorner(8) })
		slotBtn.Parent = slotList
		
		slotBtn.MouseButton1Click:Connect(function()
			LoadoutUI.SelectSlot(slot)
		end)
	end
	
	-- Content area (right side)
	local content = Create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -220, 1, -70),
		Position = UDim2.new(0, 200, 0, 55),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(8) })
	content.Parent = loadoutFrame
	
	-- Save button
	local saveBtn = Create("TextButton", {
		Name = "Save",
		Size = UDim2.new(0, 120, 0, 40),
		Position = UDim2.new(1, -130, 1, -50),
		BackgroundColor3 = T.Success,
		Text = "SAVE",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 16,
		Font = Enum.Font.GothamBold,
	}, { CreateCorner(8) })
	saveBtn.Parent = loadoutFrame
	
	saveBtn.MouseButton1Click:Connect(function()
		LoadoutUI.SaveLoadout()
	end)
	
	print("[LoadoutUI] Initialized")
end

function LoadoutUI.SelectSlot(slotName)
	-- Update UI to show selected slot's weapon/attachments
	print("[LoadoutUI] Selected slot:", slotName)
	-- Would populate content area with weapon grid, attachments, skins
end

function LoadoutUI.UpdateSlot(slot, data)
	-- Update visual for slot change
	print(string.format("[LoadoutUI] %s updated: %s", slot, data and data.WeaponId or "cleared"))
end

function LoadoutUI.SaveLoadout()
	-- Save is handled per-change via UpdateLoadout remote
	-- This button could trigger a bulk save or close the panel
	loadoutFrame.Visible = false
end

return LoadoutUI
