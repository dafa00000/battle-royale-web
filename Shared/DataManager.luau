--[[
	DataManager - ProfileService wrapper for secure data persistence
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

-- ProfileService (loaded via Wally)
local ProfileService = require(ReplicatedStorage.SharedPackages.ProfileService)

local DataManager = {}

export type PlayerProfile = {
	UserId: number,
	Username: string,
	DisplayName: string,
	Stats: PlayerStats,
	Currency: Currency,
	Loadout: Loadout,
	Inventory: Inventory,
	SelectedSkin: string,
	OwnedSkins: { [string]: boolean },
	OwnedWeaponSkins: { [string]: boolean },
	OwnedEmotes: { [string]: boolean },
	Settings: PlayerSettings,
	LastLogin: number,
	Version: string,
}

export type PlayerStats = {
	Level: number,
	XP: number,
	SkillRating: number,
	Kills: number,
	Deaths: number,
	Wins: number,
	Top10s: number,
	PlayTime: number,
	Headshots: number,
	LongestShot: number,
	DamageDealt: number,
	Revives: number,
}

export type Currency = {
	Cash: number,
	Credits: number,
}

export type Loadout = {
	Primary: LoadoutSlot?,
	Secondary: LoadoutSlot?,
	Melee: LoadoutSlot?,
	Throw: LoadoutSlot?,
	Armor: LoadoutSlot?,
	Backpack: LoadoutSlot?,
}

export type LoadoutSlot = {
	WeaponId: string?,
	Attachments: { [string]: string },
	SkinId: string?,
}

export type Inventory = {
	Items: { [number]: InventoryItem },
	Hotbar: { [number]: number },
	Capacity: number,
	Weight: number,
	MaxWeight: number,
}

export type InventoryItem = {
	Id: string,
	TemplateId: string,
	Quantity: number,
	Durability: number?,
	Metadata: { [string]: any }?,
	Slot: number,
}

export type PlayerSettings = {
	Graphics: GraphicsSettings,
	Audio: AudioSettings,
	Controls: ControlSettings,
	Gameplay: GameplaySettings,
}

export type GraphicsSettings = {
	Quality: number,
	Resolution: Vector2,
	Fullscreen: boolean,
	VSync: boolean,
	FOV: number,
	Shadows: boolean,
	Particles: boolean,
}

export type AudioSettings = {
	MasterVolume: number,
	SFXVolume: number,
	MusicVolume: number,
	VoiceVolume: number,
	VoiceChat: boolean,
	PushToTalk: boolean,
}

export type ControlSettings = {
	Keybinds: { [string]: Enum.KeyCode },
	Sensitivity: number,
	ADSMultiplier: number,
	InvertY: boolean,
	Vibration: boolean,
}

export type GameplaySettings = {
	AutoReload: boolean,
	AutoPickup: boolean,
	ShowDamageNumbers: boolean,
	ShowKillFeed: boolean,
	CrosshairStyle: string,
	CrosshairColor: Color3,
}

-- ProfileStore
local ProfileStore = DataStoreService:GetDataStore("PlayerProfiles_" .. Constants.DATASTORE_VERSION)

local ProfileTemplate: PlayerProfile = {
	UserId = 0,
	Username = "",
	DisplayName = "",
	Stats = {
		Level = 1,
		XP = 0,
		SkillRating = 1000,
		Kills = 0,
		Deaths = 0,
		Wins = 0,
		Top10s = 0,
		PlayTime = 0,
		Headshots = 0,
		LongestShot = 0,
		DamageDealt = 0,
		Revives = 0,
	},
	Currency = {
		Cash = Constants.STARTING_CASH,
		Credits = Constants.STARTING_CREDITS,
	},
	Loadout = {},
	Inventory = {
		Items = {},
		Hotbar = {},
		Capacity = Constants.INVENTORY_SLOTS,
		Weight = 0,
		MaxWeight = 50,
	},
	SelectedSkin = "Default",
	OwnedSkins = { Default = true },
	OwnedWeaponSkins = {},
	OwnedEmotes = {},
	Settings = {
		Graphics = {
			Quality = 3,
			Resolution = Vector2.new(1920, 1080),
			Fullscreen = true,
			VSync = true,
			FOV = 80,
			Shadows = true,
			Particles = true,
		},
		Audio = {
			MasterVolume = 1,
			SFXVolume = 1,
			MusicVolume = 0.8,
			VoiceVolume = 1,
			VoiceChat = true,
			PushToTalk = true,
		},
		Controls = {
			Keybinds = Constants.DEFAULT_KEYBINDS,
			Sensitivity = 1,
			ADSMultiplier = 0.8,
			InvertY = false,
			Vibration = true,
		},
		Gameplay = {
			AutoReload = true,
			AutoPickup = true,
			ShowDamageNumbers = true,
			ShowKillFeed = true,
			CrosshairStyle = "Default",
			CrosshairColor = Color3.fromRGB(255, 255, 255),
		},
	},
	LastLogin = 0,
	Version = Constants.VERSION,
}

local Profiles: { [Player]: any } = {}
local ProfileLoaded: { [Player]: boolean } = {}

function DataManager.Initialize()
	-- Setup ProfileService
	ProfileStore = ProfileService.GetProfileStore("PlayerProfiles_" .. Constants.DATASTORE_VERSION, ProfileTemplate)
	
	-- Handle player joining
	Players.PlayerAdded:Connect(DataManager.OnPlayerAdded)
	
	-- Handle players already in game
	for _, player in ipairs(Players:GetPlayers()) do
		DataManager.OnPlayerAdded(player)
	end
	
	-- Auto-save interval
	task.spawn(function()
		while true do
			task.wait(60) -- Save every minute
			DataManager.SaveAllProfiles()
		end
	end)
	
	print("[DataManager] Initialized")
end

function DataManager.OnPlayerAdded(player: Player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId, "ForceLoad")
	
	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile() -- Fill missing fields from template
		
		profile:ListenToRelease(function()
			Profiles[player] = nil
			ProfileLoaded[player] = nil
			player:Kick("Profile released - please rejoin")
		end)
		
		if player:IsDescendantOf(Players) then
			Profiles[player] = profile
			ProfileLoaded[player] = true
			
			-- Update last login
			profile.Data.LastLogin = os.time()
			profile.Data.Username = player.Name
			profile.Data.DisplayName = player.DisplayName
			
			-- Fire loaded event
			ReplicatedStorage.Remotes.LobbyRemotes.ProfileLoaded:FireClient(player, profile.Data)
			
			print("[DataManager] Profile loaded for", player.Name)
		else
			profile:Release()
		end
	else
		player:Kick("Failed to load profile - please rejoin")
	end
end

function DataManager.OnPlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile then
		profile:Release()
	end
end

Players.PlayerRemoving:Connect(DataManager.OnPlayerRemoving)

function DataManager.GetProfile(player: Player): any?
	return Profiles[player]
end

function DataManager.GetData(player: Player): PlayerProfile?
	local profile = Profiles[player]
	return profile and profile.Data
end

function DataManager.UpdateData(player: Player, updater: (PlayerProfile) -> ()): boolean
	local profile = Profiles[player]
	if not profile then return false end
	
	updater(profile.Data)
	return true
end

function DataManager.SaveProfile(player: Player): boolean
	local profile = Profiles[player]
	if not profile then return false end
	
	profile:Save()
	return true
end

function DataManager.SaveAllProfiles()
	for player, profile in pairs(Profiles) do
		if profile and profile:IsActive() then
			profile:Save()
		end
	end
end

-- Currency operations
function DataManager.AddCash(player: Player, amount: number): boolean
	return DataManager.UpdateData(player, function(data)
		data.Currency.Cash = math.max(0, data.Currency.Cash + amount)
	end)
end

function DataManager.RemoveCash(player: Player, amount: number): boolean
	return DataManager.UpdateData(player, function(data)
		if data.Currency.Cash >= amount then
			data.Currency.Cash -= amount
			return true
		end
		return false
	end)
end

function DataManager.AddCredits(player: Player, amount: number): boolean
	return DataManager.UpdateData(player, function(data)
		data.Currency.Credits = math.max(0, data.Currency.Credits + amount)
	end)
end

function DataManager.GetCash(player: Player): number
	local data = DataManager.GetData(player)
	return data and data.Currency.Cash or 0
end

function DataManager.GetCredits(player: Player): number
	local data = DataManager.GetData(player)
	return data and data.Currency.Credits or 0
end

-- Stats operations
function DataManager.AddXP(player: Player, amount: number): boolean
	return DataManager.UpdateData(player, function(data)
		data.Stats.XP += amount
		-- Check level up
		local xpForNextLevel = data.Stats.Level * 1000
		if data.Stats.XP >= xpForNextLevel then
			data.Stats.Level += 1
			data.Stats.XP -= xpForNextLevel
			-- Reward for level up
			data.Currency.Cash += data.Stats.Level * 100
		end
	end)
end

function DataManager.UpdateStats(player: Player, stats: { [string]: number }): boolean
	return DataManager.UpdateData(player, function(data)
		for key, value in pairs(stats) do
			if data.Stats[key] ~= nil then
				data.Stats[key] += value
			end
		end
	end)
end

-- Inventory operations
function DataManager.GetInventory(player: Player): Inventory?
	local data = DataManager.GetData(player)
	return data and data.Inventory
end

function DataManager.UpdateInventory(player: Player, inventory: Inventory): boolean
	return DataManager.UpdateData(player, function(data)
		data.Inventory = inventory
	end)
end

-- Loadout operations
function DataManager.GetLoadout(player: Player): Loadout?
	local data = DataManager.GetData(player)
	return data and data.Loadout
end

function DataManager.UpdateLoadout(player: Player, loadout: Loadout): boolean
	return DataManager.UpdateData(player, function(data)
		data.Loadout = loadout
	end)
end

-- Skin operations
function DataManager.OwnsSkin(player: Player, skinId: string): boolean
	local data = DataManager.GetData(player)
	return data and data.OwnedSkins[skinId] or false
end

function DataManager.GrantSkin(player: Player, skinId: string): boolean
	return DataManager.UpdateData(player, function(data)
		data.OwnedSkins[skinId] = true
	end)
end

function DataManager.SetSelectedSkin(player: Player, skinId: string): boolean
	if not DataManager.OwnsSkin(player, skinId) then return false end
	return DataManager.UpdateData(player, function(data)
		data.SelectedSkin = skinId
	end)
end

-- Settings
function DataManager.GetSettings(player: Player): PlayerSettings?
	local data = DataManager.GetData(player)
	return data and data.Settings
end

function DataManager.UpdateSettings(player: Player, settings: PlayerSettings): boolean
	return DataManager.UpdateData(player, function(data)
		data.Settings = settings
	end)
end

-- Match rewards
function DataManager.ApplyMatchRewards(player: Player, placement: number, kills: number, damage: number, survivalTime: number): boolean
	return DataManager.UpdateData(player, function(data)
		-- Placement rewards
		local rewards = Constants.PLACEMENT_REWARDS[placement]
		if rewards then
			data.Currency.Cash += rewards.cash
			data.Currency.Credits += rewards.credits
			data.Stats.XP += rewards.xp
		end
		
		-- Kill rewards
		data.Currency.Cash += kills * Constants.KILL_REWARD_CASH
		
		-- Survival time rewards
		data.Currency.Cash += math.floor(survivalTime / 60) * Constants.SURVIVAL_REWARD_CASH_PER_MIN
		
		-- Stats
		data.Stats.Kills += kills
		data.Stats.DamageDealt += damage
		data.Stats.PlayTime += survivalTime
		
		-- Skill rating adjustment (simplified Elo)
		local ratingChange = math.floor((10 - placement) * 10 + kills * 5)
		data.Stats.SkillRating = math.max(0, data.Stats.SkillRating + ratingChange)
	end)
end

return DataManager