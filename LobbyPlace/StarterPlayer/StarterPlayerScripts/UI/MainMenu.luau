--[[
	MainMenu - Lobby main menu UI
	Play button, squad display, player stats, currency, settings
	Dark theme from Constants.UI_THEME
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local MainMenu = {}
local localPlayer = nil
local playerProfile = nil

-- UI References
local screenGui = nil
local mainFrame = nil
local playButton = nil
local queueLabel = nil
local statsFrame = nil
local currencyLabel = nil

-- Theme shortcuts
local T = Constants.UI_THEME

-- ==================== UI CREATION ====================

local function Create(className, props)
	return Util.Create(className, props)
end

local function CreateCorner(radius)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function CreateStroke(color, thickness)
	return Create("UIStroke", { Color = color, Thickness = thickness })
end

local function CreatePadding(p)
	return Create("UIPadding", {
		PaddingLeft = UDim.new(0, p),
		PaddingRight = UDim.new(0, p),
		PaddingTop = UDim.new(0, p),
		PaddingBottom = UDim.new(0, p),
	})
end

-- ==================== COMPONENTS ====================

local function CreateHeader(parent)
	local header = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(12) })
	header.Parent = parent
	
	local title = Create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.new(0, 20, 0, 0),
		BackgroundTransparency = 1,
		Text = Constants.GAME_NAME,
		TextColor3 = T.Text,
		TextSize = 28,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	title.Parent = header
	
	local version = Create("TextLabel", {
		Name = "Version",
		Size = UDim2.new(0, 100, 0, 20),
		Position = UDim2.new(1, -110, 0, 10),
		BackgroundTransparency = 1,
		Text = "v" .. Constants.VERSION,
		TextColor3 = T.TextMuted,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	version.Parent = header
	
	return header
end

local function CreatePlayerCard(parent)
	local card = Create("Frame", {
		Name = "PlayerCard",
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(12), CreateStroke(T.Border, 1) })
	card.Parent = parent
	
	local layout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 16),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	layout.Parent = card
	CreatePadding(20).Parent = card
	
	-- Avatar
	local avatar = Create("ImageLabel", {
		Name = "Avatar",
		Size = UDim2.new(0, 80, 0, 80),
		BackgroundColor3 = T.Background,
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. (localPlayer and localPlayer.UserId or 0) .. "&w=150&h=150",
	}, { CreateCorner(40) })
	avatar.Parent = card
	
	-- Info
	local info = Create("Frame", {
		Name = "Info",
		Size = UDim2.new(1, -120, 1, 0),
		BackgroundTransparency = 1,
	})
	info.Parent = card
	
	local infoLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 4),
	})
	infoLayout.Parent = info
	
	local nameLabel = Create("TextLabel", {
		Name = "Name",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = localPlayer and localPlayer.DisplayName or "Player",
		TextColor3 = T.Text,
		TextSize = 24,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	nameLabel.Parent = info
	
	local levelLabel = Create("TextLabel", {
		Name = "Level",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "Level 1",
		TextColor3 = T.Primary,
		TextSize = 16,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	levelLabel.Parent = info
	
	currencyLabel = Create("TextLabel", {
		Name = "Currency",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "💰 0  💎 0",
		TextColor3 = T.Secondary,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	currencyLabel.Parent = info
	
	return card
end

local function CreatePlaySection(parent)
	local section = Create("Frame", {
		Name = "PlaySection",
		Size = UDim2.new(1, 0, 0, 200),
		BackgroundTransparency = 1,
	})
	section.Parent = parent
	
	playButton = Create("TextButton", {
		Name = "PlayButton",
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = T.Primary,
		Text = "PLAY",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 32,
		Font = Enum.Font.GothamBlack,
		AutoButtonColor = true,
	}, { CreateCorner(12) })
	playButton.Parent = section
	
	queueLabel = Create("TextLabel", {
		Name = "QueueLabel",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 80),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = T.TextMuted,
		TextSize = 16,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	queueLabel.Parent = section
	
	-- Map selector
	local mapFrame = Create("Frame", {
		Name = "MapSelector",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 120),
		BackgroundTransparency = 1,
	})
	mapFrame.Parent = section
	
	local mapLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	mapLayout.Parent = mapFrame
	
	for _, map in ipairs(Constants.MAPS) do
		local mapBtn = Create("TextButton", {
			Name = map,
			Size = UDim2.new(0, 100, 1, 0),
			BackgroundColor3 = map == Constants.DEFAULT_MAP and T.Primary or T.Surface,
			Text = map:gsub("_Remastered", ""),
			TextColor3 = map == Constants.DEFAULT_MAP and Color3.new(1,1,1) or T.Text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
		}, { CreateCorner(8) })
		mapBtn.Parent = mapFrame
		
		mapBtn.MouseButton1Click:Connect(function()
			for _, btn in ipairs(mapFrame:GetChildren()) do
				if btn:IsA("TextButton") then
					local isSelected = btn.Name == map
					btn.BackgroundColor3 = isSelected and T.Primary or T.Surface
					btn.TextColor3 = isSelected and Color3.new(1,1,1) or T.Text
				end
			end
		end)
	end
	
	return section
end

local function CreateStatsPanel(parent)
	statsFrame = Create("Frame", {
		Name = "StatsPanel",
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(12), CreateStroke(T.Border, 1) })
	statsFrame.Parent = parent
	
	local title = Create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Text = "CAREER STATS",
		TextColor3 = T.TextMuted,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
	})
	title.Parent = statsFrame
	CreatePadding(16).Parent = statsFrame
	
	local grid = Create("Frame", {
		Name = "Grid",
		Size = UDim2.new(1, 0, 0, 80),
		Position = UDim2.new(0, 0, 0, 50),
		BackgroundTransparency = 1,
	})
	grid.Parent = statsFrame
	
	local gridLayout = Create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -10, 0, 40),
		CellPadding = UDim2.new(0, 20, 0, 10),
	})
	gridLayout.Parent = grid
	
	local stats = {
		{ Name = "Kills", Value = "0", Icon = "🔫" },
		{ Name = "Wins", Value = "0", Icon = "🏆" },
		{ Name = "Top 10", Value = "0", Icon = "🎯" },
		{ Name = "K/D", Value = "0.0", Icon = "📊" },
	}
	
	for _, stat in ipairs(stats) do
		local statFrame = Create("Frame", {
			Name = stat.Name,
			BackgroundTransparency = 1,
		})
		statFrame.Parent = grid
		
		local iconLabel = Create("TextLabel", {
			Name = "Icon",
			Size = UDim2.new(0, 30, 1, 0),
			BackgroundTransparency = 1,
			Text = stat.Icon,
			TextSize = 20,
			Font = Enum.Font.Gotham,
		})
		iconLabel.Parent = statFrame
		
		local valueLabel = Create("TextLabel", {
			Name = "Value",
			Size = UDim2.new(0, 80, 0, 24),
			Position = UDim2.new(0, 35, 0, 0),
			BackgroundTransparency = 1,
			Text = stat.Value,
			TextColor3 = T.Text,
			TextSize = 20,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		valueLabel.Parent = statFrame
		
		local nameLabel = Create("TextLabel", {
			Name = "Label",
			Size = UDim2.new(0, 80, 0, 16),
			Position = UDim2.new(0, 35, 0, 24),
			BackgroundTransparency = 1,
			Text = stat.Name,
			TextColor3 = T.TextMuted,
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		nameLabel.Parent = statFrame
	end
	
	return statsFrame
end

local function CreateSquadPanel(parent)
	local panel = Create("Frame", {
		Name = "SquadPanel",
		Size = UDim2.new(1, 0, 0, 180),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(12), CreateStroke(T.Border, 1) })
	panel.Parent = parent
	
	local title = Create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Text = "SQUAD",
		TextColor3 = T.TextMuted,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
	})
	title.Parent = panel
	CreatePadding(16).Parent = panel
	
	local memberList = Create("Frame", {
		Name = "MemberList",
		Size = UDim2.new(1, 0, 0, 120),
		Position = UDim2.new(0, 0, 0, 45),
		BackgroundTransparency = 1,
	})
	memberList.Parent = panel
	
	local listLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
	})
	listLayout.Parent = memberList
	
	-- Placeholder slots
	for i = 1, 4 do
		local slot = Create("Frame", {
			Name = "Slot" .. i,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = T.Background,
			BorderSizePixel = 0,
		}, { CreateCorner(6) })
		slot.Parent = memberList
		
		local slotLabel = Create("TextLabel", {
			Name = "Label",
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			BackgroundTransparency = 1,
			Text = i == 1 and (localPlayer and localPlayer.Name or "You") or "Empty",
			TextColor3 = i == 1 and T.Primary or T.TextMuted,
			TextSize = 14,
			Font = i == 1 and Enum.Font.GothamMedium or Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		slotLabel.Parent = slot
	end
	
	return panel
end

-- ==================== PUBLIC API ====================

function MainMenu.Initialize(player, profile)
	localPlayer = player
	playerProfile = profile
	
	-- Create ScreenGui
	screenGui = Create("ScreenGui", {
		Name = "LobbyGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	screenGui.Parent = player:WaitForChild("PlayerGui")
	
	-- Main container
	mainFrame = Create("Frame", {
		Name = "MainFrame",
		Size = UDim2.new(0, 500, 0, 700),
		Position = UDim2.new(0.5, -250, 0.5, -350),
		BackgroundColor3 = T.Background,
		BorderSizePixel = 0,
	}, { CreateCorner(16), CreateStroke(T.Border, 2) })
	mainFrame.Parent = screenGui
	
	local layout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 16),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	layout.Parent = mainFrame
	CreatePadding(20).Parent = mainFrame
	
	-- Build components
	CreateHeader(mainFrame)
	CreatePlayerCard(mainFrame)
	CreatePlaySection(mainFrame)
	CreateStatsPanel(mainFrame)
	CreateSquadPanel(mainFrame)
	
	-- Update with profile data
	if profile then
		MainMenu.UpdateStats(profile.Stats)
		MainMenu.UpdateCurrency(profile.Currency)
	end
	
	-- Play button handler
	playButton.MouseButton1Click:Connect(function()
		MainMenu.OnPlayClicked()
	end)
	
	print("[MainMenu] Initialized")
end

function MainMenu.UpdateStats(stats)
	if not statsFrame then return end
	-- Would update stat values here
end

function MainMenu.UpdateCurrency(currency)
	if currencyLabel then
		currencyLabel.Text = string.format("💰 %s  💎 %s",
			Util.FormatNumber(currency.Cash or 0),
			Util.FormatNumber(currency.Credits or 0))
	end
end

function MainMenu.UpdateQueueStatus(data)
	if not queueLabel then return end
	
	if data.State == "Queued" then
		queueLabel.Text = string.format("In queue... Position: %d | Est. wait: %ds",
			data.Position or 0, data.EstimatedWait or 0)
		queueLabel.TextColor3 = T.Primary
		playButton.Text = "CANCEL"
		playButton.BackgroundColor3 = T.Danger
	elseif data.State == "Found" then
		queueLabel.Text = "Match found! Get ready..."
		queueLabel.TextColor3 = T.Success
		playButton.Text = "READY"
		playButton.BackgroundColor3 = T.Success
	else
		queueLabel.Text = ""
		playButton.Text = "PLAY"
		playButton.BackgroundColor3 = T.Primary
	end
end

function MainMenu.UpdateSquadDisplay(squadData)
	-- SquadUI handles detailed squad display
	-- This is just the mini panel in main menu
end

function MainMenu.ShowMatchFound(data)
	MainMenu.ShowNotification("Success", "Match found! Teleporting...")
end

function MainMenu.ShowNotification(notifType, message)
	-- Simple notification system
	local notif = Create("Frame", {
		Name = "Notification",
		Size = UDim2.new(0, 300, 0, 60),
		Position = UDim2.new(0.5, -150, 0, 20),
		BackgroundColor3 = notifType == "Error" and T.Danger
			or notifType == "Warning" and T.Secondary
			or T.Success,
		BorderSizePixel = 0,
	}, { CreateCorner(8) })
	notif.Parent = screenGui
	
	local label = Create("TextLabel", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		Text = message,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
	})
	label.Parent = notif
	
	-- Auto-remove
	task.delay(3, function()
		local tween = TweenService:Create(notif, TweenInfo.new(0.3), {
			Position = UDim2.new(0.5, -150, 0, -70),
			BackgroundTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		notif:Destroy()
	end)
end

function MainMenu.OnPlayClicked()
	local text = playButton.Text
	if text == "PLAY" then
		local success, msg = pcall(function()
			return game:GetService("ReplicatedStorage").LobbyRemotes.JoinQueue:InvokeServer(nil, nil)
		end)
		if not success then
			MainMenu.ShowNotification("Error", "Failed to join queue")
		end
	elseif text == "CANCEL" then
		pcall(function()
			game:GetService("ReplicatedStorage").LobbyRemotes.LeaveQueue:InvokeServer()
		end)
	elseif text == "READY" then
		pcall(function()
			game:GetService("ReplicatedStorage").LobbyRemotes.ReadyUp:InvokeServer(true)
		end)
	end
end

return MainMenu
