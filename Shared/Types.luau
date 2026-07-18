--[[
	Shared Type Definitions - Strict Luau types for type safety
]]

-- Luau type exports
export type Vector3 = Vector3
export type CFrame = CFrame
export type Color3 = Color3
export type UDim2 = UDim2
export type NumberSequence = NumberSequence
export type ColorSequence = ColorSequence
export type RaycastParams = RaycastParams
export type RaycastResult = RaycastResult
export type TweenInfo = TweenInfo
export type Instance = Instance
export type Player = Player
export type Character = Model & {
	Humanoid: Humanoid,
	HumanoidRootPart: BasePart,
	Head: BasePart,
}
export type Humanoid = Humanoid
export type BasePart = BasePart

-- Game Enums
export type Stance = "Stand" | "Crouch" | "Prone"
export type WeaponClass = "AR" | "SMG" | "SR" | "DMR" | "SG" | "Pistol" | "Melee" | "Throw"
export type ItemCategory = "Weapon" | "Ammo" | "Med" | "Armor" | "Attachment" | "Throw" | "Consumable" | "Key"
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type ZonePhase = number
export type SquadId = string
export type MatchId = string
export type UserId = number

-- Player Profile Data
export type PlayerStats = {
	Level: number,
	XP: number,
	SkillRating: number,
	Kills: number,
	Deaths: number,
	Wins: number,
	Top10s: number,
	PlayTime: number, -- seconds
	Headshots: number,
	LongestShot: number,
	DamageDealt: number,
	Revives: number,
}

export type Currency = {
	Cash: number,
	Credits: number,
}

export type LoadoutSlot = {
	WeaponId: string?,
	Attachments: { [string]: string },
	SkinId: string?,
}

export type Loadout = {
	Primary: LoadoutSlot?,
	Secondary: LoadoutSlot?,
	Melee: LoadoutSlot?,
	Throw: LoadoutSlot?,
	Armor: LoadoutSlot?,
	Backpack: LoadoutSlot?,
}

export type InventoryItem = {
	Id: string,           -- Unique instance ID
	TemplateId: string,   -- References ItemDefinitions
	Quantity: number,
	Durability: number?,  -- 0-100 for weapons/armor
	Metadata: { [string]: any }?, -- Ammo count, attachment slots, etc.
}

export type Inventory = {
	Items: { [number]: InventoryItem }, -- Slot index -> Item
	Hotbar: { [number]: number },       -- Hotbar slot -> Inventory slot index
	Capacity: number,
	Weight: number,
	MaxWeight: number,
}

export type PlayerProfile = {
	UserId: UserId,
	Username: string,
	DisplayName: string,
	Stats: PlayerStats,
	Currency: Currency,
	Loadout: Loadout,
	Inventory: Inventory,
	SelectedSkin: string,
	OwnedSkins: { [string]: boolean },
	OwnedWeaponSkins: { [string]: boolean },
	OwnedEmotes: { [string]: boolean },
	Settings: PlayerSettings,
	LastLogin: number,
	Version: string,
}

export type PlayerSettings = {
	Graphics: GraphicsSettings,
	Audio: AudioSettings,
	Controls: ControlSettings,
	Gameplay: GameplaySettings,
}

export type GraphicsSettings = {
	Quality: number, -- 1-5
	Resolution: Vector2,
	Fullscreen: boolean,
	VSync: boolean,
	FOV: number,
	Shadows: boolean,
	Particles: boolean,
}

export type AudioSettings = {
	MasterVolume: number,
	SFXVolume: number,
	MusicVolume: number,
	VoiceVolume: number,
	VoiceChat: boolean,
	PushToTalk: boolean,
}

export type ControlSettings = {
	Keybinds: { [string]: Enum.KeyCode },
	Sensitivity: number,
	ADSMultiplier: number,
	InvertY: boolean,
	Vibration: boolean,
}

export type GameplaySettings = {
	AutoReload: boolean,
	AutoPickup: boolean,
	ShowDamageNumbers: boolean,
	ShowKillFeed: boolean,
	CrosshairStyle: string,
	CrosshairColor: Color3,
}

-- Match Data
export type SquadData = {
	SquadId: SquadId,
	Leader: UserId,
	Members: { [UserId]: SquadMember },
	Loadouts: { [UserId]: Loadout },
	Skins: { [UserId]: string },
}

export type SquadMember = {
	UserId: UserId,
	Username: string,
	IsLeader: boolean,
	IsReady: boolean,
	Loadout: Loadout,
	Skin: string,
}

export type MatchData = {
	MatchId: MatchId,
	Map: string,
	StartTime: number,
	EndTime: number?,
	Players: { [UserId]: MatchPlayerData },
	Squads: { [SquadId]: SquadData },
	Winner: SquadId?,
	FinalCircle: ZoneData?,
}

export type MatchPlayerData = {
	UserId: UserId,
	SquadId: SquadId,
	Kills: number,
	Damage: number,
	SurvivalTime: number,
	Placement: number?,
	Rewards: Currency,
}

export type ZoneData = {
	Center: Vector3,
	Radius: number,
	Phase: ZonePhase,
	PhaseEndTime: number,
	IsShrinking: boolean,
	NextCenter: Vector3?,
	NextRadius: number?,
}

-- Weapon Data
export type WeaponStats = {
	Damage: number,
	FireRate: number, -- RPM
	MuzzleVelocity: number,
	Range: number,
	RecoilPattern: { [number]: Vector2 }, -- Shot index -> (vertical, horizontal)
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

export type WeaponTemplate = {
	Id: string,
	Name: string,
	Class: WeaponClass,
	Model: string, -- Asset ID
	ViewModel: string,
	Icon: string,
	Stats: WeaponStats,
	Attachments: { [string]: { string } }, -- Slot -> { AttachmentIds }
	DefaultAttachments: { [string]: string }?,
	Animations: { [string]: string },
	Sounds: { [string]: string },
	Rarity: Rarity,
	Price: Currency,
}

-- Item Definition
export type ItemTemplate = {
	Id: string,
	Name: string,
	Category: ItemCategory,
	SubCategory: string?,
	Description: string,
	Model: string?,
	Icon: string,
	StackSize: number,
	Weight: number,
	Rarity: Rarity,
	Price: Currency?,
	UseFunction: string?, -- Server function name
	UseTime: number?,
	Cooldown: number?,
	Metadata: { [string]: any }?, -- Ammo: { Caliber, Count }, Med: { HealAmount, HealTime, MaxHealth }
}

-- Attachment
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
	Rarity: Rarity,
	Price: Currency?,
}

-- Vehicle
export type VehicleTemplate = {
	Id: string,
	Name: string,
	Model: string,
	Seats: number,
	Health: number,
	MaxSpeed: number,
	Acceleration: number,
	Handling: number,
	FuelCapacity: number,
	FuelConsumption: number,
	EngineSound: string,
	HornSound: string,
	SpawnChance: number,
	Rarity: Rarity,
}

-- Loot Spawn
export type LootTable = {
	[ItemCategory]: { [string]: number }, -- Category -> { ItemId -> Weight }
}

export type LootZone = {
	Name: string,
	Center: Vector3,
	Radius: number,
	LootTable: LootTable,
	MinItems: number,
	MaxItems: number,
	RespawnTime: number,
	Tier: number, -- 1-5
}

-- Network Payloads
export type RemotePayload = {
	[string]: any,
}

export type WeaponFirePayload = {
	WeaponId: string,
	Origin: Vector3,
	Direction: Vector3,
	Timestamp: number,
	ShotIndex: number,
	Seed: number,
}

export type WeaponHitPayload = {
	WeaponId: string,
	Target: Player | BasePart,
	HitPosition: Vector3,
	HitNormal: Vector3,
	HitMaterial: Enum.Material,
	ShotIndex: number,
	Timestamp: number,
	Damage: number,
	IsHeadshot: boolean,
	Penetrated: boolean,
}

export type MovementUpdatePayload = {
	Position: Vector3,
	Velocity: Vector3,
	Stance: Stance,
	IsMoving: boolean,
	IsSprinting: boolean,
	IsSliding: boolean,
	Lean: number, -- -1 to 1
	Timestamp: number,
}

export type ZoneUpdatePayload = {
	Center: Vector3,
	CurrentRadius: number,
	TargetRadius: number,
	Phase: ZonePhase,
	PhaseEndTime: number,
	IsShrinking: boolean,
	NextCenter: Vector3?,
	NextRadius: number?,
}

export type GasEffectPayload = {
	Intensity: number, -- 0-1
	DamagePerTick: number,
	IsInGas: boolean,
}

export type VehicleEnterPayload = {
	VehicleId: string,
	SeatIndex: number,
}

export type VehicleExitPayload = {
	VehicleId: string,
	ExitPosition: Vector3,
}

export type InventoryActionPayload = {
	Action: "Move" | "Split" | "Drop" | "Use" | "Equip" | "Unequip" | "Attach" | "Detach",
	FromSlot: number,
	ToSlot: number?,
	Quantity: number?,
	ItemId: string?,
}

export type MatchmakingPayload = {
	Action: "JoinQueue" | "LeaveQueue" | "JoinSquad" | "LeaveSquad" | "ReadyUp" | "SelectMap",
	SquadId: SquadId?,
	Map: string?,
}

-- Utility Types
export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
}

export type Promise<T> = {
	andThen: (self: Promise<T>, onResolved: (T) -> any) -> Promise<any>,
	catch: (self: Promise<T>, onRejected: (any) -> any) -> Promise<T>,
	finally: (self: Promise<T>, onFinally: () -> any) -> Promise<T>,
	await: (self: Promise<T>) -> T,
}

export type Trove = {
	Add: (self: Trove, object: any, cleanupMethod: string?, key: any?) -> any,
	Remove: (self: Trove, key: any) -> boolean,
	Clean: (self: Trove) -> (),
	AttachToInstance: (self: Trove, instance: Instance) -> (),
}

export type TableUtil = {
	Copy: <T>(table: T) -> T,
	DeepCopy: <T>(table: T) -> T,
	FastRemove: <T>(table: { T }, index: number) -> T,
	FastRemoveFirstValue: <T>(table: { T }, value: T, startIndex: number?) -> number?,
	Shuffle: <T>(table: { T }) -> { T },
	Flat: <T>(table: { { T } }) -> { T },
	Map: <T, U>(table: { T }, callback: (T, number) -> U) -> { U },
	Filter: <T>(table: { T }, callback: (T, number) -> boolean) -> { T },
	Reduce: <T, U>(table: { T }, callback: (U, T, number) -> U, initial: U) -> U,
	Assign: <T>(target: T, ...sources: { T }) -> T,
	Extend: <T>(target: T, ...sources: { T }) -> T,
	Reverse: <T>(table: { T }) -> { T },
	Keys: <K, V>(table: { [K]: V }) -> { K },
	Values: <K, V>(table: { [K]: V }) -> { V },
	Find: <T>(table: { T }, callback: (T, number) -> boolean) -> (T?, number?),
	Every: <T>(table: { T }, callback: (T, number) -> boolean) -> boolean,
	Some: <T>(table: { T }, callback: (T, number) -> boolean) -> boolean,
	Truncate: <T>(table: { T }, length: number) -> { T },
}

-- DataStore Types
export type ProfileData = {
	Data: PlayerProfile,
	MetaData: {
		ProfileCreateTime: number,
		SessionLoadCount: number,
		ActiveSession: { string }?,
		ForceLoadSession: string?,
		MetaTags: { [string]: any }?,
	},
	RobloxMetaData: {
		UserId: number,
		Username: string,
		DisplayName: string,
	},
	GlobalUpdates: {
		[number]: {
			ID: number,
			Data: any,
			LockedBy: string?,
			AddedTime: number,
		},
	},
}

export type DataStoreOptions = {
	RetryCount: number?,
	RetryDelay: number?,
	Timeout: number?,
}

return nil -- Module type definition only