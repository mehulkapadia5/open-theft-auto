class_name VehicleCatalog
## Cars sold at the Vice Beach dealership.
##
## Fields match the live vehicle dict built by Game._make_vehicle — `color` is
## passed straight in, `max_speed` overrides the spawned car's top speed.
## Prices are anchored to VIP bounties ($1M+): a starter car is pocket change,
## a supercar is a real trophy. Cars are the cheap tier; suits and property are
## the deep money sinks (added later).

## max_speed is in m/s — the speedometer shows it ×3.6 as km/h. The spread is
## deliberately wide: a city cab tops out near 65 km/h, the Formula 1 car well
## past 350 km/h before boost.
const LIST: Array = [
	#    name              category   style     price        max_speed  color
	{"name": "City Cab",    "category": "Sedan",   "style": "sedan",  "price": 35_000,    "max_speed": 18.0,  "color": 0xc9a23a},
	{"name": "Vapid Stride","category": "Sedan",   "style": "sedan",  "price": 60_000,    "max_speed": 23.0,  "color": 0x2b384e},
	{"name": "Granger XL",  "category": "SUV",     "style": "suv",    "price": 180_000,   "max_speed": 26.0,  "color": 0x1b1b1d},
	{"name": "Buffalo GT",  "category": "Sports",  "style": "sports", "price": 480_000,   "max_speed": 40.0,  "color": 0x5e2a2a},
	{"name": "Comet Coupe", "category": "Coupe",   "style": "coupe",  "price": 850_000,   "max_speed": 46.0,  "color": 0x9a9ca0},
	{"name": "Banshee",     "category": "Sports",  "style": "sports", "price": 1_400_000, "max_speed": 54.0,  "color": 0xdcdcda},
	{"name": "Adder",       "category": "Hyper",   "style": "hyper",  "price": 2_600_000, "max_speed": 66.0,  "color": 0x14202e},
	{"name": "Vacca Veloce","category": "Hyper",   "style": "hyper",  "price": 4_500_000, "max_speed": 78.0,  "color": 0xb8902a},
	{"name": "Formula 1",   "category": "Formula 1","style": "f1",    "price": 8_000_000, "max_speed": 111.0, "color": 0xc0392b},
]
