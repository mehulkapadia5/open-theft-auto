class_name DonateTerminal
extends CanvasLayer
## Free Harbor General Hospital — the donation kiosk.
##
## A single panel: type (or chip-pick) a dollar amount, confirm, and it's
## deducted from cash and converted into Respect + Happiness with diminishing
## returns — a small gift barely moves the needle once you're already a saint,
## but even a modest gift matters a lot when you're a nobody.

signal closed

const TEXT := Color("e8e6e0")
const DIM := Color("8c9bab")
const FAINT := Color(0.55, 0.57, 0.6)
const GOLD := Color("c2a05a")
const MONEY := Color("84a85f")
const RED := Color("e0776c")
const SCREEN_BG := Color(0.03, 0.04, 0.05, 0.98)
const PANEL_BG := Color(0.075, 0.085, 0.10, 1.0)
const FIELD_BG := Color(0.04, 0.05, 0.06, 1.0)
const EDGE := Color(0.62, 0.42, 0.42, 0.5)

var _root: Control
var _open := false

var _cash_val: Label
var _respect_val: Label
var _happiness_val: Label
var _total_val: Label

var _input: LineEdit
var _quick: Array = []
var _preview: Label
var _result: Label
var _confirm: Button


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
	center.add_child(_build_panel())


func _build_panel() -> PanelContainer:
	var panel := _panel()
	panel.custom_minimum_size = Vector2(640, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(_lbl("FREE HARBOR GENERAL HOSPITAL", 26, RED))
	title_box.add_child(_lbl("Donate to lift the city", 14, DIM))
	head.add_child(title_box)
	_cash_val = _stat_box(head, "CASH", MONEY, "$0")
	col.add_child(_rule())

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 24)
	col.add_child(stats)
	_respect_val = _stat_box(stats, "RESPECT", GOLD, "0")
	_happiness_val = _stat_box(stats, "HAPPINESS", MONEY, "0")
	_total_val = _stat_box(stats, "TOTAL DONATED", TEXT, "$0")

	col.add_child(_rule())

	col.add_child(_lbl("DONATION AMOUNT  ($)", 12, FAINT))
	_input = LineEdit.new()
	_input.custom_minimum_size = Vector2(0, 44)
	_input.add_theme_font_size_override("font_size", 22)
	_input.add_theme_color_override("font_color", TEXT)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = FIELD_BG
	fsb.border_color = EDGE
	fsb.set_border_width_all(1)
	fsb.set_corner_radius_all(3)
	fsb.content_margin_left = 12
	fsb.content_margin_right = 12
	fsb.content_margin_top = 6
	fsb.content_margin_bottom = 6
	_input.add_theme_stylebox_override("normal", fsb)
	_input.add_theme_stylebox_override("focus", fsb)
	# Click-only focus: a gamepad's d-pad/stick navigation skips right over
	# this onto the quick chips and CLOSE/DONATE — there's no way to type a
	# dollar amount into a LineEdit with a controller.
	_input.focus_mode = Control.FOCUS_CLICK
	_input.text_changed.connect(func(_t: String) -> void: _refresh_preview())
	col.add_child(_input)

	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 8)
	col.add_child(quick)
	var labels := ["$1,000", "$10,000", "$100,000", "MAX"]
	for i in 4:
		var b := _make_button(labels[i], 148, GOLD)
		b.pressed.connect(_quick_fill.bind(i))
		quick.add_child(b)
		_quick.append(b)

	_preview = _lbl("", 15, DIM)
	col.add_child(_preview)
	col.add_child(_lbl("Gamepad: L1 / R1 adjust the amount by a coarse step", 12, FAINT))

	_result = _lbl("", 15, MONEY)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_result)

	col.add_child(_rule())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 18)
	col.add_child(foot)
	var hint := _lbl("Every gift lifts Respect and Happiness — big gifts matter most early on.",
		14, DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	var close_btn := _make_button("CLOSE  (E)", 150, TEXT)
	close_btn.pressed.connect(_close)
	foot.add_child(close_btn)
	_confirm = _make_button("DONATE", 160, MONEY)
	_confirm.pressed.connect(_confirm_donation)
	foot.add_child(_confirm)
	return panel


# ---------------- Navigation ----------------
func open() -> void:
	_open = true
	_root.visible = true
	_input.text = str(mini(1000, GameState.money))
	_result.text = ""
	_refresh()
	UiNav.apply.call_deferred(_root)


func _close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	closed.emit()


func _quick_fill(i: int) -> void:
	var amts := [1000, 10000, 100000, GameState.money]
	_input.text = str(amts[i])
	_refresh_preview()


func _confirm_donation() -> void:
	var amount := clampi(int(_num(_input.text)), 0, GameState.money)
	if amount <= 0:
		return
	GameState.money -= amount
	var rgain := _gain(amount, GameState.respect)
	var hgain := _gain(amount, GameState.happiness)
	GameState.add_respect(rgain)
	GameState.add_happiness(hgain)
	GameState.total_donated += amount
	AudioFX.coin()
	_result.text = _thank_you(amount) + "  (+%.1f Respect, +%.1f Happiness)" % [rgain, hgain]
	_refresh()


## Diminishing-returns gain curve: bigger gifts move the needle more (log
## scale, so the tenth million matters far less than the first), and every
## gift's effect tapers off again as the metric nears its 100 cap.
func _gain(amount: float, current: float) -> float:
	if amount <= 0.0:
		return 0.0
	var scale: float = log(1.0 + amount / 1000.0) * 1.8
	var headroom: float = clampf((100.0 - current) / 100.0, 0.0, 1.0)
	return scale * headroom


func _thank_you(amount: int) -> String:
	if amount >= 10_000_000:
		return "The board renames the east wing after you."
	if amount >= 1_000_000:
		return "A ribbon-cutting ceremony is held in your honor."
	if amount >= 100_000:
		return "The hospital board sends a personal thank-you."
	if amount >= 10_000:
		return "The nurses cheer as the check clears."
	return "Every dollar helps. Thank you."


## Coarse gamepad-only amount stepper (L1 down / R1 up) — see the matching
## helper in stock_terminal.gd for why this exists (the LineEdit itself is
## click-only, unreachable with a controller).
func _step_amount(dir: int) -> void:
	var cur := int(_num(_input.text))
	_input.text = str(clampi(cur + dir * _dollar_step(cur), 0, GameState.money))
	_refresh_preview()


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
			_step_amount(-1)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_step_amount(1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E and not _input.has_focus():
			_close()
			get_viewport().set_input_as_handled()


# ---------------- Refresh ----------------
func _refresh() -> void:
	if not _open:
		return
	_cash_val.text = "$" + _commas(GameState.money)
	_respect_val.text = str(int(round(GameState.respect))) + " / 100"
	_happiness_val.text = str(int(round(GameState.happiness))) + " / 100"
	_total_val.text = "$" + _commas(GameState.total_donated)
	_refresh_preview()


func _refresh_preview() -> void:
	if not _open:
		return
	var amount := clampi(int(_num(_input.text)), 0, GameState.money)
	var rgain := _gain(amount, GameState.respect)
	var hgain := _gain(amount, GameState.happiness)
	_preview.text = "Gives  +%.1f Respect   +%.1f Happiness" % [rgain, hgain]
	_confirm.disabled = amount <= 0


## Parse a typed amount, tolerating "1,500", "1 500" and "$100".
func _num(t: String) -> float:
	return t.replace(",", "").replace(" ", "").replace("_", "") \
		.replace("$", "").to_float()


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


func _stat_box(parent: HBoxContainer, caption: String, value_color: Color,
		initial := "0") -> Label:
	var box := VBoxContainer.new()
	var cap := _lbl(caption, 11, FAINT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(cap)
	var val := _lbl(initial, 21, value_color)
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
