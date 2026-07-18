// ============================================
// HUD - Smartwatch Style
// ============================================

import { GameState } from '../types';

export class HUD {
  private state: GameState;
  private elements: Record<string, HTMLElement> = {};

  constructor(state: GameState) {
    this.state = state;
    this.init();
  }

  private init(): void {
    this.elements.hp = document.getElementById('hp')!;
    this.elements.armor = document.getElementById('armor')!;
    this.elements.zonePhase = document.getElementById('zone-phase')!;
    this.elements.alive = document.getElementById('alive')!;
    this.elements.ammoCurrent = document.getElementById('ammo-current')!;
    this.elements.ammoTotal = document.getElementById('ammo-total')!;
    this.elements.weaponName = document.getElementById('weapon-name')!;
    this.elements.fireMode = document.getElementById('fire-mode')!;
    this.elements.zoneWarning = document.getElementById('zone-warning')!;
    this.elements.zoneWarningSub = document.getElementById('zone-warning-sub')!;
    this.elements.killFeed = document.getElementById('kill-feed')!;
    this.elements.gasVignette = document.getElementById('gas-vignette')!;
  }

  update(): void {
    const p = this.state.player;
    const z = this.state.zone;

    // Health & Armor
    this.elements.hp.textContent = Math.round(p.health).toString();
    this.elements.hp.style.color = p.health > 50 ? '#32c864' : p.health > 25 ? '#ff8c00' : '#dc3232';

    this.elements.armor.textContent = Math.round(p.armor).toString();
    this.elements.armor.style.color = p.armor > 0 ? '#00b4ff' : '#a0a0a0';

    // Zone & Alive
    this.elements.zonePhase.textContent = z.phase.toString();
    this.elements.alive.textContent = this.state.alivePlayers.toString();

    // Ammo
    this.elements.ammoCurrent.textContent = p.ammo.toString();
    this.elements.ammoTotal.textContent = ` / ${p.maxAmmo}`;

    // Weapon
    this.elements.weaponName.textContent = p.currentWeapon?.Name || '—';
    this.elements.fireMode.textContent = p.fireMode.toUpperCase();

    // Gas warning
    if (this.state.isInGas) {
      this.showGasWarning();
    } else {
      this.hideGasWarning();
    }

    // Kill feed cleanup
    this.cleanupKillFeed();
  }

  private showGasWarning(): void {
    const vignette = document.getElementById('gas-vignette')!;
    vignette.style.opacity = `${this.state.gasIntensity * 0.5}`;
    vignette.style.background = `radial-gradient(ellipse at center, transparent 40%, rgba(0, 80, 40, ${this.state.gasIntensity * 0.6}) 100%)`;
  }

  private hideGasWarning(): void {
    const vignette = document.getElementById('gas-vignette')!;
    vignette.style.opacity = '0';
  }

  showZoneWarning(phase: number, message: string): void {
    this.elements.zoneWarningSub.textContent = message;
    this.elements.zoneWarning.classList.add('visible');
  }

  hideZoneWarning(): void {
    this.elements.zoneWarning.classList.remove('visible');
  }

  addKillFeed(killer: string, victim: string, weapon: string): void {
    const entry = document.createElement('div');
    entry.className = 'kill-entry';
    entry.innerHTML = `
      <span class="killer">${killer}</span>
      <span style="color:#a0a0a0; margin:0 0.5rem;">eliminated</span>
      <span class="victim">${victim}</span>
      <span style="color:#a0a0a0; margin:0 0.5rem;">with</span>
      <span class="weapon">${weapon}</span>
    `;
    this.elements.killFeed.insertBefore(entry, this.elements.killFeed.firstChild);

    // Animate in
    requestAnimationFrame(() => entry.classList.add('visible'));

    // Remove old entries
    if (this.elements.killFeed.children.length > 8) {
      this.elements.killFeed.lastChild?.remove();
    }

    // Auto remove after 5s
    setTimeout(() => {
      entry.classList.remove('visible');
      setTimeout(() => entry.remove(), 300);
    }, 5000);
  }

  showDamageIndicator(direction: number, damage: number, isHeadshot: boolean): void {
    // Create directional damage indicator on screen edge
    const indicator = document.createElement('div');
    indicator.style.cssText = `
      position:fixed; pointer-events:none; z-index:55;
      width:60px; height:60px; transform:translate(-50%, -50%);
      background:radial-gradient(circle, rgba(220,50,50,0.6) 0%, transparent 70%);
      border-radius:50%;
    `;
    indicator.style.left = `${50 + Math.cos(direction) * 40}%`;
    indicator.style.top = `${50 + Math.sin(direction) * 40}%`;
    document.getElementById('ui')!.appendChild(indicator);

    setTimeout(() => {
      indicator.style.transition = 'opacity 0.5s, transform 0.5s';
      indicator.style.opacity = '0';
      indicator.style.transform = 'translate(-50%, -50%) scale(2)';
      setTimeout(() => indicator.remove(), 500);
    }, 100);
  }

  showHitMarker(isHeadshot: boolean): void {
    const crosshair = document.getElementById('crosshair')!;
    crosshair.style.borderColor = isHeadshot ? '#ffd700' : '#00b4ff';
    setTimeout(() => { crosshair.style.borderColor = '#00b4ff'; }, 100);
  }

  private cleanupKillFeed(): void {
    const entries = this.elements.killFeed.querySelectorAll('.kill-entry');
    entries.forEach((entry, i) => {
      if (i > 5) (entry as HTMLElement).style.opacity = `${1 - (i - 5) * 0.15}`;
    });
  }
}