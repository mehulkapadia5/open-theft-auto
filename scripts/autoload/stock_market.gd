extends Node
## Vice Beach Exchange — a live stock-market simulation.
##
## Prices evolve continuously in real time on a fixed tick, independent of the
## game being paused, so the player can buy in, walk away, and come back to a
## fortune or a wipeout. Most tickers drift gently; the volatile "meme" stocks
## can enter rally or crash runs that multiply or gut their price every tick.

signal updated

const TICK := 1.6              # real seconds between market ticks
const MAX_PRICE := 8_000_000.0
const MIN_PRICE := 0.02
const HIST := 90               # price-history samples kept per stock (sparkline)

var stocks: Array = []
var _t := 0.0

func _ready() -> void:
	reset()

## Rebuild the market from scratch — called at the start of every run.
func reset() -> void:
	stocks = [
		#     name                symbol  price    vol    drift    event   rally
		_mk("Vinewood Pictures", "VIN", 128.0, 0.012,  0.0006, 0.0010, 0.55),
		_mk("Maibatsu Motors",   "MBT",  74.0, 0.015,  0.0005, 0.0014, 0.50),
		_mk("Pisswasser Beer",   "PSW",  39.0, 0.021,  0.0004, 0.0026, 0.50),
		_mk("Bean Machine",      "BNM",  52.0, 0.026,  0.0003, 0.0040, 0.52),
		_mk("Lifeinvader",       "LFE",  88.0, 0.036,  0.0002, 0.0075, 0.50),
		_mk("FlyUS Airways",     "FLY",  16.0, 0.046, -0.0006, 0.0120, 0.40),
		_mk("Bawsaq Crypto",     "BWC",   6.5, 0.078,  0.0011, 0.0230, 0.56),
		_mk("RastaPasta",        "RAS",   1.2, 0.092,  0.0009, 0.0270, 0.53),
	]
	_t = 0.0
	updated.emit()

func _mk(nm: String, sym: String, price: float, vol: float, drift: float,
		event: float, rally_bias: float) -> Dictionary:
	return {
		"name": nm, "symbol": sym, "price": price, "open": price,
		"base": price, "prev": price, "vol": vol, "drift": drift,
		"event": event, "rally_bias": rally_bias,
		"owned": 0.0, "spent": 0.0,
		"mode": "normal", "mode_ticks": 0, "rate": 0.0,
		"history": [price] as Array,
	}

func _process(delta: float) -> void:
	_t += delta
	# Catch up on missed ticks (e.g. after a long pause) without runaway loops.
	var guard := 0
	while _t >= TICK and guard < 240:
		_t -= TICK
		guard += 1
		_tick()

func _tick() -> void:
	for s in stocks:
		s.prev = s.price
		if s.mode == "normal":
			# Gentle random walk with mild mean-reversion toward the anchor.
			var revert: float = (log(s.base) - log(s.price)) * 0.02
			var step: float = s.drift + revert + randfn(0.0, s.vol)
			s.price *= clampf(1.0 + step, 0.55, 1.7)
			# Roll for a dramatic rally or crash run.
			if randf() < s.event:
				if randf() < s.rally_bias:
					s.mode = "rally"
					s.mode_ticks = 7 + randi() % 28
					s.rate = 0.07 + randf() * (s.vol * 6.0 + 0.10)
				else:
					s.mode = "crash"
					s.mode_ticks = 5 + randi() % 16
					s.rate = -(0.09 + randf() * 0.26)
		else:
			# In an event run: a strong per-tick move plus noise.
			var jitter: float = randfn(0.0, s.vol * 0.5)
			s.price *= maxf(0.04, 1.0 + s.rate + jitter)
			s.mode_ticks -= 1
			if s.mode_ticks <= 0:
				s.mode = "normal"
				# After a violent move the anchor drifts toward the new reality.
				s.base = lerpf(s.base, s.price, 0.4)
		s.price = clampf(s.price, MIN_PRICE, MAX_PRICE)
		s.history.append(s.price)
		if s.history.size() > HIST:
			s.history.pop_front()
	updated.emit()

## Spend `cash` dollars on stock `idx`, buying fractional shares at the live
## price. Cash is capped at what the player actually has. Returns shares bought.
func buy_with_cash(idx: int, cash: int) -> float:
	var s: Dictionary = stocks[idx]
	if s.price <= 0.0:
		return 0.0
	cash = clampi(cash, 0, GameState.money)
	if cash <= 0:
		return 0.0
	var shares: float = float(cash) / s.price
	GameState.money -= cash
	s.owned += shares
	s.spent += float(cash)
	updated.emit()
	return shares

## Sell `shares` (fractional allowed) of stock `idx` at the live price.
## Returns the number of shares actually sold.
func sell(idx: int, shares: float) -> float:
	var s: Dictionary = stocks[idx]
	shares = minf(shares, s.owned)
	if shares <= 0.0:
		return 0.0
	var avg: float = s.spent / s.owned
	GameState.money += int(round(shares * s.price))
	s.spent = maxf(0.0, s.spent - avg * shares)
	s.owned -= shares
	if s.owned <= 0.0001:
		s.owned = 0.0
		s.spent = 0.0
	updated.emit()
	return shares

## Total live market value of every share the player holds.
func portfolio_value() -> int:
	var v := 0.0
	for s in stocks:
		v += s.owned * s.price
	return int(round(v))
