--[[
	RaycastWeapon Server - Server-authoritative weapon system with client prediction reconciliation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage.Remotes
local MatchRemotes = Remotes.MatchRemotes
local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local Ballistics = require(script.Parent.Ballistics)
local DamageService = require(script.Parent.DamageService)
local HitValidation = require(script.Parent.HitValidation)

local WeaponFire = MatchRemotes.WeaponFire
local WeaponHit = MatchRemotes.WeaponHit
local WeaponReload = MatchRemotes.WeaponReload
local WeaponSwitch = MatchRemotes.WeaponSwitch
local WeaponAds = MatchRemotes.WeaponAds
local HitMarker = MatchRemotes.HitMarker
local KillFeed = MatchRemotes.KillFeed

-- Server weapon state
local playerWeapons: { [Player]: { [string]: WeaponState } } = {}
local pendingShots: { [Player]: { PendingShot } } = {}

export type WeaponState = {
	templateId: string,
	currentAmmo: number,
	reserveAmmo: number,
	isReloading: boolean,
	reloadStartTime: number,
	lastFireTime: number,
	shotIndex: number,
	spreadPattern: { Vector2 },
	isAds: boolean,
	equipped: boolean,
}

export type PendingShot = {
	shotId: number,
	origin: Vector3,
	direction: Vector3,
	timestamp: number,
	weaponId: string,
	shotIndex: number,
	seed: number,
	processed: boolean,
}

-- Weapon templates cache
local weaponTemplates: { [string]: WeaponTemplate } = {}

export type WeaponTemplate = {
	Id: string,
	Name: string,
	Class: string,
	Model: string,
	ViewModel: string,
	Icon: string,
	Stats: WeaponStats,
	Attachments: { [string]: { string } },
	DefaultAttachments: { [string]: string }?,
	Animations: { [string]: string },
	Sounds: { [string]: string },
	Rarity: string,
	Price: { Cash: number, Credits: number },
}

export type WeaponStats = {
	Damage: number,
	FireRate: number,
	MuzzleVelocity: number,
	Range: number,
	RecoilPattern: { [number]: Vector2 },
	RecoilRecovery: number,
	Spread: number,
	SpreadADS: number,
	SpreadMove: number,
	SpreadJump: number,
	ReloadTime: number,
	TacticalReloadTime: number,
	MagSize: number,
	AmmoType: string,
	Weight: number,
	AdsTime: number,
	Sway: number,
	Penetration: number,
	BulletDrop: number,
}

-- Initialize weapon templates from definitions
local function LoadWeaponTemplates()
	-- In production, load from ItemDefinitions module
	-- For now, define basic templates
	weaponTemplates["AK74"] = {
		Id = "AK74",
		Name = "AK-74",
		Class = "AR",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = Constants.BASE_DAMAGE.AR,
			FireRate = 600,
			MuzzleVelocity = 900,
			Range = 400,
			RecoilPattern = {
				[1] = Vector2.new(0.8, 0.1),
				[2] = Vector2.new(1.2, -0.2),
				[3] = Vector2.new(1.5, 0.3),
				[4] = Vector2.new(1.8, -0.1),
				[5] = Vector2.new(2.0, 0.2),
			},
			RecoilRecovery = 8,
			Spread = 2.5,
			SpreadADS = 0.8,
			SpreadMove = 4.0,
			SpreadJump = 8.0,
			ReloadTime = 2.8,
			TacticalReloadTime = 2.2,
			MagSize = 30,
			AmmoType = "5.45x39",
			Weight = 3.5,
			AdsTime = 0.25,
			Sway = 1.2,
			Penetration = 12,
			BulletDrop = 1.0,
		},
		Attachments = {
			Optic = { "RedDot", "Holographic", "Scope2x", "Scope4x", "Scope6x" },
			Muzzle = { "Compensator", "Suppressor", "FlashHider" },
			Barrel = { "Lightweight", "Heavy", "Long" },
			Underbarrel = { "VerticalGrip", "AngledGrip", "HalfGrip" },
			Magazine = { "ExtendedMag", "QuickDrawMag" },
			Stock = { "TacticalStock", "FoldingStock" },
		},
		Animations = {},
		Sounds = {},
		Rarity = "Common",
		Price = { Cash = 500, Credits = 0 },
	}
	
	weaponTemplates["M416"] = {
		Id = "M416",
		Name = "M416",
		Class = "AR",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = Constants.BASE_DAMAGE.AR,
			FireRate = 750,
			MuzzleVelocity = 880,
			Range = 380,
			RecoilPattern = {
				[1] = Vector2.new(0.6, 0.05),
				[2] = Vector2.new(1.0, -0.1),
				[3] = Vector2.new(1.3, 0.15),
				[4] = Vector2.new(1.5, -0.05),
				[5] = Vector2.new(1.7, 0.1),
			},
			RecoilRecovery = 10,
			Spread = 2.0,
			SpreadADS = 0.6,
			SpreadMove = 3.5,
			SpreadJump = 7.0,
			ReloadTime = 2.5,
			TacticalReloadTime = 1.9,
			MagSize = 30,
			AmmoType = "5.56x45",
			Weight = 3.2,
			AdsTime = 0.22,
			Sway = 1.0,
			Penetration = 10,
			BulletDrop = 1.0,
		},
		Attachments = {
			Optic = { "RedDot", "Holographic", "Scope2x", "Scope4x", "Scope6x" },
			Muzzle = { "Compensator", "Suppressor", "FlashHider" },
			Barrel = { "Lightweight", "Heavy", "Long" },
			Underbarrel = { "VerticalGrip", "AngledGrip", "HalfGrip" },
			Magazine = { "ExtendedMag", "QuickDrawMag" },
			Stock = { "TacticalStock", "FoldingStock" },
		},
		Animations = {},
		Sounds = {},
		Rarity = "Uncommon",
		Price = { Cash = 800, Credits = 0 },
	}
	
	-- Add more weapons: SR, SMG, SG, Pistol, DMR...
	print("[RaycastWeapon] Loaded", Util.TableLength(weaponTemplates), "weapon templates")
end

LoadWeaponTemplates()

-- Get weapon template
local function GetWeaponTemplate(templateId: string): WeaponTemplate?
	return weaponTemplates[templateId]
end

-- Initialize player weapon state
local function InitializePlayerWeapons(player: Player)
	playerWeapons[player] = {}
	pendingShots[player] = {}
end

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
	playerWeapons[player] = nil
	pendingShots[player] = nil
end)

-- ==================== REMOTE HANDLERS ====================

-- Client requests to fire weapon (with prediction data)
WeaponFire.OnServerEvent:Connect(function(player: Player, payload: {
	weaponId: string,
	origin: Vector3,
	direction: Vector3,
	timestamp: number,
	shotIndex: number,
	seed: number,
})
	if not Util.ValidatePlayer(player) then return end
	if not Util.ValidatePosition(payload.origin, Constants.MAP_RADIUS * 2) then return end
	if not Util.ValidatePosition(payload.direction) then return end
	
	local weaponState = playerWeapons[player] and playerWeapons[player][payload.weaponId]
	if not weaponState or not weaponState.equipped then return end
	
	-- Rate limiting
	local template = GetWeaponTemplate(weaponState.templateId)
	if not template then return end
	
	local minInterval = 60 / template.Stats.FireRate
	if os.clock() - weaponState.lastFireTime < minInterval then return end
	
	-- Ammo check
	if weaponState.currentAmmo <= 0 then
		-- Trigger dry fire sound on client
		WeaponFire:FireClient(player, { dryFire = true, weaponId = payload.weaponId })
		return
	end
	
	-- Server-side validation: check if origin is reasonable (anti-cheat)
	local character = player.Character
	if not Util.ValidateCharacter(character) then return end
	
	local rootPart = character.HumanoidRootPart
	local maxDist = (rootPart.Position - payload.origin).Magnitude
	if maxDist > 5 then -- Allow small prediction offset
		warn("[RaycastWeapon] Shot origin too far from player:", player.Name, maxDist)
		return
	end
	
	-- Consume ammo
	weaponState.currentAmmo -= 1
	weaponState.lastFireTime = os.clock()
	weaponState.shotIndex = payload.shotIndex
	
	-- Store pending shot for hit validation
	local pendingShot: PendingShot = {
		shotId = payload.shotIndex,
		origin = payload.origin,
		direction = payload.direction,
		timestamp = payload.timestamp,
		weaponId = payload.weaponId,
		shotIndex = payload.shotIndex,
		seed = payload.seed,
		processed = false,
	}
	
	table.insert(pendingShots[player], pendingShot)
	
	-- Replicate to other clients (visual effects only)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			WeaponFire:FireClient(other, {
				weaponId = payload.weaponId,
				origin = payload.origin,
				direction = payload.direction,
				shotIndex = payload.shotIndex,
				shooter = player,
			})
		end
	end
end)

-- Client reports hit (server validates)
WeaponHit.OnServerEvent:Connect(function(player: Player, payload: {
	weaponId: string,
	target: Player | BasePart,
	hitPosition: Vector3,
	hitNormal: Vector3,
	hitMaterial: Enum.Material,
	shotIndex: number,
	timestamp: number,
	damage: number,
	isHeadshot: boolean,
	penetrated: boolean,
})
	if not Util.ValidatePlayer(player) then return end
	
	-- Find pending shot
	local shots = pendingShots[player]
	local shotIndex = -1
	for i, shot in ipairs(shots) do
		if shot.shotIndex == payload.shotIndex and shot.weaponId == payload.weaponId then
			shotIndex = i
			break
		end
	end
	
	if shotIndex == -1 then
		warn("[RaycastWeapon] Invalid shot index:", payload.shotIndex, "from", player.Name)
		return
	end
	
	local pendingShot = shots[shotIndex]
	if pendingShot.processed then
		warn("[RaycastWeapon] Shot already processed:", payload.shotIndex)
		table.remove(shots, shotIndex)
		return
	end
	
	pendingShot.processed = true
	table.remove(shots, shotIndex)
	
	-- Validate hit with HitValidation module
	local validation = HitValidation.ValidateHit(player, pendingShot, payload)
	if not validation.valid then
		-- Reject hit - could log for anti-cheat
		warn("[RaycastWeapon] Hit validation failed:", player.Name, validation.reason)
		return
	end
	
	-- Apply damage
	local damageResult = DamageService.ApplyDamage(
		player,
		payload.target,
		validation.damage,
		payload.hitPosition,
		payload.hitNormal,
		payload.isHeadshot,
		payload.weaponId
	)
	
	if damageResult then
		-- Send hit marker to shooter
		HitMarker:FireClient(player, {
			position = payload.hitPosition,
			damage = validation.damage,
			isHeadshot = payload.isHeadshot,
			isKill = damageResult.isKill,
		})
		
		-- Broadcast kill feed if kill
		if damageResult.isKill then
			KillFeed:FireAllClients({
				killer = player.Name,
				victim = payload.target.Name,
				weapon = payload.weaponId,
				isHeadshot = payload.isHeadshot,
				distance = validation.distance,
			})
		end
	end
end)

-- Reload handling
WeaponReload.OnServerEvent:Connect(function(player: Player, payload: { weaponId: string, isTactical: boolean })
	if not Util.ValidatePlayer(player) then return end
	
	local weaponState = playerWeapons[player] and playerWeapons[player][payload.weaponId]
	if not weaponState or weaponState.isReloading then return end
	
	local template = GetWeaponTemplate(weaponState.templateId)
	if not template then return end
	
	local neededAmmo = template.Stats.MagSize - weaponState.currentAmmo
	if neededAmmo <= 0 or weaponState.reserveAmmo <= 0 then return end
	
	weaponState.isReloading = true
	weaponState.reloadStartTime = os.clock()
	
	local reloadTime = payload.isTactical and template.Stats.TacticalReloadTime or template.Stats.ReloadTime
	
	-- Simulate reload completion
	task.delay(reloadTime, function()
		if not playerWeapons[player] or not playerWeapons[player][payload.weaponId] then return end
		local ws = playerWeapons[player][payload.weaponId]
		if ws.reloadStartTime ~= weaponState.reloadStartTime then return end -- Cancelled
		
		local toLoad = math.min(neededAmmo, ws.reserveAmmo)
		ws.currentAmmo += toLoad
		ws.reserveAmmo -= toLoad
		ws.isReloading = false
		
		WeaponReload:FireClient(player, { weaponId = payload.weaponId, currentAmmo = ws.currentAmmo, reserveAmmo = ws.reserveAmmo })
	end)
end)

-- Weapon switch
WeaponSwitch.OnServerEvent:Connect(function(player: Player, payload: { weaponId: string, fromId: string? })
	if not Util.ValidatePlayer(player) then return end
	
	-- Unequip current
	if payload.fromId and playerWeapons[player] and playerWeapons[player][payload.fromId] then
		playerWeapons[player][payload.fromId].equipped = false
	end
	
	-- Equip new
	if playerWeapons[player] and playerWeapons[player][payload.weaponId] then
		playerWeapons[player][payload.weaponId].equipped = true
		WeaponSwitch:FireClient(player, { weaponId = payload.weaponId, success = true })
	end
end)

-- ADS state
WeaponAds.OnServerEvent:Connect(function(player: Player, payload: { weaponId: string, isAds: boolean })
	if not Util.ValidatePlayer(player) then return end
	if playerWeapons[player] and playerWeapons[player][payload.weaponId] then
		playerWeapons[player][payload.weaponId].isAds = payload.isAds
	end
end)

-- ==================== PUBLIC API ====================

local RaycastWeapon = {}

function RaycastWeapon.GiveWeapon(player: Player, templateId: string, attachments: { [string]: string }?): boolean
	if not Util.ValidatePlayer(player) then return false end
	
	local template = GetWeaponTemplate(templateId)
	if not template then return false end
	
	if not playerWeapons[player] then InitializePlayerWeapons(player) end
	
	local weaponId = templateId .. "_" .. Util.GenerateShortUID(6)
	
	playerWeapons[player][weaponId] = {
		templateId = templateId,
		currentAmmo = template.Stats.MagSize,
		reserveAmmo = template.Stats.MagSize * 3,
		isReloading = false,
		reloadStartTime = 0,
		lastFireTime = 0,
		shotIndex = 0,
		spreadPattern = Ballistics.GenerateSpreadPattern(
			Util.GenerateUID():sub(1, 8),
			100,
			template.Stats.Spread,
			0.1
		),
		isAds = false,
		equipped = false,
	}
	
	return true
end

function RaycastWeapon.GetWeaponState(player: Player, weaponId: string): WeaponState?
	return playerWeapons[player] and playerWeapons[player][weaponId]
end

function RaycastWeapon.GetEquippedWeapon(player: Player): (string, WeaponState)?
	if not playerWeapons[player] then return nil end
	for id, state in pairs(playerWeapons[player]) do
		if state.equipped then return id, state end
	end
	return nil
end

function RaycastWeapon.SetAmmo(player: Player, weaponId: string, current: number, reserve: number)
	if playerWeapons[player] and playerWeapons[player][weaponId] then
		playerWeapons[player][weaponId].currentAmmo = current
		playerWeapons[player][weaponId].reserveAmmo = reserve
	end
end

function RaycastWeapon.RemoveWeapon(player: Player, weaponId: string)
	if playerWeapons[player] then
		playerWeapons[player][weaponId] = nil
	end
end

function RaycastWeapon.GetAllWeapons(player: Player): { [string]: WeaponState }?
	return playerWeapons[player]
end

return RaycastWeapon