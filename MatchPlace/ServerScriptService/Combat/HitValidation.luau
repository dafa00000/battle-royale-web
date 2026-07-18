--[[
	HitValidation (Server) - Server-authoritative hit validation
	Uses shared HitValidation module for validation logic, applies damage
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local DamageService = require(script.Parent.DamageService)
local HitValidationShared = require(ReplicatedStorage.Modules.WeaponSystem.HitValidation)

local ServerHitValidation = {}

-- ==================== REMOTE HANDLERS ====================

local MatchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes")
local WeaponHit = MatchRemotes.WeaponHit

WeaponHit.OnServerEvent:Connect(function(player, payload)
	if not Util.ValidatePlayer(player) then return end
	if not Util.ValidateCharacter(player.Character) then return end
	
	-- Validate payload structure
	if not payload or not payload.WeaponId or not payload.Target then
		warn("[ServerHitValidation] Invalid payload from", player.Name)
		return
	end
	
	-- Run server-side validation
	local validationResult = HitValidationShared.ValidateHit(player, payload)
	
	if not validationResult.Valid then
		-- Log potential cheat
		warn(string.format("[ServerHitValidation] Invalid hit from %s: %s", player.Name, validationResult.Reason))
		
		-- Could track violations for anti-cheat
		-- AntiCheat.TrackViolation(player, validationResult.Reason)
		return
	end
	
	-- Valid hit - apply damage
	local target = payload.Target
	local isHeadshot = validationResult.IsHeadshot
	local damage = validationResult.ValidatedDamage
	local hitPosition = validationResult.HitPosition
	local hitNormal = validationResult.HitNormal
	
	-- Apply damage through DamageService
	DamageService.ApplyDamage(target, damage, {
		Attacker = player,
		WeaponId = payload.WeaponId,
		IsHeadshot = isHeadshot,
		HitPosition = hitPosition,
		HitNormal = hitNormal,
		Penetrated = validationResult.Penetrated,
	})
	
	-- Replicate hit effects to other clients (not shooter)
	WeaponHit:FireAllClients({
		WeaponId = payload.WeaponId,
		Target = target,
		HitPosition = hitPosition,
		HitNormal = hitNormal,
		Damage = damage,
		IsHeadshot = isHeadshot,
		Penetrated = validationResult.Penetrated,
		Shooter = player,
	})
end)

-- ==================== PROJECTILE HIT VALIDATION ====================

local ThrowProjectile = MatchRemotes.ThrowProjectile

ThrowProjectile.OnServerEvent:Connect(function(player, payload)
	if not Util.ValidatePlayer(player) then return end
	
	-- Validate projectile throw (origin, direction, velocity)
	-- Delegate to ProjectileService for physics
	local ProjectileService = require(script.Parent.Parent.ProjectileService)
	ProjectileService.CreateProjectile(player, payload)
end)

print("[ServerHitValidation] Initialized")
return ServerHitValidation