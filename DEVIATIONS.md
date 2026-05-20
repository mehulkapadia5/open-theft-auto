# Deviations from the Three.js prototype (`game.js`)

This Godot port reproduces the prototype's mechanics and numeric tuning. The
following intentional differences exist.

## Bug fixes (the spec demands it "feel better than the browser version")

- **Cop bullets now actually hit the player.** In `game.js`, cops fire
  `WEAPONS[1]` (KNIFE) — a melee entry with range 2.8, so cop "bullets" die in
  ~0.02 s and travel under 3 m. They also spawn at chest height with a purely
  horizontal direction, while the player's collision point is at `y = 0`, so the
  distance check `< 1` could never pass. Both issues made cops unable to deal
  ranged damage at all. This port fires the **PISTOL** (`WeaponDB.LIST[2]`, as
  spec §11 states), aims at the player's torso, and tests hits against a torso
  point (`y = 1.2`). Cops are now a real threat.
- **The plane can actually take off.** In `game.js` the on-ground branch pins
  `pos.y = 0` every frame, while the airborne branch only runs once `pos.y`
  exceeds `0.12` — so the plane could never leave the runway. This port lets
  the plane rotate and lift off once it reaches takeoff speed with the nose
  pitched up.
- **Plane pitch is on the arrow keys.** In `game.js` the camera block also
  zeroes `mouse.dy` before the plane branch reads it, so mouse pitch was always
  0. This port pitches the nose with the `↑` / `↓` arrow keys (`W`/`S`
  throttle, `A`/`D` turn), which is reliable and frees the mouse in flight.
- Entity hit detection (player bullets vs. NPCs/cops, and cop bullets vs.
  player) uses a torso reference point rather than the ground-level `pos`, so
  combat is reliable regardless of bullet height.

## Gameplay additions

- **Automatic chase camera while driving.** In a car the camera smoothly swings
  to sit behind the car's heading, giving a third-person driver's view with no
  mouse input. The prototype required constant mouse steering of the camera.
  On foot and in the plane the mouse still controls the camera freely.
- **The airport was rebuilt as a south-east grass airfield.** The prototype's
  airport was a flat zone west of downtown. It is now an off-grid airfield in
  the south-east — a long flat grass field reached by a causeway from the city
  road grid. It has two long runways (the main runway is ~690 m) with
  centreline dashes and edge lights, plus generous grass overrun ahead of each
  one so a slow plane rolls onto grass instead of crashing. It keeps a walkable
  terminal (solid walls, a 10 m entrance, glass front, interior floor, pillars,
  ceiling lights, gold roof sign), a control tower, a hangar and an apron. Each
  runway has a parked plane at its near end facing down the runway, and a
  helipad with a parked **helicopter** (vertical takeoff, hover, no runway
  needed) sits east of the runways. The helicopter is a gameplay addition not
  present in the prototype.
- **Iron Man suit.** An armoured suit spawns on open ground near the player.
  Stepping onto it assembles it plate by plate; while worn the player is
  bulletproof, can fly (hold `Space` to thrust, `WASD` to move), fire rapid
  repulsor blasts (left mouse) and explosive missiles (right mouse), and powers
  the suit back down with `F`. Not present in the prototype.
- **Exclusive fullscreen.** The game launches in exclusive fullscreen at the
  monitor's resolution; the prototype ran in a browser canvas.

## Visual / technical simplifications

- **Roads/sidewalks** use flat-tinted materials instead of the prototype's
  procedurally-painted canvas textures (asphalt grain, concrete). Stripes,
  layout, and dimensions are unchanged.
- **Crosswalk** decals are omitted (cosmetic only); road stripes are kept.
- **Sky** uses Godot's `ProceduralSkyMaterial` with day/night colour + sun
  animation instead of the Three.js Preetham `Sky` shader. Fog, lamp/window
  emissive, headlights, and the pulsing airport beacon are all driven by the
  same time-of-day curve as the original.
- Building **windows** are drawn with a single `MultiMesh` (one draw call) whose
  emissive energy animates at night — same look, far cheaper than thousands of
  individual quads.

## Structure

- Input is read directly via physical key codes (`Input.is_physical_key_pressed`)
  rather than a Godot Input Map. This matches the prototype's raw key handling
  and avoids layout-dependent bindings; behaviour is identical to spec §15.
- Script files are consolidated slightly versus the spec's suggested tree
  (e.g. world generation + collision live together in `world.gd`). All
  systems from the spec are present.
