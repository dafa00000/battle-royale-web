--[[
	MatchDataStore - Save match results, load history, update leaderboards
	Uses DataStore with OrderedDataStore for leaderboards
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local DataManager = require(Shared.DataManager)

local MatchDataStore = {}

-- DataStores
local matchHistoryStore = DataStoreService:GetDataStore(Constants.MATCH_DATA_KEY .. Constants.DATASTORE_VERSION)
local leaderboardStore = DataStoreService:GetOrderedDataStore(Constants.LEADERBOARD_KEY .. Constants.DATASTORE_VERSION)

-- ==================== SAVE MATCH RESULT ====================

function MatchDataStore.SaveMatchResult(matchData)
	local key = Constants.MATCH_DATA_KEY .. matchData.MatchId
	
	local success, err = pcall(function()
		matchHistoryStore:SetAsync(key, matchData)
	end)
	
	if not success then
		warn("[MatchDataStore] Failed to save match:", err)
		-- Retry with exponential backoff
		task.delay(5, function()
			MatchDataStore.SaveMatchResult(matchData)
		end)
		return false
	end
	
	-- Update leaderboards
	MatchDataStore.UpdateLeaderboards(matchData)
	
	print(string.format("[MatchDataStore] Saved match %s", matchData.MatchId))
	return true
end

function MatchDataStore.UpdateLeaderboards(matchData)
	-- Update wins leaderboard
	for _, squad in pairs(matchData.Squads or {}) do
		if matchData.Winner == squad.SquadId then
			for userId, _ in pairs(squad.Members) do
				MatchDataStore.IncrementStat(userId, "Wins", 1)
			end
		end
	end
	
	-- Update kills, top10s, etc.
	for userId, playerData in pairs(matchData.Players or {}) do
		if playerData.Kills > 0 then
			MatchDataStore.IncrementStat(userId, "Kills", playerData.Kills)
		end
		if playerData.Placement and playerData.Placement <= 10 then
			MatchDataStore.IncrementStat(userId, "Top10s", 1)
		end
	end
end

function MatchDataStore.IncrementStat(userId, statName, amount)
	local key = "Leaderboard_" .. statName .. "_" .. userId
	local success, current = pcall(function()
		return leaderboardStore:GetAsync(key) or 0
	end)
	
	local newValue = (current or 0) + amount
	
	pcall(function()
		leaderboardStore:SetAsync(key, newValue)
	end)
end

-- ==================== LOAD HISTORY ====================

function MatchDataStore.LoadPlayerHistory(userId, limit)
	limit = limit or 20
	
	local prefix = Constants.MATCH_DATA_KEY .. "Match_"
	local results = {}
	
	local success, pages = pcall(function()
		return matchHistoryStore:ListKeysAsync(prefix, limit)
	end)
	
	if success and pages then
		local keys = pages:GetCurrentPage()
		for _, keyInfo in ipairs(keys) do
			local matchData = matchHistoryStore:GetAsync(keyInfo.KeyName)
			if matchData and matchData.Players and matchData.Players[userId] then
				table.insert(results, matchData)
			end
		end
	end
	
	return results
end

-- ==================== LEADERBOARD QUERIES ====================

function MatchDataStore.GetTopPlayers(statName, limit, page)
	limit = limit or 50
	page = page or 1
	
	local keyPrefix = "Leaderboard_" .. statName .. "_"
	
	local success, pages = pcall(function()
		return leaderboardStore:GetSortedAsync(false, limit * page)
	end)
	
	if not success then
		return {}
	end
	
	local results = {}
	local currentPage = pages:GetCurrentPage()
	
	for i = (page - 1) * limit + 1, math.min(page * limit, #currentPage) do
		local entry = currentPage[i]
		if entry then
			table.insert(results, {
				Rank = i,
				UserId = tonumber(entry.key:match("_(%d+)$")),
				Value = entry.value,
			})
		end
	end
	
	return results
end

function MatchDataStore.GetPlayerRank(userId, statName)
	local key = "Leaderboard_" .. statName .. "_" .. userId
	
	local success, rank = pcall(function()
		return leaderboardStore:GetRankAsync(key)
	end)
	
	if success then
		return rank
	end
	return 0
end

-- ==================== MATCH STATS AGGREGATION ====================

function MatchDataStore.GetPlayerCareerStats(userId)
	local history = MatchDataStore.LoadPlayerHistory(userId, 100)
	
	local stats = {
		Matches = #history,
		Wins = 0,
		Top10s = 0,
		Kills = 0,
		Damage = 0,
		BestPlacement = 101,
		AvgPlacement = 0,
		TotalPlayTime = 0,
		Headshots = 0,
		LongestShot = 0,
	}
	
	local totalPlacement = 0
	
	for _, match in ipairs(history) do
		local playerData = match.Players[userId]
		if not playerData then continue end
		
		if match.Winner == match.Squads[playerData.SquadId] then
			stats.Wins += 1
		end
		
		if playerData.Placement then
			stats.BestPlacement = math.min(stats.BestPlacement, playerData.Placement)
			totalPlacement += playerData.Placement
			
			if playerData.Placement <= 10 then
				stats.Top10s += 1
			end
		end
		
		stats.Kills += playerData.Kills or 0
		stats.Damage += playerData.Damage or 0
		stats.TotalPlayTime += playerData.SurvivalTime or 0
	end
	
	if stats.Matches > 0 then
		stats.AvgPlacement = totalPlacement / stats.Matches
		stats.KD = stats.Deaths > 0 and stats.Kills / stats.Deaths or stats.Kills
		stats.WinRate = stats.Wins / stats.Matches
	end
	
	return stats
end

-- ==================== CLEANUP ====================

function MatchDataStore.CleanupOldMatches(daysToKeep)
	daysToKeep = daysToKeep or 30
	local cutoff = os.time() - (daysToKeep * 86400)
	
	-- This would use ListKeysAsync and delete old entries
	-- Implementation depends on DataStore limits
	print("[MatchDataStore] Cleanup old matches (not fully implemented)")
end

print("[MatchDataStore] Initialized")
return MatchDataStore