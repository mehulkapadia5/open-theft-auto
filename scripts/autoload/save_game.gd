extends Node
## Local persistent save — money, weapons, owned vehicles, suit tier, properties
## and stock holdings, written to user:// as JSON. Auto-saves on a timer and on
## quit; cleared when the player picks "New Game".

const PATH := "user://open_theft_auto_save.json"
const AUTOSAVE_EVERY := 10.0

var _t := 0.0


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func clear() -> void:
	if has_save():
		DirAccess.open("user://").remove("open_theft_auto_save.json")


func save_now() -> void:
	if not GameState.started:
		return
	# Only finite ammo is stored; unlimited (INF) weapons re-init on load.
	var ammo := {}
	for k in GameState.weapon_ammo:
		var v = GameState.weapon_ammo[k]
		if v != INF:
			ammo[k] = v
	var holdings := []
	for s in StockMarket.stocks:
		if float(s.get("owned", 0.0)) > 0.0:
			holdings.append({"symbol": s.symbol, "owned": s.owned, "spent": s.spent})
	# Market state travels with the holdings — otherwise a Continue reprices
	# every position back to its base price and the portfolio value teleports.
	var market := []
	for s in StockMarket.stocks:
		market.append({
			"symbol": s.symbol, "price": s.price, "base": s.base,
			"mode": s.mode, "mode_ticks": s.mode_ticks, "rate": s.rate,
		})

	var d := {
		"money": GameState.money,
		"weapon_idx": GameState.weapon_idx,
		"ammo": ammo,
		"owned_vehicles": Garage.owned_vehicles,
		"suit_tier": Garage.suit_tier,
		"properties": Garage.properties,
		"active_property": Garage.active_property,
		"holdings": holdings,
		"market": market,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()


## Apply a saved game over the freshly-reset state. Call AFTER the usual
## reset_run()/Garage.reset()/StockMarket.reset() in _on_start.
func load_into() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return false

	GameState.money = int(d.get("money", GameState.money))
	GameState.weapon_idx = int(d.get("weapon_idx", 2))
	GameState.init_weapon_ammo()
	var ammo = d.get("ammo", {})
	if typeof(ammo) == TYPE_DICTIONARY:
		for k in ammo:
			GameState.weapon_ammo[k] = ammo[k]

	Garage.owned_vehicles = _int_array(d.get("owned_vehicles", []))
	Garage.suit_tier = int(d.get("suit_tier", 1))
	Garage.properties = _int_array(d.get("properties", []))
	Garage.active_property = int(d.get("active_property", -1))

	var holdings = d.get("holdings", [])
	if typeof(holdings) == TYPE_ARRAY:
		for h in holdings:
			for s in StockMarket.stocks:
				if s.symbol == h.get("symbol", ""):
					s.owned = float(h.get("owned", 0.0))
					s.spent = float(h.get("spent", 0.0))
					break

	var market = d.get("market", [])
	if typeof(market) == TYPE_ARRAY:
		for m in market:
			for s in StockMarket.stocks:
				if s.symbol == m.get("symbol", ""):
					s.price = clampf(float(m.get("price", s.price)),
							StockMarket.MIN_PRICE, StockMarket.MAX_PRICE)
					s.base = clampf(float(m.get("base", s.base)),
							StockMarket.MIN_PRICE, StockMarket.MAX_PRICE)
					s.mode = str(m.get("mode", "normal"))
					s.mode_ticks = int(m.get("mode_ticks", 0))
					s.rate = float(m.get("rate", 0.0))
					s.open = s.price
					s.prev = s.price
					s.history = [s.price] as Array
					break
		StockMarket.updated.emit()
	return true


func _int_array(a) -> Array[int]:
	var out: Array[int] = []
	if typeof(a) == TYPE_ARRAY:
		for v in a:
			out.append(int(v))
	return out


func _process(dt: float) -> void:
	if not GameState.started or GameState.paused:
		return
	_t += dt
	if _t >= AUTOSAVE_EVERY:
		_t = 0.0
		save_now()


func _notification(what: int) -> void:
	# Flush a final save when the window is closed.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
