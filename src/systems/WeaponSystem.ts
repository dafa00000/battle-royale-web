// ============================================
// WEAPON SYSTEM (clean, no duplicates)
// ============================================
import * as THREE from 'three';
import type { GameState, WeaponTemplate } from '../types';

interface WeaponInstance {
  template: WeaponTemplate;
  currentAmmo: number;
  reserveAmmo: number;
  fireMode: 'auto' | 'semi';
  lastFireTime: number;
  spread: number;
  isReloading: boolean;
  reloadEndTime: number;
  shotIndex: number;
}

const WEAPONS: Record<string, WeaponTemplate> = {
  AK74: {
    Id: 'AK74', Name: 'AK-74', Class: 'AR', Model: '', ViewModel: '', Icon: '',
    Stats: { Damage: 36, FireRate: 600, MuzzleVelocity: 800, Range: 600,
      RecoilPattern: {}, RecoilRecovery: 8, Spread: 0.003, SpreadADS: 0.0015,
      SpreadMove: 0.005, SpreadJump: 0.02, ReloadTime: 2.8, TacticalReloadTime: 2.2,
      MagSize: 30, AmmoType: '545x39', Weight: 3.5, AdsTime: 0.18, Sway: 0.02,
      Penetration: 1.5, BulletDrop: 0.05 },
    Attachments: {}, Animations: {}, Sounds: {}, Rarity: 'Common', Price: { Cash: 0, Credits: 0 },
  },
};

export class WeaponSystem {
  private state: GameState;
  private camera: THREE.Camera;
  private scene: THREE.Scene;
  private rayCaster: THREE.Raycaster;
  private currentWeapon: WeaponInstance | null = null;
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
    const mat = new THREE.MeshBasicMaterial({ color: 0xffaa00, transparent: true, opacity: 0, side: THREE.DoubleSide });
    this.muzzleFlash = new THREE.Mesh(geo, mat);
    this.muzzleFlash.name = 'muzzleFlash';
    this.muzzleFlash.position.set(0.3, -0.2, -0.5);
    this.camera.add(this.muzzleFlash);
  }

  equipWeapon(weaponId: string): void {
    const template = WEAPONS[weaponId];
    if (!template) return;
    this.currentWeapon = {
      template, currentAmmo: template.Stats.MagSize, reserveAmmo: template.Stats.MagSize * 4,
      fireMode: 'auto', lastFireTime: 0, spread: template.Stats.Spread,
      isReloading: false, reloadEndTime: 0, shotIndex: 0,
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
    const fireInterval = 60000 / this.currentWeapon.template.Stats.FireRate;
    if (now - this.currentWeapon.lastFireTime < fireInterval) return;

    this.currentWeapon.lastFireTime = now;
    this.currentWeapon.currentAmmo--;
    this.state.player.ammo = this.currentWeapon.currentAmmo;
    this.currentWeapon.shotIndex++;

    this.applyRecoil();
    this.playMuzzleFlash();
    this.simulateBullet();
  }

  stopFire(): void {}

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

  melee(): void { console.log('Melee!'); }
  throwGrenade(): void { console.log('Grenade!'); }

  update(delta: number): void {
    if (!this.currentWeapon) return;

    // recoil recovery handled via camera (simplified)
    if (this.currentWeapon.isReloading) {
      this.currentWeapon.reloadEndTime -= delta;
      if (this.currentWeapon.reloadEndTime <= 0) this.currentWeapon.isReloading = false;
    }

    if (this.muzzleFlash) {
      const mat = this.muzzleFlash.material as THREE.MeshBasicMaterial;
      mat.opacity = Math.max(0, mat.opacity - delta * 10);
    }

    for (let i = this.bulletTrails.length - 1; i >= 0; i--) {
      const trail = this.bulletTrails[i];
      const ages = (trail.userData as any).age = ((trail.userData as any).age || 0) + delta;
      if (ages > 0.1) {
        this.scene.remove(trail);
        this.bulletTrails.splice(i, 1);
      }
    }
  }

  private applyRecoil(): void {
    if (!this.currentWeapon) return;
    const stats = this.currentWeapon.template.Stats;
    const vertical = 0.5 + Math.random() * 0.3;
    const horizontal = (Math.random() - 0.5) * 0.4;
    this.camera.rotation.x -= vertical * 0.01;
    this.camera.rotation.y += horizontal * 0.01;
    this.currentWeapon.spread = Math.min(stats.Spread * 3, this.currentWeapon.spread + 0.001);
  }

  private playMuzzleFlash(): void {
    if (!this.muzzleFlash) return;
    const mat = this.muzzleFlash.material as THREE.MeshBasicMaterial;
    mat.opacity = 1;
    this.muzzleFlash.scale.setScalar(0.8 + Math.random() * 0.4);
    this.muzzleFlash.rotation.z = Math.random() * Math.PI * 2;
  }

  private simulateBullet(): void {
    if (!this.currentWeapon) return;
    const stats = this.currentWeapon.template.Stats;
    const origin = new THREE.Vector3().copy(this.camera.position);
    const direction = new THREE.Vector3(0, 0, -1).applyQuaternion(this.camera.quaternion);

    const spread = this.currentWeapon.spread * (this.state.isADS ? 0.3 : 1);
    direction.add(new THREE.Vector3(
      (Math.random() - 0.5) * spread,
      (Math.random() - 0.5) * spread,
      (Math.random() - 0.5) * spread
    )).normalize();

    this.rayCaster.set(origin, direction);
    const intersects = this.rayCaster.intersectObjects(this.scene.children, true);

    const trailGeo = new THREE.BufferGeometry();
    trailGeo.setAttribute('position', new THREE.BufferAttribute(new Float32Array([origin.x, origin.y, origin.z, 0, 0, 0]), 3));
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
      this.createHitEffect(hit.point);
      const dmg = this.calculateDamage(stats.Damage, hit.distance);
      console.log(`Hit ${hit.object.name} for ${dmg} at ${hit.distance.toFixed(1)}m`);
    } else {
      const end = origin.clone().add(direction.clone().multiplyScalar(stats.Range));
      trailGeo.setAttribute('position', new THREE.BufferAttribute(
        new Float32Array([origin.x, origin.y, origin.z, end.x, end.y, end.z]), 3
      ));
    }
  }

  private calculateDamage(baseDamage: number, distance: number): number {
    const falloff = Math.max(0, 1 - distance / 500);
    return Math.round(baseDamage * falloff);
  }

  private createHitEffect(position: THREE.Vector3): void {
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

  getCurrentWeapon(): WeaponInstance | null { return this.currentWeapon; }
}
