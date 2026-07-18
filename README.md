# Battle Royale Web Demo

Interactive browser-based demo of the Battle Royale systems built with **TypeScript + Three.js + Vite**.

## Live Demo

Once deployed: `https://<username>.github.io/battle-royale-web/`

## Features

- **Movement System** - WASD, Sprint (Shift), Crouch (C), Prone (Z), Slide (Ctrl+Sprint), Jump (Space), Vault
- **Zone System** - 7-phase dynamic safe zone with warning, shrink animation, gas damage
- **Weapon System** - Raycast shooting, recoil patterns, spread, reload (tactical/full), fire modes
- **HUD** - Health/Armor, Ammo, Zone phase, Alive count, Kill feed, Hit markers, Gas vignette
- **Minimap** - GTA V style with zone, player arrow, compass, squad markers
- **Inventory** - 30-slot grid + 5-slot hotbar, drag-drop, rarity borders, weight system

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Shift | Sprint |
| C | Crouch |
| Z | Prone |
| Ctrl | Slide (while sprinting) |
| Space | Jump / Vault |
| Mouse Move | Look |
| Click | Lock Mouse |
| Left Click | Fire |
| Right Click | ADS |
| R | Reload |
| B | Toggle Fire Mode |
| V | Melee |
| G | Throw Grenade |
| Tab | Inventory |
| M | Minimap (toggle) |

## Local Development

```bash
# Install dependencies
npm install

# Start dev server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Project Structure

```
src/
├── main.ts              # Entry point, Three.js init, game loop
├── constants.ts         # Game constants (from Luau)
├── types.ts             # TypeScript types (from Luau)
├── systems/
│   ├── MovementSystem.ts    # WASD, stances, slide, vault
│   ├── ZoneSystem.ts        # Safe zone, gas, warnings
│   └── WeaponSystem.ts      # Shooting, recoil, reload
└── ui/
    ├── HUD.ts           # Health, ammo, zone, kill feed
    ├── Minimap.ts       # Canvas-based minimap
    └── InventoryUI.ts   # Grid + hotbar, drag-drop
```

## Deployment

1. Push to `main` branch
2. GitHub Actions builds and deploys to GitHub Pages
3. Enable Pages in repo Settings → Pages → Source: "GitHub Actions"

## Tech Stack

- **Three.js** (r165) - 3D rendering
- **TypeScript** - Type safety
- **Vite** - Fast dev server & build
- **GitHub Actions** - CI/CD

## Credits

Converted from the Roblox Luau Battle Royale codebase (Rojo + Wally architecture).