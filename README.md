# Open Theft Auto

A **Godot 4.6** open-world sandbox — a GTA-style "Vice Beach" homage built in
pure GDScript. Third-person: walk, drive, fly, shoot in a procedural,
Los-Angeles-style city with a wanted/police system, day/night cycle, flyable
planes and a helicopter at the airport, and a wearable Iron-Man-style flight
suit.

> Open Theft Auto is an unofficial, fan-made homage. It is not affiliated with,
> endorsed by, or connected to Rockstar Games or Take-Two Interactive, and uses
> none of their assets.

The city is split into districts: a **downtown** core of glassy skyscrapers, a
mid-rise **commercial** ring, sprawling **residential villas** (each with a
lawn, pool, garage and pitched roof), a leafy **hills** neighbourhood, green
**parks** with ponds, and a north-south **river** crossed by bridges. Snow-capped
mountains ring the horizon.

## Run it

1. Install **Godot 4.6+** (standard, not .NET — the project is pure GDScript).
2. Open Godot, **Import** this folder (`gta-my-city/`), or open `project.godot`.
3. Press **F5** (Run Project). The game launches in exclusive fullscreen.
   Click **PRESS START**.

> If you run inside the editor's embedded game view, fullscreen fills that
> panel. For true monitor fullscreen, run the exported `.app`, or turn off
> **"Embed Game on Play"** in the game-view toolbar.

The mouse is captured on start — move the mouse to look around immediately.

## Controls

| Action | Keys |
|---|---|
| Move (on foot) / drive (car) | `W` `A` `S` `D` |
| Sprint / boost | `Shift` |
| Handbrake (car) | `Space` |
| Aim — zoom into first-person (on foot) | Hold `Space` |
| Look (on foot / plane) | Mouse |
| Shoot (on foot) | Left Mouse |
| Enter / exit vehicle | `F` |
| Next / prev weapon | `Q` or `Tab` / `Z` |
| Pick weapon 1–9 | `1`–`9` |
| Cycle weapon (on foot) | Mouse wheel |
| Heal + restock ammo / respawn | `R` |
| Mute | `M` |
| Release / recapture mouse | `Esc` |

**Plane (proper flight):** the engine spools up on its own, so the plane
always builds flying speed — just hold `↑` to climb once it's rolling. `A` /
`D` yaw (banked turn), `↓` drops the nose to descend, `W` / `S` boost / throttle
back. Fly too slowly and it stalls and sinks. Press `F` while airborne to
**bail out with a parachute** (`WASD` steers your drift down). If the plane is
shot down in the air you auto-deploy a chute.

**Helicopter:** parked on the airport helipad. Hold `↑` to lift straight off
the ground and climb, `↓` to descend, `W` / `S` to fly forward / back, `A` /
`D` to turn. Release every key and it simply hovers in place — no runway
needed. `F` bails out with a parachute, same as the plane.

**Iron Man suit:** an armoured suit stands on open ground near where you
spawn — walk onto it and it assembles onto you plate by plate. Suited up you
are **fully bulletproof**, and you can:

- **Fly** — `↑` rises, `↓` descends, and it **hovers in place** when you press
  neither. `W` `A` `S` `D` fly around (relative to the camera), `Shift` boosts.
- **Aim** — hold `Space` to zoom into a first-person targeting view.
- **Repulsors** — hold **Left Mouse** for rapid hand-beam blasts.
- **Missiles** — **Right Mouse** fires an explosive missile.

Press `F` to power the suit down — it drops where you stand, and you can step
onto it again any time to re-suit.

**Vehicle camera:** in a car *or* plane the chase cam follows automatically —
turn and the view swings with you, no mouse needed.

**Airport airfield (south-east):** follow the gold **AIRPORT** marker, cross the
causeway, and walk through the huge terminal lobby. The airport is a long flat
grass airfield with two runways — a **big airliner** on the long main runway
and a **smaller plane** on the secondary one — plus a **helipad** with a
parked **helicopter**. There's plenty of grass past the end of each runway, so
build up speed and pitch the nose up well before you run out of tarmac. To fly,
press `F` next to any parked aircraft.

**Rich VIPs:** cream-suited VIPs roam the city, each shadowed by three
black-suited bodyguards. They are *filthy* rich — taking one down drops a
fortune (anywhere from $1 million to over $1 billion) — but harm the VIP or a
guard and the whole detail opens fire on you.

Dying only costs a small mugging fee ($10–$15), not half your cash.

## Project layout

```
project.godot          autoloads, main scene, window config
scenes/main.tscn       root scene (Node3D + game.gd)
scripts/
  autoload/game_state.gd   money / wanted / time / weapon + ammo
  autoload/audio_fx.gd     procedural Web-Audio-style SFX
  build.gd                 static mesh/material helpers
  weapons.gd               WeaponDB — the 9-weapon table
  human.gd                 blocky humanoid builder + walk animation
  world.gd                 CityWorld — procedural city, airport, collision
  hud.gd                   boot screen / in-game HUD / death screen
  game.gd                  main orchestrator + game loop
```

The world (player, vehicles, NPCs, particles) uses pure kinematic movement with
AABB collision — there are no physics bodies — exactly mirroring the prototype.

## Export for macOS

1. Editor → **Project → Export…**
2. Add a **macOS** preset (install the export templates when prompted).
3. **Export Project** → choose a path → produces a `.app` you can run locally.

For an unsigned local build, leave code-signing disabled in the preset; macOS
Gatekeeper may require right-click → Open the first time.

## Notes

See `DEVIATIONS.md` for the handful of intentional differences from the
original `game.js` prototype.

## Contributing

Issues and pull requests are welcome. The whole game is plain GDScript under
`scripts/` — no build step, just open the folder in Godot 4.6 and press **F5**.

## Credits

Almost everything in the world is generated procedurally in GDScript. The one
third-party art asset is the Formula 1 car:

- **McLaren MCL35M** by [chwashere123](https://sketchfab.com/chwashere123)
  ([Sketchfab](https://sketchfab.com/3d-models/mc-laren-mcl35m-14ae5aaa76e14c278f7d0e45e065279d)),
  licensed under [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/).
  Fitted to game space in `scripts/car_mesh.gd`; the model and its license live
  in `assets/vehicles/mclaren_mcl35m/`.

## License

Released under the [MIT License](LICENSE) — free to use, modify, and
redistribute. "Grand Theft Auto" and "GTA" are trademarks of Take-Two
Interactive; this project is an independent, non-commercial homage and is not
affiliated with them.
