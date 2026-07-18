// ============================================
// BATTLE ROYALE WEB - CONSTANTS
// Converted from Luau Constants.luau
// ============================================

export const CONSTANTS = {
  // Game Config
  GAME_NAME: 'BattleRoyale',
  VERSION: '0.1.0',
  MAX_PLAYERS: 100,
  MIN_PLAYERS: 50,

  // Map
  MAP_RADIUS: 2500,
  MAP_SIZE: 5000,

  // Safe Zone Phases (duration in seconds, radius in studs, damage per tick, tick interval, warning time)
  ZONE_PHASES: [
    { duration: 180, radius: 1500, damagePerTick: 2, tickInterval: 2, warningTime: 30 },
    { duration: 150, radius: 1000, damagePerTick: 5, tickInterval: 1.5, warningTime: 30 },
    { duration: 120, radius: 600, damagePerTick: 10, tickInterval: 1, warningTime: 20 },
    { duration: 90, radius: 300, damagePerTick: 20, tickInterval: 0.75, warningTime: 15 },
    { duration: 60, radius: 100, damagePerTick: 35, tickInterval: 0.5, warningTime: 10 },
    { duration: 30, radius: 50, damagePerTick: 50, tickInterval: 0.3, warningTime: 5 },
  ],
  INITIAL_ZONE_RADIUS: 2000,
  FINAL_ZONE_RADIUS: 50,

  // Combat
  BULLET_SPEED: 800,
  BULLET_DROP: 0.05,
  MAX_PENETRATION: 2,
  HEADSHOT_MULTIPLIER: 2.0,
  LIMB_MULTIPLIER: 0.7,
  BASE_DAMAGE: {
    AR: 35, SMG: 25, SR: 90, DMR: 55, SG: 12, Pistol: 28, Melee: 40,
  },

  // Movement
  WALK_SPEED: 14,
  RUN_SPEED: 20,
  SPRINT_SPEED: 28,
  CROUCH_SPEED: 6,
  PRONE_SPEED: 3,
  JUMP_POWER: 45,
  SLIDE_SPEED: 35,
  SLIDE_DURATION: 1.2,
  SLIDE_COOLDOWN: 2.5,
  VAULT_HEIGHT: 4.5,
  VAULT_DURATION: 0.6,
  STANCE_TRANSITION: 0.3,

  // Inventory
  INVENTORY_SLOTS: 30,
  HOTBAR_SLOTS: 5,
  MAX_STACK: { Ammo: 200, Med: 5, Throw: 3, Attachment: 1, Consumable: 10 },

  // Audio
  AUDIO_ROLLOFF: {
    Footsteps: { min: 10, max: 60 },
    Gunfire: { min: 50, max: 500 },
    Vehicle: { min: 30, max: 300 },
    Explosion: { min: 100, max: 1000 },
  },

  // UI Theme
  UI_THEME: {
    Background: '#141414',
    Surface: '#1e1e1e',
    Primary: '#00b4ff',
    Secondary: '#ff8c00',
    Danger: '#dc3232',
    Success: '#32c864',
    Text: '#f0f0f0',
    TextMuted: '#a0a0a0',
    Border: '#3c3c3c',
    Overlay: 'rgba(0,0,0,0.85)',
  },

  // Keybinds
  KEYBINDS: {
    MoveForward: 'KeyW', MoveBackward: 'KeyS', MoveLeft: 'KeyA', MoveRight: 'KeyD',
    Jump: 'Space', Crouch: 'KeyC', Prone: 'KeyZ', Sprint: 'ShiftLeft',
    Slide: 'ControlLeft', Interact: 'KeyE', Reload: 'KeyR',
    Fire: 'Mouse0', ADS: 'Mouse1', Melee: 'KeyV', Grenade: 'KeyG',
    Inventory: 'Tab', Map: 'KeyM', PushToTalk: 'KeyT', LeanLeft: 'KeyQ', LeanRight: 'KeyE',
  },
} as const;

export type ZonePhase = typeof CONSTANTS.ZONE_PHASES[number];
export type WeaponClass = keyof typeof CONSTANTS.BASE_DAMAGE;