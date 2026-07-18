// ============================================
// WEAPON SYSTEM
// ============================================

import * as THREE from 'three';
import { GameState, WeaponTemplate, Vector3 } from '../types';
import { CONSTANTS } from '../constants';

export interface WeaponInstance {
  template: WeaponTemplate;
  currentAmmo: number;
  reserveAmmo: number;
  fireMode: 'auto' | 'semi';
  lastFireTime: number;
  recoil: { pitch: number; yaw: number };
  spread: number;
  isReloading: boolean;
  reloadEndTime: number;
  shotIndex: number;
}

const WEAPONS: Record<string, WeaponTemplate> = {
  AK74: {
    Id: 'AK74', Name: 'AK-74', Class: 'AR',
    Stats: {
      Damage: 36, FireRate: 600, MuzzleVelocity: 800, Range: 600,
      RecoilPattern: {}, RecoilRecovery: 8, Spread: 0.003, SpreadADS: 0.0015,
      SpreadMove: 0.005, SpreadJump: 0.02,
      ReloadTime: 2.8, TacticalReloadTime: 2.2, MagSize: 30, AmmoType: '545x39',
      Weight: 3.5, AdsTime: 0.18, Sway: 0.02, Penetration: 1.5, BulletDrop: 0.05,
    },
    Attachments: {}, Animations: {}, Sounds: {}, Rarity: 'Common', Price: { Cash: 0, Credits: 0 },
  },
  M416: {
    Id: 'M416', Name: 'M416', Class: 'AR',
    Stats: {
      Damage: 35, FireRate: 750, MuzzleVelocity: 850, Range: 650,
      RecoilPattern: {}, RecoilRecovery: 9, Spread: 0.0025, SpreadADS: 0.0012,
      SpreadMove: 0.004, SpreadJump: 0.018,
      ReloadTime: 2.6, TacticalReloadTime: 2.0, MagSize: 30, AmmoType: '556x45',
      Weight: 3.3, AdsTime: 0.16, Sway: 0.015, Penetration: 1.4, BulletDrop: 0.04,
    },
    Attachments: {}, Animations: {}, Sounds: {}, Rarity: 'Uncommon', Price: { Cash: 500, Credits: 50 },
  },
  AWM: {
    Id: 'AWM', Name: 'AWM', Class: 'SR',
    Stats: {
      Damage: 120, FireRate: 35, MuzzleVelocity: 900, Range: 1200,
      RecoilPattern: {}, RecoilRecovery: 5, Spread: 0.0005, SpreadADS: 0.0001,
      SpreadMove: 0.003, SpreadJump: 0.01,
      ReloadTime: 3.5, TacticalReloadTime: 3.0, MagSize: 5, AmmoType: '300wm',
      Weight: 6.5, AdsTime: 0.25, Sway: 0.03, Penetration: 3.0, BulletDrop: 0.03,
    },
    Attachments: {}, Animations: {}, Sounds: {}, Rarity: 'Legendary', Price: { Cash: 5000, Credits: 500 },
  },
};

export class WeaponSystem {
  private state: GameState;
  private camera: THREE.Camera;
  private scene: THREE.Scene;
  private rayCaster: THREE.Raycaster;
  private currentWeapon: WeaponInstance | null = null;
  private isFiring = false;
  private fireInterval: number | null = null;
  private muzzleFlash: THREE.Mesh | null = null;
  private bulletTrails: THREE.Line[] = [];

  constructor(state: GameState, camera: THREE.Camera, scene: THREE.Scene) {
    this.state = state;
    this.camera = camera;
    this.scene = scene;
    this.rayCaster = new THREE.Raycaster();
    this.rayCaster.far = 2000;
    this.createMuzzleFlash();
  }

  private createMuzzleFlash(): void {
    const geo = new THREE.PlaneGeometry(0.5, 0.5);
    const mat = new THREE.MeshBasicMaterial({
      color: 0xffaa00, transparent: true, opacity: 0, side: THREE.DoubleSide,
    });
    this.muzzleFlash = new THREE.Mesh(geo, mat);
    this.muzzleFlash.name = 'muzzleFlash';
    this.camera.add(this.muzzleFlash);
    this.muzzleFlash.position.set(0.3, -0.2, -0.5);
  }

  equipWeapon(weaponId: string): void {
    const template = WEAPONS[weaponId];
    if (!template) return;

    this.currentWeapon = {
      template,
      currentAmmo: template.Stats.MagSize,
      reserveAmmo: template.Stats.MagSize * 4,
      fireMode: 'auto',
      lastFireTime: 0,
      recoil: { pitch: 0, yaw: 0 },
      spread: template.Stats.Spread,
      isReloading: false,
      reloadEndTime: 0,
      shotIndex: 0,
    };

    this.state.player.currentWeapon = template;
    this.state.player.maxAmmo = template.Stats.MagSize;
    this.state.player.ammo = template.Stats.MagSize;
    this.state.player.fireMode = 'auto';
  }

  fire(): void {
    if (!this.currentWeapon || this.currentWeapon.isReloading) return;
    if (this.currentWeapon.currentAmmo <= 0) { this.reload(); return; }

    const now = performance.now();
    const fireRate = this.currentWeapon.template.Stats.FireRate;
    const fireInterval = 60000 / fireRate; // ms between shots

    if (now - this.currentWeapon.lastFireTime < fireInterval) return;

    this.currentWeapon.lastFireTime = now;
    this.currentWeapon.currentAmmo--;
    this.state.player.ammo = this.currentWeapon.currentAmmo;
    this.currentWeapon.shotIndex++;

    this.applyRecoil();
    this.playMuzzleFlash();
    this.simulateBullet();
  }

  stopFire(): void {
    // For semi-auto or when releasing trigger
    if (this.fireInterval) {
      clearInterval(this.fireInterval);
      this.fireInterval = null;
    }
    this.isFiring = false;
  }

  toggleFireMode(): void {
    if (!this.currentWeapon) return;
    this.currentWeapon.fireMode = this.currentWeapon.fireMode === 'auto' ? 'semi' : 'auto';
    this.state.player.fireMode = this.currentWeapon.fireMode;
  }

  reload(): void {
    if (!this.currentWeapon || this.currentWeapon.isReloading) return;
    if (this.currentWeapon.currentAmmo === this.currentWeapon.template.Stats.MagSize) return;
    if (this.currentWeapon.reserveAmmo <= 0) return;

    this.currentWeapon.isReloading = true;
    const isTactical = this.currentWeapon.currentAmmo > 0;
    const reloadTime = isTactical
      ? this.currentWeapon.template.Stats.TacticalReloadTime
      : this.currentWeapon.template.Stats.ReloadTime;

    this.currentWeapon.reloadEndTime = reloadTime;

    // Animation would go here
    setTimeout(() => {
      if (!this.currentWeapon) return;
      const needed = this.currentWeapon.template.Stats.MagSize - this.currentWeapon.currentAmmo;
      const taken = Math.min(needed, this.currentWeapon.reserveAmmo);
      this.currentWeapon.currentAmmo += taken;
      this.currentWeapon.reserveAmmo -= taken;
      this.state.player.ammo = this.currentWeapon.currentAmmo;
      this.currentWeapon.isReloading = false;
    }, reloadTime * 1000);
  }

  melee(): void {
    console.log('Melee attack!');
    // Raycast forward, deal melee damage
  }

  throwGrenade(): void {
    console.log('Throw grenade!');
    // Physics projectile
  }

  update(delta: number): void {
    if (!this.currentWeapon) return;

    // Update recoil recovery
    this.currentWeapon.recoil.pitch *= Math.max(0, 1 - this.currentWeapon.template.Stats.RecoilRecovery * delta);
    this.currentWeapon.recoil.yaw *= Math.max(0, 1 - this.currentWeapon.template.Stats.RecoilRecovery * delta);

    // Update reload timer
    if (this.currentWeapon.isReloading) {
      this.currentWeapon.reloadEndTime -= delta;
      if (this.currentWeapon.reloadEndTime <= 0) {
        this.currentWeapon.isReloading = false;
      }
    }

    // Update muzzle flash
    if (this.muzzleFlash) {
      const mat = this.muzzleFlash.material as THREE.MeshBasicMaterial;
      mat.opacity = Math.max(0, mat.opacity - delta * 10);
    }

    // Update bullet trails
    this.bulletTrails.forEach((trail, i) => {
      const ages = (trail.userData as any).age += delta;
      if (ages > 0.1) {
        this.scene.remove(trail);
        this.bulletTrails.splice(i, 1);
      }
    });
  }

  private applyRecoil(): void {
    if (!this.currentWeapon) return;
    const stats = this.currentWeapon.template.Stats;

    // Base recoil
    const vertical = 0.5 + Math.random() * 0.3;
    const horizontal = (Math.random() - 0.5) * 0.4;

    this.currentWeapon.recoil.pitch += vertical;
    this.currentWeapon.recoil.yaw += horizontal;

    // Apply to camera
    this.camera.rotation.x -= vertical * 0.01;
    this.camera.rotation.y += horizontal * 0.01;

    // Spread increase
    this.currentWeapon.spread = Math.min(
      stats.Spread * 3,
      this.currentWeapon.spread + 0.001
    );
  }

  private playMuzzleFlash(): void {
    if (!this.muzzleFlash) return;
    this.muzzleFlash.material.opacity = 1;
    this.muzzleFlash.scale.setScalar(0.8 + Math.random() * 0.4);
    this.muzzleFlash.rotation.z = Math.random() * Math.PI * 2;
  }

  private simulateBullet(): void {
    if (!this.currentWeapon) return;

    const stats = this.currentWeapon.template.Stats;
    const origin = new THREE.Vector3().copy(this.camera.position);
    const direction = new THREE.Vector3(0, 0, -1).applyQuaternion(this.camera.quaternion);

    // Apply spread
    const spread = this.currentWeapon.spread * (this.state.isADS ? 0.3 : 1);
    const spreadVec = new THREE.Vector3(
      (Math.random() - 0.5) * spread,
      (Math.random() - 0.5) * spread,
      (Math.random() - 0.5) * spread
    );
    direction.add(spreadVec).normalize();

    // Raycast
    this.rayCaster.set(origin, direction);
    const intersects = this.rayCaster.intersectObjects(this.scene.children, true);

    // Visual trail
    const trailGeo = new THREE.BufferGeometry();
    const trailPos = new Float32Array([origin.x, origin.y, origin.z, 0, 0, 0]);
    trailGeo.setAttribute('position', new THREE.BufferAttribute(trailPos, 3));
    const trailMat = new THREE.LineBasicMaterial({ color: 0xffaa00, transparent: true, opacity: 0.8 });
    const trail = new THREE.Line(trailGeo, trailMat);
    trail.userData = { age: 0 };
    this.scene.add(trail);
    this.bulletTrails.push(trail);

    if (intersects.length > 0) {
      const hit = intersects[0];
      trailGeo.setAttribute('position', new THREE.BufferAttribute(
        new Float32Array([origin.x, origin.y, origin.z, hit.point.x, hit.point.y, hit.point.z]), 3
      ));

      // Hit effect
      this.createHitEffect(hit.point, hit.face?.normal);

      // Damage
      const dmg = this.calculateDamage(stats.Damage, hit.distance);
      console.log(`Hit ${hit.object.name} for ${dmg} damage at ${hit.distance.toFixed(1)}m`);
    } else {
      // Max range
      const end = origin.clone().add(direction.multiplyScalar(stats.Range));
      trailGeo.setAttribute('position', new THREE.BufferAttribute(
        new Float32Array([origin.x, origin.y, origin.z, end.x, end.y, end.z]), 3
      ));
    }
  }

  private calculateDamage(baseDamage: number, distance: number): number {
    const falloff = Math.max(0, 1 - distance / 500);
    return Math.round(baseDamage * falloff);
  }

  private createHitEffect(position: THREE.Vector3, normal?: THREE.Vector3): void {
    // Spark particles
    const geo = new THREE.SphereGeometry(0.05, 4, 4);
    const mat = new THREE.MeshBasicMaterial({ color: 0xffaa00 });
    for (let i = 0; i < 8; i++) {
      const spark = new THREE.Mesh(geo, mat);
      spark.position.copy(position);
      this.scene.add(spark);
      const vel = new THREE.Vector3(
        (Math.random() - 0.5) * 5, Math.random() * 3, (Math.random() - 0.5) * 5
      );
      const animate = () => {
        if (!spark.parent) return;
        spark.position.addScaledVector(vel, 0.016);
        vel.y -= 0.01;
        if (spark.position.y < 0) { this.scene.remove(spark); return; }
        requestAnimationFrame(animate);
      };
      animate();
    }
  }

  getCurrentWeapon(): WeaponInstance | null {
    return this.currentWeapon;
  }
}