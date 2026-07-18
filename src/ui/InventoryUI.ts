// ============================================
// INVENTORY UI - Grid + Hotbar
// ============================================

import { GameState, InventoryItem } from '../types';
import { CONSTANTS } from '../constants';

export class InventoryUI {
  private state: GameState;
  private isOpen = false;
  private container: HTMLElement;
  private grid: HTMLElement;
  private hotbar: HTMLElement;
  private weightEl: HTMLElement;

  constructor(state: GameState) {
    this.state = state;
    this.createUI();
    this.bindEvents();
  }

  private createUI(): void {
    // Main container
    this.container = document.createElement('div');
    this.container.id = 'inventory-ui';
    this.container.style.cssText = `
      position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%);
      width: 720px; height: 520px; background: rgba(20,20,20,0.97);
      border: 1px solid #3c3c3c; border-radius: 12px; overflow: hidden;
      display: none; flex-direction: column; z-index: 200;
      font-family: 'Inter', sans-serif; color: #f0f0f0;
      box-shadow: 0 20px 60px rgba(0,0,0,0.5);
    `;

    // Header
    const header = document.createElement('div');
    header.style.cssText = `
      display: flex; align-items: center; justify-content: space-between;
      padding: 1rem 1.5rem; background: #1e1e1e; border-bottom: 1px solid #3c3c3c;
    `;
    header.innerHTML = `
      <h2 style="margin:0; font-size:1.1rem; font-weight:600;">INVENTORY</h2>
      <button id="inv-close" style="background:#dc3232;border:none;color:#fff;width:32px;height:32px;border-radius:6px;cursor:pointer;font-size:1.2rem;">×</button>
    `;
    this.container.appendChild(header);

    // Content area
    const content = document.createElement('div');
    content.style.cssText = `
      display: flex; flex: 1; overflow: hidden; padding: 1rem;
      gap: 1rem; background: rgba(26,26,26,0.5);
    `;

    // Left: Grid
    const left = document.createElement('div');
    left.style.cssText = `width: 340px; flex-shrink: 0; display: flex; flex-direction: column; gap: 0.75rem;`;

    const gridTitle = document.createElement('div');
    gridTitle.style.cssText = `font-size:0.75rem; text-transform:uppercase; color:#a0a0a0; letter-spacing:0.05em;`;
    gridTitle.textContent = 'BACKPACK';
    left.appendChild(gridTitle);

    this.grid = document.createElement('div');
    this.grid.style.cssText = `
      display: grid; grid-template-columns: repeat(6, 1fr); gap: 6px;
      flex: 1; background: #141414; border-radius: 8px; padding: 12px;
    `;
    left.appendChild(this.grid);

    // Weight
    this.weightEl = document.createElement('div');
    this.weightEl.style.cssText = `text-align:right; font-size:0.8rem; color:#a0a0a0; font-family:'JetBrains Mono',monospace;`;
    left.appendChild(this.weightEl);

    // Right: Hotbar
    const right = document.createElement('div');
    right.style.cssText = `width: 340px; flex-shrink: 0; display: flex; flex-direction: column; gap: 0.75rem;`;

    const hotbarTitle = document.createElement('div');
    hotbarTitle.style.cssText = `font-size:0.75rem; text-transform:uppercase; color:#a0a0a0; letter-spacing:0.05em;`;
    hotbarTitle.textContent = 'HOTBAR (1-5)';
    right.appendChild(hotbarTitle);

    this.hotbar = document.createElement('div');
    this.hotbar.style.cssText = `
      display: flex; gap: 8px; flex: 1; background: #141414; border-radius: 8px; padding: 12px;
      align-items: center; justify-content: center;
    `;
    right.appendChild(this.hotbar);

    content.appendChild(left);
    content.appendChild(right);
    this.container.appendChild(content);
    document.getElementById('ui')!.appendChild(this.container);

    // Create slots
    this.createGridSlots();
    this.createHotbarSlots();

    // Close button
    document.getElementById('inv-close')!.addEventListener('click', () => this.close());
  }

  private createGridSlots(): void {
    for (let i = 0; i < CONSTANTS.INVENTORY_SLOTS; i++) {
      const slot = this.createSlot(i, 'inventory');
      this.grid.appendChild(slot);
    }
  }

  private createHotbarSlots(): void {
    for (let i = 0; i < CONSTANTS.HOTBAR_SLOTS; i++) {
      const slot = this.createSlot(i, 'hotbar');
      slot.style.cssText += `
        width: 56px; height: 56px; font-size: 1rem;
        box-shadow: inset 0 0 0 2px #00b4ff;
      `;
      const keyLabel = document.createElement('span');
      keyLabel.style.cssText = `position:absolute; top:2px; left:4px; font-size:0.65rem; color:#888; font-weight:600;`;
      keyLabel.textContent = (i + 1).toString();
      slot.appendChild(keyLabel);
      this.hotbar.appendChild(slot);
    }
  }

  private createSlot(index: number, type: 'inventory' | 'hotbar'): HTMLElement {
    const slot = document.createElement('div');
    slot.dataset.index = index.toString();
    slot.dataset.type = type;
    slot.style.cssText = `
      width: 44px; height: 44px; background: #1e1e1e;
      border: 1px solid #3c3c3c; border-radius: 6px;
      position: relative; display: flex; align-items: center;
      justify-content: center; cursor: pointer; transition: all 0.15s;
    `;

    const icon = document.createElement('img');
    icon.style.cssText = `width: 32px; height: 32px; object-fit: contain; display: none;`;
    icon.alt = '';
    slot.appendChild(icon);

    const qty = document.createElement('span');
    qty.style.cssText = `
      position: absolute; bottom: 2px; right: 4px;
      font-size: 0.7rem; font-weight: 700; color: #fff;
      font-family: 'JetBrains Mono', monospace; text-shadow: 0 0 3px #000;
      display: none;
    `;
    slot.appendChild(qty);

    const rarityBorder = document.createElement('div');
    rarityBorder.style.cssText = `
      position: absolute; inset: -2px; border-radius: 8px;
      border: 2px solid transparent; pointer-events: none; display: none;
    `;
    slot.appendChild(rarityBorder);

    slot.addEventListener('mouseenter', () => {
      if (!slot.dataset.empty) slot.style.borderColor = '#00b4ff';
    });
    slot.addEventListener('mouseleave', () => {
      if (!slot.dataset.empty) slot.style.borderColor = '#3c3c3c';
    });

    slot.addEventListener('mousedown', (e) => this.onDragStart(e, slot));
    slot.addEventListener('mouseup', () => this.onDragEnd(slot));
    slot.addEventListener('contextmenu', (e) => { e.preventDefault(); this.showContextMenu(slot); });

    return slot;
  }

  private bindEvents(): void {
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') { e.preventDefault(); this.toggle(); }
      if (e.key >= '1' && e.key <= '5') this.useHotbar(parseInt(e.key) - 1);
    });

    document.addEventListener('mousemove', (e) => this.onDragMove(e));
    document.addEventListener('mouseup', () => this.onDragEnd(null));
  }

  private onDragStart(e: MouseEvent, slot: HTMLElement): void {
    if (slot.dataset.empty) return;
    this.draggedItem = this.getItemFromSlot(slot);
    this.dragFromSlot = slot;
    slot.style.opacity = '0.4';

    // Create drag ghost
    this.dragGhost = document.createElement('div');
    this.dragGhost.style.cssText = `
      position: fixed; pointer-events: none; z-index: 9999;
      width: 44px; height: 44px; background: #1e1e1e; border: 2px solid #00b4ff;
      border-radius: 6px; display: flex; align-items: center; justify-content: center;
      box-shadow: 0 4px 20px rgba(0,0,0,0.5); transform: translate(-50%, -50%);
    `;
    this.dragGhost.innerHTML = slot.innerHTML;
    document.body.appendChild(this.dragGhost);
    this.onDragMove(e);
  }

  private onDragMove(e: MouseEvent): void {
    if (this.dragGhost) {
      this.dragGhost.style.left = `${e.clientX}px`;
      this.dragGhost.style.top = `${e.clientY}px`;
    }
  }

  private onDragEnd(targetSlot: HTMLElement | null): void {
    if (!this.draggedItem || !this.dragFromSlot) return;

    if (targetSlot && targetSlot !== this.dragFromSlot) {
      this.swapItems(this.dragFromSlot, targetSlot);
    }

    this.dragFromSlot.style.opacity = '1';
    this.draggedItem = null;
    this.dragFromSlot = null;
    if (this.dragGhost) this.dragGhost.remove();
    this.dragGhost = null;
  }

  private swapItems(from: HTMLElement, to: HTMLElement): void {
    const fromItem = this.getItemFromSlot(from);
    const toItem = this.getItemFromSlot(to);

    // Update state (simplified)
    console.log(`Swap: ${from.dataset.type}[${from.dataset.index}] <-> ${to.dataset.type}[${to.dataset.index}]`);
    this.render();
  }

  private getItemFromSlot(slot: HTMLElement): InventoryItem | null {
    // Would look up from state.inventory
    return null;
  }

  private showContextMenu(slot: HTMLElement): void {
    // Right-click menu: Use, Drop, Split
    console.log('Context menu for slot', slot.dataset);
  }

  private useHotbar(index: number): void {
    const slot = this.hotbar.children[index] as HTMLElement;
    if (slot && !slot.dataset.empty) {
      console.log('Use hotbar item', index);
    }
  }

  private render(): void {
    // Update grid
    Array.from(this.grid.children).forEach((slot, i) => this.updateSlot(slot as HTMLElement, i, 'inventory'));
    Array.from(this.hotbar.children).forEach((slot, i) => this.updateSlot(slot as HTMLElement, i, 'hotbar'));

    // Weight
    const w = this.state.player.inventoryWeight || 0;
    const mw = this.state.player.maxWeight || 100;
    this.weightEl.textContent = `Weight: ${w.toFixed(1)} / ${mw} kg`;
    this.weightEl.style.color = w / mw > 0.8 ? '#ff8c00' : w / mw > 1 ? '#dc3232' : '#a0a0a0';
  }

  private updateSlot(slot: HTMLElement, index: number, type: 'inventory' | 'hotbar'): void {
    const icon = slot.querySelector('img') as HTMLImageElement;
    const qty = slot.querySelector('span') as HTMLElement;
    const border = slot.querySelector('div') as HTMLElement;

    // Get item from state (simplified)
    const item = null; // this.state.inventory.get(index);

    if (item) {
      slot.dataset.empty = 'false';
      icon.src = item.icon || '';
      icon.style.display = 'block';
      qty.textContent = item.quantity > 1 ? `x${item.quantity}` : '';
      qty.style.display = item.quantity > 1 ? 'block' : 'none';

      // Rarity border
      const rarityColors: Record<string, string> = {
        Common: '#b4b4b4', Uncommon: '#32c832', Rare: '#3296ff',
        Epic: '#b432ff', Legendary: '#ffb400', Mythic: '#ff3232'
      };
      border.style.borderColor = rarityColors[item.rarity] || '#3c3c3c';
      border.style.display = 'block';

      slot.style.borderColor = rarityColors[item.rarity] || '#3c3c3c';
    } else {
      slot.dataset.empty = 'true';
      icon.style.display = 'none';
      qty.style.display = 'none';
      border.style.display = 'none';
      slot.style.borderColor = '#3c3c3c';
    }
  }

  private draggedItem: any = null;
  private dragFromSlot: HTMLElement | null = null;
  private dragGhost: HTMLElement | null = null;

  toggle(): void {
    this.isOpen = !this.isOpen;
    this.container.style.display = this.isOpen ? 'flex' : 'none';
    if (this.isOpen) {
      this.render();
      // Lock mouse
      document.exitPointerLock?.();
    }
  }

  close(): void {
    this.isOpen = false;
    this.container.style.display = 'none';
    document.body.style.cursor = '';
    // Re-lock mouse if in game
  }
}