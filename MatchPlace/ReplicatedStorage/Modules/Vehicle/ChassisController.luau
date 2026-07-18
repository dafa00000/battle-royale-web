--[[
	ChassisController - Constraint-based vehicle physics (Spring, Cylindrical, Hinge)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local ChassisController = {}

export type VehicleData = {
	model: Model,
	chassis: BasePart,
	wheels: { WheelData },
	engine: EngineData,
	suspension: SuspensionData,
	steering: SteeringData,
	inputs: VehicleInputs,
	state: VehicleState,
}

export type WheelData = {
	part: BasePart,
	attachment: Attachment,
	spring: SpringConstraint,
	cylindrical: CylindricalConstraint,
	hinge: HingeConstraint,
	alignOrientation: AlignOrientation,
	position: Vector3,
	radius: number,
	width: number,
	isFront: boolean,
	isPowered: boolean,
	isSteerable: boolean,
}

export type EngineData = {
	maxTorque: number,
	maxRPM: number,
	idleRPM: number,
	redlineRPM: number,
	gearRatios: { number },
	finalDrive: number,
	currentGear: number,
	throttle: number,
	brake: number,
	clutch: number,
	rpm: number,
}

export type SuspensionData = {
	stiffness: number,
	damping: number,
	freeLength: number,
	minLength: number,
	maxLength: number,
}

export type SteeringData = {
	maxAngle: number,
	speedSensitivity: number,
	returnSpeed: number,
	currentAngle: number,
}

export type VehicleInputs = {
	throttle: number,
	brake: number,
	steer: number,
	handbrake: boolean,
	gearUp: boolean,
	gearDown: boolean,
}

export type VehicleState = {
	speed: number,
	velocity: Vector3,
	localVelocity: Vector3,
	rpm: number,
	gear: number,
	isGrounded: boolean,
	wheelContacts: number,
	damage: number,
	health: number,
	fuel: number,
}

local vehicles: { [string]: VehicleData } = {}
local playerVehicle: { [Player]: string } = {}

-- Collision groups
PhysicsService:RegisterCollisionGroup("Vehicles")
PhysicsService:RegisterCollisionGroup("VehicleWheels")
PhysicsService:CollisionGroupSetCollidable("Vehicles", "VehicleWheels", false)

function ChassisController.CreateVehicle(model: Model, template: VehicleTemplate): VehicleData
	local chassis = model:FindFirstChild("Chassis") or model.PrimaryPart
	if not chassis then error("Vehicle needs Chassis part") end
	
	chassis.CollisionGroup = "Vehicles"
	
	-- Find wheels
	local wheels: { WheelData } = {}
	for _, wheelModel in ipairs(model:GetDescendants()) do
		if wheelModel.Name:find("Wheel") and wheelModel:IsA("BasePart") then
			local wheelData = ChassisController.SetupWheel(wheelModel, chassis)
			if wheelData then table.insert(wheels, wheelData) end
		end
	end
	
	-- Engine setup
	local engine: EngineData = {
		maxTorque = template.MaxTorque or 4000,
		maxRPM = template.MaxRPM or 6500,
		idleRPM = template.IdleRPM or 800,
		redlineRPM = template.RedlineRPM or 7000,
		gearRatios = template.GearRatios or { 3.5, 2.2, 1.5, 1.1, 0.8 },
		finalDrive = template.FinalDrive or 3.7,
		currentGear = 1,
		throttle = 0,
		brake = 0,
		clutch = 1,
		rpm = 0,
	}
	
	-- Suspension
	local suspension: SuspensionData = {
		stiffness = template.SuspensionStiffness or 30000,
		damping = template.SuspensionDamping or 3000,
		freeLength = template.SuspensionLength or 0.5,
		minLength = template.SuspensionMinLength or 0.1,
		maxLength = template.SuspensionMaxLength or 0.8,
	}
	
	-- Steering
	local steering: SteeringData = {
		maxAngle = template.MaxSteerAngle or 35,
		speedSensitivity = template.SpeedSensitivity or 0.5,
		returnSpeed = template.ReturnSpeed or 5,
		currentAngle = 0,
	}
	
	local vehicleData: VehicleData = {
		model = model,
		chassis = chassis,
		wheels = wheels,
		engine = engine,
		suspension = suspension,
		steering = steering,
		inputs = { throttle = 0, brake = 0, steer = 0, handbrake = false, gearUp = false, gearDown = false },
		state = { speed = 0, velocity = Vector3.zero, localVelocity = Vector3.zero, rpm = 0, gear = 1, isGrounded = false, wheelContacts = 0, damage = 0, health = template.Health or 1000, fuel = 100 },
	}
	
	vehicles[model.Name] = vehicleData
	return vehicleData
end

function ChassisController.SetupWheel(wheelPart: BasePart, chassis: BasePart): WheelData?
	wheelPart.CollisionGroup = "VehicleWheels"
	wheelPart.CanCollide = true
	wheelPart.Massless = false
	wheelPart.CustomPhysicalProperties = PhysicalProperties.new(10, 0.8, 0.01)
	
	-- Create attachments
	local wheelAttachment = Instance.new("Attachment")
	wheelAttachment.Name = "WheelAttachment"
	wheelAttachment.Parent = wheelPart
	
	local chassisAttachment = Instance.new("Attachment")
	chassisAttachment.Name = "ChassisAttachment"
	chassisAttachment.Parent = chassis
	chassisAttachment.Position = wheelPart.Position - chassis.Position
	
	-- Spring constraint (suspension)
	local spring = Instance.new("SpringConstraint")
	spring.Name = "SuspensionSpring"
	spring.Attachment0 = chassisAttachment
	spring.Attachment1 = wheelAttachment
	spring.FreeLength = 0.5
	spring.Stiffness = 30000
	spring.Damping = 3000
	spring.LimitsEnabled = true
	spring.MinLength = 0.1
	spring.MaxLength = 0.8
	spring.Parent = chassis
	
	-- Cylindrical constraint (wheel rotation)
	local cylindrical = Instance.new("CylindricalConstraint")
	cylindrical.Name = "WheelCylindrical"
	cylindrical.Attachment0 = chassisAttachment
	cylindrical.Attachment1 = wheelAttachment
	cylindrical.AngularLimitsEnabled = false
	cylindrical.MotorMaxTorque = 5000
	cylindrical.MotorMaxAngularVelocity = 100
	cylindrical.InclinedAngleEnabled = true
	cylindrical.InclinedAngle = 0
	cylindrical.Parent = chassis
	
	-- Hinge constraint (steering)
	local hinge = Instance.new("HingeConstraint")
	hinge.Name = "SteeringHinge"
	hinge.Attachment0 = chassisAttachment
	hinge.Attachment1 = wheelAttachment
	hinge.LimitsEnabled = true
	hinge.LowerAngle = -35
	hinge.UpperAngle = 35
	hinge.MotorMaxTorque = 1000
	hinge.AngularSpeed = 10
	hinge.Parent = chassis
	
	-- Align orientation (keep wheel upright)
	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "WheelAlignment"
	alignOrientation.Attachment0 = wheelAttachment
	alignOrientation.Attachment1 = chassisAttachment
	alignOrientation.RigidityEnabled = false
	alignOrientation.MaxTorque = 5000
	alignOrientation.Responsiveness = 50
	alignOrientation.Parent = wheelPart
	
	-- Determine wheel properties
	local isFront = wheelPart.Position.Z > chassis.Position.Z
	local isPowered = wheelPart:GetAttribute("Powered") or false
	local isSteerable = wheelPart:GetAttribute("Steerable") or isFront
	
	return {
		part = wheelPart,
		attachment = wheelAttachment,
		spring = spring,
		cylindrical = cylindrical,
		hinge = hinge,
		alignOrientation = alignOrientation,
		position = wheelPart.Position - chassis.Position,
		radius = wheelPart.Size.Y / 2,
		width = wheelPart.Size.X,
		isFront = isFront,
		isPowered = isPowered,
		isSteerable = isSteerable,
	}
end

function ChassisController.UpdateVehicle(vehicleData: VehicleData, dt: number)
	local chassis = vehicleData.chassis
	local engine = vehicleData.engine
	local wheels = vehicleData.wheels
	local inputs = vehicleData.inputs
	local state = vehicleData.state
	
	-- Update wheel contacts
	local wheelContacts = 0
	for _, wheel in ipairs(wheels) do
		if wheel.part:GetNetworkOwner() == nil then
			wheel.part:SetNetworkOwner(nil) -- Server physics
		end
		
		-- Check ground contact
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { vehicleData.model }
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		
		local result = Workspace:Raycast(wheel.part.Position, Vector3.new(0, -wheel.radius - 0.3, 0), raycastParams)
		if result then
			wheelContacts += 1
			
			-- Suspension force (handled by SpringConstraint)
			-- But we can read compression for effects
			local compression = (wheel.spring.FreeLength - wheel.spring.CurrentLength) / wheel.spring.FreeLength
			wheel.part:SetAttribute("SuspensionCompression", compression)
		end
	end
	
	state.wheelContacts = wheelContacts
	state.isGrounded = wheelContacts >= 2
	
	-- Engine simulation
	if state.isGrounded then
		ChassisController.UpdateEngine(vehicleData, dt)
	end
	
	-- Apply wheel forces
	for _, wheel in ipairs(wheels) do
		ChassisController.UpdateWheel(wheel, vehicleData, dt)
	end
	
	-- Steering
	ChassisController.UpdateSteering(vehicleData, dt)
	
	-- Update state
	state.velocity = chassis.AssemblyLinearVelocity
	state.localVelocity = chassis.CFrame:VectorToObjectSpace(state.velocity)
	state.speed = state.velocity.Magnitude
	state.rpm = engine.rpm
	state.gear = engine.currentGear
end

function ChassisController.UpdateEngine(vehicleData: VehicleData, dt: number)
	local engine = vehicleData.engine
	local state = vehicleData.state
	local wheels = vehicleData.wheels
	
	-- Calculate wheel RPM from powered wheels
	local avgWheelRPM = 0
	local poweredCount = 0
	for _, wheel in ipairs(wheels) do
		if wheel.isPowered then
			local wheelRPM = wheel.cylindrical.CurrentAngularVelocity * 60 / (2 * math.pi)
			avgWheelRPM += math.abs(wheelRPM)
			poweredCount += 1
		end
	end
	if poweredCount > 0 then avgWheelRPM /= poweredCount end
	
	-- Engine RPM based on wheel RPM and gear ratio
	local gearRatio = engine.gearRatios[engine.currentGear] * engine.finalDrive
	engine.rpm = math.max(engine.idleRPM, avgWheelRPM * gearRatio * engine.clutch)
	engine.rpm = math.min(engine.rpm, engine.redlineRPM * 1.1)
	
	-- Torque curve (simplified)
	local torqueMultiplier = 1 - (engine.rpm / engine.redlineRPM) ^ 2
	torqueMultiplier = math.max(0.3, torqueMultiplier)
	
	-- Apply throttle
	local targetThrottle = inputs.throttle
	engine.throttle = Util.Lerp(engine.throttle, targetThrottle, dt * 5)
	
	-- Apply brake
	engine.brake = inputs.brake
	
	-- Gear shifting logic
	if inputs.gearUp and engine.currentGear < #engine.gearRatios then
		engine.currentGear += 1
		engine.clutch = 0
		task.delay(0.3, function() engine.clutch = 1 end)
	elseif inputs.gearDown and engine.currentGear > 1 then
		engine.currentGear -= 1
		engine.clutch = 0
		task.delay(0.3, function() engine.clutch = 1 end)
	end
	
	-- Auto shift (simple)
	if engine.rpm > engine.redlineRPM * 0.95 and engine.currentGear < #engine.gearRatios then
		engine.currentGear += 1
		engine.clutch = 0
		task.delay(0.2, function() engine.clutch = 1 end)
	elseif engine.rpm < engine.idleRPM * 1.5 and engine.currentGear > 1 then
		engine.currentGear -= 1
	end
end

function ChassisController.UpdateWheel(wheel: WheelData, vehicleData: VehicleData, dt: number)
	local engine = vehicleData.engine
	local inputs = vehicleData.inputs
	local state = vehicleData.state
	
	-- Motor torque for powered wheels
	if wheel.isPowered and state.isGrounded then
		local maxTorque = engine.maxTorque * engine.throttle * engine.clutch
		local gearRatio = engine.gearRatios[engine.currentGear] * engine.finalDrive
		local wheelTorque = maxTorque * gearRatio * 0.8 -- Efficiency
		
		wheel.cylindrical.MotorMaxTorque = wheelTorque
		wheel.cylindrical.MotorMaxAngularVelocity = engine.maxRPM * gearRatio
	else
		wheel.cylindrical.MotorMaxTorque = 0
	end
	
	-- Brake torque
	if inputs.brake > 0 or inputs.handbrake then
		local brakeForce = (inputs.handbrake and 20000 or 10000) * inputs.brake
		if wheel.isFront or inputs.handbrake then
			wheel.cylindrical.MotorMaxTorque = brakeForce
			wheel.cylindrical.MotorMaxAngularVelocity = 0
		end
	end
	
	-- Steering angle for steerable wheels
	if wheel.isSteerable then
		wheel.hinge.TargetAngle = math.rad(vehicleData.steering.currentAngle)
	end
end

function ChassisController.UpdateSteering(vehicleData: VehicleData, dt: number)
	local steering = vehicleData.steering
	local inputs = vehicleData.inputs
	local state = vehicleData.state
	
	-- Speed-sensitive steering
	local speedFactor = 1 - (state.speed / 100) * steering.speedSensitivity
	speedFactor = math.clamp(speedFactor, 0.3, 1)
	
	local targetAngle = inputs.steer * steering.maxAngle * speedFactor
	
	-- Smooth steering return
	if math.abs(inputs.steer) < 0.01 then
		targetAngle = 0
	end
	
	steering.currentAngle = Util.Lerp(steering.currentAngle, targetAngle, dt * steering.returnSpeed)
end

function ChassisController.SetInputs(vehicleName: string, inputs: VehicleInputs)
	local vehicle = vehicles[vehicleName]
	if vehicle then
		vehicle.inputs = inputs
	end
end

function ChassisController.EnterVehicle(player: Player, vehicleName: string): boolean
	local vehicle = vehicles[vehicleName]
	if not vehicle then return false end
	
	-- Check seat availability
	local seat = vehicle.model:FindFirstChild("DriverSeat") or vehicle.model:FindFirstChild("Seat")
	if not seat then return false end
	
	if seat.Occupant then return false end
	
	-- Sit player
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Sit = true
			seat:Sit(humanoid)
		end
	end
	
	playerVehicle[player] = vehicleName
	
	-- Give network ownership to player
	for _, wheel in ipairs(vehicle.wheels) do
		wheel.part:SetNetworkOwner(player)
	end
	vehicle.chassis:SetNetworkOwner(player)
	
	return true
end

function ChassisController.ExitVehicle(player: Player)
	local vehicleName = playerVehicle[player]
	if not vehicleName then return end
	
	local vehicle = vehicles[vehicleName]
	if vehicle then
		-- Return network ownership to server
		for _, wheel in ipairs(vehicle.wheels) do
			wheel.part:SetNetworkOwner(nil)
		end
		vehicle.chassis:SetNetworkOwner(nil)
	end
	
	playerVehicle[player] = nil
end

function ChassisController.GetVehicle(vehicleName: string): VehicleData?
	return vehicles[vehicleName]
end

function ChassisController.GetPlayerVehicle(player: Player): VehicleData?
	local name = playerVehicle[player]
	if name then return vehicles[name] end
	return nil
end

function ChassisController.DamageVehicle(vehicleName: string, amount: number, hitPosition: Vector3, hitNormal: Vector3)
	local vehicle = vehicles[vehicleName]
	if not vehicle then return end
	
	vehicle.state.health -= amount
	vehicle.state.damage += amount
	
	-- Visual deformation at hit point
	ChassisController.DeformMesh(vehicle, hitPosition, hitNormal, amount)
	
	if vehicle.state.health <= 0 then
		ChassisController.DestroyVehicle(vehicleName)
	end
end

function ChassisController.DeformMesh(vehicle: VehicleData, hitPos: Vector3, hitNormal: Vector3, force: number)
	-- Find closest body panel
	-- In practice, you'd use mesh deformation or swap damaged parts
	print("[Chassis] Deform at", hitPos, "force:", force)
end

function ChassisController.DestroyVehicle(vehicleName: string)
	local vehicle = vehicles[vehicleName]
	if not vehicle then return end
	
	-- Explosion effects
	-- Remove vehicle
	vehicle.model:Destroy()
	vehicles[vehicleName] = nil
end

-- Main update loop
RunService.Heartbeat:Connect(function(dt)
	for _, vehicle in pairs(vehicles) do
		if vehicle.chassis and vehicle.chassis.Parent then
			ChassisController.UpdateVehicle(vehicle, dt)
		end
	end
end)

return ChassisController