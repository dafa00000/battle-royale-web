--[[
	SquadService - Squad creation, management, and persistence
	Max 4 players per squad, leader transfer, invite/kick system
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local LobbyRemotes = ReplicatedStorage:WaitForChild("LobbyRemotes")

local SquadService = {}

-- Types
export type SquadMember = {
	UserId: number,
	Username: string,
	IsLeader: boolean,
	IsReady: boolean,
	JoinedAt: number,
}

export type Squad = {
	SquadId: string,
	Leader: number,
	Members: { [number]: SquadMember },
	CreatedAt: number,
	MaxSize: number,
}

-- State
local squads: { [string]: Squad } = {} -- SquadId -> Squad
local playerSquad: { [number]: string } = {} -- UserId -> SquadId
local inviteCooldowns: { [number]: { [number]: number } } = {} -- Inviter -> Target -> timestamp

local MAX_SQUAD_SIZE = 4
local INVITE_COOLDOWN = 10 -- seconds

-- ==================== SQUAD CRUD ====================

function SquadService.CreateSquad(player: Player): (boolean, string)
	if not Util.ValidatePlayer(player) then
		return false, "Invalid player"
	end
	
	local userId = player.UserId
	
	if playerSquad[userId] then
		return false, "Already in a squad"
	end
	
	local squadId = Util.GenerateShortUID(6)
	local squad: Squad = {
		SquadId = squadId,
		Leader = userId,
		Members = {
			[userId] = {
				UserId = userId,
				Username = player.Name,
				IsLeader = true,
				IsReady = false,
				JoinedAt = os.clock(),
			}
		},
		CreatedAt = os.clock(),
		MaxSize = MAX_SQUAD_SIZE,
	}
	
	squads[squadId] = squad
	playerSquad[userId] = squadId
	
	SquadService.BroadcastSquadUpdate(squadId)
	print(string.format("[Squad] %s created squad %s", player.Name, squadId))
	
	return true, squadId
end

function SquadService.JoinSquad(player: Player, squadId: string): (boolean, string)
	if not Util.ValidatePlayer(player) then
		return false, "Invalid player"
	end
	
	local userId = player.UserId
	local squad = squads[squadId]
	
	if not squad then
		return false, "Squad not found"
	end
	
	if playerSquad[userId] then
		return false, "Already in a squad"
	end
	
	if Util.TableLength(squad.Members) >= squad.MaxSize then
		return false, "Squad is full"
	end
	
	-- Add member
	squad.Members[userId] = {
		UserId = userId,
		Username = player.Name,
		IsLeader = false,
		IsReady = false,
		JoinedAt = os.clock(),
	}
	playerSquad[userId] = squadId
	
	SquadService.BroadcastSquadUpdate(squadId)
	print(string.format("[Squad] %s joined squad %s", player.Name, squadId))
	
	return true, "Joined squad"
end

function SquadService.LeaveSquad(player: Player): (boolean, string)
	if not Util.ValidatePlayer(player) then
		return false, "Invalid player"
	end
	
	local userId = player.UserId
	local squadId = playerSquad[userId]
	
	if not squadId then
		return false, "Not in a squad"
	end
	
	local squad = squads[squadId]
	if not squad then
		playerSquad[userId] = nil
		return false, "Squad data corrupted"
	end
	
	-- Remove member
	squad.Members[userId] = nil
	playerSquad[userId] = nil
	
	-- If empty, disband
	if Util.TableLength(squad.Members) == 0 then
		squads[squadId] = nil
		print(string.format("[Squad] Squad %s disbanded (empty)", squadId))
	else
		-- If leader left, transfer to oldest member
		if squad.Leader == userId then
			local oldest, oldestTime = nil, math.huge
			for memberId, member in pairs(squad.Members) do
				if member.JoinedAt < oldestTime then
					oldest = memberId
					oldestTime = member.JoinedAt
				end
			end
			if oldest then
				squad.Leader = oldest
				squad.Members[oldest].IsLeader = true
				local leaderPlayer = Players:GetPlayerByUserId(oldest)
				if leaderPlayer then
					LobbyRemotes.Notification:FireClient(leaderPlayer, {
						Type = "Info",
						Message = "You are now the squad leader",
					})
				end
			end
		end
		SquadService.BroadcastSquadUpdate(squadId)
	end
	
	-- Notify leaver
	LobbyRemotes.SquadUpdate:FireClient(player, {
		SquadId = nil,
		Members = {},
	})
	
	print(string.format("[Squad] %s left squad %s", player.Name, squadId))
	return true, "Left squad"
end

function SquadService.KickFromSquad(player: Player, targetUserId: number): (boolean, string)
	if not Util.ValidatePlayer(player) then
		return false, "Invalid player"
	end
	
	local userId = player.UserId
	local squadId = playerSquad[userId]
	
	if not squadId then
		return false, "Not in a squad"
	end
	
	local squad = squads[squadId]
	if not squad then
		return false, "Squad not found"
	end
	
	if squad.Leader ~= userId then
		return false, "Only leader can kick"
	end
	
	if not squad.Members[targetUserId] then
		return false, "Target not in squad"
	end
	
	if targetUserId == userId then
		return false, "Cannot kick yourself"
	end
	
	-- Remove target
	local targetName = squad.Members[targetUserId].Username
	squad.Members[targetUserId] = nil
	playerSquad[targetUserId] = nil
	
	-- Notify target
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if targetPlayer then
		LobbyRemotes.SquadUpdate:FireClient(targetPlayer, {
			SquadId = nil,
			Members = {},
		})
		LobbyRemotes.Notification:FireClient(targetPlayer, {
			Type = "Warning",
			Message = "You were kicked from the squad",
		})
	end
	
	SquadService.BroadcastSquadUpdate(squadId)
	print(string.format("[Squad] %s kicked %s from squad %s", player.Name, targetName, squadId))
	
	return true, "Kicked player"
end

-- ==================== INVITES ====================

function SquadService.InviteToSquad(player: Player, targetUserId: number): (boolean, string)
	if not Util.ValidatePlayer(player) then
		return false, "Invalid player"
	end
	
	local userId = player.UserId
	local squadId = playerSquad[userId]
	
	if not squadId then
		return false, "Not in a squad"
	end
	
	local squad = squads[squadId]
	if not squad then
		return false, "Squad not found"
	end
	
	if Util.TableLength(squad.Members) >= squad.MaxSize then
		return false, "Squad is full"
	end
	
	-- Check cooldown
	if inviteCooldowns[userId] and inviteCooldowns[userId][targetUserId] then
		local elapsed = os.clock() - inviteCooldowns[userId][targetUserId]
		if elapsed < INVITE_COOLDOWN then
			return false, string.format("Invite cooldown: %ds", math.ceil(INVITE_COOLDOWN - elapsed))
		end
	end
	
	-- Send invite
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if not targetPlayer then
		return false, "Player not online"
	end
	
	if playerSquad[targetUserId] then
		return false, "Player already in a squad"
	end
	
	-- Set cooldown
	if not inviteCooldowns[userId] then
		inviteCooldowns[userId] = {}
	end
	inviteCooldowns[userId][targetUserId] = os.clock()
	
	LobbyRemotes.SquadInvite:FireClient(targetPlayer, {
		SquadId = squadId,
		InviterName = player.Name,
		InviterUserId = userId,
		MemberCount = Util.TableLength(squad.Members),
	})
	
	print(string.format("[Squad] %s invited %s to squad %s", player.Name, targetPlayer.Name, squadId))
	return true, "Invite sent"
end

function SquadService.AcceptInvite(player: Player, squadId: string): (boolean, string)
	return SquadService.JoinSquad(player, squadId)
end

function SquadService.DeclineInvite(player: Player, squadId: string)
	-- Just a notification, no state change
	local squad = squads[squadId]
	if squad then
		local leader = Players:GetPlayerByUserId(squad.Leader)
		if leader then
			LobbyRemotes.Notification:FireClient(leader, {
				Type = "Info",
				Message = player.Name .. " declined your invite",
			})
		end
	end
end

-- ==================== READY SYSTEM ====================

function SquadService.SetReady(player: Player, ready: boolean): (boolean, string)
	if not Util.ValidatePlayer(player) then
		return false, "Invalid player"
	end
	
	local userId = player.UserId
	local squadId = playerSquad[userId]
	
	if not squadId then
		return false, "Not in a squad"
	end
	
	local squad = squads[squadId]
	if not squad then
		return false, "Squad not found"
	end
	
	if not squad.Members[userId] then
		return false, "Not in squad"
	end
	
	squad.Members[userId].IsReady = ready
	SquadService.BroadcastSquadUpdate(squadId)
	
	return true, ready and "Ready" or "Not ready"
end

function SquadService.IsSquadReady(squadId: string): boolean
	local squad = squads[squadId]
	if not squad then return false end
	
	for _, member in pairs(squad.Members) do
		if not member.IsReady then
			return false
		end
	end
	return true
end

-- ==================== QUERIES ====================

function SquadService.GetSquad(squadId: string): Squad?
	return squads[squadId]
end

function SquadService.GetPlayerSquad(player: Player): Squad?
	local squadId = playerSquad[player.UserId]
	return squadId and squads[squadId] or nil
end

function SquadService.GetPlayerSquadId(player: Player): string?
	return playerSquad[player.UserId]
end

function SquadService.BroadcastSquadUpdate(squadId: string)
	local squad = squads[squadId]
	if not squad then return end
	
	local memberList = {}
	for _, member in pairs(squad.Members) do
		table.insert(memberList, {
			UserId = member.UserId,
			Username = member.Username,
			IsLeader = member.IsLeader,
			IsReady = member.IsReady,
		})
	end
	
	-- Sort by join time
	table.sort(memberList, function(a, b)
		local ma = squad.Members[a.UserId]
		local mb = squad.Members[b.UserId]
		return ma.JoinedAt < mb.JoinedAt
	end)
	
	for _, member in pairs(squad.Members) do
		local player = Players:GetPlayerByUserId(member.UserId)
		if player then
			LobbyRemotes.SquadUpdate:FireClient(player, {
				SquadId = squadId,
				Leader = squad.Leader,
				Members = memberList,
				MaxSize = squad.MaxSize,
			})
		end
	end
end

-- ==================== REMOTE HANDLERS ====================

LobbyRemotes.JoinSquad.OnServerInvoke = function(player, squadId)
	return SquadService.JoinSquad(player, squadId)
end

LobbyRemotes.LeaveSquad.OnServerInvoke = function(player)
	return SquadService.LeaveSquad(player)
end

LobbyRemotes.InviteToSquad.OnServerInvoke = function(player, targetUserId)
	return SquadService.InviteToSquad(player, targetUserId)
end

LobbyRemotes.KickFromSquad.OnServerInvoke = function(player, targetUserId)
	return SquadService.KickFromSquad(player, targetUserId)
end

LobbyRemotes.ReadyUp.OnServerInvoke = function(player, ready)
	return SquadService.SetReady(player, ready)
end

LobbyRemotes.RequestSquadInfo.OnServerEvent:Connect(function(player)
	local squad = SquadService.GetPlayerSquad(player)
	if squad then
		SquadService.BroadcastSquadUpdate(squad.SquadId)
	else
		LobbyRemotes.SquadUpdate:FireClient(player, {
			SquadId = nil,
			Members = {},
		})
	end
end)

-- ==================== CLEANUP ====================

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	if playerSquad[userId] then
		SquadService.LeaveSquad(player)
	end
	inviteCooldowns[userId] = nil
end)

print("[SquadService] Initialized")
return SquadService
