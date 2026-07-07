class_name PauseMenu
extends CanvasLayer
## Escape / pad-Start pause menu — resume, rebindable controls (diagrammatic
## keyboard+mouse or controller view), or exit to desktop.
##
## Mirrors the kiosk terminals / Phone for styling and input conventions:
## opened by game.gd (which owns the "when is it allowed" gate), closes itself
## via _unhandled_input the same way Phone/StockTerminal do, so an Escape that
## opens the menu can't also close it again on the very same frame.

signal resumed
signal exit_requested

const TEXT := Color("e8e6e0")
const DIM := Color("8c9bab")
const FAINT := Color(0.55, 0.57, 0.6)
const GOLD := Color("c2a05a")
const DANGER := Color("c8534a")
const PANEL_BG := Color(0.075, 0.085, 0.10, 1.0)
const EDGE := Color(0.42, 0.62, 0.55, 0.5)
const CHIP_BG := Color(0.16, 0.17, 0.20)
const CHIP_BORDER := Color(0.40, 0.43, 0.48)
const CAPTURE_COLOR := Color("6fd4c6")

var _root: Control
var _pause_view: Control
var _controls_view: Control
var _kb_view: Control
var _pad_view: GamepadDiagram
var _tab_kb: Button
var _tab_pad: Button

var _open := false
var _view := "pause"          # pause | controls
var _device_tab := "kb"       # kb | pad

var _capturing := false
var _capture_action := ""
var _capture_device := ""
var _capture_btn: Button
var _capture_tween: Tween

var _kb_chips := {}           # action name -> Button


func _ready() -> void:
	layer = 30
	_build()
	_root.visible = false
	InputConfig.changed.connect(func() -> void:
		if _open and _view == "controls":
			_refresh_controls())


func is_open() -> bool:
	return _open


## Opened by game.gd on Escape / pad Start while actually playing.
func open() -> void:
	if _open:
		return
	_cancel_capture()
	_open = true
	_device_tab = InputConfig.preferred_device()
	_root.visible = true
	_show_pause_root()


func _close_resume() -> void:
	if not _open:
		return
	_cancel_capture()
	_open = false
	_root.visible = false
	resumed.emit()


func _exit_game() -> void:
	SaveGame.save_now()
	get_tree().quit()


# =====================================================================
# Navigation
# =====================================================================
func _show_pause_root() -> void:
	_view = "pause"
	_controls_view.visible = false
	_pause_view.visible = true
	UiNav.apply.call_deferred(_pause_view)


func _open_controls() -> void:
	_view = "controls"
	_pause_view.visible = false
	_controls_view.visible = true
	_refresh_controls()
	UiNav.apply.call_deferred(_controls_view)


func _back() -> void:
	if _capturing:
		_cancel_capture()
	elif _view == "controls":
		_show_pause_root()
	else:
		_close_resume()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if _capturing:
		_try_capture(event)
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		_back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_back()
		get_viewport().set_input_as_handled()


# =====================================================================
# Rebind capture
# =====================================================================
func _start_capture(action: String, device: String, btn: Button) -> void:
	if _capturing:
		_cancel_capture()
	_capturing = true
	_capture_action = action
	_capture_device = device
	_capture_btn = btn
	btn.text = "PRESS A KEY..." if device == "kb" else "PRESS A BUTTON..."
	btn.add_theme_color_override("font_color", CAPTURE_COLOR)
	_capture_tween = create_tween().set_loops()
	_capture_tween.tween_property(btn, "modulate:a", 0.35, 0.45)
	_capture_tween.tween_property(btn, "modulate:a", 1.0, 0.45)


func _cancel_capture() -> void:
	if not _capturing:
		return
	_capturing = false
	if _capture_tween != null and _capture_tween.is_valid():
		_capture_tween.kill()
	if _capture_btn != null and is_instance_valid(_capture_btn):
		_capture_btn.modulate.a = 1.0
	_capture_btn = null
	_refresh_controls()


func _try_capture(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel_capture()
			get_viewport().set_input_as_handled()
			return
		if _capture_device == "kb":
			var ek := InputEventKey.new()
			ek.physical_keycode = event.physical_keycode
			InputConfig.rebind(_capture_action, "kb", ek)
			_finish_capture()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and _capture_device == "kb":
		var em := InputEventMouseButton.new()
		em.button_index = event.button_index
		InputConfig.rebind(_capture_action, "kb", em)
		_finish_capture()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and _capture_device == "pad":
		var ej := InputEventJoypadButton.new()
		ej.button_index = event.button_index
		InputConfig.rebind(_capture_action, "pad", ej)
		_finish_capture()
		get_viewport().set_input_as_handled()


func _finish_capture() -> void:
	_capturing = false
	if _capture_tween != null and _capture_tween.is_valid():
		_capture_tween.kill()
	if _capture_btn != null and is_instance_valid(_capture_btn):
		_capture_btn.modulate.a = 1.0
	_capture_btn = null
	_refresh_controls()


# =====================================================================
# Build — pause root
# =====================================================================
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.55)
	_root.add_child(backdrop)

	_pause_view = _build_pause_root()
	_root.add_child(_pause_view)

	_controls_view = _build_controls_view()
	_controls_view.visible = false
	_root.add_child(_controls_view)


func _build_pause_root() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(360, 0)
	panel.add_child(col)

	var title := _lbl("PAUSED", 34, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(_rule())

	var resume_btn := _menu_button("RESUME", TEXT)
	resume_btn.pressed.connect(_close_resume)
	col.add_child(resume_btn)

	var controls_btn := _menu_button("CONTROLS", TEXT)
	controls_btn.pressed.connect(_open_controls)
	col.add_child(controls_btn)

	col.add_child(_rule())
	var exit_btn := _menu_button("EXIT GAME", DANGER)
	exit_btn.pressed.connect(_exit_game)
	col.add_child(exit_btn)

	return center


# =====================================================================
# Build — controls screen
# =====================================================================
func _build_controls_view() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(940, 0)
	panel.add_child(col)

	var title := _lbl("CONTROLS", 28, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	_tab_kb = _menu_button("KEYBOARD & MOUSE", TEXT)
	_tab_kb.custom_minimum_size = Vector2(260, 38)
	_tab_kb.pressed.connect(func(): _set_device_tab("kb"))
	tabs.add_child(_tab_kb)
	_tab_pad = _menu_button("CONTROLLER", TEXT)
	_tab_pad.custom_minimum_size = Vector2(260, 38)
	_tab_pad.pressed.connect(func(): _set_device_tab("pad"))
	tabs.add_child(_tab_pad)
	col.add_child(tabs)
	col.add_child(_rule())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var scroll_inner := CenterContainer.new()
	scroll.add_child(scroll_inner)

	_kb_view = _build_kb_view()
	scroll_inner.add_child(_kb_view)

	_pad_view = GamepadDiagram.new()
	_pad_view.chip_pressed.connect(_on_pad_chip_pressed)
	_pad_view.visible = false
	scroll_inner.add_child(_pad_view)

	col.add_child(_rule())
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	var reset_btn := _menu_button("RESET TO DEFAULTS", DANGER)
	reset_btn.custom_minimum_size = Vector2(260, 40)
	reset_btn.pressed.connect(_on_reset_defaults)
	bottom.add_child(reset_btn)
	var back_btn := _menu_button("BACK", DIM)
	back_btn.custom_minimum_size = Vector2(180, 40)
	back_btn.pressed.connect(_show_pause_root)
	bottom.add_child(back_btn)
	col.add_child(bottom)

	return root


func _build_kb_view() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.custom_minimum_size = Vector2(860, 0)
	for group in InputConfig.GROUP_ORDER:
		var actions: Array = InputConfig.actions_in_group(group)
		if actions.is_empty():
			continue
		col.add_child(_section_label(group))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 30)
		grid.add_theme_constant_override("v_separation", 8)
		for a in actions:
			var lbl := _lbl(a.label, 15, TEXT)
			lbl.custom_minimum_size = Vector2(300, 38)
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			grid.add_child(lbl)
			var chip := _make_chip("")
			chip.pressed.connect(_on_kb_chip_pressed.bind(a.name, chip))
			_kb_chips[a.name] = chip
			grid.add_child(chip)
		col.add_child(grid)
	return col


func _on_kb_chip_pressed(action: String, chip: Button) -> void:
	_start_capture(action, "kb", chip)


func _on_pad_chip_pressed(action: String) -> void:
	var btn := _pad_view.get_button(action)
	if btn != null:
		_start_capture(action, "pad", btn)


func _on_reset_defaults() -> void:
	_cancel_capture()
	InputConfig.reset_defaults()
	_refresh_controls()


func _set_device_tab(tab: String) -> void:
	if _capturing:
		_cancel_capture()
	_device_tab = tab
	_refresh_controls()


func _refresh_controls() -> void:
	_kb_view.visible = (_device_tab == "kb")
	_pad_view.visible = (_device_tab == "pad")
	_tab_kb.add_theme_color_override("font_color", GOLD if _device_tab == "kb" else DIM)
	_tab_pad.add_theme_color_override("font_color", GOLD if _device_tab == "pad" else DIM)
	for action_name in _kb_chips:
		if _capturing and _capture_device == "kb" and _capture_action == action_name:
			continue
		var chip: Button = _kb_chips[action_name]
		chip.text = InputConfig.binding_text(action_name, "kb")
	_pad_view.refresh(_capturing, _capture_action if _capture_device == "pad" else "")
	UiNav.apply.call_deferred(_controls_view)


# =====================================================================
# Shared widget helpers (styled to match the kiosk terminals / Phone)
# =====================================================================
func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(26)
	return sb


func _section_label(text: String) -> Label:
	var l := _lbl(text.to_upper(), 13, FAINT)
	l.add_theme_constant_override("line_spacing", 4)
	return l


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = EDGE
	r.custom_minimum_size = Vector2(0, 1)
	return r


func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _menu_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 17)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.15, 0.17)
	normal.border_color = color
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.21, 0.23, 0.26)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	return b


## A keyboard "keycap" chip — a Button styled with a subtle 3D bevel (lighter
## top edge, soft drop shadow) so a row of bindings reads like a row of keys.
func _make_chip(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 40)
	b.add_theme_font_size_override("font_size", 15)

	var normal := StyleBoxFlat.new()
	normal.bg_color = CHIP_BG
	normal.border_color = CHIP_BORDER
	normal.set_border_width_all(2)
	normal.border_width_top = 3
	normal.set_corner_radius_all(6)
	normal.shadow_color = Color(0, 0, 0, 0.4)
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0, 2)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.22, 0.24, 0.28)

	var pressed_sb := normal.duplicate()
	pressed_sb.bg_color = Color(0.10, 0.11, 0.13)
	pressed_sb.border_width_top = 1
	pressed_sb.shadow_size = 1

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed_sb)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	return b


# =====================================================================
# Controller diagram — a drawn PS-style gamepad with callout labels.
# Non-rebindable analog inputs (sticks, triggers) show as fixed labels;
# rebindable pad buttons double as clickable callouts.
# =====================================================================
class GamepadDiagram extends Control:
	signal chip_pressed(action: String)

	const SIZE := Vector2(920, 300)
	const BODY_COLOR := Color(0.14, 0.15, 0.18)
	const BODY_EDGE := Color(0.32, 0.35, 0.4)
	const STICK_COLOR := Color(0.20, 0.22, 0.26)
	const STICK_EDGE := Color(0.45, 0.48, 0.54)
	const LINE_COLOR := Color(0.42, 0.62, 0.55, 0.55)
	const FIXED_COLOR := Color(0.55, 0.57, 0.6)
	const CAP_COLOR := Color("6fd4c6")

	# Diagram-space points for the drawn body parts.
	const P_LSTICK := Vector2(340, 210)
	const P_RSTICK := Vector2(575, 210)
	const P_DPAD := Vector2(340, 108)
	const P_TRIANGLE := Vector2(575, 78)
	const P_CIRCLE := Vector2(615, 112)
	const P_SQUARE := Vector2(535, 112)
	const P_CROSS := Vector2(575, 146)
	const P_L1 := Vector2(300, 26)
	const P_L2 := Vector2(300, 4)
	const P_R1 := Vector2(610, 26)
	const P_R2 := Vector2(610, 4)
	const P_SHARE := Vector2(410, 70)
	const P_START := Vector2(505, 70)

	# name -> {point, side, fixed, text/action}
	var _left_entries := []
	var _right_entries := []
	var _lines := []
	var _buttons := {}    # action -> Button


	func _ready() -> void:
		custom_minimum_size = SIZE
		_left_entries = [
			{"fixed": true, "text": "Brake / Reverse", "glyph": "L2", "point": P_L2},
			{"fixed": false, "action": "weapon_prev", "point": P_L1},
			{"fixed": false, "action": "phone", "point": P_SHARE},
			{"fixed": false, "action": "restock_respawn", "point": P_DPAD + Vector2(0, -14)},
			{"fixed": false, "action": "race_terminal", "point": P_DPAD + Vector2(0, 14)},
			{"fixed": true, "text": "Weapon Prev / Next", "glyph": "D-PAD ← →", "point": P_DPAD},
			{"fixed": true, "text": "Move / Steer", "glyph": "L STICK", "point": P_LSTICK},
			{"fixed": true, "text": "Sprint / Boost", "glyph": "✕", "point": P_LSTICK + Vector2(20, 40)},
		]
		_right_entries = [
			{"fixed": true, "text": "Accelerate", "glyph": "R2", "point": P_R2},
			{"fixed": false, "action": "weapon_next", "point": P_R1},
			{"fixed": true, "text": "Pause Menu", "glyph": "OPTIONS", "point": P_START},
			{"fixed": false, "action": "enter_exit", "point": P_TRIANGLE},
			{"fixed": false, "action": "summon_suit", "point": P_CIRCLE},
			{"fixed": false, "action": "interact", "point": P_SQUARE},
			{"fixed": true, "text": "Camera Look", "glyph": "R STICK", "point": P_RSTICK},
		]
		_build_widgets()
		queue_redraw()


	func _build_widgets() -> void:
		var y := 12.0
		for e in _left_entries:
			_add_entry(e, Vector2(10, y))
			y += 36.0
		y = 12.0
		for e in _right_entries:
			_add_entry(e, Vector2(690, y))
			y += 36.0


	func _add_entry(e: Dictionary, pos: Vector2) -> void:
		var line_start: Vector2
		if e.fixed:
			var lbl := Label.new()
			lbl.text = "%s   %s" % [e.glyph, e.text]
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", FIXED_COLOR)
			lbl.position = pos
			lbl.custom_minimum_size = Vector2(220, 30)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(lbl)
			line_start = pos + Vector2(110, 15)
		else:
			var btn := Button.new()
			btn.position = pos
			btn.custom_minimum_size = Vector2(220, 32)
			_style_button(btn)
			btn.pressed.connect(func(): chip_pressed.emit(e.action))
			add_child(btn)
			_buttons[e.action] = btn
			line_start = pos + Vector2(110, 16)
		_lines.append({"a": line_start, "b": e.point})


	func _style_button(b: Button) -> void:
		b.add_theme_font_size_override("font_size", 13)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.14, 0.15, 0.17)
		normal.border_color = Color(0.42, 0.62, 0.55, 0.7)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(4)
		var hover := normal.duplicate()
		hover.bg_color = Color(0.21, 0.23, 0.26)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_stylebox_override("focus", hover)
		b.add_theme_color_override("font_color", Color("e8e6e0"))
		b.add_theme_color_override("font_hover_color", Color("c2a05a"))


	func get_button(action: String) -> Button:
		return _buttons.get(action)


	## Re-pull binding text onto every callout; `capturing_action` (if not
	## empty) keeps that one button's "PRESS A BUTTON..." placeholder intact.
	func refresh(is_capturing: bool, capturing_action: String) -> void:
		for action in _buttons:
			if is_capturing and action == capturing_action:
				continue
			var btn: Button = _buttons[action]
			# Interact and Handbrake share Square by design (never overlap in
			# play — one's on foot at a kiosk, the other mid-drive).
			var label := "Interact / Handbrake" if action == "interact" else InputConfig.label_for(action)
			btn.text = "%s   %s" % [label, InputConfig.binding_text(action, "pad")]
		queue_redraw()


	func _draw() -> void:
		for l in _lines:
			draw_line(l.a, l.b, LINE_COLOR, 1.5)

		var body_sb := StyleBoxFlat.new()
		body_sb.bg_color = BODY_COLOR
		body_sb.border_color = BODY_EDGE
		body_sb.set_border_width_all(2)
		body_sb.set_corner_radius_all(48)
		draw_style_box(body_sb, Rect2(250, 40, 420, 220))

		var pill := StyleBoxFlat.new()
		pill.bg_color = Color(0.18, 0.19, 0.22)
		pill.border_color = BODY_EDGE
		pill.set_border_width_all(2)
		pill.set_corner_radius_all(9)
		draw_style_box(pill, Rect2(255, P_L2.y, 90, 18))
		draw_style_box(pill, Rect2(255, P_L1.y, 90, 18))
		draw_style_box(pill, Rect2(575, P_R2.y, 90, 18))
		draw_style_box(pill, Rect2(575, P_R1.y, 90, 18))

		draw_circle(P_LSTICK, 28, STICK_COLOR)
		draw_arc(P_LSTICK, 28, 0, TAU, 32, STICK_EDGE, 2.0)
		draw_circle(P_RSTICK, 28, STICK_COLOR)
		draw_arc(P_RSTICK, 28, 0, TAU, 32, STICK_EDGE, 2.0)

		draw_rect(Rect2(P_DPAD.x - 22, P_DPAD.y - 8, 44, 16), STICK_COLOR)
		draw_rect(Rect2(P_DPAD.x - 8, P_DPAD.y - 22, 16, 44), STICK_COLOR)

		draw_circle(P_TRIANGLE, 15, STICK_COLOR)
		draw_circle(P_CIRCLE, 15, STICK_COLOR)
		draw_circle(P_SQUARE, 15, STICK_COLOR)
		draw_circle(P_CROSS, 15, STICK_COLOR)
		_glyph(P_TRIANGLE, "△", Color("8fb4e6"))
		_glyph(P_CIRCLE, "○", Color("e68fa0"))
		_glyph(P_SQUARE, "□", Color("e6c88f"))
		_glyph(P_CROSS, "✕", Color("8fe6b0"))

		draw_circle(P_SHARE, 6, BODY_EDGE)
		draw_circle(P_START, 6, BODY_EDGE)


	func _glyph(p: Vector2, s: String, color: Color) -> void:
		var font := ThemeDB.fallback_font
		draw_string(font, p + Vector2(-7, 6), s, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, color)
