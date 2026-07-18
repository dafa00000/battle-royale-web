--[[
	Match Remotes - RemoteEvent/RemoteFunction definitions for Match Place
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = Instance.new("Folder")
Remotes.Name = "MatchRemotes"
Remotes.Parent = ReplicatedStorage

-- Combat Remotes
local WeaponFire = Instance.new("RemoteEvent")
WeaponFire.Name = "WeaponFire"
WeaponFire.Parent = Remotes

local WeaponHit = Instance.new("RemoteEvent")
WeaponHit.Name = "WeaponHit"
WeaponHit.Parent = Remotes

local WeaponReload = Instance.new("RemoteEvent")
WeaponReload.Name = "WeaponReload"
WeaponReload.Parent = Remotes

local WeaponSwitch = Instance.new("RemoteEvent")
WeaponSwitch.Name = "WeaponSwitch"
WeaponSwitch.Parent = Remotes

local WeaponAds = Instance.new("RemoteEvent")
WeaponAds.Name = "WeaponAds"
WeaponAds.Parent = Remotes

local MeleeAttack = Instance.new("RemoteEvent")
MeleeAttack.Name = "MeleeAttack"
MeleeAttack.Parent = Remotes

local ThrowProjectile = Instance.new("RemoteEvent")
ThrowProjectile.Name = "ThrowProjectile"
ThrowProjectile.Parent = Remotes

local DamageIndicator = Instance.new("RemoteEvent")
DamageIndicator.Name = "DamageIndicator"
DamageIndicator.Parent = Remotes

local HitMarker = Instance.new("RemoteEvent")
HitMarker.Name = "HitMarker"
HitMarker.Parent = Remotes

local KillFeed = Instance.new("RemoteEvent")
KillFeed.Name = "KillFeed"
KillFeed.Parent = Remotes

-- Movement Remotes
local MovementUpdate = Instance.new("RemoteEvent")
MovementUpdate.Name = "MovementUpdate"
MovementUpdate.Parent = Remotes

local StanceChange = Instance.new("RemoteEvent")
StanceChange.Name = "StanceChange"
StanceChange.Parent = Remotes

local VaultAction = Instance.new("RemoteEvent")
VaultAction.Name = "VaultAction"
VaultAction.Parent = Remotes

local SlideAction = Instance.new("RemoteEvent")
SlideAction.Name = "SlideAction"
SlideAction.Parent = Remotes

local LeanUpdate = Instance.new("RemoteEvent")
LeanUpdate.Name = "LeanUpdate"
LeanUpdate.Parent = Remotes

local ParachuteDeploy = Instance.new("RemoteEvent")
ParachuteDeploy.Name = "ParachuteDeploy"
ParachuteDeploy.Parent = Remotes

-- Zone Remotes
local ZoneUpdate = Instance.new("RemoteEvent")
ZoneUpdate.Name = "ZoneUpdate"
ZoneUpdate.Parent = Remotes

local GasEffect = Instance.new("RemoteEvent")
GasEffect.Name = "GasEffect"
GasEffect.Parent = Remotes

local ZoneWarning = Instance.new("RemoteEvent")
ZoneWarning.Name = "ZoneWarning"
ZoneWarning.Parent = Remotes

-- Vehicle Remotes
local VehicleEnter = Instance.new("RemoteEvent")
VehicleEnter.Name = "VehicleEnter"
VehicleEnter.Parent = Remotes

local VehicleExit = Instance.new("RemoteEvent")
VehicleExit.Name = "VehicleExit"
VehicleExit.Parent = Remotes

local VehicleUpdate = Instance.new("RemoteEvent")
VehicleUpdate.Name = "VehicleUpdate"
VehicleUpdate.Parent = Remotes

local VehicleDamage = Instance.new("RemoteEvent")
VehicleDamage.Name = "VehicleDamage"
VehicleDamage.Parent = Remotes

local VehicleEnterRequest = Instance.new("RemoteFunction")
VehicleEnterRequest.Name = "VehicleEnterRequest"
VehicleEnterRequest.Parent = Remotes

local VehicleExitRequest = Instance.new("RemoteFunction")
VehicleExitRequest.Name = "VehicleExitRequest"
VehicleExitRequest.Parent = Remotes

-- Inventory Remotes
local InventoryAction = Instance.new("RemoteFunction")
InventoryAction.Name = "InventoryAction"
InventoryAction.Parent = Remotes

local InventoryUpdate = Instance.new("RemoteEvent")
InventoryUpdate.Name = "InventoryUpdate"
InventoryUpdate.Parent = Remotes

local LootDrop = Instance.new("RemoteEvent")
LootDrop.Name = "LootDrop"
LootDrop.Parent = Remotes

local LootPickup = Instance.new("RemoteFunction")
LootPickup.Name = "LootPickup"
LootPickup.Parent = Remotes

local GroundLootUpdate = Instance.new("RemoteEvent")
GroundLootUpdate.Name = "GroundLootUpdate"
GroundLootUpdate.Parent = Remotes

-- Interaction Remotes
local Interact = Instance.new("RemoteFunction")
Interact.Name = "Interact"
Interact.Parent = Remotes

local RevivePlayer = Instance.new("RemoteFunction")
RevivePlayer.Name = "RevivePlayer"
RevivePlayer.Parent = Remotes

local UseConsumable = Instance.new("RemoteFunction")
UseConsumable.Name = "UseConsumable"
UseConsumable.Parent = Remotes

-- Match Flow Remotes
local MatchStart = Instance.new("RemoteEvent")
MatchStart.Name = "MatchStart"
MatchStart.Parent = Remotes

local MatchEnd = Instance.new("RemoteEvent")
MatchEnd.Name = "MatchEnd"
MatchEnd.Parent = Remotes

local PlayerEliminated = Instance.new("RemoteEvent")
PlayerEliminated.Name = "PlayerEliminated"
PlayerEliminated.Parent = Remotes

local PlayerDowned = Instance.new("RemoteEvent")
PlayerDowned.Name = "PlayerDowned"
PlayerDowned.Parent = Remotes

local SpectateTarget = Instance.new("RemoteEvent")
SpectateTarget.Name = "SpectateTarget"
SpectateTarget.Parent = Remotes

local RequestSpectate = Instance.new("RemoteFunction")
RequestSpectate.Name = "RequestSpectate"
RequestSpectate.Parent = Remotes

-- UI/Client Remotes
local HudUpdate = Instance.new("RemoteEvent")
HudUpdate.Name = "HudUpdate"
HudUpdate.Parent = Remotes

local MinimapUpdate = Instance.new("RemoteEvent")
MinimapUpdate.Name = "MinimapUpdate"
MinimapUpdate.Parent = Remotes

local CompassUpdate = Instance.new("RemoteEvent")
CompassUpdate.Name = "CompassUpdate"
CompassUpdate.Parent = Remotes

local VoiceProximity = Instance.new("RemoteEvent")
VoiceProximity.Name = "VoiceProximity"
VoiceProximity.Parent = Remotes

local PingLocation = Instance.new("RemoteEvent")
PingLocation.Name = "PingLocation"
PingLocation.Parent = Remotes

local EmotePlay = Instance.new("RemoteEvent")
EmotePlay.Name = "EmotePlay"
EmotePlay.Parent = Remotes

-- Admin/Debug
local AdminCommand = Instance.new("RemoteFunction")
AdminCommand.Name = "AdminCommand"
AdminCommand.Parent = Remotes

local DebugInfo = Instance.new("RemoteFunction")
DebugInfo.Name = "DebugInfo"
DebugInfo.Parent = Remotes

-- Export
return {
	-- Combat
	WeaponFire = WeaponFire,
	WeaponHit = WeaponHit,
	WeaponReload = WeaponReload,
	WeaponSwitch = WeaponSwitch,
	WeaponAds = WeaponAds,
	MeleeAttack = MeleeAttack,
	ThrowProjectile = ThrowProjectile,
	DamageIndicator = DamageIndicator,
	HitMarker = HitMarker,
	KillFeed = KillFeed,
	
	-- Movement
	MovementUpdate = MovementUpdate,
	StanceChange = StanceChange,
	VaultAction = VaultAction,
	SlideAction = SlideAction,
	LeanUpdate = LeanUpdate,
	ParachuteDeploy = ParachuteDeploy,
	
	-- Zone
	ZoneUpdate = ZoneUpdate,
	GasEffect = GasEffect,
	ZoneWarning = ZoneWarning,
	
	-- Vehicle
	VehicleEnter = VehicleEnter,
	VehicleExit = VehicleExit,
	VehicleUpdate = VehicleUpdate,
	VehicleDamage = VehicleDamage,
	VehicleEnterRequest = VehicleEnterRequest,
	VehicleExitRequest = VehicleExitRequest,
	
	-- Inventory
	InventoryAction = InventoryAction,
	InventoryUpdate = InventoryUpdate,
	LootDrop = LootDrop,
	LootPickup = LootPickup,
	GroundLootUpdate = GroundLootUpdate,
	
	-- Interaction
	Interact = Interact,
	RevivePlayer = RevivePlayer,
	UseConsumable = UseConsumable,
	
	-- Match Flow
	MatchStart = MatchStart,
	MatchEnd = MatchEnd,
	PlayerEliminated = PlayerEliminated,
	PlayerDowned = PlayerDowned,
	SpectateTarget = SpectateTarget,
	RequestSpectate = RequestSpectate,
	
	-- UI
	HudUpdate = HudUpdate,
	MinimapUpdate = MinimapUpdate,
	CompassUpdate = CompassUpdate,
	VoiceProximity = VoiceProximity,
	PingLocation = PingLocation,
	EmotePlay = EmotePlay,
	
	-- Admin
	AdminCommand = AdminCommand,
	DebugInfo = DebugInfo,
}