--[[
	RecoilPattern - Deterministic recoil system per weapon
	Pattern table, shot index lookup, recovery over time, attachment modifiers
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local RecoilPattern = {}

export type RecoilConfig = {
	pattern: { [number]: Vector2 }, -- Shot index -> (vertical, horizontal)
	recoveryRate: number, -- Degrees per second
	recoveryDelay: number, -- Seconds after last shot before recovery starts
	maxRecoil: number, -- Maximum total recoil accumulation
	horizontalDrift: number, -- Random horizontal variance
	verticalDrift: number, -- Random vertical variance
}

export type RecoilState = {
	currentShotIndex: number,
	lastShotTime: number,
	accumulatedRecoil: Vector2,
	targetRecoil: Vector2,
	recoilVelocity: Vector2,
	isRecovering: boolean,
}

-- Default recoil patterns for each weapon class
local DEFAULT_PATTERNS: { [string]: RecoilConfig } = {
	AR = {
		pattern = {
			[1] = Vector2.new(0.8, 0.1),
			[2] = Vector2.new(1.2, -0.15),
			[3] = Vector2.new(1.5, 0.25),
			[4] = Vector2.new(1.7, -0.2),
			[5] = Vector2.new(1.9, 0.15),
			[6] = Vector2.new(2.1, -0.25),
			[7] = Vector2.new(2.2, 0.1),
			[8] = Vector2.new(2.3, -0.15),
			[9] = Vector2.new(2.4, 0.2),
			[10] = Vector2.new(2.5, -0.1),
		},
		recoveryRate = 12,
		recoveryDelay = 0.15,
		maxRecoil = 8,
		horizontalDrift = 0.3,
		verticalDrift = 0.2,
	},
	SMG = {
		pattern = {
			[1] = Vector2.new(0.4, 0.05),
			[2] = Vector2.new(0.7, -0.1),
			[3] = Vector2.new(0.9, 0.1),
			[4] = Vector2.new(1.1, -0.08),
			[5] = Vector2.new(1.2, 0.12),
			[6] = Vector2.new(1.3, -0.1),
			[7] = Vector2.new(1.35, 0.08),
			[8] = Vector2.new(1.4, -0.05),
		},
		recoveryRate = 18,
		recoveryDelay = 0.1,
		maxRecoil = 5,
		horizontalDrift = 0.25,
		verticalDrift = 0.15,
	},
	SR = {
		pattern = {
			[1] = Vector2.new(3.5, 0.5),
		},
		recoveryRate = 4,
		recoveryDelay = 0.5,
		maxRecoil = 6,
		horizontalDrift = 0.4,
		verticalDrift = 0.3,
	},
	DMR = {
		pattern = {
			[1] = Vector2.new(1.8, 0.2),
			[2] = Vector2.new(2.0, -0.15),
			[3] = Vector2.new(2.2, 0.1),
			[4] = Vector2.new(2.4, -0.2),
		},
		recoveryRate = 6,
		recoveryDelay = 0.3,
		maxRecoil = 7,
		horizontalDrift = 0.35,
		verticalDrift = 0.25,
	},
	SG = {
		pattern = {
			[1] = Vector2.new(2.5, 0.4),
		},
		recoveryRate = 5,
		recoveryDelay = 0.4,
		maxRecoil = 5,
		horizontalDrift = 0.5,
		verticalDrift = 0.3,
	},
	Pistol = {
		pattern = {
			[1] = Vector2.new(0.6, 0.1),
			[2] = Vector2.new(0.9, -0.08),
			[3] = Vector2.new(1.1, 0.12),
			[4] = Vector2.new(1.3, -0.1),
		},
		recoveryRate = 15,
		recoveryDelay = 0.12,
		maxRecoil = 4,
		horizontalDrift = 0.2,
		verticalDrift = 0.15,
	},
}

-- Attachment modifiers
local ATTACHMENT_MODIFIERS = {
	Compensator = { vertical = 0.75, horizontal = 0.85 },
	Suppressor = { vertical = 0.9, horizontal = 0.95 },
	FlashHider = { vertical = 0.95, horizontal = 0.9 },
	VerticalGrip = { vertical = 0.7, horizontal = 1.0 },
	AngledGrip = { vertical = 0.85, horizontal = 0.8 },
	HalfGrip = { vertical = 0.8, horizontal = 0.9 },
	TacticalStock = { vertical = 0.9, horizontal = 0.9 },
	FoldingStock = { vertical = 0.95, horizontal = 1.0 },
	HeavyBarrel = { vertical = 1.1, horizontal = 1.05 },
	LightweightBarrel = { vertical = 0.95, horizontal = 0.9 },
}

-- Active recoil states per weapon instance
local weaponStates: { [string]: RecoilState } = {}

function RecoilPattern.InitializeState(weaponId: string, weaponClass: string): RecoilState
	local state: RecoilState = {
		currentShotIndex = 0,
		lastShotTime = 0,
		accumulatedRecoil = Vector2.zero,
		targetRecoil = Vector2.zero,
		recoilVelocity = Vector2.zero,
		isRecovering = false,
	}
	weaponStates[weaponId] = state
	return state
end

function RecoilPattern.GetState(weaponId: string): RecoilState?
	return weaponStates[weaponId]
end

function RecoilPattern.GetRecoilForShot(
	weaponId: string,
	weaponClass: string,
	shotIndex: number,
	attachments: { [string]: string }?
): Vector2
	local config = DEFAULT_PATTERNS[weaponClass] or DEFAULT_PATTERNS.AR
	local state = weaponStates[weaponId]
	
	if not state then
		state = RecoilPattern.InitializeState(weaponId, weaponClass)
	end
	
	-- Get base recoil from pattern
	local baseRecoil = config.pattern[shotIndex]
	if not baseRecoil then
		-- Use last pattern entry with diminishing returns for spray patterns
		local lastIndex = #config.pattern
		local lastRecoil = config.pattern[lastIndex]
		local excess = shotIndex - lastIndex
		baseRecoil = Vector2.new(
			lastRecoil.X * (1 + excess * 0.05),
			lastRecoil.Y * (1 + excess * 0.03)
		)
	end
	
	-- Apply attachment modifiers
	local vModifier = 1.0
	local hModifier = 1.0
	if attachments then
		for slot, attachmentId in pairs(attachments) do
			local mod = ATTACHMENT_MODIFIERS[attachmentId]
			if mod then
				vModifier *= mod.vertical or 1.0
				hModifier *= mod.horizontal or 1.0
			end
		end
	end
	
	-- Apply drift (deterministic based on shot index)
	local hDrift = math.noise(shotIndex * 0.7, 0.3) * config.horizontalDrift
	local vDrift = math.noise(0.2, shotIndex * 0.5) * config.verticalDrift
	
	local finalRecoil = Vector2.new(
		(baseRecoil.X + vDrift) * vModifier,
		(baseRecoil.Y + hDrift) * hModifier
	)
	
	-- Clamp to max recoil
	finalRecoil = Vector2.new(
		math.clamp(finalRecoil.X, -config.maxRecoil, config.maxRecoil),
		math.clamp(finalRecoil.Y, -config.maxRecoil, config.maxRecoil)
	)
	
	return finalRecoil
end

function RecoilPattern.ApplyShot(weaponId: string, weaponClass: string, attachments: { [string]: string }?): Vector2
	local state = weaponStates[weaponId]
	if not state then
		state = RecoilPattern.InitializeState(weaponId, weaponClass)
	end
	
	state.currentShotIndex += 1
	state.lastShotTime = os.clock()
	state.isRecovering = false
	
	local recoil = RecoilPattern.GetRecoilForShot(weaponId, weaponClass, state.currentShotIndex, attachments)
	
	-- Accumulate recoil
	state.accumulatedRecoil += recoil
	state.targetRecoil = state.accumulatedRecoil
	
	-- Clamp accumulated
	local config = DEFAULT_PATTERNS[weaponClass] or DEFAULT_PATTERNS.AR
	state.accumulatedRecoil = Vector2.new(
		math.clamp(state.accumulatedRecoil.X, -config.maxRecoil, config.maxRecoil),
		math.clamp(state.accumulatedRecoil.Y, -config.maxRecoil, config.maxRecoil)
	)
	
	return recoil
end

function RecoilPattern.UpdateRecovery(weaponId: string, weaponClass: string, deltaTime: number): Vector2
	local state = weaponStates[weaponId]
	if not state then return Vector2.zero end
	
	local config = DEFAULT_PATTERNS[weaponClass] or DEFAULT_PATTERNS.AR
	local timeSinceLastShot = os.clock() - state.lastShotTime
	
	-- Start recovery after delay
	if timeSinceLastShot >= config.recoveryDelay then
		state.isRecovering = true
	end
	
	if state.isRecovering then
		-- Smooth recovery towards zero
		local recoveryAmount = config.recoveryRate * deltaTime
		
		-- Recover vertical first, then horizontal
		if math.abs(state.accumulatedRecoil.X) > 0.01 then
			local sign = state.accumulatedRecoil.X > 0 and 1 or -1
			state.accumulatedRecoil = Vector2.new(
				state.accumulatedRecoil.X - sign * math.min(recoveryAmount, math.abs(state.accumulatedRecoil.X)),
				state.accumulatedRecoil.Y
			)
		elseif math.abs(state.accumulatedRecoil.Y) > 0.01 then
			local sign = state.accumulatedRecoil.Y > 0 and 1 or -1
			state.accumulatedRecoil = Vector2.new(
				state.accumulatedRecoil.X,
				state.accumulatedRecoil.Y - sign * math.min(recoveryAmount, math.abs(state.accumulatedRecoil.Y))
			)
		else
			state.accumulatedRecoil = Vector2.zero
			state.isRecovering = false
		end
	end
	
	return state.accumulatedRecoil
end

function RecoilPattern.ResetState(weaponId: string)
	local state = weaponStates[weaponId]
	if state then
		state.currentShotIndex = 0
		state.accumulatedRecoil = Vector2.zero
		state.targetRecoil = Vector2.zero
		state.recoilVelocity = Vector2.zero
		state.isRecovering = false
	end
end

function RecoilPattern.GetPatternLength(weaponClass: string): number
	local config = DEFAULT_PATTERNS[weaponClass] or DEFAULT_PATTERNS.AR
	return #config.pattern
end

function RecoilPattern.GetConfig(weaponClass: string): RecoilConfig
	return DEFAULT_PATTERNS[weaponClass] or DEFAULT_PATTERNS.AR
end

function RecoilPattern.SetCustomPattern(weaponClass: string, config: RecoilConfig)
	DEFAULT_PATTERNS[weaponClass] = config
end

function RecoilPattern.Cleanup(weaponId: string)
	weaponStates[weaponId] = nil
end

return RecoilPattern
