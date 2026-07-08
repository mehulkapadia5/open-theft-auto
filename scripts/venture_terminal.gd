class_name VentureTerminal
extends CanvasLayer
## Angel Ventures HQ — the deal-flow terminal for the Ventures autoload.
##
## A deal-flow list on the left (pick a startup), a founder pitch + ticket
## panel in the centre, and the player's live portfolio on the right — active
## holdings with a stage bar and P/L, closed deals below. Modeled on
## stock_terminal.gd's layout and chrome, not pixel-identical to the web
## original this was ported from.

signal closed

const TEXT := Color("e8e6e0")
const DIM := Color("8c9bab")
const FAINT := Color(0.55, 0.57, 0.6)
const UP := Color("5fb86a")
const DOWN := Color("c8534a")
const GOLD := Color("f0c975")
const MONEY := Color("84a85f")
const VIOLET := Color("b39dff")
const SCREEN_BG := Color(0.03, 0.04, 0.05, 0.98)
const PANEL_BG := Color(0.075, 0.075, 0.09, 1.0)
const ROW_BG := Color(0.11, 0.11, 0.14, 1.0)
const FIELD_BG := Color(0.04, 0.04, 0.06, 1.0)
const EDGE := Color(0.62, 0.55, 0.35, 0.5)

var _root: Control
var _open := false
var _sel := 0

# Header
var _cash_val: Label
var _pv_val: Label
var _real_val: Label

# Deal-flow list
var _deal_col: VBoxContainer
var _deal_rows: Array = []

# Main pane
var _m_title: Label
var _m_sector: Label
var _m_risk: Label
var _m_founder: Label
var _m_role: Label
var _m_thesis: Label
var _m_valuation: Label
var _m_raising: Label
var _m_equity: Label
var _m_traction: Label
var _neg_result: Label

# Ticket panel
var _o_input: LineEdit
var _o_quick: Array = []
var _o_result: Label
var _o_invest: Button

# Portfolio pane
var _port_col: VBoxContainer


func _ready() -> void:
	layer = 25
	_build()
	_root.visible = false
	Ventures.updated.connect(_refresh)


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
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	# ---- Header ----
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(_lbl("ANGEL VENTURES HQ", 28, GOLD))
	title_box.add_child(_lbl("Deal Flow · Founders Pitching", 14, DIM))
	head.add_child(title_box)
	_cash_val = _stat_box(head, "CASH", MONEY)
	_pv_val = _stat_box(head, "PORTFOLIO", TEXT)
	_real_val = _stat_box(head, "REALISED P/L", TEXT)
	col.add_child(_rule())

	# ---- Body: deal flow | main pane | portfolio ----
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	col.add_child(body)

	# Deal flow (left)
	var deal_wrap := VBoxContainer.new()
	deal_wrap.custom_minimum_size = Vector2(300, 0)
	deal_wrap.add_theme_constant_override("separation", 8)
	body.add_child(deal_wrap)
	deal_wrap.add_child(_lbl("DEAL FLOW", 12, FAINT))
	var deal_scroll := ScrollContainer.new()
	deal_scroll.custom_minimum_size = Vector2(300, 460)
	deal_wrap.add_child(deal_scroll)
	_deal_col = VBoxContainer.new()
	_deal_col.add_theme_constant_override("separation", 6)
	_deal_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deal_scroll.add_child(_deal_col)

	# Main pane (centre)
	var main_wrap := VBoxContainer.new()
	main_wrap.custom_minimum_size = Vector2(480, 0)
	main_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_wrap.add_theme_constant_override("separation", 10)
	body.add_child(main_wrap)

	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 12)
	main_wrap.add_child(mh)
	_m_title = _lbl("", 23, GOLD)
	_m_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(_m_title)
	_m_risk = _lbl("", 13, TEXT)
	mh.add_child(_m_risk)

	_m_sector = _lbl("", 13, DIM)
	main_wrap.add_child(_m_sector)

	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 10)
	main_wrap.add_child(fr)
	_m_founder = _lbl("", 17, TEXT)
	fr.add_child(_m_founder)
	_m_role = _lbl("", 13, DIM)
	fr.add_child(_m_role)

	_m_thesis = _lbl("", 15, Color(0.8, 0.8, 0.82))
	_m_thesis.autowrap_mode = TextServer.AUTOWRAP_WORD
	main_wrap.add_child(_m_thesis)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 18)
	main_wrap.add_child(stats)
	_m_valuation = _info_box(stats, "VALUATION")
	_m_raising = _info_box(stats, "RAISING")
	_m_equity = _info_box(stats, "EQUITY OFFERED")
	_m_traction = _info_box(stats, "TRACTION")

	var neg_row := HBoxContainer.new()
	neg_row.add_theme_constant_override("separation", 14)
	main_wrap.add_child(neg_row)
	var neg_btn := _make_button("NEGOTIATE", 160, VIOLET)
	neg_btn.pressed.connect(_on_negotiate)
	neg_row.add_child(neg_btn)
	_neg_result = _lbl("", 13, DIM)
	_neg_result.autowrap_mode = TextServer.AUTOWRAP_WORD
	_neg_result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	neg_row.add_child(_neg_result)

	main_wrap.add_child(_rule())

	main_wrap.add_child(_lbl("YOUR TICKET  ($)", 12, FAINT))
	_o_input = LineEdit.new()
	_o_input.custom_minimum_size = Vector2(0, 42)
	_o_input.add_theme_font_size_override("font_size", 20)
	_o_input.add_theme_color_override("font_color", TEXT)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = FIELD_BG
	fsb.border_color = EDGE
	fsb.set_border_width_all(1)
	fsb.set_corner_radius_all(3)
	fsb.content_margin_left = 12
	fsb.content_margin_right = 12
	fsb.content_margin_top = 6
	fsb.content_margin_bottom = 6
	_o_input.add_theme_stylebox_override("normal", fsb)
	_o_input.add_theme_stylebox_override("focus", fsb)
	# Click-only focus: a gamepad's d-pad/stick navigation skips right over
	# this onto the quick chips / NEGOTIATE / INVEST — there's no way to type
	# a ticket size into a LineEdit with a controller.
	_o_input.focus_mode = Control.FOCUS_CLICK
	_o_input.text_changed.connect(func(_t: String) -> void: _refresh_ticket())
	main_wrap.add_child(_o_input)

	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 8)
	main_wrap.add_child(quick)
	var labels := ["$100K", "$1M", "$5M", "MAX"]
	for i in 4:
		var b := _make_button(labels[i], 108, GOLD)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_quick_fill.bind(i))
		quick.add_child(b)
		_o_quick.append(b)

	_o_result = _lbl("", 14, DIM)
	main_wrap.add_child(_o_result)
	main_wrap.add_child(_lbl("Gamepad: L1 / R1 adjust the ticket by a coarse step", 11, FAINT))

	# The primary action — full-width and taller so it reads as the commit
	# button, not another preset chip.
	_o_invest = _make_button("INVEST", 120, MONEY)
	_o_invest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o_invest.custom_minimum_size = Vector2(0, 52)
	_o_invest.add_theme_font_size_override("font_size", 18)
	_o_invest.pressed.connect(_on_invest)
	main_wrap.add_child(_o_invest)

	# Portfolio (right)
	var port_wrap := VBoxContainer.new()
	port_wrap.custom_minimum_size = Vector2(300, 0)
	port_wrap.add_theme_constant_override("separation", 8)
	body.add_child(port_wrap)
	port_wrap.add_child(_lbl("YOUR PORTFOLIO", 12, FAINT))
	var port_scroll := ScrollContainer.new()
	port_scroll.custom_minimum_size = Vector2(300, 460)
	port_wrap.add_child(port_scroll)
	_port_col = VBoxContainer.new()
	_port_col.add_theme_constant_override("separation", 6)
	_port_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_scroll.add_child(_port_col)

	col.add_child(_rule())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 18)
	col.add_child(foot)
	var hint := _lbl(
		"Back a founder for a stake. Negotiate a bigger cheque for more equity — lowball and they may walk.",
		13, DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	var close_btn := _make_button("CLOSE  (E)", 150, TEXT)
	close_btn.pressed.connect(_close)
	foot.add_child(close_btn)
	return panel


# ---------------- Navigation ----------------
func open() -> void:
	_open = true
	_root.visible = true
	_sel = clampi(_sel, 0, maxi(Ventures.deals.size() - 1, 0))
	_o_input.text = str(clampi(1_000_000, Ventures.MIN_TICKET, maxi(GameState.money, Ventures.MIN_TICKET)))
	_neg_result.text = ""
	_refresh()
	UiNav.apply.call_deferred(_root)


func _close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	closed.emit()


func _select(idx: int) -> void:
	_sel = idx
	_neg_result.text = ""
	_refresh()


func _quick_fill(i: int) -> void:
	var amts := [100_000, 1_000_000, 5_000_000, GameState.money]
	_o_input.text = str(amts[i])
	_refresh_ticket()


func _on_negotiate() -> void:
	if Ventures.deals.is_empty():
		return
	var ticket := clampi(int(_num(_o_input.text)), 0, GameState.money)
	var res: Dictionary = Ventures.negotiate(_sel, ticket)
	match res.get("status", ""):
		"walked_away":
			_neg_result.text = "They walked away — that deal is off the board."
			_neg_result.add_theme_color_override("font_color", DOWN)
			_sel = clampi(_sel, 0, maxi(Ventures.deals.size() - 1, 0))
		"negotiating":
			_neg_result.text = "New terms: %.0f%% equity, valuation $%s." \
				% [res.equity, _commas(int(res.valuation))]
			_neg_result.add_theme_color_override("font_color", VIOLET)
		_:
			_neg_result.text = ""
	_refresh()


func _on_invest() -> void:
	var amount := clampi(int(_num(_o_input.text)), 0, GameState.money)
	if Ventures.invest(_sel, amount):
		AudioFX.coin()
		_neg_result.text = ""
	_refresh()


## Coarse gamepad-only ticket-size stepper (L1 down / R1 up) — see the
## matching helper in stock_terminal.gd for why this exists (the LineEdit
## itself is click-only, unreachable with a controller).
func _step_amount(dir: int) -> void:
	var cur := int(_num(_o_input.text))
	_o_input.text = str(clampi(cur + dir * _dollar_step(cur), 0, GameState.money))
	_refresh_ticket()


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
		elif event.keycode == KEY_E and not _o_input.has_focus():
			_close()
			get_viewport().set_input_as_handled()


# ---------------- Refresh ----------------
func _refresh() -> void:
	if not _open:
		return
	_cash_val.text = "$" + _commas(GameState.money)
	_pv_val.text = "$" + _commas(Ventures.portfolio_value())
	var real: int = Ventures.realised
	_real_val.text = ("+" if real >= 0 else "") + "$" + _commas(real)
	_real_val.add_theme_color_override("font_color", UP if real >= 0 else DOWN)

	_sel = clampi(_sel, 0, maxi(Ventures.deals.size() - 1, 0))
	_refresh_deal_list()
	_refresh_main()
	_refresh_ticket()
	_refresh_portfolio()


func _refresh_deal_list() -> void:
	for c in _deal_col.get_children():
		c.queue_free()
	_deal_rows.clear()
	for i in Ventures.deals.size():
		var d: Dictionary = Ventures.deals[i]
		var card := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = ROW_BG if i != _sel else Color(0.20, 0.17, 0.10, 1.0)
		csb.set_corner_radius_all(4)
		csb.set_border_width_all(1)
		csb.border_color = GOLD if i == _sel else Color(0, 0, 0, 0)
		csb.set_content_margin_all(9)
		card.add_theme_stylebox_override("panel", csb)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		card.add_child(row)
		var top_row := HBoxContainer.new()
		top_row.add_child(_lbl(String(d.emoji) + " " + String(d.company), 16, TEXT))
		row.add_child(top_row)
		row.add_child(_lbl(String(d.founder) + "  ·  " + String(d.sector), 12, DIM))
		var bot := HBoxContainer.new()
		bot.add_theme_constant_override("separation", 10)
		bot.add_child(_lbl("$" + _commas(int(d.ask)), 15, GOLD))
		bot.add_child(_lbl(String(d.risk).to_upper() + " RISK", 11, _risk_color(d.risk)))
		row.add_child(bot)

		card.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed \
				and e.button_index == MOUSE_BUTTON_LEFT:
				_select(i))
		_deal_col.add_child(card)
		_deal_rows.append(card)


func _refresh_main() -> void:
	if Ventures.deals.is_empty():
		_m_title.text = "No deals open right now."
		_m_sector.text = ""
		_m_risk.text = ""
		_m_founder.text = ""
		_m_role.text = ""
		_m_thesis.text = "New founders arrive shortly."
		_m_valuation.text = "--"
		_m_raising.text = "--"
		_m_equity.text = "--"
		_m_traction.text = "--"
		_o_invest.disabled = true
		return
	var d: Dictionary = Ventures.deals[_sel]
	_m_title.text = String(d.emoji) + "  " + String(d.company)
	_m_sector.text = String(d.sector)
	_m_risk.text = String(d.risk).to_upper() + " RISK"
	_m_risk.add_theme_color_override("font_color", _risk_color(d.risk))
	_m_founder.text = String(d.founder)
	_m_role.text = String(d.role)
	_m_thesis.text = "“" + String(d.thesis) + "”"
	_m_valuation.text = "$" + _commas(int(d.valuation))
	_m_raising.text = "$" + _commas(int(d.ask))
	var equity_txt := "%.0f%%" % d.equity
	if not is_equal_approx(float(d.equity), float(d.base_equity)):
		equity_txt += "  (was %.0f%%)" % d.base_equity
	_m_equity.text = equity_txt
	_m_traction.text = String(d.traction)


func _refresh_ticket() -> void:
	if Ventures.deals.is_empty():
		_o_result.text = ""
		_o_invest.disabled = true
		return
	var d: Dictionary = Ventures.deals[_sel]
	var amount := clampi(int(_num(_o_input.text)), 0, GameState.money)
	var stake_mult: float = d.equity / d.base_equity if d.base_equity > 0.0 else 1.0
	var stake_value: int = int(floor(float(amount) * stake_mult))
	if amount < Ventures.MIN_TICKET:
		_o_result.text = "Minimum ticket is $" + _commas(Ventures.MIN_TICKET)
	else:
		_o_result.text = "Ticket $%s  →  stake worth ≈ $%s at %.0f%% equity" \
			% [_commas(amount), _commas(stake_value), d.equity]
	_o_invest.disabled = amount < Ventures.MIN_TICKET or amount > GameState.money


func _refresh_portfolio() -> void:
	for c in _port_col.get_children():
		c.queue_free()

	var active: Array = []
	var closed: Array = []
	for p in Ventures.portfolio:
		if p.status == "active":
			active.append(p)
		else:
			closed.append(p)

	if active.is_empty() and closed.is_empty():
		_port_col.add_child(_lbl("No investments yet.\nBack a founder to build your portfolio.",
			13, DIM))
		return

	if not active.is_empty():
		_port_col.add_child(_lbl("ACTIVE · %d" % active.size(), 11, FAINT))
		for p in active:
			_port_col.add_child(_active_card(p))

	if not closed.is_empty():
		_port_col.add_child(_lbl("CLOSED · %d" % closed.size(), 11, FAINT))
		# Most recent first, capped so the panel doesn't grow forever.
		for i in range(closed.size() - 1, maxi(-1, closed.size() - 11), -1):
			_port_col.add_child(_closed_row(closed[i]))


func _active_card(p: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = ROW_BG
	csb.set_corner_radius_all(4)
	csb.set_content_margin_all(9)
	card.add_theme_stylebox_override("panel", csb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	card.add_child(col)

	var top := HBoxContainer.new()
	top.add_child(_lbl(String(p.emoji) + " " + String(p.company), 15, TEXT))
	var stage_lbl := _lbl(Ventures.STAGES[p.stage], 12, GOLD)
	stage_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(stage_lbl)
	col.add_child(top)

	col.add_child(_lbl(_stage_dots(p.stage), 12, GOLD))

	var pl: int = int(p.value) - int(p.invested)
	var pc: float = float(pl) / float(p.invested) * 100.0 if int(p.invested) > 0 else 0.0
	var mid := HBoxContainer.new()
	mid.add_child(_lbl("Invested $" + _commas(int(p.invested)), 12, DIM))
	col.add_child(mid)
	var pl_lbl := _lbl(("+" if pl >= 0 else "") + "$" + _commas(pl) +
		"  (" + ("+" if pc >= 0.0 else "") + ("%.0f" % pc) + "%)   ·  worth $" +
		_commas(int(p.value)), 12, UP if pl >= 0 else DOWN)
	col.add_child(pl_lbl)
	return card


func _closed_row(p: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_lbl(String(p.emoji) + " " + String(p.company), 12, DIM))
	var tail := Label.new()
	tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if p.status == "exited":
		var payout: int = int(p.get("payout", p.value))
		tail.text = "Exited +$" + _commas(payout - int(p.invested))
		tail.add_theme_color_override("font_color", UP)
	else:
		tail.text = "Failed -$" + _commas(int(p.invested))
		tail.add_theme_color_override("font_color", DOWN)
	tail.add_theme_font_size_override("font_size", 12)
	row.add_child(tail)
	return row


func _stage_dots(stage: int) -> String:
	var s := ""
	for i in 5:
		s += "●" if i <= stage else "○"
	return s


func _risk_color(risk: String) -> Color:
	match risk:
		"low":
			return UP
		"high":
			return DOWN
		_:
			return GOLD


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


func _stat_box(parent: HBoxContainer, caption: String, value_color: Color) -> Label:
	var box := VBoxContainer.new()
	var cap := _lbl(caption, 11, FAINT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(cap)
	var val := _lbl("$0", 22, value_color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(val)
	parent.add_child(box)
	return val


func _info_box(parent: HBoxContainer, caption: String) -> Label:
	var box := VBoxContainer.new()
	box.add_child(_lbl(caption, 11, FAINT))
	var val := _lbl("--", 16, TEXT)
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
	b.add_theme_font_size_override("font_size", 15)
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
