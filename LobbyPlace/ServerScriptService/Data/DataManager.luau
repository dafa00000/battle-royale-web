--[[
	Lobby DataManager - Re-exports Shared DataManager with lobby-specific helpers
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local DataManager = require(Shared.DataManager)

local LobbyDataManager = {}

function LobbyDataManager.GetProfile(player)
	return DataManager.GetProfile(player)
end

function LobbyDataManager.GetProfileData(player)
	local profile = DataManager.GetProfile(player)
	return profile and profile.Data or nil
end

function LobbyDataManager.SaveProfile(player)
	local profile = DataManager.GetProfile(player)
	if profile then
		profile:Save()
	end
end

function LobbyDataManager.GetDefaultLoadout()
	return {
		Primary = {
			WeaponId = "AK74",
			Attachments = {},
			SkinId = nil,
		},
		Secondary = {
			WeaponId = "P1911",
			Attachments = {},
			SkinId = nil,
		},
		Melee = {
			WeaponId = "Pan",
			Attachments = {},
			SkinId = nil,
		},
		Throw = {
			WeaponId = "Frag",
			Attachments = {},
			SkinId = nil,
		},
		Armor = {
			WeaponId = "Vest_Level1",
			Attachments = {},
			SkinId = nil,
		},
		Backpack = {
			WeaponId = "Backpack_Level1",
			Attachments = {},
			SkinId = nil,
		},
	}
end

function LobbyDataManager.AddCurrency(player, cash, credits)
	local profile = DataManager.GetProfile(player)
	if not profile then return false end
	
	profile.Data.Currency.Cash += cash or 0
	profile.Data.Currency.Credits += credits or 0
	profile:MarkDirty("Currency")
	return true
end

function LobbyDataManager.GetLeaderboard(stat, limit)
	-- Would query OrderedDataStore
	-- Stub for now
	return {}
end

print("[LobbyDataManager] Initialized")
return LobbyDataManager
