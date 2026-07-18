--[[
	Ballistics Module - Realistic bullet physics with drop, penetration, and travel time
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage").Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local Ballistics = {}

-- Ballistics configuration
local GRAVITY = Workspace.Gravity * Constants.BULLET_DROP -- ~9.81 * 0.05
local MAX_SIMULATION_TIME = 5 -- seconds
local SIMULATION_STEP = 1/60 -- 60 Hz simulation
local PENETRATION_MATERIALS = {
	[Enum.Material.Wood] = 1.0,
	[Enum.Material.Plastic] = 0.8,
	[Enum.Material.Glass] = 0.5,
	[Enum.Material.Concrete] = 0.1,
	[Enum.Material.Metal] = 0.05,
	[Enum.Material.Brick] = 0.15,
}

export type BallisticsData = {
	origin: Vector3,
	direction: Vector3,
	velocity: number,
	damage: number,
	penetration: number,
	range: number,
	drop: number,
	hitResults: { RaycastResult },
}

export type HitResult = {
	position: Vector3,
	normal: Vector3,
	material: Enum.Material,
	instance: Instance,
	distance: number,
	damage: number,
	isHeadshot: boolean,
	penetrated: boolean,
}

-- Simulate bullet trajectory with gravity and air resistance
function Ballistics.SimulateTrajectory(
	origin: Vector3,
	direction: Vector3,
	muzzleVelocity: number,
	bulletDrop: number,
	maxRange: number,
	penetrationPower: number,
	ignoreList: { Instance }?,
	callback: (HitResult) -> boolean?
): { HitResult }
	
	local results = {}
	local currentPos = origin
	local currentVel = direction.Unit * muzzleVelocity
	local timeAlive = 0
	local totalDistance = 0
	local remainingPenetration = penetrationPower
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = ignoreList or {}
	raycastParams.IgnoreWater = true
	
	while timeAlive < MAX_SIMULATION_TIME and totalDistance < maxRange do
		local dt = SIMULATION_STEP
		timeAlive += dt
		
		-- Apply gravity (bullet drop)
		currentVel += Vector3.new(0, -GRAVITY * bulletDrop, 0) * dt
		
		-- Calculate step
		local stepDistance = currentVel.Magnitude * dt
		local stepDirection = currentVel.Unit
		local nextPos = currentPos + stepDirection * stepDistance
		
		-- Raycast for this step
		raycastParams.FilterDescendantsInstances = ignoreList or {}
		local result = Workspace:Raycast(currentPos, stepDirection * stepDistance, raycastParams)
		
		totalDistance += stepDistance
		
		if result then
			local hitResult: HitResult = {
				position = result.Position,
				normal = result.Normal,
				material = result.Material,
				instance = result.Instance,
				distance = totalDistance,
				damage = 0, -- Calculated by damage system
				isHeadshot = false, -- Determined by damage system
				penetrated = false,
			}
			
			table.insert(results, hitResult)
			
			-- Check for penetration
			local materialPenetration = PENETRATION_MATERIALS[result.Material] or 0.1
			local thickness = Ballistics.EstimateThickness(result.Instance, result.Position, -stepDirection)
			local requiredPenetration = thickness * materialPenetration
			
			if remainingPenetration >= requiredPenetration and thickness < Constants.MAX_PENETRATION_DEPTH then
				-- Bullet penetrates
				remainingPenetration -= requiredPenetration
				hitResult.penetrated = true
				
				-- Continue from exit point
				currentPos = result.Position + stepDirection * (thickness + 0.1)
				currentVel *= 0.7 -- Velocity loss on penetration
				
				-- Add penetrated instance to ignore list for next iteration
				if ignoreList then
					table.insert(ignoreList, result.Instance)
				else
					ignoreList = { result.Instance }
				end
				
				-- Callback for penetration hit
				if callback and not callback(hitResult) then
					break
				end
			else
				-- Bullet stops
				if callback then callback(hitResult) end
				break
			end
		else
			-- No hit, continue
			currentPos = nextPos
			
			-- Check if we should continue
			if totalDistance >= maxRange then break end
		end
	end
	
	return results
end

-- Estimate material thickness at hit point
function Ballistics.EstimateThickness(instance: Instance, hitPos: Vector3, direction: Vector3): number
	if not instance:IsA("BasePart") then return 0.5 end
	
	-- Cast from opposite side to measure thickness
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { instance }
	
	-- Start from slightly behind the hit point going opposite direction
	local startPos = hitPos - direction * 10
	local result = Workspace:Raycast(startPos, direction * 20, raycastParams)
	
	if result and result.Instance == instance then
		return (result.Position - hitPos).Magnitude
	end
	
	-- Fallback: estimate from part size
	local size = instance.Size
	local cf = instance.CFrame
	local localHit = cf:PointToObjectSpace(hitPos)
	local localDir = cf:VectorToObjectSpace(direction)
	
	-- Calculate intersection with part bounds
	local tMin, tMax = -math.huge, math.huge
	for i = 1, 3 do
		local d = localDir[i]
		local p = localHit[i]
		local halfSize = size[i] * 0.5
		
		if math.abs(d) < 1e-6 then
			if p < -halfSize or p > halfSize then return 0.5 end
		else
			local t1 = (-halfSize - p) / d
			local t2 = (halfSize - p) / d
			tMin = math.max(tMin, math.min(t1, t2))
			tMax = math.min(tMax, math.max(t1, t2))
		end
	end
	
	if tMax >= tMin and tMax >= 0 then
		return math.max(0, tMax - math.max(0, tMin))
	end
	
	return math.min(size.X, size.Y, size.Z) * 0.5
end

-- Calculate damage falloff over distance
function Ballistics.CalculateDamageFalloff(
	baseDamage: number,
	distance: number,
	effectiveRange: number,
	minDamageMultiplier: number
): number
	local falloffStart = effectiveRange * 0.5
	if distance <= falloffStart then return baseDamage end
	
	if distance >= effectiveRange then
		return baseDamage * minDamageMultiplier
	end
	
	-- Linear falloff
	local t = (distance - falloffStart) / (effectiveRange - falloffStart)
	return baseDamage * (1 - t * (1 - minDamageMultiplier))
end

-- Calculate bullet drop compensation for aiming
function Ballistics.CalculateDropCompensation(
	distance: number,
	muzzleVelocity: number,
	bulletDrop: number
): number
	if distance <= 0 or muzzleVelocity <= 0 then return 0 end
	
	local timeOfFlight = distance / muzzleVelocity
	local drop = 0.5 * GRAVITY * bulletDrop * timeOfFlight ^ 2
	return drop -- in studs
end

-- Calculate lead for moving targets
function Ballistics.CalculateLead(
	targetPos: Vector3,
	targetVel: Vector3,
	origin: Vector3,
	muzzleVelocity: number
): Vector3?
	local toTarget = targetPos - origin
	local distance = toTarget.Magnitude
	
	if distance <= 0 or muzzleVelocity <= 0 then return targetPos end
	
	-- Time of flight approximation (ignoring drop for lead calc)
	local timeOfFlight = distance / muzzleVelocity
	
	-- Predicted position
	local predictedPos = targetPos + targetVel * timeOfFlight
	
	-- Iterate for better accuracy (accounting for changing distance)
	for i = 1, 3 do
		local newDist = (predictedPos - origin).Magnitude
		local newTime = newDist / muzzleVelocity
		predictedPos = targetPos + targetVel * newTime
	end
	
	return predictedPos
end

-- Generate deterministic spread pattern for recoil
function Ballistics.GenerateSpreadPattern(
	seed: number,
	shotCount: number,
	baseSpread: number,
	spreadGrowth: number
): { Vector2 }
	local random = Random.new(seed)
	local pattern = {}
	
	for i = 1, shotCount do
		-- Current spread increases with each shot
		local currentSpread = baseSpread + spreadGrowth * (i - 1)
		
		-- Generate random point in circle (uniform distribution)
		local r = math.sqrt(random:NextNumber()) * currentSpread
		local theta = random:NextNumber() * math.pi * 2
		
		local offset = Vector2.new(
			r * math.cos(theta),
			r * math.sin(theta)
		)
		
		table.insert(pattern, offset)
	end
	
	return pattern
end

-- Client-side prediction: calculate where bullet will hit at given time
function Ballistics.PredictImpactPoint(
	origin: Vector3,
	direction: Vector3,
	muzzleVelocity: number,
	bulletDrop: number,
	time: number
): Vector3
	local horizontalVel = direction * muzzleVelocity
	local verticalVel = 0
	local pos = origin
	
	local steps = math.ceil(time / SIMULATION_STEP)
	local dt = time / steps
	
	for i = 1, steps do
		verticalVel -= GRAVITY * bulletDrop * dt
		pos += horizontalVel * dt + Vector3.new(0, verticalVel * dt, 0)
	end
	
	return pos
end

return Ballistics