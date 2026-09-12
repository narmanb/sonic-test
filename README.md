# Sonic · Cobalt Coast

A single playable HTML5 / WebGL 3D fan level, built for touchscreens. The approximately 2.8 km course includes free lateral steering, auto-running, two vertical loops, spring gaps, manual jump gaps, rings, robots, crates, spike traps, four checkpoints, and a stage-clear rank.

## Play

Open the deployed site in a modern WebGL 2 browser. Landscape gives the widest view; portrait is supported. The fullscreen control requests landscape where the browser permits it.

- Touch: drag the left steering control; tap JUMP; hold BOOST. Release it after the meter is exhausted to re-arm.
- In the air: tap JUMP again when a robot or spring is locked to home in on it, at any point in the jump. A nontargeted air dash adds horizontal speed without restarting vertical motion.
- Keyboard: A/D or Left/Right to steer, Space to jump, Shift to boost, Down/S to brake, P/Escape to pause.
- Standard gamepad: left stick/D-pad, A to jump, X/right trigger to boost, Start to pause.
- Pause menu: resume, restart checkpoint, restart course, and cycle Balanced/High/Low graphics.

## Implementation

The game ships with its renderer and has no external runtime assets or CDN requests. All character, scenery, obstacle, and particle graphics are modelled procedurally in `world.mjs`; audio and music are synthesized in `audio.mjs`. Three.js r170 is the rendering library, with its MIT license included in `dist/THREE-LICENSE.txt`. Sonic is a Sega character. This is an unofficial fan demo; no Sega assets or recordings are bundled.

`core.mjs` owns deterministic game simulation; `main.mjs` connects the UI, pointer/keyboard/gamepad events and fixed-step simulation. `index.html` and `style.css` implement the responsive game screens. Author the static files directly; no package installation or build is required.

## Validation

Run `node tests/game-tests.mjs` for 13 gameplay checks, including course geometry, jumping, damage, homing, spring gaps, checkpoint recovery and complete runs at 30/60/120 simulation updates per second.

Additional local checks exercised real Three.js scene geometry and camera projection with a stub renderer, and UI events with a mock DOM. They covered mobile portrait/landscape framing, simultaneous touch controls, pointer cancellation, pause/resume, retry/restart, keyboard/gamepad routing, and optional page-tool validation. Those checks do not validate GPU output, actual touch hardware, browser WebMCP support or device frame rate. No browser visual QA or physical-device performance measurement has been performed.

The current hosted release is private. Its identity is maintained in `.openai/hosting.json`.
