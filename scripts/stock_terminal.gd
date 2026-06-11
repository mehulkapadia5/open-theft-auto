class_name StockTerminal
extends CanvasLayer
## The city exchange's trading terminal.
##
## Three views: a clean ticker list, a per-stock detail page with a full price
## chart, and a modal order ticket where the player invests a chosen dollar
## amount (buying fractional shares) or sells a chosen number of shares.

signal closed

const TEXT := Color("e8e6e0")
const DIM := Color("8c9bab")
const FAINT := Color(0.55, 0.57, 0.6)
const UP := Color("5fb86a")
const DOWN := Color("c8534a")
const GOLD := Color("c2a05a")
const MONEY := Color("84a85f")
const SCREEN_BG := Color(0.03, 0.04, 0.05, 0.98)
const PANEL_BG := Color(0.075, 0.085, 0.10, 1.0)
const ROW_BG := Color(0.11, 0.12, 0.14, 1.0)
const FIELD_BG := Color(0.04, 0.05, 0.06, 1.0)
const EDGE := Color(0.42, 0.62, 0.55, 0.5)

const W_TICK := 330
const W_PRICE := 180
const W_CHG := 200
const W_HOLD := 230

var _root: Control
var _list_view: CenterContainer
var _detail_view: CenterContainer
var _order_view: Control

var _mode := "list"          # list | detail
var _detail_idx := 0
var _order_idx := 0
var _order_kind := "buy"     # buy | sell
var _open := false

# List-view widgets
var _list_cash: Label
var _list_port: Label
var _list_rows: Array = []

# Detail-view widgets
var _d_symbol: Label
var _d_name: Label
var _d_price: Label
var _d_chg: Label
var _d_stats: Label
var _d_hold: Label
var _d_chart: Chart
var _d_sell_btn: Button

# Order-ticket widgets
var _o_title: Label
var _o_price: Label
var _o_avail: Label
var _o_input_label: Label
var _o_input: LineEdit
var _o_quick: Array = []
var _o_result: Label
var _o_total: Label
var _o_place: Button


## A full price-history chart.
class Chart extends Control:
	var _data: Array = []
	var _open_price := 0.0
	var _color := Color("5fb86a")

	func set_series(data: Array, open_price: float, color: Color) -> void:
		_data = data
		_open_price = open_price
		_color = color
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.4))
		if _data.size() < 2:
			return
		var lo: float = _data.min()
		var hi: float = _data.max()
		lo = minf(lo, _open_price)
		hi = maxf(hi, _open_price)
		var rng: float = maxf(hi - lo, 0.0001)
		var pad := 14.0
		var plot_h: float = size.y - pad * 2.0
		var pts := PackedVector2Array()
		for i in _data.size():
			var x: float = float(i) / float(_data.size() - 1) * size.x
			var y: float = pad + plot_h - (_data[i] - lo) / rng * plot_h
			pts.append(Vector2(x, y))
		var oy: float = pad + plot_h - (_open_price - lo) / rng * plot_h
		var dash := Color(0.5, 0.52, 0.55, 0.45)
		var dx := 0.0
		while dx < size.x:
			draw_line(Vector2(dx, oy), Vector2(dx + 9.0, oy), dash, 1.0)
			dx += 18.0
		var poly := PackedVector2Array(pts)
		poly.append(Vector2(size.x, size.y))
		poly.append(Vector2(0, size.y))
		draw_colored_polygon(poly, Color(_color.r, _color.g, _color.b, 0.12))
		draw_polyline(pts, _color, 2.0, true)


func _ready() -> void:
	layer = 20
	_build()
	_root.visible = false
	StockMarket.updated.connect(_refresh)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var screen := ColorRect.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.color = SCREEN_BG
	_root.add_child(screen)

	_list_view = _full_center()
	_root.add_child(_list_view)
	_list_view.add_child(_build_list())

	_detail_view = _full_center()
	_root.add_child(_detail_view)
	_detail_view.add_child(_build_detail())

	_order_view = Control.new()
	_order_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_order_view)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_order_view.add_child(dim)
	var ocenter := _full_center()
	_order_view.add_child(ocenter)
	ocenter.add_child(_build_order())


# ---------------- List view ----------------
func _build_list() -> PanelContainer:
	var panel := _panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 9)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 30)
	col.add_child(head)
	var title := _lbl("FREE HARBOR EXCHANGE", 30, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_list_cash = _stat_box(head, "CASH", MONEY)
	_list_port = _stat_box(head, "PORTFOLIO", TEXT)

	col.add_child(_rule())

	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 16)
	col.add_child(ch)
	ch.add_child(_cell("TICKER", W_TICK, FAINT, 12, HORIZONTAL_ALIGNMENT_LEFT))
	ch.add_child(_cell("PRICE", W_PRICE, FAINT, 12, HORIZONTAL_ALIGNMENT_RIGHT))
	ch.add_child(_cell("CHANGE", W_CHG, FAINT, 12, HORIZONTAL_ALIGNMENT_RIGHT))
	ch.add_child(_cell("HOLDINGS", W_HOLD, FAINT, 12, HORIZONTAL_ALIGNMENT_RIGHT))
	ch.add_child(_cell("", 276, FAINT, 12, HORIZONTAL_ALIGNMENT_CENTER))

	for i in StockMarket.stocks.size():
		col.add_child(_build_row(i))

	col.add_child(_rule())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 18)
	col.add_child(foot)
	var hint := _lbl("Click a ticker for its price chart. Prices move in real time.",
		14, DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	var close_btn := _make_button("CLOSE  (E)", 150, TEXT)
	close_btn.pressed.connect(_close)
	foot.add_child(close_btn)
	return panel


func _build_row(idx: int) -> PanelContainer:
	var s: Dictionary = StockMarket.stocks[idx]
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

	# Clickable ticker (symbol + name) -> detail page.
	var tick := VBoxContainer.new()
	tick.custom_minimum_size = Vector2(W_TICK, 0)
	tick.mouse_filter = Control.MOUSE_FILTER_STOP
	tick.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tick.add_child(_lbl(s.symbol, 22, GOLD))
	tick.add_child(_lbl(s.name, 13, DIM))
	tick.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed \
			and e.button_index == MOUSE_BUTTON_LEFT:
			_show_detail(idx))
	row.add_child(tick)

	var price := _cell("", W_PRICE, TEXT, 21, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(price)

	# Change cell: percent on top, a RALLY / CRASH signal beneath it.
	var chg_box := VBoxContainer.new()
	chg_box.custom_minimum_size = Vector2(W_CHG, 0)
	chg_box.add_theme_constant_override("separation", 1)
	var chg := _lbl("", 19, TEXT)
	chg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var sig := _lbl("", 12, FAINT)
	sig.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chg_box.add_child(chg)
	chg_box.add_child(sig)
	row.add_child(chg_box)

	var hold := _cell("", W_HOLD, DIM, 16, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(hold)

	var trade := HBoxContainer.new()
	trade.add_theme_constant_override("separation", 8)
	var buy := _make_button("BUY", 124, UP)
	buy.pressed.connect(_open_order.bind(idx, "buy"))
	trade.add_child(buy)
	var sell := _make_button("SELL", 124, DOWN)
	sell.pressed.connect(_open_order.bind(idx, "sell"))
	trade.add_child(sell)
	row.add_child(trade)

	_list_rows.append({
		"price": price, "chg": chg, "sig": sig, "hold": hold, "sell": sell,
	})
	return wrap


# ---------------- Detail view ----------------
func _build_detail() -> PanelContainer:
	var panel := _panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)
	var back := _make_button("< BACK", 130, DIM)
	back.pressed.connect(_show_list)
	head.add_child(back)
	var nm := VBoxContainer.new()
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d_symbol = _lbl("", 30, GOLD)
	_d_name = _lbl("", 15, DIM)
	nm.add_child(_d_symbol)
	nm.add_child(_d_name)
	head.add_child(nm)
	var pr := VBoxContainer.new()
	_d_price = _lbl("", 32, TEXT)
	_d_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_d_chg = _lbl("", 19, DIM)
	_d_chg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pr.add_child(_d_price)
	pr.add_child(_d_chg)
	head.add_child(pr)

	col.add_child(_rule())

	_d_chart = Chart.new()
	_d_chart.custom_minimum_size = Vector2(1180, 330)
	col.add_child(_d_chart)

	col.add_child(_rule())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 18)
	col.add_child(foot)
	_d_stats = _lbl("", 14, DIM)
	foot.add_child(_d_stats)
	_d_hold = _lbl("", 15, TEXT)
	_d_hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d_hold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(_d_hold)
	var buy := _make_button("BUY", 150, UP)
	buy.pressed.connect(func() -> void: _open_order(_detail_idx, "buy"))
	foot.add_child(buy)
	_d_sell_btn = _make_button("SELL", 150, DOWN)
	_d_sell_btn.pressed.connect(func() -> void: _open_order(_detail_idx, "sell"))
	foot.add_child(_d_sell_btn)
	return panel


# ---------------- Order ticket ----------------
func _build_order() -> PanelContainer:
	var panel := _panel()
	panel.custom_minimum_size = Vector2(620, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 13)
	panel.add_child(col)

	_o_title = _lbl("", 25, GOLD)
	col.add_child(_o_title)
	col.add_child(_rule())

	_o_price = _lbl("", 17, TEXT)
	col.add_child(_o_price)
	_o_avail = _lbl("", 14, DIM)
	col.add_child(_o_avail)

	_o_input_label = _lbl("AMOUNT", 12, FAINT)
	col.add_child(_o_input_label)
	_o_input = LineEdit.new()
	_o_input.custom_minimum_size = Vector2(0, 44)
	_o_input.add_theme_font_size_override("font_size", 22)
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
	_o_input.text_changed.connect(func(_t: String) -> void: _refresh_order())
	col.add_child(_o_input)

	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 8)
	col.add_child(quick)
	for i in 4:
		var b := _make_button("", 138, GOLD)
		b.pressed.connect(_quick.bind(i))
		quick.add_child(b)
		_o_quick.append(b)

	_o_result = _lbl("", 16, DIM)
	col.add_child(_o_result)

	col.add_child(_rule())
	_o_total = _lbl("", 22, TEXT)
	col.add_child(_o_total)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	btns.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(btns)
	var cancel := _make_button("CANCEL", 150, DIM)
	cancel.pressed.connect(_close_order)
	btns.add_child(cancel)
	_o_place = _make_button("PLACE ORDER", 240, UP)
	_o_place.pressed.connect(_place_order)
	btns.add_child(_o_place)
	return panel


# ---------------- Navigation ----------------
func open() -> void:
	_open = true
	_root.visible = true
	_show_list()


func _close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	closed.emit()


func _show_list() -> void:
	_mode = "list"
	_list_view.visible = true
	_detail_view.visible = false
	_order_view.visible = false
	_refresh()


func _show_detail(idx: int) -> void:
	_mode = "detail"
	_detail_idx = idx
	_list_view.visible = false
	_detail_view.visible = true
	_order_view.visible = false
	_refresh()


func _open_order(idx: int, kind: String) -> void:
	var s: Dictionary = StockMarket.stocks[idx]
	if kind == "sell" and s.owned <= 0.0:
		return
	_order_idx = idx
	_order_kind = kind
	if kind == "buy":
		_o_input_label.text = "AMOUNT TO INVEST  ($)"
		_o_input.placeholder_text = "dollars to spend"
		_o_input.text = str(mini(100, GameState.money))
		var amts := ["$100", "$1,000", "$10,000", "MAX"]
		for i in 4:
			_o_quick[i].text = amts[i]
		_o_place.text = "PLACE BUY ORDER"
	else:
		_o_input_label.text = "SHARES TO SELL"
		_o_input.placeholder_text = "shares (fractional ok)"
		_o_input.text = _shares_str(s.owned)
		var labs := ["25%", "50%", "75%", "100%"]
		for i in 4:
			_o_quick[i].text = labs[i]
		_o_place.text = "PLACE SELL ORDER"
	_order_view.visible = true
	_refresh()


func _close_order() -> void:
	_order_view.visible = false
	_refresh()


func _quick(i: int) -> void:
	var s: Dictionary = StockMarket.stocks[_order_idx]
	if _order_kind == "buy":
		var amts := [100, 1000, 10000, GameState.money]
		_o_input.text = str(amts[i])
	else:
		var fracs := [0.25, 0.5, 0.75, 1.0]
		if i == 3:
			_o_input.text = "%.6f" % s.owned
		else:
			_o_input.text = _shares_str(s.owned * fracs[i])
	_refresh_order()


func _place_order() -> void:
	var s: Dictionary = StockMarket.stocks[_order_idx]
	var done := false
	if _order_kind == "buy":
		var cash := clampi(int(_o_input.text.to_float()), 0, GameState.money)
		done = StockMarket.buy_with_cash(_order_idx, cash) > 0.0
	else:
		var shares := _o_input.text.to_float()
		if shares >= s.owned * 0.995:
			shares = s.owned                     # treat near-full as sell-all
		done = StockMarket.sell(_order_idx, shares) > 0.0
	if done:
		AudioFX.coin()
		_close_order()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _order_view.visible:
				_close_order()
			elif _mode == "detail":
				_show_list()
			else:
				_close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E and not _order_view.visible:
			# E closes list / detail, but not while typing an order amount.
			if _mode == "detail":
				_show_list()
			else:
				_close()
			get_viewport().set_input_as_handled()


# ---------------- Refresh ----------------
func _refresh() -> void:
	if not _open:
		return
	if _list_view.visible:
		_refresh_list()
	if _detail_view.visible:
		_refresh_detail()
	if _order_view.visible:
		_refresh_order()


func _refresh_list() -> void:
	_list_cash.text = "$" + _commas(GameState.money)
	_list_port.text = "$" + _commas(StockMarket.portfolio_value())
	for i in _list_rows.size():
		var s: Dictionary = StockMarket.stocks[i]
		var r: Dictionary = _list_rows[i]
		var tint: Color = UP if s.price >= s.open else DOWN
		r.price.text = "$" + _price_str(s.price)
		r.chg.text = _pct_str(s)
		r.chg.add_theme_color_override("font_color", tint)
		match s.mode:
			"rally":
				r.sig.text = "RALLY"
				r.sig.add_theme_color_override("font_color", UP)
			"crash":
				r.sig.text = "CRASH"
				r.sig.add_theme_color_override("font_color", DOWN)
			_:
				r.sig.text = ""
		if s.owned > 0.0:
			r.hold.text = "%s sh   $%s" % [_shares_str(s.owned),
				_commas(int(round(s.owned * s.price)))]
		else:
			r.hold.text = "--"
		r.sell.disabled = s.owned <= 0.0


func _refresh_detail() -> void:
	var s: Dictionary = StockMarket.stocks[_detail_idx]
	var tint: Color = UP if s.price >= s.open else DOWN
	_d_symbol.text = s.symbol
	_d_name.text = s.name
	_d_price.text = "$" + _price_str(s.price)
	var sig := ""
	if s.mode == "rally":
		sig = "   ▲ RALLY"
	elif s.mode == "crash":
		sig = "   ▼ CRASH"
	_d_chg.text = _pct_str(s) + sig
	_d_chg.add_theme_color_override("font_color", tint)
	var hi: float = s.history.max()
	var lo: float = s.history.min()
	_d_stats.text = "SESSION HIGH  $%s      LOW  $%s" % [_price_str(hi), _price_str(lo)]
	if s.owned > 0.0:
		var value: float = s.owned * s.price
		var pl: float = value - s.spent
		_d_hold.text = "HOLDING %s sh  ·  $%s  (%s$%s)" % [_shares_str(s.owned),
			_commas(int(round(value))), ("+" if pl >= 0.0 else "-"),
			_commas(int(abs(round(pl))))]
	else:
		_d_hold.text = "No position"
	_d_sell_btn.disabled = s.owned <= 0.0
	_d_chart.set_series(s.history, s.open, tint)


func _refresh_order() -> void:
	var s: Dictionary = StockMarket.stocks[_order_idx]
	_o_title.text = ("BUY " if _order_kind == "buy" else "SELL ") + s.symbol \
		+ "  ·  " + s.name
	_o_price.text = "MARKET PRICE   $" + _price_str(s.price) + " / share"
	if _order_kind == "buy":
		_o_avail.text = "Cash $%s   ·   Portfolio $%s" \
			% [_commas(GameState.money), _commas(StockMarket.portfolio_value())]
		var cash := clampi(int(_o_input.text.to_float()), 0, GameState.money)
		var shares: float = float(cash) / s.price if s.price > 0.0 else 0.0
		_o_result.text = "Buys  ≈ %s shares" % _shares_str(shares)
		_o_total.text = "ORDER TOTAL   $" + _commas(cash)
		_o_place.disabled = cash <= 0
	else:
		_o_avail.text = "You hold %s shares  ·  worth $%s" \
			% [_shares_str(s.owned), _commas(int(round(s.owned * s.price)))]
		var shares: float = clampf(_o_input.text.to_float(), 0.0, s.owned)
		var proceeds := int(round(shares * s.price))
		_o_result.text = "Sells  ≈ %s shares" % _shares_str(shares)
		_o_total.text = "PROCEEDS   $" + _commas(proceeds)
		_o_place.disabled = shares <= 0.0


# ---------------- Helpers ----------------
func _pct_str(s: Dictionary) -> String:
	var pct: float = (s.price / s.open - 1.0) * 100.0 if s.open > 0.0 else 0.0
	return ("+" if pct >= 0.0 else "") + _commas(int(round(pct))) + "%"


func _price_str(p: float) -> String:
	if p >= 1000.0:
		return _commas(int(round(p)))
	return "%.2f" % p


func _shares_str(n: float) -> String:
	if n >= 1000.0:
		return _commas(int(round(n)))
	if n >= 1.0:
		return "%.2f" % n
	return "%.4f" % n


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


func _full_center() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE   # never block clicks behind
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
