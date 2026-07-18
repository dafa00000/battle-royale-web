// ============================================
// VIEWMODEL - FPS Weapon View (Hands + AK-74)
// Procedural 3D model (no external GLB needed)
// ============================================

import * as THREE from 'three';

export class ViewModel {
  public group: THREE.Group;
  private scene: THREE.Scene;
  private camera: THREE.Camera;

  // Offset position (bottom-right corner)
  private readonly ORIGIN = new THREE.Vector3(0.28, -0.28, -0.55);
  private readonly ORIGIN_ROT = new THREE.Euler(0.05, 0.12, 0.02);

  // Sway state
  private swayX = 0;
  private swayY = 0;
  private swayTargetX = 0;
  private swayTargetY = 0;

  // Recoil state
  private recoilPos = new THREE.Vector3(0, 0, 0);
  private recoilRot = new THREE.Vector3(0, 0, 0);
  private recoilPunch = 0;

  // Reload animation
  private isReloading = false;
  private reloadTime = 0;
  private readonly RELOAD_DURATION = 2.2;

  // Bob (walking)
  private bobTime = 0;
  private bobIntensity = 0;

  constructor(scene: THREE.Scene, camera: THREE.Camera) {
    this.scene = scene;
    this.camera = camera;
    this.group = new THREE.Group();
    this.group.name = 'viewModel';
    this.buildProceduralWeapon();
    this.applyOrigin();
    camera.add(this.group);
    scene.add(camera); // ensure camera is in scene
  }

  // ============================================
  // Procedural AK-74 + Hands (no external asset)
  // ============================================
  private buildProceduralWeapon(): void {
    const weapon = new THREE.Group();
    weapon.name = 'AK74';
    this.group.add(weapon);

    // === Receiver (main body) ===
    const receiverMat = new THREE.MeshStandardMaterial({
      color: 0x1a1a1e, roughness: 0.55, metalness: 0.65,
    });
    const receiverGeo = new THREE.BoxGeometry(0.08, 0.1, 0.28);
    const receiver = new THREE.Mesh(receiverGeo, receiverMat);
    receiver.position.set(0, 0, -0.14);
    weapon.add(receiver);

    // === Barrel ===
    const barrelMat = new THREE.MeshStandardMaterial({
      color: 0x0e0e10, roughness: 0.35, metalness: 0.85,
    });
    const barrelGeo = new THREE.CylinderGeometry(0.014, 0.014, 0.34, 12);
    const barrel = new THREE.Mesh(barrelGeo, barrelMat);
    barrel.rotation.x = Math.PI / 2;
    barrel.position.set(0, 0.01, -0.42);
    weapon.add(barrel);

    // === Front sight block ===
    const sightGeo = new THREE.BoxGeometry(0.02, 0.035, 0.04);
    const frontSight = new THREE.Mesh(sightGeo, barrelMat);
    frontSight.position.set(0, 0.045, -0.56);
    weapon.add(frontSight);

    // Rear sight
    const rearSight = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.02, 0.03), receiverMat);
    rearSight.position.set(0, 0.062, -0.02);
    weapon.add(rearSight);

    // === Magazine (curved banana mag look) ===
    const magMat = new THREE.MeshStandardMaterial({
      color: 0x222528, roughness: 0.7, metalness: 0.3,
    });
    const magGroup = new THREE.Group();
    // Simulate curve with 3 stacked boxes
    const magTop = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.04, 0.08), magMat);
    magTop.position.set(0, -0.07, -0.05);
    magGroup.add(magTop);
    const magMid = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.05, 0.07), magMat);
    magMid.position.set(0.005, -0.11, -0.02);
    magMid.rotation.x = -0.2;
    magGroup.add(magMid);
    const magBot = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.05, 0.06), magMat);
    magBot.position.set(0.012, -0.15, 0.01);
    magBot.rotation.x = -0.4;
    magGroup.add(magBot);
    weapon.add(magGroup);

    // === Handguard (wooden foregrip) ===
    const woodMat = new THREE.MeshStandardMaterial({
      color: 0x4a3420, roughness: 0.85, metalness: 0.05,
    });
    const handguardGeo = new THREE.BoxGeometry(0.07, 0.055, 0.16);
    const handguard = new THREE.Mesh(handguardGeo, woodMat);
    handguard.position.set(0, -0.005, -0.26);
    weapon.add(handguard);

    // === Pistol grip ===
    const gripGeo = new THREE.BoxGeometry(0.04, 0.09, 0.04);
    const grip = new THREE.Mesh(gripGeo, woodMat);
    grip.position.set(0.005, -0.07, 0.0);
    grip.rotation.x = 0.18;
    weapon.add(grip);

    // === Stock ===
    const stockMat = new THREE.MeshStandardMaterial({
      color: 0x3a2a18, roughness: 0.88, metalness: 0.02,
    });
    const stockGroup = new THREE.Group();
    const stockMain = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.06, 0.12), stockMat);
    stockMain.position.set(0, -0.02, 0.14);
    stockGroup.add(stockMain);
    const stockEnd = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.08, 0.03), stockMat);
    stockEnd.position.set(0, -0.025, 0.21);
    stockGroup.add(stockEnd);
    weapon.add(stockGroup);

    // === Hands ===
    const skinMat = new THREE.MeshStandardMaterial({
      color: 0xc8a070, roughness: 0.92, metalness: 0.0,
    });
    const gloveMat = new THREE.MeshStandardMaterial({
      color: 0x1a1a1a, roughness: 0.88, metalness: 0.05,
    });

    // Right hand (front, on handguard)
    const rightHand = new THREE.Mesh(new THREE.BoxGeometry(0.07, 0.05, 0.09), gloveMat);
    rightHand.position.set(0.02, -0.04, -0.26);
    rightHand.rotation.y = -0.08;
    weapon.add(rightHand);

    // Knuckle detail (right)
    const knucklesR = new THREE.Mesh(new THREE.BoxGeometry(0.045, 0.025, 0.05), skinMat);
    knucklesR.position.set(0.005, -0.02, -0.235);
    weapon.add(knucklesR);

    // Left hand (on pistol grip)
    const leftHand = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.055, 0.07), gloveMat);
    leftHand.position.set(-0.005, -0.05, 0.0);
    weapon.add(leftHand);

    // Left wrist/arm extending offscreen
    const leftArm = new THREE.Mesh(new THREE.BoxGeometry(0.07, 0.07, 0.18), gloveMat);
    leftArm.position.set(-0.005, -0.09, 0.13);
    leftArm.rotation.x = -0.25;
    weapon.add(leftArm);

    // Muzzle flash (hidden, toggled on fire)
    const flashMat = new THREE.MeshBasicMaterial({
      color: 0xffaa33, transparent: true, opacity: 0, side: THREE.DoubleSide,
    });
    const flashGeo = new THREE.PlaneGeometry(0.12, 0.12);
    const muzzleFlash = new THREE.Mesh(flashGeo, flashMat);
    muzzleFlash.position.set(0, 0.01, -0.6);
    muzzleFlash.name = 'muzzleFlashVM';
    weapon.add(muzzleFlash);

    // === Shadow-catch checkbox ===
    weapon.traverse(obj => {
      if (obj instanceof THREE.Mesh) {
        obj.castShadow = true;
        obj.frustumCulled = false;
      }
    });
  }

  private applyOrigin(): void {
    this.group.position.copy(this.ORIGIN);
    this.group.rotation.copy(this.ORIGIN_ROT);
  }

  // ============================================
  // SWAY (weapon follows camera look)
  // ============================================
  updateSway(lookDx: number, lookDy: number, delta: number): void {
    // Target offsets based on look delta (drag speed)
    this.swayTargetX = -lookDx * 0.015;
    this.swayTargetY = -lookDy * 0.015;

    // Clamp
    this.swayTargetX = Math.max(-0.05, Math.min(0.05, this.swayTargetX));
    this.swayTargetY = Math.max(-0.05, Math.min(0.05, this.swayTargetY));

    // Lerp to target
    const lerpAmt = 1 - Math.pow(0.001, delta);
    this.swayX = THREE.MathUtils.lerp(this.swayX, this.swayTargetX, lerpAmt);
    this.swayY = THREE.MathUtils.lerp(this.swayY, this.swayTargetY, lerpAmt);

    // Spring back when not moving
    this.swayTargetX *= 0.9;
    this.swayTargetY *= 0.9;
  }

  // ============================================
  // RECOIL PUNCH (on fire)
  // ============================================
  triggerRecoil(): void {
    this.recoilPunch = 1.0;
    // Random side-to-side kick
    this.recoilPos.x = (Math.random() - 0.5) * 0.012;
    this.recoilRot.z = (Math.random() - 0.5) * 0.03;
  }

  private updateRecoil(delta: number): void {
    // Apply punch
    const kick = this.recoilPunch;
    this.recoilPos.z = kick * 0.04;  // backward
    this.recoilPos.y = kick * 0.025; // up
    this.recoilRot.x = kick * 0.08;  // tilt up

    // Decay
    this.recoilPunch = Math.max(0, this.recoilPunch - delta * 5);

    // Lerp recoil back to 0
    if (this.recoilPunch <= 0) {
      this.recoilPos.lerp(new THREE.Vector3(0, 0, 0), delta * 12);
      this.recoilRot.lerp(new THREE.Vector3(0, 0, 0), delta * 12);
    }
  }

  // ============================================
  // RELOAD ANIMATION
  // ============================================
  triggerReload(): void {
    if (this.isReloading) return;
    this.isReloading = true;
    this.reloadTime = 0;
  }

  private updateReload(delta: number): void {
    if (!this.isReloading) return;
    this.reloadTime += delta;
    const t = this.reloadTime / this.RELOAD_DURATION;

    if (t >= 1) {
      this.isReloading = false;
      this.reloadTime = 0;
      this.group.rotation.x = this.ORIGIN_ROT.x;
      this.group.position.y = this.ORIGIN.y;
      return;
    }

    // Dip the weapon down + rotate (magazine swap motion)
    if (t < 0.4) {
      // Dipping down
      const k = t / 0.4;
      this.group.rotation.x = this.ORIGIN_ROT.x + k * 0.5;
      this.group.position.y = this.ORIGIN.y - k * 0.08;
    } else if (t < 0.7) {
      // Hold down (magazine swap)
      this.group.rotation.x = this.ORIGIN_ROT.x + 0.5;
      this.group.position.y = this.ORIGIN.y - 0.08;
    } else {
      // Return up
      const k = (t - 0.7) / 0.3;
      const ease = 1 - Math.pow(1 - k, 3);
      this.group.rotation.x = this.ORIGIN_ROT.x + 0.5 - ease * 0.5;
      this.group.position.y = this.ORIGIN.y - 0.08 + ease * 0.08;
    }
  }

  // ============================================
  // WALK BOB
  // ============================================
  updateBob(isMoving: boolean, isSprinting: boolean, delta: number): void {
    if (isMoving) {
      this.bobTime += delta * (isSprinting ? 12 : 8);
      const intensity = isSprinting ? 0.015 : 0.008;
      this.bobIntensity = THREE.MathUtils.lerp(this.bobIntensity, intensity, delta * 10);
    } else {
      this.bobIntensity = THREE.MathUtils.lerp(this.bobIntensity, 0, delta * 5);
    }
  }

  // ============================================
  // MUZZLE FLASH
  // ============================================
  showMuzzleFlash(): void {
    const flash = this.group.getObjectByName('muzzleFlashVM') as THREE.Mesh;
    if (!flash) return;
    const mat = flash.material as THREE.MeshBasicMaterial;
    mat.opacity = 1;
    flash.scale.setScalar(0.7 + Math.random() * 0.6);
    flash.rotation.z = Math.random() * Math.PI * 2;
  }

  // ============================================
  // MAIN UPDATE (called each frame)
  // ============================================
  update(delta: number, isMoving: boolean, isSprinting: boolean): void {
    this.updateBob(isMoving, isSprinting, delta);

    // Compute final transform
    this.updateRecoil(delta);
    this.updateReload(delta);

    // Don't override position during reload (handled separately)
    if (!this.isReloading) {
      // Base offset + sway + bob + recoil
      const bobY = Math.sin(this.bobTime) * this.bobIntensity;
      const bobX = Math.cos(this.bobTime * 0.5) * this.bobIntensity * 0.6;

      this.group.position.set(
        this.ORIGIN.x + this.swayX + bobX + this.recoilPos.x,
        this.ORIGIN.y + this.swayY + bobY + this.recoilPos.y,
        this.ORIGIN.z + this.recoilPos.z
      );
      this.group.rotation.set(
        this.ORIGIN_ROT.x + this.recoilRot.x,
        this.ORIGIN_ROT.y + this.swayX * 0.5,
        this.ORIGIN_ROT.z + this.recoilRot.z
      );
    }

    // Fade muzzle flash
    const flash = this.group.getObjectByName('muzzleFlashVM') as THREE.Mesh;
    if (flash) {
      const mat = flash.material as THREE.MeshBasicMaterial;
      mat.opacity = Math.max(0, mat.opacity - delta * 8);
    }
  }

  getWeaponGroup(): THREE.Group {
    return this.group;
  }
}
