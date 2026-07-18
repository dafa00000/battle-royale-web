--[[
	DamageService - Centralized damage calculation and application
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local DamageService = {}

export type DamageResult = {
	damageDealt: number,
	actualDamage: number,
	isKill: boolean,
	newHealth: number,
	hitPart: string,
}

export type DamageContext = {
	attacker: Player,
	victim: Player | Model,
	weaponId: string,
	damage: number,
	hitPosition: Vector3,
	hitNormal: Vector3,
	isHeadshot: boolean,
	distance: number,
	penetrated: boolean,
}

-- Hitbox multipliers
local HITBOX_MULTIPLIERS = {
	Head = Constants.HEADSHOT_MULTIPLIER,
	UpperTorso = 1.0,
	LowerTorso = 1.0,
	LeftUpperArm = Constants.LIMB_MULTIPLIER,
	LeftLowerArm = Constants.LIMB_MULTIPLIER,
	LeftHand = Constants.LIMB_MULTIPLIER * 0.8,
	RightUpperArm = Constants.LIMB_MULTIPLIER,
	RightLowerArm = Constants.LIMB_MULTIPLIER,
	RightHand = Constants.LIMB_MULTIPLIER * 0.8,
	LeftUpperLeg = Constants.LIMB_MULTIPLIER,
	LeftLowerLeg = Constants.LIMB_MULTIPLIER * 0.9,
	LeftFoot = Constants.LIMB_MULTIPLIER * 0.7,
	RightUpperLeg = Constants.LIMB_MULTIPLIER,
	RightLowerLeg = Constants.LIMB_MULTIPLIER * 0.9,
	RightFoot = Constants.LIMB_MULTIPLIER * 0.7,
}

-- Armor damage reduction
local ARMOR_PROTECTION = {
	Level1 = 0.3,  -- 30% damage reduction
	Level2 = 0.4,  -- 40%
	Level3 = 0.5,  -- 50%
}

local ARMOR_DURABILITY_LOSS = {
	Level1 = 8,
	Level2 = 6,
	Level3 = 4,
}

function DamageService.CalculateDamage(context: DamageContext): number
	local baseDamage = context.damage
	
	-- Distance falloff
	local effectiveRange = Constants.BASE_DAMAGE[context.weaponId] and 300 or 400
	if context.distance > effectiveRange then
		local falloff = math.min((context.distance - effectiveRange) / 200, 1)
		baseDamage = baseDamage * (1 - falloff * 0.5)
	end
	
	-- Penetration penalty
	if context.penetrated then
		baseDamage = baseDamage * 0.7
	end
	
	return math.max(1, math.floor(baseDamage))
end

function DamageService.GetHitboxMultiplier(hitPartName: string): number
	return HITBOX_MULTIPLIERS[hitPartName] or 1.0
end

function DamageService.ApplyDamage(context: DamageContext): DamageResult?
	-- Validate victim
	local victim = context.victim
	local victimPlayer = victim
	if victim:IsA("Model") then
		victimPlayer = Players:GetPlayerFromCharacter(victim)
	end
	
	if not victimPlayer then
		-- NPC or environmental damage
		return DamageService.ApplyDamageToModel(victim, context.damage, context.hitPosition, context.hitNormal)
	end
	
	-- Can't damage self
	if victimPlayer == context.attacker then return nil end
	
	-- Check team (no friendly fire in squads)
	if context.attacker.Team and victimPlayer.Team and context.attacker.Team == victimPlayer.Team then
		return nil
	end
	
	-- Get humanoid
	local humanoid = victim:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	
	-- Get hit part for multiplier
	local hitPartName = context.hitPartName or "UpperTorso"
	local multiplier = DamageService.GetHitboxMultiplier(hitPartName)
	
	-- Calculate final damage
	local calculatedDamage = DamageService.CalculateDamage(context)
	local finalDamage = calculatedDamage * multiplier
	
	-- Armor mitigation
	local armorData = DamageService.GetArmorData(victimPlayer)
	if armorData and armorData.durability > 0 then
		local reduction = ARMOR_PROTECTION[armorData.level] or 0
		local damageToArmor = finalDamage * reduction
		local damageToHealth = finalDamage - damageToArmor
		
		-- Apply armor durability loss
		DamageService.DamageArmor(victimPlayer, damageToArmor * ARMOR_DURABILITY_LOSS[armorData.level] / 100)
		finalDamage = damageToHealth
	end
	
	-- Apply to humanoid
	local oldHealth = humanoid.Health
	humanoid:TakeDamage(finalDamage)
	local newHealth = humanoid.Health
	
	local result: DamageResult = {
		damageDealt = finalDamage,
		actualDamage = math.min(finalDamage, oldHealth),
		isKill = newHealth <= 0,
		newHealth = newHealth,
		hitPart = hitPartName,
	}
	
	-- Handle kill
	if result.isKill then
		DamageService.HandleKill(context.attacker, victimPlayer, context.weaponId, context.isHeadshot, context.distance)
	end
	
	-- Fire hit event for stats tracking
	ReplicatedStorage.Remotes.MatchRemotes.DamageDealt:FireClient(context.attacker, {
		victim = victimPlayer.Name,
		damage = result.actualDamage,
		isKill = result.isKill,
		isHeadshot = context.isHeadshot,
		distance = context.distance,
		weapon = context.weaponId,
	})
	
	return result
end

function DamageService.ApplyDamageToModel(model: Model, damage: number, hitPos: Vector3, hitNormal: Vector3): DamageResult?
	local humanoid = model:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	
	local oldHealth = humanoid.Health
	humanoid:TakeDamage(damage)
	
	return {
		damageDealt = damage,
		actualDamage = math.min(damage, oldHealth),
		isKill = humanoid.Health <= 0,
		newHealth = humanoid.Health,
		hitPart = "Body",
	}
end

function DamageService.GetArmorData(player: Player): { level: string, durability: number }?
	-- Get from player's profile/inventory
	-- This would integrate with DataManager
	return nil -- Placeholder
end

function DamageService.DamageArmor(player: Player, amount: number)
	-- Reduce armor durability
	-- If durability reaches 0, break armor
end

function DamageService.HandleKill(killer: Player, victim: Player, weaponId: string, isHeadshot: boolean, distance: number)
	-- Award stats
	local killerProfile = DataManager.GetProfile(killer)
	local victimProfile = DataManager.GetProfile(victim)
	
	if killerProfile then
		killerProfile.Data.Stats.Kills += 1
		if isHeadshot then killerProfile.Data.Stats.Headshots += 1 end
		if distance > killerProfile.Data.Stats.LongestShot then
			killerProfile.Data.Stats.LongestShot = distance
		end
		-- Award cash
		killerProfile.Data.Currency.Cash += Constants.KILL_REWARD_CASH
	end
	
	if victimProfile then
		victimProfile.Data.Stats.Deaths += 1
	end
	
	-- Trigger kill effects
	ReplicatedStorage.Remotes.MatchRemotes.KillConfirmed:FireClient(killer, {
		victim = victim.Name,
		weapon = weaponId,
		isHeadshot = isHeadshot,
		distance = distance,
	})
end

function DamageService.ApplyFallDamage(player: Player, fallHeight: number): number
	if fallHeight < 10 then return 0 end
	
	-- Exponential fall damage
	local damage = math.floor((fallHeight - 10) ^ 1.3)
	damage = math.min(damage, 100) -- Cap at 100
	
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid:TakeDamage(damage)
		end
	end
	
	return damage
end

function DamageService.ApplyZoneDamage(player: Player, damage: number, zonePhase: number)
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	
	humanoid:TakeDamage(damage)
	
	-- Client effects handled via ZoneRemotes.GasEffect
end

function DamageService.ApplyExplosionDamage(
	attacker: Player?,
	center: Vector3,
	radius: number,
	baseDamage: number,
	falloff: number,
	ignoreList: { Instance }?
): { [Player]: number }
	local results = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList or {}
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player == attacker then continue end
		local character = player.Character
		if not character then continue end
		
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then continue end
		
		local distance = (root.Position - center).Magnitude
		if distance > radius then continue end
		
		-- Check line of sight
		local rayResult = Workspace:Raycast(center, (root.Position - center).Unit * distance, params)
		if rayResult and rayResult.Instance:IsDescendantOf(character) then
			-- Direct hit
			local damage = baseDamage * (1 - (distance / radius) * falloff)
			damage = math.max(1, math.floor(damage))
			
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid:TakeDamage(damage)
				results[player] = damage
			end
		end
	end
	
	return results
end

function DamageService.ApplyFireDamage(player: Player, dps: number, duration: number)
	-- Damage over time
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	local startTime = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if os.clock() - startTime >= duration then
			connection:Disconnect()
			return
		end
		
		if not humanoid.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			return
		end
		
		humanoid:TakeDamage(dps * RunService.Heartbeat:Wait())
	end)
end

return DamageService