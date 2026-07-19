// ============================================
// VIEWMODEL - Simple foolproof FPS weapon (no crash)
// ============================================

import * as THREE from 'three';

export class ViewModel {
  public group: THREE.Group;
  private camera: THREE.Camera;
  private scene: THREE.Scene;
  private readonly ORIGIN = new THREE.Vector3(0.25, -0.2, -0.45);

  constructor(scene: THREE.Scene, camera: THREE.Camera) {
    this.scene = scene;
    this.camera = camera;
    this.group = new THREE.Group();
    this.group.name = 'viewModel';
    this.buildSimpleWeapon();
    this.applyOrigin();
    camera.add(this.group);
    if (!scene.children.includes(camera)) scene.add(camera);
  }

  private buildSimpleWeapon(): void {
    try {
      // Steel body
      const steelMat = new THREE.MeshStandardMaterial({
        color: 0x2a2a2a, metalness: 0.85, roughness: 0.38,
      });
      // Wood handguard/stock
      const woodMat = new THREE.MeshStandardMaterial({
        color: 0x5a2a18, metalness: 0.0, roughness: 0.7,
      });
      // Polymer grip/mag
      const polymerMat = new THREE.MeshStandardMaterial({
        color: 0x1a1a1a, metalness: 0.1, roughness: 0.85,
      });
      // Gloves
      const gloveMat = new THREE.MeshStandardMaterial({
        color: 0x14141a, roughness: 0.88, metalness: 0.05,
      });

      // Body (receiver)
      const body = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.085, 0.24), steelMat);
      body.position.set(0, 0, -0.12);
      this.group.add(body);

      // Barrel
      const barrel = new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.30, 12), steelMat);
      barrel.rotation.x = Math.PI / 2;
      barrel.position.set(0, 0.012, -0.38);
      this.group.add(barrel);

      // Magazine (bakelite orange-red)
      const bakeliteMat = new THREE.MeshStandardMaterial({
        color: 0x6a2a10, metalness: 0.05, roughness: 0.6,
      });
      const mag = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.12, 0.06), bakeliteMat);
      mag.position.set(0.005, -0.12, -0.04);
      mag.rotation.x = -0.2;
      this.group.add(mag);

      // Handguard (wood)
      const handguard = new THREE.Mesh(new THREE.BoxGeometry(0.056, 0.048, 0.16), woodMat);
      handguard.position.set(0, -0.004, -0.25);
      this.group.add(handguard);

      // Stock (wood)
      const stock = new THREE.Mesh(new THREE.BoxGeometry(0.042, 0.058, 0.16), woodMat);
      stock.position.set(0, -0.022, 0.15);
      this.group.add(stock);

      // Grip (polymer)
      const grip = new THREE.Mesh(new THREE.BoxGeometry(0.034, 0.082, 0.038), polymerMat);
      grip.position.set(0.004, -0.064, 0.0);
      grip.rotation.x = 0.2;
      this.group.add(grip);

      // Right hand
      const rightHand = new THREE.Mesh(new THREE.BoxGeometry(0.062, 0.045, 0.082), gloveMat);
      rightHand.position.set(0.018, -0.035, -0.24);
      this.group.add(rightHand);

      // Left hand
      const leftHand = new THREE.Mesh(new THREE.BoxGeometry(0.054, 0.05, 0.063), gloveMat);
      leftHand.position.set(-0.003, -0.046, 0.0);
      this.group.add(leftHand);

      // Muzzle flash (hidden)
      const flashMat = new THREE.MeshBasicMaterial({
        color: 0xffaa33, transparent: true, opacity: 0, side: THREE.DoubleSide,
      });
      const muzzleFlash = new THREE.Mesh(new THREE.PlaneGeometry(0.1, 0.1), flashMat);
      muzzleFlash.position.set(0, 0.012, -0.56);
      muzzleFlash.name = 'muzzleFlashVM';
      this.group.add(muzzleFlash);
    } catch (e) {
      console.error('ViewModel build failed, using fallback box:', e);
      const fallback = new THREE.Mesh(
        new THREE.BoxGeometry(0.05, 0.05, 0.3),
        new THREE.MeshStandardMaterial({ color: 0x444444 })
      );
      this.group.add(fallback);
    }
  }

  private applyOrigin(): void {
    this.group.position.copy(this.ORIGIN);
  }

  updateSway(_dx: number, _dy: number, _delta: number): void {
    // No-op (kept for compatibility)
  }

  update(_delta: number, _isMoving: boolean, _isSprinting: boolean): void {
    // Fade muzzle flash
    const flash = this.group.getObjectByName('muzzleFlashVM') as THREE.Mesh | null;
    if (flash) {
      const mat = flash.material as THREE.MeshBasicMaterial;
      mat.opacity = Math.max(0, mat.opacity - _delta * 8);
    }
  }

  triggerRecoil(): void {}
  triggerReload(): void {}

  showMuzzleFlash(): void {
    const flash = this.group.getObjectByName('muzzleFlashVM') as THREE.Mesh | null;
    if (!flash) return;
    const mat = flash.material as THREE.MeshBasicMaterial;
    mat.opacity = 1;
    flash.scale.setScalar(0.7 + Math.random() * 0.6);
    flash.rotation.z = Math.random() * Math.PI * 2;
  }
}
