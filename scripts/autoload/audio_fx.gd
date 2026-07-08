extends Node
## Procedural sound effects — ports the Web Audio beep/noise logic from game.js.
## All sounds are synthesized at load time into AudioStreamWAV buffers.

const MIX_RATE := 22050

var _muted: bool = false
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _ambient_player: AudioStreamPlayer
var _radio_player: AudioStreamPlayer
var _rocket_player: AudioStreamPlayer   # continuous ascent engine loop
var _wind_player: AudioStreamPlayer     # continuous re-entry wind roar loop
var _spacecraft_player: AudioStreamPlayer   # continuous spacecraft engine loop

# Pre-baked streams
var _s_hit: AudioStreamWAV
var _s_coin_a: AudioStreamWAV
var _s_coin_b: AudioStreamWAV
var _s_explode_noise: AudioStreamWAV
var _s_explode_low: AudioStreamWAV
var _s_siren_a: AudioStreamWAV
var _s_siren_b: AudioStreamWAV
var _s_gun: AudioStreamWAV          # real recorded gunshot (CC0) — generic fallback
var _s_gun_sniper: AudioStreamWAV   # deeper boom for the sniper (recorded sample)
var _s_sniper_tail: AudioStreamWAV  # synthesized deep sub-boom layered under it
# Distinct, synthesized per-weapon firing reports — see gunshot() and _gunshot().
var _s_gun_pistol: AudioStreamWAV
var _s_gun_revolver: AudioStreamWAV
var _s_gun_smg: AudioStreamWAV
var _s_gun_rifle: AudioStreamWAV
var _s_gun_shotgun: AudioStreamWAV
var _s_gun_rpg: AudioStreamWAV
var _s_repulsor: AudioStreamWAV     # Iron Man hand repulsor energy blast
var _s_missile: AudioStreamWAV      # Iron Man shoulder missile launch
var _s_rocket_ignite: AudioStreamWAV
var _s_rocket_loop: AudioStreamWAV
var _s_wind_loop: AudioStreamWAV
var _s_spacecraft_loop: AudioStreamWAV

func _ready() -> void:
	for i in 20:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_s_hit = _tone(180.0, 0.08, "sawtooth", 0.6)
	_s_coin_a = _tone(880.0, 0.06, "square", 0.45)
	_s_coin_b = _tone(1320.0, 0.09, "square", 0.45)
	_s_explode_noise = _noise(0.5, 0.9)
	_s_explode_low = _tone(80.0, 0.4, "sawtooth", 0.85)
	_s_siren_a = _tone(700.0, 0.15, "sine", 0.4)
	_s_siren_b = _tone(500.0, 0.15, "sine", 0.4)
	_s_rocket_ignite = _rocket_ignition(1.1, 0.95)
	_s_rocket_loop = _rocket_rumble(1.4, 0.85)
	_s_wind_loop = _wind_noise(1.0, 0.8)
	_s_spacecraft_loop = _spacecraft_hum(1.3, 0.8)
	_s_repulsor = _repulsor(0.22, 0.7)
	_s_missile = _missile_launch(0.5, 0.9)

	# Real recorded gunfire (CC0, OpenGameArt "Free Firearm Sound Library").
	_s_gun = load("res://assets/audio/gunshot.wav")
	_s_gun_sniper = load("res://assets/audio/gunshot_sniper.wav")
	_s_sniper_tail = _sniper_tail(0.65, 0.85)

	# Per-weapon firing reports — each is a layered noise-snap + pitch-dropping
	# "crack" tone + low body thump + noise tail (see _gunshot()), tuned so
	# every gun in WeaponDB.LIST reads as a distinct weapon rather than a
	# shared beep. See gunshot() for the name -> sound dispatch.
	_s_gun_pistol = _gunshot(0.14, 0.7, 1900.0, 500.0, 0.9, 150.0, 0.5, 0.05, 0.25, 0.5, 0.95)
	_s_gun_revolver = _gunshot(0.22, 0.75, 1500.0, 320.0, 0.95, 105.0, 0.68, 0.08, 0.42, 0.4, 1.0)
	_s_gun_smg = _gunshot(0.07, 0.8, 2500.0, 950.0, 0.8, 230.0, 0.32, 0.03, 0.08, 0.62, 0.8)
	_s_gun_rifle = _gunshot(0.17, 0.75, 1700.0, 380.0, 1.0, 120.0, 0.72, 0.07, 0.32, 0.45, 1.0)
	_s_gun_shotgun = _gunshot(0.38, 0.9, 900.0, 190.0, 0.7, 72.0, 0.9, 0.13, 0.75, 0.22, 1.0)
	_s_gun_rpg = _rpg_launch(0.55, 0.95)

	# Looping background tracks on their own dedicated players.
	_ambient_player = AudioStreamPlayer.new()
	add_child(_ambient_player)
	_ambient_player.stream = _drone([55.0, 82.5], 2.0, 0.5)
	_ambient_player.volume_db = -23.0
	_radio_player = AudioStreamPlayer.new()
	add_child(_radio_player)
	_radio_player.stream = _melody(
		[220.0, 277.0, 330.0, 440.0, 392.0, 330.0, 277.0, 220.0], 0.26, "sine", 0.5)
	_radio_player.volume_db = -13.0
	_rocket_player = AudioStreamPlayer.new()
	add_child(_rocket_player)
	_rocket_player.stream = _s_rocket_loop
	_wind_player = AudioStreamPlayer.new()
	add_child(_wind_player)
	_wind_player.stream = _s_wind_loop
	_spacecraft_player = AudioStreamPlayer.new()
	add_child(_spacecraft_player)
	_spacecraft_player.stream = _s_spacecraft_loop


## A WAV that loops forward forever — for ambience and the radio.
func _loop_wav(data: PackedByteArray) -> AudioStreamWAV:
	var st := _wav(data)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = data.size() / 2 - 1
	return st


## A soft sustained drone — the freqs must complete whole cycles over `dur`
## so the buffer loops seamlessly.
func _drone(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var s := 0.0
		for f in freqs:
			s += sin(float(i) / MIX_RATE * float(f) * TAU)
		s /= float(freqs.size())
		data.encode_s16(i * 2, int(clamp(s * vol, -1.0, 1.0) * 32767.0))
	return _loop_wav(data)


## A looping chiptune riff — one note per entry in `freqs`.
func _melody(freqs: Array, note_dur: float, wave: String, vol: float) -> AudioStreamWAV:
	var per := int(MIX_RATE * note_dur)
	var data := PackedByteArray()
	data.resize(per * freqs.size() * 2)
	var idx := 0
	for f in freqs:
		var phase := 0.0
		var inc: float = float(f) / MIX_RATE
		for i in per:
			var t := float(i) / float(per)
			var env := clampf(minf(t * 8.0, (1.0 - t) * 8.0), 0.0, 1.0)
			var s := 0.0
			match wave:
				"square":
					s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				"sawtooth":
					s = fmod(phase, 1.0) * 2.0 - 1.0
				_:
					s = sin(phase * TAU)
			phase += inc
			data.encode_s16(idx * 2, int(clamp(s * env * vol, -1.0, 1.0) * 32767.0))
			idx += 1
	return _loop_wav(data)

func _tone(freq: float, dur: float, wave: String, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var inc := freq / MIX_RATE
	for i in n:
		var t := float(i) / float(n)
		var env: float = pow(0.0002, t)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"sawtooth":
				s = fmod(phase, 1.0) * 2.0 - 1.0
			_:
				s = sin(phase * TAU)
		phase += inc
		var v := int(clamp(s * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	return _wav(data)

## The rocket ignition swell — a deep sub tone plus brown-noise rumble that
## builds in over the first third of a second, with a sparse crackle layer
## (short random impulses) riding on top. The real signature of a rocket
## launch is that crackle — many small sharp pops rather than one smooth
## roar — so it's approximated here with randomised impulse bursts instead of
## a single tone.
func _rocket_ignition(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var brown := 0.0
	for i in n:
		var t := float(i) / float(n)
		var env: float = clampf(t / 0.3, 0.0, 1.0)
		var white := randf() * 2.0 - 1.0
		brown = (brown + white * 0.02) / 1.02
		var crackle := 0.0
		if randf() < 0.006:
			crackle = (randf() * 2.0 - 1.0) * (0.5 + env * 0.6)
		var sub: float = sin(TAU * 46.0 * (t * dur)) * 0.5
		var s := (brown * 3.0 + crackle + sub) * env
		data.encode_s16(i * 2, int(clamp(s * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)


## Continuous rocket-engine loop: brown noise (a leaky integrator over white
## noise, so it's weighted low like a real engine roar) plus the same sparse
## crackle layer as the ignition swell. Volume/pitch are driven live by
## rocket_engine_set() as thrust and altitude change.
func _rocket_rumble(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var brown := 0.0
	for i in n:
		var white := randf() * 2.0 - 1.0
		brown = (brown + white * 0.02) / 1.02
		var crackle := 0.0
		if randf() < 0.0035:
			crackle = (randf() * 2.0 - 1.0) * 0.9
		var s := brown * 3.2 + crackle
		data.encode_s16(i * 2, int(clamp(s * vol, -1.0, 1.0) * 32767.0))
	return _loop_wav(data)


## A soft, airy noise loop for the re-entry wind roar — lightly smoothed white
## noise, brighter/hissier than the rocket's brown-noise rumble so the two
## never get mistaken for each other.
func _wind_noise(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev := 0.0
	for i in n:
		var white := randf() * 2.0 - 1.0
		prev = prev * 0.55 + white * 0.45
		data.encode_s16(i * 2, int(clamp(prev * vol, -1.0, 1.0) * 32767.0))
	return _loop_wav(data)


## A smooth sci-fi engine whine for the spacecraft — two slightly detuned
## sine layers (a slow shimmering beat) plus a soft filtered-noise breath,
## brighter and more electric than the rocket's brown-noise rumble so the two
## engines never get mistaken for one another.
func _spacecraft_hum(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var phase_a := 0.0
	var phase_b := 0.0
	var f_a := 140.0
	var f_b := 141.6   # detuned a couple Hz sharp — a slow shimmering beat
	for i in n:
		phase_a += f_a / MIX_RATE
		phase_b += f_b / MIX_RATE
		var tone := (sin(phase_a * TAU) + sin(phase_b * TAU)) * 0.5
		var white := randf() * 2.0 - 1.0
		lp += (white - lp) * 0.08
		var s := tone * 0.75 + lp * 0.5
		data.encode_s16(i * 2, int(clamp(s * vol, -1.0, 1.0) * 32767.0))
	return _loop_wav(data)


func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var env := 1.0 - float(i) / float(n)
		var s := (randf() * 2.0 - 1.0) * env * vol
		data.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
	return _wav(data)


## The Iron Man hand repulsor — a short, punchy energy "pew" rather than a
## firearm crack. A bright sine whose pitch sweeps sharply downward (the
## charge-to-release snap) fattened with a detuned octave shimmer and a light
## ring-mod sparkle, under a hard exponential decay. Deliberately nothing like
## the recorded gunshot so a repulsor reads as a beam weapon.
func _repulsor(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := 300.0 + 1250.0 * pow(1.0 - t, 2.2)   # 1550 Hz -> 300 Hz sweep
		phase += f / MIX_RATE
		var body := sin(phase * TAU)
		var octave := 0.35 * sin(phase * TAU * 2.01)          # detuned = shimmer
		var sparkle := 0.16 * sin(phase * TAU * 5.0) * sin(t * 120.0)
		var env: float = pow(0.0008, t) * clampf(t / 0.012, 0.0, 1.0)
		var s := (body + octave + sparkle) * env
		data.encode_s16(i * 2, int(clamp(s * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)


## The shoulder missile launch — a low ignition "thunk" under a rising
## filtered-noise whoosh as the round clears the rail. Airier and lower than
## the repulsor's tight pew so the two suit weapons stay distinct.
func _missile_launch(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var white := randf() * 2.0 - 1.0
		lp = lp + (white - lp) * (0.05 + 0.5 * t)            # low-pass opens up
		var whoosh := lp * clampf(t / 0.05, 0.0, 1.0) * (1.0 - t)
		var thump: float = sin(TAU * (70.0 + 40.0 * (1.0 - t)) * (t * dur)) * pow(0.0004, t) * 0.8
		var s := whoosh * 1.5 + thump
		data.encode_s16(i * 2, int(clamp(s * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)


## Shared layered gunshot synth — every firearm's report is built from the
## same four ingredients, just re-tuned per weapon (see the _s_gun_* bakes in
## _ready()):
##   1. a very short broadband noise "snap" (the transient click of the
##      round leaving the barrel — real gunfire is mostly this, not a tone)
##   2. a sharp downward-sweeping tone under it (the "crack" — what turns a
##      noise burst into something that reads as a punch instead of a hiss)
##   3. a low sine "thump" for body/weight, decaying a little slower than the
##      crack so the heavier guns feel like they hit harder
##   4. a low-passed noise tail that trails off — short/near-absent for the
##      SMG's tight pop, long and heavy for the shotgun's boom
## This replaces the old flat single-tone "beep" placeholder with something
## that has an actual transient + body, the way a real gunshot does.
func _gunshot(dur: float, snap_amt: float, crack_freq0: float, crack_freq1: float,
		crack_amt: float, body_freq: float, body_amt: float, body_decay: float,
		tail_amt: float, tail_cut: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var tail_lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var snap_env: float = pow(0.0006, t / 0.05)
		var snap := (randf() * 2.0 - 1.0) * snap_env * snap_amt
		var cf: float = crack_freq1 + (crack_freq0 - crack_freq1) * pow(1.0 - t, 3.0)
		phase += cf / MIX_RATE
		var crack_env: float = pow(0.0008, t / 0.09)
		var crack := sin(phase * TAU) * crack_env * crack_amt
		var body_env: float = pow(0.001, t / body_decay)
		var body := sin(TAU * body_freq * (t * dur)) * body_env * body_amt
		var white := randf() * 2.0 - 1.0
		tail_lp += (white - tail_lp) * tail_cut
		var tail := tail_lp * (1.0 - t) * (1.0 - t) * tail_amt
		var s := snap + crack + body + tail
		data.encode_s16(i * 2, int(clamp(s * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)


## The RPG's launch — a heavier, more mechanical cousin of the suit's
## _missile_launch: a lower ignition thump under a bigger, slower-opening
## noise whoosh, sized for a shoulder-fired rocket rather than a wrist-mounted
## repeater.
func _rpg_launch(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var thump_env: float = pow(0.0008, t / 0.1)
		var thump: float = sin(TAU * 58.0 * (t * dur)) * thump_env * 0.9
		var white := randf() * 2.0 - 1.0
		lp += (white - lp) * 0.32
		var whoosh := lp * clampf(t / 0.08, 0.0, 1.0) * pow(1.0 - t, 1.5) * 1.2
		var s := thump + whoosh
		data.encode_s16(i * 2, int(clamp(s * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)


## A deep sub-bass boom + soft low-pass'd noise tail, layered under the
## recorded sniper sample (see shoot_sniper()) to give it more weight without
## touching the recording itself.
func _sniper_tail(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var env: float = pow(0.002, t / 0.6)
		var white := randf() * 2.0 - 1.0
		lp += (white - lp) * 0.15
		var sub := sin(TAU * 52.0 * (t * dur)) * env * 0.65
		var s := (lp * 0.8 + sub) * env
		data.encode_s16(i * 2, int(clamp(s * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = MIX_RATE
	st.stereo = false
	st.data = data
	return st

func _play(stream: AudioStreamWAV, db := 0.0) -> void:
	if _muted or stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = db
	p.play()

## Generic fallback report (the real recorded sample) — used by cops, guards
## and any caller that just wants "a gunshot" without picking a specific
## weapon (see gunshot() for the full per-weapon dispatch).
func shoot() -> void:
	_play(_s_gun, -3.0)


## The sniper's report — the recorded sample, layered with a synthesized deep
## sub-boom tail for extra weight (see _sniper_tail()).
func shoot_sniper() -> void:
	_play(_s_gun_sniper, -1.0)
	_play(_s_sniper_tail, -5.0)


## Per-weapon firing report — dispatches on WeaponDB.LIST's "name" field so
## every gun (PISTOL/REVOLVER/SMG/RIFLE/SHOTGUN/SNIPER/RPG) gets its own
## distinct, punchy sound instead of one shared beep. Melee weapons
## (FISTS/KNIFE) have no report and should never reach this — see
## _fire_weapon()'s `if w.sound:` guard in game.gd. Anything unrecognised
## falls back to the generic recorded shoot().
func gunshot(weapon_name: String) -> void:
	match weapon_name:
		"PISTOL":
			_play(_s_gun_pistol, -3.0)
		"REVOLVER":
			_play(_s_gun_revolver, -2.0)
		"SMG":
			_play(_s_gun_smg, -6.0)
		"RIFLE":
			_play(_s_gun_rifle, -2.0)
		"SHOTGUN":
			_play(_s_gun_shotgun, -1.0)
		"SNIPER":
			shoot_sniper()
		"RPG":
			_play(_s_gun_rpg, -2.0)
		_:
			shoot()


func repulsor() -> void:
	_play(_s_repulsor, -4.0)


func missile() -> void:
	_play(_s_missile, -2.0)

func hit() -> void:
	_play(_s_hit, -6.0)

func coin() -> void:
	_play(_s_coin_a)
	await get_tree().create_timer(0.05).timeout
	_play(_s_coin_b)

func explode() -> void:
	_play(_s_explode_noise, 2.0)
	_play(_s_explode_low, 0.0)

func siren() -> void:
	_play(_s_siren_a, -10.0)
	await get_tree().create_timer(0.15).timeout
	_play(_s_siren_b, -10.0)

func engine() -> void:
	_play(_tone(60.0 + randf() * 40.0, 0.05, "sawtooth", 0.25), -14.0)

## Engine note pitched by how fast the vehicle is going (0..1).
func engine_rev(frac: float) -> void:
	_play(_tone(72.0 + clampf(frac, 0.0, 1.0) * 205.0, 0.1, "sawtooth", 0.3), -13.0)

## One-shot deep-rumble-plus-crackle swell for the instant of liftoff.
func rocket_ignite() -> void:
	_play(_s_rocket_ignite, -2.0)

## Start the continuous ascent engine loop (idempotent — safe to call every
## frame while it should be running).
func rocket_engine_start() -> void:
	if not _muted and not _rocket_player.playing:
		_rocket_player.volume_db = -60.0
		_rocket_player.pitch_scale = 0.85
		_rocket_player.play()

## Track thrust (0..1) and an altitude fade (1 low down, fading to 0 in the
## thin/vacuum upper atmosphere) onto the running loop's volume and pitch.
func rocket_engine_set(thrust: float, fade: float) -> void:
	if not _rocket_player.playing:
		return
	var base_db: float = lerp(-34.0, -6.0, clampf(thrust, 0.0, 1.0))
	_rocket_player.volume_db = base_db - (1.0 - clampf(fade, 0.0, 1.0)) * 50.0
	_rocket_player.pitch_scale = 0.85 + thrust * 0.5

## Stop the engine loop — idempotent, so callers can invoke it every frame the
## engine should be silent without worrying about double-stopping.
func rocket_engine_stop() -> void:
	if _rocket_player.playing:
		_rocket_player.stop()

## Short hissy burst — the lunar lander's vernier thrusters (descent/ascent).
func thruster() -> void:
	_play(_noise(0.16, 0.55), -8.0)
	_play(_tone(360.0, 0.14, "sawtooth", 0.3), -14.0)

## Start the re-entry wind-roar loop (idempotent).
func wind_start() -> void:
	if not _muted and not _wind_player.playing:
		_wind_player.volume_db = -36.0
		_wind_player.pitch_scale = 0.8
		_wind_player.play()

## Track re-entry progress (0 at interface, 1 deep into the burn) onto the
## wind loop so it rises the way a real re-entry roar builds.
func wind_set(intensity: float) -> void:
	if not _wind_player.playing:
		return
	_wind_player.volume_db = lerp(-36.0, -3.0, clampf(intensity, 0.0, 1.0))
	_wind_player.pitch_scale = 0.8 + intensity * 0.6

## Stop the wind loop — idempotent.
func wind_stop() -> void:
	if _wind_player.playing:
		_wind_player.stop()

## Start the spacecraft's continuous engine loop (idempotent — safe to call
## every frame while it should be running, same convention as
## rocket_engine_start()).
func spacecraft_engine_start() -> void:
	if not _muted and not _spacecraft_player.playing:
		_spacecraft_player.volume_db = -60.0
		_spacecraft_player.pitch_scale = 0.9
		_spacecraft_player.play()

## Track thrust (0..1) and a fade (1 audible, fading to 0) onto the loop.
func spacecraft_engine_set(thrust: float, fade: float) -> void:
	if not _spacecraft_player.playing:
		return
	var base_db: float = lerp(-30.0, -6.0, clampf(thrust, 0.0, 1.0))
	_spacecraft_player.volume_db = base_db - (1.0 - clampf(fade, 0.0, 1.0)) * 50.0
	_spacecraft_player.pitch_scale = 0.9 + thrust * 0.8

## Stop the spacecraft's engine loop — idempotent.
func spacecraft_engine_stop() -> void:
	if _spacecraft_player.playing:
		_spacecraft_player.stop()

## Splashdown — a splash plus a low thump as the capsule settles.
func splash() -> void:
	_play(_noise(0.5, 0.75), -3.0)
	_play(_tone(200.0, 0.3, "sine", 0.4), -10.0)

## Start the looping city ambience (call once at game start).
func start_ambient() -> void:
	if not _ambient_player.playing:
		_ambient_player.play()

## Toggle the in-car radio loop.
func set_radio(on: bool) -> void:
	if on and not _radio_player.playing:
		_radio_player.play()
	elif not on and _radio_player.playing:
		_radio_player.stop()

func set_muted(v: bool) -> void:
	_muted = v
	if _ambient_player != null:
		_ambient_player.stream_paused = v
	if _radio_player != null:
		_radio_player.stream_paused = v
	if _rocket_player != null:
		_rocket_player.stream_paused = v
	if _wind_player != null:
		_wind_player.stream_paused = v
	if _spacecraft_player != null:
		_spacecraft_player.stream_paused = v

func is_muted() -> bool:
	return _muted
