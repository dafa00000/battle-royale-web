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

    // Header
    const header = document.createElement('div');
    header.style.cssText = `
      display: flex; justify-content: space-between; align-items: center;
      padding: 1rem 1.5rem; background: #1e1e1e; border-bottom: 1px solid #3c3c3c;
      border-radius: 12px 12px 0 0;
    `;
    header.innerHTML = `
      <h2 style="margin:0; font-size:1.1rem; font-weight:600;">INVENTORY</h2>
      <button id="inv-close" style="background:#dc3232;border:none;color:#fff;width:32px;height:32px;border-radius:6px;cursor:pointer;font-size:1.25rem;">×</button>
    `;
    this.container.appendChild(header);

    // Content area
    const content = document.createElement('div');
    content.style.cssText = 'flex:1; display:flex; padding:1rem; gap:1rem; overflow:hidden;';

    // Left: Grid
    const left = document.createElement('div');
    left.style.cssText = 'width:340px; flex-shrink:0; display:flex; flex-direction:column; gap:0.5rem;';
    left.innerHTML = '<h3 style="margin:0 0 0.5rem; color:#a0a0a0; font-size:0.75rem; text-transform:uppercase;">BACKPACK</h3>';
    this.grid = document.createElement('div');
    this.grid.style.cssText = `
      flex:1; display:grid; grid-template-columns: repeat(6, 1fr); gap:6px;
      background:#141414; border-radius:8px; padding:12px;
    `;
    left.appendChild(this.grid);

    // Weight
    this.weightEl = document.createElement('div');
    this.weightEl.style.cssText = 'text-align:right; color:#a0a0a0; font-family:"JetBrains Mono",monospace; font-size:0.85rem;';
    left.appendChild(this.weightEl);
    content.appendChild(left);

    // Right: Hotbar
    const right = document.createElement('div');
    right.style.cssText = 'width:340px; flex-shrink:0; display:flex; flex-direction:column; gap:0.5rem;';
    right.innerHTML = '<h3 style="margin:0 0 0.5rem; color:#a0a0a0; font-size:0.75rem; text-transform:uppercase;">HOTBAR (1-5)</h3>';
    this.hotbar = document.createElement('div');
    this.hotbar.style.cssText = `
      display:flex; gap:8px; padding:0.5rem; background:#1e1e1e; border-radius:8px;
      justify-content:center;
    `;
    right.appendChild(this.hotbar);
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
      slot.style.cssText += 'width:56px;height:56px;font-size:1rem;box-shadow:inset 0 0 0 2px #00b4ff;';
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
      width:50px;height:50px;background:#1e1e1e;border:1px solid #3c3c3c;
      border-radius:6px;position:relative;cursor:pointer;display:flex;
      align-items:center;justify-content:center;transition:all 0.15s;
    `;

    const icon = document.createElement('img');
    icon.className = 'slot-icon';
    icon.style.cssText = 'width:80%;height:80%;object-fit:contain;display:none;';
    slot.appendChild(icon);

    const qty = document.createElement('span');
    qty.className = 'slot-qty';
    qty.style.cssText = 'position:absolute;bottom:2px;right:4px;font-size:0.7rem;font-weight:700;color:#fff;font-family:"JetBrains Mono",monospace;text-shadow:0 0 3px #000;display:none;';
    slot.appendChild(qty);

    const border = document.createElement('div');
    border.style.cssText = 'position:absolute;inset:-2px;border-radius:8px;border:2px solid transparent;pointer-events:none;display:none;';
    slot.appendChild(border);

    // Drag events
    slot.addEventListener('mousedown', (e) => this.onDragStart(e, slot));
    slot.addEventListener('dragover', (e) => e.preventDefault());
    slot.addEventListener('drop', (e) => this.onDrop(e, slot));
    slot.addEventListener('contextmenu', (e) => this.showContextMenu(e, slot));

    // Hover
    slot.addEventListener('mouseenter', () => {
      if (!slot.dataset.empty) slot.style.borderColor = '#00b4ff';
    });
    slot.addEventListener('mouseleave', () => {
      if (!slot.dataset.empty) slot.style.borderColor = '#3c3c3c';
    });

    return slot;
  }

  private bindEvents(): void {
    document.getElementById('inv-close')!.addEventListener('click', () => this.close());
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') { e.preventDefault(); this.toggle(); }
      if (e.key >= '1' && e.key <= '5') this.useHotbar(parseInt(e.key) - 1);
    });
    document.addEventListener('mousemove', (e) => this.onDragMove(e));
    document.addEventListener('mouseup', () => this.onDragEnd());
  }

  private createSlot(index: number, type: 'inventory' | 'hotbar'): HTMLElement {
    const slot = document.createElement('div');
    slot.dataset.index = index.toString();
    slot.dataset.type = type;
    slot.className = 'inv-slot';
    slot.style.cssText = `
      width:50px;height:50px;background:#1e1e1e;border:1px solid #3c3c3c;
      border-radius:6px;position:relative;cursor:pointer;display:flex;
      align-items:center;justify-content:center;transition:all 0.15s;flex-shrink:0;
    `;

    const icon = document.createElement('img');
    icon.style.cssText = 'width:80%;height:80%;object-fit:contain;pointer-events:none;display:none;';
    slot.appendChild(icon);

    const qty = document.createElement('span');
    qty.style.cssText = 'position:absolute;bottom:2px;right:4px;font-size:0.7rem;font-weight:700;color:#fff;font-family:"JetBrains Mono",monospace;display:none;';
    slot.appendChild(qty);

    const border = document.createElement('div');
    border.style.cssText = 'position:absolute;inset:-2px;border-radius:8px;border:2px solid transparent;pointer-events:none;display:none;';
    slot.appendChild(border);

    slot.addEventListener('mousedown', (e) => this.onDragStart(e, slot));
    slot.addEventListener('dragover', (e) => e.preventDefault());
    slot.addEventListener('drop', (e) => this.onDrop(e, slot));
    slot.addEventListener('contextmenu', (e) => { e.preventDefault(); this.showContextMenu(e, slot); });

    slot.addEventListener('mouseenter', () => { if (!slot.dataset.empty) slot.style.borderColor = '#00b4ff'; });
    slot.addEventListener('mouseleave', () => { if (!slot.dataset.empty) slot.style.borderColor = '#3c3c3c'; });

    return slot;
  }

  private bindEvents(): void {
    document.getElementById('inv-close')!.addEventListener('click', () => this.close());
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') { e.preventDefault(); this.toggle(); }
      if (e.key >= '1' && e.key <= '5') this.useHotbar(parseInt(e.key) - 1);
    });
    document.addEventListener('mousemove', (e) => this.onDragMove(e));
    document.addEventListener('mouseup', () => this.onDragEnd());
  }

  // ========== DRAG & DROP ==========
  private draggedItem: InventoryItem | null = null;
  private draggedFromSlot: HTMLElement | null = null;
  private dragGhost: HTMLElement | null = null;

  private onDragStart(e: MouseEvent, slot: HTMLElement): void {
    if (slot.dataset.empty) return;
    this.draggedFromSlot = slot;
    const item = this.getItemAtSlot(parseInt(slot.dataset.index!), slot.dataset.type as 'inventory' | 'hotbar');
    if (!item) return;

    this.draggedItem = item;
    slot.style.opacity = '0.4';

    this.dragGhost = document.createElement('div');
    this.dragGhost.style.cssText = `
      position:fixed;pointer-events:none;z-index:9999;width:50px;height:50px;
      background:#1e1e1e;border:2px solid #00b4ff;border-radius:6px;
      display:flex;align-items:center;justify-content:center;transform:translate(-50%,-50%);
      box-shadow:0 4px 20px rgba(0,0,0,0.5);
    `;
    this.dragGhost.innerHTML = slot.innerHTML;
    document.body.appendChild(this.dragGhost);
  }

  private onDragMove(e: MouseEvent): void {
    if (this.dragGhost) {
      this.dragGhost.style.left = `${e.clientX}px`;
      this.dragGhost.style.top = `${e.clientY}px`;
    }
  }

  private onDrop(e: DragEvent, targetSlot: HTMLElement): void {
    e.preventDefault();
    if (!this.draggedItem || !this.draggedFromSlot) return;

    const fromIndex = parseInt(this.draggedFromSlot.dataset.index!);
    const fromType = this.draggedFromSlot.dataset.type as 'inventory' | 'hotbar';
    const toIndex = parseInt(targetSlot.dataset.index!);
    const toType = targetSlot.dataset.type as 'inventory' | 'hotbar';

    // Swap or move
    this.moveItem(fromIndex, fromType, toIndex, toType);
    this.render();
    this.cleanupDrag();
  }

  private onDragEnd(): void {
    if (this.draggedFromSlot) {
      this.draggedFromSlot.style.opacity = '1';
    }
    this.draggedItem = null;
    this.draggedFromSlot = null;
    if (this.dragGhost) this.dragGhost.remove();
    this.dragGhost = null;
  }

  private onDragMove(e: MouseEvent): void {
    if (this.dragGhost) {
      this.dragGhost.style.left = `${e.clientX}px`;
      this.dragGhost.style.top = `${e.clientY}px`;
    }
  }

  private moveItem(fromIndex: number, fromType: 'inventory' | 'hotbar', toIndex: number, toType: 'inventory' | 'hotbar'): void {
    // In a real implementation, would modify state.inventory
    console.log(`Move ${fromType}[${fromIndex}] -> ${toType}[${toIndex}]`);
  }

  private getItemAtSlot(index: number, type: 'inventory' | 'hotbar'): InventoryItem | null {
    // Would query actual inventory state
    return null;
  }

  private render(): void {
    // Update grid
    Array.from(this.grid.children).forEach((slot, i) => this.updateSlot(slot as HTMLElement, i, 'inventory'));
    Array.from(this.hotbar.children).forEach((slot, i) => this.updateSlot(slot as HTMLElement, i, 'hotbar'));
    this.updateWeight();
  }

  private updateSlot(slot: HTMLElement, index: number, type: 'inventory' | 'hotbar'): void {
    const item = this.getItemAtSlot(index, type);
    const icon = slot.querySelector('.slot-icon') as HTMLImageElement;
    const qty = slot.querySelector('.slot-qty') as HTMLElement;
    const border = slot.querySelector('div[style*="border-radius:8px"]') as HTMLElement;

    if (item) {
      slot.dataset.empty = 'false';
      if (icon) { icon.src = item.icon || ''; icon.style.display = 'block'; }
      if (qty) { qty.textContent = item.quantity > 1 ? `x${item.quantity}` : ''; qty.style.display = item.quantity > 1 ? 'block' : 'none'; }
      if (border) {
        const rarityColors: Record<string, string> = {
          Common: '#b4b4b4', Uncommon: '#32c832', Rare: '#3296ff',
          Epic: '#b432ff', Legendary: '#ffb400', Mythic: '#ff3232'
        };
        border.style.borderColor = rarityColors[item.rarity] || '#3c3c3c';
        border.style.display = 'block';
      }
    } else {
      slot.dataset.empty = 'true';
      if (icon) { icon.style.display = 'none'; icon.src = ''; }
      if (qty) { qty.style.display = 'none'; qty.textContent = ''; }
      if (border) { border.style.display = 'none'; }
      slot.style.borderColor = '#3c3c3c';
    }
  }

  private updateWeight(): void {
    const w = this.state.player.inventoryWeight || 0;
    const mw = this.state.player.maxWeight || 100;
    this.weightEl!.textContent = `Weight: ${w.toFixed(1)} / ${mw} kg`;
    this.weightEl!.style.color = w / mw > 0.8 ? '#ff8c00' : w / mw > 1 ? '#dc3232' : '#a0a0a0';
  }

  private showContextMenu(slot: HTMLElement, e: MouseEvent): void {
    e.preventDefault();
    // Would show context menu with Use, Drop, Split
    console.log('Context menu for slot', slot.dataset.index, slot.dataset.type);
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

  private useHotbar(index: number): void {
    console.log('Use hotbar slot', index);
  }

  private updateWeight(): void {
    const w = this.state.player.inventoryWeight || 0;
    const mw = this.state.player.maxWeight || 100;
    this.weightEl!.textContent = `Weight: ${w.toFixed(1)} / ${mw} kg`;
    this.weightEl!.style.color = w / mw > 0.8 ? '#ff8c00' : w / mw > 1 ? '#dc3232' : '#a0a0a0';
  }
}