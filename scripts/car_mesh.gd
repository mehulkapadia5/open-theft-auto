class_name CarMesh
## Procedural low-poly car bodies in five distinct styles — sedan, coupe,
## sports, SUV and hyper. Shared by live traffic / owned vehicles (game.gd)
## and the static display cars on the dealership lot (world.gd), so a car of
## a given class looks the same wherever it appears.
##
## Nose points +Z. Wheels rest on y = 0; the body floats above on its tyres.

const STYLES := ["sedan", "coupe", "sports", "suv", "hyper", "f1"]

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
	var p := _profile(style)
	var g := Node3D.new()

	var body_m := Build.mat(Build.hex(color), 0.38, 0.4)
	var dark_m := Build.mat(Build.hex(0x14161b), 0.5, 0.4)
	var glass_m := Build.mat(Build.hex(0x0a1426), 0.06, 0.1)
	glass_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_m.albedo_color.a = 0.82
	if head_m == null:
		head_m = Build.emissive(Build.hex(0xfff6c0), Build.hex(0xfff6c0), 0.5)
	if tail_m == null:
		tail_m = Build.emissive(Build.hex(0xff3030), Build.hex(0xff2020), 0.5)
	var tire_m := Build.mat(Build.hex(0x0a0a0a), 0.95)
	var rim_m := Build.mat(Build.hex(0xcccccc), 0.25, 0.95)

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

	# Wheels.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tire := Build.cyl(p.tire_r, p.tire_r, 0.36, 16, tire_m)
			tire.rotation.z = PI / 2.0
			tire.position = Vector3(sx * p.tire_x, p.tire_r, sz * p.tire_z)
			g.add_child(tire)
			var rim := Build.cyl(p.tire_r * 0.6, p.tire_r * 0.6, 0.4, 12, rim_m)
			rim.rotation.z = PI / 2.0
			rim.position = Vector3(sx * p.tire_x, p.tire_r, sz * p.tire_z)
			g.add_child(rim)

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


## A Formula 1 open-wheel racer — long pointed nose, open cockpit with the
## driver's helmet showing, sidepods, front + rear wings, and four exposed
## tyres on suspension arms. Nose points +Z; wheels rest on y = 0.
static func _build_f1(color: int) -> Node3D:
	var g := Node3D.new()
	var body_m := Build.mat(Build.hex(color), 0.34, 0.4)
	var dark_m := Build.mat(Build.hex(0x16181c), 0.5, 0.35)
	var tire_m := Build.mat(Build.hex(0x0a0a0a), 0.95)
	var rim_m := Build.mat(Build.hex(0x9a9ca0), 0.3, 0.9)
	var helmet_m := Build.mat(Build.hex(0x1c1c22), 0.45)
	var visor_m := Build.emissive(Build.hex(0x10141c), Build.hex(0x6fd0ff), 0.5)

	# Underbody floor.
	var floor_p := Build.box(1.5, 0.14, 5.2, dark_m)
	floor_p.position = Vector3(0, 0.16, -0.1)
	g.add_child(floor_p)

	# Monocoque / cockpit tub.
	var tub := Build.box(0.94, 0.52, 2.7, body_m)
	tub.position = Vector3(0, 0.54, -0.1)
	g.add_child(tub)

	# Long nose tapering down toward the front wing.
	var nose := Build.box(0.64, 0.42, 2.1, body_m)
	nose.position = Vector3(0, 0.58, 2.05)
	nose.rotation.x = 0.14
	g.add_child(nose)
	var nose_tip := Build.box(0.42, 0.3, 0.7, body_m)
	nose_tip.position = Vector3(0, 0.34, 3.15)
	g.add_child(nose_tip)

	# Front wing — two planes with endplates.
	var fw := Build.box(2.4, 0.1, 0.8, dark_m)
	fw.position = Vector3(0, 0.2, 3.25)
	g.add_child(fw)
	var fw2 := Build.box(2.0, 0.08, 0.42, dark_m)
	fw2.position = Vector3(0, 0.4, 3.42)
	g.add_child(fw2)
	for sx in [-1.0, 1.0]:
		var ep := Build.box(0.12, 0.46, 0.9, dark_m)
		ep.position = Vector3(sx * 1.18, 0.36, 3.27)
		g.add_child(ep)

	# Sidepods.
	for sx2 in [-1.0, 1.0]:
		var pod := Build.box(0.58, 0.56, 2.0, dark_m)
		pod.position = Vector3(sx2 * 0.84, 0.5, -0.35)
		g.add_child(pod)

	# Driver — helmet + glowing visor in the open cockpit.
	var helmet := Build.box(0.44, 0.46, 0.44, helmet_m)
	helmet.position = Vector3(0, 0.98, 0.15)
	g.add_child(helmet)
	var visor := Build.box(0.38, 0.15, 0.1, visor_m)
	visor.position = Vector3(0, 1.02, 0.37)
	g.add_child(visor)

	# Roll hoop / airbox behind the driver.
	var airbox := Build.box(0.5, 0.62, 0.7, body_m)
	airbox.position = Vector3(0, 1.02, -0.7)
	g.add_child(airbox)

	# Engine cover sloping down to the rear.
	var cover := Build.box(0.72, 0.5, 1.7, body_m)
	cover.position = Vector3(0, 0.68, -1.7)
	cover.rotation.x = -0.12
	g.add_child(cover)

	# Rear wing.
	for sx3 in [-1.0, 1.0]:
		var rep := Build.box(0.12, 1.0, 0.9, dark_m)
		rep.position = Vector3(sx3 * 0.96, 0.92, -2.95)
		g.add_child(rep)
	var rw_top := Build.box(2.15, 0.14, 0.72, dark_m)
	rw_top.position = Vector3(0, 1.34, -2.95)
	g.add_child(rw_top)
	var rw_low := Build.box(1.7, 0.1, 0.46, dark_m)
	rw_low.position = Vector3(0, 0.72, -3.0)
	g.add_child(rw_low)
	var pylon := Build.box(0.2, 0.66, 0.4, dark_m)
	pylon.position = Vector3(0, 1.0, -2.86)
	g.add_child(pylon)

	# Exposed tyres — fat, bigger at the rear — on suspension arms.
	for spec in [[1.18, 1.55, 0.5, 0.44], [1.2, -2.0, 0.6, 0.6]]:
		for sx4 in [-1.0, 1.0]:
			var tx: float = sx4 * spec[0]
			var tz: float = spec[1]
			var tr: float = spec[2]
			var tw: float = spec[3]
			var tire := Build.cyl(tr, tr, tw, 14, tire_m)
			tire.rotation.z = PI / 2.0
			tire.position = Vector3(tx, tr, tz)
			g.add_child(tire)
			var rim := Build.cyl(tr * 0.5, tr * 0.5, tw + 0.04, 10, rim_m)
			rim.rotation.z = PI / 2.0
			rim.position = Vector3(tx, tr, tz)
			g.add_child(rim)
			var arm_len: float = absf(tx) - 0.42
			for az in [-0.4, 0.4]:
				var arm := Build.box(arm_len, 0.08, 0.09, dark_m)
				arm.position = Vector3(tx - sx4 * arm_len / 2.0, tr, tz + az)
				g.add_child(arm)

	return g
