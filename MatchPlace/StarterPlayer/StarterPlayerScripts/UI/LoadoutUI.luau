--[[
	LoadoutUI - Pre-match loadout editor (read-only during match)
	Weapon stats, attachments, skin selector
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local MatchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes")

local LoadoutUI = {}
local localPlayer = Players.LocalPlayer
local screenGui = nil
local loadoutFrame = nil
local currentSlot = "Primary"
local isReadOnly = false -- true during match

local T = Constants.UI_THEME

-- ==================== UI CREATION ====================

local function Create(className, props, children)
	return Util.Create(className, props, children)
end

local function CreateCorner(radius)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function LoadoutUI.Initialize(readOnly)
	isReadOnly = readOnly or false
	
	screenGui = Create("ScreenGui", {
		Name = "LoadoutGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
	
	-- Main frame
	loadoutFrame = Create("Frame", {
		Name = "LoadoutFrame",
		Size = UDim2.new(0, 800, 0, 550),
		Position = UDim2.new(0.5, -400, 0.5, -275),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
	}, { CreateCorner(12), Create("UIStroke", { Color = T.Border, Thickness = 2 }) })
	loadoutFrame.Parent = screenGui
	
	-- Title
	local titleBar = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(12) })
	titleBar.Parent = loadoutFrame
	
	local title = Create("TextLabel", {
		Size = UDim2.new(1, -100, 1, 0),
		Position = UDim2.new(0, 20, 0, 0),
		BackgroundTransparency = 1,
		Text = isReadOnly and "LOADOUT (VIEW ONLY)" or "LOADOUT EDITOR",
		TextColor3 = T.Text,
		TextSize = 20,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	title.Parent = titleBar
	
	local closeBtn = Create("TextButton", {
		Size = UDim2.new(0, 40, 0, 40),
		Position = UDim2.new(1, -50, 0, 5),
		BackgroundColor3 = T.Danger,
		Text = "×",
		TextColor3 = Color3.new(1,1,1),
		TextSize = 28,
		Font = Enum.Font.GothamBold,
	}, { CreateCorner(6) })
	closeBtn.Parent = titleBar
	closeBtn.MouseButton1Click:Connect(LoadoutUI.Close)
	
	-- Slot selector (left)
	local slotSelector = Create("Frame", {
		Name = "SlotSelector",
		Size = UDim2.new(0, 160, 1, -70),
		Position = UDim2.new(0, 10, 0, 60),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(8) })
	slotSelector.Parent = loadoutFrame
	
	local slotLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	slotLayout.Parent = slotSelector
	Create("UIPadding", { PaddingTop = UDim.new(0, 16) }).Parent = slotSelector
	
	local slots = { "Primary", "Secondary", "Melee", "Throw", "Armor", "Backpack" }
	for _, slot in ipairs(slots) do
		local btn = Create("TextButton", {
			Name = "Slot_" .. slot,
			Size = UDim2.new(0.9, 0, 0, 50),
			BackgroundColor3 = slot == currentSlot and T.Primary or T.Background,
			Text = slot,
			TextColor3 = slot == currentSlot and Color3.new(1,1,1) or T.Text,
			TextSize = 14,
			Font = Enum.Font.GothamBold,
		}, { CreateCorner(6) })
		btn.Parent = slotSelector
		
		btn.MouseButton1Click:Connect(function()
			LoadoutUI.SelectSlot(slot)
		end)
	end
	
	-- Weapon preview (center)
	local previewFrame = Create("Frame", {
		Name = "PreviewFrame",
		Size = UDim2.new(0, 300, 0, 350),
		Position = UDim2.new(0, 180, 0, 60),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(8) })
	previewFrame.Parent = loadoutFrame
	
	-- ViewportFrame for 3D weapon model
	local viewport = Create("ViewportFrame", {
		Name = "WeaponViewport",
		Size = UDim2.new(1, -20, 1, -60),
		Position = UDim2.new(0, 10, 0, 10),
		BackgroundTransparency = 1,
		CurrentCamera = nil, -- Set dynamically
	})
	viewport.Parent = previewFrame
	
	-- Weapon stats
	local statsFrame = Create("Frame", {
		Name = "StatsFrame",
		Size = UDim2.new(0, 250, 0, 350),
		Position = UDim2.new(1, -260, 0, 60),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(8) })
	statsFrame.Parent = loadoutFrame
	
	local statsLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
	})
	statsLayout.Parent = statsFrame
	Create("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }).Parent = statsFrame
	
	local statTitle = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = "WEAPON STATS",
		TextColor3 = T.TextMuted,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	statTitle.Parent = statsFrame
	
	-- Stat bars will be created dynamically
	LoadoutUI.statBars = {}
	
	-- Attachments (bottom center)
	local attachFrame = Create("Frame", {
		Name = "AttachmentsFrame",
		Size = UDim2.new(0, 300, 0, 120),
		Position = UDim2.new(0, 180, 1, -130),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(8) })
	attachFrame.Parent = loadoutFrame
	
	local attachTitle = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = "ATTACHMENTS",
		TextColor3 = T.TextMuted,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	attachTitle.Parent = attachFrame
	Create("UIPadding", { PaddingLeft = UDim.new(0, 16) }).Parent = attachFrame
	
	LoadoutUI.attachmentSlots = {}
	local attachSlots = { "Optic", "Muzzle", "Barrel", "Underbarrel", "Magazine", "Stock", "Grip", "Laser" }
	local attachLayout = Create("UIGridLayout", {
		CellSize = UDim2.new(0, 40, 0, 40),
		CellPadding = UDim2.new(0, 8, 0, 8),
		FillDirection = Enum.FillDirection.Horizontal,
	})
	attachLayout.Parent = attachFrame
	
	for _, slotName in ipairs(attachSlots) do
		local btn = Create("TextButton", {
			Name = "Attach_" .. slotName,
			Size = UDim2.new(0, 40, 0, 40),
			BackgroundColor3 = T.Background,
			Text = "",
			BorderSizePixel = 0,
		}, { CreateCorner(6), Create("UIStroke", { Color = T.Border, Thickness = 1 }) })
		btn.Parent = attachFrame
		
		local label = Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 12),
			Position = UDim2.new(0, 0, 1, -12),
			BackgroundTransparency = 1,
			Text = slotName:sub(1,3),
			TextColor3 = T.TextMuted,
			TextSize = 8,
			Font = Enum.Font.Gotham,
		})
		label.Parent = btn
		
		LoadoutUI.attachmentSlots[slotName] = btn
	end
	
	print("[LoadoutUI] Initialized (readOnly: " .. tostring(isReadOnly) .. ")")
end

function LoadoutUI.SelectSlot(slot)
	currentSlot = slot
	
	-- Update button highlights
	for _, btn in pairs(loadoutFrame.SlotSelector:GetChildren()) do
		if btn:IsA("TextButton") then
			local isSelected = btn.Name == "Slot_" .. slot
			btn.BackgroundColor3 = isSelected and T.Primary or T.Background
			btn.TextColor3 = isSelected and Color3.new(1,1,1) or T.Text
		end
	end
	
	-- Load slot data
	LoadoutUI.LoadSlotData(slot)
end

function LoadoutUI.LoadSlotData(slot)
	-- Request from server
	local success, data = pcall(function()
		return MatchRemotes.GetLoadout:InvokeServer(slot)
	end)
	
	if success and data then
		LoadoutUI.UpdateWeaponPreview(data)
		LoadoutUI.UpdateStats(data)
		LoadoutUI.UpdateAttachments(data)
	end
end

function LoadoutUI.UpdateWeaponPreview(data)
	-- Set up viewport camera and model
	print("[LoadoutUI] Preview weapon: " .. (data.WeaponId or "none"))
end

function LoadoutUI.UpdateStats(data)
	-- Clear old
	for _, bar in pairs(LoadoutUI.statBars) do
		bar:Destroy()
	end
	LoadoutUI.statBars = {}
	
	if not data.Stats then return end
	
	local stats = {
		{ name = "Damage", value = data.Stats.Damage or 0, max = 120, color = T.Danger },
		{ name = "Fire Rate", value = data.Stats.FireRate or 0, max = 1200, color = T.Primary },
		{ name = "Range", value = data.Stats.Range or 0, max = 800, color = T.Success },
		{ name = "Accuracy", value = (1 - (data.Stats.Spread or 0)) * 100, max = 100, color = T.Secondary },
		{ name = "Mobility", value = math.max(0, 100 - (data.Stats.Weight or 0) * 5), max = 100, color = T.Success },
		{ name = "Control", value = math.max(0, 100 - (data.Stats.Recoil or 0) * 10), max = 100, color = T.Primary },
	}
	
	for _, stat in ipairs(stats) do
		local bar = LoadoutUI.CreateStatBar(stat)
		bar.Parent = loadoutFrame.StatsFrame
		table.insert(LoadoutUI.statBars, bar)
	end
end

function LoadoutUI.CreateStatBar(stat)
	local frame = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
	})
	
	local name = Create("TextLabel", {
		Size = UDim2.new(0, 80, 1, 0),
		BackgroundTransparency = 1,
		Text = stat.name,
		TextColor3 = T.Text,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	name.Parent = frame
	
	local bg = Create("Frame", {
		Size = UDim2.new(1, -90, 0, 8),
		Position = UDim2.new(0, 85, 0.5, -4),
		BackgroundColor3 = T.Background,
		BorderSizePixel = 0,
	}, { CreateCorner(4) })
	bg.Parent = frame
	
	local fill = Create("Frame", {
		Size = UDim2.new(stat.value / stat.max, 1, 0),
		BackgroundColor3 = stat.color,
		BorderSizePixel = 0,
	}, { CreateCorner(4) })
	fill.Parent = bg
	
	local value = Create("TextLabel", {
		Size = UDim2.new(0, 40, 1, 0),
		Position = UDim2.new(1, -40, 0, 0),
		BackgroundTransparency = 1,
		Text = tostring(math.floor(stat.value)),
		TextColor3 = T.TextMuted,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	value.Parent = frame
	
	return frame
end

function LoadoutUI.UpdateAttachments(data)
	-- Update attachment slot visuals
	for slotName, btn in pairs(LoadoutUI.attachmentSlots) do
		local attachId = data.Attachments and data.Attachments[slotName]
		if attachId then
			btn.BackgroundColor3 = T.Primary
			btn:SetAttribute("AttachmentId", attachId)
		else
			btn.BackgroundColor3 = T.Background
			btn:SetAttribute("AttachmentId", nil)
		end
	end
end

function LoadoutUI.Open()
	if not loadoutFrame then
		LoadoutUI.Initialize()
	end
	loadoutFrame.Visible = true
	LoadoutUI.LoadSlotData(currentSlot)
end

function LoadoutUI.Close()
	loadoutFrame.Visible = false
end

function LoadoutUI.SetReadOnly(readOnly)
	isReadOnly = readOnly
	if loadoutFrame and loadoutFrame.TitleBar then
		loadoutFrame.TitleBar.TextLabel.Text = readOnly and "LOADOUT (VIEW ONLY)" or "LOADOUT EDITOR"
	end
end

print("[LoadoutUI] Module loaded")
return LoadoutUI