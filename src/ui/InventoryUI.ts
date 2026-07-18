// ============================================
// INVENTORY UI - Grid inventory (30 slots), hotbar 5 slots
// Item icons, rarity border, drag-drop, context menu (use/drop/split)
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
  private draggedItem: InventoryItem | null = null;
  private dragFromSlot: number | null = null;
  private dragFromType: 'inventory' | 'hotbar' | null = null;
  private dragGhost: HTMLElement | null = null;

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
    this.container = document.createElement('div');
    this.container.id = 'inventory-ui';
    this.container.style.cssText = `
      position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%);
      width: 720px; height: 520px; background: rgba(20,20,20,0.97);
      border: 1px solid #3c3c3c; border-radius: 12px;
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
    left.style.cssText = 'width:340px; flex-shrink:0; display:flex; flex-direction:column; gap:0.5rem;';

    const gridTitle = document.createElement('div');
    gridTitle.style.cssText = 'font-size:0.75rem; text-transform:uppercase; color:#a0a0a0; letter-spacing:0.05em;';
    gridTitle.textContent = 'BACKPACK';
    left.appendChild(gridTitle);

    this.grid = document.createElement('div');
    this.grid.style.cssText = `
      flex:1; display:grid; grid-template-columns: repeat(6, 1fr); gap:6px;
      background:#141414; border-radius:8px; padding:12px;
    `;
    left.appendChild(this.grid);

    this.weightEl = document.createElement('div');
    this.weightEl.style.cssText = 'text-align:right; color:#a0a0a0; font-family:"JetBrains Mono",monospace; font-size:0.85rem;';
    left.appendChild(this.weightEl);

    const right = document.createElement('div');
    right.style.cssText = 'width:340px; flex-shrink:0; display:flex; flex-direction:column; gap:0.5rem;';

    right.innerHTML = '<h3 style="margin:0 0 0.5rem; color:#a0a0a0; font-size:0.75rem; text-transform:uppercase;">HOTBAR (1-5)</h3>';
    this.hotbar = document.createElement('div');
    this.hotbar.style.cssText = `
      display:flex; gap:8px; flex:1; background:#141414; border-radius:8px; padding:12px;
      align-items:center; justify-content:center;
    `;
    right.appendChild(this.hotbar);

    const content = document.createElement('div');
    content.style.cssText = 'flex:1; display:flex; padding:1rem; gap:1rem; overflow:hidden;';
    content.appendChild(left);
    content.appendChild(right);
    this.container.appendChild(content);

    this.createGridSlots();
    this.createHotbarSlots();

    document.getElementById('inv-close')!.addEventListener('click', () => this.close());
    document.getElementById('ui')!.appendChild(this.container);
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
      slot.style.cssText += `width:56px;height:56px;box-shadow:inset 0 0 0 2px #00b4ff;`;
      const keyLabel = document.createElement('span');
      keyLabel.style.cssText = `position:absolute;top:2px;left:4px;font-size:0.65rem;color:#888;font-weight:600;`;
      keyLabel.textContent = (i + 1).toString();
      slot.appendChild(keyLabel);
      this.hotbar.appendChild(slot);
    }
  }

  private createSlot(index: number, type: 'inventory' | 'hotbar'): HTMLElement {
    const slot = document.createElement('div');
    slot.dataset.index = index.toString();
    slot.dataset.type = type;
    slot.className = 'inv-slot';
    slot.style.cssText = `
      width:44px;height:44px;background:#1e1e1e;border:1px solid #3c3c3c;
      border-radius:6px;position:relative;display:flex;align-items:center;
      justify-content:center;cursor:pointer;transition:all 0.15s;
    `;

    const icon = document.createElement('img');
    icon.style.cssText = 'width:80%;height:80%;object-fit:contain;display:none;';
    slot.appendChild(icon);

    const qty = document.createElement('span');
    qty.style.cssText = 'position:absolute;bottom:2px;right:4px;font-size:0.7rem;font-weight:700;color:#fff;font-family:"JetBrains Mono",monospace;text-shadow:0 0 3px #000;display:none;';
    slot.appendChild(qty);

    const rarityBorder = document.createElement('div');
    rarityBorder.style.cssText = 'position:absolute;inset:-2px;border-radius:8px;border:2px solid transparent;pointer-events:none;display:none;';
    slot.appendChild(rarityBorder);

    slot.addEventListener('mouseenter', () => { if (!slot.dataset.empty) slot.style.borderColor = '#00b4ff'; });
    slot.addEventListener('mouseleave', () => { if (!slot.dataset.empty) slot.style.borderColor = '#3c3c3c'; });
    slot.addEventListener('mousedown', (e) => this.onDragStart(e, slot));
    slot.addEventListener('contextmenu', (e) => { e.preventDefault(); this.showContextMenu(slot); });

    return slot;
  }

  private bindEvents(): void {
    this.container.querySelector('#inv-close')!.addEventListener('click', () => this.close());
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') { e.preventDefault(); this.toggle(); }
      if (e.key >= '1' && e.key <= '5') this.useHotbar(parseInt(e.key) - 1);
    });
    document.addEventListener('mousemove', (e) => this.onDragMove(e));
    document.addEventListener('mouseup', () => this.onDragEnd());
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
      slot.style.cssText += `width:56px;height:56px;box-shadow:inset 0 0 0 2px #00b4ff;`;
      const keyLabel = document.createElement('span');
      keyLabel.style.cssText = 'position:absolute;top:2px;left:4px;font-size:0.65rem;color:#888;font-weight:600;';
      keyLabel.textContent = (i + 1).toString();
      slot.appendChild(keyLabel);
      this.hotbar.appendChild(slot);
    }
  }

  private createSlot(index: number, type: 'inventory' | 'hotbar'): HTMLElement {
    const slot = document.createElement('div');
    slot.dataset.index = index.toString();
    slot.dataset.type = type;
    slot.className = 'inv-slot';
    slot.style.cssText = `
      width:44px;height:44px;background:#1e1e1e;border:1px solid #3c3c3c;
      border-radius:6px;position:relative;display:flex;align-items:center;
      justify-content:center;cursor:pointer;transition:all 0.15s;
    `;

    const icon = document.createElement('img');
    icon.style.cssText = 'width:80%;height:80%;object-fit:contain;pointer-events:none;display:none;';
    slot.appendChild(icon);

    const qty = document.createElement('span');
    qty.style.cssText = 'position:absolute;bottom:2px;right:4px;font-size:0.7rem;font-weight:700;color:#fff;font-family:"JetBrains Mono",monospace;text-shadow:0 0 3px #000;display:none;';
    slot.appendChild(qty);

    const rarityBorder = document.createElement('div');
    rarityBorder.style.cssText = 'position:absolute;inset:-2px;border-radius:8px;border:2px solid transparent;pointer-events:none;display:none;';
    slot.appendChild(rarityBorder);

    slot.addEventListener('mouseenter', () => { if (!slot.dataset.empty) slot.style.borderColor = '#00b4ff'; });
    slot.addEventListener('mouseleave', () => { if (!slot.dataset.empty) slot.style.borderColor = '#3c3c3c'; });
    slot.addEventListener('mousedown', (e) => this.onDragStart(e, slot));
    slot.addEventListener('contextmenu', (e) => { e.preventDefault(); this.showContextMenu(slot); });

    return slot;
  }

  private bindEvents(): void {
    this.container.querySelector('#inv-close')!.addEventListener('click', () => this.close());
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') { e.preventDefault(); this.toggle(); }
      if (e.key >= '1' && e.key <= '5') this.useHotbar(parseInt(e.key) - 1);
    });

    document.addEventListener('mousemove', (e) => this.onDragMove(e));
    document.addEventListener('mouseup', () => this.onDragEnd());
  }

  private onDragStart(e: MouseEvent, slot: HTMLElement): void {
    const item = this.getItemAtSlot(slot);
    if (!item) return;

    this.draggedItem = item;
    this.dragFromSlot = parseInt(slot.dataset.index!);
    this.dragFromType = slot.dataset.type as 'inventory' | 'hotbar';

    this.dragGhost = document.createElement('div');
    this.dragGhost.style.cssText = `
      position:fixed;pointer-events:none;z-index:9999;
      width:44px;height:44px;background:#1e1e1e;border:2px solid #00b4ff;
      border-radius:6px;display:flex;align-items:center;justify-content:center;
      box-shadow:0 4px 20px rgba(0,0,0,0.5);transform:translate(-50%,-50%);
    `;
    this.dragGhost.innerHTML = slot.innerHTML;
    document.body.appendChild(this.dragGhost);
    this.dragGhost.style.left = `${e.clientX}px`;
    this.dragGhost.style.top = `${e.clientY}px`;

    slot.style.opacity = '0.4';
    document.addEventListener('mousemove', this.onDragMove.bind(this));
    document.addEventListener('mouseup', this.onDragEnd.bind(this));
  }

  private onDragMove(e: MouseEvent): void {
    if (this.dragGhost) {
      this.dragGhost.style.left = `${e.clientX}px`;
      this.dragGhost.style.top = `${e.clientY}px`;
    }
  }

  private onDragEnd(): void {
    if (!this.draggedItem || !this.dragFromSlot) return;

    const dropTarget = document.elementFromPoint(
      this.dragGhost?.offsetLeft || 0,
      this.dragGhost?.offsetTop || 0
    );

    const targetSlot = dropTarget?.closest('.inv-slot') as HTMLElement | null;
    if (targetSlot && targetSlot !== this.dragFromSlot as HTMLElement) {
      this.swapItems(this.dragFromSlot, parseInt(targetSlot.dataset.index!), this.dragFromType!, targetSlot.dataset.type as 'inventory' | 'hotbar');
    }

    this.cleanupDrag();
  }

  private cleanupDrag(): void {
    if (this.dragFromSlot) (this.dragFromSlot as HTMLElement).style.opacity = '1';
    if (this.dragGhost) this.dragGhost.remove();
    this.draggedItem = null;
    this.dragFromSlot = null;
    this.dragFromType = null;
    this.dragGhost = null;
  }

  private swapItems(fromIndex: number, toIndex: number, fromType: 'inventory' | 'hotbar', toType: 'inventory' | 'hotbar'): void {
    console.log(`Swap ${fromType}[${fromIndex}] <-> ${toType}[${toIndex}]`);
  }

  private getItemAtSlot(slot: HTMLElement): InventoryItem | null {
    return null;
  }

  private showContextMenu(slot: HTMLElement): void {
    console.log('Context menu for slot', slot.dataset.index);
  }

  private onDragMove(e: MouseEvent): void {
    if (this.dragGhost) {
      this.dragGhost.style.left = `${e.clientX}px`;
      this.dragGhost.style.top = `${e.clientY}px`;
    }
  }

  private onDragEnd(): void {
    if (!this.draggedItem || this.dragFromSlot === null) return;

    const targetSlot = document.elementFromPoint(
      this.dragGhost?.offsetLeft || 0,
      this.dragGhost?.offsetTop || 0
    )?.closest('.inv-slot') as HTMLElement | null;

    if (targetSlot && targetSlot !== this.dragFromSlot) {
      this.swapItems(this.dragFromSlot, parseInt(targetSlot.dataset.index!), this.dragFromType!, targetSlot.dataset.type as 'inventory' | 'hotbar');
    }

    this.cleanupDrag();
  }

  private cleanupDrag(): void {
    if (this.dragFromSlot) (this.dragFromSlot as HTMLElement).style.opacity = '1';
    if (this.dragGhost) this.dragGhost.remove();
    this.draggedItem = null;
    this.dragFromSlot = null;
    this.dragFromType = null;
    this.dragGhost = null;
  }

  private swapItems(fromIndex: number, toIndex: number, fromType: 'inventory' | 'hotbar', toType: 'inventory' | 'hotbar'): void {
    console.log(`Swap ${fromType}[${fromIndex}] <-> ${toType}[${toIndex}]`);
  }

  private getItemAtSlot(slot: HTMLElement): InventoryItem | null {
    return null;
  }

  private showContextMenu(slot: HTMLElement): void {
    console.log('Context menu for slot', slot.dataset.index);
  }

  private render(): void {
    Array.from(this.grid.children).forEach((slot, i) => this.updateSlot(slot as HTMLElement, i, 'inventory'));
    Array.from(this.hotbar.children).forEach((slot, i) => this.updateSlot(slot as HTMLElement, i, 'hotbar'));

    const w = this.state.player.inventoryWeight || 0;
    const mw = this.state.player.maxWeight || 100;
    this.weightEl.textContent = `Weight: ${w.toFixed(1)} / ${mw} kg`;
    this.weightEl.style.color = w / mw > 0.8 ? '#ff8c00' : w / mw > 1 ? '#dc3232' : '#a0a0a0';
  }

  private updateSlot(slot: HTMLElement, index: number, type: 'inventory' | 'hotbar'): void {
    const icon = slot.querySelector('img') as HTMLImageElement;
    const qty = slot.querySelector('span') as HTMLElement;
    const border = slot.querySelector('div') as HTMLElement;

    const item = this.getItemAtSlot(slot);
    if (item) {
      slot.dataset.empty = 'false';
      icon.src = item.icon || '';
      icon.style.display = 'block';
      qty.textContent = item.quantity > 1 ? `x${item.quantity}` : '';
      qty.style.display = item.quantity > 1 ? 'block' : 'none';

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

  private draggedItem: InventoryItem | null = null;
  private dragFromSlot: number | null = null;
  private dragFromType: 'inventory' | 'hotbar' | null = null;
  private dragGhost: HTMLElement | null = null;

  private onDragMove(e: MouseEvent): void {
    if (this.dragGhost) {
      this.dragGhost.style.left = `${e.clientX}px`;
      this.dragGhost.style.top = `${e.clientY}px`;
    }
  }

  private onDragEnd(): void {
    this.cleanupDrag();
  }

  private cleanupDrag(): void {
    if (this.dragFromSlot) (this.dragFromSlot as HTMLElement).style.opacity = '1';
    if (this.dragGhost) this.dragGhost.remove();
    this.draggedItem = null;
    this.dragFromSlot = null;
    this.dragFromType = null;
    this.dragGhost = null;
  }

  private swapItems(fromIndex: number, toIndex: number, fromType: 'inventory' | 'hotbar', toType: 'inventory' | 'hotbar'): void {
    console.log(`Swap ${fromType}[${fromIndex}] <-> ${toType}[${toIndex}]`);
  }

  private getItemAtSlot(slot: HTMLElement): InventoryItem | null {
    return null;
  }

  private showContextMenu(slot: HTMLElement): void {
    console.log('Context menu for slot', slot.dataset.index);
  }

  private render(): void {
    Array.from(this.grid.children).forEach((slot, i) => this.updateSlot(slot as HTMLElement, i, 'inventory'));
    Array.from(this.hotbar.children).forEach((slot, i) => this.updateSlot(slot as HTMLElement, i, 'hotbar'));

    const w = this.state.player.inventoryWeight || 0;
    const mw = this.state.player.maxWeight || 100;
    this.weightEl.textContent = `Weight: ${w.toFixed(1)} / ${mw} kg`;
    this.weightEl.style.color = w / mw > 0.8 ? '#ff8c00' : w / mw > 1 ? '#dc3232' : '#a0a0a0';
  }

  private updateSlot(slot: HTMLElement, index: number, type: 'inventory' | 'hotbar'): void {
    const icon = slot.querySelector('img') as HTMLImageElement;
    const qty = slot.querySelector('span') as HTMLElement;
    const border = slot.querySelector('div') as HTMLElement;

    const item = this.getItemAtSlot(slot);
    if (item) {
      slot.dataset.empty = 'false';
      icon.src = item.icon || '';
      icon.style.display = 'block';
      qty.textContent = item.quantity > 1 ? `x${item.quantity}` : '';
      qty.style.display = item.quantity > 1 ? 'block' : 'none';

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

  toggle(): void {
    this.isOpen = !this.isOpen;
    this.container.style.display = this.isOpen ? 'flex' : 'none';
    if (this.isOpen) {
      this.render();
      document.body.style.cursor = 'default';
      document.exitPointerLock?.();
    }
  }

  close(): void {
    this.isOpen = false;
    this.container.style.display = 'none';
  }

  private useHotbar(index: number): void {
    const slot = this.hotbar.children[index] as HTMLElement;
    if (slot && !slot.dataset.empty) {
      console.log('Use hotbar item', index);
    }
  }
}