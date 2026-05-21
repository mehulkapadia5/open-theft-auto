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

# Airport island — a grass airfield in the bay south of the city, reached by a
# single causeway. Kept entirely clear of the city grid and the racing circuit.
const AIRPORT := {"x": 82.0, "z": 230.0}                             # waypoint = terminal forecourt
const RUNWAY_A := {"x": 172.0, "z": 475.0, "len": 500.0, "w": 16.0}  # main runway (big plane)
const RUNWAY_B := {"x": 215.0, "z": 460.0, "len": 420.0, "w": 10.0}  # secondary runway (small plane)
# Flat grass airfield the runways sit on — an island, solid ground amid the sea.
const AIRFIELD := {"x0": 30.0, "x1": 235.0, "z0": 195.0, "z1": 745.0}
const HELIPAD := {"x": 145.0, "z": 235.0}                            # helicopter pad
# Causeway corridor linking the city shore to the terminal — a walkable bay crossing.
const CAUSEWAY := {"x0": 70.0, "x1": 90.0, "z0": 160.0, "z1": 234.0}
# Stock-exchange kiosk in the dead-centre downtown block — walk up and press E.
const EXCHANGE := {"x": 0.0, "z": -6.0}
# Car dealership kiosk, one block north of the exchange — walk up and press E.
const DEALERSHIP := {"x": 0.0, "z": 26.0}
# Stark lab kiosk (Iron Man suits), one block west of the exchange.
const STARK_LAB := {"x": -32.0, "z": -6.0}
# Lit pad beside the Stark kiosk — a bought suit is delivered here to step onto.
const STARK_SUIT_PAD := {"x": -26.0, "z": -6.0}
# Realtor kiosk (safehouse property), one block east of the exchange.
const REALTOR := {"x": 32.0, "z": -6.0}

## True inside the grass airfield rectangle (runways + overrun + taxiways).
func on_airfield(x: float, z: float) -> bool:
	return x > AIRFIELD.x0 and x < AIRFIELD.x1 and z > AIRFIELD.z0 and z < AIRFIELD.z1

## True on the causeway deck bridging the bay to the airport island.
func _on_causeway(x: float, z: float) -> bool:
	return x > CAUSEWAY.x0 and x < CAUSEWAY.x1 and z > CAUSEWAY.z0 and z < CAUSEWAY.z1

## True where a boat can float — the city river and the open sea — but not on
## the airport island or its causeway.
func on_water(x: float, z: float) -> bool:
	if on_airfield(x, z) or _on_causeway(x, z):
		return false
	if _on_estate(x, z) or _on_estate_causeway(x, z):
		return false
	# The river channel, running the city's length and out into the bay.
	if absf(x - RIVER_CX) < RIVER_HALF and z > -WORLD_HALF + 2.0 and z < WORLD_HALF + 14.0:
		return true
	# Open sea south of the shoreline.
	if z > WORLD_HALF + 4.0:
		return true
	return false

## True on the President's estate island.
func _on_estate(x: float, z: float) -> bool:
	return x > ESTATE_GROUNDS.x0 and x < ESTATE_GROUNDS.x1 \
		and z > ESTATE_GROUNDS.z0 and z < ESTATE_GROUNDS.z1

## True on the short causeway linking the estate to the airport island.
func _on_estate_causeway(x: float, z: float) -> bool:
	return x > ESTATE_CAUSEWAY.x0 and x < ESTATE_CAUSEWAY.x1 \
		and z > ESTATE_CAUSEWAY.z0 and z < ESTATE_CAUSEWAY.z1

## The board point of the dock nearest a position (Vector3.INF if there are none).
func nearest_dock(pos: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for d in docks:
		var dd: float = Vector2(d.board.x - pos.x, d.board.z - pos.z).length()
		if dd < bd:
			bd = dd
			best = d.board
	return best

## Height of an elevated bridge deck for a given distance from the river centre
## — flat over the channel, ramping down to road level on each bank.
func _bridge_profile(x: float) -> float:
	var d := absf(x - RIVER_CX)
	if d >= 26.0:
		return 0.0
	if d <= 10.0:
		return BRIDGE_H
	return BRIDGE_H * (26.0 - d) / 16.0

## Height of the walkable surface at a point — 0 on flat ground, raised on the
## elevated river bridges and the dock jetties. Cars and the player ride this.
func surface_height(x: float, z: float) -> float:
	var h := 0.0
	# While the office is occupied, lift the player onto its floor — it sits
	# high over the bay, far from any normal walkable ground.
	if trading_floor_active:
		var tf := TRADING_FLOOR
		if absf(x - tf.x) < 11.5 and absf(z - tf.z) < 8.5:
			return tf.y
	if absf(x - RIVER_CX) < 26.0:
		for i in range(GRID + 1):
			var gz: float = -WORLD_HALF + i * BLOCK
			if absf(z - gz) < (ROAD_W + 2.0) / 2.0:
				h = maxf(h, _bridge_profile(x))
				break
	for d in _dock_rects:
		if x > d.x - d.w / 2.0 and x < d.x + d.w / 2.0 \
			and z > d.z - d.d / 2.0 and z < d.z + d.d / 2.0:
			h = maxf(h, 0.55)
	return h

# Realistic city palette — concrete, stucco, slate, sandstone, weathered brick.
const PALETTE := [0x8a8a82, 0x9a8f7a, 0x6e7479, 0x7a6a58, 0x5f6b66, 0xa7a098, 0x55606b, 0x8a7256]
# Glassy blue-grey towers for the downtown core.
const DOWNTOWN_PALETTE := [0x3d4e63, 0x46586c, 0x33414f, 0x556375, 0x2f3d4c]
# Warm stucco tones for residential villas, plus tiled / slate roofs.
const VILLA_PALETTE := [0xd8cdb0, 0xc99878, 0xe3dcc8, 0xb8a888, 0xcdb89a, 0xa8b0a0]
const ROOF_PALETTE := [0x7a3b2e, 0x4a4a52, 0x6a4434, 0x8a4a38]
const PARK_BLOCKS := [Vector2i(5, 4), Vector2i(4, 8), Vector2i(3, 6)]
const RIVER_CX := -64.0              # the city river runs north-south here (block 3 centre)
const RIVER_HALF := 8.0              # half-width of the navigable river channel
const BRIDGE_H := 4.2                # deck height of the elevated river bridges
# The President's estate — a large gated compound on its own island in the bay,
# just west of the airport and reached by a short causeway off the airport.
const ESTATE_GROUNDS := {"x0": -135.0, "x1": 18.0, "z0": 252.0, "z1": 470.0}
const ESTATE_CAUSEWAY := {"x0": 14.0, "x1": 34.0, "z0": 330.0, "z1": 350.0}
const PRESIDENT_HOUSE := {"x": -46.0, "z": 300.0}   # the mansion (motorcade origin)
# Vice Space launch complex — in the north wilderness, clear of the F1 circuit.
const LAUNCH := {"x": 210.0, "z": -250.0}
# The Moon — a grey surface built high above the world; the rocket flies up to it.
const MOON_Y := 4000.0
const MOON_PAD := {"x": 0.0, "z": 0.0}
# The exchange trading floor — an enterable glass penthouse crowning the stock
# exchange tower (block 5,5: tower centred at x0, z3, roof at y66). Reached by
# teleport from the kiosk; floor and walls only affect the player while occupied.
const TRADING_FLOOR := {"x": 0.0, "z": 3.0, "y": 66.4}
const OFFICE_EXIT := {"x": 0.0, "z": -0.5}    # exit pad, and the arrival point
const OFFICE_DESK := {"x": 0.0, "z": 8.0}     # standing spot in front of the desk

var buildings: Array = []            # collision AABBs {x,z,w,d,h}
var docks: Array = []                # {board: Vector3 water-end, dir: Vector2}
var _dock_rects: Array = []          # walkable pier footprints {x,z,w,d}
var trading_floor_active := false    # true only while the player is in the office
var _office_root: Node3D             # parent of all trading-floor geometry
var _office_walls: Array = []        # interior collision rects {x,z,w,d}
var track: Track                     # the F1 circuit looping the wilderness
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
	_build_beach()
	_build_presidential_residence()
	_build_docks()
	_build_launch_base()
	_build_moon()
	_build_trading_floor()
	track = Track.new()
	add_child(track)
	track.build()
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


## Vice Space launch complex — a pad, gantry tower, fuel tanks and a sign. The
## rocket itself is a flyable vehicle spawned by Game.
func _build_launch_base() -> void:
	var cx: float = LAUNCH.x
	var cz: float = LAUNCH.z
	var concrete := Build.mat(Build.hex(0x8e9298), 0.9)
	var dark := Build.mat(Build.hex(0x33363d), 0.7)
	var metal := Build.mat(Build.hex(0xb4b8be), 0.3, 0.7)

	var apron := Build.box(72.0, 0.3, 72.0, concrete)
	apron.position = Vector3(cx, 0.15, cz)
	add_child(apron)
	var pad := Build.cyl(9.0, 9.0, 0.6, 24, dark)
	pad.position = Vector3(cx, 0.5, cz)
	add_child(pad)

	# Service / gantry tower beside the pad.
	var tx := cx + 14.0
	for ly in range(7):
		var ring := Build.box(5.4, 0.5, 5.4, metal)
		ring.position = Vector3(tx, 4.0 + ly * 7.0, cz)
		add_child(ring)
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			var leg := Build.box(0.7, 48.0, 0.7, dark)
			leg.position = Vector3(tx + lx * 2.4, 24.0, cz + lz * 2.4)
			add_child(leg)
	buildings.append({"x": tx, "z": cz, "w": 6.0, "d": 6.0, "h": 48.0})

	# Fuel tanks.
	for i in 3:
		var tank := Build.cyl(3.2, 3.2, 14.0, 16, metal)
		tank.position = Vector3(cx - 24.0, 7.0, cz - 16.0 + i * 16.0)
		add_child(tank)
		buildings.append({"x": cx - 24.0, "z": cz - 16.0 + i * 16.0,
			"w": 6.4, "d": 6.4, "h": 14.0})

	var sign := Label3D.new()
	sign.text = "VICE SPACE"
	sign.font_size = 130
	sign.pixel_size = 0.02
	sign.modulate = Color("e8e6e0")
	sign.outline_modulate = Color(0, 0, 0, 0.85)
	sign.position = Vector3(cx, 6.5, cz + 32.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)


## The Moon — a grey cratered surface built high above the world. The rocket
## flies up here; the player walks the surface in low gravity.
func _build_moon() -> void:
	var my: float = MOON_Y
	var mx: float = MOON_PAD.x
	var mz: float = MOON_PAD.z
	var grey := Build.mat(Build.hex(0x9c9ca0), 1.0)
	var dgrey := Build.mat(Build.hex(0x7a7a80), 1.0)

	var surf := Build.cyl(340.0, 340.0, 4.0, 40, grey)
	surf.position = Vector3(mx, my - 2.0, mz)
	add_child(surf)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1969
	for i in 44:
		var a := rng.randf() * TAU
		var d := rng.randf() * 300.0
		var cr := 6.0 + rng.randf() * 22.0
		var crater := Build.cyl(cr, cr * 1.3, 1.8, 14, dgrey)
		crater.position = Vector3(mx + cos(a) * d, my + 0.2, mz + sin(a) * d)
		add_child(crater)
	for i in 32:
		var a2 := rng.randf() * TAU
		var d2 := rng.randf() * 310.0
		var rr := 1.5 + rng.randf() * 3.4
		var rock := Build.cyl(rr * 0.7, rr, rr * 1.4, 6, dgrey)
		rock.position = Vector3(mx + cos(a2) * d2, my + rr * 0.7, mz + sin(a2) * d2)
		add_child(rock)

	# Earth hanging in the black sky.
	var earth_m := Build.emissive(Build.hex(0x2f6cb4), Build.hex(0x3f86d0), 0.7)
	var earth := Build.sphere(74.0, earth_m)
	earth.position = Vector3(mx + 130.0, my + 190.0, mz - 380.0)
	add_child(earth)

	# Landing pad.
	var lpad := Build.cyl(11.0, 11.0, 0.5, 24, Build.mat(Build.hex(0x45494f), 0.8))
	lpad.position = Vector3(mx, my + 0.4, mz)
	add_child(lpad)
	var flag_pole := Build.cyl(0.12, 0.12, 6.0, 6, Build.mat(Build.hex(0xcfd2d6), 0.4))
	flag_pole.position = Vector3(mx + 8.0, my + 3.0, mz + 6.0)
	add_child(flag_pole)
	var flag := Build.box(0.1, 1.7, 2.8, Build.mat(Build.hex(0xc23a3a), 0.6))
	flag.position = Vector3(mx + 8.0, my + 5.0, mz + 7.4)
	add_child(flag)

	_build_moon_base(mx, mz - 60.0, my)
	# A loop of glowing gates — the low-gravity buggy course.
	var gate_m := Build.emissive(Build.hex(0x14303a), Color("4fd6ff"), 2.4)
	for gi in 9:
		var ga := gi * TAU / 9.0
		var gd := 150.0 + sin(gi * 1.7) * 40.0
		var gx := mx + cos(ga) * gd
		var gz := mz + sin(ga) * gd
		for gpost in [-4.0, 4.0]:
			var post := Build.box(0.7, 7.0, 0.7, gate_m)
			post.position = Vector3(gx + cos(ga + PI / 2.0) * gpost, my + 3.5,
				gz + sin(ga + PI / 2.0) * gpost)
			add_child(post)
		var bar := Build.box(9.0, 0.7, 0.7, gate_m)
		bar.position = Vector3(gx, my + 7.0, gz)
		bar.rotation.y = ga + PI / 2.0
		add_child(bar)


## A lunar outpost — habitat domes, modules, solar arrays and a comms dish.
func _build_moon_base(bx: float, bz: float, by: float) -> void:
	var white := Build.mat(Build.hex(0xe4e6ea), 0.6)
	var dark := Build.mat(Build.hex(0x2a2d33), 0.6)
	var glass := Build.mat(Build.hex(0x9fd6e6), 0.15, 0.4)
	var solar := Build.emissive(Build.hex(0x16243f), Color("3a6fb0"), 0.5)

	# Two habitat domes.
	for dome_dx in [-14.0, 14.0]:
		var base_cyl := Build.cyl(7.0, 7.0, 3.4, 20, white)
		base_cyl.position = Vector3(bx + dome_dx, by + 1.7, bz)
		add_child(base_cyl)
		var dome := Build.sphere(7.0, glass)
		dome.position = Vector3(bx + dome_dx, by + 3.4, bz)
		add_child(dome)
	# Connecting module + airlock.
	var tube := Build.cyl(1.6, 1.6, 18.0, 12, white)
	tube.rotation.z = PI / 2.0
	tube.position = Vector3(bx, by + 1.8, bz)
	add_child(tube)
	var hub := Build.box(6.0, 4.0, 6.0, white)
	hub.position = Vector3(bx, by + 2.0, bz - 11.0)
	add_child(hub)
	var hub_door := Build.emissive(Build.hex(0x2a2418), Color("ffd98a"), 1.4)
	var door := Build.box(2.0, 3.0, 0.3, hub_door)
	door.position = Vector3(bx, by + 1.5, bz - 14.05)
	add_child(door)
	# Solar arrays.
	for sa in [-1.0, 1.0]:
		for col in 3:
			var panel := Build.box(5.0, 0.2, 3.4, solar)
			panel.position = Vector3(bx + sa * 26.0, by + 3.0, bz - 8.0 + col * 4.2)
			panel.rotation.x = -0.5
			add_child(panel)
		var mast := Build.cyl(0.3, 0.3, 6.0, 6, dark)
		mast.position = Vector3(bx + sa * 26.0, by + 3.0, bz)
		add_child(mast)
	# Comms dish.
	var dish_mast := Build.cyl(0.4, 0.5, 9.0, 8, dark)
	dish_mast.position = Vector3(bx, by + 4.5, bz + 12.0)
	add_child(dish_mast)
	var dish := Build.cyl(0.3, 3.6, 1.6, 14, white)
	dish.rotation.x = -1.0
	dish.position = Vector3(bx, by + 9.5, bz + 12.0)
	add_child(dish)
	var sign := Label3D.new()
	sign.text = "VICE  MOON  BASE"
	sign.font_size = 100
	sign.pixel_size = 0.02
	sign.modulate = Color("cfe8ff")
	sign.outline_modulate = Color(0, 0, 0, 0.85)
	sign.position = Vector3(bx, by + 9.0, bz)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)


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
	# North-south roads run the full length (none lie on the river).
	for i in range(GRID + 1):
		_add_road_strip(-WORLD_HALF + i * BLOCK, 0.0, ROAD_W, WORLD)
	# East-west cross-streets are gapped over the river — the elevated bridge
	# carries the road across, leaving open water beneath it for boats.
	var gap_l := RIVER_CX - 26.0
	var gap_r := RIVER_CX + 26.0
	for i in range(GRID + 1):
		var rz := -WORLD_HALF + i * BLOCK
		var left_w := gap_l + WORLD_HALF
		_add_road_strip(-WORLD_HALF + left_w / 2.0, rz, left_w, ROAD_W)
		var right_w := WORLD_HALF - gap_r
		_add_road_strip(gap_r + right_w / 2.0, rz, right_w, ROAD_W)

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
			if _in_estate(cx, cz) >= 0:
				continue                                 # reserved estate grounds
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


## Shows or hides the trading-floor office and arms its floor + wall collision.
func set_trading_floor(active: bool) -> void:
	trading_floor_active = active
	if _office_root != null:
		_office_root.visible = active


## A glass penthouse crowning the stock exchange tower. The player teleports up
## from the exchange kiosk into a skyline lounge, walks through a glass partition
## into the trading room, and trades at a wall of live monitors. Hidden until
## entered — see set_trading_floor.
func _build_trading_floor() -> void:
	var ox: float = TRADING_FLOOR.x
	var oz: float = TRADING_FLOOR.z
	var oy: float = TRADING_FLOOR.y
	var hw := 11.0           # half-width  (x)
	var hd := 8.0            # half-depth  (z)
	var ceil_h := 3.8        # floor-to-ceiling height

	_office_root = Node3D.new()
	_office_root.visible = false
	add_child(_office_root)

	var glass := Build.mat(Build.hex(0xbfe6ec), 0.04, 0.2)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.18
	var frame := Build.mat(Build.hex(0x10141c), 0.35, 0.85)
	var floor_mat := Build.mat(Build.hex(0x1b2026), 0.18, 0.5)
	var desk_mat := Build.mat(Build.hex(0x14181e), 0.3, 0.4)

	# Floor slab (overhangs the tower as a cantilevered crown), carpet, ceiling.
	var slab := Build.box(hw * 2.0 + 1.2, 0.6, hd * 2.0 + 1.2, frame)
	slab.position = Vector3(ox, oy - 0.42, oz)
	_office_root.add_child(slab)
	var deck := Build.box(hw * 2.0, 0.12, hd * 2.0, floor_mat)
	deck.position = Vector3(ox, oy - 0.06, oz)
	_office_root.add_child(deck)
	var rug := Build.emissive(Build.hex(0x10242b), Build.hex(0x2f6f6a), 0.5)
	var carpet := Build.box(hw * 2.0 - 3.0, 0.06, hd * 2.0 - 3.0, rug)
	carpet.position = Vector3(ox, oy + 0.03, oz)
	_office_root.add_child(carpet)
	var ceiling := Build.box(hw * 2.0 + 1.0, 0.4, hd * 2.0 + 1.0, frame)
	ceiling.position = Vector3(ox, oy + ceil_h + 0.2, oz)
	_office_root.add_child(ceiling)
	var panel := Build.emissive(Build.hex(0xeaf6ff), Build.hex(0xeaf6ff), 1.6)
	for cl in [-5.0, -1.7, 1.7, 5.0]:
		var strip := Build.box(hw * 2.0 - 3.0, 0.12, 0.8, panel)
		strip.position = Vector3(ox, oy + ceil_h - 0.1, oz + cl)
		_office_root.add_child(strip)

	# Perimeter glass curtain wall — front faces the city skyline.
	var wall_specs := [
		{"x": ox,      "z": oz - hd, "w": hw * 2.0, "d": 0.3},
		{"x": ox,      "z": oz + hd, "w": hw * 2.0, "d": 0.3},
		{"x": ox - hw, "z": oz,      "w": 0.3,      "d": hd * 2.0},
		{"x": ox + hw, "z": oz,      "w": 0.3,      "d": hd * 2.0},
	]
	for ws in wall_specs:
		var pane := Build.box(ws.w, ceil_h - 0.5, ws.d, glass)
		pane.position = Vector3(ws.x, oy + (ceil_h - 0.5) / 2.0 + 0.25, ws.z)
		_office_root.add_child(pane)
		var sill := Build.box(ws.w, 0.25, ws.d + 0.15, frame)
		sill.position = Vector3(ws.x, oy + 0.12, ws.z)
		_office_root.add_child(sill)
		var head := Build.box(ws.w, 0.22, ws.d + 0.15, frame)
		head.position = Vector3(ws.x, oy + ceil_h - 0.1, ws.z)
		_office_root.add_child(head)
		_office_walls.append(ws)
	# Vertical mullions break up the skyline-facing wall.
	for mx in [-7.5, -3.5, 3.5, 7.5]:
		var mull := Build.box(0.2, ceil_h - 0.4, 0.4, frame)
		mull.position = Vector3(ox + mx, oy + (ceil_h - 0.4) / 2.0 + 0.2, oz - hd)
		_office_root.add_child(mull)

	# Glass partition splitting the lounge (front) from the trading room (back),
	# leaving a 4-wide doorway at the centre.
	var pz := oz + 1.5
	for seg in [-6.5, 6.5]:
		var part := Build.box(9.0, ceil_h - 0.5, 0.25, glass)
		part.position = Vector3(ox + seg, oy + (ceil_h - 0.5) / 2.0 + 0.25, pz)
		_office_root.add_child(part)
		var pframe := Build.box(9.0, 0.2, 0.4, frame)
		pframe.position = Vector3(ox + seg, oy + ceil_h - 0.15, pz)
		_office_root.add_child(pframe)
		_office_walls.append({"x": ox + seg, "z": pz, "w": 9.0, "d": 0.25})
	for dx in [-2.0, 2.0]:
		var jamb := Build.box(0.3, ceil_h - 0.4, 0.5, frame)
		jamb.position = Vector3(ox + dx, oy + (ceil_h - 0.4) / 2.0 + 0.2, pz)
		_office_root.add_child(jamb)

	# Trading desk against the back wall, topped with an emissive ledge.
	var desk_z := oz + hd - 1.5
	var desk := Build.box(17.5, 1.0, 1.3, desk_mat)
	desk.position = Vector3(ox, oy + 0.6, desk_z)
	_office_root.add_child(desk)
	var ledge := Build.emissive(Build.hex(0x1c2730), Build.hex(0x39c0a8), 0.6)
	var top := Build.box(17.9, 0.12, 1.6, ledge)
	top.position = Vector3(ox, oy + 1.12, desk_z)
	_office_root.add_child(top)

	# A wall of glowing monitors above the desk — two stacked rows.
	var mon_colors := [0x39e0a0, 0x39e0a0, 0xe0b13a, 0x39e0a0,
		0xe05a4a, 0x39e0a0, 0x4aa8e0, 0xe0b13a]
	var ci := 0
	for row in [2.05, 3.0]:
		for col in range(-6, 7, 2):
			var glow: int = mon_colors[ci % mon_colors.size()]
			ci += 1
			var bezel := Build.box(1.9, 0.86, 0.12, frame)
			bezel.position = Vector3(ox + col, oy + row, oz + hd - 0.3)
			_office_root.add_child(bezel)
			var scr := Build.emissive(Build.hex(0x081016), Build.hex(glow), 2.6)
			var screen := Build.box(1.68, 0.7, 0.08, scr)
			screen.position = Vector3(ox + col, oy + row, oz + hd - 0.22)
			_office_root.add_child(screen)

	# Lounge benches by the skyline window.
	for bx in [-6.0, 6.0]:
		var bench := Build.box(3.0, 0.5, 1.1, desk_mat)
		bench.position = Vector3(ox + bx, oy + 0.31, oz - hd + 2.2)
		_office_root.add_child(bench)

	# Exit pad in the lounge — step on, press E to drop back to the street.
	var pad_mat := Build.emissive(Build.hex(0x0c2a22), Build.hex(0x46e6a4), 2.4)
	var pad := Build.cyl(1.5, 1.5, 0.12, 24, pad_mat)
	pad.position = Vector3(OFFICE_EXIT.x, oy + 0.08, OFFICE_EXIT.z)
	_office_root.add_child(pad)
	_office_root.add_child(_office_label("EXIT TO STREET  ·  PRESS E",
		Vector3(OFFICE_EXIT.x, oy + 1.7, OFFICE_EXIT.z), Color("9ff0cf")))

	# Trade prompt floating in front of the monitor desk.
	_office_root.add_child(_office_label("TRADE STOCKS  ·  PRESS E",
		Vector3(OFFICE_DESK.x, oy + 1.7, OFFICE_DESK.z), Color("9ff0cf")))

	# Branding on the inside of the skyline wall.
	var title := Label3D.new()
	title.text = "VICE BEACH EXCHANGE"
	title.font_size = 64
	title.pixel_size = 0.008
	title.modulate = Color("cdeee2")
	title.outline_modulate = Color(0, 0, 0, 0.8)
	title.position = Vector3(ox, oy + ceil_h - 0.55, oz - hd + 0.35)
	_office_root.add_child(title)


## A floating billboard prompt used inside the trading-floor office.
func _office_label(text: String, pos: Vector3, color: Color) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 52
	lbl.pixel_size = 0.006
	lbl.modulate = color
	lbl.outline_modulate = Color(0, 0, 0, 0.8)
	lbl.position = pos
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return lbl


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
	_add_display_car(cx - 5.6, cz - 6.5, 0xc0392b, "f1", false, 0.5)
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
## A static armoured figure for the Stark showroom — posed standing, faces +Z.
func _build_display_suit(primary: int, secondary: int, dk: int, big: bool) -> Node3D:
	var g := Node3D.new()
	var pm := Build.mat(Build.hex(primary), 0.35, 0.55)
	var sm := Build.mat(Build.hex(secondary), 0.3, 0.7)
	var dm := Build.mat(Build.hex(dk), 0.5, 0.5)
	var glow := Build.emissive(Build.hex(0x9fe9ff), Build.hex(0x9fe9ff), 4.0)
	var eyeglow := Build.emissive(Build.hex(0xeaffff), Build.hex(0xd6f4ff), 4.0)
	for lx in [-0.22, 0.22]:
		var thigh := Build.box(0.32, 0.52, 0.34, pm)
		thigh.position = Vector3(lx, 0.74, 0)
		g.add_child(thigh)
		var shin := Build.box(0.3, 0.5, 0.32, sm)
		shin.position = Vector3(lx, 0.26, 0)
		g.add_child(shin)
		var boot := Build.box(0.32, 0.16, 0.48, pm)
		boot.position = Vector3(lx, 0.08, 0.07)
		g.add_child(boot)
	var pelvis := Build.box(0.56, 0.26, 0.36, dm)
	pelvis.position.y = 1.06
	g.add_child(pelvis)
	var torso := Build.box(0.74, 0.78, 0.44, pm)
	torso.position.y = 1.46
	g.add_child(torso)
	var abdomen := Build.box(0.58, 0.28, 0.4, sm)
	abdomen.position.y = 1.12
	g.add_child(abdomen)
	var reactor := Build.cyl(0.13, 0.13, 0.1, 14, glow)
	reactor.rotation.x = PI / 2.0
	reactor.position = Vector3(0, 1.6, 0.23)
	g.add_child(reactor)
	var shoulders := Build.box(1.04, 0.28, 0.48, pm)
	shoulders.position.y = 1.84
	g.add_child(shoulders)
	for ax in [-1.0, 1.0]:
		var upper := Build.box(0.24, 0.5, 0.24, pm)
		upper.position = Vector3(ax * 0.62, 1.55, 0)
		g.add_child(upper)
		var fore := Build.box(0.22, 0.46, 0.22, sm)
		fore.position = Vector3(ax * 0.68, 1.08, 0)
		g.add_child(fore)
		var hand := Build.box(0.2, 0.16, 0.2, dm)
		hand.position = Vector3(ax * 0.7, 0.82, 0)
		g.add_child(hand)
	var helmet := Build.box(0.4, 0.42, 0.4, pm)
	helmet.position.y = 2.16
	g.add_child(helmet)
	var face := Build.box(0.32, 0.22, 0.08, sm)
	face.position = Vector3(0, 2.14, 0.21)
	g.add_child(face)
	for ex in [-0.085, 0.085]:
		var eye := Build.box(0.08, 0.045, 0.03, eyeglow)
		eye.position = Vector3(ex, 2.19, 0.23)
		g.add_child(eye)
	if big:
		g.scale = Vector3(1.55, 1.55, 1.55)
	return g

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

	# --- Glass showroom hall toward the back of the block ---
	var sw := 17.0
	var sd := 12.0
	var wall_h := 9.0
	var sz := cz + 2.0
	var fz := sz - sd / 2.0                                  # glass front face

	var steel := Build.mat(Build.hex(0x8d949c), 0.4, 0.75)
	var floor := Build.emissive(Build.hex(0xa9b6c0), Build.hex(0x4a5560), 0.5)
	var glass := Build.mat(Build.hex(0xbfe6ec), 0.05, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.32

	var plinth := Build.box(sw, 0.5, sd, Build.mat(Build.hex(0x1c1f25), 0.8))
	plinth.position = Vector3(cx, 0.25, sz)
	add_child(plinth)
	var floor_mi := Build.box(sw - 0.8, 0.1, sd - 0.8, floor)
	floor_mi.position = Vector3(cx, 0.52, sz)
	add_child(floor_mi)

	# Showroom shell — solid collision once, drawn with glass walls.
	buildings.append({"x": cx, "z": sz, "w": sw, "d": sd, "h": wall_h})
	var back := Build.box(sw, wall_h, 0.4, Build.mat(Build.hex(0x23262d), 0.8))
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
	for px in [-sw / 2.0, -2.8, 2.8, sw / 2.0]:
		var post := Build.box(0.5, wall_h, 0.5, steel)
		post.position = Vector3(cx + px, wall_h / 2.0 + 0.5, fz)
		add_child(post)
	# Flat overhanging roof + lit blue ceiling so the suits inside read clearly.
	var roof := Build.box(sw + 1.8, 0.55, sd + 1.8, Build.mat(Build.hex(0x202329), 0.85))
	roof.position = Vector3(cx, wall_h + 0.85, sz)
	add_child(roof)
	var ceiling := Build.emissive(Build.hex(0xcdeeff), Build.hex(0xa6e3ff), 1.5)
	for cl in [-1.0, 0.0, 1.0]:
		var cstrip := Build.box(sw - 2.0, 0.15, 1.5, ceiling)
		cstrip.position = Vector3(cx, wall_h + 0.3, sz + cl * 3.2)
		add_child(cstrip)

	# Lit fascia + correctly-facing brand sign above the entrance.
	var fascia := Build.emissive(Build.hex(0x06141d), blue, 2.6)
	var fband := Build.box(sw + 1.8, 1.8, 0.3, fascia)
	fband.position = Vector3(cx, wall_h + 1.95, fz - 0.9)
	add_child(fband)
	var sign_text := Label3D.new()
	sign_text.text = "STARK INDUSTRIES"
	sign_text.font_size = 96
	sign_text.pixel_size = 0.011
	sign_text.modulate = Color("06141d")
	sign_text.outline_size = 0
	sign_text.rotation.y = PI                                # face the plaza
	sign_text.position = Vector3(cx, wall_h + 1.95, fz - 1.06)
	add_child(sign_text)

	# --- Stark tower rising from the back of the showroom ---
	var tw := 9.0
	var td := 5.0
	var th := 52.0
	var tz := sz + sd / 2.0 - td / 2.0 - 0.4
	var tower := Build.box(tw, th, td, Build.mat(Build.hex(0x1d2026), 0.3, 0.6))
	tower.position = Vector3(cx, th / 2.0 + wall_h, tz)
	add_child(tower)
	buildings.append({"x": cx, "z": tz, "w": tw, "d": td, "h": th + wall_h})
	var band := Build.emissive(Build.hex(0x0c2230), blue, 2.0)
	for by in [18.0, 30.0, 42.0, 53.0]:
		var stripe := Build.box(tw + 0.3, 0.7, td + 0.3, band)
		stripe.position = Vector3(cx, by, tz)
		add_child(stripe)
	# A glowing arc-reactor disc set into the tower face.
	var reactor := Build.emissive(Build.hex(0xeafcff), Color("d8f6ff"), 3.4)
	var disc := Build.cyl(2.0, 2.0, 0.3, 24, reactor)
	disc.rotation.x = PI / 2.0
	disc.position = Vector3(cx, 24.0, tz - td / 2.0 - 0.2)
	add_child(disc)
	var tower_label := Label3D.new()
	tower_label.text = "STARK"
	tower_label.font_size = 64
	tower_label.pixel_size = 0.013
	tower_label.modulate = Color("d8f6ff")
	tower_label.outline_modulate = Color(0, 0, 0, 0.8)
	tower_label.rotation.y = PI                              # face the plaza
	tower_label.position = Vector3(cx, th + wall_h - 6.0, tz - td / 2.0 - 0.3)
	add_child(tower_label)

	# Suit delivery pad — a glowing dais where a bought suit is placed to wear.
	var pad_dark := Build.mat(Build.hex(0x1a1d24), 0.5, 0.5)
	var dais := Build.cyl(2.2, 2.5, 0.16, 28, pad_dark)
	dais.position = Vector3(STARK_SUIT_PAD.x, 0.08, STARK_SUIT_PAD.z)
	add_child(dais)
	var ring := Build.emissive(Build.hex(0x0c2230), blue, 2.6)
	var ring_mi := Build.cyl(2.1, 2.1, 0.06, 28, ring)
	ring_mi.position = Vector3(STARK_SUIT_PAD.x, 0.18, STARK_SUIT_PAD.z)
	add_child(ring_mi)
	# A soft column of light marking the pad from a distance.
	var beam_m := Build.emissive(Build.hex(0x6fd8ff), blue, 0.9)
	beam_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_m.albedo_color.a = 0.16
	var beam := Build.cyl(1.5, 1.5, 9.0, 20, beam_m)
	beam.position = Vector3(STARK_SUIT_PAD.x, 4.7, STARK_SUIT_PAD.z)
	add_child(beam)
	var pad_label := Label3D.new()
	pad_label.text = "SUIT BAY"
	pad_label.font_size = 48
	pad_label.pixel_size = 0.006
	pad_label.modulate = Color("c8f0ff")
	pad_label.outline_modulate = Color(0, 0, 0, 0.8)
	pad_label.position = Vector3(STARK_SUIT_PAD.x, 2.6, STARK_SUIT_PAD.z)
	pad_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(pad_label)

	# --- Showroom — the full suit line-up displayed on lit pedestals. ---
	var liveries := [
		{"name": "MARK III", "p": 0xb01a1a, "s": 0xe0ad28, "d": 0x2a2a30, "big": false},
		{"name": "MARK VI", "p": 0x9c1216, "s": 0xc6cad2, "d": 0x26262c, "big": false},
		{"name": "WAR MACHINE", "p": 0x52565d, "s": 0x303338, "d": 0x1a1b20, "big": false},
		{"name": "HULKBUSTER", "p": 0xb83838, "s": 0xd0a840, "d": 0x2a2a30, "big": true},
	]
	var sr_z := sz - 1.5                                      # inside the showroom
	for i in liveries.size():
		var L: Dictionary = liveries[i]
		var sx := cx - 6.0 + i * 4.0
		var ped := Build.cyl(1.4, 1.6, 0.66, 24, Build.mat(Build.hex(0x16181e), 0.5, 0.5))
		ped.position = Vector3(sx, 0.91, sr_z)              # raised onto showroom floor
		add_child(ped)
		var pring := Build.cyl(1.45, 1.45, 0.08, 24, Build.emissive(Build.hex(0x0c2230), blue, 2.6))
		pring.position = Vector3(sx, 1.27, sr_z)
		add_child(pring)
		var disp := _build_display_suit(L.p, L.s, L.d, L.big)
		disp.position = Vector3(sx, 1.24, sr_z)
		disp.rotation.y = PI                                  # face the plaza
		add_child(disp)
		var slbl := Label3D.new()
		slbl.text = L.name
		slbl.font_size = 34
		slbl.pixel_size = 0.006
		slbl.modulate = Color("c8f0ff")
		slbl.outline_modulate = Color(0, 0, 0, 0.8)
		slbl.position = Vector3(sx, 4.7, sr_z)
		slbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(slbl)

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


## Index of the safehouse whose anchor block centre is (cx, cz), or -1 if none.
func _safehouse_at(cx: float, cz: float) -> int:
	for i in PropertyCatalog.LIST.size():
		var p: Dictionary = PropertyCatalog.LIST[i]
		if is_equal_approx(cx, p.x) and is_equal_approx(cz, p.z):
			return i
	return -1


## Each estate occupies a 2x2 block region — the catalog block plus the three
## neighbours toward the city centre. Returns the property index if block
## (cx, cz) falls in any estate region, else -1.
func _in_estate(cx: float, cz: float) -> int:
	for i in PropertyCatalog.LIST.size():
		var p: Dictionary = PropertyCatalog.LIST[i]
		var ddx: float = -BLOCK if p.x > 0.0 else BLOCK
		var ddz: float = -BLOCK if p.z > 0.0 else BLOCK
		for ox in [0.0, ddx]:
			for oz in [0.0, ddz]:
				if is_equal_approx(cx, p.x + ox) and is_equal_approx(cz, p.z + oz):
					return i
	return -1


## A buyable safehouse — a sprawling walled estate filling a 2x2 block region:
## a big two-storey glass-and-white mansion with a stepped upper floor, a
## three-door garage wing, a large pool, a rooftop helipad, lawns, hedges,
## palms and cypress trees, and a gated entrance bearing the estate's name.
## Pricier properties are built grander. The respawn spot (PropertyCatalog x/z,
## a corner of the grounds) is kept clear of every building.
func _build_safehouse(idx: int) -> void:
	var p: Dictionary = PropertyCatalog.LIST[idx]
	# The estate is centred on its 2x2 block region (catalog block + 3 inward).
	var ddx: float = -BLOCK if p.x > 0.0 else BLOCK
	var ddz: float = -BLOCK if p.z > 0.0 else BLOCK
	var cx: float = p.x + ddx / 2.0
	var cz: float = p.z + ddz / 2.0
	var s: float = lerpf(0.92, 1.08, idx / 3.0)    # pricier homes are grander
	var has_pool := idx >= 1
	var has_heli := idx >= 2
	var half := 26.0                               # estate plot half-width

	var wall_m := Build.mat(Build.hex(0xeceef0), 0.6)
	var glass_m := Build.mat(Build.hex(0x1f2c3a), 0.12, 0.5)
	var roof_m := Build.mat(Build.hex(0x33363d), 0.8)
	var door_m := Build.mat(Build.hex(0x383b42), 0.4, 0.3)
	var lawn_m := Build.mat(Build.hex(0x6f8a4e), 0.95)
	var pave_m := Build.mat(Build.hex(0xb7b2a6), 0.9)
	var hedge_m := Build.mat(Build.hex(0x46703a), 0.97)
	var fence_m := Build.mat(Build.hex(0xe4e6e8), 0.7)
	var water_m := Build.mat(Build.hex(0x2f8fb0), 0.15, 0.35)

	# --- Grounds: a big lawn, a driveway and a paved forecourt ---
	var lawn := Build.box(half * 2.0, 0.14, half * 2.0, lawn_m)
	lawn.position = Vector3(cx, 0.09, cz)
	add_child(lawn)
	var drive := Build.box(13.0, 0.16, half * 2.0 - 2.0, pave_m)
	drive.position = Vector3(cx, 0.12, cz)
	add_child(drive)
	var court := Build.box(30.0, 0.16, 14.0, pave_m)
	court.position = Vector3(cx, 0.13, cz - 2.0)
	add_child(court)

	# --- Main house: two stepped storeys ---
	var gw := 26.0 * s
	var gd := 14.0 * s
	var gh := 5.4
	var hcx := cx + 1.0
	var hcz := cz + 7.0
	var g1 := Build.box(gw, gh, gd, wall_m)
	g1.position = Vector3(hcx, gh / 2.0 + 0.16, hcz)
	add_child(g1)
	buildings.append({"x": hcx, "z": hcz, "w": gw, "d": gd, "h": gh})
	var r1 := Build.box(gw + 0.8, 0.5, gd + 0.8, roof_m)
	r1.position = Vector3(hcx, gh + 0.38, hcz)
	add_child(r1)

	var uw := 16.0 * s
	var ud := 9.0 * s
	var uh := 4.6
	var ucx := hcx - 3.0
	var ucz := hcz + 0.6
	var uy := gh + 0.62
	var g2 := Build.box(uw, uh, ud, wall_m)
	g2.position = Vector3(ucx, uy + uh / 2.0, ucz)
	add_child(g2)
	var r2 := Build.box(uw + 0.7, 0.45, ud + 0.7, roof_m)
	r2.position = Vector3(ucx, uy + uh + 0.32, ucz)
	add_child(r2)

	# Glass — broad window bands on both floors, plus a glazed side wall.
	var fzf := hcz - gd / 2.0 - 0.05
	for wx in [-8.0, -4.0, 0.0, 4.0]:
		var pane := Build.box(3.0 * s, 3.0, 0.24, glass_m)
		pane.position = Vector3(hcx + wx * s, 2.8, fzf)
		add_child(pane)
	var ufzf := ucz - ud / 2.0 - 0.05
	for wx2 in [-4.5, 0.0, 4.5]:
		var pane2 := Build.box(2.8 * s, 2.6, 0.24, glass_m)
		pane2.position = Vector3(ucx + wx2 * s, uy + 2.3, ufzf)
		add_child(pane2)
	var side_glass := Build.box(0.24, 3.0, 6.0 * s, glass_m)
	side_glass.position = Vector3(hcx + gw / 2.0 + 0.04, 2.8, hcz)
	add_child(side_glass)

	# Glowing entrance door, courtyard-facing.
	var door_glow := Build.emissive(Build.hex(0x2a2418), Color("ffd98a"), 1.5)
	var door := Build.box(3.2, 3.6, 0.34, door_glow)
	door.position = Vector3(hcx + 8.5 * s, 1.9, fzf)
	add_child(door)

	# --- Three-door garage wing, front-left ---
	var gar_w := 15.0
	var gar_d := 7.0
	var gar_h := 4.2
	var gar_x := cx - 14.0
	var gar_z := cz - 5.5
	var garage := Build.box(gar_w, gar_h, gar_d, wall_m)
	garage.position = Vector3(gar_x, gar_h / 2.0 + 0.16, gar_z)
	add_child(garage)
	buildings.append({"x": gar_x, "z": gar_z, "w": gar_w, "d": gar_d, "h": gar_h})
	var gar_roof := Build.box(gar_w + 0.6, 0.45, gar_d + 0.6, roof_m)
	gar_roof.position = Vector3(gar_x, gar_h + 0.34, gar_z)
	add_child(gar_roof)
	for di in 3:
		var dx := gar_x - gar_w / 2.0 + 2.6 + di * 4.2
		var gdm := Build.box(3.4, 3.0, 0.22, door_m)
		gdm.position = Vector3(dx, 1.66, gar_z - gar_d / 2.0 - 0.08)
		add_child(gdm)

	# --- Rooftop helipad (grander estates) ---
	if has_heli:
		var pad_x := hcx + gw / 2.0 - 5.0
		var pad := Build.cyl(3.2, 3.2, 0.14, 28, Build.mat(Build.hex(0x2e3138), 0.9))
		pad.position = Vector3(pad_x, gh + 0.68, hcz)
		add_child(pad)
		var hp := Build.mat(Build.hex(0xe7e7e2), 0.85)
		for legdx in [-1.1, 1.1]:
			var leg := Build.box(0.55, 0.06, 3.0, hp)
			leg.position = Vector3(pad_x + legdx, gh + 0.78, hcz)
			add_child(leg)
		var bar := Build.box(2.3, 0.06, 0.6, hp)
		bar.position = Vector3(pad_x, gh + 0.78, hcz)
		add_child(bar)

	# --- Swimming pool + deck, front-right ---
	if has_pool:
		var deck := Build.box(16.0, 0.18, 13.0, pave_m)
		deck.position = Vector3(cx + 13.0, 0.15, cz - 5.5)
		add_child(deck)
		var pool := Build.box(11.0, 0.34, 7.4, water_m)
		pool.position = Vector3(cx + 13.0, 0.26, cz - 5.5)
		add_child(pool)
		for li in [-2.4, 0.0, 2.4]:
			var lounge := Build.box(1.1, 0.32, 2.4, Build.mat(Build.hex(0xdad6c8), 0.8))
			lounge.position = Vector3(cx + 18.5, 0.36, cz - 5.5 + li)
			add_child(lounge)

	# --- Perimeter wall with an 11 m gate gap on the front (-z) side ---
	var t := 0.45
	var wh := 2.0
	_wall(cx, cz + half, half * 2.0, wh, t, fence_m)
	_wall(cx - half, cz, t, wh, half * 2.0, fence_m)
	_wall(cx + half, cz, t, wh, half * 2.0, fence_m)
	var flank := half - 5.5
	_wall(cx - 5.5 - flank / 2.0, cz - half, flank, wh, t, fence_m)
	_wall(cx + 5.5 + flank / 2.0, cz - half, flank, wh, t, fence_m)

	# Gate posts with glowing lamp caps.
	for px in [cx - 5.5, cx + 5.5]:
		var post := Build.box(1.4, 3.4, 1.4, fence_m)
		post.position = Vector3(px, 1.86, cz - half)
		add_child(post)
		var cap := Build.box(1.0, 1.0, 1.0,
			Build.emissive(Build.hex(0x2a2418), Color("ffe6a8"), 1.6))
		cap.position = Vector3(px, 3.9, cz - half)
		add_child(cap)

	# Hedges lining the front wall.
	for hx in [cx - 5.5 - flank / 2.0, cx + 5.5 + flank / 2.0]:
		var hedge := Build.box(flank - 1.0, 1.4, 1.4, hedge_m)
		hedge.position = Vector3(hx, 0.85, cz - half + 1.6)
		add_child(hedge)

	# Palms across the grounds and cypress trees flanking the drive.
	for sp in [Vector2(cx - half + 4.0, cz + half - 5.0),
			Vector2(cx + half - 4.0, cz + half - 5.0),
			Vector2(cx - half + 5.0, cz - half + 7.0),
			Vector2(cx + half - 5.0, cz - half + 9.0)]:
		_add_palm(sp.x, sp.y)
	for cyp in [Vector2(cx - 9.0, cz - half + 5.0),
			Vector2(cx + 9.0, cz - half + 5.0)]:
		var trunk := Build.cyl(0.2, 0.24, 1.5, 6, Build.mat(Build.hex(0x6b4422), 0.95))
		trunk.position = Vector3(cyp.x, 0.75, cyp.y)
		add_child(trunk)
		var foliage := Build.cyl(0.1, 1.7, 7.0, 7, Build.mat(Build.hex(0x3f6a36), 0.95))
		foliage.position = Vector3(cyp.x, 4.9, cyp.y)
		add_child(foliage)

	# Estate name sign above the gate.
	var sign_text := Label3D.new()
	sign_text.text = p.name
	sign_text.font_size = 60
	sign_text.pixel_size = 0.014
	sign_text.modulate = Color("fff2d2")
	sign_text.outline_modulate = Color(0, 0, 0, 0.9)
	sign_text.position = Vector3(cx, 4.4, cz - half)
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
	var river_w := RIVER_HALF * 2.0
	var river := Build.plane(river_w, WORLD, Build.mat(Build.hex(0x2f6f8c), 0.18, 0.35))
	river.position = Vector3(RIVER_CX, 0.06, 0.0)
	add_child(river)
	for i in range(GRID + 1):
		_build_river_bridge(-WORLD_HALF + i * BLOCK)


## One elevated cross-street bridge over the river — a flat span high above the
## water (boats pass beneath) reached by a ramp down to road level on each bank.
func _build_river_bridge(gz: float) -> void:
	var deck_m := Build.mat(Build.hex(0x3a3a42), 0.85)
	var rail_m := Build.mat(Build.hex(0x9a9aa3), 0.7)
	var pylon_m := Build.mat(Build.hex(0x6a6a72), 0.8)
	var dw := ROAD_W + 2.0
	# Flat span over the channel (matches _bridge_profile: |x-RIVER_CX| <= 10).
	var span := Build.box(20.0, 0.5, dw, deck_m)
	span.position = Vector3(RIVER_CX, BRIDGE_H - 0.25, gz)
	add_child(span)
	# Approach ramps, 16 m run down to road level on each bank.
	var run := 16.0
	var ang := atan2(BRIDGE_H, run)
	var hyp := sqrt(run * run + BRIDGE_H * BRIDGE_H)
	for sgn in [-1.0, 1.0]:
		var ramp := Build.box(hyp, 0.5, dw, deck_m)
		ramp.position = Vector3(RIVER_CX + sgn * 18.0, BRIDGE_H / 2.0 - 0.22, gz)
		ramp.rotation.z = -sgn * ang
		add_child(ramp)
	# Pillars rising from the water to carry the span.
	for px in [RIVER_CX - 8.0, RIVER_CX + 8.0]:
		for pz in [gz - dw / 2.0 + 1.6, gz + dw / 2.0 - 1.6]:
			var pil := Build.cyl(0.7, 0.9, BRIDGE_H, 8, pylon_m)
			pil.position = Vector3(px, BRIDGE_H / 2.0, pz)
			add_child(pil)
	# Railings along the flat span.
	for rz in [gz - dw / 2.0 + 0.4, gz + dw / 2.0 - 0.4]:
		var rail := Build.box(20.0, 1.0, 0.4, rail_m)
		rail.position = Vector3(RIVER_CX, BRIDGE_H + 0.5, rz)
		add_child(rail)

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

## A leisure stretch along the western part of the south shore — towels,
## sunbathers in swimwear, parasols, strolling beachgoers and moored boats.
func _build_beach() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260521
	var skins := [0xe8b890, 0xc88a5a, 0xf0c8a0, 0x8d5a3a, 0xd6a070]
	var hairs := [0x2a1a08, 0x6b4a20, 0x111111, 0xc9a24a, 0x7a3b1a]
	var bikinis := [0xff5fa2, 0x18c0c8, 0xffd23f, 0xff7043, 0xf0f0f0, 0x9c27b0]
	var shorts := [0x2a6fb0, 0xe04a3a, 0x33aa55, 0xffa726, 0x5e35b1, 0x00897b]
	var towels := [0xff5252, 0x42a5f5, 0xffca28, 0x26a69a, 0xec407a]

	# Sunbathers laid out on towels across the dry sand.
	var x := -150.0
	while x < 14.0:
		if absf(x - RIVER_CX) < RIVER_HALF + 5.0:
			x += 13.0                                # leave the river mouth clear
			continue
		var tz := 163.0 + rng.randf() * 12.0
		var female := rng.randf() < 0.5
		var suit: int = (bikinis if female else shorts)[rng.randi() % 6]
		_add_beach_towel(x, tz, towels[rng.randi() % towels.size()], rng.randf() * 0.6 - 0.3)
		_add_sunbather(x, tz, female, skins[rng.randi() % skins.size()],
			suit, hairs[rng.randi() % hairs.size()])
		if rng.randf() < 0.55:
			_add_parasol(x + 1.7, tz - 0.4, bikinis[rng.randi() % bikinis.size()])
		if rng.randf() < 0.4:
			var ball := Build.sphere(0.32, Build.mat(Build.hex(bikinis[rng.randi() % bikinis.size()]), 0.6))
			ball.position = Vector3(x + 1.2, 0.32, tz + 1.6)
			add_child(ball)
		x += 14.0 + rng.randf() * 8.0

	# Beachgoers strolling the sand on foot.
	for _i in 12:
		var sx := -148.0 + rng.randf() * 158.0
		if absf(sx - RIVER_CX) < RIVER_HALF + 3.0:
			continue                                 # not on the river mouth
		var sz := 159.0 + rng.randf() * 18.0
		var female2 := rng.randf() < 0.5
		var suit2: int = (bikinis if female2 else shorts)[rng.randi() % 6]
		var h := Human.build(skins[rng.randi() % skins.size()],
			suit2 if female2 else skins[rng.randi() % skins.size()],
			suit2, hairs[rng.randi() % hairs.size()], -1, female2)
		h.position = Vector3(sx, 0.0, sz)
		h.rotation.y = rng.randf() * TAU
		add_child(h)

	# Boats moored just offshore in the shallows.
	var bx := -140.0
	while bx < 10.0:
		_add_boat(bx + rng.randf() * 10.0, 198.0 + rng.randf() * 46.0,
			rng.randf() * TAU, rng)
		bx += 30.0 + rng.randf() * 14.0

func _add_beach_towel(x: float, z: float, color: int, yaw: float) -> void:
	var towel := Build.box(1.2, 0.05, 2.4, Build.mat(Build.hex(color), 0.95))
	towel.position = Vector3(x, 0.06, z)
	towel.rotation.y = yaw
	add_child(towel)

func _add_sunbather(x: float, z: float, female: bool, skin: int, suit: int, hair: int) -> void:
	# Built standing, then tipped onto its back to lie flat on the towel.
	var h := Human.build(skin, suit if female else skin, suit, hair, -1, female)
	h.rotation.x = PI / 2.0
	h.position = Vector3(x, 0.3, z + 1.0)
	add_child(h)

func _add_parasol(x: float, z: float, color: int) -> void:
	var pole := Build.cyl(0.05, 0.05, 3.0, 8, Build.mat(Build.hex(0xdedede), 0.5, 0.6))
	pole.position = Vector3(x, 1.5, z)
	add_child(pole)
	var canopy := Build.cyl(0.0, 2.0, 0.5, 14, Build.mat(Build.hex(color), 0.85))
	canopy.position = Vector3(x, 3.05, z)
	add_child(canopy)
	buildings.append({"x": x, "z": z, "w": 0.4, "d": 0.4, "h": 3.0})

func _add_boat(x: float, z: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var boat := Node3D.new()
	boat.position = Vector3(x, 0.3, z)
	boat.rotation.y = yaw
	boat.rotation.z = rng.randf() * 0.06 - 0.03
	add_child(boat)
	var hull_c: int = [0xe8e8e8, 0xcf3a3a, 0x2f6fb0, 0xf0c020, 0x2a2a32][rng.randi() % 5]
	var hull := Build.box(2.4, 0.8, 6.0, Build.mat(Build.hex(hull_c), 0.6))
	hull.position.y = 0.0
	boat.add_child(hull)
	var deck := Build.box(2.0, 0.12, 5.2, Build.mat(Build.hex(0xc9a878), 0.8))
	deck.position = Vector3(0, 0.42, 0)
	boat.add_child(deck)
	var bow := Build.box(2.2, 0.78, 1.0, Build.mat(Build.hex(hull_c), 0.6))
	bow.position = Vector3(0, 0.0, 3.3)
	bow.rotation.x = -0.35
	boat.add_child(bow)
	var cabin := Build.box(1.5, 1.0, 2.2, Build.mat(Build.hex(0xf4f4f4), 0.5))
	cabin.position = Vector3(0, 1.0, -0.8)
	boat.add_child(cabin)
	var mast := Build.cyl(0.05, 0.06, 3.0, 8, Build.mat(Build.hex(0xdedede), 0.4, 0.6))
	mast.position = Vector3(0, 2.0, 0.4)
	boat.add_child(mast)

## Wooden jetties on the riverbanks and the beach — boats moor here and the
## player can walk the planks on or off a boat.
func _build_docks() -> void:
	var plank_m := Build.mat(Build.hex(0x8a6a40), 0.9)
	var pile_m := Build.mat(Build.hex(0x4f3c22), 0.95)
	# Each pier runs from a bank end to a water end (the board point). River
	# docks sit mid-block, clear of the elevated bridges at the grid lines.
	var piers := [
		[Vector3(-74, 0, -32), Vector3(-66, 0, -32)],     # river — west bank
		[Vector3(-54, 0, 64), Vector3(-62, 0, 64)],       # river — east bank
		[Vector3(-74, 0, 124), Vector3(-66, 0, 124)],     # river — west bank
		[Vector3(-36, 0, 172), Vector3(-36, 0, 192)],     # south beach jetty
		[Vector3(44, 0, 172), Vector3(44, 0, 192)],       # south beach jetty
	]
	for pr in piers:
		var a: Vector3 = pr[0]
		var b: Vector3 = pr[1]
		var mid := (a + b) * 0.5
		var span := b - a
		var horiz: bool = absf(span.x) > absf(span.z)
		var length := span.length()
		var deck_w := 3.4
		# A raised plank deck — its top sits at y 0.55, clear above the water,
		# so it reads as a jetty (the player is lifted onto it by surface_height).
		var deck := Build.box(length if horiz else deck_w, 0.3,
			deck_w if horiz else length, plank_m)
		deck.position = Vector3(mid.x, 0.40, mid.z)
		add_child(deck)
		var n := maxi(2, int(length / 3.0))
		for i in n + 1:
			var p := a.lerp(b, float(i) / float(n))
			for side in [-1.0, 1.0]:
				var pile := Build.cyl(0.22, 0.26, 2.6, 6, pile_m)
				if horiz:
					pile.position = Vector3(p.x, 0.5, p.z + side * deck_w / 2.0)
				else:
					pile.position = Vector3(p.x + side * deck_w / 2.0, 0.5, p.z)
				add_child(pile)
		var postn := Build.cyl(0.2, 0.24, 1.6, 6, pile_m)
		postn.position = Vector3(b.x, 1.2, b.z)
		add_child(postn)
		var rw := (length + 1.0) if horiz else deck_w
		var rd := deck_w if horiz else (length + 1.0)
		_dock_rects.append({"x": mid.x, "z": mid.z, "w": rw, "d": rd})
		docks.append({"board": Vector3(b.x, 0.0, b.z),
			"dir": Vector2(span.x, span.z).normalized()})

## The President's estate — a vast gated compound on its own bay island: a grand
## two-storey mansion, a lake, landscaped parkland, a huge garage and a helipad.
func _build_presidential_residence() -> void:
	var ex0: float = ESTATE_GROUNDS.x0
	var ex1: float = ESTATE_GROUNDS.x1
	var ez0: float = ESTATE_GROUNDS.z0
	var ez1: float = ESTATE_GROUNDS.z1
	var ecx := (ex0 + ex1) / 2.0
	var ecz := (ez0 + ez1) / 2.0
	var gate_z := 340.0
	var road_m := Build.mat(Build.hex(0x6a6a72), 0.9)

	# --- Estate grounds — a manicured lawn island in the bay. ---
	var lawn := Build.plane(ex1 - ex0, ez1 - ez0, Build.mat(Build.hex(0x4f7d3a), 0.95))
	lawn.position = Vector3(ecx, 0.05, ecz)
	add_child(lawn)

	# --- Causeway linking the estate to the airport island. ---
	var cw := Build.box(ESTATE_CAUSEWAY.x1 - ESTATE_CAUSEWAY.x0 + 6.0, 0.4,
		ESTATE_CAUSEWAY.z1 - ESTATE_CAUSEWAY.z0, Build.mat(Build.hex(0x33343a), 0.9))
	cw.position = Vector3((ESTATE_CAUSEWAY.x0 + ESTATE_CAUSEWAY.x1) / 2.0, 0.2, gate_z)
	add_child(cw)
	for rz in [gate_z - 10.0, gate_z + 10.0]:
		var rail := Build.box(ESTATE_CAUSEWAY.x1 - ESTATE_CAUSEWAY.x0 + 6.0, 1.0, 0.5,
			Build.mat(Build.hex(0x6a6e74), 0.5, 0.4))
		rail.position = Vector3((ESTATE_CAUSEWAY.x0 + ESTATE_CAUSEWAY.x1) / 2.0, 0.75, rz)
		add_child(rail)

	# --- Perimeter wall with a grand gateway on the east (airport) side. ---
	var wall_m := Build.mat(Build.hex(0xc4bda8), 0.9)
	var wh := 3.0
	_wall(ecx, ez0, ex1 - ex0, wh, 0.8, wall_m)            # north
	_wall(ecx, ez1, ex1 - ex0, wh, 0.8, wall_m)            # south
	_wall(ex0, ecz, 0.8, wh, ez1 - ez0, wall_m)            # west
	var e_n := (gate_z - 5.0) - ez0
	var e_s := ez1 - (gate_z + 5.0)
	_wall(ex1, ez0 + e_n / 2.0, 0.8, wh, e_n, wall_m)
	_wall(ex1, ez1 - e_s / 2.0, 0.8, wh, e_s, wall_m)
	for gz in [gate_z - 5.0, gate_z + 5.0]:
		var gpost := Build.box(1.6, 5.0, 1.6, Build.mat(Build.hex(0x8a8276), 0.85))
		gpost.position = Vector3(ex1, 2.5, gz)
		add_child(gpost)
		buildings.append({"x": ex1, "z": gz, "w": 1.6, "d": 1.6, "h": 5.0})

	# --- Driveways — gate to mansion, and a spur to the garage. ---
	var drive := Build.box(64.0, 0.06, 7.0, road_m)
	drive.position = Vector3(ex1 - 32.0, 0.12, gate_z)
	add_child(drive)
	var drive2 := Build.box(6.0, 0.06, 30.0, road_m)
	drive2.position = Vector3(-28.0, 0.12, 326.0)
	add_child(drive2)

	# --- The mansion — a grand two-storey residence. ---
	var mx: float = PRESIDENT_HOUSE.x
	var mz: float = PRESIDENT_HOUSE.z
	var house_m := Build.mat(Build.hex(0xece7d8), 0.85)
	var trim_m := Build.mat(Build.hex(0xf4f1e6), 0.8)
	var roof_m := Build.mat(Build.hex(0x5e3a2c), 0.9)
	var mw := 16.0
	var md := 10.0
	var mh := 11.0
	var main := Build.box(mw * 2.0, mh, md * 2.0, house_m)
	main.position = Vector3(mx, mh / 2.0 + 0.05, mz)
	add_child(main)
	buildings.append({"x": mx, "z": mz, "w": mw * 2.0, "d": md * 2.0, "h": mh})
	var band := Build.box(mw * 2.0 + 0.4, 0.5, md * 2.0 + 0.4, trim_m)
	band.position = Vector3(mx, mh / 2.0 + 0.05, mz)
	add_child(band)
	var mroof := Build.box(mw * 2.0 + 2.0, 1.0, md * 2.0 + 2.0, roof_m)
	mroof.position = Vector3(mx, mh + 0.55, mz)
	add_child(mroof)
	for wz in [mz - md - 5.0, mz + md + 5.0]:
		var wing := Build.box(18.0, 7.0, 12.0, house_m)
		wing.position = Vector3(mx + 2.0, 3.55, wz)
		add_child(wing)
		buildings.append({"x": mx + 2.0, "z": wz, "w": 18.0, "d": 12.0, "h": 7.0})
		var wroof := Build.box(19.6, 0.8, 13.6, roof_m)
		wroof.position = Vector3(mx + 2.0, 7.4, wz)
		add_child(wroof)
	# Columned portico facing the drive (east).
	var portico := Build.box(4.0, 0.6, 14.0, trim_m)
	portico.position = Vector3(mx + mw + 2.0, mh - 0.6, mz)
	add_child(portico)
	for cz2 in [mz - 5.0, mz - 1.7, mz + 1.7, mz + 5.0]:
		var col := Build.cyl(0.45, 0.5, mh - 0.6, 12, trim_m)
		col.position = Vector3(mx + mw + 2.0, (mh - 0.6) / 2.0, cz2)
		add_child(col)
	var win_m := Build.mat(Build.hex(0x35506a), 0.2, 0.4)
	for fy in [3.0, 7.6]:
		for wz2 in [mz - 6.0, mz - 2.0, mz + 2.0, mz + 6.0]:
			var win := Build.box(0.3, 2.0, 1.6, win_m)
			win.position = Vector3(mx + mw + 0.06, fy, wz2)
			add_child(win)
	# Flagpoles flanking the portico.
	for fz in [mz - 8.0, mz + 8.0]:
		var fpole := Build.cyl(0.1, 0.13, 11.0, 8, Build.mat(Build.hex(0xcfcfcf), 0.4, 0.6))
		fpole.position = Vector3(mx + mw + 4.0, 5.5, fz)
		add_child(fpole)
		var flag := Build.box(0.1, 1.3, 2.2, Build.mat(Build.hex(0xb01a1a), 0.7))
		flag.position = Vector3(mx + mw + 4.0, 9.8, fz + 1.2)
		add_child(flag)

	# --- Huge garage — a long six-bay block. ---
	var gcx := -22.0
	var gcz := 372.0
	var gw := 19.0
	var gd := 8.0
	var gh := 7.0
	var garage := Build.box(gw * 2.0, gh, gd * 2.0, Build.mat(Build.hex(0xb8b2a2), 0.9))
	garage.position = Vector3(gcx, gh / 2.0 + 0.05, gcz)
	add_child(garage)
	buildings.append({"x": gcx, "z": gcz, "w": gw * 2.0, "d": gd * 2.0, "h": gh})
	var groof := Build.box(gw * 2.0 + 1.4, 0.7, gd * 2.0 + 1.4, Build.mat(Build.hex(0x44464c), 0.9))
	groof.position = Vector3(gcx, gh + 0.35, gcz)
	add_child(groof)
	var door_m := Build.mat(Build.hex(0x2f3138), 0.5, 0.3)
	for k in 6:
		var door := Build.box(4.6, 4.6, 0.3, door_m)
		door.position = Vector3(gcx - gw + 4.0 + k * 6.0, 2.4, gcz - gd - 0.06)
		add_child(door)
	var gapron := Build.box(gw * 2.0 + 6.0, 0.06, 14.0, road_m)
	gapron.position = Vector3(gcx, 0.12, gcz - gd - 7.0)
	add_child(gapron)

	# --- Helipad — circular pad with a painted H, north-west of the mansion. ---
	var hx := -104.0
	var hz := 286.0
	var pad := Build.cyl(13.0, 13.0, 0.16, 30, Build.mat(Build.hex(0x383841), 0.92))
	pad.position = Vector3(hx, 0.13, hz)
	add_child(pad)
	var hpaint := Build.mat(Build.hex(0xe8e8e8), 0.85)
	for leg_dx in [-2.6, 2.6]:
		var leg := Build.box(1.6, 0.05, 8.0, hpaint)
		leg.position = Vector3(hx + leg_dx, 0.22, hz)
		add_child(leg)
	var hbar := Build.box(3.6, 0.05, 1.8, hpaint)
	hbar.position = Vector3(hx, 0.22, hz)
	add_child(hbar)

	# --- Ornamental lake in the south-west of the grounds. ---
	var lake := Build.plane(58.0, 42.0, Build.mat(Build.hex(0x2f6f8c), 0.18, 0.35))
	lake.position = Vector3(-92.0, 0.09, 418.0)
	add_child(lake)
	var kerb_m := Build.mat(Build.hex(0x9a9488), 0.9)
	for kz in [396.0, 440.0]:
		var k := Build.box(62.0, 0.4, 1.4, kerb_m)
		k.position = Vector3(-92.0, 0.2, kz)
		add_child(k)
	for kx in [-122.0, -62.0]:
		var k2 := Build.box(1.4, 0.4, 46.0, kerb_m)
		k2.position = Vector3(kx, 0.2, 418.0)
		add_child(k2)

	# --- Parkland — a central fountain ringed by trees in the south-east. ---
	var fountain := Build.cyl(4.0, 4.4, 0.7, 20, kerb_m)
	fountain.position = Vector3(-24.0, 0.35, 420.0)
	add_child(fountain)
	var fwater := Build.cyl(3.3, 3.3, 0.2, 20, Build.mat(Build.hex(0x3f8fae), 0.2, 0.4))
	fwater.position = Vector3(-24.0, 0.7, 420.0)
	add_child(fwater)
	var fjet := Build.cyl(0.3, 0.4, 3.0, 8, Build.mat(Build.hex(0xbfe0ea), 0.3))
	fjet.position = Vector3(-24.0, 2.2, 420.0)
	add_child(fjet)
	buildings.append({"x": -24.0, "z": 420.0, "w": 8.4, "d": 8.4, "h": 0.7})
	for ps in [Vector2(-6, 400), Vector2(-44, 410), Vector2(-8, 440),
			Vector2(-40, 446), Vector2(2, 422), Vector2(-58, 392), Vector2(-20, 460)]:
		_add_leafy_tree(ps.x, ps.y)
	for pp in [Vector2(-120, 300), Vector2(-118, 342), Vector2(-116, 392),
			Vector2(10, 272), Vector2(10, 408)]:
		_add_palm(pp.x, pp.y)

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

## The airport island and its causeway — kept clear of city props.
func _in_airport_zone(x: float, z: float) -> bool:
	return on_airfield(x, z) or _on_causeway(x, z)

func _build_airport() -> void:
	var pole_m := Build.mat(Build.hex(0x1a1a1a), 0.4, 0.7)

	# --- The airport island — one long grass airfield set in the bay, well south
	#     of the city grid and the racing circuit so neither road nor track ever
	#     crosses it. The runways roll out down the length of the island. ---
	var grass_w: float = AIRFIELD.x1 - AIRFIELD.x0
	var grass_d: float = AIRFIELD.z1 - AIRFIELD.z0
	var field := Build.plane(grass_w, grass_d, Build.mat(Build.hex(0x5f7a3e), 0.95))
	field.position = Vector3((AIRFIELD.x0 + AIRFIELD.x1) / 2.0, 0.05,
		(AIRFIELD.z0 + AIRFIELD.z1) / 2.0)
	add_child(field)

	# --- Causeway — the single land link, bridging the bay from the city shore
	#     to the airfield edge. The deck stops at the airfield so it never pokes
	#     up through the grass or apron, and the rails sit inset on the deck. ---
	var cw_x := 80.0
	var cw_z0: float = CAUSEWAY.z0
	var cw_z1: float = AIRFIELD.z0 + 3.0          # meet the airfield, don't overrun it
	var cw_len := cw_z1 - cw_z0
	var cw_z := (cw_z0 + cw_z1) / 2.0
	var causeway := Build.box(16.0, 0.4, cw_len, Build.mat(Build.hex(0x33343a), 0.9))
	causeway.position = Vector3(cw_x, 0.2, cw_z)
	add_child(causeway)
	for rail_x in [cw_x - 7.6, cw_x + 7.6]:
		var rail := Build.box(0.5, 0.9, cw_len, Build.mat(Build.hex(0x6a6e74), 0.5, 0.4))
		rail.position = Vector3(rail_x, 0.85, cw_z)
		add_child(rail)
	var cw_dash_m := Build.mat(Build.hex(0xd9c020), 0.85)
	var cwz := cw_z0 + 4.0
	while cwz < cw_z1 - 2.0:
		var cwd := Build.box(0.3, 0.06, 2.4, cw_dash_m)
		cwd.position = Vector3(cw_x, 0.41, cwz)
		add_child(cwd)
		cwz += 5.0

	# --- Apron — the paved expanse fronting the terminal and the runway thresholds ---
	var apron := Build.box(160.0, 0.05, 156.0, Build.mat(Build.hex(0x4f4f58), 0.9))
	apron.position = Vector3(155.0, 0.12, 287.0)
	add_child(apron)

	# --- Terminal forecourt — paved drop-off where cars arrive ---
	var court := Build.box(30.0, 0.06, 52.0, Build.mat(Build.hex(0x55555e), 0.9))
	court.position = Vector3(82.0, 0.14, 256.0)
	add_child(court)

	# --- Helipad — circular pad with a painted 'H' for the helicopter ---
	var helipad := Build.cyl(11.0, 11.0, 0.14, 28, Build.mat(Build.hex(0x383841), 0.92))
	helipad.position = Vector3(HELIPAD.x, 0.2, HELIPAD.z)
	add_child(helipad)
	var hpaint := Build.mat(Build.hex(0xe8e8e8), 0.85)
	for leg_dx in [-2.3, 2.3]:
		var leg := Build.box(1.4, 0.05, 7.0, hpaint)
		leg.position = Vector3(HELIPAD.x + leg_dx, 0.29, HELIPAD.z)
		add_child(leg)
	var crossbar := Build.box(3.2, 0.05, 1.6, hpaint)
	crossbar.position = Vector3(HELIPAD.x, 0.29, HELIPAD.z)
	add_child(crossbar)

	# --- Yellow taxi guide line from the terminal frontage to the runways ---
	var taxi_m := Build.mat(Build.hex(0xd9c020), 0.85)
	var tlx := 134.0
	while tlx < 224.0:
		var td := Build.box(3.0, 0.04, 0.4, taxi_m)
		td.position = Vector3(tlx, 0.2, 268.0)
		add_child(td)
		tlx += 6.0

	_build_terminal(112.0, 255.0)
	_build_runway(RUNWAY_A.x, RUNWAY_A.z, RUNWAY_A.len, RUNWAY_A.w)
	_build_runway(RUNWAY_B.x, RUNWAY_B.z, RUNWAY_B.len, RUNWAY_B.w)
	_build_control_tower(140.0, 320.0)

	# --- Hangar ---
	var hangar := Build.box(13.0, 9.0, 16.0, Build.mat(Build.hex(0x6f747a), 0.9))
	hangar.position = Vector3(195.0, 4.5, 345.0)
	add_child(hangar)
	buildings.append({"x": 195.0, "z": 345.0, "w": 13.0, "d": 16.0, "h": 9.0})

	# --- Tall red beacon, visible across the bay ---
	beacon_mat = Build.emissive(Build.hex(0xff2244), Build.hex(0xff1133), 0.8)
	beacon_node = Build.sphere(2.4, beacon_mat)
	beacon_node.position = Vector3(228.0, 54.0, 240.0)
	add_child(beacon_node)
	var beacon_pole := Build.cyl(0.2, 0.35, 50.0, 8, pole_m)
	beacon_pole.position = Vector3(228.0, 25.0, 240.0)
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
		# Keep the city clear. The city is a SQUARE — its diagonal corners reach
		# much further than a radial test, so measure distance to the rectangle.
		var csx := clampf(x, -WORLD_HALF, WORLD_HALF)
		var csz := clampf(z, -WORLD_HALF, WORLD_HALF)
		if Vector2(x - csx, z - csz).length() < r + 34.0:
			continue
		# Keep the grass airfield clear — no mountain may intrude on it.
		var ax := clampf(x, AIRFIELD.x0, AIRFIELD.x1)
		var az := clampf(z, AIRFIELD.z0, AIRFIELD.z1)
		if Vector2(x - ax, z - az).length() < r + 30.0:
			continue
		# Keep the F1 circuit corridor clear of mountains.
		if track != null and track.near(x, z, r + 26.0):
			continue
		# Keep the launch complex clear.
		if Vector2(LAUNCH.x - x, LAUNCH.z - z).length() < r + 50.0:
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
		# Keep the city square clear — corners reach further than a radial test.
		var csx := clampf(x, -WORLD_HALF, WORLD_HALF)
		var csz := clampf(z, -WORLD_HALF, WORLD_HALF)
		if Vector2(x - csx, z - csz).length() < 46.0:
			continue
		# Keep the grass airfield (and a margin around it) free of hills/trees.
		var fx := clampf(x, AIRFIELD.x0, AIRFIELD.x1)
		var fz := clampf(z, AIRFIELD.z0, AIRFIELD.z1)
		if Vector2(x - fx, z - fz).length() < 48.0:
			continue
		# Keep the F1 circuit corridor clear of hills, rocks and trees.
		if track != null and track.near(x, z, 30.0):
			continue
		# Keep the launch complex clear.
		if Vector2(LAUNCH.x - x, LAUNCH.z - z).length() < 60.0:
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
	# Inside the trading-floor office only its own glass walls block the player;
	# the city far below is irrelevant.
	if trading_floor_active:
		var tf := TRADING_FLOOR
		if absf(x - tf.x) < 12.0 and absf(z - tf.z) < 9.0:
			for w in _office_walls:
				if x > w.x - w.w / 2.0 - r and x < w.x + w.w / 2.0 + r \
					and z > w.z - w.d / 2.0 - r and z < w.z + w.d / 2.0 + r:
					return true
			return false
	for b in buildings:
		if altitude > b.h + 2.0:
			continue
		if x > b.x - b.w / 2.0 - r and x < b.x + b.w / 2.0 + r \
			and z > b.z - b.d / 2.0 - r and z < b.z + b.d / 2.0 + r:
			return true
	# Dock piers are solid footing out over the water.
	for d in _dock_rects:
		if x > d.x - d.w / 2.0 and x < d.x + d.w / 2.0 \
			and z > d.z - d.d / 2.0 and z < d.z + d.d / 2.0:
			return false
	# The grass airfield is solid ground its full length — never sea.
	if on_airfield(x, z):
		return false
	# The causeway deck spans the bay — solid footing over the water.
	if _on_causeway(x, z):
		return false
	# The President's estate island and its link causeway are solid ground.
	if _on_estate(x, z) or _on_estate_causeway(x, z):
		return false
	# The city river is open water — the bridges arch high above it, so anything
	# down at ground level is blocked the whole length of the channel.
	if absf(x - RIVER_CX) < RIVER_HALF and z > -WORLD_HALF and z < WORLD_HALF \
		and altitude < BRIDGE_H - 1.2:
		return true
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
