--[[
	HitValidation - Server-side hit validation for anti-cheat
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local Ballistics = require(script.Parent.Ballistics)

local HitValidation = {}

export type ValidationResult = {
	valid: boolean,
	reason: string?,
	damage: number,
	distance: number,
	hitPart: string?,
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

export type HitPayload = {
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
}

-- Validation thresholds
local MAX_POSITION_DEVIATION = 3 -- studs
local MAX_TIME_DEVIATION = 0.5 -- seconds
local MAX_DAMAGE_DEVIATION = 1.5 -- multiplier

function HitValidation.ValidateHit(
	attacker: Player,
	pendingShot: PendingShot,
	payload: HitPayload
): ValidationResult
	
	-- 1. Basic validation
	if not Util.ValidatePlayer(attacker) then
		return { valid = false, reason = "Invalid attacker" }
	end
	
	local character = attacker.Character
	if not Util.ValidateCharacter(character) then
		return { valid = false, reason = "Invalid character" }
	end
	
	-- 2. Time validation (prevent shot manipulation)
	local serverTime = os.clock()
	local clientTime = payload.timestamp
	if math.abs(serverTime - clientTime) > MAX_TIME_DEVIATION then
		return { valid = false, reason = "Time deviation exceeded" }
	end
	
	-- 3. Position validation (origin check)
	local rootPart = character.HumanoidRootPart
	local originDeviation = (rootPart.Position - pendingShot.origin).Magnitude
	if originDeviation > MAX_POSITION_DEVIATION then
		return { valid = false, reason = "Origin position deviation" }
	end
	
	-- 4. Direction validation
	local shotDirection = pendingShot.direction.Unit
	local payloadDirection = (payload.hitPosition - pendingShot.origin).Unit
	local angleDiff = math.deg(math.acos(math.clamp(shotDirection:Dot(payloadDirection), -1, 1)))
	if angleDiff > 15 then -- Allow 15 degree tolerance for prediction
		return { valid = false, reason = "Direction deviation" }
	end
	
	-- 5. Distance validation
	local distance = (payload.hitPosition - pendingShot.origin).Magnitude
	local template = HitValidation.GetWeaponTemplate(payload.weaponId)
	if template and distance > template.Stats.Range * 1.2 then
		return { valid = false, reason = "Distance exceeds weapon range" }
	end
	
	-- 6. Line of sight validation (server authoritative raycast)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true
	
	local serverResult = Workspace:Raycast(pendingShot.origin, shotDirection * distance, raycastParams)
	
	if serverResult then
		-- Check if hit position matches
		local hitDeviation = (serverResult.Position - payload.hitPosition).Magnitude
		if hitDeviation > MAX_POSITION_DEVIATION * 2 then
			return { valid = false, reason = "Hit position mismatch" }
		end
		
		-- Verify target
		local target = payload.target
		if target:IsA("Player") then
			local targetChar = target.Character
			if not targetChar or not serverResult.Instance:IsDescendantOf(targetChar) then
				return { valid = false, reason = "Target mismatch" }
			end
		elseif target:IsA("BasePart") then
			if serverResult.Instance ~= target and not target:IsAncestorOf(serverResult.Instance) then
				return { valid = false, reason = "Target part mismatch" }
			end
		end
	else
		-- No server hit but client claims hit - possible desync or cheat
		if distance < 50 then -- Close range, should hit
			return { valid = false, reason = "Server raycast missed" }
		end
	end
	
	-- 7. Damage validation
	local expectedDamage = HitValidation.CalculateExpectedDamage(payload.weaponId, distance, payload.isHeadshot, payload.penetrated)
	local damageRatio = payload.damage / expectedDamage
	if damageRatio > MAX_DAMAGE_DEVIATION or damageRatio < 0.5 then
		return { valid = false, reason = "Damage deviation", damage = expectedDamage }
	end
	
	-- 8. Fire rate validation (handled in RaycastWeapon but double-check)
	-- 9. Ammo validation (handled in RaycastWeapon)
	
	-- Determine hit part name
	local hitPartName = "UpperTorso"
	if serverResult and serverResult.Instance:IsA("BasePart") then
		hitPartName = serverResult.Instance.Name
	end
	
	return {
		valid = true,
		damage = expectedDamage,
		distance = distance,
		hitPart = hitPartName,
	}
end

function HitValidation.CalculateExpectedDamage(
	weaponId: string,
	distance: number,
	isHeadshot: boolean,
	penetrated: boolean
): number
	local template = HitValidation.GetWeaponTemplate(weaponId)
	if not template then return Constants.BASE_DAMAGE.AR end
	
	local baseDamage = template.Stats.Damage
	
	-- Distance falloff
	local falloffStart = template.Stats.Range * 0.5
	if distance > falloffStart then
		local t = math.min((distance - falloffStart) / (template.Stats.Range - falloffStart), 1)
		baseDamage = baseDamage * (1 - t * 0.5)
	end
	
	-- Headshot multiplier
	if isHeadshot then
		baseDamage = baseDamage * Constants.HEADSHOT_MULTIPLIER
	end
	
	-- Penetration penalty
	if penetrated then
		baseDamage = baseDamage * 0.7
	end
	
	return math.max(1, math.floor(baseDamage))
end

function HitValidation.GetWeaponTemplate(weaponId: string): { Stats: any }?
	-- Extract base template ID from weapon instance ID
	local baseId = weaponId:match("^([^_]+)")
	if baseId then
		-- Would load from shared definitions
		return {
			Stats = {
				Damage = Constants.BASE_DAMAGE[baseId] or Constants.BASE_DAMAGE.AR,
				Range = 400,
			}
		}
	end
	return nil
end

-- Advanced: Replay validation for suspicious players
local shotHistory: { [Player]: { PendingShot } } = {}

function HitValidation.RecordShot(player: Player, shot: PendingShot)
	if not shotHistory[player] then shotHistory[player] = {} end
	table.insert(shotHistory[player], shot)
	
	-- Keep last 100 shots
	if #shotHistory[player] > 100 then
		table.remove(shotHistory[player], 1)
	end
end

function HitValidation.AnalyzePattern(player: Player): { suspicious: boolean, reasons: { string } }
	local history = shotHistory[player]
	if not history or #history < 10 then
		return { suspicious = false, reasons = {} }
	end
	
	local reasons = {}
	
	-- Check for impossible fire rates
	local lastTime = 0
	local rapidFireCount = 0
	for _, shot in ipairs(history) do
		if shot.timestamp - lastTime < 0.05 then -- < 50ms between shots
			rapidFireCount += 1
		end
		lastTime = shot.timestamp
	end
	
	if rapidFireCount > 5 then
		table.insert(reasons, "Impossible fire rate detected")
	end
	
	-- Check for perfect accuracy (aimbot indicator)
	local hitCount = 0
	local totalShots = #history
	for _, shot in ipairs(history) do
		if shot.processed then hitCount += 1 end
	end
	
	if totalShots > 20 and hitCount / totalShots > 0.95 then
		table.insert(reasons, "Suspicious accuracy")
	end
	
	-- Check for snapping (instant direction changes)
	for i = 2, #history do
		local prev = history[i-1].direction.Unit
		local curr = history[i].direction.Unit
		local angle = math.deg(math.acos(math.clamp(prev:Dot(curr), -1, 1)))
		if angle > 90 and (history[i].timestamp - history[i-1].timestamp) < 0.1 then
			table.insert(reasons, "Instant direction change (snapping)")
			break
		end
	end
	
	return {
		suspicious = #reasons > 0,
		reasons = reasons,
	}
end

function HitValidation.FlagPlayer(player: Player, reason: string)
	-- Log to DataStore for review
	warn("[HitValidation] Player flagged:", player.Name, "-", reason)
	
	-- Could trigger: kick, ban, shadowban, or log for manual review
	-- For now, just log
end

return HitValidation