--[[
	SafeZoneService - Server-authoritative safe zone management
	Phases from Constants.ZONE_PHASES, shrink with TweenService, damage tick to players outside zone,
	broadcast ZoneUpdate. Handles warning time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)
local DamageService = require(script.Parent.Parent.Combat.DamageService)

local MatchRemotes = ReplicatedStorage.Remotes.MatchRemotes

local SafeZoneService = {}

export type ZonePhase = {
	duration: number,
	radius: number,
	damagePerTick: number,
	tickInterval: number,
	warningTime: number,
}

export type ZoneState = {
	Phase: number,
	Center: Vector3,
	CurrentRadius: number,
	TargetRadius: number,
	IsShrinking: boolean,
	IsWarning: boolean,
	PhaseStartTime: number,
	PhaseEndTime: number,
	WarningEndTime: number,
	ShrinkStartTime: number,
	NextCenter: Vector3?,
	NextRadius: number?,
}

-- State
local zoneState: ZoneState = {
	Phase = 0,
	Center = Vector3.new(0, 0, 0),
	CurrentRadius = Constants.INITIAL_ZONE_RADIUS,
	TargetRadius = Constants.INITIAL_ZONE_RADIUS,
	IsShrinking = false,
	IsWarning = false,
	PhaseStartTime = 0,
	PhaseEndTime = 0,
	WarningEndTime = 0,
	ShrinkStartTime = 0,
	NextCenter = nil,
	NextRadius = nil,
}

local zonePart: Part? = nil
local shrinkTween: Tween? = nil
local phaseConnection: RBXScriptConnection? = nil
local isActive = false

-- ==================== INITIALIZATION ====================

function SafeZoneService.Initialize()
	-- Pick random center within map bounds
	local mapRadius = Constants.MAP_RADIUS * 0.6
	local angle = math.random() * math.pi * 2
	local distance = math.random() * mapRadius
	zoneState.Center = Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)
	zoneState.CurrentRadius = Constants.INITIAL_ZONE_RADIUS
	zoneState.TargetRadius = Constants.INITIAL_ZONE_RADIUS

	-- Create zone visual
	SafeZoneService.CreateZoneVisual()

	isActive = true
	print("[SafeZoneService] Initialized at", zoneState.Center, "radius:", zoneState.CurrentRadius)
end

function SafeZoneService.CreateZoneVisual()
	if zonePart then zonePart:Destroy() end

	zonePart = Instance.new("Part")
	zonePart.Name = "SafeZone"
	zonePart.Shape = Enum.PartType.Cylinder
	zonePart.Size = Vector3.new(zoneState.CurrentRadius * 2, 1000, zoneState.CurrentRadius * 2)
	zonePart.Position = zoneState.Center + Vector3.new(0, 500, 0)
	zonePart.Anchored = true
	zonePart.CanCollide = false
	zonePart.Transparency = 0.9
	zonePart.Color = Color3.fromRGB(0, 255, 0)
	zonePart.Material = Enum.Material.ForceField
	zonePart.Parent = Workspace

	-- Add highlight for visibility
	local highlight = Instance.new("Highlight")
	highlight.Name = "ZoneHighlight"
	highlight.FillTransparency = 0.9
	highlight.OutlineTransparency = 0.5
	highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
	highlight.Parent = zonePart
end

function SafeZoneService.UpdateZoneVisual()
	if not zonePart then return end

	local targetSize = Vector3.new(zoneState.CurrentRadius * 2, 1000, zoneState.CurrentRadius * 2)
	local targetPos = zoneState.Center + Vector3.new(0, 500, 0)

	-- Tween the visual
	if shrinkTween then shrinkTween:Cancel() end

	local tweenInfo = TweenInfo.new(
		0.5,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)

	shrinkTween = TweenService:Create(zonePart, tweenInfo, {
		Size = targetSize,
		Position = targetPos,
	})
	shrinkTween:Play()

	-- Update color based on state
	if zoneState.IsShrinking then
		zonePart.Color = Color3.fromRGB(255, 100, 0) -- Orange when shrinking
	elseif zoneState.IsWarning then
		zonePart.Color = Color3.fromRGB(255, 200, 0) -- Yellow when warning
	else
		zonePart.Color = Color3.fromRGB(0, 255, 0) -- Green when safe
	end
end

-- ==================== ZONE CONTROL ====================

function SafeZoneService.StartPhase(phaseIndex: number)
	local phases = Constants.ZONE_PHASES
	if phaseIndex < 1 or phaseIndex > #phases then
		warn("[SafeZoneService] Invalid phase:", phaseIndex)
		return
	end

	local phase = phases[phaseIndex]
	local prevPhase = phaseIndex > 1 and phases[phaseIndex - 1] or nil

	zoneState.Phase = phaseIndex
	zoneState.PhaseStartTime = os.clock()
	zoneState.PhaseEndTime = os.clock() + phase.duration
	zoneState.IsWarning = false
	zoneState.IsShrinking = false

	-- Calculate next zone target
	local nextRadius = phase.radius
	local nextCenter = SafeZoneService.CalculateNextCenter(phaseIndex)

	zoneState.NextCenter = nextCenter
	zoneState.NextRadius = nextRadius

	-- Start warning phase
	SafeZoneService.StartWarning(phaseIndex)

	-- Schedule shrink
	task.delay(phase.warningTime, function()
		if zoneState.Phase == phaseIndex then
			SafeZoneService.StartShrink(phaseIndex)
		end
	end)

	-- Schedule damage ticks
	SafeZoneService.StartDamageTicks(phaseIndex)

	-- Broadcast initial state
	SafeZoneService.BroadcastZoneUpdate()

	print("[SafeZoneService] Phase", phaseIndex, "started. Warning:", phase.warningTime, "s, Duration:", phase.duration, "s")
end

function SafeZoneService.CalculateNextCenter(phaseIndex: number): Vector3
	local phases = Constants.ZONE_PHASES
	local phase = phases[phaseIndex]
	local currentRadius = phaseIndex > 1 and phases[phaseIndex - 1].radius or Constants.INITIAL_ZONE_RADIUS
	local nextRadius = phase.radius

	-- Random offset within the difference of radii
	local maxOffset = math.max(0, currentRadius - nextRadius)
	local angle = math.random() * math.pi * 2
	local distance = math.random() * maxOffset * 0.8 -- Bias towards center

	return Vector3.new(
		zoneState.Center.X + math.cos(angle) * distance,
		0,
		zoneState.Center.Z + math.sin(angle) * distance
	)
end

function SafeZoneService.StartWarning(phaseIndex: number)
	zoneState.IsWarning = true
	zoneState.WarningEndTime = os.clock() + Constants.ZONE_PHASES[phaseIndex].warningTime

	MatchRemotes.ZoneWarning:FireAllClients({
		phase = phaseIndex,
		warningTime = Constants.ZONE_PHASES[phaseIndex].warningTime,
		nextCenter = zoneState.NextCenter,
		nextRadius = zoneState.NextRadius,
		timestamp = os.clock(),
	})

	SafeZoneService.UpdateZoneVisual()

	-- Warning countdown updates
	task.spawn(function()
		while zoneState.IsWarning and zoneState.Phase == phaseIndex do
			local remaining = zoneState.WarningEndTime - os.clock()
			if remaining <= 0 then break end

			MatchRemotes.ZoneWarning:FireAllClients({
				phase = phaseIndex,
				remaining = remaining,
				isCountdown = true,
				timestamp = os.clock(),
			})
			task.wait(1)
		end
	end)
end

function SafeZoneService.StartShrink(phaseIndex: number)
	local phase = Constants.ZONE_PHASES[phaseIndex]
	zoneState.IsWarning = false
	zoneState.IsShrinking = true
	zoneState.ShrinkStartTime = os.clock()

	local startRadius = zoneState.CurrentRadius
	local startCenter = zoneState.Center
	local targetRadius = phase.radius
	local targetCenter = zoneState.NextCenter or zoneState.Center
	local shrinkDuration = phase.duration - phase.warningTime

	-- Animate shrink
	local startTime = os.clock()
	while os.clock() - startTime < shrinkDuration and zoneState.Phase == phaseIndex do
		local alpha = (os.clock() - startTime) / shrinkDuration
		alpha = math.clamp(alpha, 0, 1)

		zoneState.CurrentRadius = Util.Lerp(startRadius, targetRadius, alpha)
		zoneState.Center = startCenter:Lerp(targetCenter, alpha)

		SafeZoneService.UpdateZoneVisual()
		SafeZoneService.BroadcastZoneUpdate()
		task.wait(0.1)
	end

	zoneState.IsShrinking = false
	zoneState.CurrentRadius = targetRadius
	zoneState.Center = targetCenter

	SafeZoneService.UpdateZoneVisual()
	SafeZoneService.BroadcastZoneUpdate()

	-- Start next phase if not last
	if phaseIndex < #Constants.ZONE_PHASES then
		task.delay(5, function()
			SafeZoneService.StartPhase(phaseIndex + 1)
		end)
	end
end

function SafeZoneService.StartDamageTicks(phaseIndex: number)
	local phase = Constants.ZONE_PHASES[phaseIndex]

	task.spawn(function()
		while zoneState.Phase == phaseIndex and isActive do
			SafeZoneService.DamagePlayersOutsideZone(phase.damagePerTick)
			task.wait(phase.tickInterval)
		end
	end)
end

function SafeZoneService.DamagePlayersOutsideZone(damagePerTick: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if not character then continue end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end

		-- Check if outside zone
		local distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - zoneState.Center).Magnitude
		if distance > zoneState.CurrentRadius then
			-- Apply zone damage
			DamageService.ApplyZoneDamage(player, damagePerTick, zoneState.Phase)

			-- Fire gas effect to client
			MatchRemotes.GasEffect:FireClient(player, {
				intensity = math.clamp(1 - (zoneState.CurrentRadius / Constants.INITIAL_ZONE_RADIUS), 0.3, 1),
				damagePerTick = damagePerTick,
				isInGas = true,
				phase = zoneState.Phase,
			})
		end
	end
end

-- ==================== QUERIES ====================

function SafeZoneService.GetZoneState(): ZoneState
	return zoneState
end

function SafeZoneService.GetCurrentRadius(): number
	return zoneState.CurrentRadius
end

function SafeZoneService.GetCenter(): Vector3
	return zoneState.Center
end

function SafeZoneService.IsInZone(position: Vector3): boolean
	local flatPos = Vector3.new(position.X, 0, position.Z)
	return (flatPos - zoneState.Center).Magnitude <= zoneState.CurrentRadius
end

function SafeZoneService.GetDistanceToZone(position: Vector3): number
	local flatPos = Vector3.new(position.X, 0, position.Z)
	return (flatPos - zoneState.Center).Magnitude - zoneState.CurrentRadius
end

function SafeZoneService.GetPhase(): number
	return zoneState.Phase
end

function SafeZoneService.GetTimeRemaining(): number
	return math.max(0, zoneState.PhaseEndTime - os.clock())
end

function SafeZoneService.IsShrinking(): boolean
	return zoneState.IsShrinking
end

function SafeZoneService.IsWarning(): boolean
	return zoneState.IsWarning
end

-- ==================== BROADCAST ====================

function SafeZoneService.BroadcastZoneUpdate()
	MatchRemotes.ZoneUpdate:FireAllClients({
		center = zoneState.Center,
		currentRadius = zoneState.CurrentRadius,
		targetRadius = zoneState.NextRadius or zoneState.CurrentRadius,
		phase = zoneState.Phase,
		phaseEndTime = zoneState.PhaseEndTime,
		isShrinking = zoneState.IsShrinking,
		isWarning = zoneState.IsWarning,
		nextCenter = zoneState.NextCenter,
		nextRadius = zoneState.NextRadius,
		timestamp = os.clock(),
	})
end

-- ==================== LIFECYCLE ====================

function SafeZoneService.Start()
	if not isActive then
		SafeZoneService.Initialize()
	end
	SafeZoneService.StartPhase(1)
end

function SafeZoneService.Stop()
	isActive = false
	if shrinkTween then
		shrinkTween:Cancel()
		shrinkTween = nil
	end
	if zonePart then
		zonePart:Destroy()
		zonePart = nil
	end
	print("[SafeZoneService] Stopped")
end

function SafeZoneService.Reset()
	SafeZoneService.Stop()
	zoneState.Phase = 0
	zoneState.CurrentRadius = Constants.INITIAL_ZONE_RADIUS
	zoneState.TargetRadius = Constants.INITIAL_ZONE_RADIUS
	zoneState.IsShrinking = false
	zoneState.IsWarning = false
	zoneState.NextCenter = nil
	zoneState.NextRadius = nil
end

return SafeZoneService
