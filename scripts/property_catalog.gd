class_name PropertyCatalog
## Safehouses sold by the Vice Beach realtor.
##
## Each property is a real house standing in the world (world.gd builds one at
## every entry). Buying the deed lets the player set it as their home — the
## point they respawn at after dying. `x`/`z` is the front-yard respawn spot;
## the house itself is built just behind it.

const LIST: Array = [
	{"name": "Vespucci Beach House",   "price": 300_000,    "x": -128.0, "z": 128.0},
	{"name": "Mirror Park Home",       "price": 1_500_000,  "x": 128.0,  "z": -128.0},
	{"name": "Rockford Villa",         "price": 6_000_000,  "x": -128.0, "z": -128.0},
	{"name": "Vinewood Hills Estate",  "price": 25_000_000, "x": -128.0, "z": 0.0},
]
