--[[
	LootSpawner - Spawn loot in predefined zones/tables, respawn timer, rarity weights,
	world model + pickup prompt. Broadcast GroundLootUpdate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local ItemDefinitions = require(ReplicatedStorage.Modules.Inventory.ItemDefinitions)

local MatchRemotes = ReplicatedStorage.Remotes.MatchRemotes

local LootSpawner = {}

export type LootItem = {
	Id: string,
	ItemId: string,
	Quantity: number,
	Rarity: string,
	Position: Vector3,
	SpawnTime: number,
	RespawnTime: number,
	IsSpawned: boolean,
	Model: Model?,
	ZoneName: string,
}

export type LootZone = {
	Name: string,
	Center: Vector3,
	Radius: number,
	MinItems: number,
	MaxItems: number,
	RespawnTime: number,
	Tier: number,
	SpawnedItems: { string },
}

-- Rarity weights for loot generation
local RARITY_WEIGHTS = {
	Common = 40,
	Uncommon = 30,
	Rare = 15,
	Epic = 8,
	Legendary = 5,
	Mythic = 2,
}

-- Zone templates with loot tables
local ZONE_TEMPLATES = {
	{
		Name = "MilitaryBase",
		MinItems = 15,
		MaxItems = 25,
		RespawnTime = 300,
		Tier = 3,
		LootTable = {
			Weapon = { AR = 30, SR = 15, SMG = 20, Pistol = 10, Shotgun = 5 },
			Ammo = { Ammo_5_56 = 30, Ammo_7_62 = 20, Ammo_9mm = 25, Ammo_12ga = 10 },
			Med = { Medkit = 10, Bandage = 30, EnergyDrink = 20, Painkiller = 15 },
			Armor = { Helmet_Lv2 = 10, Vest_Lv2 = 10, Helmet_Lv3 = 5, Vest_Lv3 = 5 },
			Throw = { FragGrenade = 10, SmokeGrenade = 10, Flashbang = 5 },
		},
	},
	{
		Name = "City",
		MinItems = 10,
		MaxItems = 20,
		RespawnTime = 240,
		Tier = 2,
		LootTable = {
			Weapon = { SMG = 25, Pistol = 30, AR = 15, Shotgun = 15 },
			Ammo = { Ammo_9mm = 35, Ammo_45acp = 25, Ammo_12ga = 20 },
			Med = { Bandage = 35, EnergyDrink = 25, Medkit = 5 },
			Armor = { Helmet_Lv1 = 20, Vest_Lv1 = 20, Helmet_Lv2 = 5, Vest_Lv2 = 5 },
			Attachment = { RedDot = 15, Holo = 10, Suppressor = 5 },
		},
	},
	{
		Name = "Village",
		MinItems = 5,
		MaxItems = 12,
		RespawnTime = 180,
		Tier = 1,
		LootTable = {
			Weapon = { Pistol = 40, SMG = 20, Shotgun = 20 },
			Ammo = { Ammo_9mm = 40, Ammo_45acp = 30 },
			Med = { Bandage = 50, EnergyDrink = 20 },
			Armor = { Helmet_Lv1 = 30, Vest_Lv1 = 30 },
		},
	},
}

-- State
local lootZones: { LootZone } = {}
local groundLoot: { [string]: LootItem } = {}
local lootFolder: Folder = nil
local nextLootId = 1

-- ==================== INITIALIZATION ====================

function LootSpawner.Initialize()
	lootFolder = Instance.new("Folder")
	lootFolder.Name = "GroundLoot"
	lootFolder.Parent = Workspace

	-- Generate loot zones across map
	LootSpawner.GenerateLootZones()

	-- Spawn initial loot
	LootSpawner.SpawnAllLoot()

	-- Start respawn checker
	task.spawn(LootSpawner.RespawnLoop)

	print("[LootSpawner] Initialized with", #lootZones, "zones")
end

function LootSpawner.GenerateLootZones()
	local mapRadius = Constants.MAP_RADIUS

	-- Generate zones at key locations
	local zoneLocations = {
		{ name = "MilitaryBase", pos = Vector3.new(mapRadius * 0.3, 0, mapRadius * 0.2), radius = 200 },
		{ name = "City", pos = Vector3.new(-mapRadius * 0.2, 0, mapRadius * 0.3), radius = 300 },
		{ name = "Village", pos = Vector3.new(mapRadius * 0.1, 0, -mapRadius * 0.4), radius = 150 },
		{ name = "Village", pos = Vector3.new(-mapRadius * 0.5, 0, -mapRadius * 0.1), radius = 120 },
		{ name = "City", pos = Vector3.new(mapRadius * 0.6, 0, -mapRadius * 0.5), radius = 250 },
	}

	for _, loc in ipairs(zoneLocations) do
		-- Find matching template
		local template = nil
		for _, t in ipairs(ZONE_TEMPLATES) do
			if t.Name == loc.name then
				template = t
				break
			end
		end

		if template then
			table.insert(lootZones, {
				Name = loc.name .. "_" .. #lootZones,
				Center = loc.pos,
				Radius = loc.radius,
				MinItems = template.MinItems,
				MaxItems = template.MaxItems,
				RespawnTime = template.RespawnTime,
				Tier = template.Tier,
				LootTable = template.LootTable,
				SpawnedItems = {},
			})
		end
	end
end

-- ==================== LOOT SPAWNING ====================

function LootSpawner.SpawnAllLoot()
	for _, zone in ipairs(lootZones) do
		LootSpawner.SpawnLootInZone(zone)
	end

	-- Broadcast initial loot state
	LootSpawner.BroadcastGroundLoot()
end

function LootSpawner.SpawnLootInZone(zone: LootZone)
	local itemCount = math.random(zone.MinItems, zone.MaxItems)
	local spawned = 0
	local attempts = 0
	local maxAttempts = itemCount * 5

	while spawned < itemCount and attempts < maxAttempts do
		attempts += 1

		-- Random position in zone
		local angle = math.random() * math.pi * 2
		local dist = math.random() * zone.Radius
		local pos = zone.Center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

		-- Find ground
		local rayOrigin = pos + Vector3.new(0, 50, 0)
		local rayDirection = Vector3.new(0, -100, 0)
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { lootFolder }

		local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
		if result then
			local groundPos = result.Position + Vector3.new(0, 0.5, 0)

			-- Check minimum distance from other loot
			local tooClose = false
			for _, itemId in ipairs(zone.SpawnedItems) do
				local item = groundLoot[itemId]
				if item and item.IsSpawned then
					if (item.Position - groundPos).Magnitude < 3 then
						tooClose = true
						break
					end
				end
			end

			if not tooClose then
				local lootItem = LootSpawner.GenerateLootItem(zone, groundPos)
				if lootItem then
					LootSpawner.SpawnLootModel(lootItem)
					table.insert(zone.SpawnedItems, lootItem.Id)
					groundLoot[lootItem.Id] = lootItem
					spawned += 1
				end
			end
		end
	end
end

function LootSpawner.GenerateLootItem(zone: LootZone, position: Vector3): LootItem?
	-- Pick category
	local categories = {}
	for category, _ in pairs(zone.LootTable) do
		table.insert(categories, category)
	end
	if #categories == 0 then return nil end

	local category = categories[math.random(#categories)]
	local items = zone.LootTable[category]

	-- Pick specific item
	local itemId = Util.WeightedRandom(items)
	if not itemId then return nil end

	-- Get item definition for rarity
	local itemDef = ItemDefinitions.GetItem(itemId)
	local rarity = itemDef and itemDef.Rarity or "Common"

	-- Determine quantity
	local quantity = 1
	if category == "Ammo" then
		quantity = math.random(20, 60)
	elseif category == "Med" then
		quantity = math.random(1, 3)
	end

	local lootId = "Loot_" .. nextLootId
	nextLootId += 1

	return {
		Id = lootId,
		ItemId = itemId,
		Quantity = quantity,
		Rarity = rarity,
		Position = position,
		SpawnTime = os.clock(),
		RespawnTime = zone.RespawnTime,
		IsSpawned = true,
		Model = nil,
		ZoneName = zone.Name,
	}
end

function LootSpawner.SpawnLootModel(lootItem: LootItem)
	-- Create world model
	local model = Instance.new("Model")
	model.Name = lootItem.Id

	local part = Instance.new("Part")
	part.Name = "LootPart"
	part.Size = Vector3.new(1.5, 0.5, 1.5)
	part.Position = lootItem.Position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = true
	part.BrickColor = BrickColor.new(Util.GetRarityColor(lootItem.Rarity))
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model

	-- Add highlight for visibility
	local highlight = Instance.new("Highlight")
	highlight.Name = "LootHighlight"
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0.3
	highlight.OutlineColor = Util.GetRarityColor(lootItem.Rarity)
	highlight.FillColor = Util.GetRarityColor(lootItem.Rarity)
	highlight.Parent = model

	-- Add proximity prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ObjectText = lootItem.ItemId
	prompt.ActionText = "Pick up"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	-- Handle pickup
	prompt.Triggered:Connect(function(player)
		LootSpawner.OnLootPickup(player, lootItem.Id)
	end)

	model.Parent = lootFolder
	lootItem.Model = model
end

-- ==================== PICKUP ====================

function LootSpawner.OnLootPickup(player: Player, lootId: string)
	local lootItem = groundLoot[lootId]
	if not lootItem or not lootItem.IsSpawned then return end

	-- Validate distance
	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if (root.Position - lootItem.Position).Magnitude > 12 then return end

	-- Add to inventory (via InventoryManager if available)
	-- For now, just mark as picked up
	lootItem.IsSpawned = false
	lootItem.PickedUpBy = player
	lootItem.PickupTime = os.clock()

	-- Remove model
	if lootItem.Model then
		lootItem.Model:Destroy()
		lootItem.Model = nil
	end

	-- Broadcast pickup
	MatchRemotes.LootDrop:FireAllClients({
		action = "PickedUp",
		lootId = lootId,
		player = player.Name,
		playerUserId = player.UserId,
		itemId = lootItem.ItemId,
		quantity = lootItem.Quantity,
	})

	-- Update ground loot
	LootSpawner.BroadcastGroundLoot()

	-- Schedule respawn
	task.delay(lootItem.RespawnTime, function()
		LootSpawner.RespawnLootItem(lootId)
	end)
end

function LootSpawner.RespawnLootItem(lootId: string)
	local lootItem = groundLoot[lootId]
	if not lootItem then return end

	-- Find zone
	local zone = nil
	for _, z in ipairs(lootZones) do
		if z.Name == lootItem.ZoneName then
			zone = z
			break
		end
	end

	if zone then
		-- Generate new item at same position
		local newItem = LootSpawner.GenerateLootItem(zone, lootItem.Position)
		if newItem then
			newItem.Id = lootId -- Keep same ID for tracking
			LootSpawner.SpawnLootModel(newItem)
			groundLoot[lootId] = newItem
			LootSpawner.BroadcastGroundLoot()
		end
	end
end

-- ==================== RESPAWN LOOP ====================

function LootSpawner.RespawnLoop()
	while true do
		task.wait(10) -- Check every 10 seconds

		local now = os.clock()
		for _, zone in ipairs(lootZones) do
			-- Count active items in zone
			local activeCount = 0
			for _, itemId in ipairs(zone.SpawnedItems) do
				local item = groundLoot[itemId]
				if item and item.IsSpawned then
					activeCount += 1
				end
			end

			-- Respawn if below minimum
			if activeCount < zone.MinItems then
				local toSpawn = math.min(zone.MinItems - activeCount, 3)
				for _ = 1, toSpawn do
					local angle = math.random() * math.pi * 2
					local dist = math.random() * zone.Radius
					local pos = zone.Center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

					local rayOrigin = pos + Vector3.new(0, 50, 0)
					local rayDirection = Vector3.new(0, -100, 0)
					local rayParams = RaycastParams.new()
					rayParams.FilterType = Enum.RaycastFilterType.Exclude
					rayParams.FilterDescendantsInstances = { lootFolder }

					local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
					if result then
						local groundPos = result.Position + Vector3.new(0, 0.5, 0)
						local lootItem = LootSpawner.GenerateLootItem(zone, groundPos)
						if lootItem then
							LootSpawner.SpawnLootModel(lootItem)
							table.insert(zone.SpawnedItems, lootItem.Id)
							groundLoot[lootItem.Id] = lootItem
						end
					end
				end

				LootSpawner.BroadcastGroundLoot()
			end
		end
	end
end

-- ==================== BROADCAST ====================

function LootSpawner.BroadcastGroundLoot()
	local lootList = {}
	for lootId, item in pairs(groundLoot) do
		if item.IsSpawned then
			table.insert(lootList, {
				id = lootId,
				itemId = item.ItemId,
				quantity = item.Quantity,
				rarity = item.Rarity,
				position = item.Position,
			})
		end
	end

	MatchRemotes.GroundLootUpdate:FireAllClients({
		action = "FullUpdate",
		loot = lootList,
		timestamp = os.clock(),
	})
end

function LootSpawner.BroadcastLootToPlayer(player: Player)
	local lootList = {}
	for lootId, item in pairs(groundLoot) do
		if item.IsSpawned then
			table.insert(lootList, {
				id = lootId,
				itemId = item.ItemId,
				quantity = item.Quantity,
				rarity = item.Rarity,
				position = item.Position,
			})
		end
	end

	MatchRemotes.GroundLootUpdate:FireClient(player, {
		action = "FullUpdate",
		loot = lootList,
		timestamp = os.clock(),
	})
end

-- ==================== REMOTE HANDLERS ====================

MatchRemotes.LootPickup.OnServerInvoke = function(player: Player, lootId: string)
	local lootItem = groundLoot[lootId]
	if not lootItem or not lootItem.IsSpawned then
		return { success = false, message = "Loot not available" }
	end

	-- Validate distance
	local character = player.Character
	if not character then
		return { success = false, message = "No character" }
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return { success = false, message = "No root part" }
	end

	if (root.Position - lootItem.Position).Magnitude > 12 then
		return { success = false, message = "Too far away" }
	end

	-- Pickup
	LootSpawner.OnLootPickup(player, lootId)
	return { success = true, itemId = lootItem.ItemId, quantity = lootItem.Quantity }
end

-- ==================== QUERIES ====================

function LootSpawner.GetLootItem(lootId: string): LootItem?
	return groundLoot[lootId]
end

function LootSpawner.GetAllLoot(): { [string]: LootItem }
	return groundLoot
end

function LootSpawner.GetLootInRadius(center: Vector3, radius: number): { LootItem }
	local results = {}
	for _, item in pairs(groundLoot) do
		if item.IsSpawned and (item.Position - center).Magnitude <= radius then
			table.insert(results, item)
		end
	end
	return results
end

function LootSpawner.GetZoneCount(): number
	return #lootZones
end

function LootSpawner.GetActiveLootCount(): number
	local count = 0
	for _, item in pairs(groundLoot) do
		if item.IsSpawned then
			count += 1
		end
	end
	return count
end

return LootSpawner
