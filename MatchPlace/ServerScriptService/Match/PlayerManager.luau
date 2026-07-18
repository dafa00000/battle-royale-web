--[[
	PlayerManager - Track all players in match: join, leave, spawn, eliminate, revive, downed state
	Integrates with DataManager for stats. Broadcasts PlayerEliminated/PlayerDowned.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local DataManager = require(Shared.DataManager)

local MatchRemotes = ReplicatedStorage.Remotes.MatchRemotes

local PlayerManager = {}

export type PlayerMatchState = "Lobby" | "Parachuting" | "Alive" | "Downed" | "Eliminated" | "Spectating"

export type PlayerMatchData = {
	Player: Player,
	State: PlayerMatchState,
	Placement: number?,
	Kills: number,
	Damage: number,
	SurvivalTime: number,
	DownedTime: number?,
	RevivedBy: Player?,
	EliminatedBy: Player?,
	EliminationCause: string?,
	JoinTime: number,
	SpawnTime: number?,
	IsBot: boolean,
}

local playerData: { [Player]: PlayerMatchData } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local downedCheckConnection: RBXScriptConnection? = nil

-- Downed state configuration
local DOWNED_BLEEDOUT_TIME = 60 -- seconds
local DOWNED_REVIVE_TIME = 8 -- seconds to revive
local DOWNED_HEALTH = 100 -- health when downed

function PlayerManager.Initialize()
	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerManager.OnPlayerJoin(player)
	end

	-- Connect events
	Players.PlayerAdded:Connect(PlayerManager.OnPlayerJoin)
	Players.PlayerRemoving:Connect(PlayerManager.OnPlayerLeave)

	-- Start downed state checker
	PlayerManager.StartDownedChecker()

	print("[PlayerManager] Initialized")
end

function PlayerManager.OnPlayerJoin(player: Player)
	if playerData[player] then return end

	local data: PlayerMatchData = {
		Player = player,
		State = "Lobby",
		Placement = nil,
		Kills = 0,
		Damage = 0,
		SurvivalTime = 0,
		DownedTime = nil,
		RevivedBy = nil,
		EliminatedBy = nil,
		EliminationCause = nil,
		JoinTime = os.clock(),
		SpawnTime = nil,
		IsBot = false,
	}
	playerData[player] = data

	-- Track character spawning
	playerConnections[player] = {}
	table.insert(playerConnections[player], player.CharacterAdded:Connect(function(character)
		PlayerManager.OnCharacterSpawn(player, character)
	end))

	-- If character already exists
	if player.Character then
		PlayerManager.OnCharacterSpawn(player, player.Character)
	end

	-- Track humanoid death
	table.insert(playerConnections[player], player.CharacterRemoving:Connect(function()
		PlayerManager.OnCharacterRemoved(player)
	end))

	print("[PlayerManager] Player joined:", player.Name)
end

function PlayerManager.OnPlayerLeave(player: Player)
	-- Clean up connections
	if playerConnections[player] then
		for _, conn in ipairs(playerConnections[player]) do
			conn:Disconnect()
		end
		playerConnections[player] = nil
	end

	-- Mark as eliminated if they leave mid-match
	local data = playerData[player]
	if data and (data.State == "Alive" or data.State == "Downed") then
		PlayerManager.EliminatePlayer(player, nil, "Disconnected")
	end

	playerData[player] = nil
	print("[PlayerManager] Player left:", player.Name)
end

function PlayerManager.OnCharacterSpawn(player: Player, character: Model)
	local data = playerData[player]
	if not data then return end

	-- Wait for humanoid
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	data.SpawnTime = os.clock()
	if data.State == "Lobby" then
		data.State = "Alive"
	end

	-- Track humanoid death
	local diedConn
	diedConn = humanoid.Died:Connect(function()
		diedConn:Disconnect()
		PlayerManager.OnPlayerDeath(player)
	end)

	-- Track damage for stats
	local healthChangedConn
	healthChangedConn = humanoid.HealthChanged:Connect(function(newHealth)
		if newHealth <= 0 then
			healthChangedConn:Disconnect()
		end
	end)

	if playerConnections[player] then
		table.insert(playerConnections[player], diedConn)
		table.insert(playerConnections[player], healthChangedConn)
	end

	print("[PlayerManager] Character spawned for:", player.Name)
end

function PlayerManager.OnCharacterRemoved(player: Player)
	-- Character removed, might respawn
end

function PlayerManager.OnPlayerDeath(player: Player)
	local data = playerData[player]
	if not data then return end

	if data.State == "Alive" then
		-- Go to downed state first
		PlayerManager.DownPlayer(player, data.EliminatedBy, "Death")
	else
		-- Already downed, fully eliminate
		PlayerManager.EliminatePlayer(player, data.EliminatedBy, data.EliminationCause or "Death")
	end
end

-- ==================== STATE MANAGEMENT ====================

function PlayerManager.SetPlayerState(player: Player, state: PlayerMatchState)
	local data = playerData[player]
	if not data then return end

	local oldState = data.State
	data.State = state

	if state == "Alive" and oldState == "Downed" then
		data.DownedTime = nil
	end
end

function PlayerManager.GetPlayerState(player: Player): PlayerMatchState?
	local data = playerData[player]
	return data and data.State
end

function PlayerManager.GetPlayerData(player: Player): PlayerMatchData?
	return playerData[player]
end

function PlayerManager.GetAllPlayerData(): { [Player]: PlayerMatchData }
	return playerData
end

function PlayerManager.GetAlivePlayers(): { Player }
	local alive = {}
	for player, data in pairs(playerData) do
		if data.State == "Alive" or data.State == "Downed" then
			table.insert(alive, player)
		end
	end
	return alive
end

function PlayerManager.GetAliveCount(): number
	local count = 0
	for _, data in pairs(playerData) do
		if data.State == "Alive" or data.State == "Downed" then
			count += 1
		end
	end
	return count
end

function PlayerManager.GetSpectatingPlayers(): { Player }
	local spectating = {}
	for player, data in pairs(playerData) do
		if data.State == "Spectating" then
			table.insert(spectating, player)
		end
	end
	return spectating
end

-- ==================== COMBAT & ELIMINATION ====================

function PlayerManager.DownPlayer(player: Player, attacker: Player?, cause: string?)
	local data = playerData[player]
	if not data then return end
	if data.State ~= "Alive" then return end

	data.State = "Downed"
	data.DownedTime = os.clock()
	data.EliminatedBy = attacker
	data.EliminationCause = cause

	-- Set health to downed health
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = DOWNED_HEALTH
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		end
	end

	-- Broadcast
	MatchRemotes.PlayerDowned:FireAllClients({
		player = player.Name,
		playerUserId = player.UserId,
		attacker = attacker and attacker.Name or nil,
		attackerUserId = attacker and attacker.UserId or nil,
		cause = cause,
		timestamp = os.clock(),
	})

	-- Update stats
	if attacker then
		PlayerManager.AddKill(attacker)
	end

	print("[PlayerManager] Player downed:", player.Name, "by", attacker and attacker.Name or "unknown")
end

function PlayerManager.RevivePlayer(player: Player, reviver: Player)
	local data = playerData[player]
	if not data then return end
	if data.State ~= "Downed" then return end

	data.State = "Alive"
	data.RevivedBy = reviver
	data.DownedTime = nil
	data.EliminatedBy = nil
	data.EliminationCause = nil

	-- Restore health
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = 50 -- Revive with 50% health
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
		end
	end

	-- Broadcast
	MatchRemotes.PlayerRevived:FireAllClients({
		player = player.Name,
		playerUserId = player.UserId,
		reviver = reviver.Name,
		reviverUserId = reviver.UserId,
		timestamp = os.clock(),
	})

	-- Update reviver stats
	local reviverData = playerData[reviver]
	if reviverData then
		-- Could track revives here
	end

	-- Update DataManager stats
	DataManager.UpdateStats(reviver, { Revives = 1 })

	print("[PlayerManager] Player revived:", player.Name, "by", reviver.Name)
end

function PlayerManager.EliminatePlayer(player: Player, killer: Player?, cause: string?)
	local data = playerData[player]
	if not data then return end

	local wasAlive = data.State == "Alive" or data.State == "Downed"
	data.State = "Eliminated"
	data.EliminatedBy = killer or data.EliminatedBy
	data.EliminationCause = cause or data.EliminationCause or "Unknown"
	data.SurvivalTime = os.clock() - data.JoinTime

	-- Calculate placement
	local aliveCount = PlayerManager.GetAliveCount()
	data.Placement = aliveCount + 1

	-- Update DataManager stats
	DataManager.UpdateStats(player, { Deaths = 1 })

	-- Broadcast
	MatchRemotes.PlayerEliminated:FireAllClients({
		player = player.Name,
		playerUserId = player.UserId,
		killer = data.EliminatedBy and data.EliminatedBy.Name or nil,
		killerUserId = data.EliminatedBy and data.EliminatedBy.UserId or nil,
		cause = data.EliminationCause,
		placement = data.Placement,
		aliveRemaining = aliveCount,
		timestamp = os.clock(),
	})

	-- Auto-spectate after delay
	task.delay(3, function()
		if playerData[player] and playerData[player].State == "Eliminated" then
			PlayerManager.StartSpectating(player)
		end
	end)

	print("[PlayerManager] Player eliminated:", player.Name, "placement:", data.Placement)
end

function PlayerManager.AddKill(player: Player, damage: number?)
	local data = playerData[player]
	if not data then return end

	data.Kills += 1
	if damage then
		data.Damage += damage
	end

	-- Update DataManager
	DataManager.UpdateStats(player, { Kills = 1 })
end

function PlayerManager.AddDamage(player: Player, damage: number)
	local data = playerData[player]
	if not data then return end
	data.Damage += damage
end

-- ==================== SPECTATING ====================

function PlayerManager.StartSpectating(player: Player)
	local data = playerData[player]
	if not data then return end

	data.State = "Spectating"

	-- Find spectate target
	local alivePlayers = PlayerManager.GetAlivePlayers()
	if #alivePlayers > 0 then
		local target = alivePlayers[math.random(#alivePlayers)]
		MatchRemotes.SpectateTarget:FireClient(player, {
			target = target.Name,
			targetUserId = target.UserId,
		})
	end
end

function PlayerManager.StopSpectating(player: Player)
	local data = playerData[player]
	if not data then return end
	if data.State == "Spectating" then
		data.State = "Eliminated"
	end
end

-- ==================== DOWNED STATE CHECKER ====================

function PlayerManager.StartDownedChecker()
	if downedCheckConnection then return end

	downedCheckConnection = RunService.Heartbeat:Connect(function()
		for player, data in pairs(playerData) do
			if data.State == "Downed" and data.DownedTime then
				local elapsed = os.clock() - data.DownedTime
				if elapsed >= DOWNED_BLEEDOUT_TIME then
					PlayerManager.EliminatePlayer(player, data.EliminatedBy, "BledOut")
				end
			end
		end
	end)
end

function PlayerManager.StopDownedChecker()
	if downedCheckConnection then
		downedCheckConnection:Disconnect()
		downedCheckConnection = nil
	end
end

-- ==================== SPAWN PROTECTION ====================

function PlayerManager.GiveSpawnProtection(player: Player, duration: number)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Make invulnerable
	humanoid.MaxHealth = 10000
	humanoid.Health = 10000

	task.delay(duration, function()
		if humanoid.Parent then
			humanoid.MaxHealth = 100
			humanoid.Health = 100
		end
	end)
end

-- ==================== REMOTE HANDLERS ====================

MatchRemotes.RevivePlayer.OnServerInvoke = function(player: Player, targetName: string): { success: boolean, message: string? }
	local target = Players:FindFirstChild(targetName)
	if not target then
		return { success = false, message = "Target not found" }
	end

	local targetData = playerData[target]
	local playerData = playerData[player]

	if not targetData or not playerData then
		return { success = false, message = "Invalid player data" }
	end

	if playerData.State ~= "Alive" then
		return { success = false, message = "You must be alive to revive" }
	end

	if targetData.State ~= "Downed" then
		return { success = false, message = "Target is not downed" }
	end

	-- Check distance
	local char1 = player.Character
	local char2 = target.Character
	if not char1 or not char2 then
		return { success = false, message = "Characters not loaded" }
	end

	local root1 = char1:FindFirstChild("HumanoidRootPart")
	local root2 = char2:FindFirstChild("HumanoidRootPart")
	if not root1 or not root2 then
		return { success = false, message = "Invalid characters" }
	end

	local distance = (root1.Position - root2.Position).Magnitude
	if distance > 10 then
		return { success = false, message = "Too far away" }
	end

	-- Revive takes time - start revive process
	task.spawn(function()
		local reviveStart = os.clock()
		while os.clock() - reviveStart < DOWNED_REVIVE_TIME do
			-- Check if still valid
			if not playerData[player] or playerData[player].State ~= "Alive" then return end
			if not playerData[target] or playerData[target].State ~= "Downed" then return end
			if (root1.Position - root2.Position).Magnitude > 10 then return end
			task.wait(0.1)
		end

		PlayerManager.RevivePlayer(target, player)
	end)

	return { success = true, message = "Reviving..." }
end

return PlayerManager
