# Open Theft Auto

A **Godot 4.7** open-world sandbox — a GTA-style "Vice Beach" homage built in
pure GDScript. Third-person: walk, drive, fly, shoot, invest and build a
reputation in a procedural, Los-Angeles-style island city with a wanted/police
system, a day/night cycle, a full economy, a wearable Iron-Man-style flight
suit, an F1 circuit, and a Space Shuttle trip to the Moon from a hidden
mountain facility. Playable end-to-end on **keyboard + mouse or a game
controller**, with saved progress.

> Open Theft Auto is an unofficial, fan-made homage. It is not affiliated with,
> endorsed by, or connected to Rockstar Games or Take-Two Interactive, and uses
> none of their assets.

The city is split into districts: a **downtown** core of glassy skyscrapers, a
mid-rise **commercial** ring, sprawling **residential villas** (each with a
lawn, pool, garage and pitched roof), a leafy **hills** neighbourhood, green
**parks** with ponds, and a north-south **river** crossed by bridges. Snow-capped
mountains ring the horizon, an **airport island** and the **President's estate**
sit off the coast across causeways, and the **Moon** hangs high above.

Deep in the northern mountains — off the map, no waypoint, no minimap marker —
sits a hidden facility: a fenced compound with a hangar, a control tower and
a rocket pad. Find it and two ways up are waiting: a real **Space Shuttle**
stack (orbiter, external tank and twin solid boosters, all three modelled
separately) that lifts off, sheds its boosters around 520 m and its tank on
reaching space, then flies the Moon trip on the orbiter alone exactly like
the old single-piece rocket did; or a fully player-flown **fighter
spacecraft** that hovers a few metres off the pad and then punches into a
sudden hyperspeed climb straight to orbit, free-flies there on the sticks,
and — instead of a scripted autoland — hover-descends under full manual
control onto the Moon (or back to Earth) wherever you choose to set down.

## Run it

1. Install **Godot 4.7+** (standard, not .NET — the project is pure GDScript).
2. Open Godot, **Import** this folder (`gta-my-city/`), or open `project.godot`.
3. Press **F5** (Run Project). At the boot screen pick **NEW GAME**, or
   **CONTINUE** if you have a save.

> If you run inside the editor's embedded game view, fullscreen fills that
> panel. For true monitor fullscreen, run the exported `.app`, or turn off
> **"Embed Game on Play"** in the game-view toolbar.

The mouse is captured on start — move the mouse to look around immediately.
Plug in a controller and it's picked up automatically.

## Controls

Every action below is **rebindable** in the pause menu (`Esc` / Options →
**CONTROLS**), which also shows a live keyboard and DualSense-style controller
diagram. The defaults:

### Keyboard & mouse

| Action | Keys |
|---|---|
| Move (on foot) / steer (car) | `W` `A` `S` `D` |
| Sprint / boost | `Shift` |
| Aim down sights (zoom) | Hold `Space` |
| Fire | Left Mouse |
| Alt-fire / suit missiles | Right Mouse |
| Melee | `C` |
| Handbrake (car) | `Space` |
| Fly up / down (suit, plane, heli) | `↑` / `↓` |
| Enter / exit vehicle · power suit on/off | `F` |
| Interact (kiosks, shops) | `E` |
| Summon Iron Man suit | `V` |
| Phone | `P` |
| Next / prev weapon | `Q` or `Tab` / `Z` |
| Pick weapon 1–9 | `1`–`9` |
| Heal + restock ammo / respawn | `R` |
| Grand Prix paddock terminal | `G` |
| Mute | `M` |
| Pause menu | `Esc` |

### Game controller (fully supported)

| Action | Button |
|---|---|
| Move / steer · Look camera | Left stick · Right stick |
| Accelerate / Brake (driving) | R2 / L2 |
| Aim down sights · Fire | L2 · R2 |
| Sprint · Melee | Left back paddle · Right back paddle |
| Boost · Handbrake · Interact · Summon suit · Enter/Exit | ✕ · □ · □ · ○ · △ |
| Prev / next weapon · adjust amount in shops | L1 / R1 |
| Restock/respawn · Grand Prix terminal | D-Pad ↑ · D-Pad ↓ |
| Phone · Pause menu | Share · Options |
| Menus: move focus · confirm · back | D-Pad / stick · ✕ · ○ |

Every shop, terminal, the phone, the boot screen and the pause menu are fully
navigable and confirmable with the controller. (Back paddles fall back to ✕ /
R3-click if your controller doesn't report them.)

## Gameplay

### On foot & combat

Nine weapons — **fists, knife, pistol, revolver, SMG, rifle, shotgun, sniper,
RPG** — each with its own distinct firing sound. Hold aim to zoom into a
first-person view; the **sniper** rolls a proper scope in with an animated zoom.
On a controller, aim-assist gently sticks your reticle to the nearest target.
A dedicated **melee** strike works with any loadout.

### Vehicles

- **Cars** — hop into anything on the street, or buy your own at **Free Harbor
  Autos**. Handbrake slides, speed-widened FOV.
- **Formula 1 & racing** — a real McLaren MCL35M and an F1 circuit; start a
  **Grand Prix** from the paddock terminal for a lap race against AI, with a
  10× payout for the win.
- **Boats** — speedboats, jet-skis and a submarine on the water.
- **Plane** — a flyable **Boeing 787**: the engine spools up on its own, hold
  `↑` to climb, `A`/`D` to bank, `↓` to descend; too slow and it stalls. Bail
  out mid-air with a parachute (`F`).
- **Helicopter** — a **UH-60 Black Hawk** on the airport helipad: vertical
  take-off, hover when you let go, `F` to bail with a chute.
- **Space Shuttle to the Moon** — find the hidden mountain facility, board the
  Shuttle stack and ride the ascent (real booster separation around 520 m,
  then the external tank drops away on reaching space) through re-entry to a
  real low-gravity **lunar surface** (rolling craters, a moon buggy, Earth in
  the sky), then fly home.
- **Spacecraft** — a fully player-flown fighter parked in the facility's
  hangar: hover off the pad, punch into a sudden hyperspeed climb to orbit,
  free-fly there on the sticks, then hover-descend under full manual control
  onto the Moon or back to Earth — no autoland, you fly every landing.

### Iron Man suit

An armoured suit stands near where you spawn — walk onto it and it assembles
plate by plate. Suited up you're **bulletproof** and can **fly** (`↑`/`↓` +
`WASD`, hover when neutral), fire **repulsors** (hold Fire) and **missiles**
(Alt-fire). Upgrade through suit tiers (up to a Hulkbuster) at **Stark
Industries**. Press `F` to drop the suit and re-suit later.

### Money & the economy

You're a rags-to-billions mogul. Spend and grow your fortune downtown:

- **Free Harbor Exchange** — a live **stock market**; buy and sell shares whose
  prices tick in real time.
- **Angel Ventures HQ** — a landmark tower where you play **angel investor**:
  back early-stage startups from the deal flow, negotiate the founder's terms
  for more equity, and watch them fail, get acquired, or IPO. High-risk bets
  mostly die but the winners can moon 10×–100×+.
- **Free Harbor Autos** — buy cars. **Free Harbor Realty** — buy safehouses.
  **Stark Industries** — upgrade the suit.
- **Wealth milestones** — crossing $1,000 / $100K / $1M / $100M / $1B / $10B /
  $1T for the first time is an event: a knot of locals rushes over on foot to
  congratulate you (escalating in size with the tier), a flavourful toast
  fires, and Respect gets a one-off bump. Each tier only ever fires once, and
  a milestone crossed mid-flight or mid-drive waits until you're next walking
  the streets on Earth to play out.
- **FORBES — RICHEST** — a live rich-list of 8 fictional rival tycoons races
  your own net worth in real time, shown on big lit banners downtown (the
  Exchange tower, Angel Ventures HQ). A couple of them play aggressive and
  occasionally leapfrog you with a "just closed a mega-deal" toast; claim #1
  for the first time and the whole city hears about it.

### Reputation — Respect & Happiness

Two live metrics on the HUD. **Donate** money at **Free Harbor General
Hospital** to lift both (with diminishing returns); a successful venture exit
raises Respect; crime and a high wanted level slowly sour the city's Mood.

### The city & its people

- **Rich VIPs** roam the streets shadowed by bodyguards — take one down for a
  fortune ($1M to over $1B), but the whole detail opens fire if you do.
- A **wanted/police** system escalates from cops to SWAT the more heat you draw.
- **President endgame** — intercept the President's motorcade to **seize the
  city** (passive income, an escort detail, and the police stand down).
- Clothed, varied pedestrians and a clothed player character.

### Quality-of-life

- **Save & Continue** — your money, weapons, cars, suit tier, properties,
  stocks, venture portfolio, reputation, wealth milestones reached and the
  FORBES rivals' live worths all autosave and resume from the boot screen.
- **Phone** (`P`) — fast-travel and quick actions.
- **Pause menu** (`Esc` / Options) — resume, rebind controls, or exit.
- Stacked **toast notifications**, a top-down minimap, a day/night cycle
  (navigable, moonlit nights), and a touch HUD for mobile.

## Project layout

```
project.godot          autoloads, main scene, window config
scenes/main.tscn       root scene (Node3D + game.gd)
scripts/
  game.gd                  main orchestrator + game loop
  world.gd                 CityWorld — procedural city, airport, Moon, collision
  human.gd                 character catalog + procedural / mocap walk animation
  car_mesh.gd              car + F1 mesh builder
  build.gd                 static mesh/material helpers
  weapons.gd               WeaponDB — the 9-weapon table
  hud.gd                   boot screen / HUD / toasts / scope / death screen
  pause_menu.gd            pause + rebindable-controls screen
  ui_nav.gd                gamepad focus navigation for menus
  phone.gd                 phone menu
  touch_hud.gd             on-screen touch controls (mobile)
  *_terminal.gd            kiosk UIs: stock, dealership, realtor, suit, race,
                           donate, venture
  vehicle_catalog.gd / property_catalog.gd / suit_catalog.gd   shop catalogs
  track.gd                 F1 circuit geometry
  autoload/
    game_state.gd            money / wanted / time / weapons / respect / happiness
    save_game.gd             autosave + Continue
    input_config.gd          rebindable actions (keyboard + controller)
    gamepad.gd               controller polling, deadzones, rumble
    audio_fx.gd              procedural + sampled SFX (per-gun sounds, engines…)
    stock_market.gd          the stock exchange
    ventures.gd              Angel Ventures — startup deal flow & outcomes
    forbes.gd                FORBES — RICHEST rival rich-list, live banners
    garage.gd                owned vehicles / suit tier / properties
    race_manager.gd          Grand Prix race state & payouts
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
`scripts/` — no build step, just open the folder in Godot 4.7 and press **F5**.

## Credits

Almost everything in the world is generated procedurally in GDScript. The
third-party art assets are the vehicles and the human character models, all used
under their respective licenses:

- **McLaren MCL35M** by [chwashere123](https://sketchfab.com/chwashere123)
  ([Sketchfab](https://sketchfab.com/3d-models/mc-laren-mcl35m-14ae5aaa76e14c278f7d0e45e065279d)),
  licensed under [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/).
  Fitted to game space in `scripts/car_mesh.gd`; the model and its license live
  in `assets/vehicles/mclaren_mcl35m/`.

- **Universal Base Characters** by [Quaternius](https://quaternius.com/), a
  free/CC0 rigged human pack. The cop and re-tinted "civilian" NPC bodies used
  throughout `scripts/human.gd`; the models live in `assets/characters/ubc/`.

- **"Indian Man in suit"** by [Pixel_Monster](https://sketchfab.com/ar.jethin)
  ([Sketchfab](https://sketchfab.com/3d-models/indian-man-in-suit-985dd9756d89464b9380414b5b12d8aa)),
  licensed under [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/).
  This work is based on "Indian Man in suit"
  (https://sketchfab.com/3d-models/indian-man-in-suit-985dd9756d89464b9380414b5b12d8aa)
  by Pixel_Monster (https://sketchfab.com/ar.jethin) licensed under CC-BY-4.0
  (http://creativecommons.org/licenses/by/4.0/). Used for the rich VIPs roaming
  the city; the model and its license live in `assets/characters/vip_suit/`.

- **"Man Dressed In Suit"** by [3d-character-br](https://sketchfab.com/3d-character-br)
  ([Sketchfab](https://sketchfab.com/3d-models/man-dressed-in-suit-ae103052b58a450397f42a189aa726b7)),
  licensed under [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/).
  This work is based on "Man Dressed In Suit"
  (https://sketchfab.com/3d-models/man-dressed-in-suit-ae103052b58a450397f42a189aa726b7)
  by 3d-character-br (https://sketchfab.com/3d-character-br) licensed under
  CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/). Used for VIP and
  Presidential bodyguards; the model and its license live in
  `assets/characters/guard_suit/`.

- **"Nathan Animated 003 - Walking 3D Man"** by [Renderpeople](https://sketchfab.com/renderpeople)
  ([Sketchfab](https://sketchfab.com/3d-models/nathan-animated-003-walking-3d-man-143a2b1ea5eb4385ae90a73657aca3bc)),
  licensed under [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/).
  This work is based on "Nathan Animated 003 - Walking 3D Man"
  (https://sketchfab.com/3d-models/nathan-animated-003-walking-3d-man-143a2b1ea5eb4385ae90a73657aca3bc)
  by Renderpeople (https://sketchfab.com/renderpeople) licensed under CC-BY-4.0
  (http://creativecommons.org/licenses/by/4.0/). A photo-scanned casual
  pedestrian mixed into the civilian crowd; the model and its license live in
  `assets/characters/nathan/`.

- **"Spider-man PETER PARKER: THE PHOTOGRAPHER"** by [YE YE](https://sketchfab.com/YEEZY_YE)
  ([Sketchfab](https://sketchfab.com/3d-models/spider-man-peter-parker-the-photographer)),
  licensed under [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/).
  This work is based on "Spider-man PETER PARKER: THE PHOTOGRAPHER"
  by YE YE (https://sketchfab.com/YEEZY_YE) licensed under CC-BY-4.0
  (http://creativecommons.org/licenses/by/4.0/). Used as the clothed player
  character; the model and its license live in `assets/characters/peter/`.

- **"Low Poly Boeing 787 Dreamliner"** by [Mauro3D](https://sketchfab.com/maurogsw)
  ([Sketchfab](https://sketchfab.com/3d-models/low-poly-boeing-787-dreamliner)),
  licensed under [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/).
  This work is based on "Low Poly Boeing 787 Dreamliner"
  by Mauro3D (https://sketchfab.com/maurogsw) licensed under CC-BY-4.0
  (http://creativecommons.org/licenses/by/4.0/). The player-flyable plane's
  visual body, fitted to game space in `scripts/game.gd`'s `_make_plane`; the
  model and its license live in `assets/vehicles/plane_787/`.

- **"US Army UH-60M Black Hawk low poly model"** by [Yi Tsung Lee](https://sketchfab.com/WTigerTw)
  ([Sketchfab](https://sketchfab.com/3d-models/us-army-uh-60m-black-hawk-low-poly-model-854bf0feee5b42dc92ac5329976f7942)),
  licensed under [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/).
  This work is based on "US Army UH-60M Black Hawk low poly model"
  (https://sketchfab.com/3d-models/us-army-uh-60m-black-hawk-low-poly-model-854bf0feee5b42dc92ac5329976f7942)
  by Yi Tsung Lee (https://sketchfab.com/WTigerTw) licensed under CC-BY-4.0
  (http://creativecommons.org/licenses/by/4.0/). The player-flyable
  helicopter's visual body, fitted to game space in `scripts/game.gd`'s
  `_make_helicopter`; the model and its license live in
  `assets/vehicles/blackhawk/`.

- **"Space Shuttle with boosters"** by [assetfactory](https://sketchfab.com/assetfactory)
  ([Sketchfab](https://sketchfab.com/3d-models/space-shuttle-with-boosters-28c98646369f48ee84bc20c267bc685f)),
  used under the [Sketchfab Standard License](https://sketchfab.com/licenses).
  Three separately detachable meshes (orbiter, external tank, twin SRB
  boosters) fitted to game space in `scripts/game.gd`'s `_make_rocket` /
  `_wrap_shuttle_mesh`; the model and its license live in
  `assets/vehicles/shuttle/`.

- **"CLASS-3 FIGHTER SPACESHIP HODBIN"** by [Kerem Kavalci](https://sketchfab.com/Keremz)
  ([Sketchfab](https://sketchfab.com/3d-models/class-3-fighter-spaceship-hodbin-free-model-3451df5fb9d34cd98c3f63cfc0321dd3)),
  used under the [Sketchfab Standard License](https://sketchfab.com/licenses).
  The player-flyable spacecraft's visual body, fitted to game space in
  `scripts/game.gd`'s `_make_spacecraft`; the model and its license live in
  `assets/vehicles/spacecraft/`.

## License

Released under the [MIT License](LICENSE) — free to use, modify, and
redistribute. "Grand Theft Auto" and "GTA" are trademarks of Take-Two
Interactive; this project is an independent, non-commercial homage and is not
affiliated with them.
