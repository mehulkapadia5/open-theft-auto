class_name HUD
extends CanvasLayer
## In-game HUD — boot screen, gameplay overlay, death screen. Built procedurally.
## Muted, realistic palette (GTA V style): charcoal panels, steel + gold accents.

signal start_pressed
signal respawn_pressed

const TEXT := Color("e8e6e0")        # off-white
const ACCENT := Color("8c9bab")      # desaturated steel blue
const MONEY := Color("84a85f")       # muted cash green
const GOLD := Color("c2a05a")        # warm brass — wanted / weapon
const BTN_BG := Color("23262b")      # dark button fill
const PANEL_BG := Color(0.055, 0.06, 0.07, 0.82)
const PANEL_EDGE := Color(0.55, 0.6, 0.65, 0.32)

var _boot: Control
var _hud: Control
var _death: Control
var _objective: Label
var _money: Label
var _stars: Label
var _waypoint: Label
var _clock: Label
var _hp: ProgressBar
var _arm: ProgressBar
var _weapon_name: Label
var _ammo: Label
var _speed_label: Label
var _speed_val: Label
var _obj_timer := 0.0

func _ready() -> void:
	layer = 10
	_build_boot()
	_build_hud()
	_build_death()
	_hud.visible = false
	_death.visible = false

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
	var tag := _label("VICE BEACH   ·   3D   ·   2026", 20, ACCENT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tag)

	var btn := _accent_button("PRESS START")
	btn.pressed.connect(func(): start_pressed.emit())
	var btn_wrap := CenterContainer.new()
	btn_wrap.add_child(btn)
	vb.add_child(btn_wrap)

	var controls := _label(
		"WASD move / drive    Mouse look    L-Click shoot    F enter/exit vehicle\n"
		+ "Q / Tab / Z weapons    1-9 pick    scroll cycle    SHIFT sprint / boost\n"
		+ "SPACE handbrake    M mute    R respawn / heal    ESC release mouse",
		15, Color(0.55, 0.57, 0.6))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(controls)

# ---------------- In-game HUD ----------------
func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	# Crosshair
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
		_hud.add_child(c)

	# Top row
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 16
	_hud.add_child(top)
	_money = _label("$0", 24, MONEY)
	top.add_child(_panel(_money))
	_stars = _label("WANTED: -----", 18, GOLD)
	top.add_child(_panel(_stars))
	_waypoint = _label("AIRPORT - west", 17, ACCENT)
	var wp_panel := _panel(_waypoint)
	wp_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waypoint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(wp_panel)
	_clock = _label("12:00", 20, ACCENT)
	top.add_child(_panel(_clock))

	# Bottom row
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 16
	bottom.offset_bottom = -16
	bottom.offset_top = -64
	_hud.add_child(bottom)
	bottom.add_child(_panel(_make_bar("HP", true)))
	bottom.add_child(_panel(_make_bar("ARM", false)))
	var wbox := VBoxContainer.new()
	wbox.add_child(_label("WEAPON", 11, Color(0.55, 0.57, 0.6)))
	_weapon_name = _label("PISTOL", 16, GOLD)
	wbox.add_child(_weapon_name)
	_ammo = _label("inf", 14, TEXT)
	wbox.add_child(_ammo)
	bottom.add_child(_panel(wbox))
	var sbox := VBoxContainer.new()
	_speed_label = _label("SPD", 11, Color(0.55, 0.57, 0.6))
	sbox.add_child(_speed_label)
	_speed_val = _label("0", 22, ACCENT)
	sbox.add_child(_speed_val)
	bottom.add_child(_panel(sbox))

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
	box.add_child(_label(bar_name, 11, Color(0.55, 0.57, 0.6)))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 12)
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
	box.add_child(bar)
	if is_hp:
		_hp = bar
	else:
		_arm = bar
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

# ---------------- Public API ----------------
func enter_game() -> void:
	_boot.visible = false
	_hud.visible = true
	_death.visible = false

func show_death() -> void:
	_death.visible = true

func hide_death() -> void:
	_death.visible = false

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

func update_hud(data: Dictionary) -> void:
	_money.text = "$%d" % data.money
	var n: int = clampi(int(round(data.wanted)), 0, 5)
	_stars.text = "WANTED: " + "*".repeat(n) + "-".repeat(5 - n)
	var mins := int(data.time_min)
	_clock.text = "%02d:%02d" % [int(mins / 60.0) % 24, mins % 60]
	_hp.value = clampf(data.hp / data.hp_max * 100.0, 0.0, 100.0)
	_arm.value = clampf(data.armor / data.armor_max * 100.0, 0.0, 100.0)
	_weapon_name.text = data.weapon
	_ammo.text = (data.ammo if data.ammo is String else str(int(data.ammo)))
	_speed_label.text = data.speed_label
	_speed_val.text = str(int(data.speed_val))
	_waypoint.text = data.waypoint
