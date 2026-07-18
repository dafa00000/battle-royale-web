--[[
	Lobby Remotes - RemoteEvent/RemoteFunction definitions for Lobby Place
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = Instance.new("Folder")
Remotes.Name = "LobbyRemotes"
Remotes.Parent = ReplicatedStorage

-- RemoteFunctions (Server -> Client callbacks)
local JoinQueue = Instance.new("RemoteFunction")
JoinQueue.Name = "JoinQueue"
JoinQueue.Parent = Remotes

local LeaveQueue = Instance.new("RemoteFunction")
LeaveQueue.Name = "LeaveQueue"
LeaveQueue.Parent = Remotes

local JoinSquad = Instance.new("RemoteFunction")
JoinSquad.Name = "JoinSquad"
JoinSquad.Parent = Remotes

local LeaveSquad = Instance.new("RemoteFunction")
LeaveSquad.Name = "LeaveSquad"
LeaveSquad.Parent = Remotes

local InviteToSquad = Instance.new("RemoteFunction")
InviteToSquad.Name = "InviteToSquad"
InviteToSquad.Parent = Remotes

local KickFromSquad = Instance.new("RemoteFunction")
KickFromSquad.Name = "KickFromSquad"
KickFromSquad.Parent = Remotes

local ReadyUp = Instance.new("RemoteFunction")
ReadyUp.Name = "ReadyUp"
ReadyUp.Parent = Remotes

local SelectMap = Instance.new("RemoteFunction")
SelectMap.Name = "SelectMap"
SelectMap.Parent = Remotes

local UpdateLoadout = Instance.new("RemoteFunction")
UpdateLoadout.Name = "UpdateLoadout"
UpdateLoadout.Parent = Remotes

local PurchaseItem = Instance.new("RemoteFunction")
PurchaseItem.Name = "PurchaseItem"
PurchaseItem.Parent = Remotes

local EquipSkin = Instance.new("RemoteFunction")
EquipSkin.Name = "EquipSkin"
EquipSkin.Parent = Remotes

local GetPlayerProfile = Instance.new("RemoteFunction")
GetPlayerProfile.Name = "GetPlayerProfile"
GetPlayerProfile.Parent = Remotes

local GetLeaderboard = Instance.new("RemoteFunction")
GetLeaderboard.Name = "GetLeaderboard"
GetLeaderboard.Parent = Remotes

-- RemoteEvents (Server -> Client notifications)
local QueueUpdate = Instance.new("RemoteEvent")
QueueUpdate.Name = "QueueUpdate"
QueueUpdate.Parent = Remotes

local SquadUpdate = Instance.new("RemoteEvent")
SquadUpdate.Name = "SquadUpdate"
SquadUpdate.Parent = Remotes

local SquadInvite = Instance.new("RemoteEvent")
SquadInvite.Name = "SquadInvite"
SquadInvite.Parent = Remotes

local MatchFound = Instance.new("RemoteEvent")
MatchFound.Name = "MatchFound"
MatchFound.Parent = Remotes

local LoadoutUpdate = Instance.new("RemoteEvent")
LoadoutUpdate.Name = "LoadoutUpdate"
LoadoutUpdate.Parent = Remotes

local CurrencyUpdate = Instance.new("RemoteEvent")
CurrencyUpdate.Name = "CurrencyUpdate"
CurrencyUpdate.Parent = Remotes

local InventoryUpdate = Instance.new("RemoteEvent")
InventoryUpdate.Name = "InventoryUpdate"
InventoryUpdate.Parent = Remotes

local SkinUpdate = Instance.new("RemoteEvent")
SkinUpdate.Name = "SkinUpdate"
SkinUpdate.Parent = Remotes

local Notification = Instance.new("RemoteEvent")
Notification.Name = "Notification"
Notification.Parent = Remotes

local SettingsUpdate = Instance.new("RemoteEvent")
SettingsUpdate.Name = "SettingsUpdate"
SettingsUpdate.Parent = Remotes

-- Client -> Server events
local RequestQueueStatus = Instance.new("RemoteEvent")
RequestQueueStatus.Name = "RequestQueueStatus"
RequestQueueStatus.Parent = Remotes

local RequestSquadInfo = Instance.new("RemoteEvent")
RequestSquadInfo.Name = "RequestSquadInfo"
RequestSquadInfo.Parent = Remotes

local RequestShopData = Instance.new("RemoteEvent")
RequestShopData.Name = "RequestShopData"
RequestShopData.Parent = Remotes

local ChatMessage = Instance.new("RemoteEvent")
ChatMessage.Name = "ChatMessage"
ChatMessage.Parent = Remotes

-- Export for type checking
return {
	-- Functions
	JoinQueue = JoinQueue,
	LeaveQueue = LeaveQueue,
	JoinSquad = JoinSquad,
	LeaveSquad = LeaveSquad,
	InviteToSquad = InviteToSquad,
	KickFromSquad = KickFromSquad,
	ReadyUp = ReadyUp,
	SelectMap = SelectMap,
	UpdateLoadout = UpdateLoadout,
	PurchaseItem = PurchaseItem,
	EquipSkin = EquipSkin,
	GetPlayerProfile = GetPlayerProfile,
	GetLeaderboard = GetLeaderboard,
	
	-- Events (Server -> Client)
	QueueUpdate = QueueUpdate,
	SquadUpdate = SquadUpdate,
	SquadInvite = SquadInvite,
	MatchFound = MatchFound,
	LoadoutUpdate = LoadoutUpdate,
	CurrencyUpdate = CurrencyUpdate,
	InventoryUpdate = InventoryUpdate,
	SkinUpdate = SkinUpdate,
	Notification = Notification,
	SettingsUpdate = SettingsUpdate,
	
	-- Events (Client -> Server)
	RequestQueueStatus = RequestQueueStatus,
	RequestSquadInfo = RequestSquadInfo,
	RequestShopData = RequestShopData,
	ChatMessage = ChatMessage,
}