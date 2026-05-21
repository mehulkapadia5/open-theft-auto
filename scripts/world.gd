class_name CityWorld
extends Node3D
## Procedural Vice Beach city — grid roads, buildings, beach, ocean, airport.
## Mirrors buildCity()/buildAirport()/collidesAt() from the Three.js prototype.

const BLOCK := 32.0                  # wide blocks so the streets are roomy
const GRID := 11
const ROAD_W := 15.0                 # broad multi-lane roads
const WORLD := BLOCK * GRID          # 352 — the dense city core
const WORLD_HALF := WORLD / 2.0      # 176
const OUTER_HALF := WORLD_HALF + 250.0   # wide green wilderness ring around the city

# Airport airfield, off the city grid in the south-east — a long grass field.
const AIRPORT := {"x": 47.0, "z": 81.0}                              # waypoint = terminal forecourt
const RUNWAY_A := {"x": 98.0, "z": 410.0, "len": 690.0, "w": 16.0}   # main runway (big plane)
const RUNWAY_B := {"x": 128.0, "z": 350.0, "len": 540.0, "w": 10.0}  # secondary runway (small plane)
# Flat grass airfield the runways sit on — solid ground, no water to crash into.
const AIRFIELD := {"x0": 30.0, "x1": 180.0, "z0": 0.0, "z1": 820.0}
const HELIPAD := {"x": 152.0, "z": 92.0}                             # helicopter pad
# Stock-exchange kiosk in the dead-centre downtown block — walk up and press E.
const EXCHANGE := {"x": 0.0, "z": -6.0}
# Car dealership kiosk, one block north of the exchange — walk up and press E.
const DEALERSHIP := {"x": 0.0, "z": 26.0}
# Stark lab kiosk (Iron Man suits), one block west of the exchange.
const STARK_LAB := {"x": -32.0, "z": -6.0}
# Realtor kiosk (safehouse property), one block east of the exchange.
const REALTOR := {"x": 32.0, "z": -6.0}

## True inside the grass airfield rectangle (runways + overrun + taxiways).
func on_airfield(x: float, z: float) -> bool:
	return x > AIRFIELD.x0 and x < AIRFIELD.x1 and z > AIRFIELD.z0 and z < AIRFIELD.z1

# Realistic city palette — concrete, stucco, slate, sandstone, weathered brick.
const PALETTE := [0x8a8a82, 0x9a8f7a, 0x6e7479, 0x7a6a58, 0x5f6b66, 0xa7a098, 0x55606b, 0x8a7256]
# Glassy blue-grey towers for the downtown core.
const DOWNTOWN_PALETTE := [0x3d4e63, 0x46586c, 0x33414f, 0x556375, 0x2f3d4c]
# Warm stucco tones for residential villas, plus tiled / slate roofs.
const VILLA_PALETTE := [0xd8cdb0, 0xc99878, 0xe3dcc8, 0xb8a888, 0xcdb89a, 0xa8b0a0]
const ROOF_PALETTE := [0x7a3b2e, 0x4a4a52, 0x6a4434, 0x8a4a38]
const PARK_BLOCKS := [Vector2i(5, 4), Vector2i(4, 8), Vector2i(3, 6)]
const RIVER_CX := -64.0              # the city river runs north-south here (block 3 centre)

var buildings: Array = []            # collision AABBs {x,z,w,d,h}
var lamp_mats: Array[StandardMaterial3D] = []
var window_mat: StandardMaterial3D
var beacon_mat: StandardMaterial3D
var sign_mat: StandardMaterial3D
var beacon_node: MeshInstance3D
var clouds: Array = []               # {node, drift}

var _window_xforms: Array[Transform3D] = []
var _road_mat: StandardMaterial3D
var _stripe_mat: StandardMaterial3D
var _sidewalk_mat: StandardMaterial3D

func generate() -> void:
	_road_mat = Build.mat(Build.hex(0x2c2c33), 0.85)
	_stripe_mat = Build.mat(Build.hex(0xd9c020), 0.85)
	_sidewalk_mat = Build.mat(Build.hex(0x9a9aa3), 0.9)
	window_mat = Build.emissive(Build.hex(0xb8a060), Build.hex(0xfff0b0), 0.0)
	window_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_add_ground()
	_build_city()
	_place_lamps()
	_build_airport()
	_add_mountains()
	_add_outer_landscape()
	_add_clouds(45)
	_build_window_multimesh()

func _add_ground() -> void:
	# Vast outer terrain so the world isn't boxed in by the city.
	var outer := Build.plane(OUTER_HALF * 2.0 + 240.0, OUTER_HALF * 2.0 + 240.0,
		Build.mat(Build.hex(0x6a7340), 0.95))
	outer.position = Vector3(0, -0.04, 0)
	add_child(outer)
	var ground := Build.plane(WORLD, WORLD, Build.mat(Build.hex(0x586b42), 0.9))
	add_child(ground)
	var ocean := Build.plane(OUTER_HALF * 2.0 + 600.0, 700.0,
		Build.mat(Build.hex(0x355767), 0.38, 0.22))
	ocean.position = Vector3(0, -0.02, WORLD_HALF + 320.0)
	add_child(ocean)
	var beach := Build.plane(WORLD, 30.0, Build.mat(Build.hex(0xd6c79c), 1.0))
	beach.position = Vector3(0, 0.01, WORLD_HALF - 5.0)
	add_child(beach)

func _add_road_strip(x: float, z: float, w: float, d: float) -> void:
	var sw := Build.box(w + 3.0, 0.04, d + 3.0, _sidewalk_mat)
	sw.position = Vector3(x, 0.02, z)
	add_child(sw)
	var r := Build.box(w, 0.05, d, _road_mat)
	r.position = Vector3(x, 0.04, z)
	add_child(r)
	if w > d:
		var i := -w / 2.0 + 2.0
		while i < w / 2.0 - 1.0:
			var s := Build.box(2.0, 0.06, 0.3, _stripe_mat)
			s.position = Vector3(x + i, 0.07, z)
			add_child(s)
			i += 4.0
	else:
		var j := -d / 2.0 + 2.0
		while j < d / 2.0 - 1.0:
			var s := Build.box(0.3, 0.06, 2.0, _stripe_mat)
			s.position = Vector3(x, 0.07, z + j)
			add_child(s)
			j += 4.0

func _add_building(x: float, z: float, w: float, d: float, h: float, color: int) -> void:
	var m := Build.box(w, h, d, Build.mat(Build.hex(color), 0.84, 0.04))
	m.position = Vector3(x, h / 2.0, z)
	add_child(m)
	# Window quads collected for one shared MultiMesh.
	var rows := int(h / 3.0)
	var cols_w := int(w / 2.0)
	var cols_d := int(d / 2.0)
	for r in rows:
		var y := 1.2 + r * 3.0
		if cols_w > 0:
			for c in cols_w:
				var wx := x - w / 2.0 + 0.6 + c * (w / float(cols_w))
				if randf() < 0.55:
					_window_xforms.append(Transform3D(Basis(), Vector3(wx, y, z + d / 2.0 + 0.03)))
				if randf() < 0.55:
					_window_xforms.append(Transform3D(Basis(Vector3.UP, PI), Vector3(wx, y, z - d / 2.0 - 0.03)))
		if cols_d > 0:
			for c in cols_d:
				var wz := z - d / 2.0 + 0.6 + c * (d / float(cols_d))
				if randf() < 0.55:
					_window_xforms.append(Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(x + w / 2.0 + 0.03, y, wz)))
				if randf() < 0.55:
					_window_xforms.append(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x - w / 2.0 - 0.03, y, wz)))
	buildings.append({"x": x, "z": z, "w": w, "d": d, "h": h})

func _build_city() -> void:
	for i in range(GRID + 1):
		_add_road_strip(-WORLD_HALF + i * BLOCK, 0.0, ROAD_W, WORLD)
	for i in range(GRID + 1):
		_add_road_strip(0.0, -WORLD_HALF + i * BLOCK, WORLD, ROAD_W)

	_build_river()

	# Each block belongs to a district — downtown skyline, commercial midtown,
	# residential villas, leafy hills, parks — for a Los-Angeles-style spread.
	for bx in GRID:
		for bz in GRID:
			var cx := -WORLD_HALF + bx * BLOCK + BLOCK / 2.0
			var cz := -WORLD_HALF + bz * BLOCK + BLOCK / 2.0
			if cz > WORLD_HALF - 30.0:
				continue                                 # beach kept clear
			if _in_airport_zone(cx, cz):
				continue                                 # airport island
			if bx == 5 and bz == 5:
				_build_exchange(cx, cz)                  # the stock exchange
				continue
			if bx == 5 and bz == 6:
				_build_dealership(cx, cz)                # the car dealership
				continue
			if bx == 4 and bz == 5:
				_build_stark_lab(cx, cz)                 # the Iron Man suit lab
				continue
			if bx == 6 and bz == 5:
				_build_realtor(cx, cz)                   # the safehouse realtor
				continue
			var house_idx := _safehouse_at(cx, cz)
			if house_idx >= 0:
				_build_safehouse(house_idx)              # a buyable safehouse
				continue
			match _district_of(cx, cz, bx, bz):
				"river":
					pass
				"hills":
					_build_hill_block(cx, cz)
				"park":
					_build_park(cx, cz)
				"downtown":
					_build_towers(cx, cz, true)
				"commercial":
					_build_towers(cx, cz, false)
				_:
					_add_villa(cx, cz)

	for i in 26:
		var x := (randf() - 0.5) * WORLD * 0.9
		var z := WORLD_HALF - 8.0 + (randf() - 0.5) * 14.0
		if _in_airport_zone(x, z):
			continue
		_add_palm(x, z)
	for i in 90:
		var x := (randf() - 0.5) * WORLD * 0.92
		var z := (randf() - 0.5) * WORLD * 0.85
		if _in_airport_zone(x, z) or absf(x - RIVER_CX) < 13.0:
			continue
		if collides_at(x, z, 1.5):
			continue
		# Distance to the nearest road centreline on each axis. A tree must sit
		# clear of the road AND its sidewalk — never on the tarmac.
		var fx := fmod(x + WORLD_HALF, BLOCK)
		var fz := fmod(z + WORLD_HALF, BLOCK)
		var dxl: float = minf(fx, BLOCK - fx)
		var dzl: float = minf(fz, BLOCK - fz)
		var off := ROAD_W / 2.0 + 3.0
		if dxl < off or dzl < off:
			continue
		_add_leafy_tree(x, z)


## Classifies a block into a city district.
func _district_of(cx: float, cz: float, bx: int, bz: int) -> String:
	if absf(cx - RIVER_CX) < 1.0:
		return "river"
	if bx <= 1 and bz <= 1:
		return "hills"
	for p in PARK_BLOCKS:
		if p.x == bx and p.y == bz:
			return "park"
	var d := sqrt(cx * cx + cz * cz)
	if d < 60.0:
		return "downtown"
	if d < 122.0:
		return "commercial"
	return "residential"


## Tall glassy towers downtown, mid-rise blocks in the commercial ring.
func _build_towers(cx: float, cz: float, downtown: bool) -> void:
	var usable := BLOCK - (ROAD_W + 1.0)
	var n := (1 + randi() % 3) if downtown else (2 + randi() % 2)
	for k in n:
		var w: float
		var d: float
		var h: float
		var col: int
		if downtown:
			w = 6.0 + randf() * 8.0
			d = 6.0 + randf() * 8.0
			h = 45.0 + randf() * 65.0
			col = DOWNTOWN_PALETTE.pick_random()
		else:
			w = 4.0 + randf() * 8.0
			d = 4.0 + randf() * 8.0
			h = 10.0 + randf() * 30.0
			col = PALETTE.pick_random()
		var px := cx + (randf() - 0.5) * (usable - w)
		var pz := cz + (randf() - 0.5) * (usable - d)
		_add_building(px, pz, w, d, h, col)


## The stock exchange — a glassy tower, a paved plaza, and a trading kiosk the
## player walks up to. The kiosk itself isn't a collider, so you can step right
## onto it; the tower behind it is solid.
func _build_exchange(cx: float, cz: float) -> void:
	var plaza_sz := BLOCK - ROAD_W
	var plaza := Build.box(plaza_sz, 0.14, plaza_sz, Build.mat(Build.hex(0x6d6e75), 0.9))
	plaza.position = Vector3(cx, 0.07, cz)
	add_child(plaza)
	var trim := Build.emissive(Build.hex(0x143028), Build.hex(0x3fd6a0), 1.0)
	for edge in [-1.0, 1.0]:
		var strip := Build.box(plaza_sz, 0.16, 0.5, trim)
		strip.position = Vector3(cx, 0.15, cz + edge * plaza_sz / 2.0)
		add_child(strip)

	# The exchange tower, set toward the back of the block.
	var tw := 15.0
	var td := 9.0
	var th := 66.0
	var tz := cz + 3.0
	var tower := Build.box(tw, th, td, Build.mat(Build.hex(0x2c3a4c), 0.3, 0.35))
	tower.position = Vector3(cx, th / 2.0 + 0.14, tz)
	add_child(tower)
	buildings.append({"x": cx, "z": tz, "w": tw, "d": td, "h": th})
	var band := Build.emissive(Build.hex(0x14242f), Build.hex(0x3fd6a0), 1.6)
	for by in [13.0, 28.0, 43.0, 58.0]:
		var stripe := Build.box(tw + 0.3, 1.0, td + 0.3, band)
		stripe.position = Vector3(cx, by, tz)
		add_child(stripe)
	var sign_panel := Build.emissive(Build.hex(0x0d1b16), Build.hex(0x4fe6b0), 2.4)
	var sign := Build.box(12.0, 3.6, 0.4, sign_panel)
	sign.position = Vector3(cx, th - 7.0, tz - td / 2.0 - 0.25)
	add_child(sign)
	var sign_text := Label3D.new()
	sign_text.text = "VICE BEACH\nEXCHANGE"
	sign_text.font_size = 84
	sign_text.pixel_size = 0.012
	sign_text.modulate = Color("06140f")
	sign_text.outline_size = 0
	sign_text.rotation.y = PI                                # face the plaza
	sign_text.position = Vector3(cx, th - 7.0, tz - td / 2.0 - 0.46)
	add_child(sign_text)

	_build_terminal_kiosk(EXCHANGE.x, EXCHANGE.z)


## A free-standing computer terminal — pedestal, angled glowing monitor, and a
## floating billboard prompt. Shared by the exchange and the dealership; the
## prompt text and glow colour identify which interaction point it is.
func _build_terminal_kiosk(x: float, z: float, prompt_text := "STOCKS  ·  PRESS E",
		screen_glow := Color("46e6a4"), prompt_color := Color("9ff0cf")) -> void:
	var dark := Build.mat(Build.hex(0x1c1f26), 0.5, 0.35)
	var base := Build.cyl(1.0, 1.2, 0.3, 16, dark)
	base.position = Vector3(x, 0.15, z)
	add_child(base)
	var pedestal := Build.box(1.3, 1.1, 0.8, dark)
	pedestal.position = Vector3(x, 0.85, z)
	add_child(pedestal)
	var screen_m := Build.emissive(Build.hex(0x0a1f1a), screen_glow, 2.8)
	var housing := Build.box(1.62, 1.14, 0.16, dark)
	housing.position = Vector3(x, 1.7, z - 0.04)
	housing.rotation.x = -0.32
	add_child(housing)
	var screen := Build.box(1.46, 0.98, 0.1, screen_m)
	screen.position = Vector3(x, 1.7, z + 0.02)
	screen.rotation.x = -0.32
	add_child(screen)
	var prompt := Label3D.new()
	prompt.text = prompt_text
	prompt.font_size = 56
	prompt.pixel_size = 0.006
	prompt.modulate = prompt_color
	prompt.outline_modulate = Color(0, 0, 0, 0.8)
	prompt.position = Vector3(x, 2.7, z)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(prompt)


## The car dealership — a glass-walled showroom with display cars lit up
## inside, a forecourt with more cars (one bonnet-up), and the trading kiosk.
## The showroom shell is solid; kiosk and display cars are walk-through.
func _build_dealership(cx: float, cz: float) -> void:
	var plaza_sz := BLOCK - ROAD_W
	var plaza := Build.box(plaza_sz, 0.14, plaza_sz, Build.mat(Build.hex(0x33343a), 0.92))
	plaza.position = Vector3(cx, 0.07, cz)
	add_child(plaza)
	var trim := Build.emissive(Build.hex(0x2e2410), Build.hex(0xe6a93f), 1.0)
	for edge in [-1.0, 1.0]:
		var strip := Build.box(plaza_sz, 0.16, 0.5, trim)
		strip.position = Vector3(cx, 0.15, cz + edge * plaza_sz / 2.0)
		add_child(strip)

	# --- Glass showroom toward the back of the block ---
	var sw := 16.0
	var sd := 11.0
	var wall_h := 5.6
	var sz := cz + 2.5
	var fz := sz - sd / 2.0                                  # glass front face

	var steel := Build.mat(Build.hex(0x9aa0a6), 0.4, 0.7)
	var floor := Build.emissive(Build.hex(0xb9bcc4), Build.hex(0x6a6e78), 0.5)
	var glass := Build.mat(Build.hex(0xbfe6ec), 0.05, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.34

	var plinth := Build.box(sw, 0.5, sd, Build.mat(Build.hex(0x2a2b30), 0.8))
	plinth.position = Vector3(cx, 0.25, sz)
	add_child(plinth)
	var floor_mi := Build.box(sw - 0.8, 0.1, sd - 0.8, floor)
	floor_mi.position = Vector3(cx, 0.52, sz)
	add_child(floor_mi)

	# Showroom shell — solid collision once, no matter how the glass is drawn.
	buildings.append({"x": cx, "z": sz, "w": sw, "d": sd, "h": wall_h})
	var back := Build.box(sw, wall_h, 0.4, Build.mat(Build.hex(0x3a3c44), 0.8))
	back.position = Vector3(cx, wall_h / 2.0 + 0.5, sz + sd / 2.0)
	add_child(back)
	for side in [-1.0, 1.0]:
		var sidewall := Build.box(0.3, wall_h - 0.4, sd - 0.5, glass)
		sidewall.position = Vector3(cx + side * sw / 2.0, wall_h / 2.0 + 0.7, sz)
		add_child(sidewall)
	var front_glass := Build.box(sw - 0.6, wall_h - 0.4, 0.3, glass)
	front_glass.position = Vector3(cx, wall_h / 2.0 + 0.7, fz)
	add_child(front_glass)
	# Steel posts at the corners and either side of the entrance.
	for px in [-sw / 2.0, -2.6, 2.6, sw / 2.0]:
		var post := Build.box(0.5, wall_h, 0.5, steel)
		post.position = Vector3(cx + px, wall_h / 2.0 + 0.5, fz)
		add_child(post)
	# Flat overhanging roof + a lit ceiling so the cars inside read clearly.
	var roof := Build.box(sw + 1.8, 0.55, sd + 1.8, Build.mat(Build.hex(0x303138), 0.85))
	roof.position = Vector3(cx, wall_h + 0.85, sz)
	add_child(roof)
	var ceiling := Build.emissive(Build.hex(0xfff4d8), Build.hex(0xfff4d8), 1.4)
	for cl in [-1.0, 0.0, 1.0]:
		var strip := Build.box(sw - 2.0, 0.15, 1.4, ceiling)
		strip.position = Vector3(cx, wall_h + 0.3, sz + cl * 3.0)
		add_child(strip)

	# Lit fascia + correctly-facing brand sign above the entrance.
	var fascia := Build.emissive(Build.hex(0x1b1305), Build.hex(0xffc861), 2.4)
	var band := Build.box(sw + 1.8, 1.7, 0.3, fascia)
	band.position = Vector3(cx, wall_h + 1.95, fz - 0.9)
	add_child(band)
	var sign_text := Label3D.new()
	sign_text.text = "VICE AUTOS"
	sign_text.font_size = 110
	sign_text.pixel_size = 0.011
	sign_text.modulate = Color("1b1305")
	sign_text.outline_size = 0
	sign_text.rotation.y = PI                                # face the forecourt
	sign_text.position = Vector3(cx, wall_h + 1.95, fz - 1.06)
	add_child(sign_text)

	# Two cars lit up inside on the raised showroom floor, two on the forecourt.
	_add_display_car(cx - 3.7, sz + 0.4, 0x9a9ca0, "hyper", false, PI - 0.5, 0.44)
	_add_display_car(cx + 3.7, sz + 0.4, 0x2b384e, "suv", false, PI + 0.5, 0.44)
	_add_display_car(cx - 5.6, cz - 6.5, 0xc23a3a, "sports", true, 0.5)
	_add_display_car(cx + 5.6, cz - 6.5, 0xdcdcda, "coupe", false, -0.5)

	_build_terminal_kiosk(DEALERSHIP.x, DEALERSHIP.z, "VEHICLES  ·  PRESS E",
		Color("ffc861"), Color("ffdca0"))


## A static showroom car on a low turntable pad. Uses the shared CarMesh so a
## display car looks exactly like the real thing the player buys. `lift` raises
## the whole thing onto the showroom's interior floor.
func _add_display_car(x: float, z: float, color: int, style: String,
		open_hood := false, yaw := 0.0, lift := 0.0) -> void:
	var pad := Build.cyl(2.05, 2.05, 0.16, 24, Build.mat(Build.hex(0x4a4b52), 0.5, 0.4))
	pad.position = Vector3(x, 0.21 + lift, z)
	add_child(pad)
	var car := CarMesh.build(color, style, open_hood)
	car.position = Vector3(x, 0.29 + lift, z)
	car.rotation.y = yaw
	add_child(car)


## The Stark lab — a sleek dark tower ringed with arc-reactor blue light, where
## the player buys Iron Man suit upgrades. Kiosk out front, tower solid.
func _build_stark_lab(cx: float, cz: float) -> void:
	var blue := Color("6fd8ff")
	var plaza_sz := BLOCK - ROAD_W
	var plaza := Build.box(plaza_sz, 0.14, plaza_sz, Build.mat(Build.hex(0x26282e), 0.85))
	plaza.position = Vector3(cx, 0.07, cz)
	add_child(plaza)
	var trim := Build.emissive(Build.hex(0x0c2230), blue, 1.2)
	for edge in [-1.0, 1.0]:
		var strip := Build.box(plaza_sz, 0.16, 0.5, trim)
		strip.position = Vector3(cx, 0.15, cz + edge * plaza_sz / 2.0)
		add_child(strip)

	var tw := 13.0
	var td := 10.0
	var th := 58.0
	var tz := cz + 3.0
	var tower := Build.box(tw, th, td, Build.mat(Build.hex(0x1d2026), 0.3, 0.6))
	tower.position = Vector3(cx, th / 2.0 + 0.14, tz)
	add_child(tower)
	buildings.append({"x": cx, "z": tz, "w": tw, "d": td, "h": th})
	var band := Build.emissive(Build.hex(0x0c2230), blue, 2.0)
	for by in [11.0, 24.0, 37.0, 50.0]:
		var stripe := Build.box(tw + 0.3, 0.8, td + 0.3, band)
		stripe.position = Vector3(cx, by, tz)
		add_child(stripe)
	# A glowing arc-reactor disc set into the tower face.
	var reactor := Build.emissive(Build.hex(0xeafcff), Color("d8f6ff"), 3.4)
	var disc := Build.cyl(2.4, 2.4, 0.3, 24, reactor)
	disc.rotation.x = PI / 2.0
	disc.position = Vector3(cx, 16.0, tz - td / 2.0 - 0.2)
	add_child(disc)
	var sign_text := Label3D.new()
	sign_text.text = "STARK\nINDUSTRIES"
	sign_text.font_size = 76
	sign_text.pixel_size = 0.013
	sign_text.modulate = Color("d8f6ff")
	sign_text.outline_modulate = Color(0, 0, 0, 0.8)
	sign_text.rotation.y = PI                                # face the plaza
	sign_text.position = Vector3(cx, th - 8.0, tz - td / 2.0 - 0.3)
	add_child(sign_text)

	_build_terminal_kiosk(STARK_LAB.x, STARK_LAB.z, "SUITS  ·  PRESS E",
		blue, Color("c8f0ff"))


## The realtor office — a low glass-and-stone building where the player buys
## safehouse deeds. Kiosk out front, office solid.
func _build_realtor(cx: float, cz: float) -> void:
	var teal := Color("7fd0c0")
	var plaza_sz := BLOCK - ROAD_W
	var plaza := Build.box(plaza_sz, 0.14, plaza_sz, Build.mat(Build.hex(0x595048), 0.9))
	plaza.position = Vector3(cx, 0.07, cz)
	add_child(plaza)
	var trim := Build.emissive(Build.hex(0x123028), teal, 1.0)
	for edge in [-1.0, 1.0]:
		var strip := Build.box(plaza_sz, 0.16, 0.5, trim)
		strip.position = Vector3(cx, 0.15, cz + edge * plaza_sz / 2.0)
		add_child(strip)

	var ow := 15.0
	var od := 9.0
	var oh := 13.0
	var oz := cz + 3.5
	var office := Build.box(ow, oh, od, Build.mat(Build.hex(0x8a7256), 0.7, 0.05))
	office.position = Vector3(cx, oh / 2.0 + 0.14, oz)
	add_child(office)
	buildings.append({"x": cx, "z": oz, "w": ow, "d": od, "h": oh})
	var glass := Build.mat(Build.hex(0x2a3a3a), 0.1, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.55
	var front := Build.box(ow - 2.0, oh - 3.0, 0.3, glass)
	front.position = Vector3(cx, oh / 2.0 + 0.6, oz - od / 2.0 - 0.16)
	add_child(front)
	var sign_panel := Build.emissive(Build.hex(0x0f221c), teal, 2.2)
	var sign := Build.box(12.0, 2.4, 0.4, sign_panel)
	sign.position = Vector3(cx, oh + 1.3, oz - od / 2.0 - 0.25)
	add_child(sign)
	var sign_text := Label3D.new()
	sign_text.text = "VICE REALTY"
	sign_text.font_size = 80
	sign_text.pixel_size = 0.013
	sign_text.modulate = Color("0f221c")
	sign_text.outline_size = 0
	sign_text.rotation.y = PI                                # face the plaza
	sign_text.position = Vector3(cx, oh + 1.3, oz - od / 2.0 - 0.46)
	add_child(sign_text)

	_build_terminal_kiosk(REALTOR.x, REALTOR.z, "PROPERTY  ·  PRESS E",
		teal, Color("c0eee2"))


## Index of the safehouse whose block centre is (cx, cz), or -1 if none.
func _safehouse_at(cx: float, cz: float) -> int:
	for i in PropertyCatalog.LIST.size():
		var p: Dictionary = PropertyCatalog.LIST[i]
		if is_equal_approx(cx, p.x) and is_equal_approx(cz, p.z):
			return i
	return -1


## A buyable safehouse — a tidy two-storey home with a lawn, driveway, a glowing
## doorway and a name sign. The respawn spot (PropertyCatalog x/z) is the front
## yard; the house sits just behind it so respawning never lands inside a wall.
func _build_safehouse(idx: int) -> void:
	var p: Dictionary = PropertyCatalog.LIST[idx]
	var fx: float = p.x
	var fz: float = p.z
	var hz := fz + 6.0                       # house centre, behind the front yard

	var lawn := Build.box(20.0, 0.12, 18.0, Build.mat(Build.hex(0x6f8a4e), 0.95))
	lawn.position = Vector3(fx, 0.06, fz + 3.0)
	add_child(lawn)
	var drive := Build.box(4.5, 0.14, 7.0, Build.mat(Build.hex(0x6b6b72), 0.9))
	drive.position = Vector3(fx, 0.08, fz - 1.0)
	add_child(drive)

	var hw := 10.0
	var hd := 8.0
	var hh := 7.5
	var house := Build.box(hw, hh, hd, Build.mat(Build.hex(0xe3dcc8), 0.85))
	house.position = Vector3(fx, hh / 2.0 + 0.14, hz)
	add_child(house)
	buildings.append({"x": fx, "z": hz, "w": hw, "d": hd, "h": hh})
	var roof := Build.box(hw + 1.0, 0.6, hd + 1.0, Build.mat(Build.hex(0x4a4a52), 0.8))
	roof.position = Vector3(fx, hh + 0.3, hz)
	add_child(roof)
	var upper := Build.box(hw - 3.0, 2.4, hd - 2.0, Build.mat(Build.hex(0xc99878), 0.85))
	upper.position = Vector3(fx, hh + 1.5, hz)
	add_child(upper)

	# Glowing doorway facing the front yard.
	var door := Build.emissive(Build.hex(0x2a2418), Color("ffd98a"), 1.6)
	var door_mi := Build.box(2.0, 3.4, 0.3, door)
	door_mi.position = Vector3(fx, 1.85, hz - hd / 2.0 - 0.1)
	add_child(door_mi)
	for wx in [-3.0, 3.0]:
		var win := Build.emissive(Build.hex(0x2a2a20), Color("fff0b0"), 0.8)
		var win_mi := Build.box(1.6, 1.6, 0.3, win)
		win_mi.position = Vector3(fx + wx, 2.4, hz - hd / 2.0 - 0.1)
		add_child(win_mi)

	var sign_text := Label3D.new()
	sign_text.text = p.name
	sign_text.font_size = 56
	sign_text.pixel_size = 0.01
	sign_text.modulate = Color("fff0c8")
	sign_text.outline_modulate = Color(0, 0, 0, 0.85)
	sign_text.position = Vector3(fx, hh + 3.6, hz - hd / 2.0)
	sign_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign_text)


## A residential villa — house, pitched roof, garage, pool, lawn and fence.
func _add_villa(cx: float, cz: float) -> void:
	var lawn := Build.box(18.0, 0.12, 16.0, Build.mat(Build.hex(0x6f8a4e), 0.95))
	lawn.position = Vector3(cx, 0.06, cz)
	add_child(lawn)
	var drive := Build.box(4.0, 0.14, 8.0, Build.mat(Build.hex(0x6b6b72), 0.9))
	drive.position = Vector3(cx - 5.0, 0.08, cz - 6.0)
	add_child(drive)

	var hw := 8.0 + randf() * 3.0
	var hd := 6.0 + randf() * 2.5
	var hh := 4.5 + randf() * 3.0
	var hx := cx + randf() * 2.0 - 1.0
	var hz := cz + randf() * 1.5
	var col: int = VILLA_PALETTE.pick_random()
	_add_building(hx, hz, hw, hd, hh, col)               # box + windows + collision

	var roof := Build.cyl(0.0, maxf(hw, hd) * 0.72, 2.6, 4,
		Build.mat(Build.hex(ROOF_PALETTE.pick_random()), 0.85))
	roof.position = Vector3(hx, hh + 1.3, hz)
	roof.rotation.y = PI / 4.0
	add_child(roof)

	var gw := 4.5
	var gx := hx + hw / 2.0 + gw / 2.0 - 0.5
	var garage := Build.box(gw, 3.2, 5.0, Build.mat(Build.hex(col), 0.85))
	garage.position = Vector3(gx, 1.6, hz - 1.0)
	add_child(garage)
	buildings.append({"x": gx, "z": hz - 1.0, "w": gw, "d": 5.0, "h": 3.2})

	var pool := Build.box(5.0, 0.2, 3.0, Build.mat(Build.hex(0x2f8fb0), 0.2, 0.3))
	pool.position = Vector3(cx + 4.0, 0.18, cz + 5.0)
	add_child(pool)

	var fence_m := Build.mat(Build.hex(0xb9b2a0), 0.8)
	for fz in [-8.0, 8.0]:
		var f := Build.box(17.0, 1.1, 0.3, fence_m)
		f.position = Vector3(cx, 0.7, cz + fz)
		add_child(f)
	for fx in [-9.0, 9.0]:
		var f := Build.box(0.3, 1.1, 16.0, fence_m)
		f.position = Vector3(cx + fx, 0.7, cz)
		add_child(f)

	_add_leafy_tree(cx - 6.0, cz + 5.0)


## A leafy hillside block — green mounds with a villa nestled among them.
func _build_hill_block(cx: float, cz: float) -> void:
	var hill_m := Build.mat(Build.hex(0x5f7a44), 0.95)
	for k in 2:
		var hr := 9.0 + randf() * 6.0
		var hh := 9.0 + randf() * 12.0
		var mound := Build.cyl(hr * 0.35, hr, hh, 8, hill_m)
		mound.position = Vector3(cx + (randf() - 0.5) * 10.0, hh / 2.0 - 1.0,
			cz + (randf() - 0.5) * 10.0)
		add_child(mound)
	_add_villa(cx, cz)
	_add_palm(cx + 7.0, cz - 6.0)
	_add_palm(cx - 7.0, cz + 6.0)


## A green park — lawn, pond, paths and trees.
func _build_park(cx: float, cz: float) -> void:
	var lawn := Build.box(BLOCK - ROAD_W, 0.12, BLOCK - ROAD_W,
		Build.mat(Build.hex(0x6a9048), 0.95))
	lawn.position = Vector3(cx, 0.06, cz)
	add_child(lawn)
	var pond := Build.cyl(4.5, 4.5, 0.25, 16, Build.mat(Build.hex(0x356d8a), 0.2, 0.3))
	pond.position = Vector3(cx + 3.0, 0.18, cz - 2.0)
	add_child(pond)
	var path_m := Build.mat(Build.hex(0xb6ad94), 0.9)
	var ph := Build.box(BLOCK - ROAD_W, 0.13, 2.4, path_m)
	ph.position = Vector3(cx, 0.1, cz)
	add_child(ph)
	var pv := Build.box(2.4, 0.13, BLOCK - ROAD_W, path_m)
	pv.position = Vector3(cx, 0.1, cz)
	add_child(pv)
	for k in 11:
		var tx := cx + (randf() - 0.5) * 13.0
		var tz := cz + (randf() - 0.5) * 13.0
		if Vector2(tx - cx - 3.0, tz - cz + 2.0).length() < 5.5:
			continue
		_add_leafy_tree(tx, tz)


## The city river plus the bridges that carry the cross-streets over it.
func _build_river() -> void:
	# The river is narrower than the gap between its two banking roads, so it
	# never floods onto the streets.
	var river_w := BLOCK - ROAD_W - 3.0
	var river := Build.plane(river_w, WORLD, Build.mat(Build.hex(0x356d8a), 0.3, 0.3))
	river.position = Vector3(RIVER_CX, 0.06, 0.0)
	add_child(river)
	var deck_m := Build.mat(Build.hex(0x3a3a42), 0.85)
	var rail_m := Build.mat(Build.hex(0x9a9aa3), 0.7)
	var pylon_m := Build.mat(Build.hex(0x6a6a72), 0.8)
	for i in range(GRID + 1):
		var z := -WORLD_HALF + i * BLOCK
		# Each bridge deck spans the full block, joining the roads on both banks.
		var deck := Build.box(BLOCK, 0.4, ROAD_W + 2.0, deck_m)
		deck.position = Vector3(RIVER_CX, 0.5, z)
		add_child(deck)
		for rz in [-(ROAD_W / 2.0 + 0.8), ROAD_W / 2.0 + 0.8]:
			var rail := Build.box(BLOCK, 1.0, 0.4, rail_m)
			rail.position = Vector3(RIVER_CX, 1.1, z + rz)
			add_child(rail)
		for px in [RIVER_CX - river_w / 2.0, RIVER_CX + river_w / 2.0]:
			var pylon := Build.cyl(0.7, 0.9, 3.0, 8, pylon_m)
			pylon.position = Vector3(px, 0.0, z)
			add_child(pylon)

func _add_palm(x: float, z: float) -> void:
	var trunk := Build.cyl(0.3, 0.4, 6.0, 8, Build.mat(Build.hex(0x6b4422), 0.95))
	trunk.position = Vector3(x, 3.0, z)
	add_child(trunk)
	var leaf_m := Build.mat(Build.hex(0x2ec96b), 0.7)
	for layer in 2:
		var ly := 6.5 - layer * 0.4
		var tilt := PI / (2.3 + layer * 0.4)
		for i in 7:
			var leaf := Build.cyl(0.0, 0.45, 3.2, 5, leaf_m)
			leaf.position = Vector3(x, ly, z)
			leaf.rotation.z = tilt
			leaf.rotation.y = float(i) / 7.0 * TAU + layer * 0.4
			leaf.translate_object_local(Vector3(0, -1.5, 0))
			add_child(leaf)
	buildings.append({"x": x, "z": z, "w": 0.8, "d": 0.8, "h": 6.0})

func _add_leafy_tree(x: float, z: float) -> void:
	var trunk := Build.cyl(0.25, 0.35, 3.0, 8, Build.mat(Build.hex(0x6b4422), 0.95))
	trunk.position = Vector3(x, 1.5, z)
	add_child(trunk)
	var foliage: int = [0x2c8a3a, 0x3aa84a, 0x1f6b2a].pick_random()
	var fm := Build.mat(Build.hex(foliage), 0.85)
	for j in 3:
		var r := 1.0 + randf() * 0.6
		var ball := Build.sphere(r, fm)
		ball.position = Vector3(x + (randf() - 0.5) * 0.6, 3.0 + j * 0.5 + randf() * 0.4, z + (randf() - 0.5) * 0.6)
		add_child(ball)
	buildings.append({"x": x, "z": z, "w": 0.7, "d": 0.7, "h": 3.0})

func _place_lamps() -> void:
	var pole_m := Build.mat(Build.hex(0x1a1a1a), 0.4, 0.7)
	for i in range(GRID + 1):
		for j in range(GRID + 1):
			if (i + j) % 2 != 0:
				continue
			var lx := -WORLD_HALF + i * BLOCK + ROAD_W / 2.0 + 1.2
			var lz := -WORLD_HALF + j * BLOCK + ROAD_W / 2.0 + 1.2
			if abs(lx) > WORLD_HALF or abs(lz) > WORLD_HALF:
				continue
			if _in_airport_zone(lx, lz):
				continue
			var pole := Build.cyl(0.08, 0.12, 5.0, 8, pole_m)
			pole.position = Vector3(lx, 2.5, lz)
			add_child(pole)
			var bulb_m := Build.emissive(Build.hex(0xffeac0), Build.hex(0xffeac0), 0.0)
			var bulb := Build.sphere(0.28, bulb_m)
			bulb.position = Vector3(lx, 4.85, lz + 0.55)
			add_child(bulb)
			lamp_mats.append(bulb_m)

## The whole south-east corner is the airport island — no city, lamps or trees.
func _in_airport_zone(x: float, z: float) -> bool:
	return x > 30.0 and z > 22.0

func _build_airport() -> void:
	var pole_m := Build.mat(Build.hex(0x1a1a1a), 0.4, 0.7)

	# --- Long flat grass airfield — the runways roll out over open field, with
	#     plenty of grass overrun ahead of every runway so a slow plane that
	#     doesn't lift off just trundles onto grass instead of crashing. ---
	var grass_w: float = AIRFIELD.x1 - AIRFIELD.x0
	var grass_d: float = AIRFIELD.z1 - AIRFIELD.z0
	var field := Build.plane(grass_w, grass_d, Build.mat(Build.hex(0x5f7a3e), 0.95))
	field.position = Vector3((AIRFIELD.x0 + AIRFIELD.x1) / 2.0, 0.05,
		(AIRFIELD.z0 + AIRFIELD.z1) / 2.0)
	add_child(field)

	# --- Paved apron pad by the terminal ---
	var pad := Build.plane(84.0, 84.0, Build.mat(Build.hex(0x9a9384), 0.92))
	pad.position = Vector3(84.0, 0.1, 80.0)               # x42..126, z38..122
	add_child(pad)

	# --- Causeway — the only land link from the city, raised over the water ---
	var causeway := Build.box(58.0, 0.4, 12.0, Build.mat(Build.hex(0x33343a), 0.9))
	causeway.position = Vector3(20.0, 0.2, 78.0)
	add_child(causeway)
	for rail_z in [72.4, 83.6]:
		var rail := Build.box(58.0, 1.0, 0.5, Build.mat(Build.hex(0x6a6e74), 0.5, 0.4))
		rail.position = Vector3(20.0, 0.75, rail_z)
		add_child(rail)
	var cw_dash_m := Build.mat(Build.hex(0xd9c020), 0.85)
	var cwx := -6.0
	while cwx < 46.0:
		var cwd := Build.box(2.4, 0.06, 0.3, cw_dash_m)
		cwd.position = Vector3(cwx, 0.41, 78.0)
		add_child(cwd)
		cwx += 5.0

	# --- Helipad — circular pad with a painted 'H' for the helicopter ---
	var helipad := Build.cyl(11.0, 11.0, 0.14, 28, Build.mat(Build.hex(0x383841), 0.92))
	helipad.position = Vector3(HELIPAD.x, 0.14, HELIPAD.z)
	add_child(helipad)
	var hpaint := Build.mat(Build.hex(0xe8e8e8), 0.85)
	for leg_dx in [-2.3, 2.3]:
		var leg := Build.box(1.4, 0.05, 7.0, hpaint)
		leg.position = Vector3(HELIPAD.x + leg_dx, 0.23, HELIPAD.z)
		add_child(leg)
	var crossbar := Build.box(3.2, 0.05, 1.6, hpaint)
	crossbar.position = Vector3(HELIPAD.x, 0.23, HELIPAD.z)
	add_child(crossbar)

	# --- Forecourt — paved drop-off where cars arrive in front of the terminal ---
	var court := Build.box(24.0, 0.06, 44.0, Build.mat(Build.hex(0x55555e), 0.9))
	court.position = Vector3(50.0, 0.14, 81.0)
	add_child(court)

	# --- Apron / taxiways between the terminal and the runways ---
	var apron := Build.box(58.0, 0.05, 86.0, Build.mat(Build.hex(0x4f4f58), 0.9))
	apron.position = Vector3(98.0, 0.12, 80.0)
	add_child(apron)

	_build_terminal(63.0, 81.0)
	_build_runway(RUNWAY_A.x, RUNWAY_A.z, RUNWAY_A.len, RUNWAY_A.w)
	_build_runway(RUNWAY_B.x, RUNWAY_B.z, RUNWAY_B.len, RUNWAY_B.w)
	_build_control_tower(84.0, 110.0)

	# --- Hangar ---
	var hangar := Build.box(11.0, 9.0, 14.0, Build.mat(Build.hex(0x6f747a), 0.9))
	hangar.position = Vector3(84.0, 4.5, 50.0)
	add_child(hangar)
	buildings.append({"x": 84.0, "z": 50.0, "w": 11.0, "d": 14.0, "h": 9.0})

	# --- Tall red beacon, visible across the bay ---
	beacon_mat = Build.emissive(Build.hex(0xff2244), Build.hex(0xff1133), 0.8)
	beacon_node = Build.sphere(2.4, beacon_mat)
	beacon_node.position = Vector3(122.0, 54.0, 46.0)
	add_child(beacon_node)
	var beacon_pole := Build.cyl(0.2, 0.35, 50.0, 8, pole_m)
	beacon_pole.position = Vector3(122.0, 25.0, 46.0)
	add_child(beacon_pole)

## A runway with centreline dashes, threshold bars and edge lights.
func _build_runway(rx: float, rz: float, rlen: float, rw: float) -> void:
	var runway := Build.box(rw, 0.06, rlen, Build.mat(Build.hex(0x2f3036), 0.92))
	runway.position = Vector3(rx, 0.16, rz)
	add_child(runway)
	var paint_m := Build.mat(Build.hex(0xe8e8e8), 0.85)
	var zz := -rlen / 2.0 + 8.0
	while zz < rlen / 2.0 - 5.0:
		var dash := Build.box(0.6, 0.04, 7.0, paint_m)
		dash.position = Vector3(rx, 0.2, rz + zz)
		add_child(dash)
		zz += 20.0
	for endd in [-1.0, 1.0]:
		for b in 5:
			var bar := Build.box(0.7, 0.04, 3.2, paint_m)
			bar.position = Vector3(rx - rw / 2.0 + 1.8 + b * (rw - 3.0) / 4.0,
				0.2, rz + endd * (rlen / 2.0 - 3.5))
			add_child(bar)
	var le := -rlen / 2.0 + 4.0
	while le < rlen / 2.0:
		for side in [-1.0, 1.0]:
			var lm := Build.emissive(Build.hex(0xffd9a0), Build.hex(0xffd9a0), 0.0)
			var lt := Build.box(0.4, 0.5, 0.4, lm)
			lt.position = Vector3(rx + side * (rw / 2.0 + 1.0), 0.3, rz + le)
			add_child(lt)
			lamp_mats.append(lm)
		le += 26.0

## A wall segment that also blocks the player (registered for collision).
func _wall(cx: float, cz: float, w: float, h: float, d: float, m: Material) -> void:
	var seg := Build.box(w, h, d, m)
	seg.position = Vector3(cx, h / 2.0 + 0.16, cz)
	add_child(seg)
	buildings.append({"x": cx, "z": cz, "w": w, "d": d, "h": h})

## Huge walkable terminal lobby — wide entrances west (forecourt) and east (apron).
func _build_terminal(tx: float, tz: float) -> void:
	var hw := 15.0
	var hd := 22.0
	var hh := 16.0
	var wall_m := Build.mat(Build.hex(0x8f9298), 0.8)
	var glass_m := Build.mat(Build.hex(0x2a3a4e), 0.1, 0.25)
	glass_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_m.albedo_color.a = 0.5

	var floor := Build.plane(hw * 2.0 - 1.0, hd * 2.0 - 1.0, Build.mat(Build.hex(0xc8c4b8), 0.7))
	floor.position = Vector3(tx, 0.18, tz)
	add_child(floor)
	var roof := Build.box(hw * 2.0, 0.5, hd * 2.0, wall_m)
	roof.position = Vector3(tx, hh, tz)
	add_child(roof)
	var skylight := Build.box(6.0, 0.6, hd * 2.0 - 8.0, glass_m)
	skylight.position = Vector3(tx, hh + 0.6, tz)
	add_child(skylight)

	# North & south walls solid; west/east walls have wide 14 m entrances.
	_wall(tx, tz + hd, hw * 2.0, hh, 1.0, wall_m)
	_wall(tx, tz - hd, hw * 2.0, hh, 1.0, wall_m)
	var wseg := (hd * 2.0 - 14.0) / 2.0
	_wall(tx - hw, tz - 7.0 - wseg / 2.0, 1.0, hh, wseg, glass_m)
	_wall(tx - hw, tz + 7.0 + wseg / 2.0, 1.0, hh, wseg, glass_m)
	_wall(tx + hw, tz - 7.0 - wseg / 2.0, 1.0, hh, wseg, wall_m)
	_wall(tx + hw, tz + 7.0 + wseg / 2.0, 1.0, hh, wseg, wall_m)

	for px in [tx - 7.0, tx + 7.0]:
		for k in 3:
			var pz := tz - 12.0 + k * 12.0
			var pil := Build.cyl(0.6, 0.7, hh, 12, wall_m)
			pil.position = Vector3(px, hh / 2.0 + 0.18, pz)
			add_child(pil)
			buildings.append({"x": px, "z": pz, "w": 1.4, "d": 1.4, "h": hh})

	for clx in [tx - 8.0, tx, tx + 8.0]:
		for k in 4:
			var clz := tz - 15.0 + k * 10.0
			var cm := Build.emissive(Build.hex(0xffeac0), Build.hex(0xffeac0), 0.0)
			var cl := Build.box(2.6, 0.2, 2.6, cm)
			cl.position = Vector3(clx, hh - 0.7, clz)
			add_child(cl)
			lamp_mats.append(cm)

	# Gold roof sign facing the forecourt
	sign_mat = Build.emissive(Build.hex(0xc2a05a), Build.hex(0xc2a05a), 0.4)
	for k in 8:
		var letter := Build.box(2.4, 2.0, 0.4, sign_mat)
		letter.position = Vector3(tx - 14.0 + k * 4.0, hh + 2.0, tz - hd)
		add_child(letter)

func _build_control_tower(cx: float, cz: float) -> void:
	var base_m := Build.mat(Build.hex(0x7d818a), 0.85)
	var tower := Build.box(7.0, 30.0, 7.0, base_m)
	tower.position = Vector3(cx, 15.0, cz)
	add_child(tower)
	buildings.append({"x": cx, "z": cz, "w": 7.0, "d": 7.0, "h": 30.0})
	var cab_m := Build.mat(Build.hex(0x243042), 0.1, 0.2)
	cab_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cab_m.albedo_color.a = 0.6
	var cabin := Build.box(10.0, 4.5, 10.0, cab_m)
	cabin.position = Vector3(cx, 32.0, cz)
	add_child(cabin)
	var cap := Build.box(10.6, 0.5, 10.6, base_m)
	cap.position = Vector3(cx, 34.5, cz)
	add_child(cap)

func _add_mountains() -> void:
	var mtn_m := Build.mat(Build.hex(0x5a6473), 1.0)
	var snow_m := Build.mat(Build.hex(0xd8dde2), 0.9)
	for i in 72:
		var ang := randf() * TAU
		var h := 60.0 + randf() * 175.0
		var r := 55.0 + randf() * 95.0
		# Offset the distance by the mountain's own radius so its base never
		# reaches into the city core — the near edge sits >=30 m past the city.
		var dist := WORLD_HALF + r + 30.0 + randf() * 260.0
		var x := cos(ang) * dist
		var z := sin(ang) * dist
		if z > WORLD_HALF + 20.0:        # keep the southern sea clear
			continue
		# Keep the grass airfield clear — no mountain may intrude on it.
		var ax := clampf(x, AIRFIELD.x0, AIRFIELD.x1)
		var az := clampf(z, AIRFIELD.z0, AIRFIELD.z1)
		if Vector2(x - ax, z - az).length() < r + 30.0:
			continue
		var m := Build.cyl(0.0, r, h, 7, mtn_m)
		m.position = Vector3(x, h / 2.0 - 12.0, z)
		add_child(m)
		if h > 150.0:
			var cap := Build.cyl(0.0, r * 0.3, h * 0.24, 7, snow_m)
			cap.position = Vector3(x, h - 12.0 - h * 0.12, z)
			add_child(cap)
		# Mountains inside the playable wilderness are solid to walk around.
		if dist < OUTER_HALF:
			buildings.append({"x": x, "z": z, "w": r * 1.1, "d": r * 1.1, "h": h})

## Hills, groves and rocks scattered across the wilderness around the city.
func _add_outer_landscape() -> void:
	for i in 110:
		var ang := randf() * TAU
		var dist := WORLD_HALF + 22.0 + randf() * (OUTER_HALF - WORLD_HALF - 36.0)
		var x := cos(ang) * dist
		var z := sin(ang) * dist
		if z > WORLD_HALF - 4.0:
			continue
		# Keep the grass airfield (and a margin around it) free of hills/trees.
		var fx := clampf(x, AIRFIELD.x0, AIRFIELD.x1)
		var fz := clampf(z, AIRFIELD.z0, AIRFIELD.z1)
		if Vector2(x - fx, z - fz).length() < 48.0:
			continue
		var pick := randi() % 3
		if pick == 0:
			var hr := 14.0 + randf() * 26.0
			var hh := 10.0 + randf() * 30.0
			var hill := Build.cyl(hr * 0.4, hr, hh, 8, Build.mat(Build.hex(0x5f7340), 0.95))
			hill.position = Vector3(x, hh / 2.0 - 3.0, z)
			add_child(hill)
		elif pick == 1:
			_add_leafy_tree(x, z)
		else:
			var rr := 2.0 + randf() * 5.0
			var rock := Build.cyl(rr * 0.7, rr, rr * 1.6, 6, Build.mat(Build.hex(0x6e6e74), 1.0))
			rock.position = Vector3(x, rr * 0.7, z)
			add_child(rock)

func _add_clouds(n: int) -> void:
	var cloud_m := Build.mat(Build.hex(0xd0d8e0), 1.0)
	cloud_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_m.albedo_color.a = 0.5
	for i in n:
		var cluster := Node3D.new()
		var lobes := 4 + (randi() % 5)
		for j in lobes:
			var r := 3.0 + randf() * 5.0
			var s := Build.sphere(r, cloud_m)
			s.position = Vector3((randf() - 0.5) * 14.0, (randf() - 0.5) * 2.0, (randf() - 0.5) * 14.0)
			cluster.add_child(s)
		cluster.position = Vector3((randf() - 0.5) * WORLD * 1.6, 55.0 + randf() * 35.0, (randf() - 0.5) * WORLD * 1.6)
		add_child(cluster)
		clouds.append({"node": cluster, "drift": 0.3 + randf() * 0.4})

func _build_window_multimesh() -> void:
	if _window_xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 1.4)
	mm.mesh = quad
	mm.instance_count = _window_xforms.size()
	for idx in _window_xforms.size():
		mm.set_instance_transform(idx, _window_xforms[idx])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = window_mat
	add_child(mmi)
	_window_xforms.clear()

func collides_at(x: float, z: float, r := 0.5, altitude := 0.0) -> bool:
	for b in buildings:
		if altitude > b.h + 2.0:
			continue
		if x > b.x - b.w / 2.0 - r and x < b.x + b.w / 2.0 + r \
			and z > b.z - b.d / 2.0 - r and z < b.z + b.d / 2.0 + r:
			return true
	# The grass airfield is solid ground its full length — never sea.
	if on_airfield(x, z):
		return false
	# The sea to the south is impassable on the ground, but planes fly over it.
	if z > WORLD_HALF + 5.0 and altitude < 5.0:
		return true
	if absf(x) > OUTER_HALF or z < -OUTER_HALF:
		return true                       # edge of the playable wilderness
	return false

func find_safe_spawn() -> Vector2:
	for r in range(0, 81):
		var tries: int = max(8, r * 3)
		for i in tries:
			var a := float(i) / float(tries) * TAU
			var dist := r * 1.2
			var x := cos(a) * dist
			var z := sin(a) * dist
			if not collides_at(x, z, 0.8):
				return Vector2(x, z)
	return Vector2.ZERO
