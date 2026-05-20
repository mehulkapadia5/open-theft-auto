class_name WeaponDB
## Weapon definitions — index maps to hotkeys 1-9 (index 0 = FISTS).

const LIST: Array = [
	{"name": "FISTS",    "ammo": INF, "damage": 10.0,  "rate": 0.32,  "range": 2.4,  "spread": 0.0,   "pellets": 1, "sound": false, "melee": true,  "explosive": false},
	{"name": "KNIFE",    "ammo": INF, "damage": 32.0,  "rate": 0.42,  "range": 2.8,  "spread": 0.0,   "pellets": 1, "sound": false, "melee": true,  "explosive": false},
	{"name": "PISTOL",   "ammo": INF, "damage": 22.0,  "rate": 0.26,  "range": 80.0, "spread": 0.012, "pellets": 1, "sound": true,  "melee": false, "explosive": false},
	{"name": "REVOLVER", "ammo": 36,  "damage": 58.0,  "rate": 0.5,   "range": 90.0, "spread": 0.006, "pellets": 1, "sound": true,  "melee": false, "explosive": false},
	{"name": "SMG",      "ammo": 300, "damage": 13.0,  "rate": 0.055, "range": 68.0, "spread": 0.04,  "pellets": 1, "sound": true,  "melee": false, "explosive": false},
	{"name": "RIFLE",    "ammo": 120, "damage": 40.0,  "rate": 0.2,   "range": 130.0,"spread": 0.018, "pellets": 1, "sound": true,  "melee": false, "explosive": false},
	{"name": "SHOTGUN",  "ammo": 48,  "damage": 13.0,  "rate": 0.62,  "range": 42.0, "spread": 0.17,  "pellets": 8, "sound": true,  "melee": false, "explosive": false},
	{"name": "SNIPER",   "ammo": 20,  "damage": 95.0,  "rate": 1.0,   "range": 220.0,"spread": 0.001, "pellets": 1, "sound": true,  "melee": false, "explosive": false},
	{"name": "RPG",      "ammo": 8,   "damage": 130.0, "rate": 1.3,   "range": 160.0,"spread": 0.015, "pellets": 1, "sound": true,  "melee": false, "explosive": true},
]
