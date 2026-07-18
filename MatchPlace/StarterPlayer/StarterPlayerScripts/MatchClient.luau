--[[
	MatchClient - Main client entry point for Match Place
	Initializes all client systems and handles replication
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

-- Client modules
local OTSCamera = require(script.Camera.OTSCamera)
local MovementController = require(script.MovementController)
local WeaponController = require(script.WeaponController)
local VehicleController = require(script.VehicleController)
local InventoryController = require(script.InventoryController)
local ZoneClient = require(script.ZoneClient)
local AudioController = require(script.AudioController)
local HUD = require(script.UI.HUD)
local LoadingScreen = require(script.UI.LoadingScreen)
local StanceSystem = require(script.Movement.StanceSystem)
local VaultingSystem = require(script.Movement.Vaulting)
local SlideSystem = require(script.Movement.SlideSystem)

local MatchClient = {}

local LocalPlayer = Players.LocalPlayer
local character: Model?
local humanoid: Humanoid?
local rootPart: BasePart?
local camera: Camera?

local isInitialized = false
local connections: { RBXScriptConnection } = {}

function MatchClient.Initialize()
	if isInitialized then return end
	
	print("[MatchClient] Initializing...")
	
	-- Wait for character
	character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	camera = Workspace.CurrentCamera
	
	-- Show loading screen
	LoadingScreen.Show()
	LoadingScreen.UpdateProgress(0.1, "INITIALIZING SYSTEMS...")
	
	-- Initialize camera
	OTSCamera.Initialize(character)
	LoadingScreen.UpdateProgress(0.2, "CAMERA READY")
	
	-- Initialize movement systems
	MovementController.Initialize(character)
	LoadingScreen.UpdateProgress(0.3, "MOVEMENT READY")
	
	StanceSystem.Initialize(character)
	LoadingScreen.UpdateProgress(0.35, "STANCE SYSTEM READY")
	
	VaultingSystem.Initialize(character)
	LoadingScreen.UpdateProgress(0.4, "VAULTING READY")
	
	SlideSystem.Initialize(character)
	LoadingScreen.UpdateProgress(0.45, "SLIDING READY")
	
	-- Initialize weapon system
	WeaponController.Initialize(character)
	LoadingScreen.UpdateProgress(0.5, "WEAPONS READY")
	
	-- Initialize vehicle system
	VehicleController.Initialize(character)
	LoadingScreen.UpdateProgress(0.55, "VEHICLES READY")
	
	-- Initialize inventory
	InventoryController.Initialize(character)
	LoadingScreen.UpdateProgress(0.6, "INVENTORY READY")
	
	-- Initialize zone client
	ZoneClient.Initialize(character)
	LoadingScreen.UpdateProgress(0.65, "ZONE SYSTEM READY")
	
	-- Initialize audio
	AudioController.Initialize(character)
	LoadingScreen.UpdateProgress(0.7, "AUDIO READY")
	
	-- Initialize HUD
	HUD.Initialize()
	LoadingScreen.UpdateProgress(0.8, "HUD READY")
	
	-- Preload assets
	LoadingScreen.UpdateProgress(0.9, "PRELOADING ASSETS...")
	LoadingScreen.PreloadGameAssets()
	
	-- Setup replication handlers
	MatchClient.SetupReplication()
	LoadingScreen.UpdateProgress(0.95, "CONNECTING...")
	
	-- Character respawn handling
	table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(newChar)
		MatchClient.OnCharacterAdded(newChar)
	end))
	
	table.insert(connections, humanoid.Died:Connect(function()
		MatchClient.OnDeath()
	end))
	
	-- Input handling
	MatchClient.SetupInput()
	
	isInitialized = true
	LoadingScreen.UpdateProgress(1, "READY")
	
	-- Hide loading screen after brief delay
	task.delay(0.5, function()
		LoadingScreen.Hide()
	end)
	
	print("[MatchClient] Initialized successfully")
end

function MatchClient.OnCharacterAdded(newChar: Model)
	character = newChar
	humanoid = newChar:WaitForChild("Humanoid")
	rootPart = newChar:WaitForChild("HumanoidRootPart")
	
	-- Reinitialize systems
	OTSCamera.Initialize(newChar)
	MovementController.Initialize(newChar)
	StanceSystem.Initialize(newChar)
	VaultingSystem.Initialize(newChar)
	SlideSystem.Initialize(newChar)
	WeaponController.Initialize(newChar)
	VehicleController.Initialize(newChar)
	InventoryController.Initialize(newChar)
	ZoneClient.Initialize(newChar)
	AudioController.Initialize(newChar)
	
	-- Rebind death
	table.insert(connections, humanoid.Died:Connect(function()
		MatchClient.OnDeath()
	end))
	
	HUD.SetWeaponVisible(true)
end

function MatchClient.OnDeath()
	HUD.SetWeaponVisible(false)
	
	-- Start spectating
	ReplicatedStorage.Remotes.MatchRemotes.RequestSpectate:InvokeServer()
end

function MatchClient.SetupInput()
	-- Stance keys
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Constants.DEFAULT_KEYBINDS.Crouch then
			MatchClient.ToggleCrouch()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINBS.Prone then
			MatchClient.ToggleProne()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Sprint then
			MovementController.SetSprinting(true)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Slide then
			SlideSystem.StartSlide()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Interact then
			MatchClient.TryInteract()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Reload then
			WeaponController.Reload()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Melee then
			WeaponController.Melee()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Grenade then
			WeaponController.ThrowGrenade()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Inventory then
			InventoryController.Toggle()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.Map then
			HUD.ToggleMap()
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.LeanLeft then
			OTSCamera.SetLeanTarget(-1)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.LeanRight then
			OTSCamera.SetLeanTarget(1)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Constants.DEFAULT_KEYBINDS.Sprint then
			MovementController.SetSprinting(false)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.LeanLeft then
			OTSCamera.SetLeanTarget(0)
		elseif input.KeyCode == Constants.DEFAULT_KEYBINDS.LeanRight then
			OTSCamera.SetLeanTarget(0)
		end
	end)
	
	-- Mouse buttons
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			WeaponController.StartFiring()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			WeaponController.SetADS(true)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			WeaponController.StopFiring()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			WeaponController.SetADS(false)
		end
	end)
	
	-- Scroll wheel for weapon switch
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			if input.Position.Z > 0 then
				WeaponController.SwitchWeapon(1)
			else
				WeaponController.SwitchWeapon(-1)
			end
		end
	end)
end

function MatchClient.ToggleCrouch()
	local currentStance = character:GetAttribute("Stance") or "Stand"
	if currentStance == "Crouch" then
		StanceSystem.SetStance("Stand")
	else
		StanceSystem.SetStance("Crouch")
	end
end

function MatchClient.ToggleProne()
	local currentStance = character:GetAttribute("Stance") or "Stand"
	if currentStance == "Prone" then
		StanceSystem.SetStance("Stand")
	else
		StanceSystem.SetStance("Prone")
	end
end

function MatchClient.TryInteract()
	-- Raycast for interactable
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local result = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 5, raycastParams)
	if result and result.Instance:GetAttribute("Interactable") then
		ReplicatedStorage.Remotes.MatchRemotes.Interact:InvokeServer(result.Instance)
	end
end

function MatchClient.SetupReplication()
	-- Zone updates
	ReplicatedStorage.Remotes.MatchRemotes.ZoneUpdate.OnClientEvent:Connect(function(data)
		ZoneClient.OnZoneUpdate(data)
	end)
	
	ReplicatedStorage.Remotes.MatchRemotes.GasEffect.OnClientEvent:Connect(function(intensity, damagePerTick)
		ZoneClient.OnGasEffect(intensity, damagePerTick)
	end)
	
	-- Weapon replication
	ReplicatedStorage.Remotes.MatchRemotes.WeaponFire.OnClientEvent:Connect(function(data)
		WeaponController.OnWeaponFired(data)
	end)
	
	-- Movement replication
	ReplicatedStorage.Remotes.MatchRemotes.MovementUpdate.OnClientEvent:Connect(function(player, data)
		MovementController.OnRemoteMovementUpdate(player, data)
	end)
	
	-- Vehicle replication
	ReplicatedStorage.Remotes.MatchRemotes.VehicleUpdate.OnClientEvent:Connect(function(data)
		VehicleController.OnVehicleUpdate(data)
	end)
	
	ReplicatedStorage.Remotes.MatchRemotes.VehicleEnter.OnClientEvent:Connect(function(data)
		VehicleController.OnVehicleEnter(data)
	end)
	
	-- Inventory replication
	ReplicatedStorage.Remotes.MatchRemotes.InventoryUpdate.OnClientEvent:Connect(function(data)
		InventoryController.OnInventoryUpdate(data)
	end)
	
	ReplicatedStorage.Remotes.MatchRemotes.GroundLootUpdate.OnClientEvent:Connect(function(data)
		InventoryController.OnGroundLootUpdate(data)
	end)
	
	-- Match flow
	ReplicatedStorage.Remotes.MatchRemotes.MatchStart.OnClientEvent:Connect(function(data)
		MatchClient.OnMatchStart(data)
	end)
	
	ReplicatedStorage.Remotes.MatchRemotes.MatchEnd.OnClientEvent:Connect(function(data)
		MatchClient.OnMatchEnd(data)
	end)
	
	ReplicatedStorage.Remotes.MatchRemotes.PlayerEliminated.OnClientEvent:Connect(function(data)
		HUD.AddKillFeed(data.killer, data.victim, data.weapon, data.isHeadshot, data.distance)
	end)
	
	-- Hit markers
	ReplicatedStorage.Remotes.MatchRemotes.HitMarker.OnClientEvent:Connect(function(data)
		HUD.ShowDamageIndicator(data.direction, data.damage, data.isHeadshot)
	end)
	
	-- Kill confirmed
	ReplicatedStorage.Remotes.MatchRemotes.KillConfirmed.OnClientEvent:Connect(function(data)
		HUD.ShowKillConfirmed(data)
	end)
	
	-- Plane updates
	ReplicatedStorage.Remotes.MatchRemotes.PlaneStart.OnClientEvent:Connect(function(data)
		MatchClient.OnPlaneStart(data)
	end)
	
	ReplicatedStorage.Remotes.MatchRemotes.PlaneUpdate.OnClientEvent:Connect(function(data)
		MatchClient.OnPlaneUpdate(data)
	end)
	
	-- Parachute
	ReplicatedStorage.Remotes.MatchRemotes.ParachuteDeploy.OnClientEvent:Connect(function(data)
		MovementController.DeployParachute()
	end)
	
	-- UI updates
	ReplicatedStorage.Remotes.MatchRemotes.HudUpdate.OnClientEvent:Connect(function(data)
		HUD.OnHudUpdate(data)
	end)
	
	ReplicatedStorage.Remotes.MatchRemotes.MinimapUpdate.OnClientEvent:Connect(function(data)
		HUD.UpdateMinimap(data.playerPos, data.zoneCenter, data.zoneRadius, data.nextZoneCenter, data.nextZoneRadius)
	end)
	
	ReplicatedStorage.Remotes.MatchRemotes.CompassUpdate.OnClientEvent:Connect(function(data)
		HUD.UpdateCompass(data.yaw)
	end)
	
	-- Voice proximity
	ReplicatedStorage.Remotes.MatchRemotes.VoiceProximity.OnClientEvent:Connect(function(data)
		AudioController.UpdateVoiceProximity(data)
	end)
	
	-- Ping
	ReplicatedStorage.Remotes.MatchRemotes.PingLocation.OnClientEvent:Connect(function(data)
		HUD.AddPing(data.position, data.player)
	end)
end

function MatchClient.OnMatchStart(data)
	print("[MatchClient] Match started on map:", data.map)
	
	-- Initialize match-specific systems
	MovementController.SetParachuting(true)
	
	-- Show map name
	HUD.ShowNotification("MAP: " .. data.map:upper(), 5)
end

function MatchClient.OnMatchEnd(data)
	print("[MatchClient] Match ended")
	
	MovementController.SetParachuting(false)
	
	-- Show results
	if data.winners then
		for _, winner in ipairs(data.winners) do
			HUD.ShowNotification("WINNER: " .. winner, 10)
		end
	end
end

function MatchClient.OnPlaneStart(data)
	-- Show plane path on minimap
	HUD.ShowPlanePath(data.path)
end

function MatchClient.OnPlaneUpdate(data)
	-- Update plane position
	HUD.UpdatePlanePosition(data.position, data.progress)
end

function MatchClient.Cleanup()
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	table.clear(connections)
	
	OTSCamera.Cleanup()
	MovementController.Cleanup()
	WeaponController.Cleanup()
	VehicleController.Cleanup()
	InventoryController.Cleanup()
	ZoneClient.Cleanup()
	AudioController.Cleanup()
	HUD.Cleanup()
	
	isInitialized = false
end

-- Initialize when character loads
if LocalPlayer.Character then
	MatchClient.Initialize()
else
	LocalPlayer.CharacterAdded:Once(MatchClient.Initialize)
end

return MatchClient