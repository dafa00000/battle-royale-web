// ============================================
// MOVEMENT SYSTEM
// ============================================

import * as THREE from 'three';
import type { GameState, Vector3, Stance } from '../types';
import { CONSTANTS } from '../constants';

export class MovementSystem {
  private state: GameState;
  private camera: THREE.Camera;
  private scene: THREE.Scene;
  private rayCaster: THREE.Raycaster;
  private footstepTimer = 0;
  private landingTimer = 0;

  // Stance heights and speeds
  private readonly STANCE_CONFIG: Record<Stance, { height: number; eyeHeight: number; speed: number; sprintMult: number }> = {
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
    const forward = new THREE.Vector3(0, 0, -1).applyEuler(new THREE.Euler(0, this.camera.rotation.y, 0));
    const right = new THREE.Vector3(1, 0, 0).applyEuler(new THREE.Euler(0, this.camera.rotation.y, 0));

    const inputDir = new THREE.Vector3(0, 0, 0);
    if (this.state.keys?.['KeyW']) inputDir.add(forward);
    if (this.state.keys?.['KeyS']) inputDir.sub(forward);
    if (this.state.keys?.['KeyA']) inputDir.sub(right);
    if (this.state.keys?.['KeyD']) inputDir.add(right);

    const player = this.state.player;
    player.isMoving = inputDir.length() > 0.1;
    player.isSprinting = this.state.keys?.['ShiftLeft'] && player.isMoving && player.stance === 'Stand';

    if (player.isMoving) {
      const config = this.STANCE_CONFIG[player.stance];
      const targetSpeed = config.speed * (player.isSprinting ? config.sprintMult : 1);

      // Acceleration
      const accel = 25 * delta;
      const vel = new THREE.Vector3(...player.velocity);
      const targetVel = inputDir.normalize().multiplyScalar(targetSpeed);

      vel.x = THREE.MathUtils.lerp(vel.x, targetVel.x, accel);
      vel.z = THREE.MathUtils.lerp(vel.z, targetVel.z, accel);

      player.velocity = [vel.x, vel.y, vel.z];
    } else {
      // Deceleration
      const drag = this.state.player.isSliding ? 3 * delta : 15 * delta;
      this.state.player.velocity[0] *= 1 - drag;
      this.state.player.velocity[2] *= 1 - drag;
    }
  }

  private updateStance(delta: number): void {
    this.state.player.stanceTransitionTime = Math.max(0, this.state.player.stanceTransitionTime - delta);

    // Smooth camera height transition
    this.camera.position.y = THREE.MathUtils.lerp(
      this.camera.position.y,
      this.state.player.position[1] + this.STANCE_CONFIG[this.state.player.stance].eyeHeight,
      delta * 10
    );
  }

  private updateMovement(delta: number): void {
    const slideDecay = 1 - delta * (1 / CONSTANTS.SLIDE_DURATION);

    if (this.state.player.isSliding) {
      if (this.state.player.slideEndTime <= 0 || this.state.player.velocity[1] < -2) {
        this.cancelSlide();
      } else {
        this.state.player.slideEndTime -= delta;
        this.state.player.velocity[0] *= slideDecay;
        this.state.player.velocity[2] *= slideDecay;
      }
    }

    // Apply velocity
    this.state.player.position[0] += this.state.player.velocity[0] * delta;
    this.state.player.position[1] += this.state.player.velocity[1] * delta;
    this.state.player.position[2] += this.state.player.velocity[2] * delta;

    // Boundary check
    const maxRange = 4000;
    this.state.player.position[0] = THREE.MathUtils.clamp(this.state.player.position[0], -maxRange, maxRange);
    this.state.player.position[2] = THREE.MathUtils.clamp(this.state.player.position[2], -maxRange, maxRange);
  }

  private updateLean(delta: number): void {
    this.state.player.leanTarget = (this.state.keys?.['KeyQ'] ? -1 : 0) + (this.state.keys?.['KeyE'] ? 1 : 0);
    this.state.player.lean = THREE.MathUtils.lerp(this.state.player.lean, this.state.player.leanTarget, delta * 15);
  }

  private applyGravity(delta: number): void {
    if (!this.state.player.isGrounded) {
      this.state.player.velocity[1] -= 9.81 * delta * 2;
      this.state.player.velocity[1] = Math.max(this.state.player.velocity[1], -50);
    }
  }

  private checkGround(): void {
    const origin = new THREE.Vector3(...this.state.player.position);
    origin.y += 0.1;
    this.rayCaster.set(origin, new THREE.Vector3(0, -1, 0));
    this.rayCaster.far = this.STANCE_CONFIG[this.state.player.stance].height + 0.2;

    const intersects = this.rayCaster.intersectObjects(this.scene.children, true);
    const wasGrounded = this.state.player.isGrounded;
    this.state.player.isGrounded = intersects.length > 0 && intersects[0].distance <= this.STANCE_CONFIG[this.state.player.stance].height + 0.2;

    if (!wasGrounded && this.state.player.isGrounded) {
      this.onLand();
    }
  }

  private onLand(): void {
    const fallSpeed = Math.abs(this.state.player.velocity[1]);
    if (fallSpeed > 15) {
      this.landingTimer = 0.2;
      this.camera.position.y -= Math.min(fallSpeed * 0.01, 0.3);
    }
    this.state.player.velocity[1] = 0;
  }

  private handleFootsteps(delta: number): void {
    if (!this.state.player.isMoving || !this.state.player.isGrounded) return;

    const speed = Math.sqrt(this.state.player.velocity[0] ** 2 + this.state.player.velocity[2] ** 2);
    const config = this.STANCE_CONFIG[this.state.player.stance];
    const interval = 0.5 * (config.speed / speed);

    this.footstepTimer -= delta;
    if (this.footstepTimer <= 0) {
      this.footstepTimer = interval;
      // Play footstep sound based on surface
      // this.playFootstepSound(this.state.player.position, this.state.player.stance);
    }
  }

  private checkVault(): void {
    if (!this.state.keys?.['Space'] || this.state.player.stance === 'Prone') return;
    if (this.state.player.velocity[1] > 0) return;

    // Raycast forward to detect vaultable obstacle
    const forward = new THREE.Vector3(0, 0, -1).applyEuler(new THREE.Euler(0, this.camera.rotation.y, 0));
    const origin = new THREE.Vector3(...this.state.player.position);
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
    if (this.state.player.isGrounded && !this.state.player.isSliding && this.state.player.stance !== 'Prone') {
      this.state.player.velocity[1] = CONSTANTS.JUMP_POWER * (this.state.player.stance === 'Crouch' ? 0.7 : 1);
      this.state.player.isGrounded = false;
    }
  }

  startSlide(): void {
    if (this.state.player.isSprinting && this.state.player.isGrounded && !this.state.player.isSliding && this.state.player.stance === 'Stand') {
      this.state.player.isSliding = true;
      this.state.player.slideEndTime = CONSTANTS.SLIDE_DURATION;
      this.state.player.velocity[0] *= 1.5;
      this.state.player.velocity[2] *= 1.5;
      // Camera tilt for slide
    }
  }

  cancelSlide(): void {
    this.state.player.isSliding = false;
    this.state.player.slideEndTime = 0;
    // Reset camera tilt
  }

  toggleCrouch(): void {
    if (this.state.player.stance === 'Stand') {
      this.state.player.stance = 'Crouch';
      this.state.player.stanceTransitionTime = CONSTANTS.STANCE_TRANSITION_TIME;
    } else if (this.state.player.stance === 'Crouch') {
      if (this.canStand()) this.state.player.stance = 'Stand';
      this.state.player.stanceTransitionTime = CONSTANTS.STANCE_TRANSITION_TIME;
    }
  }

  toggleProne(): void {
    if (this.state.player.stance === 'Stand') {
      this.state.player.stance = 'Prone';
      this.state.player.stanceTransitionTime = CONSTANTS.STANCE_TRANSITION_TIME;
    } else if (this.state.player.stance === 'Prone') {
      if (this.canStand()) this.state.player.stance = 'Stand';
      this.state.player.stanceTransitionTime = CONSTANTS.STANCE_TRANSITION_TIME;
    }
  }

  private canStand(): boolean {
    const origin = new THREE.Vector3(...this.state.player.position);
    this.rayCaster.set(origin, new THREE.Vector3(0, 1, 0));
    this.rayCaster.far = this.STANCE_CONFIG.Stand.height + 0.2;
    const intersects = this.rayCaster.intersectObjects(this.scene.children, true);
    return intersects.length === 0 || intersects[0].distance > this.STANCE_CONFIG.Stand.height + 0.1;
  }
}