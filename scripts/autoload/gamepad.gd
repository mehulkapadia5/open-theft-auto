extends Node
## PlayStation (DualSense / DualShock) controller support + haptics.
##
## Centralizes everything pad-related so the rest of the game has one
## device-agnostic read path: deadzoned sticks/triggers, button polling, and a
## layered rumble "engine" for real-feel haptics. The active pad is auto-picked
## from the first connected joypad and re-picked on connect/disconnect.
##
## Rumble model — every frame we recompute the desired vibration from a
## continuous BASE (the engine channel, re-set each frame by the driving code)
## plus any number of decaying one-shot PULSES (gunfire, hits, explosions...).
## The strongest of all layers wins on each motor, and we re-issue the OS
## vibration every frame so it sustains and modulates smoothly. The DualSense
## maps Godot's "weak" magnitude to the high-frequency motor and "strong" to the
## low-frequency motor, so weak == buzzy/textured, strong == deep thud.

signal pad_changed(connected: bool)

const STICK_DEADZONE := 0.18
const TRIGGER_DEADZONE := 0.06
const VIBRATION_REFRESH := 0.15   # > one frame, so per-frame re-issues sustain

var device: int = -1              # active pad id, -1 when none connected
var is_playstation := false
var pad_name := ""
var haptics_enabled := true

# Layered rumble state.
var _base_weak := 0.0
var _base_strong := 0.0
var _pulses: Array = []           # each: {weak, strong, t, dur}
var _emitting := false


func _ready() -> void:
	# Keep ticking regardless of the game's own pause flag so rumble can decay
	# and stop cleanly even while a menu is up.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_connection_changed)
	_pick_device()


func _on_connection_changed(_dev: int, _connected: bool) -> void:
	_pick_device()


## Adopt the first connected joypad; drop to -1 when none remain.
func _pick_device() -> void:
	var pads := Input.get_connected_joypads()
	var new_dev: int = pads[0] if pads.size() > 0 else -1
	if new_dev == device:
		return
	if device >= 0:
		Input.stop_joy_vibration(device)
	device = new_dev
	if device >= 0:
		pad_name = Input.get_joy_name(device)
		is_playstation = _looks_playstation(pad_name)
	else:
		pad_name = ""
		is_playstation = false
	pad_changed.emit(device >= 0)


func connected() -> bool:
	return device >= 0


func _looks_playstation(n: String) -> bool:
	var s := n.to_lower()
	for tag in ["dualsense", "dualshock", "playstation", "ps5", "ps4", "ps3",
			"sony", "wireless controller"]:
		if s.contains(tag):
			return true
	return false


# =====================================================================
# Reads (deadzoned, normalized)
# =====================================================================
func _dz_axis(v: float) -> float:
	# Radial-ish per-axis deadzone with a smooth rescale past the threshold so
	# motion eases in from zero instead of snapping.
	var a := absf(v)
	if a < STICK_DEADZONE:
		return 0.0
	return signf(v) * (a - STICK_DEADZONE) / (1.0 - STICK_DEADZONE)


func _dz_trigger(v: float) -> float:
	if v < TRIGGER_DEADZONE:
		return 0.0
	return (v - TRIGGER_DEADZONE) / (1.0 - TRIGGER_DEADZONE)


## Left stick — x: strafe/steer (+right), y: +down (forward is negative).
func move() -> Vector2:
	if device < 0:
		return Vector2.ZERO
	return Vector2(
		_dz_axis(Input.get_joy_axis(device, JOY_AXIS_LEFT_X)),
		_dz_axis(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)))


## Right stick — camera look.
func look() -> Vector2:
	if device < 0:
		return Vector2.ZERO
	return Vector2(
		_dz_axis(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)),
		_dz_axis(Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)))


func trigger_left() -> float:   # L2 (0..1)
	if device < 0:
		return 0.0
	return _dz_trigger(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT))


func trigger_right() -> float:  # R2 (0..1)
	if device < 0:
		return 0.0
	return _dz_trigger(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT))


func pressed(button: int) -> bool:
	return device >= 0 and Input.is_joy_button_pressed(device, button)


# =====================================================================
# Haptics
# =====================================================================
func set_haptics(on: bool) -> void:
	haptics_enabled = on
	if not on and device >= 0:
		Input.stop_joy_vibration(device)


## Continuous base rumble for the current frame (engine/thrusters). Must be
## re-called every frame it should persist — it auto-clears otherwise.
func set_engine(weak: float, strong: float) -> void:
	_base_weak = maxf(_base_weak, clampf(weak, 0.0, 1.0))
	_base_strong = maxf(_base_strong, clampf(strong, 0.0, 1.0))


## One-shot transient that linearly decays to zero over `dur` seconds.
func pulse(weak: float, strong: float, dur: float) -> void:
	if not haptics_enabled or device < 0 or dur <= 0.0:
		return
	_pulses.append({
		"weak": clampf(weak, 0.0, 1.0),
		"strong": clampf(strong, 0.0, 1.0),
		"t": dur, "dur": dur,
	})


func _process(delta: float) -> void:
	if device < 0:
		return

	var weak := _base_weak
	var strong := _base_strong
	# The base is re-set each frame by whoever wants it; clear it now so it
	# decays the instant they stop calling set_engine().
	_base_weak = 0.0
	_base_strong = 0.0

	var kept: Array = []
	for p in _pulses:
		p.t -= delta
		if p.t <= 0.0:
			continue
		var k: float = p.t / p.dur            # 1 -> 0 envelope
		weak = maxf(weak, p.weak * k)
		strong = maxf(strong, p.strong * k)
		kept.append(p)
	_pulses = kept

	if not haptics_enabled:
		weak = 0.0
		strong = 0.0

	if weak <= 0.001 and strong <= 0.001:
		if _emitting:
			Input.stop_joy_vibration(device)
			_emitting = false
		return

	# Re-issue every frame so the vibration sustains and tracks the envelope.
	Input.start_joy_vibration(device, weak, strong, VIBRATION_REFRESH)
	_emitting = true
