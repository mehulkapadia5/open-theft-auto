extends Node
## The player's garage — everything they own.
##
## v1 tracks bought cars from the dealership. Ownership is permanent for the
## run: the spawned car in the world is a disposable instance, so a car that
## gets wrecked can always be re-spawned for free. Owned state lives only in
## memory and is wiped by reset() at the start of every run, matching the way
## GameState clears money and StockMarket rebuilds the market.

signal updated

var owned_vehicles: Array[int] = []     # catalog indices the player owns

func _ready() -> void:
	reset()

## Wipe the garage — called at the start of every run.
func reset() -> void:
	owned_vehicles.clear()
	updated.emit()

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
