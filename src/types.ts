// ============================================
// TYPES - Battle Royale Web
// ============================================

export type Vector3 = [number, number, number];
export type Stance = 'Stand' | 'Crouch' | 'Prone';
export type WeaponClass = 'AR' | 'SMG' | 'SR' | 'DMR' | 'SG' | 'Pistol' | 'Melee' | 'Throw';

export interface WeaponStats {
  Damage: number;
  FireRate: number;
  MuzzleVelocity: number;
  Range: number;
  RecoilPattern: Record<number, Vector3>;
  RecoilRecovery: number;
  Spread: number;
  SpreadADS: number;
  SpreadMove: number;
  SpreadJump: number;
  ReloadTime: number;
  TacticalReloadTime: number;
  MagSize: number;
  AmmoType: string;
  Weight: number;
  AdsTime: number;
  Sway: number;
  Penetration: number;
  BulletDrop: number;
}

export interface WeaponTemplate {
  Id: string;
  Name: string;
  Class: WeaponClass;
  Model: string;
  ViewModel: string;
  Icon: string;
  Stats: WeaponStats;
  Attachments: Record<string, string[]>;
  DefaultAttachments?: Record<string, string>;
  Animations: Record<string, string>;
  Sounds: Record<string, string>;
  Rarity: string;
  Price: { Cash: number; Credits: number };
}

export interface PlayerState {
  position: Vector3;
  velocity: Vector3;
  stance: Stance;
  isMoving: boolean;
  isSprinting: boolean;
  isSliding: boolean;
  isADS: boolean;
  lean: number;
  health: number;
  armor: number;
  maxHealth: number;
  maxArmor: number;
  currentWeapon: WeaponTemplate | null;
  ammo: number;
  maxAmmo: number;
  fireMode: 'auto' | 'semi';
  stanceTransitionTime: number;
  slideEndTime: number;
  leanTarget: number;
}

export interface ZoneState {
  center: Vector3;
  radius: number;
  phase: number;
  phaseEndTime: number;
  isShrinking: boolean;
  nextCenter?: Vector3;
  nextRadius?: number;
  damagePerTick: number;
  tickInterval: number;
}

export interface GameState {
  player: PlayerState;
  zone: ZoneState;
  alivePlayers: number;
  currentPhase: number;
  matchTime: number;
  isInGas: boolean;
  gasIntensity: number;
}

export interface KillFeedEntry {
  killer: string;
  victim: string;
  weapon: string;
  timestamp: number;
}

export interface ZoneWarningData {
  phase: number;
  message: string;
}