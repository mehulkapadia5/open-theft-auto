extends Node
## Angel Ventures HQ — an angel-investing deal flow, ported from the user's web
## prototype (mafia-sim game3d.html's `Boardroom` module). Founders pitch a
## rotating slate of 5 open deals; back one for a stake, then watch it fail,
## get acquired/IPO, raise a follow-on round, or drift in place on a timer.
##
## Unlike the web original — which negotiated equity live over an LLM call — this
## build is fully offline, so the founder haggle is a small deterministic rule
## (see negotiate()) instead of an AI conversation. See scripts/venture_terminal.gd
## for the UI.

signal updated
## Fired with a short flavour line whenever a holding resolves or a founder
## reacts to a negotiation — game.gd forwards these to hud.show_objective.
signal toast(text: String)

const STAGES := ["Seed", "Series A", "Series B", "Series C", "Pre-IPO"]
const FIRST := ["Aarav", "Diya", "Kabir", "Ishaan", "Anaya", "Vivaan", "Myra", "Rohan",
	"Saanvi", "Arjun", "Zara", "Dev", "Tara", "Neel", "Riya", "Aryan", "Ira", "Vihaan"]
const LAST := ["Mehta", "Kapoor", "Iyer", "Shah", "Reddy", "Nair", "Bose", "Khanna",
	"Verma", "Rao", "Sethi", "Gupta", "Menon", "Patel"]
const PRE := ["Hyper", "Quantum", "Nova", "Zen", "Byte", "Flux", "Apex", "Lumen",
	"Orbit", "Indra", "Vayu", "Astra", "Maple", "Pixel", "Cred", "Swift"]
const SUF := ["AI", "Labs", "Pay", "Cart", "Mind", "Grid", "Loop", "Works", "Stack",
	"Health", "Wheels", "Bazaar", "Drone", "Forge"]
const SECT := ["FinTech", "D2C", "AgriTech", "SaaS", "HealthTech", "Mobility",
	"CleanEnergy", "Gaming", "EdTech", "Logistics"]
const SEMO := {
	"FinTech": "💳", "D2C": "🧴", "AgriTech": "🌾", "SaaS": "💻", "HealthTech": "🩺",
	"Mobility": "🛵", "CleanEnergy": "⚡", "Gaming": "🎮", "EdTech": "🎓",
	"Logistics": "📦",
}
const ROLES := ["Founder & CEO", "Co-founder & CEO", "Founder & CTO", "CEO", "Founder"]
const THESES := [
	"Building the operating system for {s}.",
	"Making {s} 10x cheaper for the next billion users.",
	"The default infrastructure layer for {s}.",
	"Reimagining {s} for the country's tier-2 and tier-3 cities.",
	"An AI-native {s} platform for modern teams.",
]
const RISKS := ["low", "med", "high"]
const ASKS := [2_000_000, 5_000_000, 10_000_000, 25_000_000, 50_000_000,
	100_000_000, 250_000_000]

const MIN_TICKET := 100_000
const DEAL_FLOW_SIZE := 5
const RESOLVE_EVERY := 5.0     # real seconds between resolution ticks (unpaused play)

var deals: Array = []
var portfolio: Array = []
var realised: int = 0
var _next_id := 1
var _t := 0.0


func _ready() -> void:
	reset()


## Rebuild the deal board and wipe the portfolio — called at the start of every run.
func reset() -> void:
	deals = []
	portfolio = []
	realised = 0
	_next_id = 1
	_t = 0.0
	_ensure_deal_flow()
	updated.emit()


func _process(delta: float) -> void:
	if not GameState.started or GameState.paused:
		return
	_t += delta
	var guard := 0
	while _t >= RESOLVE_EVERY and guard < 20:
		_t -= RESOLVE_EVERY
		guard += 1
		_resolve_tick()


func _ensure_deal_flow() -> void:
	while deals.size() < DEAL_FLOW_SIZE:
		deals.append(_make_deal())


func _make_deal() -> Dictionary:
	var risk: String = RISKS.pick_random()
	var sector: String = SECT.pick_random()
	var ask: int = ASKS.pick_random()
	var equity: float = float(5 + randi() % 21)     # 5..25%
	var d := {
		"id": _next_id, "company": PRE.pick_random() + SUF.pick_random(),
		"founder": FIRST.pick_random() + " " + LAST.pick_random(),
		"role": ROLES.pick_random(), "sector": sector,
		"emoji": SEMO.get(sector, "🚀"), "risk": risk, "ask": ask,
		"equity": equity, "base_equity": equity,
		"valuation": int(round(float(ask) / (equity / 100.0))),
		"thesis": String(THESES.pick_random()).replace("{s}", sector),
		"traction": _traction(),
	}
	_next_id += 1
	return d


func _traction() -> String:
	var opts := [
		str(2 + randi() % 45) + "% MoM growth",
		str(10 + randi() % 90) + "k users",
		"$" + _commas(100_000 + randi() % 4_900_000) + " ARR",
		"live in " + str(2 + randi() % 20) + " cities",
	]
	return opts.pick_random()


func _commas(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var c := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


## Back deal `idx` with `amount` dollars. Amount is clamped to
## [MIN_TICKET, GameState.money]; rejects (returns false) below the minimum
## ticket or if the player has no cash at all. Creates a portfolio holding at
## floor(invested * stakeMult) where stakeMult reflects any negotiated bump
## to equity above the deal's original baseline.
func invest(idx: int, amount: int) -> bool:
	if idx < 0 or idx >= deals.size():
		return false
	var d: Dictionary = deals[idx]
	amount = clampi(amount, 0, GameState.money)
	if amount < MIN_TICKET:
		return false
	var stake_mult: float = d.equity / d.base_equity if d.base_equity > 0.0 else 1.0
	GameState.money -= amount
	var holding := {
		"id": _next_id, "company": d.company, "founder": d.founder,
		"sector": d.sector, "emoji": d.emoji, "risk": d.risk,
		"equity": d.equity, "invested": amount,
		"value": int(floor(float(amount) * stake_mult)),
		"stage": 0, "status": "active",
	}
	_next_id += 1
	portfolio.append(holding)
	deals.remove_at(idx)
	deals.append(_make_deal())
	updated.emit()
	return true


## Deterministic, offline stand-in for the web original's LLM-negotiated
## haggle (mafia-sim's api/negotiate.js used an OpenRouter model to roleplay
## the founder). Here, a bigger cheque relative to the ask earns more equity —
## up to a hard cap — and a lowball offer risks the founder walking away and
## the deal being pulled from the board.
func negotiate(idx: int, ticket: int) -> Dictionary:
	if idx < 0 or idx >= deals.size():
		return {"status": "invalid"}
	var d: Dictionary = deals[idx]
	var ratio: float = float(ticket) / maxf(float(d.ask), 1.0)
	if ratio < 0.25 and randf() < 0.35:
		var founder_first: String = String(d.founder).split(" ")[0]
		toast.emit(founder_first + " walked away — that offer insulted them.")
		deals.remove_at(idx)
		deals.append(_make_deal())
		updated.emit()
		return {"status": "walked_away"}
	# A cheque bigger than the ask buys real equity upside; matching the ask
	# earns a token concession; a modest lowball earns nothing extra.
	var bonus: float = 0.0
	if ratio > 1.0:
		bonus = clampf((ratio - 1.0) * 12.0, 0.0, 10.0)
	elif ratio >= 0.7:
		bonus = ratio * 1.5
	d.equity = clampf(d.base_equity + bonus, d.base_equity, 40.0)
	d.valuation = int(round(float(d.ask) / (d.equity / 100.0)))
	var founder_first: String = String(d.founder).split(" ")[0]
	toast.emit(founder_first + " will take " + str(int(round(d.equity))) +
		"% for that cheque.")
	updated.emit()
	return {"status": "negotiating", "equity": d.equity, "valuation": d.valuation}


## Advance every active holding one resolution step (fail / exit / raise /
## drift). Built on mafia-sim's Boardroom.progress() odds, but the up-round
## growth is risk-weighted to model the VC power law: high-risk bets mostly die
## (higher fail chance) yet the survivors moon — up to ~8x PER round, and they
## raise more often, so a few up-rounds compound into 10x–100x+ (1,000–10,000%)
## exits. Low-risk plods along at modest multiples; medium sits between.
func _resolve_tick() -> void:
	var changed := false
	for p in portfolio:
		if p.status != "active":
			continue
		var rm: float = 1.5 if p.risk == "high" else (0.6 if p.risk == "low" else 1.0)
		var fail_b: float = [0.06, 0.045, 0.03, 0.018, 0.01][p.stage] * rm
		var exit_b: float = 0.03 + 0.025 * (p.stage - 2) if p.stage >= 2 else 0.0
		# High-risk startups get a few more shots at an up-round (and fail more,
		# above); low-risk raise less often so they plod.
		var raise_b: float = 0.20 if p.risk == "high" else (0.14 if p.risk == "low" else 0.18)
		var r := randf()
		if r < fail_b:
			p.status = "failed"
			p.value = 0
			realised -= p.invested
			changed = true
			toast.emit(String(p.company) + " shut down — lost $" + _commas(p.invested))
		elif r < fail_b + exit_b:
			var payout: int = p.value
			GameState.money += payout
			realised += payout - p.invested
			p.status = "exited"
			p.payout = payout
			changed = true
			var verb := "IPO'd" if p.stage >= 4 else "got acquired"
			toast.emit(String(p.company) + " " + verb + "! +$" + _commas(payout))
			GameState.add_respect(2.0 + p.stage * 1.0)
		elif r < fail_b + exit_b + raise_b and p.stage < 4:
			p.stage += 1
			# Up-round multiple scales with risk — this is where the huge
			# high-risk winners come from (compounded over several rounds).
			var up: float
			match p.risk:
				"high": up = 1.8 + randf() * 2.7   # ~1.8x–4.5x a round → 10x–100x+ tails
				"low":  up = 1.25 + randf() * 0.85  # steady, modest
				_:      up = 1.5 + randf() * 1.7    # medium
			p.value = int(floor(float(p.value) * up))
			changed = true
			toast.emit(String(p.company) + " raised " + STAGES[p.stage] + "! " +
				("%.1f" % up) + "x")
		else:
			p.value = int(floor(float(p.value) * (1.0 + (randf() * 0.05 - 0.02))))
	if changed:
		updated.emit()


## Total live mark of every active holding.
func portfolio_value() -> int:
	var v := 0
	for p in portfolio:
		if p.status == "active":
			v += int(p.value)
	return v


## Total cash actually invested in still-active holdings.
func invested_active() -> int:
	var v := 0
	for p in portfolio:
		if p.status == "active":
			v += int(p.invested)
	return v
