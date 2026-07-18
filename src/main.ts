// ============================================
// BATTLE ROYALE - HUD PROTOTYPE (UI only, no 3D)
// ============================================

interface GameState {
  health: number; maxHealth: number;
  armor: number; maxArmor: number;
  ammo: number; ammoReserve: number; maxAmmo: number;
  weaponName: string; fireMode: 'AUTO' | 'SEMI';
  zonePhase: number; alive: number;
  isReloading: boolean;
}

const state: GameState = {
  health: 100, maxHealth: 100,
  armor: 0, maxArmor: 100,
  ammo: 30, ammoReserve: 90, maxAmmo: 30,
  weaponName: 'AK-74', fireMode: 'AUTO',
  zonePhase: 1, alive: 100,
  isReloading: false,
};

// ============================================
// HUD UPDATE
// ============================================
function updateHUD(): void {
  const hpEl = document.getElementById('hp');
  const hpBar = document.getElementById('hp-bar-fill');
  const ammoCur = document.getElementById('ammo-current');
  const ammoTot = document.getElementById('ammo-total');
  const fireModeEl = document.getElementById('fire-mode');
  const weaponEl = document.getElementById('weapon-name');
  const zoneEl = document.getElementById('zone-phase');
  const aliveEl = document.getElementById('alive');
  const lowHealth = document.getElementById('low-health');

  if (hpEl) hpEl.textContent = String(Math.round(state.health));
  if (hpBar) {
    const pct = (state.health / state.maxHealth) * 100;
    hpBar.style.width = `${pct}%`;
    hpBar.className = 'health-bar-fill';
    if (pct < 25) hpBar.classList.add('critical');
    else if (pct < 50) hpBar.classList.add('low');
  }
  if (lowHealth) lowHealth.classList.toggle('active', state.health < 25);

  if (ammoCur) ammoCur.textContent = String(state.ammo);
  if (ammoTot) ammoTot.textContent = String(state.ammoReserve);
  if (fireModeEl) fireModeEl.textContent = state.fireMode;
  if (weaponEl) weaponEl.textContent = state.weaponName;
  if (zoneEl) zoneEl.textContent = String(state.zonePhase);
  if (aliveEl) aliveEl.textContent = String(state.alive);
}

// ============================================
// SQUAD STATUS
// ============================================
interface SquadMember { name: string; hp: number; status: 'ALIVE' | 'DOWN' | 'DEAD'; }
let squad: SquadMember[] = [
  { name: 'Ghost_42', hp: 100, status: 'ALIVE' },
  { name: 'Recon_07', hp: 65, status: 'ALIVE' },
  { name: 'Viper_X', hp: 25, status: 'ALIVE' },
  { name: 'Dead_MeAT', hp: 0, status: 'DEAD' },
];

function renderSquad(): void {
  const container = document.getElementById('squad');
  if (!container) return;
  container.innerHTML = '';

  squad.forEach(member => {
    const div = document.createElement('div');
    div.className = 'squad-member';

    const initial = member.name[0].toUpperCase();
    const hpClass = member.hp > 60 ? '' : member.hp > 30 ? 'med' : 'low';

    div.innerHTML = `
      <div class="squad-avatar">${initial}</div>
      <div class="squad-info">
        <div style="display:flex;justify-content:space-between;align-items:center;">
          <span class="squad-name">${member.name}</span>
          <span class="squad-status ${member.status === 'DOWN' ? 'down' : ''}">${member.status}</span>
        </div>
        <div class="squad-hp"><div class="squad-hp-fill ${hpClass}" style="width:${member.hp}%"></div></div>
      </div>
    `;
    container.appendChild(div);
  });
}

// ============================================
// KILL FEED
// ============================================
function addKillFeed(killer: string, victim: string, weapon: string): void {
  const feed = document.getElementById('kill-feed');
  if (!feed) return;
  const entry = document.createElement('div');
  entry.className = 'kill-entry';
  entry.innerHTML = `<span class="killer">${killer}</span> ▸ <span class="weapon">${weapon}</span> ▸ <span class="victim">${victim}</span>`;
  feed.appendChild(entry);
  requestAnimationFrame(() => entry.classList.add('visible'));

  setTimeout(() => {
    entry.classList.remove('visible');
    setTimeout(() => entry.remove(), 400);
  }, 5000);
}

// ============================================
// INTERACTION PROMPT
// ============================================
const pickMessages = [
  { text: 'PICK UP M4A1 AMMO', sub: '5.56mm · 30 rounds' },
  { text: 'PICK UP MEDKIT', sub: '+25 HP' },
  { text: 'PICK UP KEVLAR VEST', sub: 'Armor · Lvl 2' },
  { text: 'PICK UP AWM', sub: '.300 Win Mag · 5 rounds' },
  { text: 'PICK UP FRAG GRENADE', sub: 'Throwable · Explosive' },
  { text: 'PICK UP ENERGY DRINK', sub: 'Sprint boost · 30s' },
  { text: 'ENTER VEHICLE', sub: 'UAZ · 4 seats' },
];

function showInteraction(msg: { text: string; sub: string }): void {
  const prompt = document.getElementById('interaction');
  const textEl = document.getElementById('interaction-text');
  const subEl = document.getElementById('interaction-sub');
  if (!prompt || !textEl || !subEl) return;

  textEl.textContent = msg.text;
  subEl.textContent = msg.sub;
  prompt.classList.add('visible');
}

function hideInteraction(): void {
  const prompt = document.getElementById('interaction');
  if (prompt) prompt.classList.remove('visible');
}

// ============================================
// ZONE WARNING
// ============================================
function showZoneWarning(phase: number, sub: string): void {
  const warn = document.getElementById('zone-warning');
  const subEl = document.getElementById('zone-warning-sub');
  if (!warn || !subEl) return;
  subEl.textContent = sub;
  warn.classList.add('visible');
}

function hideZoneWarning(): void {
  const warn = document.getElementById('zone-warning');
  if (warn) warn.classList.remove('visible');
}

// ============================================
// RADAR CANVAS
// ============================================
function drawRadar(): void {
  const canvas = document.getElementById('radar-canvas') as HTMLCanvasElement | null;
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  const w = canvas.width;
  const h = canvas.height;
  const cx = w / 2;
  const cy = h / 2;
  const radius = w / 2 - 10;

  // Clear
  ctx.fillStyle = 'rgba(15,15,20,0.6)';
  ctx.fillRect(0, 0, w, h);

  // Outer ring
  ctx.strokeStyle = 'rgba(0,180,255,0.3)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(cx, cy, radius, 0, Math.PI * 2);
  ctx.stroke();

  // Crosshair lines
  ctx.strokeStyle = 'rgba(0,180,255,0.15)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(cx, cy - radius); ctx.lineTo(cx, cy + radius);
  ctx.moveTo(cx - radius, cy); ctx.lineTo(cx + radius, cy);
  ctx.stroke();

  // Zone (shrinking circle)
  const zoneR = radius * (0.6 + Math.sin(Date.now() / 3000) * 0.1);
  ctx.strokeStyle = 'rgba(0,180,255,0.8)';
  ctx.lineWidth = 2;
  ctx.setLineDash([4, 4]);
  ctx.beginPath();
  ctx.arc(cx, cy, zoneR, 0, Math.PI * 2);
  ctx.stroke();
  ctx.setLineDash([]);

  // Next zone (orange)
  const nextR = radius * 0.4;
  ctx.strokeStyle = 'rgba(255,140,0,0.6)';
  ctx.lineWidth = 1.5;
  ctx.setLineDash([2, 4]);
  ctx.beginPath();
  ctx.arc(cx + 20, cy - 15, nextR, 0, Math.PI * 2);
  ctx.stroke();
  ctx.setLineDash([]);

  // Player dot
  ctx.fillStyle = '#00b4ff';
  ctx.beginPath();
  ctx.arc(cx, cy, 4, 0, Math.PI * 2);
  ctx.fill();

  // Player direction
  ctx.strokeStyle = '#00b4ff';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(cx, cy);
  ctx.lineTo(cx, cy - 12);
  ctx.stroke();

  // Enemy dots
  const enemyPositions = [
    { x: 0.2, y: -0.3 }, { x: -0.4, y: 0.2 }, { x: 0.3, y: 0.4 },
  ];
  enemyPositions.forEach(p => {
    if (Math.sin(Date.now() / 2000 + p.x * 10) > 0.3) return; // intermittent
    ctx.fillStyle = '#dc3232';
    ctx.beginPath();
    ctx.arc(cx + p.x * radius, cy + p.y * radius, 3, 0, Math.PI * 2);
    ctx.fill();
  });

  // Squad dots
  squad.forEach((m, i) => {
    if (m.status !== 'ALIVE') return;
    const angle = (i / squad.length) * Math.PI * 2 + Date.now() / 10000;
    const dist = radius * 0.4;
    ctx.fillStyle = '#00cc66';
    ctx.beginPath();
    ctx.arc(cx + Math.cos(angle) * dist, cy + Math.sin(angle) * dist, 2.5, 0, Math.PI * 2);
    ctx.fill();
  });
}

// ============================================
// GAS VIGNETTE
// ============================================
function updateGasEffect(intensity: number): void {
  const vignette = document.getElementById('gas-vignette');
  if (vignette) {
    vignette.style.opacity = (intensity * 0.5).toString();
    vignette.style.background = `radial-gradient(ellipse at center, transparent 30%, rgba(0,100,50,${intensity * 0.6}) 80%)`;
  }
}

// ============================================
// SIMULATION CONTROLS
// ============================================
(window as any).simReload = function (): void {
  if (state.isReloading) return;
  if (state.ammo === state.maxAmmo || state.ammoReserve <= 0) return;

  state.isReloading = true;
  const reloadText = document.getElementById('reload-text');
  reloadText?.classList.add('visible');

  setTimeout(() => {
    const needed = state.maxAmmo - state.ammo;
    const taken = Math.min(needed, state.ammoReserve);
    state.ammo += taken;
    state.ammoReserve -= taken;
    state.isReloading = false;
    reloadText?.classList.remove('visible');
    updateHUD();
  }, 2200);
};

(window as any).simDamage = function (): void {
  state.health = Math.max(0, state.health - 15);
  updateHUD();
};

(window as any).simHeal = function (): void {
  state.health = Math.min(state.maxHealth, state.health + 25);
  updateHUD();
};

(window as any).simPickup = function (): void {
  const msg = pickMessages[Math.floor(Math.random() * pickMessages.length)];
  showInteraction(msg);
  setTimeout(() => hideInteraction(), 2500);
};

(window as any).simKill = function (): void {
  const killers = ['Ghost_42', 'Recon_07', 'Viper', 'Sniper_K', 'Rusher66'];
  const victims = ['Runner99', 'Camper_1', 'NoobMaster', 'Loot_Goblin', 'AFK_Andy'];
  const weapons = ['AK-74', 'AWM', 'M416', 'Groza', 'Pan'];
  const k = killers[Math.floor(Math.random() * killers.length)];
  const v = victims[Math.floor(Math.random() * victims.length)];
  const w = weapons[Math.floor(Math.random() * weapons.length)];
  addKillFeed(k, v, w);
};

// ============================================
// KEYBOARD INPUT
// ============================================
document.addEventListener('keydown', (e: KeyboardEvent) => {
  const key = e.key.toLowerCase();
  switch (key) {
    case 'r': (window as any).simReload(); break;
    case 'h': (window as any).simDamage(); break;
    case 'e': (window as any).simPickup(); break;
    case 'b':
      state.fireMode = state.fireMode === 'AUTO' ? 'SEMI' : 'AUTO';
      updateHUD();
      break;
    case ' ':
      // Random kill on space (for testing)
      (window as any).simKill();
      break;
  }
  // Also bind to debug buttons functions globally
});

// Prevent tab navigation
document.addEventListener('keydown', (e) => {
  if (e.key === 'Tab') e.preventDefault();
});

// ============================================
// ALIVE COUNTER TICK DOWN
// ============================================
let aliveInterval = setInterval(() => {
  if (state.alive > 1) {
    state.alive -= Math.random() < 0.6 ? 1 : 0;
    if (state.alive < 1) state.alive = 1;
    updateHUD();
  } else {
    clearInterval(aliveInterval);
  }
}, 800 + Math.random() * 1500);

// ============================================
// ZONE PHASE INCREMENT
// ============================================
let zoneInterval = setInterval(() => {
  if (state.zonePhase < 8) {
    state.zonePhase++;
    updateHUD();
    showZoneWarning(state.zonePhase, `Zone ${state.zonePhase} incoming!`);
    setTimeout(() => hideZoneWarning(), 4500);
    addKillFeed('【ZONE】', `Phase ${state.zonePhase}`, 'SHRINK');
  } else {
    clearInterval(zoneInterval);
  }
}, 60000); // every 60 seconds

// ============================================
// AUTO FIRE (hold mouse)
// ============================================
let isFiring = false;
let fireInterval: number | null = null;

function startFire(): void {
  if (isFiring) return;
  isFiring = true;
  const fire = () => {
    if (state.ammo > 0 && !state.isReloading) {
      state.ammo--;
      updateHUD();
    } else {
      stopFire();
    }
  };
  fire();
  fireInterval = window.setInterval(fire, 100); // 600 RPM
}

function stopFire(): void {
  isFiring = false;
  if (fireInterval) { clearInterval(fireInterval); fireInterval = null; }
}

document.addEventListener('mousedown', (e) => {
  const target = e.target as HTMLElement;
  // Prevent firing when clicking buttons
  if (target.classList.contains('debug-btn')) return;
  if (e.button === 0) startFire();
});
document.addEventListener('mouseup', stopFire);

// ============================================
// MAIN LOOP
// ============================================
function loop(): void {
  drawRadar();
  // Random gas effect fluctuation for testing
  const gasIntensity = (Math.sin(Date.now() / 4000) + 1) / 2 * 0.3;
  updateGasEffect(gasIntensity);
  requestAnimationFrame(loop);
}

// ============================================
// START
// ============================================
function start(): void {
  // Hide loading
  const loading = document.getElementById('loading');
  if (loading) {
    loading.style.opacity = '0';
    setTimeout(() => { loading.style.display = 'none'; }, 300);
  }

  renderSquad();
  updateHUD();
  loop();

  // Auto demo events
  setTimeout(() => addKillFeed('Ghost_42', 'Loot_Goblin', 'AK-74'), 3000);
  setTimeout(() => addKillFeed('Recon_07', 'Camper_1', 'AWM'), 7000);
  setTimeout(() => showInteraction(pickMessages[0]), 5000);
  setTimeout(() => hideInteraction(), 9000);
  setTimeout(() => addKillFeed('Viper_X', 'NoobMaster', 'Groza'), 12000);

  console.log('🎮 Battle Royale HUD Prototype Started!');
  console.log('● Press R or click [Reload] — reload animation');
  console.log('● Press H or click [Damage] — lose 15 HP');
  console.log('● Press E or click [Pickup] — show loot prompt');
  console.log('● Press B — toggle AUTO/SEMI');
  console.log('● Click on screen — fire weapon (decreases ammo)');
  console.log('● Press Space — random kill feed entry');
  console.log('● Alive counter ticks down automatically');
  console.log('● Zone increments every 60 seconds');
}

start();
