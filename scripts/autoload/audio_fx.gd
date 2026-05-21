extends Node
## Procedural sound effects — ports the Web Audio beep/noise logic from game.js.
## All sounds are synthesized at load time into AudioStreamWAV buffers.

const MIX_RATE := 22050

var _muted: bool = false
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _ambient_player: AudioStreamPlayer
var _radio_player: AudioStreamPlayer

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
	_play(_s_shoot, -4.0)
	_play(_s_shoot_noise, -8.0)

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

## A low rocket-launch rumble.
func rumble() -> void:
	_play(_noise(0.34, 0.8), -3.0)
	_play(_tone(46.0, 0.34, "sawtooth", 0.85), -3.0)

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

func is_muted() -> bool:
	return _muted
