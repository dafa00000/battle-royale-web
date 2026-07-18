--[[
	LobbyClient - Main client entry point for Lobby Place
	Initializes UI, connects remotes, handles match found teleport
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local LobbyRemotes = ReplicatedStorage:WaitForChild("LobbyRemotes")

-- UI Modules
local MainMenu = require(script.UI.MainMenu)
local SquadUI = require(script.UI.SquadUI)
local LoadoutUI = require(script.UI.LoadoutUI)

local LobbyClient = {}

-- State
local playerProfile = nil
local currentSquad = nil
local queueState = "Idle"

-- ==================== INITIALIZATION ====================

function LobbyClient.Initialize()
	print("[LobbyClient] Initializing...")
	
	-- Load player profile
	LobbyClient.LoadProfile()
	
	-- Initialize UI
	MainMenu.Initialize(LocalPlayer, playerProfile)
	SquadUI.Initialize(LocalPlayer)
	LoadoutUI.Initialize(LocalPlayer)
	
	-- Connect remotes
	LobbyClient.ConnectRemotes()
	
	-- Request initial data
	LobbyRemotes.RequestSquadInfo:FireServer()
	LobbyRemotes.RequestQueueStatus:FireServer()
	
	print("[LobbyClient] Initialized")
end

function LobbyClient.LoadProfile()
	local success, profile = pcall(function()
		return LobbyRemotes.GetPlayerProfile:InvokeServer()
	end)
	
	if success and profile then
		playerProfile = profile
		print(string.format("[LobbyClient] Loaded profile: Level %d, %d wins",
			profile.Stats.Level, profile.Stats.Wins))
	else
		warn("[LobbyClient] Failed to load profile")
		-- Create default display profile
		playerProfile = {
			Username = LocalPlayer.Name,
			DisplayName = LocalPlayer.DisplayName,
			Stats = {
				Level = 1,
				XP = 0,
				Kills = 0,
				Wins = 0,
				Top10s = 0,
			},
			Currency = { Cash = 0, Credits = 0 },
		}
	end
end

function LobbyClient.ConnectRemotes()
	-- Queue updates
	LobbyRemotes.QueueUpdate.OnClientEvent:Connect(function(data)
		queueState = data.State
		MainMenu.UpdateQueueStatus(data)
		
		if data.State == "Queued" then
			print(string.format("[LobbyClient] Queue position: %d, wait: ~%ds",
				data.Position or 0, data.EstimatedWait or 0))
		end
	end)
	
	-- Squad updates
	LobbyRemotes.SquadUpdate.OnClientEvent:Connect(function(data)
		currentSquad = data
		SquadUI.UpdateSquad(data)
		MainMenu.UpdateSquadDisplay(data)
	end)
	
	-- Squad invites
	LobbyRemotes.SquadInvite.OnClientEvent:Connect(function(data)
		SquadUI.ShowInvite(data)
	end)
	
	-- Match found
	LobbyRemotes.MatchFound.OnClientEvent:Connect(function(data)
		MainMenu.ShowMatchFound(data)
	end)
	
	-- Loadout updates
	LobbyRemotes.LoadoutUpdate.OnClientEvent:Connect(function(data)
		LoadoutUI.UpdateSlot(data.Slot, data.Data)
	end)
	
	-- Currency updates
	LobbyRemotes.CurrencyUpdate.OnClientEvent:Connect(function(data)
		if playerProfile then
			playerProfile.Currency = data
		end
		MainMenu.UpdateCurrency(data)
	end)
	
	-- Notifications
	LobbyRemotes.Notification.OnClientEvent:Connect(function(data)
		MainMenu.ShowNotification(data.Type, data.Message)
	end)
end

-- ==================== PUBLIC API ====================

function LobbyClient.GetProfile()
	return playerProfile
end

function LobbyClient.GetSquad()
	return currentSquad
end

function LobbyClient.GetQueueState()
	return queueState
end

function LobbyClient.JoinQueue(map)
	return LobbyRemotes.JoinQueue:InvokeServer(nil, map)
end

function LobbyClient.LeaveQueue()
	return LobbyRemotes.LeaveQueue:InvokeServer()
end

function LobbyClient.SetReady(ready)
	return LobbyRemotes.ReadyUp:InvokeServer(ready)
end

-- ==================== START ====================

LobbyClient.Initialize()
return LobbyClient
