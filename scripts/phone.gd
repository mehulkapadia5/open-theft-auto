class_name Phone
extends CanvasLayer
## The player's phone — a quick-action menu: call a vehicle, fast-travel to a
## landmark, or buy a service. Opened with P; pauses the game while open.

signal closed
signal action(id: String)

const TEXT := Color("e8e6e0")
const DIM := Color("8c9bab")
const FAINT := Color(0.55, 0.57, 0.6)
const GOLD := Color("c2a05a")
const SCREEN_BG := Color(0.03, 0.04, 0.05, 0.9)
const PANEL_BG := Color(0.075, 0.085, 0.10, 1.0)
const EDGE := Color(0.42, 0.62, 0.55, 0.5)

var _root: Control
var _open := false


func _ready() -> void:
	layer = 21
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var screen := ColorRect.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.color = SCREEN_BG
	_root.add_child(screen)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = PANEL_BG
	psb.border_color = EDGE
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(14)
	psb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	col.custom_minimum_size = Vector2(340, 0)
	panel.add_child(col)

	col.add_child(_lbl("PHONE", 28, GOLD))
	col.add_child(_rule())
	_section(col, "VEHICLES")
	_btn(col, "Call a Sports Car", "car_sports")
	_btn(col, "Call the Formula 1", "car_f1")
	_section(col, "FAST TRAVEL")
	_btn(col, "Airport", "tp_airport")
	_btn(col, "Stock Exchange", "tp_exchange")
	_btn(col, "Rocket Launch Pad", "tp_launch")
	_section(col, "SERVICES")
	_btn(col, "Full Heal + Ammo", "heal")
	_btn(col, "Bribe the Cops  ($50,000)", "bribe")
	col.add_child(_rule())
	var close := _make_button("CLOSE  (P)", DIM)
	close.pressed.connect(_close)
	col.add_child(close)


func _section(col: VBoxContainer, title: String) -> void:
	var l := _lbl(title, 12, FAINT)
	l.add_theme_constant_override("line_spacing", 6)
	col.add_child(l)


func _btn(col: VBoxContainer, text: String, id: String) -> void:
	var b := _make_button(text, TEXT)
	b.pressed.connect(func() -> void:
		action.emit(id)
		_close())
	col.add_child(b)


# ---------------- API ----------------
func open() -> void:
	_open = true
	_root.visible = true


func _close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			_close()
			get_viewport().set_input_as_handled()


# ---------------- Helpers ----------------
func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = EDGE
	r.custom_minimum_size = Vector2(0, 1)
	return r


func _make_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.15, 0.17)
	normal.border_color = color
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
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
