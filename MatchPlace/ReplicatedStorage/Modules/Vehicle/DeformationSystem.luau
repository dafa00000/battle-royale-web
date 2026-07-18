--[[
	DeformationSystem - Vehicle mesh deformation on impact, damage based on speed, repair over time or with kit
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local DeformationSystem = {}

export type DeformationData = {
	part: BasePart,
	originalCFrame: CFrame,
	originalSize: Vector3,
	deformation: Vector3,
	deformationTarget: Vector3,
	damage: number,
	lastImpactTime: number,
}

export type VehicleDeformState = {
	vehicle: Model,
	parts: { [BasePart]: DeformationData },
	totalDamage: number,
	maxDamage: number,
	isRepairing: boolean,
	repairStartTime: number,
	repairRate: number,
}

-- Configuration
local CONFIG = {
	maxDeformation = 0.4, -- Max studs to deform
	damageToDeformRatio = 0.01, -- Damage per deformation unit
	repairRate = 5, -- Damage repaired per second
	repairDelay = 5, -- Seconds after damage before repair starts
	deformationRecovery = 0.5, -- Deformation recovery per second (when repairing)
	impactThreshold = 10, -- Minimum speed for damage
}

-- Active vehicle states
local vehicleStates: { [string]: VehicleDeformState } = {}

function DeformationSystem.RegisterVehicle(vehicle: Model, maxDamage: number?)
	local state: VehicleDeformState = {
		vehicle = vehicle,
		parts = {},
		totalDamage = 0,
		maxDamage = maxDamage or Constants.VEHICLE_HEALTH.UAZ or 1000,
		isRepairing = false,
		repairStartTime = 0,
		repairRate = CONFIG.repairRate,
	}

	-- Find deformable parts (body panels)
	for _, part in ipairs(vehicle:GetDescendants()) do
		if part:IsA("BasePart") and part.Name:find("Body") or part.Name:find("Panel") or part.Name:find("Door") or part.Name:find("Hood") or part.Name:find("Trunk") then
			state.parts[part] = {
				part = part,
				originalCFrame = part.CFrame,
				originalSize = part.Size,
				deformation = Vector3.zero,
				deformationTarget = Vector3.zero,
				damage = 0,
				lastImpactTime = 0,
			}
		end
	end

	vehicleStates[vehicle.Name] = state

	-- Connect impact detection
	DeformationSystem.SetupImpactDetection(vehicle)

	return state
end

function DeformationSystem.SetupImpactDetection(vehicle: Model)
	local chassis = vehicle:FindFirstChild("Chassis") or vehicle.PrimaryPart
	if not chassis then return end

	chassis.Touched:Connect(function(hit)
		local state = vehicleStates[vehicle.Name]
		if not state then return end

		-- Check if hit by world object (not another vehicle part)
		if hit:IsDescendantOf(vehicle) then return end
		if not hit.CanCollide then return end

		-- Calculate impact speed
		local velocity = chassis.AssemblyLinearVelocity
		local speed = velocity.Magnitude

		if speed < CONFIG.impactThreshold then return end

		-- Calculate impact point and normal
		local impactPoint = chassis.Position
		local impactNormal = -velocity.Unit

		-- Apply damage based on speed
		local damage = speed * 0.5
		DeformationSystem.ApplyImpact(vehicle.Name, impactPoint, impactNormal, damage)
	end)
end

function DeformationSystem.ApplyImpact(vehicleName: string, hitPosition: Vector3, hitNormal: Vector3, damage: number)
	local state = vehicleStates[vehicleName]
	if not state then return end

	state.totalDamage = math.min(state.totalDamage + damage, state.maxDamage)
	state.isRepairing = false

	-- Find closest deformable part
	local closestPart: BasePart?
	local closestDist = math.huge

	for part, data in pairs(state.parts) do
		local dist = (part.Position - hitPosition).Magnitude
		if dist < closestDist then
			closestDist = dist
			closestPart = part
		end
	end

	if not closestPart then return end

	local data = state.parts[closestPart]
	if not data then return end

	-- Calculate deformation based on damage
	local deformAmount = math.min(damage * CONFIG.damageToDeformRatio, CONFIG.maxDeformation)
	local deformDir = hitNormal * deformAmount

	data.deformationTarget = data.deformationTarget + deformDir
	data.damage += damage
	data.lastImpactTime = os.clock()

	-- Clamp deformation
	data.deformationTarget = Vector3.new(
		math.clamp(data.deformationTarget.X, -CONFIG.maxDeformation, CONFIG.maxDeformation),
		math.clamp(data.deformationTarget.Y, -CONFIG.maxDeformation, CONFIG.maxDeformation),
		math.clamp(data.deformationTarget.Z, -CONFIG.maxDeformation, CONFIG.maxDeformation)
	)

	-- Visual effects
	DeformationSystem.SpawnImpactEffects(hitPosition, hitNormal, damage)

	-- Check for destruction
	if state.totalDamage >= state.maxDamage then
		DeformationSystem.OnVehicleDestroyed(vehicleName)
	end
end

function DeformationSystem.SpawnImpactEffects(position: Vector3, normal: Vector3, damage: number)
	-- Create spark particles
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 200, 50))
	particles.Size = NumberSequence.new(0.2)
	particles.Lifetime = NumberRange.new(0.1, 0.3)
	particles.Rate = 0
	particles.Speed = NumberRange.new(5, 15)
	particles.SpreadAngle = Vector2.new(30, 30)
	particles.Parent = attachment

	-- Emit burst
	particles:Emit(math.floor(damage * 0.5))

	-- Cleanup
	task.delay(2, function()
		attachment:Destroy()
	end)

	-- Sound effect (placeholder)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://0" -- Metal impact
	sound.Volume = math.clamp(damage * 0.02, 0.1, 1)
	sound.RollOffMaxDistance = 50
	sound.Parent = attachment
	sound:Play()
end

function DeformationSystem.Update(deltaTime: number)
	for vehicleName, state in pairs(vehicleStates) do
		if not state.vehicle or not state.vehicle.Parent then
			vehicleStates[vehicleName] = nil
			continue
		end

		-- Check for repair
		if not state.isRepairing and state.totalDamage > 0 then
			local timeSinceDamage = os.clock() - DeformationSystem.GetLastDamageTime(state)
			if timeSinceDamage > CONFIG.repairDelay then
				state.isRepairing = true
				state.repairStartTime = os.clock()
			end
		end

		-- Apply repair
		if state.isRepairing and state.totalDamage > 0 then
			local repairAmount = state.repairRate * deltaTime
			state.totalDamage = math.max(0, state.totalDamage - repairAmount)

			-- Recover deformation
			for part, data in pairs(state.parts) do
				if data.damage > 0 then
					data.damage = math.max(0, data.damage - repairAmount * 0.5)
					local recovery = CONFIG.deformationRecovery * deltaTime
					data.deformationTarget = data.deformationTarget:Lerp(Vector3.zero, recovery)
				end
			end

			if state.totalDamage <= 0 then
				state.isRepairing = false
			end
		end

		-- Smooth deformation interpolation
		for part, data in pairs(state.parts) do
			if data.deformation ~= data.deformationTarget then
				data.deformation = data.deformation:Lerp(data.deformationTarget, deltaTime * 10)

				-- Apply deformation to part
				if part and part.Parent then
					local offset = data.deformation
					part.CFrame = data.originalCFrame * CFrame.new(offset)

					-- Scale deformation for mesh parts
					if part:IsA("MeshPart") then
						local scale = Vector3.new(
							1 - math.abs(offset.X) * 0.2,
							1 - math.abs(offset.Y) * 0.2,
							1 - math.abs(offset.Z) * 0.2
						)
						part.Size = data.originalSize * scale
					end
				end
			end
		end
	end
end

function DeformationSystem.GetLastDamageTime(state: VehicleDeformState): number
	local latest = 0
	for _, data in pairs(state.parts) do
		latest = math.max(latest, data.lastImpactTime)
	end
	return latest
end

function DeformationSystem.RepairWithKit(vehicleName: string, repairAmount: number): boolean
	local state = vehicleStates[vehicleName]
	if not state then return false end

	state.totalDamage = math.max(0, state.totalDamage - repairAmount)

	-- Recover deformation proportionally
	local repairRatio = repairAmount / state.maxDamage
	for part, data in pairs(state.parts) do
		data.damage = math.max(0, data.damage - repairAmount * 0.5)
		data.deformationTarget = data.deformationTarget:Lerp(Vector3.zero, repairRatio)
	end

	return true
end

function DeformationSystem.GetDamage(vehicleName: string): number
	local state = vehicleStates[vehicleName]
	return state and state.totalDamage or 0
end

function DeformationSystem.GetDamagePercent(vehicleName: string): number
	local state = vehicleStates[vehicleName]
	if not state or state.maxDamage <= 0 then return 0 end
	return state.totalDamage / state.maxDamage
end

function DeformationSystem.IsRepairing(vehicleName: string): boolean
	local state = vehicleStates[vehicleName]
	return state and state.isRepairing or false
end

function DeformationSystem.OnVehicleDestroyed(vehicleName: string)
	local state = vehicleStates[vehicleName]
	if not state then return end

	-- Explosion effects
	local chassis = state.vehicle:FindFirstChild("Chassis") or state.vehicle.PrimaryPart
	if chassis then
		local explosion = Instance.new("Explosion")
		explosion.Position = chassis.Position
		explosion.BlastRadius = 15
		explosion.BlastPressure = 500000
		explosion.Parent = Workspace
	end

	-- Remove state
	vehicleStates[vehicleName] = nil
end

function DeformationSystem.UnregisterVehicle(vehicleName: string)
	vehicleStates[vehicleName] = nil
end

function DeformationSystem.Cleanup()
	vehicleStates = {}
end

-- Start update loop
RunService.Heartbeat:Connect(DeformationSystem.Update)

return DeformationSystem
