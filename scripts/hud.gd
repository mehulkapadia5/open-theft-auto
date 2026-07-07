class_name HUD
extends CanvasLayer
## In-game HUD — boot screen, gameplay overlay, death screen. Built procedurally.
## Muted, realistic palette (GTA V style): charcoal panels, steel + gold accents.

signal start_pressed
signal new_game_pressed
signal respawn_pressed

const TEXT := Color("e8e6e0")        # off-white
const ACCENT := Color("8c9bab")      # desaturated steel blue
const MONEY := Color("84a85f")       # muted cash green
const GOLD := Color("c2a05a")        # warm brass — wanted / weapon
const FAINT := Color(0.55, 0.57, 0.6)
const BTN_BG := Color("23262b")      # dark button fill
const PANEL_BG := Color(0.055, 0.06, 0.07, 0.82)
const PANEL_EDGE := Color(0.55, 0.6, 0.65, 0.32)

var _boot: Control
var _hud: Control
var _death: Control
var _victory: Control
var _victory_timer := 0.0
var _objective: Label
var _money: Label
var _stars: Stars
var _waypoint: Label
var _clock: Label
var _hp: ProgressBar
var _arm: ProgressBar
var _weapon_name: Label
var _ammo: Label
var _speed_label: Label
var _speed_val: Label
var _minimap: Minimap
var _speedo: Speedometer
var _speedo_panel: PanelContainer
var _race_panel: PanelContainer
var _race_pos: Label
var _race_lap: Label
var _race_time: Label
var _race_best: Label
var _race_drift: Label
var _obj_timer := 0.0
var _crosshair: Control
var _scope: Control


## Show/hide the sniper scope (and hide the normal crosshair while it's up).
func set_scope(on: bool) -> void:
	if _scope == null or _scope.visible == on:
		return
	_scope.visible = on
	_crosshair.visible = not on
	_scope.queue_redraw()


## Sniper scope: a black surround masking everything outside a circular view,
## with a fine cross reticle, stadia lines and mil-dots.
class Scope extends Control:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var sz := size
		var c := sz * 0.5
		var r: float = minf(sz.x, sz.y) * 0.46
		var big := sz.length()
		var black := Color(0, 0, 0, 1)
		# Black surround — a thick ring from the scope edge out past the corners.
		draw_arc(c, r + (big - r) * 0.5, 0.0, TAU, 96, black, big - r, true)
		# Soft inner vignette + crisp rim.
		draw_arc(c, r - 9.0, 0.0, TAU, 96, Color(0, 0, 0, 0.5), 18.0, true)
		draw_arc(c, r, 0.0, TAU, 160, black, 3.0, true)
		draw_arc(c, r - 2.5, 0.0, TAU, 160, Color(0.2, 0.21, 0.22, 0.8), 1.5, true)
		# Reticle.
		var line := Color(0.04, 0.04, 0.05, 0.95)
		var gap := 9.0
		for s in [-1.0, 1.0]:
			draw_line(Vector2(c.x + gap * s, c.y), Vector2(c.x + r * s, c.y), line, 1.5, true)
			draw_line(Vector2(c.x, c.y + gap * s), Vector2(c.x, c.y + r * s), line, 1.5, true)
			# Heavier outer stadia.
			draw_line(Vector2(c.x + r * 0.6 * s, c.y), Vector2(c.x + r * s, c.y), line, 4.0, true)
			draw_line(Vector2(c.x, c.y + r * 0.6 * s), Vector2(c.x, c.y + r * s), line, 4.0, true)
			# Mil-dots.
			for i in range(1, 5):
				var d: float = gap + i * (r * 0.55) / 5.0
				draw_circle(Vector2(c.x + d * s, c.y), 1.7, line)
				draw_circle(Vector2(c.x, c.y + d * s), 1.7, line)
		draw_circle(c, 1.8, Color(0.75, 0.1, 0.1, 0.95))


## A stylised top-down city minimap.
class Minimap extends Control:
	var px := 0.0
	var pz := 0.0
	var pyaw := 0.0
	var pa := false              # President's motorcade is out
	var pgx := 0.0
	var pgz := 0.0

	const ROAD := Color(0.30, 0.31, 0.35)
	const GRASS := Color(0.30, 0.39, 0.24)
	const WATER := Color(0.21, 0.43, 0.54)
	const SAND := Color(0.62, 0.57, 0.42)

	func set_player(x: float, z: float, yaw: float) -> void:
		px = x
		pz = z
		pyaw = yaw
		queue_redraw()

	func set_president(active: bool, x: float, z: float) -> void:
		pa = active
		pgx = x
		pgz = z

	func _span() -> float:
		return 1080.0           # wide enough to take in the bay, airport and estate

	func _w2m(wx: float, wz: float) -> Vector2:
		var span := _span()
		return Vector2((wx / span + 0.5) * size.x, (wz / span + 0.5) * size.y)

	func _draw() -> void:
		var span := _span()
		var wh: float = CityWorld.WORLD_HALF
		# The bay fills the frame; landmasses sit on top.
		draw_rect(Rect2(Vector2.ZERO, size), WATER)
		# Mainland — wilderness and the city, everything north of the shoreline.
		var land0 := _w2m(-span / 2.0, -span / 2.0)
		var land1 := _w2m(span / 2.0, wh)
		draw_rect(Rect2(land0, land1 - land0), GRASS)
		# Beach strip along the south edge of the city.
		var bs0 := _w2m(-wh, wh - 20.0)
		var bs1 := _w2m(wh, wh)
		draw_rect(Rect2(bs0, bs1 - bs0), SAND)
		# River.
		var rv0 := _w2m(CityWorld.RIVER_CX - CityWorld.RIVER_HALF, -wh)
		var rv1 := _w2m(CityWorld.RIVER_CX + CityWorld.RIVER_HALF, wh)
		draw_rect(Rect2(rv0, rv1 - rv0), WATER)
		# Road grid.
		for i in range(CityWorld.GRID + 1):
			var g: float = -wh + i * CityWorld.BLOCK
			draw_line(_w2m(g, -wh), _w2m(g, wh), ROAD, 1.5)
			draw_line(_w2m(-wh, g), _w2m(wh, g), ROAD, 1.5)
		# Airport island and the President's estate island.
		_landmass(CityWorld.AIRFIELD.x0, CityWorld.AIRFIELD.z0,
			CityWorld.AIRFIELD.x1, CityWorld.AIRFIELD.z1)
		_landmass(CityWorld.ESTATE_GROUNDS.x0, CityWorld.ESTATE_GROUNDS.z0,
			CityWorld.ESTATE_GROUNDS.x1, CityWorld.ESTATE_GROUNDS.z1)
		_causeway(CityWorld.CAUSEWAY)
		_causeway(CityWorld.ESTATE_CAUSEWAY)
		# Landmarks.
		_marker(CityWorld.AIRPORT.x, CityWorld.AIRPORT.z, Color("e0b050"))
		_marker(CityWorld.EXCHANGE.x, CityWorld.EXCHANGE.z, Color("4fe6b0"))
		_marker(CityWorld.PRESIDENT_HOUSE.x, CityWorld.PRESIDENT_HOUSE.z, Color("c878e0"))
		# The President — a pulsing red marker while his motorcade is out.
		if pa:
			var pp := _w2m(clampf(pgx, -span / 2.0, span / 2.0),
				clampf(pgz, -span / 2.0, span / 2.0))
			draw_circle(pp, 6.5, Color("e23b3b"))
			draw_circle(pp, 6.5, Color(0, 0, 0, 0.6), false, 1.5)
			draw_circle(pp, 11.0, Color("e23b3b"), false, 2.0)
		# Player arrow.
		var fwd := Vector2(sin(pyaw), cos(pyaw))
		var perp := Vector2(fwd.y, -fwd.x)
		var c := _w2m(clampf(px, -span / 2.0, span / 2.0),
			clampf(pz, -span / 2.0, span / 2.0))
		var tri := PackedVector2Array([
			c + fwd * 9.0, c - fwd * 5.0 + perp * 6.0, c - fwd * 5.0 - perp * 6.0])
		draw_colored_polygon(tri, Color("f4f4f0"))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]),
			Color(0, 0, 0, 0.6), 1.0, true)

	func _landmass(x0: float, z0: float, x1: float, z1: float) -> void:
		var a := _w2m(x0, z0)
		var b := _w2m(x1, z1)
		draw_rect(Rect2(a, b - a), GRASS)

	func _causeway(r: Dictionary) -> void:
		var a := _w2m(r.x0, r.z0)
		var b := _w2m(r.x1, r.z1)
		draw_rect(Rect2(a, b - a), ROAD)

	func _marker(wx: float, wz: float, col: Color) -> void:
		var p := _w2m(wx, wz)
		draw_circle(p, 4.0, col)
		draw_circle(p, 4.0, Color(0, 0, 0, 0.5), false, 1.0)


## The wanted level drawn as five proper stars.
class Stars extends Control:
	var level := 0
	const STAR := Color("d2b25e")
	const EMPTY := Color(0.5, 0.5, 0.52, 0.7)

	func set_level(n: int) -> void:
		if n != level:
			level = n
			queue_redraw()

	func _draw() -> void:
		var r := 9.0
		var gap := 25.0
		var cy := size.y / 2.0
		for i in 5:
			_star(Vector2(r + 2.0 + i * gap, cy), r, i < level)

	func _star(c: Vector2, r: float, filled: bool) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var ang := -PI / 2.0 + k * PI / 5.0
			var rad: float = r if k % 2 == 0 else r * 0.42
			pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
		if filled:
			for k in 10:
				draw_colored_polygon(
					PackedVector2Array([c, pts[k], pts[(k + 1) % 10]]), STAR)
		else:
			var loop := PackedVector2Array(pts)
			loop.append(pts[0])
			draw_polyline(loop, EMPTY, 1.3, true)


## A semicircular car speedometer — arc gauge, sweeping needle, digital readout.
class Speedometer extends Control:
	const W := 210.0
	const H := 132.0
	const START := 135.0          # arc start angle (degrees)
	const SWEEP := 270.0          # total arc sweep
	const TRACK := Color(0.5, 0.52, 0.56, 0.55)
	const FILL := Color("c2a05a")
	const REDLINE := Color("c8534a")
	const NEEDLE := Color("e8e6e0")

	var _frac := 0.0
	var _num: Label

	func _ready() -> void:
		custom_minimum_size = Vector2(W, H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_num = Label.new()
		_num.add_theme_font_size_override("font_size", 40)
		_num.add_theme_color_override("font_color", NEEDLE)
		_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_num.size = Vector2(W, 46)
		_num.position = Vector2(0, 40)
		_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_num.text = "0"
		add_child(_num)
		var unit := Label.new()
		unit.text = "KM/H"
		unit.add_theme_font_size_override("font_size", 13)
		unit.add_theme_color_override("font_color", Color(0.55, 0.57, 0.6))
		unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unit.size = Vector2(W, 16)
		unit.position = Vector2(0, 86)
		unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(unit)

	func set_speed(kmh: float, frac: float) -> void:
		_frac = clampf(frac, 0.0, 1.0)
		if _num != null:
			_num.text = str(int(round(kmh)))
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(W / 2.0, H - 12.0)
		var r := 78.0
		var s := deg_to_rad(START)
		var e := deg_to_rad(START + SWEEP)
		draw_arc(c, r, s, e, 96, TRACK, 5.0, true)
		var rl := deg_to_rad(START + SWEEP * 0.82)
		draw_arc(c, r, rl, e, 32, REDLINE, 5.0, true)
		if _frac > 0.002:
			var fe := deg_to_rad(START + SWEEP * _frac)
			draw_arc(c, r, s, fe, 96, FILL, 5.0, true)
		for i in 10:
			var a := deg_to_rad(START + SWEEP * i / 9.0)
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * (r - 12.0), c + d * (r - 3.0), TRACK, 2.0)
		var na := deg_to_rad(START + SWEEP * _frac)
		var nd := Vector2(cos(na), sin(na))
		draw_line(c, c + nd * (r - 8.0), NEEDLE, 3.0, true)
		draw_circle(c, 6.0, NEEDLE)
		draw_circle(c, 3.0, Color("23262b"))


func _ready() -> void:
	layer = 10
	_build_boot()
	_build_hud()
	_build_death()
	_build_victory()
	_hud.visible = false
	_death.visible = false
	_victory.visible = false

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb

func _panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style())
	p.add_child(child)
	return p

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _accent_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 24)
	btn.custom_minimum_size = Vector2(280, 62)
	var normal := StyleBoxFlat.new()
	normal.bg_color = BTN_BG
	normal.border_color = ACCENT
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 24
	normal.content_margin_right = 24
	var hover := normal.duplicate()
	hover.bg_color = Color("32363d")
	hover.border_color = TEXT
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", TEXT)
	return btn

# ---------------- Boot screen ----------------
func _build_boot() -> void:
	_boot = Control.new()
	_boot.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_boot)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0c0d0f")
	_boot.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	center.add_child(vb)

	var title := _label("GTA VI", 124, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var tag := _label("FREE HARBOR   ·   3D   ·   2026", 20, ACCENT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tag)

	# Continue an existing save, or start fresh. With no save there's just one
	# button (a fresh start).
	if SaveGame.has_save():
		var cont := _accent_button("CONTINUE")
		cont.pressed.connect(func(): start_pressed.emit())
		var cw := CenterContainer.new()
		cw.add_child(cont)
		vb.add_child(cw)
		var ng := _accent_button("NEW GAME")
		ng.pressed.connect(func(): new_game_pressed.emit())
		var nw := CenterContainer.new()
		nw.add_child(ng)
		vb.add_child(nw)
	else:
		var btn := _accent_button("PRESS START")
		btn.pressed.connect(func(): start_pressed.emit())
		var btn_wrap := CenterContainer.new()
		btn_wrap.add_child(btn)
		vb.add_child(btn_wrap)
	# Give the boot buttons gamepad/keyboard focus — without it a controller
	# player with a save could never pick NEW GAME (mouse-only button).
	UiNav.apply.call_deferred(vb)

	var controls := _label(
		"WASD move / drive    Mouse look    L-Click shoot    F enter/exit vehicle\n"
		+ "Q / Tab / Z weapons    1-9 pick    scroll cycle    SHIFT sprint / boost\n"
		+ "SPACE handbrake    E downtown kiosks    G enter Grand Prix (in an F1 car)    M mute    R respawn / heal\n"
		+ "ESC pause menu — resume, rebind controls, or exit",
		15, Color(0.55, 0.57, 0.6))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(controls)

# ---------------- In-game HUD ----------------
func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	# Crosshair — hidden while the sniper scope is up.
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_crosshair)
	for is_vert in [true, false]:
		var c := ColorRect.new()
		c.color = TEXT
		if is_vert:
			c.size = Vector2(2, 16)
			c.position = Vector2(-1, -8)
		else:
			c.size = Vector2(16, 2)
			c.position = Vector2(-8, -1)
		c.anchor_left = 0.5
		c.anchor_right = 0.5
		c.anchor_top = 0.5
		c.anchor_bottom = 0.5
		_crosshair.add_child(c)

	# Sniper scope overlay — a black surround with a circular view and a fine
	# reticle. Hidden until the player aims the sniper.
	_scope = Scope.new()
	_scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.visible = false
	_hud.add_child(_scope)

	# Top bar — money, wanted, waypoint, clock.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 16
	_hud.add_child(top)
	_money = _label("$0", 24, MONEY)
	top.add_child(_panel(_money))
	var wanted_box := HBoxContainer.new()
	wanted_box.add_theme_constant_override("separation", 9)
	var wlbl := _label("WANTED", 15, GOLD)
	wlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wanted_box.add_child(wlbl)
	_stars = Stars.new()
	_stars.custom_minimum_size = Vector2(132, 26)
	wanted_box.add_child(_stars)
	top.add_child(_panel(wanted_box))
	_waypoint = _label("AIRPORT", 17, ACCENT)
	var wp_panel := _panel(_waypoint)
	wp_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waypoint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(wp_panel)
	_clock = _label("12:00", 20, ACCENT)
	top.add_child(_panel(_clock))

	# Left status column — HP, armour, weapon, speed — under the top bar.
	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 6)
	var left := _panel(status)
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = 16
	left.offset_top = 68
	_hud.add_child(left)
	status.add_child(_make_bar("HEALTH", true))
	status.add_child(_make_bar("ARMOUR", false))
	var wsrow := HBoxContainer.new()
	wsrow.add_theme_constant_override("separation", 22)
	status.add_child(wsrow)
	var wbox := VBoxContainer.new()
	wbox.add_child(_label("WEAPON", 11, FAINT))
	_weapon_name = _label("PISTOL", 16, GOLD)
	wbox.add_child(_weapon_name)
	_ammo = _label("inf", 13, TEXT)
	wbox.add_child(_ammo)
	wsrow.add_child(wbox)
	var sbox := VBoxContainer.new()
	_speed_label = _label("SPD", 11, FAINT)
	sbox.add_child(_speed_label)
	_speed_val = _label("0", 22, ACCENT)
	sbox.add_child(_speed_val)
	wsrow.add_child(sbox)

	# Minimap — bottom-right corner.
	_minimap = Minimap.new()
	_minimap.custom_minimum_size = Vector2(228, 228)
	_minimap.clip_contents = true
	var map_panel := _panel(_minimap)
	map_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	map_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	map_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	map_panel.offset_right = -16
	map_panel.offset_bottom = -16
	_hud.add_child(map_panel)

	# Speedometer — bottom-centre, only visible while driving a car.
	_speedo = Speedometer.new()
	_speedo_panel = _panel(_speedo)
	_speedo_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speedo_panel.anchor_left = 0.5
	_speedo_panel.anchor_right = 0.5
	_speedo_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_speedo_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_speedo_panel.offset_bottom = -16
	_speedo_panel.visible = false
	_hud.add_child(_speedo_panel)

	# Race panel — top-right, only visible while driving (lap timing + drift).
	var race_box := VBoxContainer.new()
	race_box.add_theme_constant_override("separation", 2)
	_race_pos = _label("P 1/1", 22, TEXT)
	race_box.add_child(_race_pos)
	_race_lap = _label("LAP 0", 15, GOLD)
	race_box.add_child(_race_lap)
	_race_time = _label("0:00.00", 27, TEXT)
	race_box.add_child(_race_time)
	_race_best = _label("BEST  --:--", 13, ACCENT)
	race_box.add_child(_race_best)
	_race_drift = _label("DRIFT  0", 13, MONEY)
	race_box.add_child(_race_drift)
	_race_panel = _panel(race_box)
	_race_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_race_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_race_panel.offset_right = -16
	_race_panel.offset_top = 68
	_race_panel.visible = false
	_hud.add_child(_race_panel)

	# Objective ticker
	_objective = _label("", 17, TEXT)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var op := _panel(_objective)
	var ops := _panel_style()
	ops.border_color = GOLD
	op.add_theme_stylebox_override("panel", ops)
	op.set_anchors_preset(Control.PRESET_CENTER_TOP)
	op.anchor_left = 0.5
	op.anchor_right = 0.5
	op.offset_top = 64
	op.grow_horizontal = Control.GROW_DIRECTION_BOTH
	op.modulate.a = 0.0
	_hud.add_child(op)
	_objective.set_meta("panel", op)

func _make_bar(bar_name: String, is_hp: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_child(_label(bar_name, 11, FAINT))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(190, 13)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = (Color("6f9e5a") if is_hp else Color("6f8aa3"))
	fg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	if is_hp:
		_hp = bar
	else:
		_arm = bar
	box.add_child(bar)
	return box

# ---------------- Death screen ----------------
func _build_death() -> void:
	_death = Control.new()
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_death)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.04, 0.78)
	_death.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)
	var t := _label("WASTED", 96, Color("9c3a30"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var p := _label("You woke up at the hospital. Lost some cash.", 18, Color(0.7, 0.7, 0.72))
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(p)
	var btn := _accent_button("CONTINUE")
	btn.pressed.connect(func(): respawn_pressed.emit())
	var bw := CenterContainer.new()
	bw.add_child(btn)
	vb.add_child(bw)

## A full-bleed "CITY OWNED" banner — non-blocking, fades out on its own.
func _build_victory() -> void:
	_victory = Control.new()
	_victory.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_victory)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victory.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	var t := _label("CITY OWNED", 110, Color("e0b24a"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var p := _label("The President is dead. Free Harbor answers to you now.",
		24, Color(0.86, 0.86, 0.9))
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(p)

# ---------------- Public API ----------------
func enter_game() -> void:
	_boot.visible = false
	_hud.visible = true
	_death.visible = false
	_victory.visible = false

func show_death() -> void:
	_death.visible = true

func hide_death() -> void:
	_death.visible = false

func show_victory() -> void:
	_victory.visible = true
	_victory.modulate.a = 1.0
	_victory_timer = 8.0

func show_objective(text: String, secs := 3.5) -> void:
	_objective.text = text
	_obj_timer = secs
	var panel: Control = _objective.get_meta("panel")
	panel.modulate.a = 1.0

func _process(delta: float) -> void:
	if _obj_timer > 0.0:
		_obj_timer -= delta
		if _obj_timer <= 0.0:
			var panel: Control = _objective.get_meta("panel")
			panel.modulate.a = 0.0
	if _victory_timer > 0.0:
		_victory_timer -= delta
		if _victory_timer < 1.5:
			_victory.modulate.a = clampf(_victory_timer / 1.5, 0.0, 1.0)
		if _victory_timer <= 0.0:
			_victory.visible = false

func update_hud(data: Dictionary) -> void:
	_money.text = "$" + _commas(int(data.money))
	_stars.set_level(clampi(int(round(data.wanted)), 0, 5))
	var mins := int(data.time_min)
	_clock.text = "%02d:%02d" % [int(mins / 60.0) % 24, mins % 60]
	_hp.value = clampf(data.hp / data.hp_max * 100.0, 0.0, 100.0)
	_arm.value = clampf(data.armor / data.armor_max * 100.0, 0.0, 100.0)
	_weapon_name.text = data.weapon
	_ammo.text = (data.ammo if data.ammo is String else str(int(data.ammo)))
	_speed_label.text = data.speed_label
	_speed_val.text = str(int(data.speed_val))
	_speedo_panel.visible = data.show_speedo
	if data.show_speedo:
		_speedo.set_speed(data.speed_kmh, data.speed_frac)
	_waypoint.text = data.waypoint
	_minimap.set_president(data.pres_active, data.pres_x, data.pres_z)
	_minimap.set_player(data.map_x, data.map_z, data.map_yaw)
	_race_panel.visible = data.racing
	if data.racing:
		_race_pos.text = "P %d/%d" % [int(data.race_rank), int(data.race_total)]
		_race_lap.text = "LAP %d/%d" % [int(data.lap) + 1, int(data.total_laps)]
		_race_time.text = data.lap_time
		_race_best.text = "BEST  " + str(data.best_lap)
		_race_drift.text = "DRIFT  " + _commas(int(data.drift))

## Group digits with thousands separators: 70991741333 -> "70,991,741,333".
func _commas(value: int) -> String:
	var neg := value < 0
	var digits := str(absi(value))
	var out := ""
	var c := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if neg else out
