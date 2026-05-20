extends Node
## Persistent game state — money, wanted level, in-game time, current weapon + ammo.

var started: bool = false
var paused: bool = false
var money: int = 0
var wanted: float = 0.0
var time_min: float = 12.0 * 60.0   # in-game minutes; 12:00 = noon
var weapon_idx: int = 2             # default PISTOL
var weapon_ammo: Dictionary = {}    # weapon name -> remaining rounds (INF = unlimited)

func init_weapon_ammo() -> void:
	weapon_ammo.clear()
	for w in WeaponDB.LIST:
		weapon_ammo[w.name] = w.ammo

func reset_run() -> void:
	money = 0
	wanted = 0.0
	time_min = 12.0 * 60.0
	weapon_idx = 2
	init_weapon_ammo()

func get_ammo(w: Dictionary) -> float:
	if w.ammo == INF:
		return INF
	return weapon_ammo.get(w.name, 0)
