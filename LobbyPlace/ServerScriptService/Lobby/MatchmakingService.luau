--[[
	MatchmakingService - MemoryStore queue + TeleportService to MatchPlace
	Handles solo/duo/squad matchmaking with ready check and countdown
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local LobbyRemotes = ReplicatedStorage:WaitForChild("LobbyRemotes")

local MatchmakingService = {}

-- Types
export type QueueEntry = {
	UserId: number,
	SquadId: string?,
	Map: string,
	JoinedAt: number,
	Ready: boolean,
}

export type QueueState = "Idle" | "Queued" | "Found" | "Starting" | "Teleporting"

-- State
local queue: { [number]: QueueEntry } = {} -- UserId -> QueueEntry
local playerStates: { [Player]: QueueState } = {}
local matchFoundCallbacks: { (string, { QueueEntry }) -> () } = {}
local queueStore = MemoryStoreService:GetSortedMap("MatchmakingQueue")
local MATCH_TELEPORT_KEY = "MatchTeleport_"

-- Config
local MAX_QUEUE_TIME = 300 -- 5 minutes
local READY_CHECK_DURATION = 15
local TELEPORT_RETRY_DELAY = 2
local MAX_TELEPORT_RETRIES = 3

-- ==================== CORE QUEUE ====================

function MatchmakingService.JoinQueue(player: Player, squadId: string?, map: string?): (boolean, string)
	if not Util.ValidatePlayer(player) then
		return false, "Invalid player"
	end
	
	local userId = player.UserId
	local state = playerStates[player]
	
	if state == "Queued" then
		return false, "Already in queue"
	end
	if state == "Found" or state == "Starting" then
		return false, "Match already found"
	end
	
	-- Validate map
	local selectedMap = map or Constants.DEFAULT_MAP
	if not Util.TableContains(Constants.MAPS, selectedMap) then
		selectedMap = Constants.DEFAULT_MAP
	end
	
	-- Add to queue
	queue[userId] = {
		UserId = userId,
		SquadId = squadId,
		Map = selectedMap,
		JoinedAt = os.clock(),
		Ready = false,
	}
	playerStates[player] = "Queued"
	
	-- Store in MemoryStore for cross-server matchmaking
	pcall(function()
		queueStore:SetAsync(tostring(userId), {
			SquadId = squadId,
			Map = selectedMap,
			JoinedAt = os.time(),
		}, MAX_QUEUE_TIME)
	end)
	
	-- Notify client
	LobbyRemotes.QueueUpdate:FireClient(player, {
		State = "Queued",
		Position = MatchmakingService.GetQueuePosition(userId),
		EstimatedWait = MatchmakingService.GetEstimatedWait(),
	})
	
	print(string.format("[Matchmaking] %s joined queue (map: %s)", player.Name, selectedMap))
	
	-- Try to form match
	MatchmakingService.TryFormMatch()
	
	return true, "Joined queue"
end

function MatchmakingService.LeaveQueue(player: Player): (boolean, string)
	if not Util.ValidatePlayer(player) then
		return false, "Invalid player"
	end
	
	local userId = player.UserId
	
	if not queue[userId] then
		return false, "Not in queue"
	end
	
	queue[userId] = nil
	playerStates[player] = "Idle"
	
	pcall(function()
		queueStore:RemoveAsync(tostring(userId))
	end)
	
	LobbyRemotes.QueueUpdate:FireClient(player, {
		State = "Idle",
	})
	
	print(string.format("[Matchmaking] %s left queue", player.Name))
	return true, "Left queue"
end

function MatchmakingService.GetQueuePosition(userId: number): number
	local position = 0
	local entries = {}
	for _, entry in pairs(queue) do
		table.insert(entries, entry)
	end
	table.sort(entries, function(a, b) return a.JoinedAt < b.JoinedAt end)
	
	for i, entry in ipairs(entries) do
		if entry.UserId == userId then
			position = i
			break
		end
	end
	return position
end

function MatchmakingService.GetEstimatedWait(): number
	local count = Util.TableLength(queue)
	if count >= Constants.MIN_PLAYERS_TO_START then
		return 10 -- seconds
	end
	return math.max(30, (Constants.MIN_PLAYERS_TO_START - count) * 5)
end

function MatchmakingService.GetQueueCount(): number
	return Util.TableLength(queue)
end

function MatchmakingService.GetPlayerState(player: Player): QueueState
	return playerStates[player] or "Idle"
end

-- ==================== MATCH FORMATION ====================

function MatchmakingService.TryFormMatch()
	local entries = {}
	for _, entry in pairs(queue) do
		if not entry.Ready then
			table.insert(entries, entry)
		end
	end
	
	if #entries < Constants.MIN_PLAYERS_TO_START then
		return false
	end
	
	-- Group by map preference
	local byMap: { [string]: { QueueEntry } } = {}
	for _, entry in ipairs(entries) do
		if not byMap[entry.Map] then
			byMap[entry.Map] = {}
		end
		table.insert(byMap[entry.Map], entry)
	end
	
	-- Find map with enough players
	for map, mapEntries in pairs(byMap) do
		if #mapEntries >= Constants.MIN_PLAYERS_TO_START then
			-- Take first N players
			local selected = {}
			for i = 1, math.min(#mapEntries, Constants.MAX_PLAYERS_PER_MATCH) do
				table.insert(selected, mapEntries[i])
			end
			MatchmakingService.StartReadyCheck(map, selected)
			return true
		end
	end
	
	return false
end

function MatchmakingService.StartReadyCheck(map: string, entries: { QueueEntry })
	local matchId = Util.GenerateUID()
	
	-- Mark players as ready check
	for _, entry in ipairs(entries) do
		local player = Players:GetPlayerByUserId(entry.UserId)
		if player then
			playerStates[player] = "Found"
			LobbyRemotes.MatchFound:FireClient(player, {
				MatchId = matchId,
				Map = map,
				Players = #entries,
				ReadyCheckDuration = READY_CHECK_DURATION,
			})
		end
	end
	
	-- Wait for ready confirmations
	local readyCount = 0
	local startTime = os.clock()
	
	while os.clock() - startTime < READY_CHECK_DURATION do
		readyCount = 0
		for _, entry in ipairs(entries) do
			if entry.Ready then
				readyCount += 1
			end
		end
		
		if readyCount >= #entries * 0.8 then -- 80% ready threshold
			break
		end
		
		task.wait(0.5)
	end
	
	-- Check if enough ready
	if readyCount >= Constants.MIN_PLAYERS_TO_START * 0.8 then
		MatchmakingService.StartMatchTeleport(matchId, map, entries)
	else
		-- Not enough ready, requeue
		for _, entry in ipairs(entries) do
			local player = Players:GetPlayerByUserId(entry.UserId)
			if player and not entry.Ready then
				-- Auto-requeue unready players
				entry.JoinedAt = os.clock()
				playerStates[player] = "Queued"
				LobbyRemotes.QueueUpdate:FireClient(player, {
					State = "Queued",
					Position = MatchmakingService.GetQueuePosition(entry.UserId),
					Reason = "Not enough players ready",
				})
			end
		end
	end
end

function MatchmakingService.SetReady(player: Player, ready: boolean)
	local userId = player.UserId
	local entry = queue[userId]
	if entry then
		entry.Ready = ready
		print(string.format("[Matchmaking] %s ready: %s", player.Name, tostring(ready)))
	end
end

-- ==================== TELEPORT ====================

function MatchmakingService.StartMatchTeleport(matchId: string, map: string, entries: { QueueEntry })
	local players = {}
	local teleportData = {
		MatchId = matchId,
		Map = map,
		Squads = {},
		StartTime = os.time(),
	}
	
	-- Build squad data
	for _, entry in ipairs(entries) do
		local player = Players:GetPlayerByUserId(entry.UserId)
		if player then
			table.insert(players, player)
			playerStates[player] = "Teleporting"
			
			if entry.SquadId then
				if not teleportData.Squads[entry.SquadId] then
					teleportData.Squads[entry.SquadId] = {}
				end
				table.insert(teleportData.Squads[entry.SquadId], entry.UserId)
			end
		end
	end
	
	-- Remove from queue
	for _, entry in ipairs(entries) do
		queue[entry.UserId] = nil
		pcall(function()
			queueStore:RemoveAsync(tostring(entry.UserId))
		end)
	end
	
	-- Teleport with retry
	local retries = 0
	local function attemptTeleport()
		local success, err = pcall(function()
			TeleportService:TeleportAsync(
				Constants.MATCH_PLACE_ID,
				players,
				teleportData,
				nil -- no custom loading screen
			)
		end)
		
		if not success then
			retries += 1
			warn(string.format("[Matchmaking] Teleport failed (attempt %d): %s", retries, tostring(err)))
			
			if retries < MAX_TELEPORT_RETRIES then
				task.wait(TELEPORT_RETRY_DELAY)
				attemptTeleport()
			else
				-- Teleport failed completely, requeue players
				for _, player in ipairs(players) do
					if player and player.Parent then
						playerStates[player] = "Queued"
						queue[player.UserId] = {
							UserId = player.UserId,
							SquadId = nil,
							Map = map,
							JoinedAt = os.clock(),
							Ready = false,
						}
						LobbyRemotes.Notification:FireClient(player, {
							Type = "Error",
							Message = "Teleport failed. Requeued.",
						})
					end
				end
			end
		else
			print(string.format("[Matchmaking] Teleported %d players to match %s", #players, matchId))
		end
	end
	
	task.spawn(attemptTeleport)
end

-- ==================== REMOTE HANDLERS ====================

LobbyRemotes.JoinQueue.OnServerInvoke = function(player, squadId, map)
	return MatchmakingService.JoinQueue(player, squadId, map)
end

LobbyRemotes.LeaveQueue.OnServerInvoke = function(player)
	return MatchmakingService.LeaveQueue(player)
end

LobbyRemotes.ReadyUp.OnServerInvoke = function(player, ready)
	MatchmakingService.SetReady(player, ready)
	return true
end

LobbyRemotes.RequestQueueStatus.OnServerEvent:Connect(function(player)
	local state = MatchmakingService.GetPlayerState(player)
	local data = {
		State = state,
		QueueCount = MatchmakingService.GetQueueCount(),
	}
	if state == "Queued" then
		data.Position = MatchmakingService.GetQueuePosition(player.UserId)
		data.EstimatedWait = MatchmakingService.GetEstimatedWait()
	end
	LobbyRemotes.QueueUpdate:FireClient(player, data)
end)

-- ==================== CLEANUP ====================

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	if queue[userId] then
		queue[userId] = nil
		pcall(function()
			queueStore:RemoveAsync(tostring(userId))
		end)
	end
	playerStates[player] = nil
end)

-- Periodic queue cleanup
task.spawn(function()
	while true do
		task.wait(30)
		local now = os.clock()
		for userId, entry in pairs(queue) do
			if now - entry.JoinedAt > MAX_QUEUE_TIME then
				local player = Players:GetPlayerByUserId(userId)
				if player then
					MatchmakingService.LeaveQueue(player)
					LobbyRemotes.Notification:FireClient(player, {
						Type = "Warning",
						Message = "Queue timeout. Please rejoin.",
					})
				else
					queue[userId] = nil
				end
			end
		end
	end
end)

print("[MatchmakingService] Initialized")
return MatchmakingService
