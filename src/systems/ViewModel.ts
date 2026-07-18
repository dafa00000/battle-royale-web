// ============================================
// VIEWMODEL - FPS Weapon View (Hands + AK-74)
// Procedural 3D model (no external GLB needed)
// ============================================

import * as THREE from 'three';

export class ViewModel {
  public group: THREE.Group;
  private scene: THREE.Scene;
  private camera: THREE.Camera;

  // Offset position (center-right, higher, closer)
  private readonly ORIGIN = new THREE.Vector3(0.2, -0.15, -0.4);
  private readonly ORIGIN_ROT = new THREE.Euler(0.02, 0.06, 0.0);

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
  // Procedural AK-74 + Hands (authentic materials)
  // ============================================
  private buildProceduralWeapon(): void {
    const weapon = new THREE.Group();
    weapon.name = 'AK74';
    this.group.add(weapon);

    // === Material definitions ===
    // Steel / metal parts (receiver, barrel, sights)
    const steelMat = new THREE.MeshStandardMaterial({
      color: 0x222222, metalness: 0.85, roughness: 0.38,
    });
    // Dark parkerized metal (barrel exterior)
    const darkSteelMat = new THREE.MeshStandardMaterial({
      color: 0x1a1a1d, metalness: 0.82, roughness: 0.45,
    });
    // Wood parts (handguard, stock, pistol grip)
    const woodMat = new THREE.MeshStandardMaterial({
      color: 0x5a2a18, metalness: 0.0, roughness: 0.7,
    });
    // Wood darker grain (stock end)
    const darkWoodMat = new THREE.MeshStandardMaterial({
      color: 0x4a1e10, metalness: 0.0, roughness: 0.75,
    });
    // Polymer / bakelite magazine + grip accents
    const polymerMat = new THREE.MeshStandardMaterial({
      color: 0x151515, metalness: 0.1, roughness: 0.85,
    });
    // Bakelite orange (some AK mags)
    const bakeliteMat = new THREE.MeshStandardMaterial({
      color: 0x6a2a10, metalness: 0.05, roughness: 0.6,
    });
    // Skin (hands/knuckles)
    const skinMat = new THREE.MeshStandardMaterial({
      color: 0xc8a070, roughness: 0.92, metalness: 0.0,
    });
    // Tactical gloves
    const gloveMat = new THREE.MeshStandardMaterial({
      color: 0x14141a, roughness: 0.88, metalness: 0.08,
    });
    // Muzzle flash
    const flashMat = new THREE.MeshBasicMaterial({
      color: 0xffaa33, transparent: true, opacity: 0, side: THREE.DoubleSide,
    });

    // === Receiver (main body — steel) ===
    const receiverGeo = new THREE.BoxGeometry(0.06, 0.085, 0.24);
    const receiver = new THREE.Mesh(receiverGeo, steelMat);
    receiver.position.set(0, 0, -0.12);
    weapon.add(receiver);

    // Receiver top rail (slightly lighter)
    const topRail = new THREE.Mesh(new THREE.BoxGeometry(0.045, 0.012, 0.18), darkSteelMat);
    topRail.position.set(0, 0.048, -0.09);
    weapon.add(topRail);

    // === Barrel (dark steel, parkerized) ===
    const barrelGeo = new THREE.CylinderGeometry(0.012, 0.012, 0.30, 16);
    const barrel = new THREE.Mesh(barrelGeo, darkSteelMat);
    barrel.rotation.x = Math.PI / 2;
    barrel.position.set(0, 0.012, -0.38);
    weapon.add(barrel);

    // Gas block (above barrel)
    const gasBlock = new THREE.Mesh(new THREE.BoxGeometry(0.022, 0.022, 0.05), darkSteelMat);
    gasBlock.position.set(0, 0.026, -0.32);
    weapon.add(gasBlock);

    // Front sight post
    const frontSight = new THREE.Mesh(new THREE.BoxGeometry(0.016, 0.038, 0.035), darkSteelMat);
    frontSight.position.set(0, 0.045, -0.52);
    weapon.add(frontSight);

    // Rear sight (steel)
    const rearSight = new THREE.Mesh(new THREE.BoxGeometry(0.038, 0.018, 0.028), steelMat);
    rearSight.position.set(0, 0.06, -0.01);
    weapon.add(rearSight);

    // === Magazine (bakelite orange-red, banana curve) ===
    const magGroup = new THREE.Group();
    const magTop = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.038, 0.07), bakeliteMat);
    magTop.position.set(0, -0.065, -0.05);
    magGroup.add(magTop);
    const magMid = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.046, 0.06), bakeliteMat);
    magMid.position.set(0.006, -0.10, -0.018);
    magMid.rotation.x = -0.18;
    magGroup.add(magMid);
    const magBot = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.046, 0.055), bakeliteMat);
    magBot.position.set(0.013, -0.14, 0.01);
    magBot.rotation.x = -0.36;
    magGroup.add(magBot);
    // Mag bottom plate
    const magBottom = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.012, 0.05), darkSteelMat);
    magBottom.position.set(0.015, -0.165, 0.025);
    magBottom.rotation.x = -0.36;
    magGroup.add(magBottom);
    weapon.add(magGroup);

    // === Handguard (wood — reddish brown) ===
    const handguardGeo = new THREE.BoxGeometry(0.056, 0.048, 0.16);
    const handguard = new THREE.Mesh(handguardGeo, woodMat);
    handguard.position.set(0, -0.004, -0.25);
    weapon.add(handguard);

    // Lower handguard
    const lowerHG = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.025, 0.12), woodMat);
    lowerHG.position.set(0, -0.029, -0.23);
    weapon.add(lowerHG);

    // === Pistol grip (polymer, dark) ===
    const gripGeo = new THREE.BoxGeometry(0.034, 0.082, 0.038);
    const grip = new THREE.Mesh(gripGeo, polymerMat);
    grip.position.set(0.004, -0.064, 0.0);
    grip.rotation.x = 0.2;
    weapon.add(grip);

    // === Stock (wood — darker reddish) ===
    const stockGroup = new THREE.Group();
    const stockMain = new THREE.Mesh(new THREE.BoxGeometry(0.042, 0.058, 0.11), darkWoodMat);
    stockMain.position.set(0, -0.022, 0.12);
    stockGroup.add(stockMain);
    // Stock end plate
    const stockEnd = new THREE.Mesh(new THREE.BoxGeometry(0.042, 0.078, 0.024), darkWoodMat);
    stockEnd.position.set(0, -0.026, 0.18);
    stockGroup.add(stockEnd);
    // Stock thumb recess
    const thumbRecess = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.025, 0.04), darkWoodMat);
    thumbRecess.position.set(0, 0.002, 0.09);
    stockGroup.add(thumbRecess);
    weapon.add(stockGroup);

    // === Trigger guard + trigger (steel) ===
    const triggerGuard = new THREE.Mesh(new THREE.BoxGeometry(0.004, 0.012, 0.04), darkSteelMat);
    triggerGuard.position.set(0, -0.04, 0.025);
    weapon.add(triggerGuard);
    const trigger = new THREE.Mesh(new THREE.BoxGeometry(0.006, 0.028, 0.008), steelMat);
    trigger.position.set(0, -0.045, 0.022);
    weapon.add(trigger);

    // === Hands (tactical gloves + skin) ===
    // Right hand (forward, on handguard)
    const rightHand = new THREE.Mesh(new THREE.BoxGeometry(0.062, 0.045, 0.082), gloveMat);
    rightHand.position.set(0.018, -0.035, -0.24);
    rightHand.rotation.y = -0.06;
    weapon.add(rightHand);

    // Right knuckles (skin)
    const knucklesR = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.022, 0.045), skinMat);
    knucklesR.position.set(0.003, -0.018, -0.218);
    weapon.add(knucklesR);

    // Left hand (on pistol grip)
    const leftHand = new THREE.Mesh(new THREE.BoxGeometry(0.054, 0.05, 0.063), gloveMat);
    leftHand.position.set(-0.003, -0.046, 0.0);
    weapon.add(leftHand);

    // Left wrist/arm extending offscreen
    const leftArm = new THREE.Mesh(new THREE.BoxGeometry(0.062, 0.062, 0.16), gloveMat);
    leftArm.position.set(-0.003, -0.082, 0.12);
    leftArm.rotation.x = -0.22;
    weapon.add(leftArm);

    // === Muzzle flash (hidden, toggled on fire) ===
    const flashGeo = new THREE.PlaneGeometry(0.1, 0.1);
    const muzzleFlash = new THREE.Mesh(flashGeo, flashMat);
    muzzleFlash.position.set(0, 0.012, -0.56);
    muzzleFlash.name = 'muzzleFlashVM';
    weapon.add(muzzleFlash);

    // === Shadows on all meshes ===
    weapon.traverse(obj => {
      if (obj instanceof THREE.Mesh) {
        obj.castShadow = true;
        obj.frustumCulled = false;
      }
    });

    // === EXCLUSIVE VIEWMODEL LIGHTING ===
    // Point light attached straight to camera, pointing at weapon
    // (added to this.group so it travels with viewmodel)
    const weaponLight = new THREE.PointLight(0xfff0d0, 2.2, 2.5, 1.0);
    weaponLight.position.set(0.0, 0.15, 0.25);
    this.group.add(weaponLight);

    // Subtle fill from below (rim light)
    const weaponFill = new THREE.PointLight(0x88a0ff, 0.6, 2.0, 1.0);
    weaponFill.position.set(-0.1, -0.1, 0.2);
    this.group.add(weaponFill);

    // Top key light (sharp specular on steel)
    const weaponKey = new THREE.SpotLight(0xffe5b0, 1.8, 2.5, Math.PI / 5, 0.4, 1.5);
    weaponKey.position.set(0.1, 0.25, 0.3);
    weaponKey.target.position.set(0, 0, -0.15);
    this.group.add(weaponKey);
    this.group.add(weaponKey.target);
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
