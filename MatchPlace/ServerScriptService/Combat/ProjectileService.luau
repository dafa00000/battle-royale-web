--[[
	ProjectileService - Handle ThrowProjectile (frag/smoke/flash/molotov),
	physics trajectory, explosion damage, area effect, broadcast to clients.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local DamageService = require(script.Parent.DamageService)

local MatchRemotes = ReplicatedStorage.Remotes.MatchRemotes

local ProjectileService = {}

export type ProjectileType = "FragGrenade" | "SmokeGrenade" | "Flashbang" | "Molotov" | "StunGrenade"

export type ProjectileData = {
	Id: string,
	Type: ProjectileType,
	Owner: Player,
	StartPosition: Vector3,
	Direction: Vector3,
	Speed: number,
	FuseTime: number,
	Radius: number,
	Damage: number,
	EffectDuration: number,
	SpawnTime: number,
	Model: Part?,
	Active: boolean,
}

export type ExplosionResult = {
	Position: Vector3,
	Radius: number,
	DamagedPlayers: { [Player]: number },
	DamagedVehicles: { [string]: number },
}

-- Projectile configurations
local PROJECTILE_CONFIGS: { [ProjectileType]: { Speed: number, FuseTime: number, Radius: number, Damage: number, EffectDuration: number } } = {
	FragGrenade = {
		Speed = 50,
		FuseTime = 3,
		Radius = 15,
		Damage = 100,
		EffectDuration = 0,
	},
	SmokeGrenade = {
		Speed = 45,
		FuseTime = 2,
		Radius = 20,
		Damage = 0,
		EffectDuration = 15,
	},
	Flashbang = {
		Speed = 50,
		FuseTime = 2,
		Radius = 25,
		Damage = 0,
		EffectDuration = 5,
	},
	Molotov = {
		Speed = 40,
		FuseTime = 0,
		Radius = 12,
		Damage = 10, -- per second
		EffectDuration = 8,
	},
	StunGrenade = {
		Speed = 50,
		FuseTime = 2.5,
		Radius = 20,
		Damage = 0,
		EffectDuration = 4,
	},
}

-- State
local activeProjectiles: { [string]: ProjectileData } = {}
local nextProjectileId = 1

-- ==================== THROWING ====================

function ProjectileService.ThrowProjectile(
	player: Player,
	projectileType: ProjectileType,
	origin: Vector3,
	direction: Vector3,
	throwPower: number?
): ProjectileData?
	-- Validate projectile type
	local config = PROJECTILE_CONFIGS[projectileType]
	if not config then
		warn("[ProjectileService] Invalid projectile type:", projectileType)
		return nil
	end

	-- Validate player
	local character = player.Character
	if not character then return nil end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	-- Validate origin is near player
	if (origin - root.Position).Magnitude > 10 then
		origin = root.Position + Vector3.new(0, 2, 0)
	end

	-- Normalize and validate direction
	direction = direction.Unit
	if direction.Magnitude ~= direction.Magnitude then -- NaN check
		direction = root.CFrame.LookVector
	end

	local projectileId = "Projectile_" .. nextProjectileId
	nextProjectileId += 1

	local speed = config.Speed * (throwPower or 1)

	local projectile: ProjectileData = {
		Id = projectileId,
		Type = projectileType,
		Owner = player,
		StartPosition = origin,
		Direction = direction,
		Speed = speed,
		FuseTime = config.FuseTime,
		Radius = config.Radius,
		Damage = config.Damage,
		EffectDuration = config.EffectDuration,
		SpawnTime = os.clock(),
		Model = nil,
		Active = true,
	}

	activeProjectiles[projectileId] = projectile

	-- Create visual model
	ProjectileService.CreateProjectileModel(projectile)

	-- Start physics simulation
	ProjectileService.SimulateProjectile(projectile)

	-- Broadcast throw
	MatchRemotes.ThrowProjectile:FireAllClients({
		action = "Thrown",
		projectileId = projectileId,
		type = projectileType,
		owner = player.Name,
		ownerUserId = player.UserId,
		origin = origin,
		direction = direction,
		speed = speed,
		fuseTime = config.FuseTime,
	})

	print("[ProjectileService]", player.Name, "threw", projectileType)

	return projectile
end

function ProjectileService.CreateProjectileModel(projectile: ProjectileData)
	local part = Instance.new("Part")
	part.Name = projectile.Id
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Shape = Enum.PartType.Ball
	part.Position = projectile.StartPosition
	part.Anchored = true
	part.CanCollide = false
	part.BrickColor = BrickColor.new("Dark stone grey")
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = Workspace

	-- Add trail
	local trail = Instance.new("Trail")
	trail.Name = "Trail"
	trail.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	trail.Lifetime = 0.5
	trail.Parent = part

	-- Add attachment points for trail
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "Attachment0"
	attachment0.Position = Vector3.new(0, 0.25, 0)
	attachment0.Parent = part

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "Attachment1"
	attachment1.Position = Vector3.new(0, -0.25, 0)
	attachment1.Parent = part

	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1

	projectile.Model = part
end

-- ==================== PHYSICS SIMULATION ====================

function ProjectileService.SimulateProjectile(projectile: ProjectileData)
	local gravity = Vector3.new(0, -Workspace.Gravity, 0)
	local velocity = projectile.Direction * projectile.Speed
	local position = projectile.StartPosition
	local startTime = os.clock()
	local fuseTime = projectile.FuseTime

	-- For molotov, trigger on impact
	if projectile.Type == "Molotov" then
		fuseTime = 60 -- Long fuse, triggers on impact
	end

	local lastPosition = position
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { projectile.Owner.Character, projectile.Model }

	task.spawn(function()
		while projectile.Active do
			local elapsed = os.clock() - startTime
			if elapsed >= fuseTime then
				ProjectileService.DetonateProjectile(projectile, position)
				break
			end

			local dt = 1/60
			velocity = velocity + gravity * dt
			position = position + velocity * dt

			-- Raycast for collision
			local rayDirection = position - lastPosition
			local rayResult = Workspace:Raycast(lastPosition, rayDirection, rayParams)

			if rayResult then
				-- Hit something
				if projectile.Type == "Molotov" then
					ProjectileService.DetonateProjectile(projectile, rayResult.Position)
				else
					-- Bounce
					local normal = rayResult.Normal
					local dot = velocity.Unit:Dot(normal)
					local reflection = velocity.Unit - 2 * dot * normal
					velocity = reflection * velocity.Magnitude * 0.6 -- Energy loss
					position = rayResult.Position + normal * 0.1
				end
			end

			-- Update model
			if projectile.Model then
				projectile.Model.Position = position
			end

			lastPosition = position
			task.wait(dt)
		end
	end)
end

-- ==================== DETONATION ====================

function ProjectileService.DetonateProjectile(projectile: ProjectileData, position: Vector3)
	if not projectile.Active then return end
	projectile.Active = false

	local result: ExplosionResult = {
		Position = position,
		Radius = projectile.Radius,
		DamagedPlayers = {},
		DamagedVehicles = {},
	}

	-- Handle different projectile types
	if projectile.Type == "FragGrenade" then
		result = ProjectileService.ExplodeFrag(projectile, position)
	elseif projectile.Type == "SmokeGrenade" then
		ProjectileService.DeploySmoke(projectile, position)
	elseif projectile.Type == "Flashbang" then
		ProjectileService.DetonateFlashbang(projectile, position)
	elseif projectile.Type == "Molotov" then
		ProjectileService.IgniteMolotov(projectile, position)
	elseif projectile.Type == "StunGrenade" then
		ProjectileService.DetonateStun(projectile, position)
	end

	-- Broadcast explosion
	MatchRemotes.ThrowProjectile:FireAllClients({
		action = "Detonated",
		projectileId = projectile.Id,
		type = projectile.Type,
		position = position,
		radius = projectile.Radius,
		owner = projectile.Owner.Name,
	})

	-- Cleanup model
	if projectile.Model then
		projectile.Model:Destroy()
		projectile.Model = nil
	end

	-- Remove from active
	activeProjectiles[projectile.Id] = nil

	return result
end

function ProjectileService.ExplodeFrag(projectile: ProjectileData, position: Vector3): ExplosionResult
	-- Visual explosion
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = projectile.Radius
	explosion.BlastPressure = 0 -- We handle damage manually
	explosion.Parent = Workspace

	Debris:AddItem(explosion, 2)

	-- Damage players
	local result = DamageService.ApplyExplosionDamage(
		projectile.Owner,
		position,
		projectile.Radius,
		projectile.Damage,
		0.5, -- 50% falloff at edge
		{ projectile.Owner.Character }
	)

	local explosionResult: ExplosionResult = {
		Position = position,
		Radius = projectile.Radius,
		DamagedPlayers = result,
		DamagedVehicles = {},
	}

	return explosionResult
end

function ProjectileService.DeploySmoke(projectile: ProjectileData, position: Vector3)
	-- Create smoke cloud
	local smokePart = Instance.new("Part")
	smokePart.Name = "SmokeCloud_" .. projectile.Id
	smokePart.Shape = Enum.PartType.Ball
	smokePart.Size = Vector3.new(projectile.Radius * 2, projectile.Radius * 2, projectile.Radius * 2)
	smokePart.Position = position
	smokePart.Anchored = true
	smokePart.CanCollide = false
	smokePart.CanQuery = false
	smokePart.Transparency = 0.3
	smokePart.Color = Color3.fromRGB(150, 150, 150)
	smokePart.Material = Enum.Material.SmoothPlastic
	smokePart.Parent = Workspace

	-- Particle effect
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SmokeEmitter"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 150, 150))
	emitter.Size = NumberSequence.new(10, 20)
	emitter.Transparency = NumberSequence.new(0.3, 0.8)
	emitter.Lifetime = NumberRange.new(2, 4)
	emitter.Rate = 50
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = smokePart

	Debris:AddItem(smokePart, projectile.EffectDuration)
end

function ProjectileService.DetonateFlashbang(projectile: ProjectileData, position: Vector3)
	-- Flash effect
	local flash = Instance.new("Part")
	flash.Name = "Flash_" .. projectile.Id
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(1, 1, 1)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.Transparency = 0
	flash.Color = Color3.fromRGB(255, 255, 200)
	flash.Material = Enum.Material.Neon
	flash.Parent = Workspace

	-- Expand and fade
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = game:GetService("TweenService"):Create(flash, tweenInfo, {
		Size = Vector3.new(projectile.Radius * 2, projectile.Radius * 2, projectile.Radius * 2),
		Transparency = 1,
	})
	tween:Play()

	Debris:AddItem(flash, 0.5)

	-- Affect players
	for _, player in ipairs(Players:GetPlayers()) do
		if player == projectile.Owner then continue end

		local character = player.Character
		if not character then continue end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		local distance = (root.Position - position).Magnitude
		if distance <= projectile.Radius then
			-- Check line of sight
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			rayParams.FilterDescendantsInstances = { character }

			local direction = (root.Position - position).Unit * distance
			local rayResult = Workspace:Raycast(position, direction, rayParams)

			if not rayResult or rayResult.Instance:IsDescendantOf(character) then
				-- Player is flashed
				local intensity = 1 - (distance / projectile.Radius)
				MatchRemotes.GasEffect:FireClient(player, {
					type = "Flash",
					intensity = intensity,
					duration = projectile.EffectDuration * intensity,
				})
			end
		end
	end
end

function ProjectileService.IgniteMolotov(projectile: ProjectileData, position: Vector3)
	-- Create fire zone
	local firePart = Instance.new("Part")
	firePart.Name = "FireZone_" .. projectile.Id
	firePart.Shape = Enum.PartType.Cylinder
	firePart.Size = Vector3.new(projectile.Radius * 2, 2, projectile.Radius * 2)
	firePart.Position = position + Vector3.new(0, 1, 0)
	firePart.Anchored = true
	firePart.CanCollide = false
	firePart.Transparency = 0.5
	firePart.Color = Color3.fromRGB(255, 100, 0)
	firePart.Material = Enum.Material.Neon
	firePart.Parent = Workspace

	-- Fire particles
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "FireEmitter"
	emitter.Texture = "rbxasset://textures/particles/fire_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 150, 0), Color3.fromRGB(255, 50, 0))
	emitter.Size = NumberSequence.new(3, 8)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Rate = 100
	emitter.Speed = NumberRange.new(5, 10)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Parent = firePart

	Debris:AddItem(firePart, projectile.EffectDuration)

	-- Damage players in fire over time
	local startTime = os.clock()
	while os.clock() - startTime < projectile.EffectDuration do
		for _, player in ipairs(Players:GetPlayers()) do
			if player == projectile.Owner then continue end

			local character = player.Character
			if not character then continue end

			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then continue end

			local distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
			if distance <= projectile.Radius then
				DamageService.ApplyFireDamage(player, projectile.Damage, 0.5)
			end
		end
		task.wait(0.5)
	end
end

function ProjectileService.DetonateStun(projectile: ProjectileData, position: Vector3)
	-- Stun effect
	for _, player in ipairs(Players:GetPlayers()) do
		if player == projectile.Owner then continue end

		local character = player.Character
		if not character then continue end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then continue end

		local distance = (root.Position - position).Magnitude
		if distance <= projectile.Radius then
			-- Slow player
			local originalSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = originalSpeed * 0.3

			task.delay(projectile.EffectDuration, function()
				if humanoid.Parent then
					humanoid.WalkSpeed = originalSpeed
				end
			end)

			-- Notify client
			MatchRemotes.GasEffect:FireClient(player, {
				type = "Stun",
				intensity = 1 - (distance / projectile.Radius),
				duration = projectile.EffectDuration,
			})
		end
	end
end

-- ==================== REMOTE HANDLERS ====================

MatchRemotes.ThrowProjectile.OnServerEvent:Connect(function(player: Player, projectileType: string, origin: Vector3, direction: Vector3, throwPower: number?)
	-- Validate type
	if not PROJECTILE_CONFIGS[projectileType] then return end

	-- Check if player has projectile in inventory
	-- This would integrate with InventoryManager

	-- Throw
	ProjectileService.ThrowProjectile(player, projectileType, origin, direction, throwPower)
end)

-- ==================== QUERIES ====================

function ProjectileService.GetActiveProjectiles(): { [string]: ProjectileData }
	return activeProjectiles
end

function ProjectileService.GetProjectileCount(): number
	local count = 0
	for _ in pairs(activeProjectiles) do
		count += 1
	end
	return count
end

function ProjectileService.CancelProjectile(projectileId: string)
	local projectile = activeProjectiles[projectileId]
	if projectile then
		projectile.Active = false
		if projectile.Model then
			projectile.Model:Destroy()
		end
		activeProjectiles[projectileId] = nil
	end
end

function ProjectileService.CancelAllProjectiles()
	for projectileId, _ in pairs(activeProjectiles) do
		ProjectileService.CancelProjectile(projectileId)
	end
end

return ProjectileService
