# Aurora Rush

A high-speed, open-world 3D platformer prototype built in **Godot 4.6** (GDScript), targeting Android
(phones and handhelds such as the Galaxy S25+ and Retroid Pocket 5) with desktop builds for Windows and Linux.

It is a momentum platformer in the boost-era style: running, boosting, homing attacks, spin dashes,
stomps, rail grinding, springs, loops and one hand-designed island to use them on. The hero ("Zip"),
the island, the enemies, all models, shaders and sounds are original and generated in code. The project
contains no third-party or ripped assets.

Everything lives in this `game/` folder; the rest of the repository is unrelated.

## Getting a build

- **Android APK / Windows / Linux:** every push runs `.github/workflows/build.yml`, which runs both test
  suites, exports a debug-signed APK plus desktop builds, and smoke-tests the exported Linux binary.
  Download them from the run's **Artifacts** on the repository's *Actions* tab
  (`aurora-rush-android-apk`, `aurora-rush-windows`, `aurora-rush-linux`).
- **From source:** open `game/project.godot` in Godot 4.6 and press Play. Export presets for Android,
  Windows and Linux are included (`export_presets.cfg`).

The APK is debug-signed (fine for sideloading; a release keystore is needed for store distribution).

## Controls

| Action | Gamepad | Touch | Keyboard |
|---|---|---|---|
| Move | Left stick | Floating stick (left side) | WASD |
| Camera | Right stick | Drag on the right side | Arrow keys / right-mouse drag |
| Jump, double jump | A | JUMP | Space |
| Homing attack / air dash | X | ATK | J or E |
| Boost | RT or RB | BOOST | Shift |
| Spin Dash (ground), Stomp (air) | B or LT (Y also stomps) | SPIN | K or Ctrl |
| Pause | Start | II (or Android back) | Esc / P |

No keyboard or mouse is required. Touch controls appear automatically on touchscreens and hide as soon
as a gamepad is used. Settings (title screen or pause menu) cover graphics quality, camera distance,
sensitivity and inversion, volume, and touch button size, opacity, visibility and a left-handed layout.

## What is in the game

**Movement** (`scripts/player/player.gd`)

- Custom momentum physics on a sphere collider: own ground detection, slope gravity, surface sticking
  and speed restoration, so seams and bumps do not eat speed. Loops, quarter pipes and rolling hills work.
- Snappy low-speed control, speed-dependent steering, skid on reversal, speed kept through turns and jumps.
- Boost with a draining/recharging gauge (sparks, enemies and pads refill it), one air-boost per jump.
- Variable-height jump, double jump, coyote time, jump buffering.
- Homing attack with a reticle, line-of-sight checks and fluid chaining; air dash when nothing is targeted.
- Spin Dash (charge and release into a low-friction roll that gains speed downhill and smashes cracked walls).
- Stomp with a shockwave (presses switches, stuns armoured enemies).
- Grind rails with slope momentum and boost, springs, dash pads, boost hoops, moving platforms.

**Aurora Isle** (`scripts/world/`): one island roughly 1 km across

- Landing Shore, Greenway Plains with a ring speedway and loop-the-loop, the Aurora Spire, Stormcrown Peak,
  Windcut Cliffs, the Sunken Ruins, Lantern Reach, the Sky Garden, Hollow Pass and its hidden cove,
  an offshore sea stack and the Guardian's Basin.
- 10 Aurora Cores: six traversal challenges (Rail Rush, Cliff Climb, Lantern Hop, Ruins Dash time trial,
  Sky Garden course, Hollow Pass), two puzzles (plains beacons, ruin vault) and two hidden cores
  (the Skyline grind from the summit, the sea stack).
- Three enemy types: Grunt (telegraphed charge), Turret (dodgeable shots), Bulwark (frontal shield: stomp
  to stun it or get behind it).
- Collect 6 cores to wake the Guardian: a two-phase boss with shockwaves, volleys and a charge.
  Beating it changes the island to evening light; the island stays explorable.
- Checkpoints, automatic saving (cores, puzzles, checkpoint, settings), recovery to the last solid ground
  after falling into the sea.

**Movement Lab**: a flat test arena (title menu) with lanes for every mechanic and enemy.

## Tests

Tests drive the real player controller with scripted inputs and check gameplay outcomes.

```
godot --headless --path game --import                                   # once
godot --headless --fixed-fps 60 --path game -- --test                   # 85 movement + combat checks
godot --headless --fixed-fps 60 --path game -- --test-island            # 44 island checks
```

- `--test` covers acceleration, steering, boost, jump heights, coyote/buffer, slope seams, bumps, hills,
  the loop, spin dash, homing chains and line of sight, rails, stomp, max-speed wall and floor impacts,
  breakable walls, hoops, damage and all three enemies.
- `--test-island` checks terrain collision against the heightmap, every aimed spring, hoop and rail, and
  runs bot playthroughs of each challenge, both puzzles and the Guardian fight.
- Add `--only=name,name` to run a subset and `--trace` to print the player's state every few frames.

## Project layout

```
game/
  project.godot, export_presets.cfg
  data/island_height.bin        baked heightmap (tools/bake_terrain.gd regenerates it)
  scripts/core/                 main flow, save/progress, input layer, procedural sound, particles
  scripts/player/               controller, procedural character animation, camera
  scripts/world/                terrain, island scenery, island content, test arena, build helpers
  scripts/objects/              springs, pads, hoops, rails, pickups, switches, gates, time trial...
  scripts/enemies/              grunt, turret, bulwark, projectile, guardian
  scripts/ui/                   HUD, menus, touch controls
  scripts/tests/                automated suites
```

To change the terrain, edit `design_height()` in `scripts/world/terrain.gd`, then run
`godot --headless --path game -s tools/bake_terrain.gd` (add `-- --map=out.png` for a top-down preview).
Island content is placed in `scripts/world/island_areas.gd`, one function per district.

## Known limitations and unfinished work

- **Not tested on real Android hardware.** The APK builds in CI and the game logic is tested headlessly,
  but frame rate, touch feel and gamepad mapping on the S25+ and Retroid Pocket 5 are unverified. The
  quality setting (render scale, shadows, MSAA, glow) is the lever if 60 FPS is not held.
- Rendering was only checked with the Compatibility renderer on a software rasteriser; the shipped
  Mobile renderer may need lighting and colour tuning.
- No music; all sound effects are simple synthesised tones.
- Art is placeholder primitives: no textured models, no skeletal animation.
- Wall running is not implemented.
- No control remapping, and touch buttons can be resized but not individually repositioned.
- Sparks and defeated enemies are not saved between sessions (cores, puzzles and checkpoints are).
- Loops rely on a guide that slides the player sideways with the corkscrew; there is no general
  spline-path automation.
- Only steps up to roughly 0.2 m are climbed automatically; taller ledges need a jump.
