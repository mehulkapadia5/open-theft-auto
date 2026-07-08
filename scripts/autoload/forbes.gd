extends Node
## FORBES — RICHEST: a fictional rival rich-list that races the player's own
## net worth in real time. ~8 invented tycoons (no real people) random-walk
## upward every tick; a couple of "aggressive" ones grow faster and
## occasionally close a mega-deal that leaps them ahead of the player, firing
## a throttled toast. world.gd mounts the live top-5 (+ the player's own rank
## if they're outside it) on downtown FORBES billboard banners — see
## banner_text() below, the single source those banners read their text from.
##
## Ported in spirit from the user's mafia-sim web prototype's competitive
## leaderboard idea, same pattern as stock_market.gd / ventures.gd: a fixed
## real-time tick independent of pause state, restored across saves.

signal updated
## Fired with a short flavour line when an aggressive rival leapfrogs the
## player, or the player claims the #1 spot for the first time — game.gd
## forwards these to hud.show_objective, same as Ventures.toast.
signal toast(text: String)

const TICK := 4.0                          # real seconds between Forbes ticks
const MIN_WORTH := 1_000_000_000.0         # no rival ever craters below $1B
const MAX_WORTH := 5_000_000_000_000.0     # or blows past $5T over a long session
const OVERTAKE_COOLDOWN := 45.0            # min seconds between "ahead of you again" toasts

# Fictional cast (no real people) spanning ~$5B-$950B so the player has a
# ladder to climb. Two "aggressive" rivals grow faster and occasionally close
# a mega-deal that leaps their worth in one tick.
const RIVAL_TEMPLATES := [
	{"name": "Otto Bergmann",    "company": "Bergmann Autowerks",       "worth": 950_000_000_000.0, "style": "aggressive"},
	{"name": "Eleanor Vance",    "company": "Vance Aerospace",          "worth": 620_000_000_000.0, "style": "steady"},
	{"name": "Kazuo Tanaka",     "company": "Tanaka Heavy Industries",  "worth": 410_000_000_000.0, "style": "steady"},
	{"name": "Rex Calloway",     "company": "Calloway Oil",             "worth": 340_000_000_000.0, "style": "aggressive"},
	{"name": "Priya Nandakumar", "company": "Nandakumar BioGen",        "worth": 95_000_000_000.0,  "style": "steady"},
	{"name": "Simone Delacroix", "company": "Delacroix Luxe Group",     "worth": 58_000_000_000.0,  "style": "steady"},
	{"name": "Marcus Whitfield", "company": "Whitfield Media",          "worth": 22_000_000_000.0,  "style": "steady"},
	{"name": "Ines Okafor",      "company": "Okafor Renewables",        "worth": 5_400_000_000.0,   "style": "steady"},
]

var rivals: Array = []
## True once the player has ever held #1 — gates the one-time trophy toast.
var reached_number_one: bool = false
var _t := 0.0
var _overtake_cd := 0.0


func _ready() -> void:
	reset()


## Rebuild the rival cast with a fresh spread — called at the start of every run.
func reset() -> void:
	rivals = []
	for t in RIVAL_TEMPLATES:
		rivals.append({"name": t.name, "company": t.company, "worth": t.worth, "style": t.style})
	reached_number_one = false
	_t = 0.0
	_overtake_cd = 0.0
	updated.emit()


func _process(delta: float) -> void:
	if not GameState.started or GameState.paused:
		return
	_t += delta
	# Catch up on missed ticks (e.g. after a long pause) without runaway loops.
	var guard := 0
	while _t >= TICK and guard < 20:
		_t -= TICK
		guard += 1
		_tick()


func _tick() -> void:
	_overtake_cd = maxf(0.0, _overtake_cd - TICK)
	var player_worth := float(player_net_worth())
	for r in rivals:
		var was_ahead: bool = r.worth > player_worth
		var aggressive: bool = r.style == "aggressive"
		var drift: float = 0.0026 if aggressive else 0.0009
		var vol: float = 0.015 if aggressive else 0.007
		var step: float = drift + randfn(0.0, vol)
		r.worth = clampf(r.worth * (1.0 + step), MIN_WORTH, MAX_WORTH)
		# Aggressive competitors occasionally close a mega-deal — a sharp
		# one-tick jump that can vault them back past the player.
		if aggressive and randf() < 0.05:
			r.worth = clampf(r.worth * (1.06 + randf() * 0.14), MIN_WORTH, MAX_WORTH)
			var now_ahead: bool = r.worth > player_worth
			if now_ahead and not was_ahead and _overtake_cd <= 0.0:
				toast.emit(String(r.name) + " just closed a mega-deal — ahead of you again.")
				_overtake_cd = OVERTAKE_COOLDOWN

	if player_rank() == 1 and not reached_number_one:
		reached_number_one = true
		toast.emit("You are the richest person alive.")
		GameState.add_respect(15.0)
	updated.emit()


## Total live "net worth" the Forbes race measures the player against — cash
## plus the live mark of every stock and venture holding. Simpler than
## tracking a separate figure, and it means cashing out a big position (or a
## venture exit) visibly moves the player's rank.
func player_net_worth() -> int:
	return GameState.money + StockMarket.portfolio_value() + Ventures.portfolio_value()


## Rivals + the player, sorted by worth descending. Each entry:
## {name, worth, is_player, rank}.
func ranked_list() -> Array:
	var entries: Array = []
	for r in rivals:
		entries.append({"name": r.name, "worth": r.worth, "is_player": false})
	entries.append({"name": "YOU", "worth": float(player_net_worth()), "is_player": true})
	entries.sort_custom(func(a, b): return a.worth > b.worth)
	for i in entries.size():
		entries[i]["rank"] = i + 1
	return entries


func player_rank() -> int:
	for e in ranked_list():
		if e.is_player:
			return e.rank
	return rivals.size() + 1


## The live text every FORBES banner in world.gd displays — top 5, plus the
## player's own line appended if they're outside it. Text-only; banners just
## copy this into their Label3D whenever `updated` fires, no geometry rebuild.
func banner_text() -> String:
	var list := ranked_list()
	var lines := ["FORBES — RICHEST"]
	var top: Array = list.slice(0, mini(5, list.size()))
	for e in top:
		lines.append("#%d  %s — %s" % [e.rank, e.name, short_money(e.worth)])
	if list.size() > 5:
		for e in list:
			if e.is_player and e.rank > 5:
				lines.append("#%d  YOU — %s" % [e.rank, short_money(e.worth)])
				break
	return "\n".join(lines)


# =====================================================================
# Shared money formatting — the one static helper the wealth-storyline code
# (this file, game.gd's milestone toasts, world.gd's banners) reuses instead
# of adding yet another _commas() copy alongside the ones already private to
# each terminal script.
# =====================================================================
static func commas(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var c := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


## Short form for a big dollar figure — $214.3B, $1.4T, $950.0M — falling
## back to full commas under $1,000.
static func short_money(n: float) -> String:
	var neg := n < 0.0
	var v := absf(n)
	var s: String
	if v >= 1_000_000_000_000.0:
		s = "$%.1fT" % (v / 1_000_000_000_000.0)
	elif v >= 1_000_000_000.0:
		s = "$%.1fB" % (v / 1_000_000_000.0)
	elif v >= 1_000_000.0:
		s = "$%.1fM" % (v / 1_000_000.0)
	elif v >= 1_000.0:
		s = "$%.1fK" % (v / 1_000.0)
	else:
		s = "$" + commas(int(v))
	return ("-" if neg else "") + s
