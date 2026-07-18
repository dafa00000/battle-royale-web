--[[
	Bootstrap Script - Run this in Roblox Studio Command Bar to initialize the project
	
	USAGE:
	1. Open Roblox Studio
	2. Create a new place for Lobby and a new place for Match
	3. In each place, run the corresponding bootstrap in Command Bar
	4. Install Rojo VS Code extension and connect to serve ports
]]

local Bootstrap = {}

function Bootstrap.SetupLobbyPlace()
	-- This would be run in the Lobby place
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StarterPlayer = game:GetService("StarterPlayer")
	local StarterGui = game:GetService("StarterGui")
	
	-- Create folder structure
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = ServerScriptService
	
	local data = Instance.new("Folder")
	data.Name = "Data"
	data.Parent = ServerScriptService
	
	local shared = Instance.new("Folder")
	shared.Name = "Shared"
	shared.Parent = ReplicatedStorage
	
	local remotes = Instance.new("Folder")
	remotes.Name = "LobbyRemotes"
	remotes.Parent = ReplicatedStorage
	
	-- Create RemoteFunctions
	local functions = {
		"JoinQueue", "LeaveQueue", "JoinSquad", "LeaveSquad",
		"InviteToSquad", "KickFromSquad", "ReadyUp", "SelectMap",
		"UpdateLoadout", "PurchaseItem", "EquipSkin", "GetPlayerProfile",
		"GetLeaderboard"
	}
	
	for _, name in ipairs(functions) do
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = remotes
	end
	
	-- Create RemoteEvents
	local events = {
		"QueueUpdate", "SquadUpdate", "SquadInvite", "MatchFound",
		"LoadoutUpdate", "CurrencyUpdate", "InventoryUpdate",
		"SkinUpdate", "Notification", "SettingsUpdate"
	}
	
	for _, name in ipairs(events) do
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = remotes
	end
	
	-- Client events
	local clientEvents = { "RequestQueueStatus", "RequestSquadInfo", "RequestShopData", "ChatMessage" }
	for _, name in ipairs(clientEvents) do
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = remotes
	end
	
	print("[Bootstrap] Lobby place structure created")
	return true
end

function Bootstrap.SetupMatchPlace()
	-- This would be run in the Match place
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StarterPlayer = game:GetService("StarterPlayer")
	local StarterGui = game:GetService("StarterGui")
	
	-- Create folder structure
	local match = Instance.new("Folder")
	match.Name = "Match"
	match.Parent = ServerScriptService
	
	local combat = Instance.new("Folder")
	combat.Name = "Combat"
	combat.Parent = ServerScriptService
	
	local movement = Instance.new("Folder")
	movement.Name = "Movement"
	movement.Parent = ServerScriptService
	
	local vehicle = Instance.new("Folder")
	vehicle.Name = "Vehicle"
	vehicle.Parent = ServerScriptService
	
	local inventory = Instance.new("Folder")
	inventory.Name = "Inventory"
	inventory.Parent = ServerScriptService
	
	local data = Instance.new("Folder")
	data.Name = "Data"
	data.Parent = ServerScriptService
	
	-- Shared modules
	local shared = Instance.new("Folder")
	shared.Name = "Shared"
	shared.Parent = ReplicatedStorage
	
	local modules = Instance.new("Folder")
	modules.Name = "Modules"
	modules.Parent = ReplicatedStorage
	
	-- Module subfolders
	local moduleNames = {
		"WeaponSystem", "Movement", "Vehicle", "Inventory", "Zone",
		"Audio", "Camera", "UI"
	}
	
	for _, name in ipairs(moduleNames) do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = modules
	end
	
	-- Remotes
	local remotes = Instance.new("Folder")
	remotes.Name = "MatchRemotes"
	remotes.Parent = ReplicatedStorage
	
	-- All the match remotes (combat, movement, zone, vehicle, inventory, etc.)
	-- See MatchRemotes.luau for full list
	
	print("[Bootstrap] Match place structure created")
	return true
end

function Bootstrap.InstallPackages()
	-- Run in terminal: wally install
	-- This creates SharedPackages folder with all dependencies
	print("Run 'wally install' in project root to install packages")
end

function Bootstrap.SetupLighting()
	local Lighting = game:GetService("Lighting")
	
	Lighting.Technology = Enum.Technology.Future
	Lighting.Ambient = Color3.fromRGB(20, 20, 30)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 40, 55)
	Lighting.ExposureCompensation = -0.5
	Lighting.Brightness = 1.2
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 45
	
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.15
	cc.Saturation = -0.2
	cc.TintColor = Color3.fromRGB(255, 245, 230)
	cc.Parent = Lighting
	
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.15
	sunRays.Spread = 0.8
	sunRays.Parent = Lighting
	
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.15
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(180, 190, 210)
	atmosphere.Decay = Color3.fromRGB(100, 110, 130)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.5
	atmosphere.Parent = Lighting
	
	print("[Bootstrap] Lighting configured for Resident Evil / GTA V style")
end

function Bootstrap.SetupCollisionGroups()
	local PhysicsService = game:GetService("PhysicsService")
	
	PhysicsService:RegisterCollisionGroup("Vehicles")
	PhysicsService:RegisterCollisionGroup("VehicleWheels")
	PhysicsService:RegisterCollisionGroup("Characters")
	PhysicsService:RegisterCollisionGroup("Projectiles")
	PhysicsService:RegisterCollisionGroup("Environment")
	PhysicsService:RegisterCollisionGroup("Loot")
	
	PhysicsService:CollisionGroupSetCollidable("Vehicles", "VehicleWheels", false)
	PhysicsService:CollisionGroupSetCollidable("Characters", "Projectiles", false)
	PhysicsService:CollisionGroupSetCollidable("Vehicles", "Characters", true)
	PhysicsService:CollisionGroupSetCollidable("Vehicles", "Environment", true)
	PhysicsService:CollisionGroupSetCollidable("Projectiles", "Environment", true)
	
	print("[Bootstrap] Collision groups configured")
end

function Bootstrap.CreateAssetStructure()
	-- Create ReplicatedStorage asset folders
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local assets = Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
	
	local assetFolders = { "Weapons", "Vehicles", "Characters", "Effects", "UI", "Sounds" }
	for _, name in ipairs(assetFolders) do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = assets
	end
	
	print("[Bootstrap] Asset folders created")
end

-- Auto-run setup
Bootstrap.SetupLobbyPlace()
Bootstrap.SetupMatchPlace()
Bootstrap.SetupLighting()
Bootstrap.SetupCollisionGroups()
Bootstrap.CreateAssetStructure()

print("[Bootstrap] Complete! Next steps:")
print("1. Run 'wally install' in project root")
print("2. Open Rojo in VS Code and connect to ports 34872 (Lobby) and 34873 (Match)")
print("3. Sync files from filesystem to Studio")
print("4. Configure Place IDs in Shared/Constants.luau")
print("5. Add weapon models, vehicle models, map assets to ReplicatedStorage/Assets")

return Bootstrap