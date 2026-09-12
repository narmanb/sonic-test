# Sonic Cobalt Coast — update checkpoint

The original release is privately hosted at https://sonic-cobalt-coast.kevvideos.chatgpt.site . This source checkpoint is an update in progress and is not yet deployed or fully validated.

Implemented in this checkpoint:
- Two spatially separated helical loops with parallel entrances/exits.
- Camera follows the road arc, with a loop obstruction raycast guard.
- Corrected the spin model pivot (the cause of the visible jump wobble).
- Normal jump: 18 m/s takeoff, 45 m/s² gravity, 85 ms apex hold (about 0.89 s total).
- Homing works at any airborne height and can target robots or springs, including a spring just passed.
- A bold screen-space target indicator distinguishes robot and spring locks.
- Boost speed 62 m/s, drain 40 units/s; release after exhaustion to re-arm.
- Course extended to 2.8 km, three manual jump gaps, a narrower final section, a fourth checkpoint.

Remaining before deployment:
1. Update and run gameplay regressions for the two loops, new gaps, homing edge cases, jump profile and boost exhaustion.
2. Check real Three.js geometry for loop intersections and camera-to-player visibility.
3. Recheck event wiring and source syntax.
4. Save the final source to this repository and publish an updated private Sites version.

Project source is under dist/ and requires no build. Serve dist/ with a local HTTP server to play. Three.js and its MIT license are bundled. No video upload or credentials are part of this repository.
