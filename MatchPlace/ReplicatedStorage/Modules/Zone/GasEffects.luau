--[[
	GasEffects - Toxic gas particle effects, screen fog/color correction when outside zone, damage vignette
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local GasEffects = {}

export type GasEffectState = {
	isInGas: boolean,
	intensity: number, -- 0-1
	damagePerTick: number,
	tickInterval: number,
	lastTickTime: number,
}

export type GasVisuals = {
	fogEffect: Atmosphere?,
	colorCorrection: ColorCorrectionEffect?,
	vignette: ImageLabel?,
	particleAttachment: Attachment?,
	gasParticles: ParticleEmitter?,
	isActive: boolean,
}

-- Configuration
local CONFIG = {
	fogDensity = 0.35,
	fogColor = Color3.fromRGB(80, 60, 40),
	fogDecay = Color3.fromRGB(60, 40, 20),
	colorCorrectionTint = Color3.fromRGB(255, 200, 150),
	colorCorrectionSaturation = -0.3,
	colorCorrectionContrast = 0.2,
	vignetteTransparency = 0.5,
	particleRate = 50,
	damageVignettePulse = 0.2,
}

-- State
local gasState: GasEffectState = {
	isInGas = false,
	intensity = 0,
	damagePerTick = 0,
	tickInterval = 1,
	lastTickTime = 0,
}

local visuals: GasVisuals = {
	fogEffect = nil,
	colorCorrection = nil,
	vignette = nil,
	particleAttachment = nil,
	gasParticles = nil,
	isActive = false,
}

local player = Players.LocalPlayer
local character: Model?
local humanoid: Humanoid?
local rootPart: BasePart?

function GasEffects.Initialize(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid") :: Humanoid
	rootPart = char:WaitForChild("HumanoidRootPart") :: BasePart

	-- Create visual effects
	GasEffects.CreateFogEffect()
	GasEffects.CreateColorCorrection()
	GasEffects.CreateVignette()
	GasEffects.CreateGasParticles()

	-- Start update loop
	RunService.Heartbeat:Connect(GasEffects.Update)

	print("[GasEffects] Initialized")
end

function GasEffects.CreateFogEffect()
	-- Create atmosphere for fog
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0
	atmosphere.Offset = 0.25
	atmosphere.Color = CONFIG.fogColor
	atmosphere.Decay = CONFIG.fogDecay
	atmosphere.Glare = 0.5
	atmosphere.Haze = 2
	atmosphere.Parent = Lighting

	visuals.fogEffect = atmosphere
end

function GasEffects.CreateColorCorrection()
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Brightness = 0
	colorCorrection.Contrast = 0
	colorCorrection.Saturation = 0
	colorCorrection.TintColor = Color3.white
	colorCorrection.Enabled = false
	colorCorrection.Parent = Lighting

	visuals.colorCorrection = colorCorrection
end

function GasEffects.CreateVignette()
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GasVignette"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Damage vignette (red edges)
	local vignette = Instance.new("ImageLabel")
	vignette.Name = "DamageVignette"
	vignette.Size = UDim2.new(1, 0, 1, 0)
	vignette.BackgroundTransparency = 1
	vignette.Image = "rbxassetid://0" -- Radial gradient texture
	vignette.ImageColor3 = Color3.fromRGB(255, 50, 50)
	vignette.ImageTransparency = 1
	vignette.ScaleType = Enum.ScaleType.Slice
	vignette.SliceCenter = Rect.new(100, 100, 100, 100)
	vignette.Parent = screenGui

	-- Gas overlay (green/yellow tint)
	local gasOverlay = Instance.new("Frame")
	gasOverlay.Name = "GasOverlay"
	gasOverlay.Size = UDim2.new(1, 0, 1, 0)
	gasOverlay.BackgroundColor3 = Color3.fromRGB(100, 120, 50)
	gasOverlay.BackgroundTransparency = 1
	gasOverlay.BorderSizePixel = 0
	gasOverlay.Parent = screenGui

	visuals.vignette = vignette
end

function GasEffects.CreateGasParticles()
	if not rootPart then return end

	local attachment = Instance.new("Attachment")
	attachment.Name = "GasParticleAttachment"
	attachment.Parent = rootPart

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "GasParticles"
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 140, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 120, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 100, 40)),
	})
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 2),
		NumberSequenceKeypoint.new(1, 4),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0.8),
	})
	particles.Lifetime = NumberRange.new(1, 3)
	particles.Rate = 0
	particles.Speed = NumberRange.new(0.5, 2)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Rotation = NumberRange.new(0, 360)
	particles.RotSpeed = NumberRange.new(-30, 30)
	particles.Parent = attachment

	visuals.particleAttachment = attachment
	visuals.gasParticles = particles
end

function GasEffects.UpdateGasState(isInGas: boolean, intensity: number, damagePerTick: number, tickInterval: number)
	gasState.isInGas = isInGas
	gasState.intensity = math.clamp(intensity, 0, 1)
	gasState.damagePerTick = damagePerTick
	gasState.tickInterval = tickInterval

	-- Update visuals
	GasEffects.UpdateVisuals()
end

function GasEffects.UpdateVisuals()
	local intensity = gasState.intensity

	-- Fog
	if visuals.fogEffect then
		visuals.fogEffect.Density = gasState.isInGas and CONFIG.fogDensity * intensity or 0
	end

	-- Color correction
	if visuals.colorCorrection then
		visuals.colorCorrection.Enabled = gasState.isInGas
		if gasState.isInGas then
			visuals.colorCorrection.TintColor = Util.LerpColor(Color3.white, CONFIG.colorCorrectionTint, intensity)
			visuals.colorCorrection.Saturation = CONFIG.colorCorrectionSaturation * intensity
			visuals.colorCorrection.Contrast = CONFIG.colorCorrectionContrast * intensity
		end
	end

	-- Vignette
	if visuals.vignette then
		local targetTransparency = gasState.isInGas and (1 - CONFIG.vignetteTransparency * intensity) or 1
		visuals.vignette.ImageTransparency = Util.Lerp(
			visuals.vignette.ImageTransparency,
			targetTransparency,
			0.1
		)

		-- Gas overlay
		local gasOverlay = visuals.vignette.Parent:FindFirstChild("GasOverlay")
		if gasOverlay then
			gasOverlay.BackgroundTransparency = gasState.isInGas and (1 - 0.3 * intensity) or 1
		end
	end

	-- Particles
	if visuals.gasParticles then
		visuals.gasParticles.Rate = gasState.isInGas and CONFIG.particleRate * intensity or 0
	end

	visuals.isActive = gasState.isInGas
end

function GasEffects.Update()
	if not gasState.isInGas then return end

	-- Damage tick
	local now = os.clock()
	if now - gasState.lastTickTime >= gasState.tickInterval then
		gasState.lastTickTime = now
		GasEffects.ApplyDamageTick()
	end

	-- Pulse vignette on damage
	if visuals.vignette then
		local pulse = math.sin(now * 5) * CONFIG.damageVignettePulse + (1 - CONFIG.damageVignettePulse)
		local baseTransparency = 1 - CONFIG.vignetteTransparency * gasState.intensity
		visuals.vignette.ImageTransparency = baseTransparency * pulse
	end
end

function GasEffects.ApplyDamageTick()
	if not humanoid or humanoid.Health <= 0 then return end

	-- Apply damage
	humanoid:TakeDamage(gasState.damagePerTick)

	-- Flash vignette
	if visuals.vignette then
		local originalTransparency = visuals.vignette.ImageTransparency
		visuals.vignette.ImageTransparency = 0.3
		task.delay(0.1, function()
			if visuals.vignette then
				visuals.vignette.ImageTransparency = originalTransparency
			end
		end)
	end
end

function GasEffects.IsInGas(): boolean
	return gasState.isInGas
end

function GasEffects.GetIntensity(): number
	return gasState.intensity
end

function GasEffects.GetState(): GasEffectState
	return gasState
end

function GasEffects.SetActive(active: boolean)
	visuals.isActive = active
	if not active then
		-- Reset all effects
		if visuals.fogEffect then
			visuals.fogEffect.Density = 0
		end
		if visuals.colorCorrection then
			visuals.colorCorrection.Enabled = false
		end
		if visuals.vignette then
			visuals.vignette.ImageTransparency = 1
			local gasOverlay = visuals.vignette.Parent:FindFirstChild("GasOverlay")
			if gasOverlay then
				gasOverlay.BackgroundTransparency = 1
			end
		end
		if visuals.gasParticles then
			visuals.gasParticles.Rate = 0
		end
	end
end

function GasEffects.Cleanup()
	if visuals.fogEffect then
		visuals.fogEffect:Destroy()
	end
	if visuals.colorCorrection then
		visuals.colorCorrection:Destroy()
	end
	if visuals.vignette then
		visuals.vignette.Parent:Destroy()
	end
	if visuals.particleAttachment then
		visuals.particleAttachment:Destroy()
	end

	visuals = {
		fogEffect = nil,
		colorCorrection = nil,
		vignette = nil,
		particleAttachment = nil,
		gasParticles = nil,
		isActive = false,
	}

	character = nil
	humanoid = nil
	rootPart = nil
end

return GasEffects
