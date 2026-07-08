class_name RaceTerminal
extends CanvasLayer
## Grand Prix race-entry screen.
##
## The player picks a race length and stakes a bet of any size. Entering costs
## a fixed fee plus the bet; finishing on the podium pays the bet back with
## winnings. START is blocked unless the player can cover fee + bet.

signal closed
signal start_requested(laps: int, bet: int)

const TEXT := Color("e8e6e0")
const DIM := Color("8c9bab")
const FAINT := Color(0.55, 0.57, 0.6)
const GOLD := Color("c2a05a")
const MONEY := Color("84a85f")
const RED := Color("c8534a")
const SCREEN_BG := Color(0.03, 0.04, 0.05, 0.98)
const PANEL_BG := Color(0.075, 0.085, 0.10, 1.0)
const FIELD_BG := Color(0.04, 0.05, 0.06, 1.0)
const EDGE := Color(0.62, 0.55, 0.34, 0.5)

const LAP_CHOICES := [3, 5, 8]

var _root: Control
var _cash: Label
var _total: Label
var _result: Label
var _bet_input: LineEdit
var _lap_btns: Array = []
var _start_btn: Button
var _laps := 3
var _open := false


func _ready() -> void:
	layer = 24
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

	var panel := _panel()
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 30)
	col.add_child(head)
	var title := _lbl("GRAND PRIX  ·  RACE ENTRY", 30, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_cash = _stat(head, "YOUR CASH", MONEY)
	col.add_child(_rule())

	var fee := _lbl("ENTRY FEE   $%s   (non-refundable)" % _commas(RaceManager.ENTRY_FEE),
		16, DIM)
	col.add_child(fee)

	# Race length.
	col.add_child(_lbl("RACE LENGTH", 12, FAINT))
	var laprow := HBoxContainer.new()
	laprow.add_theme_constant_override("separation", 10)
	col.add_child(laprow)
	for i in LAP_CHOICES.size():
		var b := _make_button("%d LAPS" % LAP_CHOICES[i], 150, TEXT)
		b.pressed.connect(_pick_laps.bind(i))
		laprow.add_child(b)
		_lap_btns.append(b)

	# Bet.
	col.add_child(_lbl("YOUR BET  ($) — bet any amount", 12, FAINT))
	_bet_input = LineEdit.new()
	_bet_input.custom_minimum_size = Vector2(0, 44)
	_bet_input.add_theme_font_size_override("font_size", 22)
	_bet_input.add_theme_color_override("font_color", TEXT)
	_bet_input.placeholder_text = "amount to stake"
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = FIELD_BG
	fsb.border_color = EDGE
	fsb.set_border_width_all(1)
	fsb.set_corner_radius_all(3)
	fsb.content_margin_left = 12
	fsb.content_margin_right = 12
	fsb.content_margin_top = 6
	fsb.content_margin_bottom = 6
	_bet_input.add_theme_stylebox_override("normal", fsb)
	_bet_input.add_theme_stylebox_override("focus", fsb)
	# Click-only focus: a gamepad's d-pad/stick navigation skips right over
	# this onto the quick chips / lap picker / START — there's no way to type
	# a bet into a LineEdit with a controller.
	_bet_input.focus_mode = Control.FOCUS_CLICK
	_bet_input.text_changed.connect(func(_t: String) -> void: _refresh())
	col.add_child(_bet_input)
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 10)
	col.add_child(quick)
	for amt in [0, 100_000, 1_000_000, -1]:
		var lbl := "MAX" if amt < 0 else ("$" + _commas(amt))
		var b := _make_button(lbl, 158, GOLD)
		b.pressed.connect(_quick_bet.bind(amt))
		quick.add_child(b)
	col.add_child(_lbl("Gamepad: L1 / R1 adjust the bet by a coarse step", 12, FAINT))

	col.add_child(_lbl("Finish 1st: 10× bet   ·   2nd: 4×   ·   3rd: 2×   ·   else: lost",
		13, DIM))
	col.add_child(_rule())
	_total = _lbl("TOTAL TO ENTER   $0", 22, TEXT)
	col.add_child(_total)
	_result = _lbl("", 14, RED)
	col.add_child(_result)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	btns.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(btns)
	var cancel := _make_button("CANCEL", 160, DIM)
	cancel.pressed.connect(_close)
	btns.add_child(cancel)
	_start_btn = _make_button("START RACE", 240, MONEY)
	_start_btn.pressed.connect(_on_start)
	btns.add_child(_start_btn)


func open() -> void:
	_open = true
	_root.visible = true
	_bet_input.text = str(mini(100_000, GameState.money))
	_pick_laps(0)
	UiNav.apply.call_deferred(_root)


func _close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	closed.emit()


func _pick_laps(i: int) -> void:
	_laps = LAP_CHOICES[i]
	for k in _lap_btns.size():
		_lap_btns[k].add_theme_color_override("font_color", GOLD if k == i else TEXT)
	_refresh()


func _quick_bet(amt: int) -> void:
	if amt < 0:
		_bet_input.text = str(maxi(0, GameState.money - RaceManager.ENTRY_FEE))
	else:
		_bet_input.text = str(amt)
	_refresh()


func _bet_value() -> int:
	# Strip separators first — to_int() stops at the first non-digit, so a
	# typed "500,000" would silently become a $500 bet.
	var t := _bet_input.text.replace(",", "").replace(" ", "") \
		.replace("_", "").replace("$", "")
	return maxi(0, int(t.to_int()))


func _refresh() -> void:
	var bet := _bet_value()
	var total := RaceManager.ENTRY_FEE + bet
	_cash.text = "$" + _commas(GameState.money)
	_total.text = "TOTAL TO ENTER   $" + _commas(total)
	if total > GameState.money:
		_result.text = "Not enough cash — you need $%s." % _commas(total)
		_start_btn.disabled = true
	else:
		_result.text = ""
		_start_btn.disabled = false


func _on_start() -> void:
	var bet := _bet_value()
	if RaceManager.ENTRY_FEE + bet > GameState.money:
		return
	start_requested.emit(_laps, bet)
	_close()


## Coarse gamepad-only bet stepper (L1 down / R1 up) — see the matching
## helper in stock_terminal.gd for why this exists (the LineEdit itself is
## click-only, unreachable with a controller).
func _step_bet(dir: int) -> void:
	var cur := _bet_value()
	_bet_input.text = str(clampi(cur + dir * _dollar_step(cur), 0, GameState.money))
	_refresh()


func _dollar_step(current: int) -> int:
	if current < 1000:
		return 100
	if current < 10000:
		return 1000
	if current < 100000:
		return 10000
	if current < 1000000:
		return 100000
	return 1000000


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B:
			_close()
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_step_bet(-1)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_step_bet(1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()


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
	psb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", psb)
	return panel


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = EDGE
	r.custom_minimum_size = Vector2(0, 1)
	return r


func _stat(parent: HBoxContainer, caption: String, value_color: Color) -> Label:
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
