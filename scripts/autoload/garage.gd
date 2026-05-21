extends Node
## The player's garage — everything they own: cars, the Iron Man suit tier,
## and safehouse property.
##
## Ownership is permanent for the run. Spawned cars in the world are disposable
## instances, so a wrecked car can always be re-spawned for free. The suit tier
## only ever climbs — the player always wears the best suit they own. Owned
## state lives only in memory and is wiped by reset() at the start of every
## run, matching the way GameState clears money and StockMarket rebuilds.

signal updated

var owned_vehicles: Array[int] = []     # catalog indices the player owns
var suit_tier: int = 1                  # 1 Mark III · 2 Mark VI · 3 War Machine · 4 Hulkbuster
var properties: Array[int] = []         # PropertyCatalog indices the player owns
var active_property: int = -1           # owned property used as the respawn home (-1 = none)

func _ready() -> void:
	reset()

## Wipe the garage — called at the start of every run.
func reset() -> void:
	owned_vehicles.clear()
	suit_tier = 1
	properties.clear()
	active_property = -1
	updated.emit()


# ---------------- Vehicles ----------------
func owns_vehicle(idx: int) -> bool:
	return owned_vehicles.has(idx)

## Buy car `idx` from the catalog. Deducts cash, records ownership.
## Returns true on success (affordable and not already owned).
func buy_vehicle(idx: int) -> bool:
	if idx < 0 or idx >= VehicleCatalog.LIST.size():
		return false
	if owns_vehicle(idx):
		return false
	var price: int = VehicleCatalog.LIST[idx].price
	if GameState.money < price:
		return false
	GameState.money -= price
	owned_vehicles.append(idx)
	updated.emit()
	return true


# ---------------- Suit ----------------
## Stats for the suit tier the player currently wears (always the best owned).
func suit_stats() -> Dictionary:
	return SuitCatalog.LIST[clampi(suit_tier - 1, 0, SuitCatalog.LIST.size() - 1)]

## Buy suit `tier` (2 or 3). Must be an upgrade over the current tier.
## Returns true on success.
func buy_suit(tier: int) -> bool:
	if tier <= suit_tier or tier > SuitCatalog.LIST.size():
		return false
	var price: int = SuitCatalog.LIST[tier - 1].price
	if GameState.money < price:
		return false
	GameState.money -= price
	suit_tier = tier
	updated.emit()
	return true


# ---------------- Property ----------------
func owns_property(idx: int) -> bool:
	return properties.has(idx)

## Buy property `idx`. The first property bought becomes home automatically.
## Returns true on success.
func buy_property(idx: int) -> bool:
	if idx < 0 or idx >= PropertyCatalog.LIST.size():
		return false
	if owns_property(idx):
		return false
	var price: int = PropertyCatalog.LIST[idx].price
	if GameState.money < price:
		return false
	GameState.money -= price
	properties.append(idx)
	if active_property < 0:
		active_property = idx
	updated.emit()
	return true

## Set an owned property as the respawn home.
func set_active_property(idx: int) -> bool:
	if not owns_property(idx):
		return false
	active_property = idx
	updated.emit()
	return true
