class_name TouchHUD
extends CanvasLayer
## On-screen touch controls for mobile builds. Instantiated by game.gd only when
## `OS.has_feature("mobile")` is true, so desktop play is completely untouched.
##
## Each frame the game polls `stick`, `sprint_held`, `fire_held`, and
## `consume_look_rel()`. Tap buttons emit `action(name)` — game.gd routes the
## name back into the existing `_handle_action` path so the rest of the game
## doesn't know touch exists.

signal action(name: StringName)   # "interact" (E), "suit" (F), "summon" (V)

# --- State the game reads every frame. -------------------------------------
var stick: Vector2 = Vector2.ZERO       # move axes [-1,1]; +y = forward
var look_rel: Vector2 = Vector2.ZERO    # consumed by the game each frame
var sprint_held: bool = false           # true when the stick is fully pushed
var fire_held: bool = false             # while a finger is on the FIRE button

# --- Layout / feel ---------------------------------------------------------
const STICK_RADIUS := 110.0             # max knob travel from origin (pixels)
const LOOK_SENS := 0.55                 # touch-drag → mouse-rel scale
const BUTTON_RADIUS := 60.0             # action buttons (E/F/V)
const FIRE_RADIUS := 84.0               # primary fire button
const SPRINT_THRESHOLD := 0.85          # stick magnitude that triggers sprint

# --- Touch tracking --------------------------------------------------------
var _stick_touch := -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_knob: Vector2 = Vector2.ZERO
var _look_touch := -1
var _fire_touch := -1

# --- Button hit-centres (recomputed in _resize on viewport change) ----------
var _btn_fire: Vector2 = Vector2.ZERO
var _btn_e: Vector2 = Vector2.ZERO
var _btn_f: Vector2 = Vector2.ZERO
var _btn_v: Vector2 = Vector2.ZERO

var _pad: Control                       # full-viewport overlay that draws


## Inner Control used purely for drawing. Mouse filter is IGNORE so it never
## blocks input — _input on the CanvasLayer handles screen-touch events.
class TouchPad extends Control:
	var hud
	func _draw() -> void:
		if hud != null:
			hud._draw_overlay(self)


func _ready() -> void:
	layer = 30
	_pad = TouchPad.new()
	_pad.hud = self
	_pad.anchor_right = 1.0
	_pad.anchor_bottom = 1.0
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)
	get_viewport().size_changed.connect(_resize)
	_resize()


func _process(_dt: float) -> void:
	# Hide (and stop swallowing touches) while a terminal/phone overlay is up,
	# so the buttons in those screens get the taps instead.
	var want := GameState.started and not GameState.paused
	if visible and not want:
		_clear_touches()   # a finger-lift while hidden would never reach _input
	visible = want


## Forget every live touch — otherwise a hold that started before the HUD hid
## (FIRE, the move stick) latches on until that control is pressed again.
func _clear_touches() -> void:
	_stick_touch = -1
	_look_touch = -1
	_fire_touch = -1
	stick = Vector2.ZERO
	look_rel = Vector2.ZERO
	sprint_held = false
	fire_held = false
	_pad.queue_redraw()


func _resize() -> void:
	var sz := get_viewport().get_visible_rect().size
	_btn_fire = Vector2(sz.x - 150.0, sz.y - 150.0)
	_btn_e    = Vector2(sz.x - 150.0, sz.y - 360.0)
	_btn_f    = Vector2(sz.x - 320.0, sz.y - 300.0)
	_btn_v    = Vector2(sz.x - 320.0, sz.y - 460.0)
	_pad.queue_redraw()


## Returns the accumulated look delta and resets it. Called by the game once
## per frame in place of mouse-relative motion.
func consume_look_rel() -> Vector2:
	var r := look_rel
	look_rel = Vector2.ZERO
	return r


# ---------------- Input dispatch -------------------------------------------
func _input(event: InputEvent) -> void:
	if not visible:
		# Still honour finger-lifts so no touch stays latched across a hide.
		if event is InputEventScreenTouch and not event.pressed:
			_release(event.index)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position, event.relative)


func _press(idx: int, pos: Vector2) -> void:
	# Buttons first — a touch on a button isn't move/look.
	if pos.distance_to(_btn_fire) < FIRE_RADIUS:
		fire_held = true
		_fire_touch = idx
		_pad.queue_redraw()
		return
	if pos.distance_to(_btn_e) < BUTTON_RADIUS:
		action.emit(&"interact"); return
	if pos.distance_to(_btn_f) < BUTTON_RADIUS:
		action.emit(&"suit"); return
	if pos.distance_to(_btn_v) < BUTTON_RADIUS:
		action.emit(&"summon"); return
	# Left half of the screen → movement joystick spawns at the touch point.
	var sz := get_viewport().get_visible_rect().size
	if pos.x < sz.x * 0.5 and _stick_touch < 0:
		_stick_touch = idx
		_stick_origin = pos
		_stick_knob = pos
		_pad.queue_redraw()
		return
	# Otherwise it's a camera-look drag.
	if _look_touch < 0:
		_look_touch = idx


func _release(idx: int) -> void:
	if idx == _fire_touch:
		fire_held = false
		_fire_touch = -1
		_pad.queue_redraw()
	if idx == _stick_touch:
		_stick_touch = -1
		stick = Vector2.ZERO
		sprint_held = false
		_pad.queue_redraw()
	if idx == _look_touch:
		_look_touch = -1


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	if idx == _stick_touch:
		var delta := pos - _stick_origin
		if delta.length() > STICK_RADIUS:
			delta = delta.normalized() * STICK_RADIUS
		_stick_knob = _stick_origin + delta
		# Screen-Y grows downward — invert so pushing up = forward.
		stick = Vector2(delta.x / STICK_RADIUS, -delta.y / STICK_RADIUS)
		sprint_held = stick.length() > SPRINT_THRESHOLD
		_pad.queue_redraw()
	elif idx == _look_touch:
		look_rel += rel * LOOK_SENS


# ---------------- Drawing --------------------------------------------------
func _draw_overlay(pad: Control) -> void:
	# Movement joystick — only drawn while a finger is on it.
	if _stick_touch >= 0:
		pad.draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.10))
		pad.draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 48,
			Color(1, 1, 1, 0.35), 2.0)
		pad.draw_circle(_stick_knob, 36.0, Color(0.5, 0.95, 0.8, 0.85))
	# Action buttons.
	_draw_button(pad, _btn_fire, FIRE_RADIUS, "FIRE",
		Color(0.95, 0.3, 0.25), fire_held)
	_draw_button(pad, _btn_e, BUTTON_RADIUS, "E",
		Color(0.4, 0.85, 0.6), false)
	_draw_button(pad, _btn_f, BUTTON_RADIUS, "F",
		Color(0.95, 0.8, 0.35), false)
	_draw_button(pad, _btn_v, BUTTON_RADIUS, "V",
		Color(0.45, 0.8, 0.95), false)


func _draw_button(pad: Control, c: Vector2, r: float, label: String,
		col: Color, pressed: bool) -> void:
	var fill := Color(col.r, col.g, col.b, 0.85 if pressed else 0.55)
	pad.draw_circle(c, r, fill)
	pad.draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 2.0)
	var font := ThemeDB.fallback_font
	var fs := 26
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1.0, fs)
	pad.draw_string(font, c - size * 0.5 + Vector2(0, fs * 0.35), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(1, 1, 1, 0.95))
