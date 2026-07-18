--[[
	EconomyService - Track kills, survival time, placement, calculate rewards,
	grant currency/XP via DataManager, broadcast MatchEnd with rewards.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local DataManager = require(Shared.DataManager)
local PlayerManager = require(script.Parent.PlayerManager)

local MatchRemotes = ReplicatedStorage.Remotes.MatchRemotes

local EconomyService = {}

export type MatchRewards = {
	Placement: number,
	Kills: number,
	Damage: number,
	SurvivalTime: number,
	CashEarned: number,
	CreditsEarned: number,
	XPEarned: number,
	RatingChange: number,
}

export type PlayerEconomyData = {
	Player: Player,
	Kills: number,
	Damage: number,
	SurvivalTime: number,
	Placement: number,
	Rewards: MatchRewards?,
}

local matchStartTime = 0
local matchEndTime = 0
local playerEconomyData: { [Player]: PlayerEconomyData } = {}
local isTracking = false

-- ==================== INITIALIZATION ====================

function EconomyService.Initialize()
	matchStartTime = os.clock()
	isTracking = true

	-- Track existing players
	for _, player in ipairs(Players:GetPlayers()) do
		EconomyService.OnPlayerJoin(player)
	end

	-- Connect events
	Players.PlayerAdded:Connect(EconomyService.OnPlayerJoin)
	Players.PlayerRemoving:Connect(EconomyService.OnPlayerLeave)

	print("[EconomyService] Initialized")
end

function EconomyService.OnPlayerJoin(player: Player)
	playerEconomyData[player] = {
		Player = player,
		Kills = 0,
		Damage = 0,
		SurvivalTime = 0,
		Placement = 0,
		Rewards = nil,
	}
end

function EconomyService.OnPlayerLeave(player: Player)
	-- Calculate partial rewards if they leave mid-match
	if isTracking and playerEconomyData[player] then
		EconomyService.CalculatePlayerRewards(player)
	end
	playerEconomyData[player] = nil
end

-- ==================== TRACKING ====================

function EconomyService.TrackKill(player: Player, damage: number?)
	local data = playerEconomyData[player]
	if not data then return end

	data.Kills += 1
	if damage then
		data.Damage += damage
	end

	-- Also track in DataManager for persistent stats
	DataManager.UpdateStats(player, { Kills = 1 })
end

function EconomyService.TrackDamage(player: Player, damage: number)
	local data = playerEconomyData[player]
	if not data then return end

	data.Damage += damage
end

function EconomyService.TrackPlacement(player: Player, placement: number)
	local data = playerEconomyData[player]
	if not data then return end

	data.Placement = placement
end

function EconomyService.TrackSurvivalTime(player: Player, survivalTime: number)
	local data = playerEconomyData[player]
	if not data then return end

	data.SurvivalTime = survivalTime
end

-- ==================== REWARD CALCULATION ====================

function EconomyService.CalculatePlayerRewards(player: Player): MatchRewards?
	local data = playerEconomyData[player]
	if not data then return nil end

	-- Get final values from PlayerManager if available
	local playerData = PlayerManager.GetPlayerData(player)
	if playerData then
		data.Kills = playerData.Kills
		data.Damage = playerData.Damage
		data.SurvivalTime = playerData.SurvivalTime
		if playerData.Placement then
			data.Placement = playerData.Placement
		end
	end

	-- Calculate survival time if not set
	if data.SurvivalTime == 0 then
		data.SurvivalTime = os.clock() - matchStartTime
	end

	-- Calculate placement if not set
	if data.Placement == 0 then
		data.Placement = PlayerManager.GetAliveCount() + 1
	end

	-- Base placement rewards
	local placementRewards = Constants.PLACEMENT_REWARDS[data.Placement]
	local cashEarned = 0
	local creditsEarned = 0
	local xpEarned = 0

	if placementRewards then
		cashEarned += placementRewards.cash
		creditsEarned += placementRewards.credits
		xpEarned += placementRewards.xp
	end

	-- Kill rewards
	cashEarned += data.Kills * Constants.KILL_REWARD_CASH

	-- Survival time rewards (per minute)
	local minutesSurvived = math.floor(data.SurvivalTime / 60)
	cashEarned += minutesSurvived * Constants.SURVIVAL_REWARD_CASH_PER_MIN

	-- Damage bonus (small)
	cashEarned += math.floor(data.Damage / 100) * 5

	-- Rating change (simplified Elo)
	local ratingChange = math.floor((10 - data.Placement) * 10 + data.Kills * 5)

	local rewards: MatchRewards = {
		Placement = data.Placement,
		Kills = data.Kills,
		Damage = data.Damage,
		SurvivalTime = data.SurvivalTime,
		CashEarned = cashEarned,
		CreditsEarned = creditsEarned,
		XPEarned = xpEarned,
		RatingChange = ratingChange,
	}

	data.Rewards = rewards
	return rewards
end

function EconomyService.CalculateAllRewards(): { [Player]: MatchRewards }
	local allRewards = {}

	for player, data in pairs(playerEconomyData) do
		local rewards = EconomyService.CalculatePlayerRewards(player)
		if rewards then
			allRewards[player] = rewards
		end
	end

	return allRewards
end

-- ==================== GRANTING ====================

function EconomyService.GrantRewards(player: Player): boolean
	local data = playerEconomyData[player]
	if not data or not data.Rewards then
		EconomyService.CalculatePlayerRewards(player)
	end

	if not data or not data.Rewards then return false end

	local rewards = data.Rewards

	-- Grant via DataManager
	DataManager.AddCash(player, rewards.CashEarned)
	DataManager.AddCredits(player, rewards.CreditsEarned)
	DataManager.AddXP(player, rewards.XPEarned)

	-- Update skill rating
	DataManager.UpdateStats(player, {
		SkillRating = rewards.RatingChange,
		DamageDealt = math.floor(rewards.Damage),
		PlayTime = math.floor(rewards.SurvivalTime),
	})

	-- Update wins/top10s
	if rewards.Placement == 1 then
		DataManager.UpdateStats(player, { Wins = 1 })
	end
	if rewards.Placement <= 10 then
		DataManager.UpdateStats(player, { Top10s = 1 })
	end

	-- Save profile
	DataManager.SaveProfile(player)

	print("[EconomyService] Granted rewards to", player.Name, "- Cash:", rewards.CashEarned, "Credits:", rewards.CreditsEarned, "XP:", rewards.XPEarned)

	return true
end

function EconomyService.GrantAllRewards()
	for player, _ in pairs(playerEconomyData) do
		EconomyService.GrantRewards(player)
	end
end

-- ==================== MATCH END ====================

function EconomyService.OnMatchEnd()
	matchEndTime = os.clock()
	isTracking = false

	-- Calculate all rewards
	local allRewards = EconomyService.CalculateAllRewards()

	-- Grant rewards to all players
	EconomyService.GrantAllRewards()

	-- Prepare broadcast data
	local broadcastData = {
		matchDuration = matchEndTime - matchStartTime,
		playerRewards = {},
		timestamp = os.clock(),
	}

	for player, rewards in pairs(allRewards) do
		broadcastData.playerRewards[player.Name] = {
			userId = player.UserId,
			placement = rewards.Placement,
			kills = rewards.Kills,
			damage = rewards.Damage,
			survivalTime = rewards.SurvivalTime,
			cashEarned = rewards.CashEarned,
			creditsEarned = rewards.CreditsEarned,
			xpEarned = rewards.XPEarned,
			ratingChange = rewards.RatingChange,
		}
	end

	-- Broadcast match end with rewards
	MatchRemotes.MatchEnd:FireAllClients(broadcastData)

	print("[EconomyService] Match ended, rewards distributed to", #Players:GetPlayers(), "players")

	return broadcastData
end

-- ==================== QUERIES ====================

function EconomyService.GetPlayerEconomyData(player: Player): PlayerEconomyData?
	return playerEconomyData[player]
end

function EconomyService.GetMatchDuration(): number
	if matchEndTime > 0 then
		return matchEndTime - matchStartTime
	end
	return os.clock() - matchStartTime
end

function EconomyService.GetLeaderboard(): { PlayerEconomyData }
	local leaderboard = {}
	for _, data in pairs(playerEconomyData) do
		table.insert(leaderboard, data)
	end

	table.sort(leaderboard, function(a, b)
		if a.Placement ~= b.Placement then
			return a.Placement < b.Placement
		end
		if a.Kills ~= b.Kills then
			return a.Kills > b.Kills
		end
		return a.Damage > b.Damage
	end)

	return leaderboard
end

-- ==================== LIFECYCLE ====================

function EconomyService.Reset()
	matchStartTime = os.clock()
	matchEndTime = 0
	isTracking = true
	playerEconomyData = {}

	for _, player in ipairs(Players:GetPlayers()) do
		EconomyService.OnPlayerJoin(player)
	end
end

function EconomyService.Stop()
	isTracking = false
end

return EconomyService
