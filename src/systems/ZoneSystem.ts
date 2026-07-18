// ============================================
// ZONE SYSTEM - Safe Zone / Gas (Clean Version)
// ============================================

import * as THREE from 'three';
import { GameState, ZoneState, Vector3 } from '../types';
import { CONSTANTS } from '../constants';

export class ZoneSystem {
  private state: GameState;
  private scene: THREE.Scene;
  private zoneRing: THREE.Mesh | null = null;
  private nextZoneRing: THREE.Mesh | null = null;
  private gasMaterial: THREE.ShaderMaterial;
  private phaseIndex = 0;
  private phaseTimer = 0;
  private warningTimer = 0;
  private isWarning = false;

  constructor(state: GameState, scene: THREE.Scene) {
    this.state = state;
    this.scene = scene;
    this.gasMaterial = this.createGasShader();
    this.findZoneRings();
    this.initZones();
  }

  private findZoneRings(): void {
    this.zoneRing = this.scene.getObjectByName('zoneRing') as THREE.Mesh;
    if (!this.zoneRing) {
      const geo = new THREE.RingGeometry(1990, 2010, 64);
      const mat = new THREE.MeshBasicMaterial({ color: 0x00b4ff, side: THREE.DoubleSide, transparent: true, opacity: 0.15 });
      this.zoneRing = new THREE.Mesh(geo, mat);
      this.zoneRing.rotation.x = -Math.PI / 2;
      this.zoneRing.position.y = 0.1;
      this.zoneRing.name = 'zoneRing';
      this.scene.add(this.zoneRing);
    }

    const nextGeo = new THREE.RingGeometry(990, 1010, 64);
    const nextMat = new THREE.MeshBasicMaterial({ color: 0xff8c00, side: THREE.DoubleSide, transparent: true, opacity: 0.1 });
    this.nextZoneRing = new THREE.Mesh(nextGeo, nextMat);
    this.nextZoneRing.rotation.x = -Math.PI / 2;
    this.nextZoneRing.position.y = 0.1;
    this.nextZoneRing.visible = false;
    this.scene.add(this.nextZoneRing);
  }

  private initZones(): void {
    const phase = CONSTANTS.ZONE_PHASES[this.phaseIndex];
    this.state.zone = {
      center: [0, 0, 0],
      radius: phase.radius,
      phase: this.phaseIndex + 1,
      phaseEndTime: phase.duration,
      isShrinking: false,
      damagePerTick: phase.damagePerTick,
      tickInterval: phase.tickInterval,
    };
    this.phaseTimer = phase.duration;
    this.warningTimer = phase.warningTime;
    this.isWarning = false;

    this.updateZoneVisuals();
  }

  private createGasShader(): THREE.ShaderMaterial {
    return new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uColor1: { value: new THREE.Color(0x003366) },
        uColor2: { value: new THREE.Color(0x0066cc) },
        uNoiseScale: { value: 2.0 },
        uScrollSpeed: { value: 0.5 },
        uIntensity: { value: 0.5 },
      },
      vertexShader: `
        varying vec2 vUv; varying vec3 vWorldPos;
        void main() {
          vUv = uv;
          vWorldPos = (modelMatrix * vec4(position, 1.0)).xyz;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        uniform float uTime; uniform vec3 uColor1; uniform vec3 uColor2;
        uniform float uNoiseScale; uniform float uScrollSpeed; uniform float uIntensity;
        varying vec2 vUv; varying vec3 vWorldPos;
        float noise(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
        float fbm(vec2 p) { float f = 0.0; float a = 0.5; vec2 s = p; for (int i = 0; i < 5; i++) { f += a * noise(s); s *= 2.0; a *= 0.5; } return f; }
        void main() {
          float n = fbm(vUv * uNoiseScale + uTime * uScrollSpeed);
          vec3 color = mix(uColor1, uColor2, n);
          float alpha = smoothstep(0.3, 0.7, n) * uIntensity;
          gl_FragColor = vec4(color, alpha);
        }
      `,
      transparent: true,
      side: THREE.DoubleSide,
      depthWrite: false,
    });
  }

  startMatch(): void {
    this.initZones();
  }

  update(delta: number): void {
    this.phaseTimer -= delta;
    this.gasMaterial.uniforms.uTime.value += delta;

    // Warning before shrink
    if (this.phaseTimer <= this.warningTimer && !this.isWarning) {
      this.startWarning();
    }

    // Shrink zone
    if (this.phaseTimer <= 0) {
      this.shrinkZone();
    }

    // Tick gas damage
    this.tickGasDamage(delta);

    // Animate zone visuals
    this.animateZoneVisuals(delta);
  }

  private startWarning(): void {
    this.isWarning = true;
    if (this.nextZoneRing) {
      this.nextZoneRing.visible = true;
      this.animateWarningRing();
    }
    this.state.isInGas = true;
  }

  private animateWarningRing(): void {
    if (!this.nextZoneRing) return;
    const pulse = () => {
      if (!this.isWarning || !this.nextZoneRing) return;
      const scale = 1 + Math.sin(performance.now() / 300) * 0.02;
      this.nextZoneRing!.scale.setScalar(scale);
      requestAnimationFrame(pulse);
    };
    pulse();
  }

  private shrinkZone(): void {
    this.phaseIndex++;
    if (this.phaseIndex >= CONSTANTS.ZONE_PHASES.length) {
      this.phaseIndex = CONSTANTS.ZONE_PHASES.length - 1;
    }

    const phase = CONSTANTS.ZONE_PHASES[this.phaseIndex];
    const oldRadius = this.state.zone.radius;

    // Move center slightly
    const angle = Math.random() * Math.PI * 2;
    const offset = oldRadius * 0.3;
    const newCenter: Vector3 = [
      this.state.zone.center[0] + Math.cos(angle) * offset,
      0,
      this.state.zone.center[2] + Math.sin(angle) * offset,
    ];

    // Animate transition
    this.animateZoneTransition(oldRadius, phase.radius, this.state.zone.center, newCenter, phase.duration);

    this.state.zone.radius = phase.radius;
    this.state.zone.center = newCenter;
    this.state.zone.phase = this.phaseIndex + 1;
    this.state.zone.phaseEndTime = phase.duration;
    this.state.zone.damagePerTick = phase.damagePerTick;
    this.state.zone.tickInterval = phase.tickInterval;
    this.state.zone.isShrinking = true;

    this.phaseTimer = phase.duration;
    this.warningTimer = phase.warningTime;
    this.isWarning = false;

    if (this.nextZoneRing) this.nextZoneRing.visible = false;

    this.updateZoneVisuals();
  }

  private animateZoneTransition(
    oldRadius: number, newRadius: number,
    oldCenter: Vector3, newCenter: Vector3,
    duration: number
  ): void {
    const startTime = performance.now() / 1000;
    const animate = () => {
      const elapsed = performance.now() / 1000 - startTime;
      const t = Math.min(elapsed / 10, 1); // 10s transition
      const eased = 1 - Math.pow(1 - t, 3);

      const radius = THREE.MathUtils.lerp(oldRadius, newRadius, eased);
      const center: Vector3 = [
        THREE.MathUtils.lerp(oldCenter[0], newCenter[0], eased),
        0,
        THREE.MathUtils.lerp(oldCenter[2], newCenter[2], eased),
      ];

      this.state.zone.radius = radius;
      this.state.zone.center = center;
      this.updateZoneVisuals();

      if (t < 1) requestAnimationFrame(animate);
      else this.state.zone.isShrinking = false;
    };
    animate();
  }

  private tickGasDamage(delta: number): void {
    const p = this.state.player;
    const dist = Math.sqrt(
      Math.pow(p.position[0] - this.state.zone.center[0], 2) +
      Math.pow(p.position[2] - this.state.zone.center[2], 2)
    );

    const wasInGas = this.state.isInGas;
    this.state.isInGas = dist > this.state.zone.radius;

    if (this.state.isInGas) {
      const overflow = dist - this.state.zone.radius;
      this.state.gasIntensity = Math.min(1, overflow / 500);

      // Apply damage over time
      if (!p.isInGasDamageCooldown) {
        p.health -= this.state.zone.damagePerTick * delta;
        p.health = Math.max(0, p.health);
        p.isInGasDamageCooldown = true;
        setTimeout(() => { p.isInGasDamageCooldown = false; }, this.state.zone.tickInterval * 1000);
      }
    } else {
      this.state.gasIntensity = 0;
    }

    // Update visual post-process for gas
    this.updateGasEffect();

    // Notify UI of gas state change
    if (wasInGas !== this.state.isInGas) {
      // UI will read state.isInGas
    }
  }

  private updateGasEffect(): void {
    const vignette = document.getElementById('gas-vignette');
    if (vignette) {
      vignette.style.opacity = (this.state.gasIntensity * 0.5).toString();
      vignette.style.background = `radial-gradient(ellipse at center, transparent 40%, rgba(0, 80, 40, ${this.state.gasIntensity * 0.6}) 100%)`;
    }
  }

  private animateZoneVisuals(delta: number): void {
    if (this.zoneRing) {
      this.zoneRing.material.opacity = 0.1 + Math.sin(performance.now() / 1000) * 0.05;
    }
  }

  private updateZoneVisuals(): void {
    if (!this.zoneRing) return;

    const r = this.state.zone.radius;
    this.zoneRing.scale.setScalar(r / 2000);
    this.zoneRing.position.set(this.state.zone.center[0], 0.1, this.state.zone.center[2]);

    if (this.nextZoneRing && this.phaseIndex + 1 < CONSTANTS.ZONE_PHASES.length) {
      const nextR = CONSTANTS.ZONE_PHASES[this.phaseIndex + 1].radius;
      this.nextZoneRing.scale.setScalar(nextR / 2000);
      this.nextZoneRing.position.set(this.state.zone.center[0], 0.1, this.state.zone.center[2]);
    }
  }

  private animateZoneVisuals(delta: number): void {
    if (this.zoneRing) {
      this.zoneRing.material.opacity = 0.1 + Math.sin(performance.now() / 1000) * 0.05;
    }
  }

  getZoneInfo() {
    return {
      center: this.state.zone.center,
      radius: this.state.zone.radius,
      phase: this.state.zone.phase,
      timeRemaining: Math.max(0, this.phaseTimer),
      isShrinking: this.state.zone.isShrinking,
      gasIntensity: this.state.gasIntensity,
      isInGas: this.state.isInGas,
    };
  }
}