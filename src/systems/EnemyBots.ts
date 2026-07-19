// ============================================
// ENEMY BOTS - Red moving targets
// ============================================

import * as THREE from 'three';

interface EnemyBot {
  mesh: THREE.Mesh;
  from: THREE.Vector3;
  to: THREE.Vector3;
  phase: number;   // 0..1
  speed: number;   // cycles per second
  direction: 1 | -1;
}

export class EnemyBots {
  private bots: EnemyBot[] = [];
  private scene: THREE.Scene;

  constructor(scene: THREE.Scene) {
    this.scene = scene;
    this.spawn();
  }

  private spawn(): void {
    const bodyMat = new THREE.MeshStandardMaterial({
      color: 0xcc2222, emissive: 0x441010, metalness: 0.3, roughness: 0.5,
    });
    const headMat = new THREE.MeshStandardMaterial({
      color: 0xee3333, emissive: 0x661010, metalness: 0.2, roughness: 0.4,
    });

    // 3 bots at different locations
    const positions: Array<[THREE.Vector3, THREE.Vector3]> = [
      [new THREE.Vector3(-25, 0, -40), new THREE.Vector3(-25, 0, 15)],
      [new THREE.Vector3(35, 0, 25), new THREE.Vector3(10, 0, 25)],
      [new THREE.Vector3(0, 0, -60), new THREE.Vector3(20, 0, -60)],
    ];

    for (const [from, to] of positions) {
      const group = new THREE.Group();
      // Body cylinder
      const body = new THREE.Mesh(
        new THREE.CylinderGeometry(0.4, 0.4, 1.6, 12),
        bodyMat
      );
      body.position.y = 0.8;
      body.castShadow = true;
      group.add(body);
      // Head box
      const head = new THREE.Mesh(
        new THREE.BoxGeometry(0.4, 0.4, 0.4),
        headMat
      );
      head.position.y = 1.85;
      head.castShadow = true;
      group.add(head);
      // Eyes (glow)
      const eyeMat = new THREE.MeshBasicMaterial({ color: 0xff2200 });
      for (const x of [-0.1, 0.1]) {
        const eye = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.05, 0.05), eyeMat);
        eye.position.set(x, 1.9, 0.21);
        group.add(eye);
      }
      // Set initial position
      group.position.copy(from);
      this.scene.add(group);

      this.bots.push({
        mesh: body, // root movement applied to parent group via mesh.parent
        from, to, phase: Math.random(), speed: 0.1 + Math.random() * 0.15, direction: 1,
      } as any);

      // Store group reference on the bot entry
      (this.bots[this.bots.length - 1] as any).group = group;
    }
  }

  update(delta: number): void {
    for (const bot of this.bots) {
      bot.phase += bot.speed * delta * bot.direction;
      if (bot.phase >= 1) { bot.phase = 1; bot.direction = -1; }
      else if (bot.phase <= 0) { bot.phase = 0; bot.direction = 1; }

      const t = bot.phase;
      const group = (bot as any).group as THREE.Group;
      // Lerp position
      group.position.lerpVectors(bot.from, bot.to, t);
      // Make them face direction of travel
      const facing = bot.direction === 1 ? bot.to : bot.from;
      group.lookAt(facing.x, group.position.y, facing.z);
      // Bob slightly
      group.position.y = Math.abs(Math.sin(t * Math.PI * 4)) * 0.08;
    }
  }
}
