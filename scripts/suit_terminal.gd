class_name SuitTerminal
extends CanvasLayer
## Stark Industries — the Iron Man suit upgrade terminal.
##
## A single list view: the three suit tiers with their flight, repulsor and
## missile capability. The player always wears the best tier they own, so
## buying a tier jumps straight to it.

signal closed
signal purchased

const TEXT := Color("e8e6e0")
const DIM := Color("8c9bab")
const FAINT := Color(0.55, 0.57, 0.6)
const GOLD := Color("c2a05a")
const MONEY := Color("84a85f")
const BLUE := Color("6fd8ff")
const SCREEN_BG := Color(0.03, 0.04, 0.05, 0.98)
const PANEL_BG := Color(0.075, 0.085, 0.10, 1.0)
const ROW_BG := Color(0.11, 0.12, 0.14, 1.0)
const EDGE := Color(0.36, 0.56, 0.66, 0.5)

const W_NAME := 300
const W_CAPS := 470
const W_PRICE := 230

var _root: Control
var _list_cash: Label
var _rows: Array = []
var _open := false


func _ready() -> void:
	layer = 22
	_build()
	_root.visible = false
	Garage.updated.connect(_refresh)


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
	center.add_child(_build_list())


func _build_list() -> PanelContainer:
	var panel := _panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 9)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 30)
	col.add_child(head)
	var title := _lbl("STARK INDUSTRIES  ·  SUIT BAY", 30, BLUE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_list_cash = _stat_box(head, "CASH", MONEY)

	col.add_child(_rule())

	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 16)
	col.add_child(ch)
	ch.add_child(_cell("SUIT", W_NAME, FAINT, 12, HORIZONTAL_ALIGNMENT_LEFT))
	ch.add_child(_cell("CAPABILITIES", W_CAPS, FAINT, 12, HORIZONTAL_ALIGNMENT_LEFT))
	ch.add_child(_cell("PRICE", W_PRICE, FAINT, 12, HORIZONTAL_ALIGNMENT_RIGHT))
	ch.add_child(_cell("", 168, FAINT, 12, HORIZONTAL_ALIGNMENT_CENTER))

	for i in SuitCatalog.LIST.size():
		col.add_child(_build_row(i))

	col.add_child(_rule())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 18)
	col.add_child(foot)
	var hint := _lbl("Your suit is delivered to the SUIT BAY pad outside — step onto it to suit up.",
		14, DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	var close_btn := _make_button("CLOSE  (E)", 150, TEXT)
	close_btn.pressed.connect(_close)
	foot.add_child(close_btn)
	return panel


func _build_row(idx: int) -> PanelContainer:
	var suit: Dictionary = SuitCatalog.LIST[idx]
	var wrap := PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = ROW_BG
	rsb.set_corner_radius_all(3)
	rsb.set_content_margin_all(9)
	rsb.content_margin_left = 14
	rsb.content_margin_right = 14
	wrap.add_theme_stylebox_override("panel", rsb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	wrap.add_child(row)

	row.add_child(_cell(suit.name, W_NAME, TEXT, 21, HORIZONTAL_ALIGNMENT_LEFT))
	var caps := "Flight %d   ·   Repulsor %d   ·   %s" % [
		int(round(suit.fly_h)), int(round(suit.repulsor_dmg)),
		("Missiles online" if suit.has_missiles else "No missiles")]
	row.add_child(_cell(caps, W_CAPS, DIM, 15, HORIZONTAL_ALIGNMENT_LEFT))
	var price := _cell("", W_PRICE, GOLD, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(price)

	var act := _make_button("BUY", 168, MONEY)
	act.pressed.connect(_on_buy.bind(idx))
	row.add_child(act)

	_rows.append({"price": price, "act": act})
	return wrap


# ---------------- Navigation ----------------
func open() -> void:
	_open = true
	_root.visible = true
	_refresh()
	UiNav.apply.call_deferred(_root)


func _close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	closed.emit()


func _on_buy(idx: int) -> void:
	# idx is the catalog index; tier is idx + 1.
	if Garage.buy_suit(idx + 1):
		AudioFX.coin()
		purchased.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventJoypadButton and event.pressed \
		and event.button_index == JOY_BUTTON_B:
		_close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			_close()
			get_viewport().set_input_as_handled()


# ---------------- Refresh ----------------
func _refresh() -> void:
	if not _open:
		return
	_list_cash.text = "$" + _commas(GameState.money)
	for i in _rows.size():
		var suit: Dictionary = SuitCatalog.LIST[i]
		var r: Dictionary = _rows[i]
		var tier := i + 1
		if tier == Garage.suit_tier:
			r.price.text = "EQUIPPED"
			r.price.add_theme_color_override("font_color", BLUE)
			r.act.text = "WORN"
			r.act.add_theme_color_override("font_color", BLUE)
			r.act.disabled = true
		elif tier < Garage.suit_tier:
			r.price.text = "OWNED"
			r.price.add_theme_color_override("font_color", MONEY)
			r.act.text = "OWNED"
			r.act.add_theme_color_override("font_color", DIM)
			r.act.disabled = true
		else:
			r.price.text = "$" + _commas(suit.price)
			r.price.add_theme_color_override("font_color", GOLD)
			r.act.text = "BUY"
			r.act.add_theme_color_override("font_color", MONEY)
			r.act.disabled = GameState.money < suit.price


# ---------------- Helpers ----------------
func _commas(n: int) -> String:
	var neg := n < 0
	var digits := str(absi(n))
	var out := ""
	var c := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if neg else out


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = PANEL_BG
	psb.border_color = EDGE
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(4)
	psb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", psb)
	return panel


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = EDGE
	r.custom_minimum_size = Vector2(0, 1)
	return r


func _stat_box(parent: HBoxContainer, caption: String, value_color: Color) -> Label:
	var box := VBoxContainer.new()
	var cap := _lbl(caption, 11, FAINT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(cap)
	var val := _lbl("$0", 25, value_color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(val)
	parent.add_child(box)
	return val


func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _cell(text: String, width: int, color: Color, size: int,
		halign: int) -> Label:
	var l := _lbl(text, size, color)
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = halign
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _make_button(text: String, width: int, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 42)
	b.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.15, 0.17)
	normal.border_color = color
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.21, 0.23, 0.26)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.10, 0.10, 0.12)
	disabled.border_color = Color(0.3, 0.3, 0.33)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.43))
	return b
