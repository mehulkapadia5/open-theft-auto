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

# Pre-baked streams
var _s_shoot: AudioStreamWAV
var _s_shoot_noise: AudioStreamWAV
var _s_hit: AudioStreamWAV
var _s_coin_a: AudioStreamWAV
var _s_coin_b: AudioStreamWAV
var _s_explode_noise: AudioStreamWAV
var _s_explode_low: AudioStreamWAV
var _s_siren_a: AudioStreamWAV
var _s_siren_b: AudioStreamWAV
var _s_gun: AudioStreamWAV          # real recorded gunshot (CC0)
var _s_gun_sniper: AudioStreamWAV   # deeper boom for the sniper
var _s_rocket_ignite: AudioStreamWAV
var _s_rocket_loop: AudioStreamWAV
var _s_wind_loop: AudioStreamWAV

func _ready() -> void:
	for i in 20:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_s_shoot = _tone(880.0, 0.05, "square", 0.5)
	_s_shoot_noise = _noise(0.07, 0.55)
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

	# Real recorded gunfire (CC0, OpenGameArt "Free Firearm Sound Library").
	_s_gun = load("res://assets/audio/gunshot.wav")
	_s_gun_sniper = load("res://assets/audio/gunshot_sniper.wav")

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


func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var env := 1.0 - float(i) / float(n)
		var s := (randf() * 2.0 - 1.0) * env * vol
		data.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
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

func shoot() -> void:
	_play(_s_gun, -3.0)


func shoot_sniper() -> void:
	_play(_s_gun_sniper, -1.0)

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

func is_muted() -> bool:
	return _muted
