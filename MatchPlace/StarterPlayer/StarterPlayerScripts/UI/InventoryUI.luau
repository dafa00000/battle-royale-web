--[[
	InventoryUI - Grid inventory (30 slots), hotbar 5 slots
	Item icons, rarity border, drag-drop, context menu (use/drop/split)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local MatchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes")

local InventoryUI = {}

-- State
local localPlayer = Players.LocalPlayer
local screenGui = nil
local inventoryFrame = nil
local gridFrame = nil
local hotbarFrame = nil
local slotFrames = {}
local hotbarSlots = {}
local draggedItem = nil
local draggedFromSlot = nil
local contextMenu = nil

local T = Constants.UI_THEME
local INVENTORY_SLOTS = Constants.INVENTORY_SLOTS
local HOTBAR_SLOTS = Constants.HOTBAR_SLOTS

-- ==================== UI CREATION ====================

local function Create(className, props, children)
	return Util.Create(className, props, children)
end

local function CreateCorner(radius)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function InventoryUI.Initialize()
	-- ScreenGui
	screenGui = Create("ScreenGui", {
		Name = "InventoryGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
	
	-- Main inventory frame (centered, hidden by default)
	inventoryFrame = Create("Frame", {
		Name = "InventoryFrame",
		Size = UDim2.new(0, 600, 0, 450),
		Position = UDim2.new(0.5, -300, 0.5, -225),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
	}, { CreateCorner(12), Create("UIStroke", { Color = T.Border, Thickness = 2 }) })
	inventoryFrame.Parent = screenGui
	
	-- Title bar
	local titleBar = Create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(12) })
	titleBar.Parent = inventoryFrame
	
	local title = Create("TextLabel", {
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		BackgroundTransparency = 1,
		Text = "INVENTORY",
		TextColor3 = T.Text,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	title.Parent = titleBar
	
	local closeBtn = Create("TextButton", {
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(1, -42, 0, 2),
		BackgroundColor3 = T.Danger,
		Text = "×",
		TextColor3 = Color3.new(1,1,1),
		TextSize = 24,
		Font = Enum.Font.GothamBold,
	}, { CreateCorner(6) })
	closeBtn.Parent = titleBar
	closeBtn.MouseButton1Click:Connect(InventoryUI.Close)
	
	-- Grid container
	local gridContainer = Create("Frame", {
		Name = "GridContainer",
		Size = UDim2.new(1, -20, 1, -100),
		Position = UDim2.new(0, 10, 0, 50),
		BackgroundTransparency = 1,
	})
	gridContainer.Parent = inventoryFrame
	
	-- Inventory grid (6 columns x 5 rows = 30 slots)
	gridFrame = Create("Frame", {
		Name = "InventoryGrid",
		Size = UDim2.new(0, 320, 1, 0),
		BackgroundTransparency = 1,
	})
	gridFrame.Parent = gridContainer
	
	local gridLayout = Create("UIGridLayout", {
		CellSize = UDim2.new(0, 50, 0, 50),
		CellPadding = UDim2.new(0, 4, 0, 4),
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
	gridLayout.Parent = gridFrame
	
	-- Create 30 slots
	for i = 1, INVENTORY_SLOTS do
		InventoryUI.CreateSlot(gridFrame, i, "Inventory")
	end
	
	-- Hotbar (bottom)
	hotbarFrame = Create("Frame", {
		Name = "Hotbar",
		Size = UDim2.new(1, -20, 0, 60),
		Position = UDim2.new(0, 10, 1, -70),
		BackgroundTransparency = 1,
	})
	hotbarFrame.Parent = inventoryFrame
	
	local hotbarLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	hotbarLayout.Parent = hotbarFrame
	
	for i = 1, HOTBAR_SLOTS do
		InventoryUI.CreateSlot(hotbarFrame, i, "Hotbar")
	end
	
	-- Weight display
	local weightFrame = Create("Frame", {
		Name = "WeightInfo",
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0, 10, 1, -105),
		BackgroundTransparency = 1,
	})
	weightFrame.Parent = inventoryFrame
	
	InventoryUI.weightLabel = Create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "Weight: 0 / 100 kg",
		TextColor3 = T.TextMuted,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	InventoryUI.weightLabel.Parent = weightFrame
	
	-- Input handling
	InventoryUI.SetupInput()
	
	print("[InventoryUI] Initialized")
end

function InventoryUI.CreateSlot(parent, index, slotType)
	local slot = Create("Frame", {
		Name = "Slot_" .. index,
		Size = UDim2.new(0, 50, 0, 50),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(6), Create("UIStroke", { Color = T.Border, Thickness = 1 }) })
	slot.Parent = parent
	
	-- Item icon
	local icon = Create("ImageLabel", {
		Name = "Icon",
		Size = UDim2.new(0.8, 0, 0.8, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = "",
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		ZIndex = 2,
	})
	icon.Parent = slot
	
	-- Quantity label
	local qty = Create("TextLabel", {
		Name = "Quantity",
		Size = UDim2.new(1, -4, 0, 16),
		Position = UDim2.new(0, 2, 1, -18),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = T.Text,
		TextSize = 10,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	})
	qty.Parent = slot
	
	-- Rarity border (UIStroke color change)
	slot.RarityStroke = slot:FindFirstChild("UIStroke")
	
	-- Drag events
	slot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			InventoryUI.OnSlotDragStart(slot, index, slotType)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			InventoryUI.ShowContextMenu(slot, index, slotType)
		end
	end)
	
	slot.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			InventoryUI.OnSlotDragEnd(slot, index, slotType)
		end
	end)
	
	if slotType == "Inventory" then
		slotFrames[index] = slot
	else
		hotbarSlots[index] = slot
	end
	
	return slot
end

-- ==================== DRAG & DROP ====================

function InventoryUI.OnSlotDragStart(slot, index, slotType)
	local item = InventoryUI.GetItemAtSlot(index, slotType)
	if not item then return end
	
	draggedItem = item
	draggedFromSlot = { index = index, type = slotType }
	
	-- Create drag visual
	local dragVisual = Create("Frame", {
		Name = "DragVisual",
		Size = UDim2.new(0, 50, 0, 50),
		Position = UDim2.new(0, UserInputService:GetMouseLocation().X - 25, 0, UserInputService:GetMouseLocation().Y - 25),
		BackgroundTransparency = 1,
		ZIndex = 100,
	})
	dragVisual.Parent = screenGui
	
	local dragIcon = Create("ImageLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Image = slot.Icon.Image,
		ScaleType = Enum.ScaleType.Fit,
	})
	dragIcon.Parent = dragVisual
	
	slot.DragVisual = dragVisual
	
	-- Follow mouse
	local connection
	connection = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			dragVisual.Position = UDim2.new(0, input.Position.X - 25, 0, input.Position.Y - 25)
		end
	end)
	
	slot.DragConnection = connection
end

function InventoryUI.OnSlotDragEnd(slot, index, slotType)
	if not draggedItem then return end
	
	local mouse = UserInputService:GetMouseLocation()
	local targetSlot = InventoryUI.GetSlotAtPosition(mouse)
	
	if targetSlot and targetSlot ~= slot then
		-- Drop on another slot
		MatchRemotes.InventoryAction:InvokeServer({
			Action = "Move",
			FromSlot = draggedFromSlot.index,
			ToSlot = targetSlot.Index,
			FromType = draggedFromSlot.type,
			ToType = targetSlot.Type,
		})
	else
		-- Drop in world
		MatchRemotes.InventoryAction:InvokeServer({
			Action = "Drop",
			FromSlot = draggedFromSlot.index,
			FromType = draggedFromSlot.type,
		})
	end
	
	InventoryUI.CleanupDrag()
end

function InventoryUI.GetSlotAtPosition(position)
	-- Check inventory slots
	for i, slot in pairs(slotFrames) do
		if InventoryUI.IsMouseOverSlot(slot, position) then
			return { Index = i, Type = "Inventory", Slot = slot }
		end
	end
	-- Check hotbar
	for i, slot in pairs(hotbarSlots) do
		if InventoryUI.IsMouseOverSlot(slot, position) then
			return { Index = i, Type = "Hotbar", Slot = slot }
		end
	end
	return nil
end

function InventoryUI.IsMouseOverSlot(slot, mousePos)
	local absPos = slot.AbsolutePosition
	local absSize = slot.AbsoluteSize
	return mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X
		and mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y
end

function InventoryUI.CleanupDrag()
	if draggedFromSlot and draggedFromSlot.Slot then
		if draggedFromSlot.Slot.DragVisual then
			draggedFromSlot.Slot.DragVisual:Destroy()
		end
		if draggedFromSlot.Slot.DragConnection then
			draggedFromSlot.Slot.DragConnection:Disconnect()
		end
	end
	draggedItem = nil
	draggedFromSlot = nil
end

-- ==================== CONTEXT MENU ====================

function InventoryUI.ShowContextMenu(slot, index, slotType)
	InventoryUI.HideContextMenu()
	
	local item = InventoryUI.GetItemAtSlot(index, slotType)
	if not item then return end
	
	contextMenu = Create("Frame", {
		Name = "ContextMenu",
		Size = UDim2.new(0, 140, 0, 100),
		Position = UDim2.new(0, UserInputService:GetMouseLocation().X, 0, UserInputService:GetMouseLocation().Y),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
		ZIndex = 50,
	}, { CreateCorner(6), Create("UIStroke", { Color = T.Border, Thickness = 1 }) })
	contextMenu.Parent = screenGui
	
	local actions = {
		{ name = "Use", action = "Use" },
		{ name = "Drop", action = "Drop" },
		{ name = "Split", action = "Split" },
	}
	
	for i, act in ipairs(actions) do
		local btn = Create("TextButton", {
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 0, (i-1)*30),
			BackgroundTransparency = 1,
			Text = act.name,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, { Create("UIPadding", { PaddingLeft = UDim.new(0, 12) }) })
		btn.Parent = contextMenu
		
		btn.MouseButton1Click:Connect(function()
			MatchRemotes.InventoryAction:InvokeServer({
				Action = act.action,
				FromSlot = index,
				FromType = slotType,
			})
			InventoryUI.HideContextMenu()
		end)
		
		btn.MouseEnter:Connect(function()
			btn.BackgroundTransparency = 0.8
			btn.BackgroundColor3 = T.Primary
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundTransparency = 1
		end)
	end
	
	-- Close on click elsewhere
	contextMenu.CloseConnection = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			InventoryUI.HideContextMenu()
		end
	end)
end

function InventoryUI.HideContextMenu()
	if contextMenu then
		if contextMenu.CloseConnection then
			contextMenu.CloseConnection:Disconnect()
		end
		contextMenu:Destroy()
		contextMenu = nil
	end
end

-- ==================== DATA UPDATES ====================

function InventoryUI.UpdateFromServer(inventoryData)
	if not inventoryData then return end
	
	-- Update grid slots
	if inventoryData.Items then
		for slotIndex, item in pairs(inventoryData.Items) do
			InventoryUI.UpdateSlot(slotFrames[slotIndex], item)
		end
	end
	
	-- Update hotbar
	if inventoryData.Hotbar then
		for hotbarIndex, invSlotIndex in pairs(inventoryData.Hotbar) do
			local item = inventoryData.Items[invSlotIndex]
			InventoryUI.UpdateSlot(hotbarSlots[hotbarIndex], item)
			hotbarSlots[hotbarIndex].HotbarIndex = hotbarIndex
			hotbarSlots[hotbarIndex].InventoryIndex = invSlotIndex
		end
	end
	
	-- Update weight
	if inventoryData.Weight and InventoryUI.weightLabel then
		InventoryUI.weightLabel.Text = string.format("Weight: %.1f / %.1f kg", inventoryData.Weight, inventoryData.MaxWeight)
	end
end

function InventoryUI.UpdateSlot(slot, item)
	if not slot then return end
	
	if item and item.TemplateId then
		slot.Icon.Image = item.Icon or "rbxassetid://0"
		slot.Icon.Visible = true
		slot.Quantity.Text = item.Quantity > 1 and "x" .. item.Quantity or ""
		
		-- Rarity border
		local rarityColor = Util.GetRarityColor(item.Rarity or "Common")
		slot.RarityStroke.Color = rarityColor
		slot.RarityStroke.Thickness = 2
	else
		slot.Icon.Image = ""
		slot.Icon.Visible = false
		slot.Quantity.Text = ""
		slot.RarityStroke.Color = T.Border
		slot.RarityStroke.Thickness = 1
	end
end

function InventoryUI.GetItemAtSlot(index, slotType)
	-- Would query from local cache
	return nil
end

-- ==================== OPEN/CLOSE ====================

function InventoryUI.SetupInput()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Tab then
			InventoryUI.Toggle()
		end
	end)
end

function InventoryUI.Toggle()
	inventoryFrame.Visible = not inventoryFrame.Visible
	if inventoryFrame.Visible then
		-- Request update from server
		MatchRemotes.InventoryAction:InvokeServer({ Action = "Get" })
	end
end

function InventoryUI.Close()
	inventoryFrame.Visible = false
	InventoryUI.HideContextMenu()
end

print("[InventoryUI] Module loaded")
return InventoryUI