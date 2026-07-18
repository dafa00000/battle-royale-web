// ============================================
// MINIMAP - GTA V Style
// ============================================

import * as THREE from 'three';
import { GameState, ZoneState, Vector3 } from '../types';
import { CONSTANTS } from '../constants';

export class Minimap {
  public state: GameState;
  public canvas: HTMLCanvasElement;
  public ctx: CanvasRenderingContext2D;
  private size = 200;
  private zoom = 1;
  private playerMarker = { x: 0, y: 0, rotation: 0 };
  private visible = true;

  constructor(state: GameState) {
    this.state = state;
    this.canvas = document.getElementById('minimap') as HTMLCanvasElement;
    this.ctx = this.canvas.getContext('2d')!;
    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  public resize(): void {
    const dpr = window.devicePixelRatio || 1;
    this.canvas.width = this.size * dpr;
    this.canvas.height = this.size * dpr;
    this.ctx.scale(dpr, dpr);
  }

  public toggle(): void {
    this.visible = !this.visible;
    this.canvas.style.display = this.visible ? 'block' : 'none';
  }

  public update(): void {
    if (!this.visible) return;
    this.clear();
    this.drawZone();
    this.drawPlayer();
    this.drawSquad();
    this.drawVehicles();
    this.drawLoot();
    this.drawCompass();
  }

  private clear(): void {
    this.ctx.clearRect(0, 0, this.size, this.size);
    // Background
    this.ctx.fillStyle = '#141414';
    this.ctx.fillRect(0, 0, this.size, this.size);
    // Grid
    this.ctx.strokeStyle = '#2a2a2a';
    this.ctx.lineWidth = 1;
    for (let i = 0; i <= 10; i++) {
      const pos = i * this.size / 10;
      this.ctx.beginPath(); this.ctx.moveTo(pos, 0); this.ctx.lineTo(pos, this.size); this.ctx.stroke();
      this.ctx.beginPath(); this.ctx.moveTo(0, pos); this.ctx.lineTo(this.size, pos); this.ctx.stroke();
    }
  }

  private drawZone(): void {
    const z = this.state.zone;
    if (!z) return;

    const centerX = this.size / 2;
    const centerY = this.size / 2;
    const scale = this.size / (CONSTANTS.MAP_RADIUS * 2);

    // Current zone
    const r = z.radius * scale;
    this.ctx.strokeStyle = '#00b4ff';
    this.ctx.lineWidth = 2;
    this.ctx.setLineDash([5, 5]);
    this.ctx.beginPath();
    this.ctx.arc(centerX, centerY, r, 0, Math.PI * 2);
    this.ctx.stroke();
    this.ctx.setLineDash([]);

    // Zone fill
    this.ctx.fillStyle = 'rgba(0, 180, 255, 0.05)';
    this.ctx.beginPath();
    this.ctx.arc(centerX, centerY, r, 0, Math.PI * 2);
    this.ctx.fill();

    // Next zone
    if (z.nextCenter && z.nextRadius) {
      const nr = z.nextRadius * scale;
      this.ctx.strokeStyle = '#ff8c00';
      this.ctx.lineWidth = 1.5;
      this.ctx.setLineDash([3, 3]);
      this.ctx.beginPath();
      this.ctx.arc(centerX, centerY, nr, 0, Math.PI * 2);
      this.ctx.stroke();
      this.ctx.setLineDash([]);
    }
  }

  private drawPlayer(): void {
    const p = this.state.player;
    const centerX = this.size / 2;
    const centerY = this.size / 2;
    const scale = this.size / (CONSTANTS.MAP_RADIUS * 2);

    const dx = (p.position[0] - this.state.zone.center[0]) * scale;
    const dz = (p.position[2] - this.state.zone.center[2]) * scale;

    this.playerMarker.x = centerX + dx;
    this.playerMarker.y = centerY - dz; // Y inverted
    this.playerMarker.rotation = this.state.player.rotation[1];

    // Player arrow
    this.ctx.save();
    this.ctx.translate(this.playerMarker.x, this.playerMarker.y);
    this.ctx.rotate(this.playerMarker.rotation);
    this.ctx.fillStyle = '#00b4ff';
    this.ctx.beginPath();
    this.ctx.moveTo(0, -10);
    this.ctx.lineTo(-5, 5);
    this.ctx.lineTo(5, 5);
    this.ctx.closePath();
    this.ctx.fill();
    this.ctx.restore();

    // Player dot
    this.ctx.fillStyle = '#00b4ff';
    this.ctx.beginPath();
    this.ctx.arc(this.playerMarker.x, this.playerMarker.y, 4, 0, Math.PI * 2);
    this.ctx.fill();
  }

  private drawSquad(): void {
    if (!this.state.squad) return;

    this.state.squad.members.forEach(member => {
      if (member.userId === this.state.player.id) return;

      const centerX = this.size / 2;
      const centerY = this.size / 2;
      const scale = this.size / (CONSTANTS.MAP_RADIUS * 2);

      // In real implementation, would use actual member position
      // For now, draw relative to player
      const angle = Math.random() * Math.PI * 2;
      const dist = 200 * scale;
      const x = centerX + Math.cos(angle) * dist;
      const y = centerY + Math.sin(angle) * dist;

      this.ctx.fillStyle = '#32c864';
      this.ctx.beginPath();
      this.ctx.arc(x, y, 3, 0, Math.PI * 2);
      this.ctx.fill();

      // Name label
      this.ctx.fillStyle = '#32c864';
      this.ctx.font = '10px Inter';
      this.ctx.textAlign = 'center';
      this.ctx.fillText(member.username, x, y - 8);
    });
  }

  private drawVehicles(): void {
    // Draw nearby vehicles
  }

  private drawLoot(): void {
    // Draw high-tier loot nearby
  }

  private drawCompass(): void {
    const centerX = this.size / 2;
    const centerY = 15;
    const radius = 12;

    this.ctx.font = '10px Inter';
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    this.ctx.fillStyle = '#a0a0a0';

    const headings = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    const playerHeading = -this.state.player.rotation[1] * 180 / Math.PI;

    headings.forEach((h, i) => {
      const angle = i * Math.PI / 4;
      const relAngle = angle - playerHeading * Math.PI / 180;
      const x = centerX + Math.sin(relAngle) * radius;
      const y = centerY - Math.cos(relAngle) * radius;
      const opacity = h === 'N' ? 1 : 0.5;
      this.ctx.fillStyle = `rgba(160,160,160,${opacity})`;
      this.ctx.fillText(h, x, y);
    });

    // Heading indicator
    this.ctx.fillStyle = '#00b4ff';
    this.ctx.beginPath();
    this.ctx.moveTo(centerX, centerY - radius - 3);
    this.ctx.lineTo(centerX - 4, centerY - radius + 3);
    this.ctx.lineTo(centerX + 4, centerY - radius + 3);
    this.ctx.closePath();
    this.ctx.fill();
  }
}