class_name CarMesh
## Procedural low-poly car bodies in five distinct styles — sedan, coupe,
## sports, SUV and hyper. Shared by live traffic / owned vehicles (game.gd)
## and the static display cars on the dealership lot (world.gd), so a car of
## a given class looks the same wherever it appears.
##
## Nose points +Z. Wheels rest on y = 0; the body floats above on its tyres.

const STYLES := ["sedan", "coupe", "sports", "suv", "hyper", "f1", "bike", "tank"]

## The Formula 1 car is a real, fully-liveried McLaren MCL35M glTF model
## (chwashere123, CC-BY-4.0 — see README credits) rather than procedural boxes.
## Instanced and reshaped to game space in _build_f1.
const MCLAREN_SCENE: PackedScene = preload(
	"res://assets/vehicles/mclaren_mcl35m/scene.gltf")

## Model → game-space fit, measured from the imported mesh AABB: the raw model
## is Y-up with the nose already pointing +Z. Scaling by 32 makes it ~5.96 m
## long × 2.19 m wide (a bit longer than the road cars, as an F1 should be);
## F1_MODEL_* recentre X/Z on the origin and drop the lowest point to y = 0.
const F1_SCALE := 32.0
const F1_MODEL_CENTER_X := 0.00164
const F1_MODEL_CENTER_Z := 0.00801
const F1_MODEL_MIN_Y := -0.007249

## Roads and the race track are modelled ~0.13 above y = 0, but every vehicle is
## placed at y = 0 (see game.gd — owned spawn, AI racers, the driven-car snap).
## The chunky procedural cars hide that gap; the low, open-wheel F1 sits its bare
## tyres right in it. Lifting the model by F1_RIDE parks the tyres on the tarmac.
## Display cars sit on a raised pad instead, so world.gd subtracts F1_RIDE there.
const F1_RIDE := 0.13

## Body proportions per style. cab_y / roof_y / hood_y are derived in build()
## from ride height and box sizes so the cabin always sits on the body.
static func _profile(style: String) -> Dictionary:
	match style:
		"coupe":
			return {
				"bw": 1.94, "bh": 0.56, "bd": 3.95, "ride": 0.56,
				"hood_d": 1.4, "hood_z": 1.1, "trunk_d": 0.95, "trunk_z": -1.3,
				"cab_w": 1.6, "cab_h": 0.54, "cab_d": 1.55, "cab_z": -0.4,
				"roof_w": 1.5, "roof_d": 1.0,
				"tire_r": 0.41, "tire_x": 1.0, "tire_z": 1.34,
				"light_z": 1.95, "wing": 0,
			}
		"sports":
			return {
				"bw": 2.04, "bh": 0.46, "bd": 4.5, "ride": 0.5,
				"hood_d": 1.8, "hood_z": 1.4, "trunk_d": 1.1, "trunk_z": -1.65,
				"cab_w": 1.54, "cab_h": 0.46, "cab_d": 1.5, "cab_z": -0.45,
				"roof_w": 1.44, "roof_d": 1.05,
				"tire_r": 0.44, "tire_x": 1.02, "tire_z": 1.5,
				"light_z": 2.2, "wing": 1,
			}
		"suv":
			return {
				"bw": 2.06, "bh": 0.82, "bd": 4.3, "ride": 0.86,
				"hood_d": 1.4, "hood_z": 1.25, "trunk_d": 1.3, "trunk_z": -1.45,
				"cab_w": 1.9, "cab_h": 0.92, "cab_d": 2.5, "cab_z": -0.05,
				"roof_w": 1.84, "roof_d": 2.4,
				"tire_r": 0.52, "tire_x": 1.03, "tire_z": 1.46,
				"light_z": 2.12, "wing": 0,
			}
		"hyper":
			return {
				"bw": 2.1, "bh": 0.38, "bd": 4.75, "ride": 0.45,
				"hood_d": 2.0, "hood_z": 1.55, "trunk_d": 0.9, "trunk_z": -1.8,
				"cab_w": 1.4, "cab_h": 0.42, "cab_d": 1.3, "cab_z": -0.3,
				"roof_w": 1.32, "roof_d": 0.85,
				"tire_r": 0.46, "tire_x": 1.05, "tire_z": 1.62,
				"light_z": 2.3, "wing": 2,
			}
		_:
			return {
				"bw": 2.0, "bh": 0.62, "bd": 4.2, "ride": 0.62,
				"hood_d": 1.5, "hood_z": 1.2, "trunk_d": 1.2, "trunk_z": -1.35,
				"cab_w": 1.7, "cab_h": 0.62, "cab_d": 2.0, "cab_z": -0.1,
				"roof_w": 1.62, "roof_d": 1.5,
				"tire_r": 0.42, "tire_x": 1.0, "tire_z": 1.42,
				"light_z": 2.05, "wing": 0,
			}


## Build a car node of `style` painted `color`. With `open_hood` the bonnet
## is propped up over a visible engine block — used for showroom display cars.
## `head_m` / `tail_m` let the caller share day/night-modulated light materials;
## when null, static materials are made here (fine for display cars).
static func build(color: int, style := "sedan", open_hood := false,
		head_m: Material = null, tail_m: Material = null) -> Node3D:
	if style == "f1":
		return _build_f1(color)
	if style == "bike":
		return _build_bike(color)
	if style == "tank":
		return _build_tank(color)
	var p := _profile(style)
	var g := Node3D.new()

	var body_m := Build.cmat(Build.hex(color), 0.38, 0.4)
	var dark_m := Build.cmat(Build.hex(0x14161b), 0.5, 0.4)
	# Glass is mutated below (alpha), so it must stay a private copy.
	var glass_m := Build.mat(Build.hex(0x0a1426), 0.06, 0.1)
	glass_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_m.albedo_color.a = 0.82
	if head_m == null:
		head_m = Build.emissive(Build.hex(0xfff6c0), Build.hex(0xfff6c0), 0.5)
	if tail_m == null:
		tail_m = Build.emissive(Build.hex(0xff3030), Build.hex(0xff2020), 0.5)
	var tire_m := Build.cmat(Build.hex(0x0a0a0a), 0.95)
	var rim_m := Build.cmat(Build.hex(0xcccccc), 0.25, 0.95)

	var body_top: float = p.ride + p.bh / 2.0

	var body := Build.box(p.bw, p.bh, p.bd, body_m)
	body.position.y = p.ride
	g.add_child(body)

	# Trunk deck.
	var trunk := Build.box(p.bw * 0.9, 0.3, p.trunk_d, body_m)
	trunk.position = Vector3(0, body_top + 0.15, p.trunk_z)
	g.add_child(trunk)

	# Bonnet — flat, or hinged open over an engine bay for display cars.
	if open_hood:
		var engine := Build.box(p.bw * 0.6, 0.5, p.hood_d * 0.8, dark_m)
		engine.position = Vector3(0, body_top + 0.22, p.hood_z)
		g.add_child(engine)
		var hinge := Node3D.new()
		hinge.position = Vector3(0, body_top + 0.16, p.hood_z + p.hood_d / 2.0)
		hinge.rotation.x = 1.15
		g.add_child(hinge)
		var lid := Build.box(p.bw * 0.9, 0.12, p.hood_d, body_m)
		lid.position = Vector3(0, 0, -p.hood_d / 2.0)
		hinge.add_child(lid)
	else:
		var hood := Build.box(p.bw * 0.9, 0.3, p.hood_d, body_m)
		hood.position = Vector3(0, body_top + 0.15, p.hood_z)
		g.add_child(hood)

	# Cabin glasshouse + roof.
	var cab_y: float = body_top + p.cab_h / 2.0
	var cabin := Build.box(p.cab_w, p.cab_h, p.cab_d, glass_m)
	cabin.position = Vector3(0, cab_y, p.cab_z)
	g.add_child(cabin)
	var roof := Build.box(p.roof_w, 0.1, p.roof_d, body_m)
	roof.position = Vector3(0, cab_y + p.cab_h / 2.0 + 0.05, p.cab_z)
	g.add_child(roof)

	# Wheels — each pair sits on a hub pivot so the front axle can visibly
	# steer (game.gd yaws the "front_wheels" hubs with the player's input).
	var front_wheels: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var hub := Node3D.new()
			hub.position = Vector3(sx * p.tire_x, p.tire_r, sz * p.tire_z)
			g.add_child(hub)
			var tire := Build.cyl(p.tire_r, p.tire_r, 0.36, 16, tire_m)
			tire.rotation.z = PI / 2.0
			hub.add_child(tire)
			var rim := Build.cyl(p.tire_r * 0.6, p.tire_r * 0.6, 0.4, 12, rim_m)
			rim.rotation.z = PI / 2.0
			hub.add_child(rim)
			if sz > 0.0:
				front_wheels.append(hub)
	g.set_meta("front_wheels", front_wheels)

	# Lights.
	for lx in [-0.6, 0.6]:
		var hl := Build.box(0.34, 0.16, 0.1, head_m)
		hl.position = Vector3(lx, body_top + 0.05, p.light_z)
		g.add_child(hl)
		var tl := Build.box(0.34, 0.15, 0.08, tail_m)
		tl.position = Vector3(lx, body_top + 0.05, -p.light_z)
		g.add_child(tl)

	# Rear wing on sports / hyper cars.
	if p.wing > 0:
		var ww := 1.5 if p.wing == 1 else 1.75
		var wy := body_top + (0.45 if p.wing == 1 else 0.6)
		var wz: float = -p.bd / 2.0 + 0.35
		for sx in [-1.0, 1.0]:
			var strut := Build.box(0.12, wy - body_top, 0.3, dark_m)
			strut.position = Vector3(sx * ww * 0.4, (wy + body_top) / 2.0, wz)
			g.add_child(strut)
		var blade := Build.box(ww, 0.09, 0.5, dark_m)
		blade.position = Vector3(0, wy, wz)
		g.add_child(blade)

	return g


## A Formula 1 open-wheel racer — the real McLaren MCL35M model, fitted to game
## space: nose points +Z, tyres rest on y = 0, centred on the origin so the car
## yaws about its middle like every other vehicle. `_color` is accepted to match
## build()'s signature but ignored — the model carries its own baked livery.
static func _build_f1(_color: int) -> Node3D:
	var g := Node3D.new()
	var model := MCLAREN_SCENE.instantiate()
	model.scale = Vector3(F1_SCALE, F1_SCALE, F1_SCALE)
	model.position = Vector3(
		-F1_MODEL_CENTER_X * F1_SCALE,
		-F1_MODEL_MIN_Y * F1_SCALE + F1_RIDE,
		-F1_MODEL_CENTER_Z * F1_SCALE)
	g.add_child(model)
	return g


## A low-poly motorcycle — two in-line wheels, frame, tank, seat, handlebars.
## Nose points +Z; wheels rest on y = 0.
static func _build_bike(color: int) -> Node3D:
	var g := Node3D.new()
	var body_m := Build.mat(Build.hex(color), 0.36, 0.4)
	var dark_m := Build.mat(Build.hex(0x16181c), 0.5, 0.4)
	var tire_m := Build.mat(Build.hex(0x0a0a0a), 0.95)
	var rim_m := Build.mat(Build.hex(0xcccccc), 0.25, 0.95)
	var head_m := Build.emissive(Build.hex(0xfff6c0), Build.hex(0xfff6c0), 0.5)

	for tz in [-0.95, 1.05]:
		var tire := Build.cyl(0.45, 0.45, 0.26, 16, tire_m)
		tire.rotation.z = PI / 2.0
		tire.position = Vector3(0, 0.45, tz)
		g.add_child(tire)
		var rim := Build.cyl(0.22, 0.22, 0.3, 10, rim_m)
		rim.rotation.z = PI / 2.0
		rim.position = Vector3(0, 0.45, tz)
		g.add_child(rim)
	var frame := Build.box(0.34, 0.4, 2.0, dark_m)
	frame.position = Vector3(0, 0.74, 0.0)
	g.add_child(frame)
	var tank := Build.box(0.56, 0.46, 1.0, body_m)
	tank.position = Vector3(0, 1.02, 0.35)
	g.add_child(tank)
	var seat := Build.box(0.5, 0.22, 1.0, dark_m)
	seat.position = Vector3(0, 0.96, -0.55)
	g.add_child(seat)
	var fairing := Build.box(0.5, 0.7, 0.5, body_m)
	fairing.position = Vector3(0, 0.95, 1.15)
	g.add_child(fairing)
	var bars := Build.box(0.9, 0.12, 0.12, dark_m)
	bars.position = Vector3(0, 1.2, 0.95)
	g.add_child(bars)
	var hl := Build.box(0.34, 0.3, 0.14, head_m)
	hl.position = Vector3(0, 1.0, 1.42)
	g.add_child(hl)
	var pipe := Build.cyl(0.1, 0.12, 1.4, 8, Build.mat(Build.hex(0x8e9298), 0.3, 0.8))
	pipe.rotation.x = PI / 2.0
	pipe.position = Vector3(0.34, 0.6, -0.7)
	g.add_child(pipe)
	return g


## A low-poly tank — wide hull, side tracks, a turret and a forward cannon.
## Nose (cannon) points +Z; tracks rest on y = 0.
static func _build_tank(color: int) -> Node3D:
	var g := Node3D.new()
	var hull_m := Build.mat(Build.hex(color), 0.85, 0.1)
	var dark_m := Build.mat(Build.hex(0x20221f), 0.8)
	var metal_m := Build.mat(Build.hex(0x6a6e63), 0.5, 0.5)

	for sx in [-1.0, 1.0]:
		var track := Build.box(0.7, 1.0, 5.0, dark_m)
		track.position = Vector3(sx * 1.35, 0.5, 0.0)
		g.add_child(track)
		for wi in 4:
			var roller := Build.cyl(0.42, 0.42, 0.75, 10, metal_m)
			roller.rotation.z = PI / 2.0
			roller.position = Vector3(sx * 1.35, 0.42, -1.65 + wi * 1.1)
			g.add_child(roller)
	var hull := Build.box(2.6, 0.95, 4.4, hull_m)
	hull.position = Vector3(0, 1.15, 0.0)
	g.add_child(hull)
	var glacis := Build.box(2.5, 0.5, 1.2, hull_m)
	glacis.position = Vector3(0, 1.05, 2.3)
	g.add_child(glacis)
	# Turret + cannon.
	var turret := Build.cyl(1.25, 1.45, 0.95, 12, hull_m)
	turret.position = Vector3(0, 2.0, -0.3)
	g.add_child(turret)
	var mantlet := Build.box(0.9, 0.6, 0.7, hull_m)
	mantlet.position = Vector3(0, 2.05, 0.7)
	g.add_child(mantlet)
	var barrel := Build.cyl(0.18, 0.22, 3.4, 10, metal_m)
	barrel.rotation.x = PI / 2.0
	barrel.position = Vector3(0, 2.1, 2.6)
	g.add_child(barrel)
	var hatch := Build.cyl(0.45, 0.45, 0.18, 10, metal_m)
	hatch.position = Vector3(0, 2.52, -0.6)
	g.add_child(hatch)
	return g
