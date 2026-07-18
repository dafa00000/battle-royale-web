// ============================================
// BATTLE ROYALE WEB - MAIN ENTRY POINT
// ============================================

import * as THREE from 'three';
import { CONSTANTS } from './constants';
import type { Vector3, WeaponTemplate, GameState, Stance, SquadData } from './types';
import { MovementSystem } from './systems/MovementSystem';
import { ZoneSystem } from './systems/ZoneSystem';
import { WeaponSystem } from './systems/WeaponSystem';
import { HUD } from './ui/HUD';
import { Minimap } from './ui/Minimap';
import { InventoryUI } from './ui/InventoryUI';

// ============================================
// GAME STATE - Using imported types
// ============================================

const state: GameState = {
  player: {
    position: [0, 1.7, 0],
    velocity: [0, 0, 0],
    rotation: [0, 0, 0],
    stance: 'Stand',
    isMoving: false,
    isSprinting: false,
    isSliding: false,
    isADS: false,
    lean: 0,
    health: 100,
    armor: 0,
    maxHealth: 100,
    maxArmor: 100,
    currentWeapon: null,
    ammo: 30,
    maxAmmo: 30,
    fireMode: 'auto',
    stanceTransitionTime: 0,
    slideEndTime: 0,
    leanTarget: 0,
    inventoryWeight: 0,
    maxWeight: 100,
    isGrounded: true,
    isInGasDamageCooldown: false,
    id: 0,
  },
  zone: { center: [0, 0, 0], radius: 2000, phase: 0, phaseEndTime: 0, isShrinking: false, damagePerTick: 2, tickInterval: 2 },
  alivePlayers: 100,
  currentPhase: 0,
  matchTime: 0,
  isInGas: false,
  gasIntensity: 0,
  squad: null,
  keys: {} as Record<string, boolean>,
  mouse: { x: 0, y: 0, locked: false },
  isADS: false,
};

// Local extended state
const localState = {
  ...state,
  keys: {} as Record<string, boolean>,
  mouse: { x: 0, y: 0, locked: false },
  isADS: false,
};

// ============================================
// THREE.JS SETUP
// ============================================

let scene: THREE.Scene;
let camera: THREE.PerspectiveCamera;
let renderer: THREE.WebGLRenderer;
let clock = new THREE.Clock();

function initThree() {
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x0a0a0f);
  scene.fog = new THREE.Fog(0x0a0a0f, 100, 2000);

  camera = new THREE.PerspectiveCamera(70, window.innerWidth / window.innerHeight, 0.1, 5000);
  camera.position.set(0, 1.7, 0);

  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.2;
  document.getElementById('app')!.appendChild(renderer.domElement);

  // Lighting (Resident Evil / GTA V style)
  const ambient = new THREE.AmbientLight(0x14141e, 0.8);
  scene.add(ambient);

  const sun = new THREE.DirectionalLight(0xffeedd, 1.5);
  sun.position.set(1000, 800, 500);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  sun.shadow.camera.near = 10;
  sun.shadow.camera.far = 3000;
  sun.shadow.camera.left = -1000;
  sun.shadow.camera.right = 1000;
  sun.shadow.camera.top = 1000;
  sun.shadow.camera.bottom = -1000;
  sun.shadow.bias = -0.001;
  scene.add(sun);

  const fill = new THREE.DirectionalLight(0x88aacc, 0.3);
  fill.position.set(-500, 300, -500);
  scene.add(fill);

  // Ground
  const groundGeo = new THREE.PlaneGeometry(10000, 10000, 100, 100);
  const groundMat = new THREE.MeshStandardMaterial({ color: 0x1a1a2e, roughness: 0.9, metalness: 0.1 });
  const ground = new THREE.Mesh(groundGeo, groundMat);
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  scene.add(ground);

  // Grid helper for reference
  const grid = new THREE.GridHelper(10000, 200, 0x3c3c3c, 0x2a2a3a);
  grid.position.y = 0.01;
  scene.add(grid);

  // Simple buildings for reference
  for (let i = 0; i < 20; i++) {
    const x = (Math.random() - 0.5) * 4000;
    const z = (Math.random() - 0.5) * 4000;
    const h = 5 + Math.random() * 30;
    const w = 8 + Math.random() * 15;
    const d = 8 + Math.random() * 15;

    const geo = new THREE.BoxGeometry(w, h, d);
    const mat = new THREE.MeshStandardMaterial({
      color: new THREE.Color().setHSL(0.08, 0.1, 0.15 + Math.random() * 0.1),
      roughness: 0.8, metalness: 0.1,
    });
    const building = new THREE.Mesh(geo, mat);
    building.position.set(x, h / 2, z);
    building.castShadow = true;
    building.receiveShadow = true;
    scene.add(building);
  }

  // Zone visualization
  const zoneGeo = new THREE.RingGeometry(1990, 2010, 64);
  const zoneMat = new THREE.MeshBasicMaterial({ color: 0x00b4ff, side: THREE.DoubleSide, transparent: true, opacity: 0.15 });
  const zoneRing = new THREE.Mesh(zoneGeo, zoneMat);
  zoneRing.rotation.x = -Math.PI / 2;
  zoneRing.position.y = 0.1;
  zoneRing.name = 'zoneRing';
  scene.add(zoneRing);

  // Weapon placeholder (raycast visualization)
  const weaponGeo = new THREE.BoxGeometry(0.1, 0.1, 0.5);
  const weaponMat = new THREE.MeshBasicMaterial({ color: 0x00b4ff, wireframe: true });
  const weaponMesh = new THREE.Mesh(weaponGeo, weaponMat);
  weaponMesh.name = 'weaponMesh';
  weaponMesh.visible = false;
  camera.add(weaponMesh);
}

// ============================================
// INPUT HANDLING
// ============================================

function initInput() {
  document.addEventListener('keydown', (e) => {
    state.keys[e.code] = true;
    handleKeyPress(e.code);
  });
  document.addEventListener('keyup', (e) => { state.keys[e.code] = false; });

  document.addEventListener('mousemove', (e) => {
    if (state.mouse.locked) {
      state.mouse.x -= e.movementX * 0.002;
      state.mouse.y -= e.movementY * 0.002;
      state.mouse.y = Math.max(-Math.PI / 2, Math.min(Math.PI / 2, state.mouse.y));
    }
  });

  document.addEventListener('mousedown', (e) => {
    if (e.button === 0 && state.mouse.locked) { // Left click - fire
      weaponSystem.fire();
    }
    if (e.button === 1) { // Middle click - lock mouse
      lockMouse();
    }
  });

  document.addEventListener('mouseup', (e) => {
    if (e.button === 0) { weaponSystem.stopFire(); }
  });

  document.addEventListener('contextmenu', (e) => e.preventDefault());

  document.addEventListener('wheel', (e) => {
    if (state.isADS) {
      camera.fov = Math.max(30, Math.min(70, camera.fov - e.deltaY * 0.05));
      camera.updateProjectionMatrix();
    }
  });

  // Pointer lock
  function lockMouse() {
    renderer.domElement.requestPointerLock();
  }
  renderer.domElement.addEventListener('click', lockMouse);
  document.addEventListener('pointerlockchange', () => {
    state.mouse.locked = document.pointerLockElement === renderer.domElement;
  });

  window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
    minimap.resize();
  });
}

function handleKeyPress(code: string) {
  switch (code) {
    case 'Tab':
      inventoryUI.toggle();
      break;
    case 'KeyM':
      minimap.toggle();
      break;
    case 'KeyV':
      weaponSystem.melee();
      break;
    case 'KeyG':
      weaponSystem.throwGrenade();
      break;
    case 'KeyR':
      weaponSystem.reload();
      break;
    case 'KeyB':
      weaponSystem.toggleFireMode();
      break;
    case 'ShiftLeft':
      break;
    case 'ControlLeft':
      if (state.player.isSprinting) {
        movementSystem.startSlide();
      }
      break;
    case 'KeyC':
      movementSystem.toggleCrouch();
      break;
    case 'KeyZ':
      movementSystem.toggleProne();
      break;
    case 'Space':
      if (state.player.stance === 'Prone') movementSystem.toggleProne();
      else movementSystem.jump();
      break;
    case 'KeyE':
      break;
  }
}

function lockMouse() {
  renderer.domElement.requestPointerLock();
}

// ============================================
// SYSTEMS
// ============================================

let movementSystem: MovementSystem;
let zoneSystem: ZoneSystem;
let weaponSystem: WeaponSystem;
let hud: HUD;
let minimap: Minimap;
let inventoryUI: InventoryUI;

function initSystems() {
  movementSystem = new MovementSystem(state, camera, scene);
  zoneSystem = new ZoneSystem(state, scene);
  weaponSystem = new WeaponSystem(state, camera, scene);
  hud = new HUD(state);
  minimap = new Minimap(state);
  inventoryUI = new InventoryUI(state);

  // Initialize demo weapon
  state.player.currentWeapon = {
    Id: 'AK74', Name: 'AK-74', Class: 'AR', Model: '', ViewModel: '', Icon: '',
    Stats: {
      Damage: 36, FireRate: 600, MuzzleVelocity: 800, Range: 600,
      RecoilPattern: {}, RecoilRecovery: 8, Spread: 0.04, SpreadADS: 0.01,
      SpreadMove: 0.08, SpreadJump: 0.15, ReloadTime: 2.8, TacticalReloadTime: 2.2,
      MagSize: 30, AmmoType: '7.62x39', Weight: 3.5, AdsTime: 0.25, Sway: 1.2,
      Penetration: 1.5, BulletDrop: 0.05,
    },
    Attachments: {}, Animations: {}, Sounds: {}, Rarity: 'Common', Price: { Cash: 0, Credits: 0 },
  };
  state.player.maxAmmo = state.player.currentWeapon.Stats.MagSize;
  state.player.ammo = state.player.maxAmmo;

  // Start zone
  zoneSystem.startMatch();
}

// ============================================
// MAIN LOOP
// ============================================

function animate() {
  requestAnimationFrame(animate);
  const delta = clock.getDelta();

  // Update systems
  movementSystem.update(delta);
  zoneSystem.update(delta);
  weaponSystem.update(delta);
  hud.update();
  minimap.update();

  // Camera follow
  const targetPos = new THREE.Vector3(...state.player.position);
  camera.position.lerp(targetPos, 0.15);
  camera.rotation.order = 'YXZ';
  camera.rotation.y = state.mouse.x;
  camera.rotation.x = state.mouse.y;

  // Apply lean
  camera.rotation.z = state.player.lean * 0.15;

  // Apply ADS FOV
  if (state.isADS) {
    camera.fov = THREE.MathUtils.lerp(camera.fov, 45, delta * 10);
  } else {
    camera.fov = THREE.MathUtils.lerp(camera.fov, 70, delta * 10);
  }
  camera.updateProjectionMatrix();

  // Render
  renderer.render(scene, camera);
}

// ============================================
// START
// ============================================

async function start() {
  // Hide loading
  document.getElementById('loading')!.style.display = 'none';

  initThree();
  initInput();
  initSystems();
  animate();

  // Add demo kill feed entries
  setTimeout(() => hud.addKillFeed('Player1', 'Player2', 'AK-74'), 3000);
  setTimeout(() => hud.addKillFeed('Player3', 'Player4', 'AWM'), 6000);
  setTimeout(() => hud.showZoneWarning(2, 'Next zone in 30s'), 8000);
  setTimeout(() => hud.hideZoneWarning(), 12000);

  console.log('🎮 Battle Royale Web Demo Started!');
  console.log('Controls: WASD Move | Shift Sprint | C Crouch | Z Prone | Ctrl Slide | Space Jump');
  console.log('Mouse: Click to lock | Left Click Fire | Right Click ADS | Scroll Zoom');
  console.log('Keys: R Reload | B Fire Mode | V Melee | G Grenade | Tab Inventory | M Map');
}

start().catch(console.error);