extends Node
## Grand Prix race control — a structured race the player enters in an F1 car.
##
## A race has four states: idle (no race), countdown (lights out in a moment),
## racing (laps counting) and finished. Entry costs a fixed fee plus a bet the
## player chooses; finishing on the podium pays the bet back with winnings.
## Lap timing and drift scoring run only while a race is live.

signal race_finished        # emitted once when the player crosses the final line

const ENTRY_FEE := 100_000

var track: Track = null

# Race state.
var state := "idle"          # idle / countdown / racing / finished
var total_laps := 3
var bet := 0
var countdown := 0.0
var finished_place := 0
var payout := 0

# Per-lap timing.
var lap := 0
var lap_time := 0.0
var last_lap := 0.0
var best_lap := 0.0
var on_track := false
var driving := false
var idx := 0                 # player's nearest baked centreline index

var drift_score := 0
var drift_active := 0.0

var _armed := false
var _cooldown := 0.0


func reset() -> void:
	state = "idle"
	total_laps = 3
	bet = 0
	countdown = 0.0
	finished_place = 0
	payout = 0
	lap = 0
	lap_time = 0.0
	last_lap = 0.0
	best_lap = 0.0
	drift_score = 0
	drift_active = 0.0
	on_track = false
	driving = false
	idx = 0
	_armed = false
	_cooldown = 0.0


func is_active() -> bool:
	return state == "countdown" or state == "racing"


## Begin a race: `laps` long, with the player's chosen `bet_amount` riding on it.
## The entry fee and bet are deducted by the caller before this is called.
func start_race(laps: int, bet_amount: int) -> void:
	total_laps = laps
	bet = bet_amount
	countdown = 4.0
	finished_place = 0
	payout = 0
	lap = 0
	lap_time = 0.0
	last_lap = 0.0
	best_lap = 0.0
	drift_score = 0
	drift_active = 0.0
	_armed = false
	_cooldown = 0.0
	state = "countdown"


## Abandon a race in progress — the bet and entry fee are forfeit.
func abort_race() -> void:
	state = "idle"


## Settle the finished race at the player's `place`. 1st pays 10× the bet, 2nd
## pays 4×, 3rd pays 2×, lower places lose it. Returns the payout.
func settle(place: int) -> int:
	finished_place = place
	var mult := 0.0
	match place:
		1: mult = 10.0
		2: mult = 4.0
		3: mult = 2.0
		_: mult = 0.0
	payout = int(round(bet * mult))
	GameState.money += payout
	state = "finished"
	return payout


## Called every frame from Game with the player's state.
func tick(dt: float, pos: Vector3, in_car: bool, drifting: bool) -> void:
	driving = in_car
	if track == null or not in_car:
		on_track = false
		drift_active = 0.0
		return

	var n := track.baked.size()
	idx = track.nearest_index(pos)
	var off := Vector2(pos.x - track.baked[idx].x, pos.z - track.baked[idx].z)
	on_track = off.length() < track.width_at(idx) / 2.0

	if state == "countdown":
		countdown -= dt
		if countdown <= 0.0:
			countdown = 0.0
			state = "racing"
			lap_time = 0.0
			_armed = false
		return

	if state != "racing":
		return

	# --- Live race: lap timing + finish detection ---
	_cooldown = maxf(0.0, _cooldown - dt)
	lap_time += dt
	if idx > n / 2:
		_armed = true
	if _armed and idx < n / 10 and _cooldown <= 0.0:
		_armed = false
		_cooldown = 6.0
		last_lap = lap_time
		if best_lap == 0.0 or last_lap < best_lap:
			best_lap = last_lap
		lap += 1
		lap_time = 0.0
		if lap >= total_laps:
			state = "finished"
			race_finished.emit()

	if drifting and on_track:
		drift_active += dt
		drift_score += int(60.0 * dt * (1.0 + drift_active * 0.4))
	else:
		drift_active = 0.0


## "m:ss.cs" — used by the HUD for lap times.
func format_time(t: float) -> String:
	if t <= 0.0:
		return "--:--"
	var mins := int(t / 60.0)
	var rem := t - mins * 60.0
	return "%d:%05.2f" % [mins, rem]
