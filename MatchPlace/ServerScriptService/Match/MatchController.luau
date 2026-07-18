--[[
	MatchController - Main match flow controller (Parachute -> Safe Zone -> Endgame)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")

local Remotes = ReplicatedStorage.Remotes
local MatchRemotes = Remotes.MatchRemotes
local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local SafeZoneService = require(script.Parent.SafeZoneService)
local LootSpawner = require(script.Parent.LootSpawner)
local VehicleService = require(script.Parent.VehicleService)
local EconomyService = require(script.Parent.EconomyService)
local DataManager = require(Shared.DataManager)

local MatchController = {}

export type MatchState = "Waiting" | "Starting" | "Parachuting" | "InProgress" | "Ending" | "Ended"
export type PlayerMatchState = "Lobby" | "Parachuting" | "Alive" | "Downed" | "Eliminated" | "Spectating"

local matchState: MatchState = "Waiting"
local matchStartTime = 0
local matchEndTime = 0
local planePath: { Vector3 } = {}
local planeProgress = 0
local alivePlayers: { [Player]: PlayerMatchState } = {}
local playerParachutes: { [Player]: boolean } = {}

-- Match phases
local MATCH_PHASES = {
	Waiting = { duration = 10, description = "Waiting for players..." },
	Starting = { duration = 15, description = "Match starting..." },
	Parachuting = { duration = 120, description = "Parachute phase" },
	InProgress = { duration = 0, description = "Match in progress" }, -- Until 1 player/team left
}

function MatchController.Initialize(matchData: any)
	-- matchData comes from TeleportData
	matchState = "Waiting"
	matchStartTime = os.clock()
	
	-- Initialize all players
	for _, player in ipairs(Players:GetPlayers()) do
		alivePlayers[player] = "Lobby"
		playerParachutes[player] = false
		
		-- Load player data
		DataManager.GetProfile(player) -- Ensures profile is loaded
	end
	
	-- Set up plane path
	MatchController.GeneratePlanePath()
	
	-- Initialize subsystems
	SafeZoneService.Initialize()
	LootSpawner.Initialize()
	VehicleService.Initialize()
	EconomyService.Initialize()
	
	-- Start match flow
	task.spawn(MatchController.MatchFlow)
	
	print("[MatchController] Initialized with", #Players:GetPlayers(), "players")
end

function MatchController.GeneratePlanePath()
	-- Generate random flight path across map
	local mapRadius = Constants.MAP_RADIUS
	local angle = math.random() * math.pi * 2
	local startPos = Vector3.new(math.cos(angle) * mapRadius * 1.2, 1000, math.sin(angle) * mapRadius * 1.2)
	local endAngle = angle + math.pi + (math.random() - 0.5) * math.pi * 0.5
	local endPos = Vector3.new(math.cos(endAngle) * mapRadius * 1.2, 1000, math.sin(endAngle) * mapRadius * 1.2)
	
	-- Create waypoints
	planePath = {}
	local steps = 10
	for i = 0, steps do
		local t = i / steps
		local pos = startPos:Lerp(endPos, t)
		-- Add some variation
		pos = pos + Vector3.new(
			(math.random() - 0.5) * 200,
			(math.random() - 0.5) * 100,
			(math.random() - 0.5) * 200
		)
		table.insert(planePath, pos)
	end
end

function MatchController.MatchFlow()
	-- Phase 1: Waiting
	MatchController.SetPhase("Waiting")
	task.wait(MATCH_PHASES.Waiting.duration)
	
	-- Phase 2: Starting
	MatchController.SetPhase("Starting")
	MatchController.StartPlane()
	task.wait(MATCH_PHASES.Starting.duration)
	
	-- Phase 3: Parachuting
	MatchController.SetPhase("Parachuting")
	
	-- Auto-deploy parachutes after delay
	task.delay(30, function()
		for player, state in pairs(alivePlayers) do
			if state == "Parachuting" and not playerParachutes[player] then
				MatchController.DeployParachute(player)
			end
		end
	end)
	
	-- Wait for parachute phase or all landed
	local parachuteEndTime = os.clock() + MATCH_PHASES.Parachuting.duration
	while os.clock() < parachuteEndTime do
		local allLanded = true
		for player, state in pairs(alivePlayers) do
			if state == "Parachuting" then
				allLanded = false
				break
			end
		end
		if allLanded then break end
		task.wait(1)
	end
	
	-- Force deploy remaining
	for player, state in pairs(alivePlayers) do
		if state == "Parachuting" and not playerParachutes[player] then
			MatchController.DeployParachute(player)
		end
	end
	
	-- Phase 4: In Progress
	MatchController.SetPhase("InProgress")
	
	-- Match runs until end condition
	MatchController.WaitForMatchEnd()
	
	-- Phase 5: Ending
	MatchController.SetPhase("Ending")
	task.wait(5)
	
	-- Phase 6: Ended
	MatchController.SetPhase("Ended")
	MatchController.EndMatch()
end

function MatchController.SetPhase(newPhase: MatchState)
	matchState = newPhase
	MatchRemotes.MatchPhaseChanged:FireAllClients({ phase = newPhase })
	print("[MatchController] Phase changed to:", newPhase)
end

function MatchController.StartPlane()
	-- Create plane visual
	local plane = Instance.new("Part")
	plane.Name = "DropPlane"
	plane.Size = Vector3.new(30, 5, 50)
	plane.Anchored = true
	plane.CanCollide = false
	plane.Transparency = 1
	plane.Parent = Workspace
	
	-- Visual mesh would be added here
	
	-- Animate plane along path
	task.spawn(function()
		local startTime = os.clock()
		local duration = MATCH_PHASES.Starting.duration + MATCH_PHASES.Parachuting.duration
		
		while os.clock() - startTime < duration and plane.Parent do
			planeProgress = (os.clock() - startTime) / duration
			local pathIndex = math.clamp(math.floor(planeProgress * #planePath) + 1, 1, #planePath)
			plane.CFrame = CFrame.new(planePath[pathIndex], planePath[math.min(pathIndex + 1, #planePath)])
			
			-- Update clients
			MatchRemotes.PlaneUpdate:FireAllClients({
				position = plane.Position,
				progress = planeProgress,
			})
			
			task.wait(1/30)
		end
		
		plane:Destroy()
	end)
	
	-- Notify clients
	MatchRemotes.PlaneStart:FireAllClients({
		path = planePath,
		startTime = os.clock(),
		duration = MATCH_PHASES.Starting.duration + MATCH_PHASES.Parachuting.duration,
	})
end

function MatchController.DeployParachute(player: Player)
	if playerParachutes[player] then return end
	playerParachutes[player] = true
	alivePlayers[player] = "Alive"
	
	-- Create parachute
	local character = player.Character
	if character then
		-- Add parachute to character
		-- This would be handled client-side with replication
	end
	
	MatchRemotes.ParachuteDeployed:FireAllClients({ player = player })
	
	-- Give starter equipment
	MatchController.GiveStarterKit(player)
end

function MatchController.GiveStarterKit(player: Player)
	-- Give basic items on landing
	local kit = {
		{ id = "Bandage", qty = 2 },
		{ id = "Ammo_5_56", qty = 60 },
		{ id = "Ammo_9mm", qty = 40 },
	}
	
	for _, item in ipairs(kit) do
		-- Add via InventoryManager
	end
end

function MatchController.WaitForMatchEnd()
	while true do
		local aliveCount = 0
		local aliveSquads: { [string]: number } = {}
		
		for player, state in pairs(alivePlayers) do
			if state == "Alive" then
				aliveCount += 1
				-- Track squads
				local profile = DataManager.GetProfile(player)
				if profile and profile.Data.SquadId then
					aliveSquads[profile.Data.SquadId] = (aliveSquads[profile.Data.SquadId] or 0) + 1
				end
			end
		end
		
		-- Check end condition: 1 squad alive or 1 player alive
		local squadsAlive = 0
		for _, count in pairs(aliveSquads) do
			if count > 0 then squadsAlive += 1 end
		end
		
		if squadsAlive <= 1 or aliveCount <= 1 then
			break
		end
		
		task.wait(2)
	end
end

function MatchController.EndMatch()
	-- Determine winners
	local winners: { Player } = {}
	local placements: { [Player]: number } = {}
	
	for player, state in pairs(alivePlayers) do
		if state == "Alive" then
			table.insert(winners, player)
			placements[player] = 1
		else
			-- Placements tracked via elimination order
		end
	end
	
	-- Apply rewards
	for player, placement in pairs(placements) do
		local profile = DataManager.GetProfile(player)
		if profile then
			local kills = profile.Data.MatchKills or 0
			local damage = profile.Data.MatchDamage or 0
			local survivalTime = os.clock() - matchStartTime
			
			DataManager.ApplyMatchRewards(player, placement, kills, damage, survivalTime)
		end
	end
	
	-- Notify clients
	MatchRemotes.MatchEnd:FireAllClients({
		winners = winners,
		placements = placements,
		matchDuration = os.clock() - matchStartTime,
	})
	
	-- Teleport back to lobby after delay
	task.delay(10, function()
		for _, player in ipairs(Players:GetPlayers()) do
			TeleportService:Teleport(Constants.LOBBY_PLACE_ID, player)
		end
	end)
end

-- ==================== PLAYER EVENTS ====================

function MatchController.OnPlayerEliminated(player: Player, killer: Player?, cause: string?)
	alivePlayers[player] = "Eliminated"
	
	-- Calculate placement
	local aliveCount = 0
	for _, state in pairs(alivePlayers) do
		if state == "Alive" then aliveCount += 1 end
	end
	
	local placement = aliveCount + 1
	
	-- Store for rewards
	local profile = DataManager.GetProfile(player)
	if profile then
		profile.Data.MatchPlacement = placement
		profile.Data.MatchKills = profile.Data.MatchKills or 0
		profile.Data.MatchDamage = profile.Data.MatchDamage or 0
	end
	
	-- Notify
	MatchRemotes.PlayerEliminated:FireAllClients({
		player = player.Name,
		killer = killer and killer.Name or nil,
		cause = cause,
		placement = placement,
		aliveRemaining = aliveCount,
	})
	
	-- Start spectating
	MatchController.StartSpectating(player)
end

function MatchController.OnPlayerDowned(player: Player, attacker: Player?)
	alivePlayers[player] = "Downed"
	
	MatchRemotes.PlayerDowned:FireAllClients({
		player = player.Name,
		attacker = attacker and attacker.Name or nil,
	})
end

function MatchController.OnPlayerRevived(player: Player, reviver: Player)
	alivePlayers[player] = "Alive"
	
	MatchRemotes.PlayerRevived:FireAllClients({
		player = player.Name,
		reviver = reviver.Name,
	})
end

function MatchController.StartSpectating(player: Player)
	alivePlayers[player] = "Spectating"
	
	-- Find someone to spectate
	local targets = {}
	for p, state in pairs(alivePlayers) do
		if state == "Alive" then table.insert(targets, p) end
	end
	
	if #targets > 0 then
		local target = targets[math.random(#targets)]
		MatchRemotes.SpectateTarget:FireClient(player, { target = target.Name })
	end
end

function MatchController.GetMatchState(): MatchState
	return matchState
end

function MatchController.GetAliveCount(): number
	local count = 0
	for _, state in pairs(alivePlayers) do
		if state == "Alive" then count += 1 end
	end
	return count
end

function MatchController.GetPlayerState(player: Player): PlayerMatchState?
	return alivePlayers[player]
end

-- ==================== REMOTE HANDLERS ====================

MatchRemotes.ParachuteDeploy.OnServerEvent:Connect(function(player: Player)
	if alivePlayers[player] == "Parachuting" then
		MatchController.DeployParachute(player)
	end
end)

MatchRemotes.RequestSpectate.OnServerInvoke = function(player: Player, targetName: string): { success: boolean }
	local target = Players:FindFirstChild(targetName)
	if target and alivePlayers[target] == "Alive" then
		MatchRemotes.SpectateTarget:FireClient(player, { target = targetName })
		return { success = true }
	end
	return { success = false }
end

return MatchController