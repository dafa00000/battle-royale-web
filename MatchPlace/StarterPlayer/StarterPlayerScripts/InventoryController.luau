--[[
	InventoryController - Client inventory management, hotbar, UI integration
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local HUD = require(script.Parent.UI.HUD)
local InventoryUI = require(script.Parent.UI.InventoryUI)

local InventoryController = {}

local LocalPlayer = Players.LocalPlayer
local character: Model?

local isOpen = false
local inventoryData: { items: { [number]: any }, hotbar: { [number]: number }, capacity: number, weight: number, maxWeight: number }?
local equipmentData: { [string]: string }?

function InventoryController.Initialize(char: Model)
	character = char
	InventoryController.SetupInput()
	InventoryController.SetupReplication()

	InventoryUI.Initialize()

	print("[InventoryController] Initialized")
end

function InventoryController.SetupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Constants.DEFAULT_KEYBINDS.Inventory then
			InventoryController.Toggle()
		end

		-- Hotbar 1-5
		if input.KeyCode == Enum.KeyCode.One then
			InventoryController.UseHotbarSlot(1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			InventoryController.UseHotbarSlot(2)
		elseif input.KeyCode == Enum.KeyCode.Three then
			InventoryController.UseHotbarSlot(3)
		elseif input.KeyCode == Enum.KeyCode.Four then
			InventoryController.UseHotbarSlot(4)
		elseif input.KeyCode == Enum.KeyCode.Five then
			InventoryController.UseHotbarSlot(5)
		end
	end)
end

function InventoryController.SetupReplication()
	ReplicatedStorage.Remotes.MatchRemotes.InventoryUpdate.OnClientEvent:Connect(function(data)
		InventoryController.OnInventoryUpdate(data)
	end)

	ReplicatedStorage.Remotes.MatchRemotes.GroundLootUpdate.OnClientEvent:Connect(function(data)
		InventoryController.OnGroundLootUpdate(data)
	end)
end

function InventoryController.Toggle()
	isOpen = not isOpen
	InventoryUI.SetVisible(isOpen)
	HUD.SetWeaponVisible(not isOpen)

	if isOpen then
		InventoryController.RequestInventory()
	end
end

function InventoryController.RequestInventory()
	-- Server pushes updates; this is for initial sync
	-- Could invoke a RemoteFunction if available
end

function InventoryController.OnInventoryUpdate(data)
	if data.inventory then
		inventoryData = data.inventory
		InventoryUI.UpdateInventory(inventoryData)
	end

	if data.equipment then
		equipmentData = data.equipment
		InventoryUI.UpdateEquipment(equipmentData)
	end
end

function InventoryController.OnGroundLootUpdate(data)
	-- Update nearby loot display
	InventoryUI.UpdateGroundLoot(data)
end

function InventoryController.SendAction(action: string, fromSlot: number, toSlot: number?, quantity: number?, itemId: string?)
	local payload = {
		Action = action,
		FromSlot = fromSlot,
		ToSlot = toSlot,
		Quantity = quantity,
		ItemId = itemId,
	}

	local result = ReplicatedStorage.Remotes.MatchRemotes.InventoryAction:InvokeServer(payload)
	return result and result.success
end

function InventoryController.MoveItem(fromSlot: number, toSlot: number)
	return InventoryController.SendAction("Move", fromSlot, toSlot)
end

function InventoryController.SplitStack(fromSlot: number, quantity: number)
	return InventoryController.SendAction("Split", fromSlot, nil, quantity)
end

function InventoryController.DropItem(fromSlot: number, quantity: number?)
	return InventoryController.SendAction("Drop", fromSlot, nil, quantity)
end

function InventoryController.UseItem(fromSlot: number)
	return InventoryController.SendAction("Use", fromSlot)
end

function InventoryController.EquipItem(fromSlot: number)
	return InventoryController.SendAction("Equip", fromSlot)
end

function InventoryController.UnequipItem(equipSlot: string)
	return InventoryController.SendAction("Unequip", 0, nil, nil, equipSlot)
end

function InventoryController.SetHotbar(hotbarSlot: number, inventorySlot: number?)
	return InventoryController.SendAction("Hotbar", hotbarSlot, inventorySlot)
end

function InventoryController.UseHotbarSlot(hotbarSlot: number)
	if not inventoryData or not inventoryData.hotbar then return end

	local invSlot = inventoryData.hotbar[hotbarSlot]
	if invSlot and inventoryData.items[invSlot] then
		local item = inventoryData.items[invSlot]
		-- If weapon, equip; if consumable, use
		local template = ReplicatedStorage.Modules.Inventory.ItemDefinitions
		local itemDef = template and require(template).Get(item.templateId)
		if itemDef and itemDef.Category == "Weapon" then
			InventoryController.EquipItem(invSlot)
		else
			InventoryController.UseItem(invSlot)
		end
	end
end

function InventoryController.GetInventoryData()
	return inventoryData
end

function InventoryController.IsOpen(): boolean
	return isOpen
end

function InventoryController.Cleanup()
	InventoryUI.SetVisible(false)
end

return InventoryController
