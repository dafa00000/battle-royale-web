// ============================================
// ENEMY BOTS - with health, hitbox, blood FX, death animation
// ============================================

import * as THREE from 'three';

export interface EnemyBot {
  id: string;
  group: THREE.Group;
  bodyMesh: THREE.Mesh;
  headMesh: THREE.Mesh;
  allHittable: THREE.Mesh[];
  health: number;
  maxHealth: number;
  isDead: boolean;
  removed: boolean;
  hitFlashTimer: number;
  deathTimer: number;        // 0 = alive, >0 = dying sequence
  deathFallAngle: number;    // 0..PI/2 (fall flat)
  fadeTimer: number;
  // Patrol state
  from: THREE.Vector3;
  to: THREE.Vector3;
  phase: number;
  speed: number;
  direction: 1 | -1;
  // Materials for flash
  bodyMat: THREE.MeshStandardMaterial;
  headMat: THREE.MeshStandardMaterial;
  origBodyColor: THREE.Color;
  origHeadColor: THREE.Color;
}

interface BloodParticle {
  mesh: THREE.Mesh;
  velocity: THREE.Vector3;
  life: number;
}

export class EnemyBots {
  private bots: EnemyBot[] = [];
  private blood: BloodParticle[] = [];
  private scene: THREE.Scene;
  private bloodMat: THREE.MeshStandardMaterial;

  constructor(scene: THREE.Scene) {
    this.scene = scene;
    this.bloodMat = new THREE.MeshStandardMaterial({
      color: 0x8a0000, emissive: 0x330000, roughness: 0.4, metalness: 0.1,
    });
    this.spawn();
  }

  get bots_alive(): EnemyBot[] {
    return this.bots.filter(b => !b.isDead);
  }

  get allHittableMeshes(): THREE.Mesh[] {
    const out: THREE.Mesh[] = [];
    for (const b of this.bots) {
      if (!b.isDead) out.push(...b.allHittable);
    }
    return out;
  }

  // Map a hit mesh back to its owning bot
  findBotByMesh(mesh: THREE.Object3D): EnemyBot | null {
    for (const b of this.bots) {
      if (b.isDead) continue;
      if (b.allHittable.includes(mesh as THREE.Mesh)) return b;
    }
    return null;
  }

  private spawn(): void {
    const positions: Array<[THREE.Vector3, THREE.Vector3]> = [
      [new THREE.Vector3(-25, 0, -40), new THREE.Vector3(-25, 0, 15)],
      [new THREE.Vector3(35, 0, 25),   new THREE.Vector3(10, 0, 25)],
      [new THREE.Vector3(0, 0, -60),   new THREE.Vector3(20, 0, -60)],
    ];

    for (let i = 0; i < positions.length; i++) {
      const [from, to] = positions[i];
      const group = new THREE.Group();

      const bodyMat = new THREE.MeshStandardMaterial({
        color: 0xcc2222, emissive: 0x441010, metalness: 0.3, roughness: 0.5,
      });
      const headMat = new THREE.MeshStandardMaterial({
        color: 0xee3333, emissive: 0x661010, metalness: 0.2, roughness: 0.4,
      });

      const body = new THREE.Mesh(
        new THREE.CylinderGeometry(0.4, 0.4, 1.6, 12),
        bodyMat
      );
      body.position.y = 0.8;
      body.castShadow = true;
      body.name = `enemy_bot_${i}_body`;
      group.add(body);

      const head = new THREE.Mesh(
        new THREE.BoxGeometry(0.4, 0.4, 0.4),
        headMat
      );
      head.position.y = 1.85;
      head.castShadow = true;
      head.name = `enemy_bot_${i}_head`;
      group.add(head);

      // Glow eyes
      const eyeMat = new THREE.MeshBasicMaterial({ color: 0xff2200 });
      for (const x of [-0.1, 0.1]) {
        const eye = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.05, 0.05), eyeMat);
        eye.position.set(x, 1.9, 0.21);
        group.add(eye);
      }

      group.position.copy(from);
      this.scene.add(group);

      this.bots.push({
        id: `bot_${i}`,
        group,
        bodyMesh: body,
        headMesh: head,
        allHittable: [body, head],
        health: 100,
        maxHealth: 100,
        isDead: false,
        removed: false,
        hitFlashTimer: 0,
        deathTimer: 0,
        deathFallAngle: 0,
        fadeTimer: 0,
        from, to,
        phase: Math.random(),
        speed: 0.08 + Math.random() * 0.12,
        direction: 1,
        bodyMat,
        headMat,
        origBodyColor: bodyMat.color.clone(),
        origHeadColor: headMat.color.clone(),
      });
    }
  }

  // Called by WeaponSystem when a hit is confirmed
  registerHit(bot: EnemyBot, impactPoint: THREE.Vector3, damage: number = 25): void {
    if (bot.isDead) return;
    bot.health -= damage;
    bot.hitFlashTimer = 0.12; // 120ms flash

    // Spawn 12 blood particles
    this.spawnBlood(impactPoint);

    if (bot.health <= 0 && !bot.isDead) {
      this.killBot(bot);
    }
  }

  private spawnBlood(at: THREE.Vector3): void {
    const count = 14;
    for (let i = 0; i < count; i++) {
      const r = 0.04 + Math.random() * 0.04;
      const p = new THREE.Mesh(
        new THREE.SphereGeometry(r, 6, 6),
        this.bloodMat
      );
      p.position.copy(at);
      // Random outward + upward force
      const angle = Math.random() * Math.PI * 2;
      const up = 1.5 + Math.random() * 2.5;
      const out = 1.5 + Math.random() * 3;
      const vel = new THREE.Vector3(
        Math.cos(angle) * out,
        up,
        Math.sin(angle) * out
      );
      this.scene.add(p);
      this.blood.push({ mesh: p, velocity: vel, life: 1.2 });
    }
  }

  private killBot(bot: EnemyBot): void {
    bot.isDead = true;
    bot.deathTimer = 0;       // start death sequence
    bot.fadeTimer = 0;
  }

  update(delta: number): void {
    // === Update alive bots patrol ===
    for (const bot of this.bots) {
      if (bot.removed) continue;

      if (!bot.isDead) {
        bot.phase += bot.speed * delta * bot.direction;
        if (bot.phase >= 1) { bot.phase = 1; bot.direction = -1; }
        else if (bot.phase <= 0) { bot.phase = 0; bot.direction = 1; }

        const t = bot.phase;
        const facing = bot.direction === 1 ? bot.to : bot.from;
        bot.group.position.lerpVectors(bot.from, bot.to, t);
        bot.group.position.y = 0 + Math.abs(Math.sin(t * Math.PI * 4)) * 0.06;
        // Re-orient toward travel direction (only Y rotation)
        const angleToTarget = Math.atan2(facing.x - bot.group.position.x, facing.z - bot.group.position.z);
        // Smooth yaw
        const curY = bot.group.rotation.y;
        let diff = angleToTarget - curY;
        while (diff > Math.PI) diff -= Math.PI * 2;
        while (diff < -Math.PI) diff += Math.PI * 2;
        bot.group.rotation.y = curY + diff * delta * 5;

        // Hit flash decay
        if (bot.hitFlashTimer > 0) {
          bot.hitFlashTimer -= delta;
          const flashAmount = Math.max(0, bot.hitFlashTimer / 0.12);
          // Lerp toward white-emissive
          bot.bodyMat.emissive.setRGB(
            bot.origBodyColor.r + (1 - bot.origBodyColor.r) * flashAmount,
            bot.origBodyColor.g + (1 - bot.origBodyColor.g) * flashAmount,
            bot.origBodyColor.b + (1 - bot.origBodyColor.b) * flashAmount
          );
          bot.headMat.emissive.setRGB(
            bot.origHeadColor.r + (1 - bot.origHeadColor.r) * flashAmount,
            bot.origHeadColor.g + (1 - bot.origHeadColor.g) * flashAmount,
            bot.origHeadColor.b + (1 - bot.origHeadColor.b) * flashAmount
          );
        }
      } else {
        // === Death sequence ===
        bot.deathTimer += delta;
        // Phase 1: tip over (first 0.6 seconds)
        if (bot.deathTimer < 0.7) {
          const t = bot.deathTimer / 0.7;
          bot.deathFallAngle = THREE.MathUtils.lerp(0, Math.PI / 2, 1 - Math.pow(1 - t, 2));
          bot.group.rotation.x = bot.deathFallAngle;
          bot.group.position.y = 0;
        }
        // Phase 2: lie flat on ground 3s, then fade
        else if (bot.deathTimer < 3.7) {
          bot.group.rotation.x = Math.PI / 2;
        }
        // Phase 3: fade out over 0.8s, then remove
        else {
          bot.fadeTimer += delta;
          const fadeT = Math.min(1, bot.fadeTimer / 0.8);
          // Lower to ground + transparent
          const mat = bot.bodyMat;
          mat.transparent = true;
          mat.opacity = 1 - fadeT;
          bot.headMat.transparent = true;
          bot.headMat.opacity = 1 - fadeT;
          bot.group.position.y = -fadeT * 0.3;

          if (bot.fadeTimer >= 0.8 && !bot.removed) {
            bot.removed = true;
            this.scene.remove(bot.group);
            // Dispose geometries (materials shared so just dispose geo)
            bot.bodyMesh.geometry.dispose();
            bot.headMesh.geometry.dispose();
          }
        }
      }
    }

    // === Update blood particles ===
    for (let i = this.blood.length - 1; i >= 0; i--) {
      const bp = this.blood[i];
      bp.life -= delta;
      // Physics
      bp.velocity.y -= 12 * delta;  // gravity
      bp.mesh.position.addScaledVector(bp.velocity, delta);
      // Floor collision (stop)
      if (bp.mesh.position.y < 0.04) {
        bp.mesh.position.y = 0.04;
        bp.velocity.set(0, 0, 0);
        bp.life = Math.min(bp.life, 0.4); // lay on floor briefly
      }
      // Scale shrink on death
      if (bp.life < 0.4) {
        const s = Math.max(0, bp.life / 0.4);
        bp.mesh.scale.setScalar(s);
      }
      if (bp.life <= 0) {
        this.scene.remove(bp.mesh);
        bp.mesh.geometry.dispose();
        this.blood.splice(i, 1);
      }
    }
  }

  // Count alive for HUD display
  aliveCount(): number {
    return this.bots.filter(b => !b.isDead).length;
  }

  // Reset a dead & removed bot (for respawn)
  respawnIfAllDead(): boolean {
    const alive = this.aliveCount();
    if (alive > 0) return false;
    // Respawn all
    for (const bot of this.bots) {
      if (bot.removed) {
        // Re-add group and reset
        bot.health = bot.maxHealth;
        bot.isDead = false;
        bot.removed = false;
        bot.deathTimer = 0;
        bot.fadeTimer = 0;
        bot.deathFallAngle = 0;
        bot.hitFlashTimer = 0;
        bot.bodyMat.opacity = 1;
        bot.bodyMat.transparent = false;
        bot.headMat.opacity = 1;
        bot.headMat.transparent = false;
        bot.group.rotation.set(0, 0, 0);
        bot.group.position.copy(bot.from);
        bot.group.position.y = 0;
        this.scene.add(bot.group);
      }
    }
    return true;
  }
}
