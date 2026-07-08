extends Node
## Local persistent save — money, weapons, owned vehicles, suit tier, properties,
## stock holdings, reputation/philanthropy and the angel-investing portfolio,
## written to user:// as JSON. Auto-saves on a timer and on quit; cleared when
## the player picks "New Game".

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
	# The venture portfolio travels whole — the open deal board is fine to
	# regenerate fresh on load (Ventures.reset() always keeps 5 deals open).
	var venture_portfolio := []
	for p in Ventures.portfolio:
		var row := {
			"company": p.company, "founder": p.founder, "sector": p.sector,
			"emoji": p.emoji, "risk": p.risk, "equity": p.equity,
			"invested": p.invested, "value": p.value, "stage": p.stage,
			"status": p.status,
		}
		if p.has("payout"):
			row["payout"] = p.payout
		venture_portfolio.append(row)

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
		"respect": GameState.respect,
		"happiness": GameState.happiness,
		"total_donated": GameState.total_donated,
		"venture_portfolio": venture_portfolio,
		"venture_realised": Ventures.realised,
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

	GameState.respect = clampf(float(d.get("respect", GameState.respect)), 0.0, 100.0)
	GameState.happiness = clampf(float(d.get("happiness", GameState.happiness)), 0.0, 100.0)
	GameState.total_donated = int(d.get("total_donated", 0))

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

	# Ventures.reset() already ran in _on_start, leaving a fresh 5-deal board —
	# only the portfolio + realised P/L need restoring on top of that.
	Ventures.realised = int(d.get("venture_realised", 0))
	var vport = d.get("venture_portfolio", [])
	if typeof(vport) == TYPE_ARRAY:
		var restored: Array = []
		for row in vport:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var holding := {
				"id": 0, "company": str(row.get("company", "")),
				"founder": str(row.get("founder", "")),
				"sector": str(row.get("sector", "")),
				"emoji": str(row.get("emoji", "🚀")),
				"risk": str(row.get("risk", "med")),
				"equity": float(row.get("equity", 10.0)),
				"invested": int(row.get("invested", 0)),
				"value": int(row.get("value", 0)),
				"stage": clampi(int(row.get("stage", 0)), 0, 4),
				"status": str(row.get("status", "active")),
			}
			if row.has("payout"):
				holding["payout"] = int(row.payout)
			restored.append(holding)
		Ventures.portfolio = restored
		Ventures.updated.emit()
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
