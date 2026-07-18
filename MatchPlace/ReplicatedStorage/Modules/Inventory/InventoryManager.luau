--[[
	InventoryManager - Server-authoritative inventory system with replication
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage.Remotes
local MatchRemotes = Remotes.MatchRemotes
local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local ItemDefinitions = require(script.Parent.ItemDefinitions)

local InventoryManager = {}

export type InventoryItem = {
	id: string,           -- Instance ID
	templateId: string,   -- References ItemDefinitions
	quantity: number,
	durability: number?,  -- 0-100
	metadata: { [string]: any }?, -- Attachments, ammo count, etc.
	slot: number,         -- Inventory slot index
}

export type Inventory = {
	items: { [number]: InventoryItem }, -- slot -> item
	hotbar: { [number]: number },       -- hotbar slot -> inventory slot
	capacity: number,
	weight: number,
	maxWeight: number,
}

export type PlayerInventoryData = {
	inventory: Inventory,
	equipment: { [string]: string }, -- slot -> item instance id
}

local playerInventories: { [Player]: PlayerInventoryData } = {}
local groundLoot: { [string]: { item: InventoryItem, position: Vector3, expiry: number } } = {}

-- Initialize player inventory
function InventoryManager.InitializePlayer(player: Player)
	local data = DataManager.GetProfile(player)
	if not data then return end
	
	playerInventories[player] = {
		inventory = data.Data.Inventory or InventoryManager.CreateEmptyInventory(),
		equipment = data.Data.Equipment or {},
	}
	
	-- Send initial state to client
	InventoryManager.ReplicateInventory(player)
end

function InventoryManager.CreateEmptyInventory(): Inventory
	return {
		items = {},
		hotbar = {},
		capacity = Constants.INVENTORY_SLOTS,
		weight = 0,
		maxWeight = 50, -- kg
	}
end

function InventoryManager.GetInventory(player: Player): Inventory?
	return playerInventories[player] and playerInventories[player].inventory
end

function InventoryManager.GetEquipment(player: Player): { [string]: string }?
	return playerInventories[player] and playerInventories[player].equipment
end

-- ==================== ITEM OPERATIONS ====================

function InventoryManager.AddItem(player: Player, templateId: string, quantity: number?, metadata: { [string]: any }?): boolean
	local inventory = InventoryManager.GetInventory(player)
	if not inventory then return false end
	
	quantity = quantity or 1
	local template = ItemDefinitions.Get(templateId)
	if not template then return false end
	
	-- Check weight
	local itemWeight = template.Weight * quantity
	if inventory.weight + itemWeight > inventory.maxWeight then
		InventoryManager.Notify(player, "Inventory too heavy!")
		return false
	end
	
	-- Try stack first
	if template.StackSize and template.StackSize > 1 then
		for slot, item in pairs(inventory.items) do
			if item.templateId == templateId 
				and (not item.durability or item.durability == (metadata and metadata.durability or 100))
				and item.quantity < template.StackSize then
				
				local canAdd = math.min(quantity, template.StackSize - item.quantity)
				item.quantity += canAdd
				quantity -= canAdd
				inventory.weight += template.Weight * canAdd
				
				if quantity <= 0 then
					InventoryManager.ReplicateInventory(player)
					return true
				end
			end
		end
	end
	
	-- Find empty slots
	for i = 1, inventory.capacity do
		if not inventory.items[i] and quantity > 0 then
			local stackSize = template.StackSize and math.min(quantity, template.StackSize) or 1
			
			inventory.items[i] = {
				id = Util.GenerateUID(),
				templateId = templateId,
				quantity = stackSize,
				durability = metadata and metadata.durability or 100,
				metadata = metadata or {},
				slot = i,
			}
			
			inventory.weight += template.Weight * stackSize
			quantity -= stackSize
			
			if quantity <= 0 then break end
		end
	end
	
	-- Drop remaining if no space
	if quantity > 0 then
		InventoryManager.DropItem(player, templateId, quantity, metadata)
	end
	
	InventoryManager.ReplicateInventory(player)
	return true
end

function InventoryManager.RemoveItem(player: Player, slot: number, quantity: number?): boolean
	local inventory = InventoryManager.GetInventory(player)
	if not inventory then return false end
	
	local item = inventory.items[slot]
	if not item then return false end
	
	quantity = quantity or item.quantity
	quantity = math.min(quantity, item.quantity)
	
	item.quantity -= quantity
	inventory.weight -= ItemDefinitions.Get(item.templateId).Weight * quantity
	
	if item.quantity <= 0 then
		inventory.items[slot] = nil
		-- Clear hotbar reference
		for hbSlot, invSlot in pairs(inventory.hotbar) do
			if invSlot == slot then
				inventory.hotbar[hbSlot] = nil
			end
		end
	end
	
	InventoryManager.ReplicateInventory(player)
	return true
end

function InventoryManager.MoveItem(player: Player, fromSlot: number, toSlot: number): boolean
	local inventory = InventoryManager.GetInventory(player)
	if not inventory then return false end
	
	if fromSlot == toSlot then return true end
	
	local fromItem = inventory.items[fromSlot]
	local toItem = inventory.items[toSlot]
	
	if not fromItem then return false end
	
	-- Swap or stack
	if toItem and toItem.templateId == fromItem.templateId 
		and ItemDefinitions.Get(toItem.templateId).StackSize and ItemDefinitions.Get(toItem.templateId).StackSize > 1 then
		-- Try stack
		local template = ItemDefinitions.Get(fromItem.templateId)
		local space = template.StackSize - toItem.quantity
		if space > 0 then
			local moveQty = math.min(fromItem.quantity, space)
			toItem.quantity += moveQty
			fromItem.quantity -= moveQty
			if fromItem.quantity <= 0 then
				inventory.items[fromSlot] = nil
			end
		else
			-- Swap
			inventory.items[fromSlot], inventory.items[toSlot] = toItem, fromItem
		end
	else
		-- Swap
		inventory.items[fromSlot], inventory.items[toSlot] = toItem, fromItem
	end
	
	-- Update slot references
	if inventory.items[fromSlot] then inventory.items[fromSlot].slot = fromSlot end
	if inventory.items[toSlot] then inventory.items[toSlot].slot = toSlot end
	
	InventoryManager.ReplicateInventory(player)
	return true
end

function InventoryManager.SplitStack(player: Player, fromSlot: number, quantity: number): boolean
	local inventory = InventoryManager.GetInventory(player)
	if not inventory then return false end
	
	local item = inventory.items[fromSlot]
	if not item or item.quantity <= 1 then return false end
	
	quantity = math.min(quantity, item.quantity - 1)
	
	-- Find empty slot
	for i = 1, inventory.capacity do
		if not inventory.items[i] then
			inventory.items[i] = {
				id = Util.GenerateUID(),
				templateId = item.templateId,
				quantity = quantity,
				durability = item.durability,
				metadata = Util.DeepCopy(item.metadata),
				slot = i,
			}
			item.quantity -= quantity
			InventoryManager.ReplicateInventory(player)
			return true
		end
	end
	
	return false
end

function InventoryManager.SetHotbar(player: Player, hotbarSlot: number, inventorySlot: number?): boolean
	local inventory = InventoryManager.GetInventory(player)
	if not inventory then return false end
	
	if hotbarSlot < 1 or hotbarSlot > Constants.HOTBAR_SLOTS then return false end
	
	if inventorySlot then
		if inventorySlot < 1 or inventorySlot > inventory.capacity then return false end
		if not inventory.items[inventorySlot] then return false end
		inventory.hotbar[hotbarSlot] = inventorySlot
	else
		inventory.hotbar[hotbarSlot] = nil
	end
	
	InventoryManager.ReplicateInventory(player)
	return true
end

-- ==================== EQUIPMENT ====================

function InventoryManager.EquipItem(player: Player, slot: number): boolean
	local inventory = InventoryManager.GetInventory(player)
	local equipment = InventoryManager.GetEquipment(player)
	if not inventory or not equipment then return false end
	
	local item = inventory.items[slot]
	if not item then return false end
	
	local template = ItemDefinitions.Get(item.templateId)
	if not template or template.Category ~= "Weapon" and template.Category ~= "Armor" then return false end
	
	local equipSlot = template.Category == "Weapon" and "Primary" or template.SubCategory
	
	-- Unequip current
	if equipment[equipSlot] then
		InventoryManager.UnequipItem(player, equipSlot)
	end
	
	equipment[equipSlot] = item.id
	
	-- Apply effects (armor, weapon stats)
	InventoryManager.ApplyEquipmentEffects(player, item, true)
	
	InventoryManager.ReplicateInventory(player)
	InventoryManager.ReplicateEquipment(player)
	return true
end

function InventoryManager.UnequipItem(player: Player, equipSlot: string): boolean
	local equipment = InventoryManager.GetEquipment(player)
	if not equipment then return false end
	
	local itemId = equipment[equipSlot]
	if not itemId then return false end
	
	-- Find item in inventory
	local inventory = InventoryManager.GetInventory(player)
	local item = nil
	for _, invItem in pairs(inventory.items) do
		if invItem.id == itemId then
			item = invItem
			break
		end
	end
	
	if item then
		InventoryManager.ApplyEquipmentEffects(player, item, false)
	end
	
	equipment[equipSlot] = nil
	
	InventoryManager.ReplicateInventory(player)
	InventoryManager.ReplicateEquipment(player)
	return true
end

function InventoryManager.ApplyEquipmentEffects(player: Player, item: InventoryItem, apply: boolean)
	-- Apply armor, weapon stats, etc.
	-- This would integrate with Character/Combat systems
end

-- ==================== GROUND LOOT ====================

function InventoryManager.SpawnGroundLoot(position: Vector3, templateId: string, quantity: number?, metadata: { [string]: any }?): string
	local template = ItemDefinitions.Get(templateId)
	if not template then return "" end
	
	local lootId = Util.GenerateUID()
	
	groundLoot[lootId] = {
		item = {
			id = lootId,
			templateId = templateId,
			quantity = quantity or 1,
			durability = metadata and metadata.durability or 100,
			metadata = metadata or {},
			slot = 0,
		},
		position = position,
		expiry = os.clock() + 300, -- 5 min despawn
	}
	
	-- Replicate to nearby clients
	MatchRemotes.LootDrop:FireAllClients({
		lootId = lootId,
		templateId = templateId,
		quantity = quantity or 1,
		position = position,
		rarity = template.Rarity,
	})
	
	-- Auto cleanup
	task.delay(300, function()
		if groundLoot[lootId] then
			InventoryManager.DespawnGroundLoot(lootId)
		end
	end)
	
	return lootId
end

function InventoryManager.PickupGroundLoot(player: Player, lootId: string): boolean
	local loot = groundLoot[lootId]
	if not loot then return false end
	
	-- Check distance
	local character = player.Character
	if not character then return false end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end
	
	if (rootPart.Position - loot.position).Magnitude > 5 then
		return false -- Too far
	end
	
	-- Add to inventory
	local success = InventoryManager.AddItem(player, loot.item.templateId, loot.item.quantity, loot.item.metadata)
	
	if success then
		InventoryManager.DespawnGroundLoot(lootId)
	end
	
	return success
end

function InventoryManager.DespawnGroundLoot(lootId: string)
	groundLoot[lootId] = nil
	MatchRemotes.LootPickup:FireAllClients({ lootId = lootId })
end

function InventoryManager.DropItem(player: Player, templateId: string, quantity: number, metadata: { [string]: any }?): boolean
	local character = player.Character
	if not character then return false end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end
	
	-- Drop in front of player
	local dropPos = rootPart.Position + rootPart.CFrame.LookVector * 3 + Vector3.new(0, 1, 0)
	
	InventoryManager.SpawnGroundLoot(dropPos, templateId, quantity, metadata)
	return true
end

-- ==================== REPLICATION ====================

function InventoryManager.ReplicateInventory(player: Player)
	local data = playerInventories[player]
	if not data then return end
	
	MatchRemotes.InventoryUpdate:FireClient(player, {
		inventory = data.inventory,
		equipment = data.equipment,
	})
end

function InventoryManager.ReplicateEquipment(player: Player)
	local data = playerInventories[player]
	if not data then return end
	
	MatchRemotes.InventoryUpdate:FireClient(player, {
		equipment = data.equipment,
	})
end

function InventoryManager.Notify(player: Player, message: string)
	Remotes.LobbyRemotes.Notification:FireClient(player, {
		message = message,
		type = "warning",
	})
end

-- ==================== REMOTE HANDLERS ====================

MatchRemotes.InventoryAction.OnServerInvoke = function(player: Player, payload: {
	action: string,
	fromSlot: number,
	toSlot: number?,
	quantity: number?,
	itemId: string?,
}): { success: boolean, error: string? }
	
	local inventory = InventoryManager.GetInventory(player)
	if not inventory then return { success = false, error = "No inventory" } end
	
	if payload.action == "Move" then
		return { success = InventoryManager.MoveItem(player, payload.fromSlot, payload.toSlot or 0) }
	elseif payload.action == "Split" then
		return { success = InventoryManager.SplitStack(player, payload.fromSlot, payload.quantity or 1) }
	elseif payload.action == "Drop" then
		local item = inventory.items[payload.fromSlot]
		if item then
			return { success = InventoryManager.DropItem(player, item.templateId, payload.quantity or item.quantity, item.metadata) }
		end
		return { success = false, error = "Item not found" }
	elseif payload.action == "Use" then
		-- Consumables, etc.
		return { success = InventoryManager.UseItem(player, payload.fromSlot) }
	elseif payload.action == "Equip" then
		return { success = InventoryManager.EquipItem(player, payload.fromSlot) }
	elseif payload.action == "Unequip" then
		return { success = InventoryManager.UnequipItem(player, payload.fromSlot) }
	elseif payload.action == "Hotbar" then
		return { success = InventoryManager.SetHotbar(player, payload.fromSlot, payload.toSlot) }
	end
	
	return { success = false, error = "Unknown action" }
end

MatchRemotes.LootPickup.OnServerInvoke = function(player: Player, lootId: string): { success: boolean }
	return { success = InventoryManager.PickupGroundLoot(player, lootId) }
end

-- ==================== CLEANUP ====================

Players.PlayerRemoving:Connect(function(player)
	playerInventories[player] = nil
end)

return InventoryManager