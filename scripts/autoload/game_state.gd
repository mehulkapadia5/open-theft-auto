extends Node
## Persistent game state — money, wanted level, in-game time, current weapon + ammo,
## reputation (respect + happiness) and philanthropy totals.

var started: bool = false
var paused: bool = false
var money: int = 0
var wanted: float = 0.0
var time_min: float = 12.0 * 60.0   # in-game minutes; 12:00 = noon
var weapon_idx: int = 2             # default PISTOL
var weapon_ammo: Dictionary = {}    # weapon name -> remaining rounds (INF = unlimited)

# Reputation metrics — both 0..100. Respect starts low (you're a nobody);
# happiness (the city's mood toward you) starts neutral.
var respect: float = 5.0
var happiness: float = 50.0
var total_donated: int = 0

# Wealth-milestone storyline — every threshold in game.gd's WEALTH_MILESTONES
# that has ever been crossed, so each one fires its celebration exactly once.
var milestones_hit: Array = []

func init_weapon_ammo() -> void:
	weapon_ammo.clear()
	for w in WeaponDB.LIST:
		weapon_ammo[w.name] = w.ammo

func reset_run() -> void:
	money = 0
	wanted = 0.0
	time_min = 12.0 * 60.0
	weapon_idx = 2
	respect = 5.0
	happiness = 50.0
	total_donated = 0
	milestones_hit = []
	init_weapon_ammo()

func get_ammo(w: Dictionary) -> float:
	if w.ammo == INF:
		return INF
	return weapon_ammo.get(w.name, 0)

## Nudge respect, clamped to 0..100.
func add_respect(amt: float) -> void:
	respect = clampf(respect + amt, 0.0, 100.0)

## Nudge happiness, clamped to 0..100.
func add_happiness(amt: float) -> void:
	happiness = clampf(happiness + amt, 0.0, 100.0)
