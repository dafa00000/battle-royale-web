// ============================================
// INVENTORY UI (clean, no duplicates)
// ============================================
import type { GameState } from '../types';
import { CONSTANTS } from '../constants';

export class InventoryUI {
  private state: GameState;
  private isOpen = false;
  private container: HTMLDivElement;
  private grid: HTMLDivElement;
  private hotbar: HTMLDivElement;
  private weightEl: HTMLDivElement;

  constructor(state: GameState) {
    this.state = state;
    this.container = document.createElement('div');
    this.grid = document.createElement('div');
    this.hotbar = document.createElement('div');
    this.weightEl = document.createElement('div');
    this.createUI();
    this.bindEvents();
  }

  private createUI(): void {
    this.container.id = 'inventory-ui';
    this.container.style.cssText = `
      position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%);
      width: 720px; max-width: 95vw; height: 520px; max-height: 80vh;
      background: rgba(20,20,20,0.97); border: 1px solid #3c3c3c; border-radius: 12px;
      display: none; flex-direction: column; z-index: 200;
      font-family: 'Inter', sans-serif; color: #f0f0f0;
      box-shadow: 0 20px 40px rgba(0,0,0,0.5);
    `;

    const header = document.createElement('div');
    header.style.cssText = `
      display: flex; justify-content: space-between; align-items: center;
      padding: 1rem 1.5rem; background: #1e1e1e; border-bottom: 1px solid #3c3c3c;
    `;
    header.innerHTML = `
      <h2 style="margin:0; font-size:1.1rem; font-weight:600;">INVENTORY</h2>
      <button id="inv-close" style="background:#dc3232;border:none;color:#fff;width:32px;height:32px;border-radius:6px;cursor:pointer;font-size:1.25rem;">×</button>
    `;
    this.container.appendChild(header);

    const content = document.createElement('div');
    content.style.cssText = 'flex:1; display:flex; padding:1rem; gap:1rem; overflow:hidden;';

    const left = document.createElement('div');
    left.style.cssText = 'flex:1; display:flex; flex-direction:column; gap:0.5rem;';
    const gridTitle = document.createElement('div');
    gridTitle.style.cssText = 'font-size:0.75rem; text-transform:uppercase; color:#a0a0a0; letter-spacing:0.05em;';
    gridTitle.textContent = 'BACKPACK';
    left.appendChild(gridTitle);

    this.grid.style.cssText = `
      flex:1; display:grid; grid-template-columns: repeat(6, 1fr); gap:6px;
      background:#141414; border-radius:8px; padding:12px;
    `;
    left.appendChild(this.grid);

    this.weightEl.style.cssText = 'text-align:right; color:#a0a0a0; font-family:monospace; font-size:0.85rem;';
    left.appendChild(this.weightEl);
    content.appendChild(left);

    const right = document.createElement('div');
    right.style.cssText = 'flex:1; display:flex; flex-direction:column; gap:0.5rem;';
    right.innerHTML = '<h3 style="margin:0 0 0.5rem; color:#a0a0a0; font-size:0.75rem; text-transform:uppercase;">HOTBAR (1-5)</h3>';
    this.hotbar.style.cssText = `
      display:flex; gap:8px; flex:1; background:#141414; border-radius:8px; padding:12px;
      align-items:center; justify-content:center;
    `;
    right.appendChild(this.hotbar);
    content.appendChild(right);

    this.container.appendChild(content);
    document.getElementById('ui')?.appendChild(this.container);

    this.createGridSlots();
    this.createHotbarSlots();
  }

  private createGridSlots(): void {
    for (let i = 0; i < CONSTANTS.INVENTORY_SLOTS; i++) {
      this.grid.appendChild(this.createSlot(i, 'inventory'));
    }
  }

  private createHotbarSlots(): void {
    for (let i = 0; i < CONSTANTS.HOTBAR_SLOTS; i++) {
      const slot = this.createSlot(i, 'hotbar');
      slot.style.cssText += 'width:56px;height:56px;box-shadow:inset 0 0 0 2px #00b4ff;';
      const keyLabel = document.createElement('span');
      keyLabel.style.cssText = 'position:absolute;top:2px;left:4px;font-size:0.65rem;color:#888;font-weight:600;';
      keyLabel.textContent = (i + 1).toString();
      slot.appendChild(keyLabel);
      this.hotbar.appendChild(slot);
    }
  }

  private createSlot(index: number, type: string): HTMLDivElement {
    const slot = document.createElement('div');
    slot.dataset.index = index.toString();
    slot.dataset.type = type;
    slot.className = 'inv-slot';
    slot.style.cssText = `
      width:44px;height:44px;background:#1e1e1e;border:1px solid #3c3c3c;
      border-radius:6px;position:relative;display:flex;align-items:center;
      justify-content:center;cursor:pointer;transition:all 0.15s;
    `;
    return slot;
  }

  private bindEvents(): void {
    this.container.querySelector('#inv-close')?.addEventListener('click', () => this.close());
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') { e.preventDefault(); this.toggle(); }
    });
  }

  toggle(): void {
    this.isOpen = !this.isOpen;
    this.container.style.display = this.isOpen ? 'flex' : 'none';
    if (this.isOpen) {
      this.render();
      document.exitPointerLock?.();
    }
  }

  close(): void {
    this.isOpen = false;
    this.container.style.display = 'none';
  }

  private render(): void {
    const w = this.state.player.inventoryWeight || 0;
    const mw = this.state.player.maxWeight || 100;
    this.weightEl.textContent = `Weight: ${w.toFixed(1)} / ${mw} kg`;
    this.weightEl.style.color = w / mw > 0.8 ? '#ff8c00' : w / mw > 1 ? '#dc3232' : '#a0a0a0';
  }
}
