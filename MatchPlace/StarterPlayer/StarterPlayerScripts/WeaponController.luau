--[[
	WeaponController - Client weapon handling: fire, ADS, reload, switch, effects, hit feedback
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local ItemDefinitions = require(ReplicatedStorage.Modules.Inventory.ItemDefinitions)
local CameraController = require(script.Parent.CameraController)
local HUD = require(script.Parent.UI.HUD)

local WeaponController = {}

local LocalPlayer = Players.LocalPlayer
local character: Model?
local humanoid: Humanoid?
local rootPart: BasePart?

-- Weapon state
local equippedWeaponId: string?
local weaponTemplate: any?
local currentAmmo = 0
local reserveAmmo = 0
local isReloading = false
local isFiring = false
local lastFireTime = 0
local shotIndex = 0
local fireSeed = tostring(math.random(1000000))

-- Effects
local muzzleFlashLight: PointLight?
local fireSound: Sound?
local reloadSound: Sound?

function WeaponController.Initialize(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")

	WeaponController.SetupInput()
	WeaponController.SetupReplication()

	print("[WeaponController] Initialized")
end

function WeaponController.SetupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Constants.DEFAULT_KEYBINDS.Fire then
			WeaponController.StartFiring()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Reload then
			WeaponController.Reload()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Melee then
			WeaponController.Melee()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Grenade then
			WeaponController.ThrowGrenade()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Constants.DEFAULT_KEYBINDS.Fire then
			WeaponController.StopFiring()
		end
	end)

	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			WeaponController.SwitchWeapon(input.Position.Z > 0 and 1 or -1)
		end
	end)
end

function WeaponController.SetupReplication()
	ReplicatedStorage.Remotes.MatchRemotes.WeaponFire.OnClientEvent:Connect(function(data)
		if data.dryFire then
			WeaponController.PlayDryFire()
			return
		end
		if data.shooter == LocalPlayer then return end -- Local prediction handles own shots
		WeaponController.PlayRemoteFireEffect(data)
	end)

	ReplicatedStorage.Remotes.MatchRemotes.WeaponReload.OnClientEvent:Connect(function(data)
		if data.weaponId == equippedWeaponId then
			currentAmmo = data.currentAmmo
			reserveAmmo = data.reserveAmmo
			HUD.UpdateAmmo(currentAmmo, reserveAmmo)
		end
	end)

	ReplicatedStorage.Remotes.MatchRemotes.WeaponSwitch.OnClientEvent:Connect(function(data)
		if data.success then
			WeaponController.OnWeaponEquipped(data.weaponId)
		end
	end)

	ReplicatedStorage.Remotes.MatchRemotes.HitMarker.OnClientEvent:Connect(function(data)
		HUD.ShowDamageIndicator(data.direction or 0, data.damage, data.isHeadshot)
		if data.isKill then
			-- Play kill confirm sound / effect
		end
	end)

	ReplicatedStorage.Remotes.MatchRemotes.DamageIndicator.OnClientEvent:Connect(function(data)
		HUD.ShowDamageIndicator(data.direction, data.damage, data.isHeadshot)
	end)
end

function WeaponController.EquipWeapon(weaponId: string)
	if equippedWeaponId == weaponId then return end

	local template = ItemDefinitions.GetWeaponTemplate(weaponId)
	if not template then return end

	-- Unequip previous
	if equippedWeaponId then
		ReplicatedStorage.Remotes.MatchRemotes.WeaponSwitch:FireServer({
			weaponId = weaponId,
			fromId = equippedWeaponId,
		})
	else
		ReplicatedStorage.Remotes.MatchRemotes.WeaponSwitch:FireServer({
			weaponId = weaponId,
		})
	end
end

function WeaponController.OnWeaponEquipped(weaponId: string)
	equippedWeaponId = weaponId
	weaponTemplate = ItemDefinitions.GetWeaponTemplate(weaponId)

	if weaponTemplate then
		currentAmmo = weaponTemplate.Stats.MagSize
		reserveAmmo = weaponTemplate.Stats.MagSize * 3 -- Default; server will correct
		HUD.UpdateWeapon(weaponTemplate.Name, "AUTO")
		HUD.UpdateAmmo(currentAmmo, reserveAmmo)
		HUD.SetWeaponVisible(true)
	end

	character:SetAttribute("EquippedWeapon", weaponId)
end

function WeaponController.StartFiring()
	if not equippedWeaponId or not weaponTemplate then return end
	if isReloading then return end
	if currentAmmo <= 0 then
		WeaponController.PlayDryFire()
		return
	end

	isFiring = true
	WeaponController.FireLoop()
end

function WeaponController.StopFiring()
	isFiring = false
end

function WeaponController.FireLoop()
	if not isFiring or not equippedWeaponId or not weaponTemplate then return end

	local fireRate = weaponTemplate.Stats.FireRate
	local interval = 60 / fireRate

	local now = os.clock()
	if now - lastFireTime < interval then
		RunService.Heartbeat:Wait()
		WeaponController.FireLoop()
		return
	end

	lastFireTime = now
	shotIndex += 1

	-- Build payload
	local camera = Workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector

	-- Apply spread
	local spread = weaponTemplate.Stats.Spread
	if CameraController.GetADSState() then
		spread = weaponTemplate.Stats.SpreadADS
	end
	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		spread = weaponTemplate.Stats.SpreadMove
	end

	local spreadRad = math.rad(spread)
	local spreadX = (math.random() - 0.5) * spreadRad
	local spreadY = (math.random() - 0.5) * spreadRad
	direction = (CFrame.lookAt(origin, origin + direction) * CFrame.Angles(spreadY, spreadX, 0)).LookVector

	local payload = {
		WeaponId = equippedWeaponId,
		Origin = origin,
		Direction = direction,
		Timestamp = now,
		ShotIndex = shotIndex,
		Seed = fireSeed,
	}

	-- Send to server
	ReplicatedStorage.Remotes.MatchRemotes.WeaponFire:FireServer(payload)

	-- Local prediction: raycast for immediate feedback
	WeaponController.PredictHit(origin, direction, payload)

	-- Consume ammo locally (server reconciles)
	currentAmmo = math.max(0, currentAmmo - 1)
	HUD.UpdateAmmo(currentAmmo, reserveAmmo)

	-- Play local effects
	WeaponController.PlayFireEffects()

	-- Apply recoil
	local recoil = weaponTemplate.Stats.RecoilPattern[math.min(shotIndex, #weaponTemplate.Stats.RecoilPattern)] or Vector2.new(1, 0)
	CameraController.AddRecoil(recoil.X * 0.02, recoil.Y * 0.02)

	-- Continue loop if automatic
	if isFiring and weaponTemplate.Class ~= "SR" and weaponTemplate.Class ~= "Pistol" then
		task.delay(interval, WeaponController.FireLoop)
	end
end

function WeaponController.PredictHit(origin: Vector3, direction: Vector3, payload: any)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local maxRange = weaponTemplate.Stats.Range
	local result = Workspace:Raycast(origin, direction * maxRange, raycastParams)

	if result then
		-- Show local impact effect
		WeaponController.PlayImpactEffect(result.Position, result.Normal, result.Material)

		-- If hit player, report to server
		local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
		if hitModel and hitModel:FindFirstChild("Humanoid") then
			local targetPlayer = Players:GetPlayerFromCharacter(hitModel)
			if targetPlayer and targetPlayer ~= LocalPlayer then
				local isHeadshot = result.Instance.Name == "Head"
				local damage = weaponTemplate.Stats.Damage
				if isHeadshot then
					damage *= Constants.HEADSHOT_MULTIPLIER
				end

				ReplicatedStorage.Remotes.MatchRemotes.WeaponHit:FireServer({
					WeaponId = payload.WeaponId,
					Target = targetPlayer,
					HitPosition = result.Position,
					HitNormal = result.Normal,
					HitMaterial = result.Material,
					ShotIndex = payload.ShotIndex,
					Timestamp = payload.Timestamp,
					Damage = damage,
					IsHeadshot = isHeadshot,
					Penetrated = false,
				})
			end
		end
	end
end

function WeaponController.Reload()
	if not equippedWeaponId or not weaponTemplate then return end
	if isReloading then return end
	if currentAmmo >= weaponTemplate.Stats.MagSize then return end
	if reserveAmmo <= 0 then return end

	isReloading = true
	HUD.ShowNotification("RELOADING...", 1)

	local isTactical = currentAmmo > 0
	local reloadTime = isTactical and weaponTemplate.Stats.TacticalReloadTime or weaponTemplate.Stats.ReloadTime

	ReplicatedStorage.Remotes.MatchRemotes.WeaponReload:FireServer({
		weaponId = equippedWeaponId,
		isTactical = isTactical,
	})

	-- Play reload sound
	if reloadSound then
		reloadSound:Play()
	end

	task.delay(reloadTime, function()
		isReloading = false
		-- Server will send updated ammo via WeaponReload remote
	end)
end

function WeaponController.SwitchWeapon(direction: number)
	-- Cycle through hotbar weapons (1-5)
	-- This requires inventory hotbar data; stub for now
	local hotbar = { "AK74", "M416", "Pistol" } -- Placeholder
	if #hotbar == 0 then return end

	local currentIndex = table.find(hotbar, equippedWeaponId) or 1
	local newIndex = ((currentIndex - 1 + direction) % #hotbar) + 1
	WeaponController.EquipWeapon(hotbar[newIndex])
end

function WeaponController.Melee()
	ReplicatedStorage.Remotes.MatchRemotes.MeleeAttack:FireServer({
		timestamp = os.clock(),
	})
	-- Play melee animation / sound
end

function WeaponController.ThrowGrenade()
	ReplicatedStorage.Remotes.MatchRemotes.ThrowProjectile:FireServer({
		timestamp = os.clock(),
	})
end

function WeaponController.PlayFireEffects()
	-- Muzzle flash
	if not muzzleFlashLight then
		muzzleFlashLight = Instance.new("PointLight")
		muzzleFlashLight.Color = Color3.fromRGB(255, 200, 100)
		muzzleFlashLight.Range = 8
		muzzleFlashLight.Brightness = 2
		muzzleFlashLight.Parent = Workspace.CurrentCamera
	end

	muzzleFlashLight.Enabled = true
	task.delay(0.05, function()
		if muzzleFlashLight then
			muzzleFlashLight.Enabled = false
		end
	end)

	-- Fire sound
	if fireSound then
		fireSound:Play()
	end

	-- Shell eject, tracer, etc. would go here
end

function WeaponController.PlayRemoteFireEffect(data)
	-- Play effect for other players' shots
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://0" -- Weapon fire sound
	sound.Volume = 0.5
	sound.EmitterSize = 10
	sound.MaxDistance = Constants.AUDIO_ROLLOFF.Gunfire.max
	sound.Parent = Workspace
	sound:Play()
	Debris:AddItem(sound, 2)
end

function WeaponController.PlayImpactEffect(position: Vector3, normal: Vector3, material: Enum.Material)
	-- Impact particles / decal
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position + normal * 0.1
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://0" -- Impact sound
	sound.Volume = 0.3
	sound.Parent = part
	sound:Play()

	Debris:AddItem(part, 1)
end

function WeaponController.PlayDryFire()
	-- Click sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://0"
	sound.Volume = 0.5
	sound.Parent = Workspace.CurrentCamera
	sound:Play()
	Debris:AddItem(sound, 1)
end

function WeaponController.SetADS(active: boolean)
	CameraController.SetADS(active)
end

function WeaponController.OnWeaponFired(data)
	-- Called by replication for remote shots
end

function WeaponController.Cleanup()
	isFiring = false
end

return WeaponController
