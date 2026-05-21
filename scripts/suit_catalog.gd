class_name SuitCatalog
## Iron Man suit tiers, sold at the Stark lab.
##
## Tier 1 (Mark III) is free — it is the suit already parked in the world.
## Buying a higher tier upgrades every stat at once; the player always wears
## the highest tier they own. Stats drive flight speed, repulsor output and
## whether the suit's shoulder missiles are online.
##
## `tier` is 1-based; catalog index is tier - 1.

const LIST: Array = [
	{
		"name": "Mark III", "price": 0,
		"fly_v": 14.0, "fly_h": 22.0,
		"repulsor_dmg": 18.0, "repulsor_cd": 0.18,
		"has_missiles": false, "missile_dmg": 0.0, "missile_cd": 1.0,
	},
	{
		"name": "Mark VI", "price": 1_800_000,
		"fly_v": 17.0, "fly_h": 26.0,
		"repulsor_dmg": 28.0, "repulsor_cd": 0.13,
		"has_missiles": true, "missile_dmg": 68.0, "missile_cd": 0.85,
	},
	{
		"name": "War Machine", "price": 15_000_000,
		"fly_v": 22.0, "fly_h": 34.0,
		"repulsor_dmg": 42.0, "repulsor_cd": 0.10,
		"has_missiles": true, "missile_dmg": 100.0, "missile_cd": 0.5,
	},
]
