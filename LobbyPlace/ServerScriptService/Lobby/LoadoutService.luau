--[[
	LoadoutService - Edit and save player loadouts
	Validates weapons, attachments, and skins before saving
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local DataManager = require(Shared.DataManager)
local LobbyRemotes = ReplicatedStorage:WaitForChild("LobbyRemotes")

local LoadoutService = {}

-- Valid loadout slots
local VALID_SLOTS = {
	Primary = true,
	Secondary = true,
	Melee = true,
	Throw = true,
	Armor = true,
	Backpack = true,
}

-- Attachment compatibility cache
local weaponAttachments: { [string]: { [string]: { string } } } = {} -- WeaponId -> Slot -> { AttachmentIds }

-- ==================== VALIDATION ====================

local function IsValidWeapon(weaponId: string): boolean
	-- Check against ItemDefinitions (would be loaded from shared)
	-- For now, basic validation
	return weaponId and #weaponId > 0 and #weaponId <= 50
end

local function IsValidAttachment(attachmentId: string, weaponId: string, slot: string): boolean
	if not attachmentId or attachmentId == "" then
		return true -- Empty slot is valid
	end
	
	-- Check if weapon supports this attachment slot
	local slots = weaponAttachments[weaponId]
	if not slots then
		return true -- No data, allow (lenient)
	end
	
	local validAttachments = slots[slot]
	if not validAttachments then
		return false -- Slot not supported
	end
	
	return Util.TableContains(validAttachments, attachmentId)
end

local function IsValidSkin(skinId: string, itemId: string): boolean
	if not skinId or skinId == "" then
		return true -- Default skin
	end
	-- Would check OwnedSkins/OwnedWeaponSkins
	return true
end

-- ==================== LOADOUT MANAGEMENT ====================

function LoadoutService.GetLoadout(player: Player): DataManager.Loadout?
	local profile = DataManager.GetProfile(player)
	if not profile then
		return nil
	end
	return profile.Data.Loadout
end

function LoadoutService.UpdateLoadout(player: Player, slot: string, data: {
	WeaponId: string?,
	Attachments: { [string]: string }?,
	SkinId: string?,
}): (boolean, string)
	if not Util.ValidatePlayer(player) then
		return false, "Invalid player"
	end
	
	if not VALID_SLOTS[slot] then
		return false, "Invalid slot: " .. tostring(slot)
	end
	
	local profile = DataManager.GetProfile(player)
	if not profile then
		return false, "Profile not loaded"
	end
	
	local loadout = profile.Data.Loadout
	
	-- Validate weapon
	if data.WeaponId and not IsValidWeapon(data.WeaponId) then
		return false, "Invalid weapon"
	end
	
	-- Validate attachments
	if data.Attachments then
		for attachSlot, attachId in pairs(data.Attachments) do
			if not IsValidAttachment(attachId, data.WeaponId or "", attachSlot) then
				return false, string.format("Invalid attachment %s for slot %s", attachId, attachSlot)
			end
		end
	end
	
	-- Validate skin
	if data.SkinId and not IsValidSkin(data.SkinId, data.WeaponId or "") then
		return false, "Invalid or unowned skin"
	end
	
	-- Update loadout
	if not loadout[slot] then
		loadout[slot] = {
			WeaponId = nil,
			Attachments = {},
			SkinId = nil,
		}
	end
	
	local slotData = loadout[slot]
	
	if data.WeaponId ~= nil then
		slotData.WeaponId = data.WeaponId
	end
	if data.Attachments then
		slotData.Attachments = data.Attachments
	end
	if data.SkinId ~= nil then
		slotData.SkinId = data.SkinId
	end
	
	-- Mark dirty for save
	profile:MarkDirty("Loadout")
	
	-- Broadcast update
	LobbyRemotes.LoadoutUpdate:FireClient(player, {
		Slot = slot,
		Data = slotData,
	})
	
	print(string.format("[Loadout] %s updated %s slot", player.Name, slot))
	return true, "Loadout updated"
end

function LoadoutService.SetWeapon(player: Player, slot: string, weaponId: string?): (boolean, string)
	return LoadoutService.UpdateLoadout(player, slot, { WeaponId = weaponId })
end

function LoadoutService.SetAttachment(player: Player, slot: string, attachSlot: string, attachmentId: string?): (boolean, string)
	local loadout = LoadoutService.GetLoadout(player)
	if not loadout or not loadout[slot] then
		return false, "Slot not configured"
	end
	
	local attachments = Util.DeepCopy(loadout[slot].Attachments)
	attachments[attachSlot] = attachmentId
	
	return LoadoutService.UpdateLoadout(player, slot, { Attachments = attachments })
end

function LoadoutService.SetSkin(player: Player, slot: string, skinId: string?): (boolean, string)
	return LoadoutService.UpdateLoadout(player, slot, { SkinId = skinId })
end

function LoadoutService.ClearSlot(player: Player, slot: string): (boolean, string)
	if not VALID_SLOTS[slot] then
		return false, "Invalid slot"
	end
	
	local profile = DataManager.GetProfile(player)
	if not profile then
		return false, "Profile not loaded"
	end
	
	profile.Data.Loadout[slot] = nil
	profile:MarkDirty("Loadout")
	
	LobbyRemotes.LoadoutUpdate:FireClient(player, {
		Slot = slot,
		Data = nil,
	})
	
	return true, "Slot cleared"
end

function LoadoutService.ResetToDefault(player: Player): (boolean, string)
	local profile = DataManager.GetProfile(player)
	if not profile then
		return false, "Profile not loaded"
	end
	
	profile.Data.Loadout = DataManager.GetDefaultLoadout()
	profile:MarkDirty("Loadout")
	
	LobbyRemotes.LoadoutUpdate:FireClient(player, {
		Slot = "All",
		Data = profile.Data.Loadout,
	})
	
	return true, "Loadout reset to default"
end

-- ==================== VALIDATION FOR MATCH ====================

function LoadoutService.ValidateLoadoutForMatch(loadout: DataManager.Loadout): (boolean, string)
	-- Ensure at least one weapon
	local hasWeapon = false
	for _, slot in ipairs({ "Primary", "Secondary", "Melee" }) do
		if loadout[slot] and loadout[slot].WeaponId then
			hasWeapon = true
			break
		end
	end
	
	if not hasWeapon then
		return false, "No weapon equipped"
	end
	
	-- Validate each slot
	for slotName, slotData in pairs(loadout) do
		if slotData and slotData.WeaponId then
			if not IsValidWeapon(slotData.WeaponId) then
				return false, string.format("Invalid weapon in %s", slotName)
			end
			
			if slotData.Attachments then
				for attachSlot, attachId in pairs(slotData.Attachments) do
					if not IsValidAttachment(attachId, slotData.WeaponId, attachSlot) then
						return false, string.format("Invalid attachment in %s.%s", slotName, attachSlot)
					end
				end
			end
		end
	end
	
	return true, "Valid"
end

-- ==================== REMOTE HANDLERS ====================

LobbyRemotes.UpdateLoadout.OnServerInvoke = function(player, action, ...)
	if action == "SetWeapon" then
		return LoadoutService.SetWeapon(player, ...)
	elseif action == "SetAttachment" then
		return LoadoutService.SetAttachment(player, ...)
	elseif action == "SetSkin" then
		return LoadoutService.SetSkin(player, ...)
	elseif action == "ClearSlot" then
		return LoadoutService.ClearSlot(player, ...)
	elseif action == "Reset" then
		return LoadoutService.ResetToDefault(player)
	elseif action == "Get" then
		return LoadoutService.GetLoadout(player)
	end
	return false, "Unknown action"
end

-- ==================== INIT ====================

function LoadoutService.Initialize()
	-- Load attachment compatibility from ItemDefinitions
	-- This would be populated from shared item data
	print("[LoadoutService] Initialized")
end

LoadoutService.Initialize()
return LoadoutService
