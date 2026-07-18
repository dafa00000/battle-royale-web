// ============================================
// BATTLE ROYALE - HUD PROTOTYPE v2 (Full Simulation)
// ============================================
import * as THREE from 'three';
import { ViewModel } from './systems/ViewModel';

interface GameState {
  health: number; maxHealth: number;
  armor: number; maxArmor: number;
  ammo: number; ammoReserve: number; maxAmmo: number;
  weaponName: string; fireMode: 'AUTO' | 'SEMI';
  zonePhase: number; alive: number;
  isReloading: boolean;
  isInGas: boolean;
  player: {
    position: [number, number, number];
    velocity: [number, number, number];
    stance: 'Stand' | 'Crouch' | 'Prone';
    isMoving: boolean;
    isSprinting: boolean;
    isGrounded: boolean;
  };
  mouse: { x: number; y: number; locked: boolean };
}

const state: GameState = {
  health: 100, maxHealth: 100,
  armor: 50, maxArmor: 100,
  ammo: 30, ammoReserve: 90, maxAmmo: 30,
  weaponName: 'AK-74', fireMode: 'AUTO',
  zonePhase: 1, alive: 100,
  isReloading: false,
  isInGas: false,
  player: {
    position: [0, 1.7, 0], velocity: [0, 0, 0],
    stance: 'Stand', isMoving: false, isSprinting: false, isGrounded: true,
  },
  mouse: { x: 0, y: 0, locked: false },
};

// ============================================
// HUD UPDATE
// ============================================
function updateHUD(): void {
  const hpEl = document.getElementById('hp');
  const hpBar = document.getElementById('hp-bar-fill');
  const armorEl = document.getElementById('armor');
  const ammoCur = document.getElementById('ammo-current');
  const ammoTot = document.getElementById('ammo-total');
  const fireModeEl = document.getElementById('fire-mode');
  const weaponEl = document.getElementById('weapon-name');
  const zoneEl = document.getElementById('zone-phase');
  const aliveEl = document.getElementById('alive');
  const lowHealth = document.getElementById('low-health');
  const emptyAlert = document.getElementById('empty-alert');

  if (hpEl) hpEl.textContent = String(Math.round(state.health));
  if (armorEl) armorEl.textContent = String(Math.round(state.armor));
  const armorBar = document.getElementById('armor-bar-fill');
  if (armorBar) armorBar.style.width = `${(state.armor / state.maxArmor) * 100}%`;

  if (hpBar) {
    const pct = (state.health / state.maxHealth) * 100;
    hpBar.style.width = `${pct}%`;
    hpBar.className = 'health-bar-fill';
    if (state.isInGas) {
      hpBar.classList.add('gas-poisoned'); // desaturated red
    } else if (pct < 25) {
      hpBar.classList.add('critical');
    } else if (pct < 50) {
      hpBar.classList.add('low');
    }
  }
  if (lowHealth) lowHealth.classList.toggle('active', state.health < 25);

  if (ammoCur) ammoCur.textContent = state.ammo === 0 ? '✕' : String(state.ammo);
  if (ammoCur) ammoCur.style.color = state.ammo === 0 ? '#dc3232' : '#00b4ff';
  if (ammoTot) ammoTot.textContent = String(state.ammoReserve);
  if (fireModeEl) fireModeEl.textContent = state.fireMode;
  if (weaponEl) weaponEl.textContent = state.weaponName;
  if (zoneEl) zoneEl.textContent = String(state.zonePhase);
  if (aliveEl) aliveEl.textContent = String(state.alive);

  if (emptyAlert) emptyAlert.classList.toggle('visible', state.ammo === 0 && !state.isReloading);
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
const killers = ['Ghost_42', 'Recon_07', 'Viper', 'Sniper_K', 'Rusher66', 'Phantom_X', 'Merc99', 'Frost_Blk'];
const victims = ['Runner99', 'Camper_1', 'NoobMaster', 'Loot_Goblin', 'AFK_Andy', 'GoldWolf', 'TaskFake', 'Zero_Q'];
const weapons = ['AK-74', 'AWM', 'M416', 'Groza', 'Pan', ' Desert Eagle', 'UMP45'];

function addKillFeed(killer?: string, victim?: string, weapon?: string): void {
  const feed = document.getElementById('kill-feed');
  if (!feed) return;

  if (!killer) killer = killers[Math.floor(Math.random() * killers.length)];
  if (!victim) victim = victims[Math.floor(Math.random() * victims.length)];
  if (!weapon) weapon = weapons[Math.floor(Math.random() * weapons.length)];

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

  ctx.fillStyle = 'rgba(15,15,20,0.6)';
  ctx.fillRect(0, 0, w, h);

  ctx.strokeStyle = 'rgba(0,180,255,0.3)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(cx, cy, radius, 0, Math.PI * 2);
  ctx.stroke();

  ctx.strokeStyle = 'rgba(0,180,255,0.15)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(cx, cy - radius); ctx.lineTo(cx, cy + radius);
  ctx.moveTo(cx - radius, cy); ctx.lineTo(cx + radius, cy);
  ctx.stroke();

  const zoneR = radius * (0.6 + Math.sin(Date.now() / 3000) * 0.1);
  ctx.strokeStyle = 'rgba(0,180,255,0.8)';
  ctx.lineWidth = 2;
  ctx.setLineDash([4, 4]);
  ctx.beginPath();
  ctx.arc(cx, cy, zoneR, 0, Math.PI * 2);
  ctx.stroke();
  ctx.setLineDash([]);

  const nextR = radius * 0.4;
  ctx.strokeStyle = 'rgba(255,140,0,0.6)';
  ctx.lineWidth = 1.5;
  ctx.setLineDash([2, 4]);
  ctx.beginPath();
  ctx.arc(cx + 20, cy - 15, nextR, 0, Math.PI * 2);
  ctx.stroke();
  ctx.setLineDash([]);

  ctx.fillStyle = '#00b4ff';
  ctx.beginPath();
  ctx.arc(cx, cy, 4, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = '#00b4ff';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(cx, cy);
  ctx.lineTo(cx, cy - 12);
  ctx.stroke();

  const enemyPositions = [
    { x: 0.2, y: -0.3 }, { x: -0.4, y: 0.2 }, { x: 0.3, y: 0.4 },
  ];
  enemyPositions.forEach(p => {
    if (Math.sin(Date.now() / 2000 + p.x * 10) > 0.3) return;
    ctx.fillStyle = '#dc3232';
    ctx.beginPath();
    ctx.arc(cx + p.x * radius, cy + p.y * radius, 3, 0, Math.PI * 2);
    ctx.fill();
  });

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
// MOBILE DETECTION & CONTROLS
// ============================================

const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;

const mobileState = {
  joystick: { dx: 0, dy: 0, active: false, id: null as number | null, maxDist: 50 },
  look: { x: 0, y: 0, active: false, id: null as number | null, lastX: 0, lastY: 0 },
};

function initMobileControls(): void {
  if (!isTouchDevice) return;

  document.body.classList.add('touch');

  // === Virtual Joystick ===
  const zone = document.getElementById('leftJoystick');
  const thumb = document.getElementById('joystickThumb');

  if (!zone || !thumb) return;

  zone.addEventListener('touchstart', (e: TouchEvent) => {
    if (mobileState.joystick.id !== null) return;
    const touch = e.changedTouches[0];
    mobileState.joystick.id = touch.identifier;
    mobileState.joystick.active = true;
    thumb.classList.add('active');
    e.preventDefault();
  }, { passive: false });

  const handleJoystickMove = (e: TouchEvent) => {
    for (let i = 0; i < e.touches.length; i++) {
      const touch = e.touches[i];
      if (touch.identifier !== mobileState.joystick.id) continue;

      const rect = zone.getBoundingClientRect();
      const centerX = rect.left + rect.width / 2;
      const centerY = rect.top + rect.height / 2;
      let dx = touch.clientX - centerX;
      let dy = touch.clientY - centerY;

      const dist = Math.sqrt(dx * dx + dy * dy);
      const maxDist = rect.width / 2 - 20;
      if (dist > maxDist) {
        const ratio = maxDist / dist;
        dx *= ratio;
        dy *= ratio;
      }

      mobileState.joystick.dx = dx / maxDist;
      mobileState.joystick.dy = dy / maxDist;

      thumb.style.left = `calc(35% + ${(dx / maxDist) * 35}%)`;
      thumb.style.top = `calc(35% + ${(dy / maxDist) * 35}%)`;
    }
    e.preventDefault();
  };

  zone.addEventListener('touchmove', handleJoystickMove, { passive: false });

  const endJoystick = (e: TouchEvent) => {
    for (let i = 0; i < e.changedTouches.length; i++) {
      if (e.changedTouches[i].identifier === mobileState.joystick.id) {
        mobileState.joystick.id = null;
        mobileState.joystick.active = false;
        mobileState.joystick.dx = 0;
        mobileState.joystick.dy = 0;
        thumb.classList.remove('active');
        thumb.style.left = '35%';
        thumb.style.top = '35%';
      }
    }
  };
  zone.addEventListener('touchend', endJoystick);
  zone.addEventListener('touchcancel', endJoystick);

  // === Look zone (camera drag) ===
  const lookZone = document.getElementById('lookZone');
  if (!lookZone) return;

  lookZone.addEventListener('touchstart', (e: TouchEvent) => {
    if (mobileState.look.id !== null) return;
    const touch = e.changedTouches[0];
    mobileState.look.id = touch.identifier;
    mobileState.look.active = true;
    mobileState.look.lastX = touch.clientX;
    mobileState.look.lastY = touch.clientY;
    e.preventDefault();
  }, { passive: false });

  lookZone.addEventListener('touchmove', (e: TouchEvent) => {
    for (let i = 0; i < e.touches.length; i++) {
      const touch = e.touches[i];
      if (touch.identifier !== mobileState.look.id) continue;

      const dx = touch.clientX - mobileState.look.lastX;
      const dy = touch.clientY - mobileState.look.lastY;
      state.mouse.x -= dx * 0.004;
      state.mouse.y -= dy * 0.004;
      state.mouse.y = Math.max(-Math.PI / 2, Math.min(Math.PI / 2, state.mouse.y));
      mobileState.look.lastX = touch.clientX;
      mobileState.look.lastY = touch.clientY;
    }
    e.preventDefault();
  }, { passive: false });

  const endLook = (e: TouchEvent) => {
    for (let i = 0; i < e.changedTouches.length; i++) {
      if (e.changedTouches[i].identifier === mobileState.look.id) {
        mobileState.look.id = null;
        mobileState.look.active = false;
      }
    }
  };
  lookZone.addEventListener('touchend', endLook);
  lookZone.addEventListener('touchcancel', endLook);

  // === Action buttons ===
  const fireBtn = document.getElementById('fireBtn');
  const reloadBtn = document.getElementById('reloadBtn');
  const crouchBtn = document.getElementById('crouchBtn');
  const jumpBtn = document.getElementById('jumpBtn');

  if (fireBtn) {
    const startFire = (e: Event) => {
      e.preventDefault();
      fireBtn.classList.add('held');
      fireInterval = window.setInterval(() => {
        (window as any).simFire();
      }, 100);
    };
    const stopFire = (e: Event) => {
      e.preventDefault();
      fireBtn.classList.remove('held');
      if (fireInterval) { clearInterval(fireInterval); fireInterval = null; }
    };
    fireBtn.addEventListener('touchstart', startFire, { passive: false });
    fireBtn.addEventListener('touchend', stopFire, { passive: false });
    fireBtn.addEventListener('touchcancel', stopFire, { passive: false });
    fireBtn.addEventListener('mousedown', startFire);
    fireBtn.addEventListener('mouseup', stopFire);
    fireBtn.addEventListener('mouseleave', stopFire);
  }

  if (reloadBtn) {
    reloadBtn.addEventListener('touchstart', (e) => {
      e.preventDefault();
      (window as any).simReload();
    }, { passive: false });
    reloadBtn.addEventListener('click', () => (window as any).simReload());
  }

  if (crouchBtn) {
    crouchBtn.addEventListener('touchstart', (e) => {
      e.preventDefault();
      state.player.stance = state.player.stance === 'Stand' ? 'Crouch' : 'Stand';
      screenShake(2, 80);
    }, { passive: false });
  }

  if (jumpBtn) {
    jumpBtn.addEventListener('touchstart', (e) => {
      e.preventDefault();
      if (state.player.isGrounded) {
        state.player.velocity[1] = 6;
        state.player.isGrounded = false;
        screenShake(1.5, 100);
      }
    }, { passive: false });
  }

  console.log('📱 Mobile touch controls initialized');
}

let fireInterval: number | null = null;

function updateMobileMovement(delta: number): void {
  if (!mobileState.joystick.active) {
    state.player.isMoving = false;
    state.player.isSprinting = false;
    return;
  }

  const dx = mobileState.joystick.dx;
  const dy = mobileState.joystick.dy;
  const mag = Math.sqrt(dx * dx + dy * dy);
  if (mag < 0.1) {
    state.player.isMoving = false;
    state.player.isSprinting = false;
    return;
  }

  // Movement: up = forward (-dy), strafe = dx
  state.player.isMoving = true;
  state.player.isSprinting = mag > 0.9;

  const yaw = state.mouse.x;
  const speed = state.player.isSprinting ? 8 : 4;
  const sin = Math.sin(yaw);
  const cos = Math.cos(yaw);

  // forward vector (-sin, 0, -cos), right vector (cos, 0, -sin)
  const moveForward = -dy;
  const moveRight = dx;

  state.player.velocity[0] = (-sin * moveForward + cos * moveRight) * speed;
  state.player.velocity[2] = (-cos * moveForward - sin * moveRight) * speed;

  // Apply to position
  state.player.position[0] += state.player.velocity[0] * delta;
  state.player.position[2] += state.player.velocity[2] * delta;

  // Gravity + ground
  if (!state.player.isGrounded) {
    state.player.velocity[1] -= 20 * delta;
  }
  state.player.position[1] += state.player.velocity[1] * delta;
  if (state.player.position[1] <= 1.7) {
    state.player.position[1] = 1.7;
    state.player.velocity[1] = 0;
    state.player.isGrounded = true;
  }
}

// ============================================
// SCREEN SHAKE (weapons / damage)
// ============================================
function screenShake(intensity: number, duration: number): void {
  const app = document.getElementById('app');
  if (!app) return;
  const start = Date.now();
  const interval = setInterval(() => {
    if (Date.now() - start > duration) {
      app.style.transform = '';
      clearInterval(interval);
      return;
    }
    const dx = (Math.random() - 0.5) * intensity;
    const dy = (Math.random() - 0.5) * intensity;
    app.style.transform = `translate(${dx}px, ${dy}px)`;
  }, 16);
}

// ============================================
// SIMULATION CONTROLS
// ============================================
(window as any).simReload = function (): void {
  if (state.isReloading) return;
  if (state.ammo === state.maxAmmo) return;
  if (state.ammoReserve <= 0) return;

  state.isReloading = true;
  document.getElementById('reload-text')?.classList.add('visible');
  // Trigger tactical reload animation on viewmodel
  viewModel?.triggerReload();

  setTimeout(() => {
    const needed = state.maxAmmo - state.ammo;
    const taken = Math.min(needed, state.ammoReserve);
    state.ammo += taken;
    state.ammoReserve -= taken;
    state.isReloading = false;
    document.getElementById('reload-text')?.classList.remove('visible');
    updateHUD();
  }, 2000); // 2 seconds as requested
};

(window as any).simFire = function (): void {
  if (state.isReloading) return;
  if (state.ammo <= 0) {
    // EMPTY alert + small shake
    const emptyAlert = document.getElementById('empty-alert');
    emptyAlert?.classList.add('visible');
    setTimeout(() => emptyAlert?.classList.remove('visible'), 800);
    return;
  }
  state.ammo--;
  // AK-74 heavy screen shake (Resident Evil style)
  screenShake(3, 120);
  // FPS viewmodel recoil + muzzle flash
  if (viewModel) {
    viewModel.triggerRecoil();
    viewModel.showMuzzleFlash();
  }
  updateHUD();
};

(window as any).simDamage = function (): void {
  state.armor = Math.max(0, state.armor - 20);
  state.health = Math.max(0, state.health - 15);
  screenShake(8, 300); // heavy shake on damage
  updateHUD();
};

(window as any).simGasDamage = function (delta: number): void {
  state.health = Math.max(0, state.health - 1.5 * delta);
  state.isInGas = true;
  updateHUD();
};

(window as any).simMedkit = function (): void {
  // Smoothly restore to 100
  const hpBar = document.getElementById('hp-bar-fill');
  if (hpBar) hpBar.style.transition = 'width 1.5s ease-out, background 1.5s';
  state.health = 100;
  state.armor = Math.min(state.maxArmor, state.armor + 20);
  updateHUD();
  setTimeout(() => {
    if (hpBar) hpBar.style.transition = '';
  }, 1600);
};

(window as any).simPickup = function (): void {
  const msg = pickMessages[Math.floor(Math.random() * pickMessages.length)];
  showInteraction(msg);
  setTimeout(() => hideInteraction(), 2500);
};

(window as any).simKill = function (): void {
  addKillFeed();
};

(window as any).simToggleFireMode = function (): void {
  state.fireMode = state.fireMode === 'AUTO' ? 'SEMI' : 'AUTO';
  updateHUD();
};

// Toggle gas state (manual testing)
let gasToggle = false;
(window as any).simToggleGas = function (): void {
  gasToggle = !gasToggle;
  state.isInGas = gasToggle;
  updateHUD();
};

// ============================================
// KEYBOARD INPUT
// ============================================
document.addEventListener('keydown', (e: KeyboardEvent) => {
  const key = e.key.toLowerCase();
  switch (key) {
    case 'r': (window as any).simReload(); break;
    case 'g': (window as any).simDamage(); break;
    case 'h': (window as any).simMedkit(); break;
    case 'e': (window as any).simPickup(); break;
    case 'k': (window as any).simKill(); break;
    case 'b': (window as any).simToggleFireMode(); break;
    case ' ': e.preventDefault(); (window as any).simFire(); break;
  }
  if (e.key === 'Tab') e.preventDefault();
});

document.addEventListener('mousedown', (e) => {
  const target = e.target as HTMLElement;
  if (target.classList.contains('debug-btn')) return;
  if (e.button === 0) (window as any).simFire();
});

// ============================================
// ALIVE COUNTER TICK DOWN (15-30s random + kill feed)
// ============================================
function scheduleNextDeath(): void {
  const interval = 15000 + Math.random() * 15000;
  setTimeout(() => {
    if (state.alive > 1) {
      state.alive--;
      updateHUD();
      // Trigger kill feed notification
      addKillFeed();
    }
    scheduleNextDeath();
  }, interval);
}

// ============================================
// ZONE PHASE INCREMENT (every 60s)
// ============================================
setInterval(() => {
  if (state.zonePhase < 8) {
    state.zonePhase++;
    updateHUD();
    showZoneWarning(state.zonePhase, `Zone ${state.zonePhase} incoming!`);
    setTimeout(() => hideZoneWarning(), 4500);
    addKillFeed('【ZONE】', `Phase ${state.zonePhase}`, 'SHRINK');
  }
}, 60000);

// ============================================
// GAS DAMAGING (if in gas, damage over time)
// ============================================
let gasDamageInterval = setInterval(() => {
  if (state.isInGas && state.health > 0) {
    state.health = Math.max(0, state.health - 1);
    updateHUD();
  }
}, 1000);

// ============================================
// 3D SCENE (background + FPS viewmodel)
// ============================================

let scene3D: THREE.Scene;
let camera3D: THREE.PerspectiveCamera;
let renderer3D: THREE.WebGLRenderer;
let viewModel: ViewModel;
let lastLookDx = 0, lastLookDy = 0;

function init3DScene(): void {
  const canvas = document.getElementById('bg3d') as HTMLCanvasElement;
  if (!canvas) return;

  scene3D = new THREE.Scene();
  scene3D.background = new THREE.Color(0x0a0a0f);
  scene3D.fog = new THREE.Fog(0x0a0a0f, 30, 200);

  camera3D = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.01, 1000);
  camera3D.rotation.order = 'YXZ';

  renderer3D = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false });
  renderer3D.setSize(window.innerWidth, window.innerHeight);
  renderer3D.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer3D.shadowMap.enabled = true;
  renderer3D.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer3D.toneMapping = THREE.ACESFilmicToneMapping;
  renderer3D.toneMappingExposure = 1.1;

  // === Lighting ===
  const ambient = new THREE.AmbientLight(0x40404a, 0.6);
  scene3D.add(ambient);

  const sun = new THREE.DirectionalLight(0xffd5a0, 1.0);
  sun.position.set(50, 80, 30);
  sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024);
  sun.shadow.camera.near = 1;
  sun.shadow.camera.far = 300;
  sun.shadow.camera.left = -80;
  sun.shadow.camera.right = 80;
  sun.shadow.camera.top = 80;
  sun.shadow.camera.bottom = -80;
  scene3D.add(sun);

  const fill = new THREE.HemisphereLight(0x88aaff, 0x221100, 0.25);
  scene3D.add(fill);

  // === Ground ===
  const groundGeo = new THREE.PlaneGeometry(400, 400, 32, 32);
  const groundMat = new THREE.MeshStandardMaterial({
    color: 0x1a1a24, roughness: 0.85, metalness: 0.1,
  });
  const ground = new THREE.Mesh(groundGeo, groundMat);
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  scene3D.add(ground);

  // Grid overlay for tactical feel
  const grid = new THREE.GridHelper(400, 80, 0x2a3a4a, 0x1a2030);
  (grid.material as THREE.Material).opacity = 0.35;
  (grid.material as THREE.Material).transparent = true;
  grid.position.y = 0.01;
  scene3D.add(grid);

  // === Buildings (placeholder cover) ===
  const buildingMat = new THREE.MeshStandardMaterial({
    color: 0x252530, roughness: 0.8, metalness: 0.15,
  });
  for (let i = 0; i < 15; i++) {
    const w = 3 + Math.random() * 5;
    const h = 5 + Math.random() * 15;
    const d = 3 + Math.random() * 5;
    const building = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), buildingMat);
    building.position.set(
      (Math.random() - 0.5) * 150,
      h / 2,
      (Math.random() - 0.5) * 150
    );
    building.castShadow = true;
    building.receiveShadow = true;
    scene3D.add(building);
  }

  // === Zone ring (visual) ===
  const zoneGeo = new THREE.RingGeometry(198, 200, 64);
  const zoneMat = new THREE.MeshBasicMaterial({
    color: 0x00b4ff, side: THREE.DoubleSide, transparent: true, opacity: 0.6,
  });
  const zoneRing = new THREE.Mesh(zoneGeo, zoneMat);
  zoneRing.rotation.x = -Math.PI / 2;
  zoneRing.position.y = 0.1;
  zoneRing.name = 'zoneRing3D';
  scene3D.add(zoneRing);

  // === FPS Viewmodel ===
  viewModel = new ViewModel(scene3D, camera3D);

  // Resize handler
  window.addEventListener('resize', () => {
    camera3D.aspect = window.innerWidth / window.innerHeight;
    camera3D.updateProjectionMatrix();
    renderer3D.setSize(window.innerWidth, window.innerHeight);
  });

  console.log('3D scene initialized ✓');
}

function update3DScene(delta: number): void {
  if (!camera3D || !renderer3D) return;

  // Camera from player yaw/pitch
  camera3D.rotation.y = state.mouse.x;
  camera3D.rotation.x = state.mouse.y;

  // Compute look delta for viewmodel sway
  const lookDx = state.mouse.x - lastLookDx;
  const lookDy = state.mouse.y - lastLookDy;
  lastLookDx = state.mouse.x;
  lastLookDy = state.mouse.y;

  viewModel.updateSway(lookDx, lookDy, delta);
  viewModel.update(delta, state.player.isMoving, state.player.isSprinting);

  // Update zone ring scale (shrink simulation)
  const zoneRing = scene3D.getObjectByName('zoneRing3D') as THREE.Mesh;
  if (zoneRing) {
    const scale = 0.5 + (8 - state.zonePhase) * 0.07;
    zoneRing.scale.setScalar(Math.max(0.1, scale));
  }

  renderer3D.render(scene3D, camera3D);
}
function loop(): void {
  drawRadar();
  updateMobileMovement(0.016);
  update3DScene(0.016);
  // Random gas effect fluctuation
  const gasIntensity = state.isInGas ? 0.7 + Math.sin(Date.now() / 4000) * 0.2 : (Math.sin(Date.now() / 4000) + 1) / 2 * 0.3;
  updateGasEffect(gasIntensity);
  requestAnimationFrame(loop);
}

// ============================================
// START
// ============================================
function start(): void {
  const loading = document.getElementById('loading');
  if (loading) {
    loading.style.opacity = '0';
    setTimeout(() => { loading.style.display = 'none'; }, 300);
  }

  renderSquad();
  updateHUD();
  loop();
  scheduleNextDeath(); // start alive countdown
  initMobileControls();
  init3DScene();

  // Auto demo events
  setTimeout(() => addKillFeed('Ghost_42', 'Loot_Goblin', 'AK-74'), 3000);
  setTimeout(() => addKillFeed('Recon_07', 'Camper_1', 'AWM'), 7000);
  setTimeout(() => showInteraction(pickMessages[0]), 5000);
  setTimeout(() => hideInteraction(), 9000);
  setTimeout(() => addKillFeed('Viper_X', 'NoobMaster', 'Groza'), 12000);

  console.log('🎮 Battle Royale HUD Prototype v2 Started!');
  console.log('● [R] Reload         | [Click]/[Space] Fire');
  console.log('● [G] Damage -15HP/-20 Armor | [H] Medkit heal to 100');
  console.log('● [E] Pickup prompt  | [K] Kill feed   | [B] Toggle fire mode');
  console.log('● Alive ticks down every 15-30s');
  console.log('● Zone increments every 60s (1→8)');
  console.log('● Damage when ammo=0 triggers EMPTY alert');
  console.log('● Low HP (<25) triggers red overlay flash');
}

start();
