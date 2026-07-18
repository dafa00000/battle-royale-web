// ============================================
// MOVEMENT SYSTEM
// ============================================

import * as THREE from 'three';
import { PlayerState, Stance, GameState, Vector3 } from './types';
import { CONSTANTS } from './constants';

export class MovementSystem {
  private state: GameState;
  private camera: THREE.Camera;
  private scene: THREE.Scene;
  private rayCaster: THREE.Raycaster;
  private footstepTimer = 0;
  private landingTimer = 0;

  // Stance heights and speeds
  private readonly STANCE_CONFIG = {
    Stand: { height: 1.7, eyeHeight: 1.6, speed: CONSTANTS.WALK_SPEED, sprintMult: CONSTANTS.SPRINT_SPEED / CONSTANTS.WALK_SPEED },
    Crouch: { height: 1.2, eyeHeight: 1.0, speed: CONSTANTS.CROUCH_SPEED, sprintMult: 1 },
    Prone: { height: 0.5, eyeHeight: 0.3, speed: CONSTANTS.PRONE_SPEED, sprintMult: 1 },
  };

  constructor(state: GameState, camera: THREE.Camera, scene: THREE.Scene) {
    this.state = state;
    this.camera = camera;
    this.scene = scene;
    this.rayCaster = new THREE.Raycaster();
    this.rayCaster.far = 10;
  }

  update(delta: number): void {
    this.handleInput(delta);
    this.updateStance(delta);
    this.updateMovement(delta);
    this.updateLean(delta);
    this.applyGravity(delta);
    this.checkGround();
    this.handleFootsteps(delta);
    this.checkVault();
  }

  private handleInput(delta: number): void {
    const p = this.state.player;
    const forward = new THREE.Vector3(0, 0, -1).applyEuler(new THREE.Euler(0, this.camera.rotation.y, 0));
    const right = new THREE.Vector3(1, 0, 0).applyEuler(new THREE.Euler(0, this.camera.rotation.y, 0));

    const inputDir = new THREE.Vector3(0, 0, 0);
    if (this.state.keys['KeyW']) inputDir.add(forward);
    if (this.state.keys['KeyS']) inputDir.sub(forward);
    if (this.state.keys['KeyA']) inputDir.sub(right);
    if (this.state.keys['KeyD']) inputDir.add(right);

    p.isMoving = inputDir.length() > 0.1;
    p.isSprinting = this.state.keys['ShiftLeft'] && p.isMoving && p.stance === 'Stand';

    if (p.isMoving) {
      const config = this.STANCE_CONFIG[p.stance];
      const targetSpeed = config.speed * (p.isSprinting ? config.sprintMult : 1);

      // Acceleration
      const accel = 25 * delta;
      const vel = new THREE.Vector3(...p.velocity);
      const targetVel = inputDir.normalize().multiplyScalar(targetSpeed);

      vel.x = THREE.MathUtils.lerp(vel.x, targetVel.x, accel);
      vel.z = THREE.MathUtils.lerp(vel.z, targetVel.z, accel);

      p.velocity = [vel.x, vel.y, vel.z];
    } else {
      // Deceleration
      const drag = p.isSliding ? 3 * delta : 15 * delta;
      p.velocity[0] *= 1 - drag;
      p.velocity[2] *= 1 - drag;
    }
  }

  private updateStance(delta: number): void {
    const p = this.state.player;
    const targetHeight = this.STANCE_CONFIG[p.stance].height;
    const targetEye = this.STANCE_CONFIG[p.stance].eyeHeight;

    p.stanceTransitionTime = Math.max(0, p.stanceTransitionTime - delta);

    // Smooth camera height transition
    this.camera.position.y = THREE.MathUtils.lerp(
      this.camera.position.y,
      p.position[1] + targetEye,
      delta * 10
    );
  }

  private updateMovement(delta: number): void {
    const p = this.state.player;
    const slideDecay = 1 - delta * (1 / CONSTANTS.SLIDE_DURATION);

    if (p.isSliding) {
      if (p.slideEndTime <= 0 || p.velocity[1] < -2) {
        this.cancelSlide();
      } else {
        p.slideEndTime -= delta;
        p.velocity[0] *= slideDecay;
        p.velocity[2] *= slideDecay;
      }
    }

    // Apply velocity
    p.position[0] += p.velocity[0] * delta;
    p.position[1] += p.velocity[1] * delta;
    p.position[2] += p.velocity[2] * delta;

    // Boundary check
    const maxRange = 4000;
    p.position[0] = THREE.MathUtils.clamp(p.position[0], -maxRange, maxRange);
    p.position[2] = THREE.MathUtils.clamp(p.position[2], -maxRange, maxRange);
  }

  private updateLean(delta: number): void {
    const p = this.state.player;
    p.leanTarget = (this.state.keys['KeyQ'] ? -1 : 0) + (this.state.keys['KeyE'] ? 1 : 0);
    p.lean = THREE.MathUtils.lerp(p.lean, p.leanTarget, delta * 15);
  }

  private applyGravity(delta: number): void {
    const p = this.state.player;
    if (!p.isGrounded) {
      p.velocity[1] -= 9.81 * delta * 2;
      p.velocity[1] = Math.max(p.velocity[1], -50);
    }
  }

  private checkGround(): void {
    const p = this.state.player;
    const origin = new THREE.Vector3(...p.position);
    origin.y += 0.1;
    this.rayCaster.set(origin, new THREE.Vector3(0, -1, 0));
    this.rayCaster.far = this.STANCE_CONFIG[p.stance].height + 0.2;

    const intersects = this.rayCaster.intersectObjects(this.scene.children, true);
    const wasGrounded = p.isGrounded;
    p.isGrounded = intersects.length > 0 && intersects[0].distance <= this.STANCE_CONFIG[p.stance].height + 0.2;

    if (!wasGrounded && p.isGrounded) {
      this.onLand();
    }
  }

  private onLand(): void {
    const p = this.state.player;
    const fallSpeed = Math.abs(p.velocity[1]);
    if (fallSpeed > 15) {
      this.landingTimer = 0.2;
      // Add landing shake
      this.camera.position.y -= Math.min(fallSpeed * 0.01, 0.3);
    }
    p.velocity[1] = 0;
  }

  private handleFootsteps(delta: number): void {
    const p = this.state.player;
    if (!p.isMoving || !p.isGrounded) return;

    const speed = Math.sqrt(p.velocity[0] ** 2 + p.velocity[2] ** 2);
    const config = this.STANCE_CONFIG[p.stance];
    const interval = 0.5 * (config.speed / speed);

    this.footstepTimer -= delta;
    if (this.footstepTimer <= 0) {
      this.footstepTimer = interval;
      // Play footstep sound based on surface
      // this.playFootstepSound(p.position, p.stance);
    }
  }

  private checkVault(): void {
    if (!this.state.keys['Space'] || this.state.player.stance === 'Prone') return;
    if (this.state.player.velocity[1] > 0) return;

    // Raycast forward to detect vaultable obstacle
    const p = this.state.player;
    const forward = new THREE.Vector3(0, 0, -1).applyEuler(new THREE.Euler(0, this.camera.rotation.y, 0));
    const origin = new THREE.Vector3(...p.position);
    origin.y += 0.5;

    this.rayCaster.set(origin, forward);
    this.rayCaster.far = 2;

    const intersects = this.rayCaster.intersectObjects(this.scene.children, true);
    if (intersects.length > 0 && intersects[0].distance < 1.5) {
      const hitY = intersects[0].point.y - origin.y;
      if (hitY > 0.5 && hitY < CONSTANTS.VAULT_HEIGHT) {
        // Check landing spot
        const landingCheck = new THREE.Vector3().copy(forward).multiplyScalar(2.5).add(origin);
        landingCheck.y += 1;
        this.rayCaster.set(landingCheck, new THREE.Vector3(0, -1, 0));
        this.rayCaster.far = 3;
        const ground = this.rayCaster.intersectObjects(this.scene.children, true);
        if (ground.length > 0) {
          this.startVault();
        }
      }
    }
  }

  private startVault(): void {
    // Vault animation would go here
    console.log('Vault!');
  }

  jump(): void {
    const p = this.state.player;
    if (p.isGrounded && !p.isSliding && p.stance !== 'Prone') {
      p.velocity[1] = CONSTANTS.JUMP_POWER * (p.stance === 'Crouch' ? 0.7 : 1);
      p.isGrounded = false;
    }
  }

  startSlide(): void {
    const p = this.state.player;
    if (p.isSprinting && p.isGrounded && !p.isSliding && p.stance === 'Stand') {
      p.isSliding = true;
      p.slideEndTime = CONSTANTS.SLIDE_DURATION;
      p.velocity[0] *= 1.5;
      p.velocity[2] *= 1.5;
      // Camera tilt for slide
    }
  }

  cancelSlide(): void {
    const p = this.state.player;
    p.isSliding = false;
    p.slideEndTime = 0;
    // Reset camera tilt
  }

  toggleCrouch(): void {
    const p = this.state.player;
    if (p.stance === 'Stand') {
      p.stance = 'Crouch';
      p.stanceTransitionTime = CONSTANTS.STANCE_TRANSITION_TIME;
    } else if (p.stance === 'Crouch') {
      // Check headroom before standing
      if (this.canStand()) p.stance = 'Stand';
      p.stanceTransitionTime = CONSTANTS.STANCE_TRANSITION_TIME;
    }
  }

  toggleProne(): void {
    const p = this.state.player;
    if (p.stance === 'Stand') {
      p.stance = 'Prone';
      p.stanceTransitionTime = CONSTANTS.STANCE_TRANSITION_TIME;
    } else if (p.stance === 'Prone') {
      if (this.canStand()) p.stance = 'Stand';
      p.stanceTransitionTime = CONSTANTS.STANCE_TRANSITION_TIME;
    }
  }

  private canStand(): boolean {
    const p = this.state.player;
    const origin = new THREE.Vector3(...p.position);
    this.rayCaster.set(origin, new THREE.Vector3(0, 1, 0));
    this.rayCaster.far = this.STANCE_CONFIG.Stand.height + 0.2;
    const intersects = this.rayCaster.intersectObjects(this.scene.children, true);
    return intersects.length === 0 || intersects[0].distance > this.STANCE_CONFIG.Stand.height + 0.1;
  }
}

// Add isGrounded to PlayerState
declare module './types' {
  interface PlayerState {
    isGrounded: boolean;
  }
}