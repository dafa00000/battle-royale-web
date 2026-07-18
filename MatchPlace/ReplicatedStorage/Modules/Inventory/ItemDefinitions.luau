--[[
	ItemDefinitions - All item templates for weapons, attachments, consumables, etc.
]]

local ItemDefinitions = {}

export type WeaponTemplate = {
	Id: string,
	Name: string,
	Class: "AR" | "SMG" | "SR" | "DMR" | "SG" | "Pistol" | "Melee" | "Throw",
	Model: string,
	ViewModel: string,
	Icon: string,
	Stats: WeaponStats,
	Attachments: { [string]: { string } },
	DefaultAttachments: { [string]: string }?,
	Animations: { [string]: string },
	Sounds: { [string]: string },
	Rarity: "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic",
	Price: { Cash: number, Credits: number },
}

export type WeaponStats = {
	Damage: number,
	FireRate: number,
	MuzzleVelocity: number,
	Range: number,
	RecoilPattern: { [number]: Vector2 },
	RecoilRecovery: number,
	Spread: number,
	SpreadADS: number,
	SpreadMove: number,
	SpreadJump: number,
	ReloadTime: number,
	TacticalReloadTime: number,
	MagSize: number,
	AmmoType: string,
	Weight: number,
	AdsTime: number,
	Sway: number,
	Penetration: number,
	BulletDrop: number,
}

export type AttachmentTemplate = {
	Id: string,
	Name: string,
	Category: "Optic" | "Muzzle" | "Barrel" | "Underbarrel" | "Magazine" | "Stock" | "Grip" | "Laser",
	CompatibleWeapons: { string },
	Stats: {
		RecoilControl: number?,
		RecoilHorizontal: number?,
		Ergonomics: number?,
		AdsSpeed: number?,
		SwayReduction: number?,
		HipFireSpread: number?,
		MuzzleVelocity: number?,
		MagSize: number?,
		ReloadSpeed: number?,
		SoundSuppression: number?,
		FlashHider: boolean?,
	},
	Model: string,
	Icon: string,
	Rarity: string,
	Price: { Cash: number, Credits: number }?,
}

export type ConsumableTemplate = {
	Id: string,
	Name: string,
	Category: "Med" | "Boost" | "Throw" | "Utility",
	Description: string,
	Model: string,
	Icon: string,
	StackSize: number,
	Weight: number,
	Rarity: string,
	Price: { Cash: number, Credits: number }?,
	UseTime: number,
	Cooldown: number,
	Effect: {
		HealAmount: number?,
		HealOverTime: number?,
		MaxHealth: number?,
		BoostType: string?,
		BoostDuration: number?,
		BoostValue: number?,
		Damage: number?,
		Radius: number?,
		FuseTime: number?,
	},
}

export type ArmorTemplate = {
	Id: string,
	Name: string,
	Model: string,
	Icon: string,
	Level: 1 | 2 | 3,
	Durability: number,
	Protection: number,
	Weight: number,
	Rarity: string,
	Price: { Cash: number, Credits: number }?,
}

export type BackpackTemplate = {
	Id: string,
	Name: string,
	Model: string,
	Icon: string,
	CapacityBonus: number,
	WeightReduction: number,
	Rarity: string,
	Price: { Cash: number, Credits: number }?,
}

export type AmmoTemplate = {
	Id: string,
	Name: string,
	Caliber: string,
	Model: string,
	Icon: string,
	StackSize: number,
	Weight: number,
	Price: { Cash: number, Credits: number }?,
	DamageMultiplier: number,
	PenetrationMultiplier: number,
	VelocityMultiplier: number,
}

-- ==================== WEAPONS ====================

ItemDefinitions.Weapons = {
	-- Assault Rifles
	AK74 = {
		Id = "AK74",
		Name = "AK-74",
		Class = "AR",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 36,
			FireRate = 600,
			MuzzleVelocity = 900,
			Range = 400,
			RecoilPattern = {
				[1] = Vector2.new(0.8, 0.1),
				[2] = Vector2.new(1.2, -0.2),
				[3] = Vector2.new(1.5, 0.3),
				[4] = Vector2.new(1.8, -0.1),
				[5] = Vector2.new(2.0, 0.2),
				[6] = Vector2.new(2.2, -0.3),
				[7] = Vector2.new(2.4, 0.1),
				[8] = Vector2.new(2.5, -0.2),
			},
			RecoilRecovery = 8,
			Spread = 2.5,
			SpreadADS = 0.8,
			SpreadMove = 4.0,
			SpreadJump = 8.0,
			ReloadTime = 2.8,
			TacticalReloadTime = 2.2,
			MagSize = 30,
			AmmoType = "5.45x39",
			Weight = 3.5,
			AdsTime = 0.25,
			Sway = 1.2,
			Penetration = 12,
			BulletDrop = 1.0,
		},
		Attachments = {
			Optic = { "RedDot", "Holographic", "Scope2x", "Scope4x", "Scope6x" },
			Muzzle = { "Compensator", "Suppressor", "FlashHider" },
			Barrel = { "Lightweight", "Heavy", "Long" },
			Underbarrel = { "VerticalGrip", "AngledGrip", "HalfGrip" },
			Magazine = { "ExtendedMag", "QuickDrawMag" },
			Stock = { "TacticalStock", "FoldingStock" },
		},
		DefaultAttachments = { Muzzle = "FlashHider" },
		Animations = { Idle = "", Fire = "", Reload = "", Ads = "" },
		Sounds = { Fire = "", Reload = "", DryFire = "" },
		Rarity = "Common",
		Price = { Cash = 500, Credits = 0 },
	},
	
	M416 = {
		Id = "M416",
		Name = "M416",
		Class = "AR",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 35,
			FireRate = 750,
			MuzzleVelocity = 880,
			Range = 380,
			RecoilPattern = {
				[1] = Vector2.new(0.6, 0.05),
				[2] = Vector2.new(1.0, -0.1),
				[3] = Vector2.new(1.3, 0.15),
				[4] = Vector2.new(1.5, -0.05),
				[5] = Vector2.new(1.7, 0.1),
				[6] = Vector2.new(1.8, -0.15),
				[7] = Vector2.new(2.0, 0.05),
				[8] = Vector2.new(2.1, -0.1),
			},
			RecoilRecovery = 10,
			Spread = 2.0,
			SpreadADS = 0.6,
			SpreadMove = 3.5,
			SpreadJump = 7.0,
			ReloadTime = 2.5,
			TacticalReloadTime = 1.9,
			MagSize = 30,
			AmmoType = "5.56x45",
			Weight = 3.2,
			AdsTime = 0.22,
			Sway = 1.0,
			Penetration = 10,
			BulletDrop = 1.0,
		},
		Attachments = {
			Optic = { "RedDot", "Holographic", "Scope2x", "Scope4x", "Scope6x" },
			Muzzle = { "Compensator", "Suppressor", "FlashHider" },
			Barrel = { "Lightweight", "Heavy", "Long" },
			Underbarrel = { "VerticalGrip", "AngledGrip", "HalfGrip" },
			Magazine = { "ExtendedMag", "QuickDrawMag" },
			Stock = { "TacticalStock", "FoldingStock" },
		},
		Animations = {},
		Sounds = {},
		Rarity = "Uncommon",
		Price = { Cash = 800, Credits = 0 },
	},
	
	SCAR = {
		Id = "SCAR",
		Name = "SCAR-H",
		Class = "AR",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 42,
			FireRate = 550,
			MuzzleVelocity = 850,
			Range = 420,
			RecoilPattern = {
				[1] = Vector2.new(1.0, 0.2),
				[2] = Vector2.new(1.5, -0.3),
				[3] = Vector2.new(1.8, 0.4),
				[4] = Vector2.new(2.0, -0.2),
				[5] = Vector2.new(2.2, 0.3),
				[6] = Vector2.new(2.4, -0.4),
				[7] = Vector2.new(2.5, 0.2),
				[8] = Vector2.new(2.6, -0.3),
			},
			RecoilRecovery = 6,
			Spread = 3.0,
			SpreadADS = 1.0,
			SpreadMove = 4.5,
			SpreadJump = 9.0,
			ReloadTime = 3.0,
			TacticalReloadTime = 2.4,
			MagSize = 20,
			AmmoType = "7.62x51",
			Weight = 4.0,
			AdsTime = 0.28,
			Sway = 1.4,
			Penetration = 18,
			BulletDrop = 1.1,
		},
		Attachments = {
			Optic = { "RedDot", "Holographic", "Scope2x", "Scope4x", "Scope6x" },
			Muzzle = { "Compensator", "Suppressor", "FlashHider" },
			Barrel = { "Heavy", "Long" },
			Underbarrel = { "VerticalGrip", "AngledGrip" },
			Magazine = { "ExtendedMag" },
			Stock = { "TacticalStock" },
		},
		Animations = {},
		Sounds = {},
		Rarity = "Rare",
		Price = { Cash = 1500, Credits = 0 },
	},
	
	-- Sniper Rifles
	Kar98k = {
		Id = "Kar98k",
		Name = "Kar98k",
		Class = "SR",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 95,
			FireRate = 40,
			MuzzleVelocity = 760,
			Range = 800,
			RecoilPattern = {
				[1] = Vector2.new(3.0, 0.5),
			},
			RecoilRecovery = 2,
			Spread = 0.1,
			SpreadADS = 0.0,
			SpreadMove = 10.0,
			SpreadJump = 20.0,
			ReloadTime = 3.5, -- Per bullet
			TacticalReloadTime = 2.0,
			MagSize = 5,
			AmmoType = "7.62x51",
			Weight = 4.2,
			AdsTime = 0.35,
			Sway = 2.0,
			Penetration = 25,
			BulletDrop = 1.2,
		},
		Attachments = {
			Optic = { "Scope4x", "Scope6x", "Scope8x" },
			Muzzle = { "Suppressor", "FlashHider" },
			Barrel = { "Long" },
			Stock = { "CheekPad" },
		},
		Animations = { BoltAction = "" },
		Sounds = {},
		Rarity = "Rare",
		Price = { Cash = 2000, Credits = 0 },
	},
	
	AWM = {
		Id = "AWM",
		Name = "AWM",
		Class = "SR",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 120,
			FireRate = 35,
			MuzzleVelocity = 910,
			Range = 1000,
			RecoilPattern = {
				[1] = Vector2.new(4.0, 0.8),
			},
			RecoilRecovery = 1.5,
			Spread = 0.05,
			SpreadADS = 0.0,
			SpreadMove = 15.0,
			SpreadJump = 25.0,
			ReloadTime = 4.0,
			TacticalReloadTime = 2.5,
			MagSize = 5,
			AmmoType = ".300Mag",
			Weight = 6.5,
			AdsTime = 0.4,
			Sway = 2.5,
			Penetration = 30,
			BulletDrop = 1.1,
		},
		Attachments = {
			Optic = { "Scope6x", "Scope8x", "Scope15x" },
			Muzzle = { "Suppressor" },
			Barrel = { "Long" },
			Stock = { "CheekPad" },
		},
		Animations = { BoltAction = "" },
		Sounds = {},
		Rarity = "Legendary",
		Price = { Cash = 0, Credits = 500 }, -- Crate only
	},
	
	-- SMGs
	MP5 = {
		Id = "MP5",
		Name = "MP5",
		Class = "SMG",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 28,
			FireRate = 800,
			MuzzleVelocity = 400,
			Range = 150,
			RecoilPattern = {
				[1] = Vector2.new(0.4, 0.05),
				[2] = Vector2.new(0.7, -0.1),
				[3] = Vector2.new(0.9, 0.1),
				[4] = Vector2.new(1.1, -0.05),
				[5] = Vector2.new(1.2, 0.1),
			},
			RecoilRecovery = 12,
			Spread = 3.0,
			SpreadADS = 1.0,
			SpreadMove = 3.5,
			SpreadJump = 6.0,
			ReloadTime = 2.2,
			TacticalReloadTime = 1.6,
			MagSize = 30,
			AmmoType = "9x19",
			Weight = 2.8,
			AdsTime = 0.18,
			Sway = 0.8,
			Penetration = 6,
			BulletDrop = 1.3,
		},
		Attachments = {
			Optic = { "RedDot", "Holographic", "Scope2x" },
			Muzzle = { "Compensator", "Suppressor", "FlashHider" },
			Barrel = { "Lightweight", "Long" },
			Underbarrel = { "VerticalGrip", "AngledGrip", "HalfGrip" },
			Magazine = { "ExtendedMag", "DrumMag" },
			Stock = { "TacticalStock", "FoldingStock", "NoStock" },
		},
		Animations = {},
		Sounds = {},
		Rarity = "Common",
		Price = { Cash = 400, Credits = 0 },
	},
	
	Vector = {
		Id = "Vector",
		Name = "Vector",
		Class = "SMG",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 30,
			FireRate = 1200,
			MuzzleVelocity = 380,
			Range = 120,
			RecoilPattern = {
				[1] = Vector2.new(0.3, 0.0),
				[2] = Vector2.new(0.5, -0.05),
				[3] = Vector2.new(0.7, 0.05),
				[4] = Vector2.new(0.8, -0.05),
				[5] = Vector2.new(0.9, 0.0),
			},
			RecoilRecovery = 15,
			Spread = 4.0,
			SpreadADS = 1.5,
			SpreadMove = 5.0,
			SpreadJump = 8.0,
			ReloadTime = 2.0,
			TacticalReloadTime = 1.4,
			MagSize = 25,
			AmmoType = ".45ACP",
			Weight = 2.5,
			AdsTime = 0.16,
			Sway = 0.7,
			Penetration = 5,
			BulletDrop = 1.4,
		},
		Attachments = {
			Optic = { "RedDot", "Holographic" },
			Muzzle = { "Compensator", "Suppressor" },
			Underbarrel = { "VerticalGrip" },
			Magazine = { "ExtendedMag" },
			Stock = { "FoldingStock" },
		},
		Animations = {},
		Sounds = {},
		Rarity = "Epic",
		Price = { Cash = 0, Credits = 300 },
	},
	
	-- Shotguns
	S12K = {
		Id = "S12K",
		Name = "S12K",
		Class = "SG",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 14, -- per pellet (8 pellets)
			FireRate = 200,
			MuzzleVelocity = 350,
			Range = 80,
			RecoilPattern = {
				[1] = Vector2.new(2.0, 0.5),
			},
			RecoilRecovery = 4,
			Spread = 8.0,
			SpreadADS = 4.0,
			SpreadMove = 10.0,
			SpreadJump = 15.0,
			ReloadTime = 0.4, -- per shell
			TacticalReloadTime = 2.5,
			MagSize = 5,
			AmmoType = "12Gauge",
			Weight = 3.8,
			AdsTime = 0.25,
			Sway = 1.5,
			Penetration = 2,
			BulletDrop = 1.5,
		},
		Attachments = {
			Optic = { "RedDot", "Holographic" },
			Muzzle = { "Choke", "Suppressor" },
			Magazine = { "ExtendedMag" },
		},
		Animations = { Pump = "" },
		Sounds = {},
		Rarity = "Uncommon",
		Price = { Cash = 600, Credits = 0 },
	},
	
	-- DMRs
	Mini14 = {
		Id = "Mini14",
		Name = "Mini-14",
		Class = "DMR",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 52,
			FireRate = 400,
			MuzzleVelocity = 990,
			Range = 600,
			RecoilPattern = {
				[1] = Vector2.new(1.2, 0.2),
				[2] = Vector2.new(1.8, -0.3),
				[3] = Vector2.new(2.2, 0.3),
				[4] = Vector2.new(2.5, -0.2),
			},
			RecoilRecovery = 7,
			Spread = 1.5,
			SpreadADS = 0.4,
			SpreadMove = 3.0,
			SpreadJump = 8.0,
			ReloadTime = 2.2,
			TacticalReloadTime = 1.8,
			MagSize = 20,
			AmmoType = "5.56x45",
			Weight = 3.6,
			AdsTime = 0.24,
			Sway = 1.1,
			Penetration = 15,
			BulletDrop = 0.8,
		},
		Attachments = {
			Optic = { "Scope2x", "Scope4x", "Scope6x", "Scope8x" },
			Muzzle = { "Compensator", "Suppressor", "FlashHider" },
			Barrel = { "Lightweight", "Long" },
			Underbarrel = { "VerticalGrip", "AngledGrip" },
			Magazine = { "ExtendedMag", "QuickDrawMag" },
			Stock = { "TacticalStock" },
		},
		Animations = {},
		Sounds = {},
		Rarity = "Rare",
		Price = { Cash = 1800, Credits = 0 },
	},
	
	-- Pistols
	P1911 = {
		Id = "P1911",
		Name = "P1911",
		Class = "Pistol",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 45,
			FireRate = 300,
			MuzzleVelocity = 380,
			Range = 100,
			RecoilPattern = {
				[1] = Vector2.new(1.5, 0.3),
			},
			RecoilRecovery = 8,
			Spread = 2.0,
			SpreadADS = 1.0,
			SpreadMove = 3.0,
			SpreadJump = 5.0,
			ReloadTime = 1.8,
			TacticalReloadTime = 1.2,
			MagSize = 7,
			AmmoType = ".45ACP",
			Weight = 1.0,
			AdsTime = 0.15,
			Sway = 0.8,
			Penetration = 7,
			BulletDrop = 1.3,
		},
		Attachments = {
			Optic = { "RedDot" },
			Muzzle = { "Suppressor", "Compensator" },
			Magazine = { "ExtendedMag" },
		},
		Animations = {},
		Sounds = {},
		Rarity = "Common",
		Price = { Cash = 100, Credits = 0 },
	},
	
	-- Melee
	Pan = {
		Id = "Pan",
		Name = "Frying Pan",
		Class = "Melee",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 60,
			FireRate = 60,
			MuzzleVelocity = 0,
			Range = 3,
			RecoilPattern = {},
			RecoilRecovery = 0,
			Spread = 0,
			SpreadADS = 0,
			SpreadMove = 0,
			SpreadJump = 0,
			ReloadTime = 0,
			TacticalReloadTime = 0,
			MagSize = 1,
			AmmoType = "None",
			Weight = 1.5,
			AdsTime = 0,
			Sway = 0,
			Penetration = 0,
			BulletDrop = 0,
		},
		Attachments = {},
		Animations = { Swing = "", Block = "" },
		Sounds = { Hit = "", Block = "" },
		Rarity = "Uncommon",
		Price = { Cash = 50, Credits = 0 },
		Special = { CanBlock = true, BlockDamageReduction = 0.8 },
	},
	
	-- Throwables
	FragGrenade = {
		Id = "FragGrenade",
		Name = "Frag Grenade",
		Class = "Throw",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 100,
			FireRate = 0,
			MuzzleVelocity = 0,
			Range = 0,
			RecoilPattern = {},
			RecoilRecovery = 0,
			Spread = 0,
			SpreadADS = 0,
			SpreadMove = 0,
			SpreadJump = 0,
			ReloadTime = 0,
			TacticalReloadTime = 0,
			MagSize = 1,
			AmmoType = "None",
			Weight = 0.5,
			AdsTime = 0,
			Sway = 0,
			Penetration = 0,
			BulletDrop = 0,
		},
		Attachments = {},
		Animations = { Throw = "", Cook = "" },
		Sounds = { PinPull = "", Explosion = "" },
		Rarity = "Common",
		Price = { Cash = 50, Credits = 0 },
		Effect = { Damage = 100, Radius = 8, FuseTime = 4.5, Cookable = true },
	},
	
	SmokeGrenade = {
		Id = "SmokeGrenade",
		Name = "Smoke Grenade",
		Class = "Throw",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 0,
			FireRate = 0,
			MuzzleVelocity = 0,
			Range = 0,
			RecoilPattern = {},
			RecoilRecovery = 0,
			Spread = 0,
			SpreadADS = 0,
			SpreadMove = 0,
			SpreadJump = 0,
			ReloadTime = 0,
			TacticalReloadTime = 0,
			MagSize = 1,
			AmmoType = "None",
			Weight = 0.5,
			AdsTime = 0,
			Sway = 0,
			Penetration = 0,
			BulletDrop = 0,
		},
		Attachments = {},
		Animations = { Throw = "" },
		Sounds = { PinPull = "", Hiss = "" },
		Rarity = "Common",
		Price = { Cash = 30, Credits = 0 },
		Effect = { Duration = 25, Radius = 12, ParticleId = "" },
	},
	
	Flashbang = {
		Id = "Flashbang",
		Name = "Flashbang",
		Class = "Throw",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 0,
			FireRate = 0,
			MuzzleVelocity = 0,
			Range = 0,
			RecoilPattern = {},
			RecoilRecovery = 0,
			Spread = 0,
			SpreadADS = 0,
			SpreadMove = 0,
			SpreadJump = 0,
			ReloadTime = 0,
			TacticalReloadTime = 0,
			MagSize = 1,
			AmmoType = "None",
			Weight = 0.4,
			AdsTime = 0,
			Sway = 0,
			Penetration = 0,
			BulletDrop = 0,
		},
		Attachments = {},
		Animations = { Throw = "" },
		Sounds = { PinPull = "", Flash = "" },
		Rarity = "Uncommon",
		Price = { Cash = 80, Credits = 0 },
		Effect = { BlindDuration = 4, DeafDuration = 6, Radius = 15 },
	},
	
	Molotov = {
		Id = "Molotov",
		Name = "Molotov Cocktail",
		Class = "Throw",
		Model = "rbxassetid://0",
		ViewModel = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Stats = {
			Damage = 30,
			FireRate = 0,
			MuzzleVelocity = 0,
			Range = 0,
			RecoilPattern = {},
			RecoilRecovery = 0,
			Spread = 0,
			SpreadADS = 0,
			SpreadMove = 0,
			SpreadJump = 0,
			ReloadTime = 0,
			TacticalReloadTime = 0,
			MagSize = 1,
			AmmoType = "None",
			Weight = 0.6,
			AdsTime = 0,
			Sway = 0,
			Penetration = 0,
			BulletDrop = 0,
		},
		Attachments = {},
		Animations = { Throw = "" },
		Sounds = { Break = "", Burn = "" },
		Rarity = "Rare",
		Price = { Cash = 120, Credits = 0 },
		Effect = { DamagePerSec = 30, Duration = 15, Radius = 6 },
	},
}

-- ==================== ATTACHMENTS ====================

ItemDefinitions.Attachments = {
	-- Optics
	RedDot = {
		Id = "RedDot",
		Name = "Red Dot Sight",
		Category = "Optic",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "P1911", "S12K" },
		Stats = { AdsSpeed = -0.05 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Common",
		Price = { Cash = 100, Credits = 0 },
	},
	
	Holographic = {
		Id = "Holographic",
		Name = "Holographic Sight",
		Category = "Optic",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "S12K" },
		Stats = { AdsSpeed = -0.08, HipFireSpread = -0.1 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Uncommon",
		Price = { Cash = 200, Credits = 0 },
	},
	
	Scope2x = {
		Id = "Scope2x",
		Name = "2x Scope",
		Category = "Optic",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "S12K" },
		Stats = { AdsSpeed = -0.1, SwayReduction = 0.1 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Uncommon",
		Price = { Cash = 300, Credits = 0 },
	},
	
	Scope4x = {
		Id = "Scope4x",
		Name = "4x Scope",
		Category = "Optic",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "Mini14", "Kar98k", "AWM" },
		Stats = { AdsSpeed = -0.15, SwayReduction = 0.2 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Rare",
		Price = { Cash = 500, Credits = 0 },
	},
	
	Scope6x = {
		Id = "Scope6x",
		Name = "6x Scope",
		Category = "Optic",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "Mini14", "Kar98k", "AWM" },
		Stats = { AdsSpeed = -0.2, SwayReduction = 0.3 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Rare",
		Price = { Cash = 800, Credits = 0 },
	},
	
	Scope8x = {
		Id = "Scope8x",
		Name = "8x Scope",
		Category = "Optic",
		CompatibleWeapons = { "Mini14", "Kar98k", "AWM" },
		Stats = { AdsSpeed = -0.25, SwayReduction = 0.4 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Epic",
		Price = { Cash = 0, Credits = 200 },
	},
	
	Scope15x = {
		Id = "Scope15x",
		Name = "15x Scope",
		Category = "Optic",
		CompatibleWeapons = { "AWM" },
		Stats = { AdsSpeed = -0.3, SwayReduction = 0.5 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Legendary",
		Price = { Cash = 0, Credits = 500 },
	},
	
	-- Muzzles
	Compensator = {
		Id = "Compensator",
		Name = "Compensator",
		Category = "Muzzle",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "Kar98k", "S12K" },
		Stats = { RecoilControl = 0.25, RecoilHorizontal = 0.15, SoundSuppression = -0.2 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Common",
		Price = { Cash = 80, Credits = 0 },
	},
	
	Suppressor = {
		Id = "Suppressor",
		Name = "Suppressor",
		Category = "Muzzle",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "Kar98k", "AWM", "P1911", "S12K" },
		Stats = { SoundSuppression = 0.9, FlashHider = true, MuzzleVelocity = -0.05, AdsSpeed = -0.05 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Uncommon",
		Price = { Cash = 150, Credits = 0 },
	},
	
	FlashHider = {
		Id = "FlashHider",
		Name = "Flash Hider",
		Category = "Muzzle",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "Kar98k", "S12K" },
		Stats = { FlashHider = true, RecoilHorizontal = 0.1 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Common",
		Price = { Cash = 50, Credits = 0 },
	},
	
	Choke = {
		Id = "Choke",
		Name = "Choke",
		Category = "Muzzle",
		CompatibleWeapons = { "S12K" },
		Stats = { SpreadADS = -0.3, Spread = -0.2 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Uncommon",
		Price = { Cash = 100, Credits = 0 },
	},
	
	-- Barrels
	LightweightBarrel = {
		Id = "LightweightBarrel",
		Name = "Lightweight Barrel",
		Category = "Barrel",
		CompatibleWeapons = { "AK74", "M416", "MP5", "Vector", "Mini14" },
		Stats = { AdsSpeed = 0.1, Sway = -0.1, MuzzleVelocity = -0.05 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Uncommon",
		Price = { Cash = 150, Credits = 0 },
	},
	
	HeavyBarrel = {
		Id = "HeavyBarrel",
		Name = "Heavy Barrel",
		Category = "Barrel",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "Mini14" },
		Stats = { RecoilControl = 0.15, MuzzleVelocity = 0.05, AdsSpeed = -0.1, Sway = 0.1 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Rare",
		Price = { Cash = 300, Credits = 0 },
	},
	
	LongBarrel = {
		Id = "LongBarrel",
		Name = "Long Barrel",
		Category = "Barrel",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "Kar98k", "AWM", "S12K" },
		Stats = { MuzzleVelocity = 0.15, Range = 0.2, AdsSpeed = -0.15, Sway = 0.15 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Rare",
		Price = { Cash = 400, Credits = 0 },
	},
	
	-- Underbarrel
	VerticalGrip = {
		Id = "VerticalGrip",
		Name = "Vertical Grip",
		Category = "Underbarrel",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "S12K" },
		Stats = { RecoilControl = 0.2, AdsSpeed = -0.05 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Common",
		Price = { Cash = 80, Credits = 0 },
	},
	
	AngledGrip = {
		Id = "AngledGrip",
		Name = "Angled Grip",
		Category = "Underbarrel",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "S12K" },
		Stats = { AdsSpeed = 0.1, HipFireSpread = -0.15, SwayReduction = 0.1 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Uncommon",
		Price = { Cash = 150, Credits = 0 },
	},
	
	HalfGrip = {
		Id = "HalfGrip",
		Name = "Half Grip",
		Category = "Underbarrel",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "S12K" },
		Stats = { RecoilControl = 0.1, AdsSpeed = 0.05, HipFireSpread = -0.1, RecoilHorizontal = 0.15 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Rare",
		Price = { Cash = 250, Credits = 0 },
	},
	
	-- Magazines
	ExtendedMag = {
		Id = "ExtendedMag",
		Name = "Extended Magazine",
		Category = "Magazine",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "Kar98k", "AWM", "P1911", "S12K" },
		Stats = { MagSize = 1.5, ReloadSpeed = -0.1, Weight = 0.2 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Common",
		Price = { Cash = 100, Credits = 0 },
	},
	
	QuickDrawMag = {
		Id = "QuickDrawMag",
		Name = "QuickDraw Magazine",
		Category = "Magazine",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "P1911" },
		Stats = { ReloadSpeed = 0.25, AdsSpeed = 0.05, MagSize = 0.9 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Uncommon",
		Price = { Cash = 200, Credits = 0 },
	},
	
	DrumMag = {
		Id = "DrumMag",
		Name = "Drum Magazine",
		Category = "Magazine",
		CompatibleWeapons = { "MP5", "Vector" },
		Stats = { MagSize = 2.5, ReloadSpeed = -0.3, Weight = 0.5, AdsSpeed = -0.15, Sway = 0.2 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Rare",
		Price = { Cash = 500, Credits = 0 },
	},
	
	-- Stocks
	TacticalStock = {
		Id = "TacticalStock",
		Name = "Tactical Stock",
		Category = "Stock",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14" },
		Stats = { RecoilControl = 0.1, AdsSpeed = 0.05, SwayReduction = 0.1 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Common",
		Price = { Cash = 100, Credits = 0 },
	},
	
	FoldingStock = {
		Id = "FoldingStock",
		Name = "Folding Stock",
		Category = "Stock",
		CompatibleWeapons = { "AK74", "M416", "SCAR", "MP5", "Vector", "Mini14", "Kar98k" },
		Stats = { AdsSpeed = 0.15, HipFireSpread = -0.1, Sway = 0.1 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Uncommon",
		Price = { Cash = 200, Credits = 0 },
	},
	
	CheekPad = {
		Id = "CheekPad",
		Name = "Cheek Pad",
		Category = "Stock",
		CompatibleWeapons = { "Kar98k", "AWM", "Mini14" },
		Stats = { AdsSpeed = 0.1, SwayReduction = 0.15, RecoilRecovery = 0.1 },
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Rarity = "Rare",
		Price = { Cash = 300, Credits = 0 },
	},
}

-- ==================== CONSUMABLES ====================

ItemDefinitions.Consumables = {
	Bandage = {
		Id = "Bandage",
		Name = "Bandage",
		Category = "Med",
		Description = "Heals 10 HP over 4 seconds. Max 75 HP.",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		StackSize = 5,
		Weight = 0.1,
		Rarity = "Common",
		Price = { Cash = 20, Credits = 0 },
		UseTime = 4,
		Cooldown = 1,
		Effect = { HealAmount = 10, MaxHealth = 75 },
	},
	
	Medkit = {
		Id = "Medkit",
		Name = "First Aid Kit",
		Category = "Med",
		Description = "Heals 75 HP over 8 seconds. Can overheal to 100.",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		StackSize = 3,
		Weight = 0.3,
		Rarity = "Uncommon",
		Price = { Cash = 100, Credits = 0 },
		UseTime = 8,
		Cooldown = 1,
		Effect = { HealAmount = 75, MaxHealth = 100 },
	},
	
	Painkillers = {
		Id = "Painkillers",
		Name = "Painkillers",
		Category = "Boost",
		Description = "Restores 50 HP over time. Boosts heal rate.",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		StackSize = 5,
		Weight = 0.15,
		Rarity = "Common",
		Price = { Cash = 50, Credits = 0 },
		UseTime = 6,
		Cooldown = 1,
		Effect = { HealOverTime = 50, BoostDuration = 120, BoostValue = 2 },
	},
	
	EnergyDrink = {
		Id = "EnergyDrink",
		Name = "Energy Drink",
		Category = "Boost",
		Description = "Restores 40 HP over time. Boosts movement speed slightly.",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		StackSize = 5,
		Weight = 0.2,
		Rarity = "Common",
		Price = { Cash = 40, Credits = 0 },
		UseTime = 4,
		Cooldown = 1,
		Effect = { HealOverTime = 40, BoostDuration = 180, BoostValue = 1.05, BoostType = "Speed" },
	},
	
	Adrenaline = {
		Id = "Adrenaline",
		Name = "Adrenaline Syringe",
		Category = "Boost",
		Description = "Instant 100% boost meter. Massive heal over time + speed boost.",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		StackSize = 1,
		Weight = 0.3,
		Rarity = "Epic",
		Price = { Cash = 0, Credits = 100 },
		UseTime = 8,
		Cooldown = 1,
		Effect = { HealOverTime = 100, BoostDuration = 300, BoostValue = 1.15, BoostType = "All", InstantBoost = true },
	},
}

-- ==================== ARMOR ====================

ItemDefinitions.Armor = {
	Level1Vest = {
		Id = "Level1Vest",
		Name = "Level 1 Vest",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Level = 1,
		Durability = 80,
		Protection = 0.3,
		Weight = 3.0,
		Rarity = "Common",
		Price = { Cash = 200, Credits = 0 },
	},
	
	Level2Vest = {
		Id = "Level2Vest",
		Name = "Level 2 Vest",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Level = 2,
		Durability = 150,
		Protection = 0.4,
		Weight = 5.0,
		Rarity = "Uncommon",
		Price = { Cash = 500, Credits = 0 },
	},
	
	Level3Vest = {
		Id = "Level3Vest",
		Name = "Level 3 Vest",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Level = 3,
		Durability = 250,
		Protection = 0.5,
		Weight = 8.0,
		Rarity = "Rare",
		Price = { Cash = 1200, Credits = 0 },
	},
	
	Level1Helmet = {
		Id = "Level1Helmet",
		Name = "Level 1 Helmet",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Level = 1,
		Durability = 80,
		Protection = 0.3,
		Weight = 1.5,
		Rarity = "Common",
		Price = { Cash = 150, Credits = 0 },
	},
	
	Level2Helmet = {
		Id = "Level2Helmet",
		Name = "Level 2 Helmet",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Level = 2,
		Durability = 150,
		Protection = 0.4,
		Weight = 2.5,
		Rarity = "Uncommon",
		Price = { Cash = 400, Credits = 0 },
	},
	
	Level3Helmet = {
		Id = "Level3Helmet",
		Name = "Level 3 Helmet",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		Level = 3,
		Durability = 230,
		Protection = 0.55,
		Weight = 3.5,
		Rarity = "Rare",
		Price = { Cash = 1000, Credits = 0 },
	},
}

-- ==================== BACKPACKS ====================

ItemDefinitions.Backpacks = {
	SmallBackpack = {
		Id = "SmallBackpack",
		Name = "Small Backpack",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		CapacityBonus = 50,
		WeightReduction = 0,
		Rarity = "Common",
		Price = { Cash = 100, Credits = 0 },
	},
	
	MediumBackpack = {
		Id = "MediumBackpack",
		Name = "Medium Backpack",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		CapacityBonus = 100,
		WeightReduction = 0.1,
		Rarity = "Uncommon",
		Price = { Cash = 300, Credits = 0 },
	},
	
	LargeBackpack = {
		Id = "LargeBackpack",
		Name = "Large Backpack",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		CapacityBonus = 200,
		WeightReduction = 0.2,
		Rarity = "Rare",
		Price = { Cash = 800, Credits = 0 },
	},
}

-- ==================== AMMO ====================

ItemDefinitions.Ammo = {
	Ammo_5_56 = {
		Id = "Ammo_5_56",
		Name = "5.56mm Ammo",
		Caliber = "5.56x45",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		StackSize = 60,
		Weight = 0.01,
		Price = { Cash = 10, Credits = 0 },
		DamageMultiplier = 1.0,
		PenetrationMultiplier = 1.0,
		VelocityMultiplier = 1.0,
	},
	
	Ammo_7_62 = {
		Id = "Ammo_7_62",
		Name = "7.62mm Ammo",
		Caliber = "7.62x51",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		StackSize = 40,
		Weight = 0.015,
		Price = { Cash = 15, Credits = 0 },
		DamageMultiplier = 1.1,
		PenetrationMultiplier = 1.2,
		VelocityMultiplier = 0.95,
	},
	
	Ammo_9mm = {
		Id = "Ammo_9mm",
		Name = "9mm Ammo",
		Caliber = "9x19",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		StackSize = 80,
		Weight = 0.008,
		Price = { Cash = 8, Credits = 0 },
		DamageMultiplier = 1.0,
		PenetrationMultiplier = 0.8,
		VelocityMultiplier = 1.0,
	},
	
	Ammo_45ACP = {
		Id = "Ammo_45ACP",
		Name = ".45 ACP Ammo",
		Caliber = ".45ACP",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		StackSize = 50,
		Weight = 0.012,
		Price = { Cash = 12, Credits = 0 },
		DamageMultiplier = 1.1,
		PenetrationMultiplier = 0.9,
		VelocityMultiplier = 0.9,
	},
	
	Ammo_12Gauge = {
		Id = "Ammo_12Gauge",
		Name = "12 Gauge Shells",
		Caliber = "12Gauge",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		StackSize = 20,
		Weight = 0.02,
		Price = { Cash = 20, Credits = 0 },
		DamageMultiplier = 1.0,
		PenetrationMultiplier = 0.5,
		VelocityMultiplier = 0.8,
	},
	
	Ammo_300Mag = {
		Id = "Ammo_300Mag",
		Name = ".300 Magnum Ammo",
		Caliber = ".300Mag",
		Model = "rbxassetid://0",
		Icon = "rbxassetid://0",
		StackSize = 20,
		Weight = 0.02,
		Price = { Cash = 0, Credits = 50 },
		DamageMultiplier = 1.0,
		PenetrationMultiplier = 1.5,
		VelocityMultiplier = 1.1,
	},
}

-- ==================== LOOKUP FUNCTIONS ====================

local allItems: { [string]: any } = {}

-- Register all items
for category, items in pairs(ItemDefinitions) do
	if type(items) == "table" then
		for id, item in pairs(items) do
			allItems[id] = item
			item.Category = category
		end
	end
end

function ItemDefinitions.Get(id: string): any
	return allItems[id]
end

function ItemDefinitions.GetWeapon(id: string): WeaponTemplate?
	local item = allItems[id]
	if item and item.Class and item.Class ~= "Melee" and item.Class ~= "Throw" then
		return item
	end
	return nil
end

function ItemDefinitions.GetAttachment(id: string): AttachmentTemplate?
	local item = allItems[id]
	if item and item.Category == "Attachments" then
		return item
	end
	return nil
end

function ItemDefinitions.GetConsumable(id: string): ConsumableTemplate?
	local item = allItems[id]
	if item and item.Category == "Consumables" then
		return item
	end
	return nil
end

function ItemDefinitions.GetArmor(id: string): ArmorTemplate?
	local item = allItems[id]
	if item and item.Category == "Armor" then
		return item
	end
	return nil
end

function ItemDefinitions.GetBackpack(id: string): BackpackTemplate?
	local item = allItems[id]
	if item and item.Category == "Backpacks" then
		return item
	end
	return nil
end

function ItemDefinitions.GetAmmo(id: string): AmmoTemplate?
	local item = allItems[id]
	if item and item.Category == "Ammo" then
		return item
	end
	return nil
end

function ItemDefinitions.GetAllWeapons(): { WeaponTemplate }
	local weapons = {}
	for _, item in pairs(allItems) do
		if item.Class and item.Class ~= "Melee" and item.Class ~= "Throw" then
			table.insert(weapons, item)
		end
	end
	return weapons
end

function ItemDefinitions.GetByCategory(category: string): { any }
	local items = {}
	for _, item in pairs(allItems) do
		if item.Category == category then
			table.insert(items, item)
		end
	end
	return items
end

function ItemDefinitions.GetCompatibleAttachments(weaponId: string): { [string]: { string } }
	local weapon = ItemDefinitions.GetWeapon(weaponId)
	return weapon and weapon.Attachments or {}
end

function ItemDefinitions.GetWeaponTemplate(templateId: string): WeaponTemplate?
	return ItemDefinitions.GetWeapon(templateId)
end

function ItemDefinitions.GetAll(): { [string]: any }
	return allItems
end

return ItemDefinitions