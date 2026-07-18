--[[
	SquadUI - Squad management interface
	Member list, invite input, ready toggle, kick/leave buttons
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local LobbyRemotes = ReplicatedStorage:WaitForChild("LobbyRemotes")

local SquadUI = {}
local localPlayer = nil
local screenGui = nil
local squadFrame = nil
local memberFrames = {}

local T = Constants.UI_THEME

-- ==================== UI CREATION ====================

local function Create(className, props, children)
	return Util.Create(className, props, children)
end

local function CreateCorner(radius)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

-- ==================== MEMBER CARD ====================

local function CreateMemberCard(member, isLeader)
	local card = Create("Frame", {
		Name = "Member_" .. member.UserId,
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = T.Background,
		BorderSizePixel = 0,
	}, { CreateCorner(8) })
	
	local layout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	layout.Parent = card
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}).Parent = card
	
	-- Avatar
	local avatar = Create("ImageLabel", {
		Name = "Avatar",
		Size = UDim2.new(0, 40, 0, 40),
		BackgroundColor3 = T.Surface,
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. member.UserId .. "&w=150&h=150",
	}, { CreateCorner(20) })
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
		Padding = UDim.new(0, 2),
	})
	infoLayout.Parent = info
	
	local nameLabel = Create("TextLabel", {
		Name = "Name",
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = member.Username .. (isLeader and " 👑" or ""),
		TextColor3 = isLeader and T.Secondary or T.Text,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	nameLabel.Parent = info
	
	local statusLabel = Create("TextLabel", {
		Name = "Status",
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = member.IsReady and "✓ Ready" or "Not ready",
		TextColor3 = member.IsReady and T.Success or T.TextMuted,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	statusLabel.Parent = info
	
	-- Kick button (if leader and not self)
	if isLeader and member.UserId ~= localPlayer.UserId then
		local kickBtn = Create("TextButton", {
			Name = "Kick",
			Size = UDim2.new(0, 50, 0, 28),
			BackgroundColor3 = T.Danger,
			Text = "Kick",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 12,
			Font = Enum.Font.GothamMedium,
		}, { CreateCorner(6) })
		kickBtn.Parent = card
		kickBtn.Position = UDim2.new(1, -60, 0.5, -14)
		
		kickBtn.MouseButton1Click:Connect(function()
			LobbyRemotes.KickFromSquad:InvokeServer(member.UserId)
		end)
	end
	
	return card
end

-- ==================== SQUAD PANEL ====================

function SquadUI.Initialize(player)
	localPlayer = player
	
	screenGui = Create("ScreenGui", {
		Name = "SquadGui",
		ResetOnSpawn = false,
	})
	screenGui.Parent = player:WaitForChild("PlayerGui")
	
	-- Toggle button (top right)
	local toggleBtn = Create("TextButton", {
		Name = "SquadToggle",
		Size = UDim2.new(0, 120, 0, 40),
		Position = UDim2.new(1, -130, 0, 10),
		BackgroundColor3 = T.Surface,
		Text = "SQUAD",
		TextColor3 = T.Text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
	}, { CreateCorner(8) })
	toggleBtn.Parent = screenGui
	
	-- Squad panel (hidden by default)
	squadFrame = Create("Frame", {
		Name = "SquadPanel",
		Size = UDim2.new(0, 350, 0, 450),
		Position = UDim2.new(1, -370, 0, 60),
		BackgroundColor3 = T.Background,
		BorderSizePixel = 0,
		Visible = false,
	}, { CreateCorner(12), Create("UIStroke", { Color = T.Border, Thickness = 2 }) })
	squadFrame.Parent = screenGui
	
	toggleBtn.MouseButton1Click:Connect(function()
		squadFrame.Visible = not squadFrame.Visible
	end)
	
	-- Panel content
	local title = Create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Text = "SQUAD MANAGEMENT",
		TextColor3 = T.Text,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
	})
	title.Parent = squadFrame
	
	local closeBtn = Create("TextButton", {
		Name = "Close",
		Size = UDim2.new(0, 30, 0, 30),
		Position = UDim2.new(1, -35, 0, 10),
		BackgroundColor3 = T.Danger,
		Text = "×",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 20,
		Font = Enum.Font.GothamBold,
	}, { CreateCorner(6) })
	closeBtn.Parent = squadFrame
	closeBtn.MouseButton1Click:Connect(function()
		squadFrame.Visible = false
	end)
	
	-- Invite section
	local inviteFrame = Create("Frame", {
		Name = "Invite",
		Size = UDim2.new(1, -20, 0, 80),
		Position = UDim2.new(0, 10, 0, 50),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(8) })
	inviteFrame.Parent = squadFrame
	
	local inviteInput = Create("TextBox", {
		Name = "InviteInput",
		Size = UDim2.new(1, -100, 0, 36),
		Position = UDim2.new(0, 10, 0, 10),
		BackgroundColor3 = T.Background,
		TextColor3 = T.Text,
		PlaceholderText = "Enter username...",
		PlaceholderColor3 = T.TextMuted,
		TextSize = 14,
		Font = Enum.Font.Gotham,
	}, { CreateCorner(6) })
	inviteInput.Parent = inviteFrame
	
	local inviteBtn = Create("TextButton", {
		Name = "InviteBtn",
		Size = UDim2.new(0, 70, 0, 36),
		Position = UDim2.new(1, -80, 0, 10),
		BackgroundColor3 = T.Primary,
		Text = "Invite",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
	}, { CreateCorner(6) })
	inviteBtn.Parent = inviteFrame
	
	inviteBtn.MouseButton1Click:Connect(function()
		local username = inviteInput.Text
		if #username > 0 then
			-- Find player by name
			local target = Players:FindFirstChild(username)
			if target then
				LobbyRemotes.InviteToSquad:InvokeServer(target.UserId)
			else
				-- Show error
			end
		end
	end)
	
	-- Member list container
	local memberList = Create("ScrollingFrame", {
		Name = "MemberList",
		Size = UDim2.new(1, -20, 0, 250),
		Position = UDim2.new(0, 10, 0, 140),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = T.Border,
	})
	memberList.Parent = squadFrame
	
	local listLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
	})
	listLayout.Parent = memberList
	
	-- Action buttons
	local btnFrame = Create("Frame", {
		Name = "Actions",
		Size = UDim2.new(1, -20, 0, 50),
		Position = UDim2.new(0, 10, 1, -60),
		BackgroundTransparency = 1,
	})
	btnFrame.Parent = squadFrame
	
	local btnLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
	})
	btnLayout.Parent = btnFrame
	
	local readyBtn = Create("TextButton", {
		Name = "Ready",
		Size = UDim2.new(0.5, -5, 1, 0),
		BackgroundColor3 = T.Success,
		Text = "READY",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 16,
		Font = Enum.Font.GothamBold,
	}, { CreateCorner(8) })
	readyBtn.Parent = btnFrame
	
	local leaveBtn = Create("TextButton", {
		Name = "Leave",
		Size = UDim2.new(0.5, -5, 1, 0),
		BackgroundColor3 = T.Danger,
		Text = "LEAVE",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 16,
		Font = Enum.Font.GothamBold,
	}, { CreateCorner(8) })
	leaveBtn.Parent = btnFrame
	
	readyBtn.MouseButton1Click:Connect(function()
		local isReady = readyBtn.Text == "READY"
		LobbyRemotes.ReadyUp:InvokeServer(isReady)
	end)
	
	leaveBtn.MouseButton1Click:Connect(function()
		LobbyRemotes.LeaveSquad:InvokeServer()
	end)
	
	print("[SquadUI] Initialized")
end

function SquadUI.UpdateSquad(squadData)
	-- Clear existing
	for _, frame in pairs(memberFrames) do
		frame:Destroy()
	end
	memberFrames = {}
	
	if not squadData or not squadData.SquadId then
		-- No squad
		return
	end
	
	-- Update member list
	local memberList = squadFrame and squadFrame:FindFirstChild("MemberList")
	if not memberList then return end
	
	local isLeader = squadData.Leader == localPlayer.UserId
	
	for _, member in ipairs(squadData.Members or {}) do
		local card = CreateMemberCard(member, isLeader)
		card.Parent = memberList
		memberFrames[member.UserId] = card
	end
end

function SquadUI.ShowInvite(data)
	-- Create invite popup
	local popup = Create("Frame", {
		Name = "SquadInvite",
		Size = UDim2.new(0, 300, 0, 120),
		Position = UDim2.new(0.5, -150, 0.5, -60),
		BackgroundColor3 = T.Surface,
		BorderSizePixel = 0,
	}, { CreateCorner(12), Create("UIStroke", { Color = T.Primary, Thickness = 2 }) })
	popup.Parent = screenGui
	
	local title = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Text = "Squad Invite",
		TextColor3 = T.Text,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
	})
	title.Parent = popup
	
	local msg = Create("TextLabel", {
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0, 10, 0, 35),
		BackgroundTransparency = 1,
		Text = data.InviterName .. " invited you to their squad",
		TextColor3 = T.TextMuted,
		TextSize = 14,
		Font = Enum.Font.Gotham,
	})
	msg.Parent = popup
	
	local btnFrame = Create("Frame", {
		Size = UDim2.new(1, -20, 0, 36),
		Position = UDim2.new(0, 10, 1, -46),
		BackgroundTransparency = 1,
	})
	btnFrame.Parent = popup
	
	local btnLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
	})
	btnLayout.Parent = btnFrame
	
	local acceptBtn = Create("TextButton", {
		Size = UDim2.new(0.5, -5, 1, 0),
		BackgroundColor3 = T.Success,
		Text = "Accept",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		Font = Enum.Font.GothamBold,
	}, { CreateCorner(6) })
	acceptBtn.Parent = btnFrame
	
	local declineBtn = Create("TextButton", {
		Size = UDim2.new(0.5, -5, 1, 0),
		BackgroundColor3 = T.Danger,
		Text = "Decline",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		Font = Enum.Font.GothamBold,
	}, { CreateCorner(6) })
	declineBtn.Parent = btnFrame
	
	acceptBtn.MouseButton1Click:Connect(function()
		LobbyRemotes.JoinSquad:InvokeServer(data.SquadId)
		popup:Destroy()
	end)
	
	declineBtn.MouseButton1Click:Connect(function()
		popup:Destroy()
	end)
	
	-- Auto-decline after 30s
	task.delay(30, function()
		if popup.Parent then
			popup:Destroy()
		end
	end)
end

return SquadUI
