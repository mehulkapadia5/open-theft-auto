extends Node
## Procedural sound effects — ports the Web Audio beep/noise logic from game.js.
## All sounds are synthesized at load time into AudioStreamWAV buffers.

const MIX_RATE := 22050

var _muted: bool = false
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0

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

func set_muted(v: bool) -> void:
	_muted = v

func is_muted() -> bool:
	return _muted
