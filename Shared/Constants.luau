--[[
	Shared Constants - Single source of truth for both Lobby and Match places
]]

local Constants = {}

-- Place IDs (UPDATE THESE WITH YOUR ACTUAL PLACE IDs)
Constants.LOBBY_PLACE_ID = 123456789
Constants.MATCH_PLACE_ID = 987654321

-- Game Configuration
Constants.GAME_NAME = "BattleRoyale"
Constants.VERSION = "0.1.0"
Constants.MAX_PLAYERS_PER_MATCH = 100
Constants.MIN_PLAYERS_TO_START = 50

-- Map Configuration
Constants.MAP_RADIUS = 2500
Constants.MAP_SIZE = Vector3.new(5000, 1000, 5000)
Constants.MAPS = {
	"Erangel_Remastered",
	"Miramar_Remastered", 
	"Sanhok_Remastered",
	"Vikendi_Remastered",
}
Constants.DEFAULT_MAP = "Erangel_Remastered"

-- Safe Zone Configuration
Constants.INITIAL_ZONE_RADIUS = 2000
Constants.FINAL_ZONE_RADIUS = 50
Constants.ZONE_PHASES = {
	{ duration = 180, radius = 1500, damagePerTick = 2, tickInterval = 2, warningTime = 30 },
	{ duration = 150, radius = 1000, damagePerTick = 5, tickInterval = 1.5, warningTime = 30 },
	{ duration = 120, radius = 600, damagePerTick = 10, tickInterval = 1, warningTime = 20 },
	{ duration = 90, radius = 300, damagePerTick = 20, tickInterval = 0.75, warningTime = 15 },
	{ duration = 60, radius = 100, damagePerTick = 35, tickInterval = 0.5, warningTime = 10 },
	{ duration = 30, radius = 50, damagePerTick = 50, tickInterval = 0.3, warningTime = 5 },
}

-- Combat Configuration
Constants.BULLET_SPEED = 800 -- studs/sec
Constants.BULLET_DROP = 0.05 -- gravity multiplier
Constants.MAX_PENETRATION_DEPTH = 2 -- studs
Constants.HEADSHOT_MULTIPLIER = 2.0
Constants.LIMB_MULTIPLIER = 0.7
Constants.BASE_DAMAGE = {
	AR = 35,
	SMG = 25,
	SR = 90,
	DMR = 55,
	SG = 12, -- per pellet
	Pistol = 28,
	Melee = 40,
}

-- Movement Configuration
Constants.WALK_SPEED = 14
Constants.RUN_SPEED = 20
Constants.SPRINT_SPEED = 28
Constants.CROUCH_SPEED = 6
Constants.PRONE_SPEED = 3
Constants.JUMP_POWER = 45
Constants.SLIDE_SPEED = 35
Constants.SLIDE_DURATION = 1.2
Constants.SLIDE_COOLDOWN = 2.5
Constants.VAULT_HEIGHT = 4.5
Constants.VAULT_DURATION = 0.6
Constants.STANCE_TRANSITION_TIME = 0.3

-- Vehicle Configuration
Constants.VEHICLE_SPAWN_CHANCE = 0.3
Constants.MAX_VEHICLES_PER_MATCH = 20
Constants.VEHICLE_HEALTH = {
	UAZ = 1200,
	Buggy = 800,
	Motorcycle = 500,
	Boat = 1000,
	Helicopter = 2000,
}

-- Economy Configuration
Constants.STARTING_CASH = 0
Constants.STARTING_CREDITS = 0
Constants.KILL_REWARD_CASH = 50
Constants.SURVIVAL_REWARD_CASH_PER_MIN = 10
Constants.PLACEMENT_REWARDS = {
	[1] = { cash = 1000, credits = 100, xp = 500 },
	[2] = { cash = 700, credits = 50, xp = 350 },
	[3] = { cash = 500, credits = 30, xp = 250 },
	[4] = { cash = 300, credits = 20, xp = 150 },
	[5] = { cash = 200, credits = 15, xp = 100 },
	[6] = { cash = 150, credits = 10, xp = 75 },
	[7] = { cash = 100, credits = 5, xp = 50 },
	[8] = { cash = 75, credits = 0, xp = 40 },
	[9] = { cash = 50, credits = 0, xp = 30 },
	[10] = { cash = 25, credits = 0, xp = 20 },
}

-- Inventory Configuration
Constants.INVENTORY_SLOTS = 30
Constants.HOTBAR_SLOTS = 5
Constants.MAX_STACK_SIZE = {
	Ammo = 200,
	Med = 5,
	Throw = 3,
	Attachment = 1,
	Consumable = 10,
}

-- Audio Configuration
Constants.AUDIO_ROLLOFF = {
	Footsteps = { min = 10, max = 60 },
	Gunfire = { min = 50, max = 500 },
	Vehicle = { min = 30, max = 300 },
	Explosion = { min = 100, max = 1000 },
	Voice = { min = 5, max = 40 },
}

-- Network Configuration
Constants.REMOTE_TIMEOUT = 5
Constants.STATE_UPDATE_RATE = 1/30 -- 30 Hz
Constants.POSITION_UPDATE_RATE = 1/20 -- 20 Hz

-- DataStore Keys
Constants.DATASTORE_VERSION = "v3"
Constants.PROFILE_KEY_PREFIX = "Profile_"
Constants.MATCH_DATA_KEY = "MatchData_"
Constants.LEADERBOARD_KEY = "Leaderboard_"

-- Anti-Cheat Configuration
Constants.MAX_PING_THRESHOLD = 300
Constants.MAX_POSITION_DELTA = 50 -- studs per frame at 60fps
Constants.MAX_DAMAGE_PER_HIT = 200
Constants.MAX_FIRERATE_DEVIATION = 0.15 -- 15% tolerance

-- UI Configuration
Constants.UI_THEME = {
	Background = Color3.fromRGB(20, 20, 20),
	Surface = Color3.fromRGB(30, 30, 30),
	Primary = Color3.fromRGB(0, 180, 255),
	Secondary = Color3.fromRGB(255, 140, 0),
	Danger = Color3.fromRGB(220, 50, 50),
	Success = Color3.fromRGB(50, 200, 100),
	Text = Color3.fromRGB(240, 240, 240),
	TextMuted = Color3.fromRGB(160, 160, 160),
	Border = Color3.fromRGB(60, 60, 60),
	Overlay = Color3.fromRGB(0, 0, 0, 0.85),
}

-- Keybinds (Default)
Constants.DEFAULT_KEYBINDS = {
	MoveForward = Enum.KeyCode.W,
	MoveBackward = Enum.KeyCode.S,
	MoveLeft = Enum.KeyCode.A,
	MoveRight = Enum.KeyCode.D,
	Jump = Enum.KeyCode.Space,
	Crouch = Enum.KeyCode.C,
	Prone = Enum.KeyCode.Z,
	Sprint = Enum.KeyCode.LeftShift,
	Slide = Enum.KeyCode.LeftControl,
	Interact = Enum.KeyCode.E,
	Reload = Enum.KeyCode.R,
	Fire = Enum.UserInputType.MouseButton1,
	ADS = Enum.UserInputType.MouseButton2,
	Melee = Enum.KeyCode.V,
	Grenade = Enum.KeyCode.G,
	Inventory = Enum.KeyCode.Tab,
	Map = Enum.KeyCode.M,
	Scoreboard = Enum.KeyCode.Tab,
	PushToTalk = Enum.KeyCode.T,
	LeanLeft = Enum.KeyCode.Q,
	LeanRight = Enum.KeyCode.E,
}

return Constants