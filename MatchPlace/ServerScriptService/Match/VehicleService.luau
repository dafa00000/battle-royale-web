--[[
	VehicleService - Spawn vehicles in map, assign network ownership to driver,
	validate enter/exit, track health, respawn/destroy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local MatchRemotes = ReplicatedStorage.Remotes.MatchRemotes

local VehicleService = {}

export type VehicleData = {
	Id: string,
	Model: Model,
	Type: string,
	Health: number,
	MaxHealth: number,
	Driver: Player?,
	Passengers: { [number]: Player? },
	SeatCount: number,
	SpawnTime: number,
	LastDamageTime: number,
	IsDestroyed: boolean,
	NetworkOwner: Player?,
}

export type VehicleSpawnPoint = {
	Position: Vector3,
	Rotation: number,
	VehicleType: string,
	Spawned: boolean,
}

-- Vehicle definitions
local VEHICLE_TYPES = {
	UAZ = {
		Name = "UAZ",
		Seats = 4,
		MaxHealth = Constants.VEHICLE_HEALTH.UAZ,
		SpawnChance = Constants.VEHICLE_SPAWN_CHANCE,
	},
	Buggy = {
		Name = "Buggy",
		Seats = 2,
		MaxHealth = Constants.VEHICLE_HEALTH.Buggy,
		SpawnChance = Constants.VEHICLE_SPAWN_CHANCE * 0.8,
	},
	Motorcycle = {
		Name = "Motorcycle",
		Seats = 2,
		MaxHealth = Constants.VEHICLE_HEALTH.Motorcycle,
		SpawnChance = Constants.VEHICLE_SPAWN_CHANCE * 1.2,
	},
	Boat = {
		Name = "Boat",
		Seats = 4,
		MaxHealth = Constants.VEHICLE_HEALTH.Boat,
		SpawnChance = Constants.VEHICLE_SPAWN_CHANCE * 0.5,
	},
	Helicopter = {
		Name = "Helicopter",
		Seats = 6,
		MaxHealth = Constants.VEHICLE_HEALTH.Helicopter,
		SpawnChance = Constants.VEHICLE_SPAWN_CHANCE * 0.2,
	},
}

-- State
local vehicles: { [string]: VehicleData } = {}
local spawnPoints: { VehicleSpawnPoint } = {}
local vehicleFolder: Folder = nil
local nextVehicleId = 1

-- ==================== INITIALIZATION ====================

function VehicleService.Initialize()
	vehicleFolder = Instance.new("Folder")
	vehicleFolder.Name = "Vehicles"
	vehicleFolder.Parent = Workspace

	-- Generate spawn points
	VehicleService.GenerateSpawnPoints()

	-- Spawn initial vehicles
	VehicleService.SpawnInitialVehicles()

	-- Start update loop
	RunService.Heartbeat:Connect(VehicleService.Update)

	print("[VehicleService] Initialized with", #spawnPoints, "spawn points")
end

function VehicleService.GenerateSpawnPoints()
	local mapRadius = Constants.MAP_RADIUS
	local numPoints = Constants.MAX_VEHICLES_PER_MATCH * 2 -- Extra points for respawning

	for i = 1, numPoints do
		local angle = (i / numPoints) * math.pi * 2 + math.random() * 0.5
		local distance = math.random() * mapRadius * 0.7
		local pos = Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)

		-- Raycast down to find ground
		local rayOrigin = pos + Vector3.new(0, 100, 0)
		local rayDirection = Vector3.new(0, -200, 0)
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { vehicleFolder }

		local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
		if result then
			-- Determine vehicle type based on location
			local vehicleType = VehicleService.GetVehicleTypeForLocation(result.Position)

			table.insert(spawnPoints, {
				Position = result.Position + Vector3.new(0, 2, 0),
				Rotation = math.random() * 360,
				VehicleType = vehicleType,
				Spawned = false,
			})
		end
	end
end

function VehicleService.GetVehicleTypeForLocation(position: Vector3): string
	-- Simple logic: water near shore = boat, otherwise random
	local roll = math.random()
	local types = { "UAZ", "Buggy", "Motorcycle" }
	local weights = { 0.5, 0.3, 0.2 }

	local total = 0
	for i, w in ipairs(weights) do
		total += w
		if roll <= total then
			return types[i]
		end
	end
	return "UAZ"
end

function VehicleService.SpawnInitialVehicles()
	local spawned = 0
	for _, point in ipairs(spawnPoints) do
		if spawned >= Constants.MAX_VEHICLES_PER_MATCH then break end

		if math.random() < VEHICLE_TYPES[point.VehicleType].SpawnChance then
			VehicleService.SpawnVehicle(point)
			spawned += 1
		end
	end

	print("[VehicleService] Spawned", spawned, "initial vehicles")
end

-- ==================== SPAWNING ====================

function VehicleService.SpawnVehicle(spawnPoint: VehicleSpawnPoint): VehicleData?
	local template = VEHICLE_TYPES[spawnPoint.VehicleType]
	if not template then return nil end

	local vehicleId = "Vehicle_" .. nextVehicleId
	nextVehicleId += 1

	-- Create vehicle model (simplified - would use actual assets)
	local model = VehicleService.CreateVehicleModel(spawnPoint.VehicleType, spawnPoint.Position, spawnPoint.Rotation)
	model.Name = vehicleId
	model.Parent = vehicleFolder

	-- Setup seats
	local seatCount = template.Seats
	local seats = {}
	for i = 1, seatCount do
		local seat = Instance.new("VehicleSeat")
		seat.Name = "Seat_" .. i
		seat.Size = Vector3.new(2, 1, 2)
		seat.Position = spawnPoint.Position + Vector3.new((i - 1) * 2.5, 0, 0)
		seat.Parent = model
		table.insert(seats, seat)
	end

	local vehicleData: VehicleData = {
		Id = vehicleId,
		Model = model,
		Type = spawnPoint.VehicleType,
		Health = template.MaxHealth,
		MaxHealth = template.MaxHealth,
		Driver = nil,
		Passengers = {},
		SeatCount = seatCount,
		SpawnTime = os.clock(),
		LastDamageTime = 0,
		IsDestroyed = false,
		NetworkOwner = nil,
	}

	vehicles[vehicleId] = vehicleData
	spawnPoint.Spawned = true

	-- Setup damage tracking
	VehicleService.SetupVehicleDamageTracking(vehicleData)

	-- Broadcast spawn
	MatchRemotes.VehicleUpdate:FireAllClients({
		action = "Spawned",
		vehicleId = vehicleId,
		vehicleType = spawnPoint.VehicleType,
		position = spawnPoint.Position,
		health = vehicleData.Health,
		maxHealth = vehicleData.MaxHealth,
	})

	return vehicleData
end

function VehicleService.CreateVehicleModel(vehicleType: string, position: Vector3, rotation: number): Model
	local model = Instance.new("Model")
	model.Name = vehicleType

	-- Main body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(8, 3, 14)
	body.Position = position
	body.Orientation = Vector3.new(0, rotation, 0)
	body.Anchored = false
	body.CanCollide = true
	body.BrickColor = BrickColor.new("Bright red")
	body.Parent = model

	-- Wheels
	for i = 1, 4 do
		local wheel = Instance.new("Part")
		wheel.Name = "Wheel_" .. i
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(1.5, 1.5, 1.5)
		local offsetX = (i % 2 == 0) and 3 or -3
		local offsetZ = (i > 2) and 4 or -4
		wheel.Position = position + Vector3.new(offsetX, -1, offsetZ)
		wheel.Orientation = Vector3.new(0, rotation, 90)
		wheel.Anchored = false
		wheel.CanCollide = true
		wheel.BrickColor = BrickColor.new("Dark stone grey")
		wheel.Parent = model

		-- Weld to body
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = wheel
		weld.Parent = body
	end

	model.PrimaryPart = body
	return model
end

-- ==================== ENTER / EXIT ====================

function VehicleService.CanEnterVehicle(player: Player, vehicleId: string): (boolean, string?)
	local vehicle = vehicles[vehicleId]
	if not vehicle then return false, "Vehicle not found" end
	if vehicle.IsDestroyed then return false, "Vehicle is destroyed" end

	-- Check if player already in vehicle
	for _, v in pairs(vehicles) do
		if v.Driver == player then return false, "Already in vehicle" end
		for _, p in pairs(v.Passengers) do
			if p == player then return false, "Already in vehicle" end
		end
	end

	-- Check if has available seat
	local hasSeat = false
	if not vehicle.Driver then
		hasSeat = true
	else
		for i = 1, vehicle.SeatCount do
			if not vehicle.Passengers[i] then
				hasSeat = true
				break
			end
		end
	end

	if not hasSeat then return false, "No available seats" end

	-- Check distance
	local character = player.Character
	if not character then return false, "No character" end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false, "No root part" end

	local vehicleRoot = vehicle.Model.PrimaryPart
	if not vehicleRoot then return false, "Vehicle has no primary part" end

	local distance = (root.Position - vehicleRoot.Position).Magnitude
	if distance > 15 then return false, "Too far from vehicle" end

	return true, nil
end

function VehicleService.EnterVehicle(player: Player, vehicleId: string, seatIndex: number?): boolean
	local canEnter, reason = VehicleService.CanEnterVehicle(player, vehicleId)
	if not canEnter then
		MatchRemotes.VehicleEnter:FireClient(player, {
			success = false,
			reason = reason,
		})
		return false
	end

	local vehicle = vehicles[vehicleId]
	local character = player.Character
	if not character then return false end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not root or not humanoid then return false end

	-- Assign seat
	local assignedSeat = seatIndex
	if not assignedSeat then
		if not vehicle.Driver then
			vehicle.Driver = player
			vehicle.NetworkOwner = player
			assignedSeat = 0 -- Driver seat
		else
			for i = 1, vehicle.SeatCount do
				if not vehicle.Passengers[i] then
					vehicle.Passengers[i] = player
					assignedSeat = i
					break
				end
			end
		end
	else
		if assignedSeat == 0 then
			if vehicle.Driver then return false end
			vehicle.Driver = player
			vehicle.NetworkOwner = player
		else
			if vehicle.Passengers[assignedSeat] then return false end
			vehicle.Passengers[assignedSeat] = player
		end
	end

	-- Sit player in vehicle seat
	local seats = {}
	for _, seat in ipairs(vehicle.Model:GetChildren()) do
		if seat:IsA("VehicleSeat") then
			table.insert(seats, seat)
		end
	end

	if #seats > 0 then
		local targetSeat = seats[math.min(assignedSeat + 1, #seats)]
		if targetSeat then
			-- Move character to seat
			root.CFrame = targetSeat.CFrame + Vector3.new(0, 2, 0)
			humanoid.Sit = true
			targetSeat:Sit(humanoid)

			-- Set network ownership for driver
			if assignedSeat == 0 then
				vehicle.Model.PrimaryPart:SetNetworkOwner(player)
			end
		end
	end

	-- Broadcast
	MatchRemotes.VehicleEnter:FireAllClients({
		success = true,
		vehicleId = vehicleId,
		player = player.Name,
		playerUserId = player.UserId,
		seatIndex = assignedSeat,
		isDriver = assignedSeat == 0,
	})

	return true
end

function VehicleService.ExitVehicle(player: Player): boolean
	local vehicleId, seatIndex = VehicleService.GetPlayerVehicle(player)
	if not vehicleId then return false end

	local vehicle = vehicles[vehicleId]
	if not vehicle then return false end

	local character = player.Character
	if not character then return false end

	local humanoid = character:FindFirstChild("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	-- Remove from seat
	if seatIndex == 0 then
		vehicle.Driver = nil
		vehicle.NetworkOwner = nil
		vehicle.Model.PrimaryPart:SetNetworkOwner(nil)
	else
		vehicle.Passengers[seatIndex] = nil
	end

	-- Stand up
	if humanoid then
		humanoid.Sit = false
	end

	-- Move away from vehicle
	if root and vehicle.Model.PrimaryPart then
		local exitPos = vehicle.Model.PrimaryPart.Position + vehicle.Model.PrimaryPart.CFrame.RightVector * 5
		root.CFrame = CFrame.new(exitPos + Vector3.new(0, 3, 0))
	end

	-- Broadcast
	MatchRemotes.VehicleExit:FireAllClients({
		vehicleId = vehicleId,
		player = player.Name,
		playerUserId = player.UserId,
		seatIndex = seatIndex,
	})

	return true
end

function VehicleService.GetPlayerVehicle(player: Player): (string?, number?)
	for vehicleId, vehicle in pairs(vehicles) do
		if vehicle.Driver == player then
			return vehicleId, 0
		end
		for seatIndex, passenger in pairs(vehicle.Passengers) do
			if passenger == player then
				return vehicleId, seatIndex
			end
		end
	end
	return nil, nil
end

-- ==================== DAMAGE & DESTRUCTION ====================

function VehicleService.SetupVehicleDamageTracking(vehicleData: VehicleData)
	local primaryPart = vehicleData.Model.PrimaryPart
	if not primaryPart then return end

	-- Track damage via touched or raycast hits
	-- This is simplified - in a real game you'd have more sophisticated damage detection
	primaryPart.Touched:Connect(function(hit)
		-- Handle collision damage
		local now = os.clock()
		if now - vehicleData.LastDamageTime < 0.5 then return end

		local velocity = primaryPart.AssemblyLinearVelocity.Magnitude
		if velocity > 20 then
			local damage = math.floor(velocity * 0.5)
			VehicleService.DamageVehicle(vehicleData.Id, damage, nil, "Collision")
			vehicleData.LastDamageTime = now
		end
	end)
end

function VehicleService.DamageVehicle(vehicleId: string, damage: number, attacker: Player?, cause: string?)
	local vehicle = vehicles[vehicleId]
	if not vehicle or vehicle.IsDestroyed then return end

	vehicle.Health = math.max(0, vehicle.Health - damage)

	-- Broadcast damage
	MatchRemotes.VehicleDamage:FireAllClients({
		vehicleId = vehicleId,
		damage = damage,
		health = vehicle.Health,
		maxHealth = vehicle.MaxHealth,
		attacker = attacker and attacker.Name or nil,
		cause = cause,
	})

	-- Check destruction
	if vehicle.Health <= 0 then
		VehicleService.DestroyVehicle(vehicleId, attacker, cause)
	end
end

function VehicleService.DestroyVehicle(vehicleId: string, attacker: Player?, cause: string?)
	local vehicle = vehicles[vehicleId]
	if not vehicle or vehicle.IsDestroyed then return end

	vehicle.IsDestroyed = true

	-- Explode effect
	local explosion = Instance.new("Explosion")
	explosion.Position = vehicle.Model.PrimaryPart.Position
	explosion.BlastRadius = 15
	explosion.BlastPressure = 500000
	explosion.Parent = Workspace

	-- Damage nearby players
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if not character then continue end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		local distance = (root.Position - explosion.Position).Magnitude
		if distance < 20 then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				local damage = math.floor(100 * (1 - distance / 20))
				humanoid:TakeDamage(damage)
			end
		end
	end

	-- Remove players from vehicle
	if vehicle.Driver then
		VehicleService.ExitVehicle(vehicle.Driver)
	end
	for _, passenger in pairs(vehicle.Passengers) do
		if passenger then
			VehicleService.ExitVehicle(passenger)
		end
	end

	-- Broadcast destruction
	MatchRemotes.VehicleUpdate:FireAllClients({
		action = "Destroyed",
		vehicleId = vehicleId,
		attacker = attacker and attacker.Name or nil,
		cause = cause,
	})

	-- Schedule respawn after delay
	task.delay(30, function()
		VehicleService.RespawnVehicle(vehicleId)
	end)

	-- Remove model after explosion
	task.delay(5, function()
		if vehicle.Model and vehicle.Model.Parent then
			vehicle.Model:Destroy()
		end
		vehicles[vehicleId] = nil
	end)
end

function VehicleService.RespawnVehicle(vehicleId: string)
	-- Find original spawn point
	for _, point in ipairs(spawnPoints) do
		if point.Spawned then
			-- Check if vehicle at this point is destroyed
			local found = false
			for id, v in pairs(vehicles) do
				if v.Model and v.Model.PrimaryPart and
					(v.Model.PrimaryPart.Position - point.Position).Magnitude < 10 then
					found = true
					break
				end
			end

			if not found then
				point.Spawned = false
				VehicleService.SpawnVehicle(point)
				return
			end
		end
	end
end

-- ==================== UPDATE ====================

function VehicleService.Update()
	-- Update network ownership based on proximity
	for vehicleId, vehicle in pairs(vehicles) do
		if vehicle.IsDestroyed then continue end

		if vehicle.Driver then
			-- Ensure driver still has network ownership
			if vehicle.NetworkOwner ~= vehicle.Driver then
				vehicle.NetworkOwner = vehicle.Driver
				vehicle.Model.PrimaryPart:SetNetworkOwner(vehicle.Driver)
			end
		else
			-- Find nearest player for network ownership
			local nearestPlayer = nil
			local nearestDist = math.huge

			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				if not character then continue end
				local root = character:FindFirstChild("HumanoidRootPart")
				if not root then continue end

				local dist = (root.Position - vehicle.Model.PrimaryPart.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestPlayer = player
				end
			end

			if nearestPlayer and nearestDist < 100 then
				if vehicle.NetworkOwner ~= nearestPlayer then
					vehicle.NetworkOwner = nearestPlayer
					vehicle.Model.PrimaryPart:SetNetworkOwner(nearestPlayer)
				end
			end
		end
	end
end

-- ==================== REMOTE HANDLERS ====================

MatchRemotes.VehicleEnterRequest.OnServerInvoke = function(player: Player, vehicleId: string, seatIndex: number?)
	return { success = VehicleService.EnterVehicle(player, vehicleId, seatIndex) }
end

MatchRemotes.VehicleExitRequest.OnServerInvoke = function(player: Player)
	return { success = VehicleService.ExitVehicle(player) }
end

-- ==================== QUERIES ====================

function VehicleService.GetVehicle(vehicleId: string): VehicleData?
	return vehicles[vehicleId]
end

function VehicleService.GetAllVehicles(): { [string]: VehicleData }
	return vehicles
end

function VehicleService.GetVehicleCount(): number
	local count = 0
	for _ in pairs(vehicles) do
		count += 1
	end
	return count
end

return VehicleService
