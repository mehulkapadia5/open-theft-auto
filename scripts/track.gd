class_name Track
extends Node3D
## Procedural F1 circuit — a closed Catmull-Rom loop through the wilderness
## around the city. The road is flat (cars drive on the ground plane); hills and
## tunnels are scenery framing it.
##
## Build order: bake the centreline, then road / curbs / props read from it.
## `baked` + `rights` are the racing line shared by checkpoints and AI racers.

const WIDTH := 16.0
const HW := 8.0
const SAMPLE := 6.0          # metres between baked centreline points
const RUNOFF := 9.0          # flat apron flanking the road on each side
const ESTATE := Vector2(-150.0, -250.0)   # billionaire estate centre

# Circuit centreline control points (x, z), clockwise. All kept north of the
# southern sea line so the road is plain drivable wilderness.
const NODES: Array = [
	Vector2(-270, -330), Vector2(110, -332), Vector2(300, -316),
	Vector2(352, -288), Vector2(386, -210), Vector2(390, -90),
	Vector2(388, 30), Vector2(372, 110), Vector2(322, 152),
	Vector2(250, 156), Vector2(110, 146), Vector2(-60, 154),
	Vector2(-210, 150), Vector2(-330, 112), Vector2(-380, 36),
	Vector2(-390, -54), Vector2(-384, -118), Vector2(-360, -168),
	Vector2(-322, -224), Vector2(-300, -276), Vector2(-284, -314),
]

var baked: PackedVector3Array = PackedVector3Array()    # centreline points (y≈0)
var rights: PackedVector3Array = PackedVector3Array()   # per-point right vector
var forwards: PackedVector3Array = PackedVector3Array() # per-point tangent
var total_length := 0.0

var pit_spots: PackedVector3Array = PackedVector3Array() # pit-lane bay centres
var paddock_pos := Vector3.ZERO                          # race-entry point
var podium_pos := Vector3.ZERO                           # winner's podium
var solids: Array = []       # collision AABBs for the track's solid buildings
							 # — world.generate() folds them into `buildings`

var _road_mat: StandardMaterial3D


func build() -> void:
	_bake_centerline()
	_road_mat = Build.mat(Build.hex(0x2b2b31), 0.92)
	_road_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_runoff()
	_build_road()
	_build_markings()
	_build_curbs()
	_build_barriers()
	_build_streetlights()
	_build_tunnel()
	_build_gantry()
	_build_pits()
	_build_grandstands()
	_build_paddock()
	_build_podium()
	_build_estate()


## Record a solid axis-aligned collision box for a yaw-rotated structure. The
## rotated footprint is bounded conservatively; good enough for buildings that
## sit well off the racing line.
func _solid(pos: Vector3, w: float, d: float, h: float, yaw := 0.0) -> void:
	var c := absf(cos(yaw))
	var s := absf(sin(yaw))
	solids.append({"x": pos.x, "z": pos.z,
		"w": w * c + d * s, "d": w * s + d * c, "h": h})


## Curvature at baked index `i`: 0 on a straight, climbing toward ~2 at a hairpin.
func _corner_amount(i: int) -> float:
	var m := baked.size()
	var a: Vector3 = forwards[(i - 4 + m) % m]
	var b: Vector3 = forwards[(i + 4) % m]
	return 1.0 - a.dot(b)


# ---------------- Centreline ----------------
func _bake_centerline() -> void:
	var n := NODES.size()
	for i in n:
		var p0: Vector2 = NODES[(i - 1 + n) % n]
		var p1: Vector2 = NODES[i]
		var p2: Vector2 = NODES[(i + 1) % n]
		var p3: Vector2 = NODES[(i + 2) % n]
		var steps: int = maxi(2, int(p1.distance_to(p2) / SAMPLE))
		for s in steps:
			var t := float(s) / float(steps)
			var pt := _catmull(p0, p1, p2, p3, t)
			# 0.16, not 0.13: the southern straight overlaps the city's own
			# tarmac (road_y = 0.13) — coplanar surfaces shimmer (z-fight).
			baked.append(Vector3(pt.x, 0.16, pt.y))
	# Tangents + right vectors from neighbouring points.
	var m := baked.size()
	for i in m:
		var a: Vector3 = baked[(i - 1 + m) % m]
		var b: Vector3 = baked[(i + 1) % m]
		var tang := b - a
		tang.y = 0.0
		tang = tang.normalized()
		forwards.append(tang)
		rights.append(Vector3(-tang.z, 0.0, tang.x))
		total_length += baked[i].distance_to(baked[(i + 1) % m])


func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
		t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Width of the road at baked index `i` — widened on corners for runoff feel.
func width_at(i: int) -> float:
	var m := baked.size()
	var a: Vector3 = forwards[(i - 4 + m) % m]
	var b: Vector3 = forwards[(i + 4) % m]
	var curve := 1.0 - a.dot(b)            # 0 straight … ~2 hairpin
	return WIDTH + clampf(curve, 0.0, 1.0) * 6.0


# ---------------- Road surface ----------------
func _build_road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := baked.size()
	for i in n:
		var j := (i + 1) % n
		var hwa := width_at(i) / 2.0
		var hwb := width_at(j) / 2.0
		var la := baked[i] - rights[i] * hwa
		var ra := baked[i] + rights[i] * hwa
		var lb := baked[j] - rights[j] * hwb
		var rb := baked[j] + rights[j] * hwb
		_tri(st, la, ra, rb)
		_tri(st, la, rb, lb)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _road_mat
	add_child(mi)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v in [a, b, c]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)


# ---------------- Runoff apron ----------------
func _build_runoff() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := baked.size()
	for i in n:
		var j := (i + 1) % n
		var hwa := width_at(i) / 2.0 + RUNOFF
		var hwb := width_at(j) / 2.0 + RUNOFF
		# 0.10, not 0.07: keeps the apron clear of the city footpath height.
		var ya := Vector3(baked[i].x, 0.10, baked[i].z)
		var yb := Vector3(baked[j].x, 0.10, baked[j].z)
		var la := ya - rights[i] * hwa
		var ra := ya + rights[i] * hwa
		var lb := yb - rights[j] * hwb
		var rb := yb + rights[j] * hwb
		_tri(st, la, ra, rb)
		_tri(st, la, rb, lb)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var sand := Build.mat(Build.hex(0xb9a36a), 0.95)
	sand.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = sand
	add_child(mi)


# ---------------- Curbs ----------------
func _build_curbs() -> void:
	var red := Build.mat(Build.hex(0xb23a32), 0.7)
	var white := Build.mat(Build.hex(0xe6e6de), 0.7)
	var n := baked.size()
	for i in n:
		if _corner_amount(i) < 0.05:
			continue
		var hw := width_at(i) / 2.0
		var yaw := atan2(forwards[i].x, forwards[i].z)
		for side in [-1.0, 1.0]:
			var c := Build.box(1.0, 0.14, 3.2, red if i % 2 == 0 else white)
			c.position = baked[i] + rights[i] * side * hw + Vector3(0, 0.02, 0)
			c.rotation.y = yaw
			add_child(c)


# ---------------- Barriers (visual) ----------------
func _build_barriers() -> void:
	var armco := Build.mat(Build.hex(0x9a9ca0), 0.4, 0.6)
	var post_m := Build.mat(Build.hex(0x33353b), 0.7)
	var n := baked.size()
	var i := 0
	while i < n:
		var off := width_at(i) / 2.0 + RUNOFF + 1.2
		var yaw := atan2(forwards[i].x, forwards[i].z)
		for side in [-1.0, 1.0]:
			var pos: Vector3 = baked[i] + rights[i] * side * off
			var rail := Build.box(0.4, 0.55, 7.4, armco)
			rail.position = Vector3(pos.x, 0.85, pos.z)
			rail.rotation.y = yaw
			add_child(rail)
			var post := Build.box(0.3, 0.85, 0.3, post_m)
			post.position = Vector3(pos.x, 0.42, pos.z)
			add_child(post)
		i += 2


func _in_tunnel(p: Vector3) -> bool:
	return p.x < -358.0


# ---------------- Streetlights ----------------
func _build_streetlights() -> void:
	var pole_m := Build.mat(Build.hex(0x2a2c31), 0.6)
	var lamp_m := Build.emissive(Build.hex(0x2a2418), Color("ffe6a8"), 1.8)
	var n := baked.size()
	var i := 0
	while i < n:
		if not _in_tunnel(baked[i]):
			var off := width_at(i) / 2.0 + RUNOFF + 2.4
			var base: Vector3 = baked[i] + rights[i] * off
			var pole := Build.cyl(0.16, 0.2, 6.5, 6, pole_m)
			pole.position = Vector3(base.x, 3.25, base.z)
			add_child(pole)
			var arm := Build.box(0.16, 0.16, 2.2, pole_m)
			arm.position = base + rights[i] * -1.1 + Vector3(0, 6.3, 0)
			add_child(arm)
			var lamp := Build.box(0.8, 0.3, 1.0, lamp_m)
			lamp.position = base + rights[i] * -2.2 + Vector3(0, 6.1, 0)
			add_child(lamp)
		i += 9


# ---------------- Tunnel sector ----------------
func _build_tunnel() -> void:
	var shell_m := Build.mat(Build.hex(0x3a3c44), 0.85)
	var neon_m := Build.emissive(Build.hex(0x12203a), Color("4fd6ff"), 2.6)
	var n := baked.size()
	var i := 0
	while i < n:
		if _in_tunnel(baked[i]):
			var hw := width_at(i) / 2.0 + 2.0
			var yaw := atan2(forwards[i].x, forwards[i].z)
			for side in [-1.0, 1.0]:
				var wall := Build.box(1.2, 6.0, 8.0, shell_m)
				wall.position = baked[i] + rights[i] * side * hw + Vector3(0, 3.0, 0)
				wall.rotation.y = yaw
				add_child(wall)
			var roof := Build.box(hw * 2.0 + 1.4, 1.0, 8.0, shell_m)
			roof.position = baked[i] + Vector3(0, 6.0, 0)
			roof.rotation.y = yaw
			add_child(roof)
			var neon := Build.box(hw * 1.6, 0.2, 7.6, neon_m)
			neon.position = baked[i] + Vector3(0, 5.4, 0)
			neon.rotation.y = yaw
			add_child(neon)
		i += 2


# ---------------- Start / finish gantry ----------------
func _build_gantry() -> void:
	var dark := Build.mat(Build.hex(0x26282e), 0.6)
	var hw := width_at(0) / 2.0 + 1.5
	var yaw := atan2(forwards[0].x, forwards[0].z)
	for side in [-1.0, 1.0]:
		var post := Build.box(1.2, 8.0, 1.2, dark)
		post.position = baked[0] + rights[0] * side * hw + Vector3(0, 4.0, 0)
		add_child(post)
	var beam := Build.box(hw * 2.0 + 1.2, 1.6, 1.2, dark)
	beam.position = baked[0] + Vector3(0, 8.4, 0)
	beam.rotation.y = yaw
	add_child(beam)
	var label := Label3D.new()
	label.text = "START  /  FINISH"
	label.font_size = 130
	label.pixel_size = 0.013
	label.modulate = Color("ffe27a")
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.position = baked[0] + Vector3(0, 8.4, 0)
	label.rotation.y = yaw + PI / 2.0
	add_child(label)


# ---------------- Pit complex ----------------
func _build_pits() -> void:
	var wall_m := Build.mat(Build.hex(0xdfe2e6), 0.7)
	var door_m := Build.mat(Build.hex(0x33363d), 0.5)
	var lane_m := Build.mat(Build.hex(0x343640), 0.9)
	var n := baked.size()
	var bay := 0
	var i := 4
	while i < n and bay < 8:
		# Pits line the main start straight (the long northern straight).
		if baked[i].z < -312.0 and _corner_amount(i) < 0.03:
			var inward: Vector3 = rights[i]          # +rights points inside the loop
			var yaw := atan2(forwards[i].x, forwards[i].z)
			var lane := baked[i] + inward * (width_at(i) / 2.0 + 6.0)
			var strip := Build.box(11.0, 0.12, 13.0, lane_m)
			strip.position = Vector3(lane.x, 0.1, lane.z)
			strip.rotation.y = yaw
			add_child(strip)
			pit_spots.append(Vector3(lane.x, 0.0, lane.z))
			var gpos := baked[i] + inward * (width_at(i) / 2.0 + 13.0)
			var garage := Build.box(9.0, 4.6, 7.0, wall_m)
			garage.position = Vector3(gpos.x, 2.4, gpos.z)
			garage.rotation.y = yaw
			add_child(garage)
			_solid(gpos, 9.0, 7.0, 4.6, yaw)
			var door := Build.box(5.2, 3.4, 0.3, door_m)
			door.position = (baked[i] + inward * (width_at(i) / 2.0 + 9.6)) \
				+ Vector3(0, 1.85, 0)
			door.rotation.y = yaw
			add_child(door)
			bay += 1
			i += 7
		else:
			i += 1


# ---------------- Grandstands ----------------
func _build_grandstand(at: Vector3, face_yaw: float) -> void:
	var stand_m := Build.mat(Build.hex(0x6a6e78), 0.85)
	var seat_m := Build.mat(Build.hex(0xb23a32), 0.8)
	var fwd := Vector3(sin(face_yaw), 0, cos(face_yaw))
	var side := Vector3(-fwd.z, 0, fwd.x)
	for tier in 6:
		var step := Build.box(22.0, 1.2, 2.4, stand_m if tier % 2 else seat_m)
		var back: Vector3 = at - fwd * (tier * 2.0) + Vector3(0, tier * 1.2 + 0.6, 0)
		step.position = back
		step.rotation.y = face_yaw
		add_child(step)
	_solid(at - fwd * 5.0, 22.0, 12.4, 7.4, face_yaw)


func _build_grandstands() -> void:
	# One stand overlooking the start, one at the hairpin (south-east).
	var hw := width_at(0) / 2.0 + RUNOFF + 6.0
	_build_grandstand(baked[0] - rights[0] * hw,
		atan2(rights[0].x, rights[0].z))
	# Hairpin: the south-east-most baked point.
	var hp := 0
	for i in baked.size():
		if baked[i].x + baked[i].z > baked[hp].x + baked[hp].z:
			hp = i
	var hhw := width_at(hp) / 2.0 + RUNOFF + 6.0
	_build_grandstand(baked[hp] + rights[hp] * hhw,
		atan2(-rights[hp].x, -rights[hp].z))


# ---------------- Paddock — race HQ ----------------
## The paddock building sits on the infield by the start straight. Driving an
## F1 car up to it is how the player enters the Grand Prix.
func _build_paddock() -> void:
	var inward: Vector3 = rights[0]
	var base: Vector3 = baked[0] + inward * (HW + RUNOFF + 26.0)
	paddock_pos = Vector3(base.x, 0.0, base.z)
	var yaw := atan2(-inward.x, -inward.z)               # face the track

	var apron := Build.box(34.0, 0.16, 24.0, Build.mat(Build.hex(0x3a3c42), 0.9))
	apron.position = Vector3(base.x, 0.08, base.z)
	apron.rotation.y = yaw
	add_child(apron)
	# Two-storey glass HQ.
	var hall := Build.box(26.0, 9.0, 12.0, Build.mat(Build.hex(0x2c2f37), 0.4, 0.4))
	hall.position = Vector3(base.x, 4.6, base.z)
	hall.rotation.y = yaw
	add_child(hall)
	_solid(Vector3(base.x, 0.0, base.z), 26.0, 12.0, 9.0, yaw)
	var glassrow := Build.mat(Build.hex(0x2a4255), 0.1, 0.5)
	glassrow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glassrow.albedo_color.a = 0.55
	var glass := Build.box(24.0, 4.4, 0.4, glassrow)
	glass.position = base + Vector3(0, 4.2, 0) - Vector3(sin(yaw), 0, cos(yaw)) * 6.1
	glass.rotation.y = yaw
	add_child(glass)
	var fascia := Build.emissive(Build.hex(0x1a1305), Color("ffd45a"), 2.2)
	var band := Build.box(26.0, 1.8, 0.4, fascia)
	band.position = base + Vector3(0, 9.6, 0) - Vector3(sin(yaw), 0, cos(yaw)) * 6.0
	band.rotation.y = yaw
	add_child(band)
	var sign := Label3D.new()
	sign.text = "GRAND PRIX PADDOCK"
	sign.font_size = 84
	sign.pixel_size = 0.013
	sign.modulate = Color("1a1305")
	sign.outline_size = 0
	sign.rotation.y = yaw + PI
	sign.position = base + Vector3(0, 9.6, 0) - Vector3(sin(yaw), 0, cos(yaw)) * 6.25
	add_child(sign)
	# A glowing entry marker on the apron — drive the F1 here to enter.
	var ring := Build.emissive(Build.hex(0x1a1305), Color("ffd45a"), 2.4)
	var disc := Build.cyl(4.5, 4.5, 0.1, 28, ring)
	disc.position = Vector3(base.x, 0.2, base.z) + Vector3(sin(yaw), 0, cos(yaw)) * 9.0
	add_child(disc)
	paddock_pos = disc.position
	var prompt := Label3D.new()
	prompt.text = "ENTER GRAND PRIX"
	prompt.font_size = 60
	prompt.pixel_size = 0.007
	prompt.modulate = Color("ffe9a8")
	prompt.outline_modulate = Color(0, 0, 0, 0.85)
	prompt.position = paddock_pos + Vector3(0, 3.0, 0)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(prompt)


# ---------------- Podium ----------------
## A three-step winner's podium on the infield beside the start/finish line.
func _build_podium() -> void:
	var inward: Vector3 = rights[0]
	var fwd: Vector3 = forwards[0]
	var base: Vector3 = baked[0] + inward * (HW + RUNOFF + 7.0) + fwd * 10.0
	podium_pos = Vector3(base.x, 0.0, base.z)
	var yaw := atan2(-inward.x, -inward.z)
	var gold := Build.mat(Build.hex(0xc2a05a), 0.4, 0.5)
	var pale := Build.mat(Build.hex(0xb8bcc4), 0.7)
	# Steps: centre (1st) tallest, flanked by 2nd and 3rd.
	var heights := [1.7, 2.5, 1.2]
	var slots := [-1.0, 0.0, 1.0]
	for k in 3:
		var h: float = heights[k]
		var step := Build.box(3.4, h, 3.4, gold if k == 1 else pale)
		step.position = base + inward.cross(Vector3.UP) * 0.0 \
			+ Vector3(sin(yaw + PI / 2.0), 0, cos(yaw + PI / 2.0)) * slots[k] * 3.7 \
			+ Vector3(0, h / 2.0, 0)
		step.rotation.y = yaw
		add_child(step)
	# Backdrop board.
	var board := Build.emissive(Build.hex(0x141414), Color("ffd45a"), 1.4)
	var panel := Build.box(13.0, 3.4, 0.4, board)
	panel.position = base + Vector3(0, 4.6, 0) - Vector3(sin(yaw), 0, cos(yaw)) * 2.4
	panel.rotation.y = yaw
	add_child(panel)
	var sign := Label3D.new()
	sign.text = "WINNERS"
	sign.font_size = 96
	sign.pixel_size = 0.012
	sign.modulate = Color("ffe9a8")
	sign.outline_modulate = Color(0, 0, 0, 0.85)
	sign.rotation.y = yaw + PI
	sign.position = base + Vector3(0, 4.6, 0) - Vector3(sin(yaw), 0, cos(yaw)) * 2.65
	add_child(sign)


## True if `pos` is in the pit lane — slow down here during a race to repair.
func in_pit_lane(pos: Vector3) -> bool:
	for s in pit_spots:
		if Vector2(s.x - pos.x, s.z - pos.z).length() < 9.0:
			return true
	return false


## Starting-grid slot `i` (0 = pole), staggered two-wide behind the line.
func grid_slot(i: int) -> Vector3:
	var row := i / 2
	var side := -1.0 if i % 2 == 0 else 1.0
	var p: Vector3 = baked[0] - forwards[0] * (7.0 + row * 8.0) \
		+ rights[0] * side * 3.2
	return Vector3(p.x, 0.0, p.z)


## Heading (yaw) cars face on the starting grid.
func grid_yaw() -> float:
	return atan2(forwards[0].x, forwards[0].z)


# ---------------- Billionaire estate (Mansion Sector) ----------------
func _build_estate() -> void:
	var ex := ESTATE.x
	var ez := ESTATE.y
	var wall_m := Build.mat(Build.hex(0xeceef0), 0.6)
	var glass_m := Build.mat(Build.hex(0x1f2c3a), 0.12, 0.5)
	var roof_m := Build.mat(Build.hex(0x33363d), 0.8)
	var lawn_m := Build.mat(Build.hex(0x5f7a44), 0.95)
	var water_m := Build.mat(Build.hex(0x2f8fb0), 0.15, 0.35)
	var pave_m := Build.mat(Build.hex(0xb7b2a6), 0.9)

	var lawn := Build.box(70.0, 0.14, 54.0, lawn_m)
	lawn.position = Vector3(ex, 0.08, ez)
	add_child(lawn)

	# Main mansion — two stepped storeys with flat roofs.
	var g1 := Build.box(26.0, 5.4, 14.0, wall_m)
	g1.position = Vector3(ex, 2.9, ez + 6.0)
	add_child(g1)
	_solid(Vector3(ex, 0.0, ez + 6.0), 26.0, 14.0, 10.6)
	var r1 := Build.box(26.8, 0.5, 14.8, roof_m)
	r1.position = Vector3(ex, 5.85, ez + 6.0)
	add_child(r1)
	var g2 := Build.box(16.0, 4.6, 9.0, wall_m)
	g2.position = Vector3(ex - 3.0, 7.8, ez + 7.0)
	add_child(g2)
	var r2 := Build.box(16.7, 0.45, 9.7, roof_m)
	r2.position = Vector3(ex - 3.0, 10.33, ez + 7.0)
	add_child(r2)
	for wx in [-8.0, -3.0, 2.0, 7.0]:
		var pane := Build.box(3.0, 3.0, 0.24, glass_m)
		pane.position = Vector3(ex + wx, 2.8, ez + 6.0 - 7.05)
		add_child(pane)

	# Helipad on the main roof.
	var pad := Build.cyl(3.0, 3.0, 0.14, 24, Build.mat(Build.hex(0x2e3138), 0.9))
	pad.position = Vector3(ex + 8.0, 5.75, ez + 6.0)
	add_child(pad)

	# Two guest houses.
	for gx in [-26.0, 26.0]:
		var guest := Build.box(10.0, 4.0, 9.0, wall_m)
		guest.position = Vector3(ex + gx, 2.1, ez - 12.0)
		add_child(guest)
		_solid(Vector3(ex + gx, 0.0, ez - 12.0), 10.0, 9.0, 4.4)
		var groof := Build.box(10.8, 0.4, 9.8, roof_m)
		groof.position = Vector3(ex + gx, 4.3, ez - 12.0)
		add_child(groof)

	# Infinity pool + deck.
	var deck := Build.box(20.0, 0.16, 12.0, pave_m)
	deck.position = Vector3(ex + 16.0, 0.13, ez - 2.0)
	add_child(deck)
	var pool := Build.box(14.0, 0.34, 7.0, water_m)
	pool.position = Vector3(ex + 16.0, 0.26, ez - 2.0)
	add_child(pool)

	# Security gate + sign facing the estate's driveway.
	for px in [-6.0, 6.0]:
		var post := Build.box(1.4, 3.4, 1.4, wall_m)
		post.position = Vector3(ex + px, 1.7, ez - 25.0)
		add_child(post)
	var palms := [Vector2(ex - 30, ez + 18), Vector2(ex + 30, ez + 18),
		Vector2(ex - 30, ez - 20), Vector2(ex + 30, ez - 20)]
	for pm in palms:
		var trunk := Build.cyl(0.3, 0.4, 6.0, 7, Build.mat(Build.hex(0x6b4422), 0.95))
		trunk.position = Vector3(pm.x, 3.0, pm.y)
		add_child(trunk)
		var frond := Build.cyl(0.1, 2.6, 1.6, 7, Build.mat(Build.hex(0x3f6a36), 0.9))
		frond.position = Vector3(pm.x, 6.6, pm.y)
		add_child(frond)
	var sign := Label3D.new()
	sign.text = "VINEWOOD HILLS"
	sign.font_size = 80
	sign.pixel_size = 0.013
	sign.modulate = Color("fff2d2")
	sign.outline_modulate = Color(0, 0, 0, 0.9)
	sign.position = Vector3(ex, 4.4, ez - 25.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)


## True if (x, z) lies within `margin` of the track (or the estate grounds) —
## used to keep mountains, hills and trees from spawning on the circuit.
func near(x: float, z: float, margin: float) -> bool:
	if Vector2(ESTATE.x - x, ESTATE.y - z).length() < margin + 32.0:
		return true
	for i in range(0, baked.size(), 3):
		var p: Vector3 = baked[i]
		if Vector2(p.x - x, p.z - z).length() < margin:
			return true
	return false


# ---------------- Markings ----------------
func _build_markings() -> void:
	# A dashed centre line, plus a chequered start/finish band.
	var dash_m := Build.mat(Build.hex(0xd9d9d2), 0.85)
	var n := baked.size()
	var i := 0
	while i < n:
		var p: Vector3 = baked[i]
		var dash := Build.box(0.5, 0.05, 3.4, dash_m)
		dash.position = p + Vector3(0, 0.04, 0)
		dash.rotation.y = atan2(forwards[i].x, forwards[i].z)
		add_child(dash)
		i += 5

	# Start/finish line — a chequered band across the road at baked point 0.
	var dark := Build.mat(Build.hex(0x1b1b1f), 0.8)
	var light := Build.mat(Build.hex(0xe9e9e2), 0.8)
	var hw0 := width_at(0) / 2.0
	var squares := 16
	for sq in squares:
		var f := (float(sq) / float(squares) - 0.5) * 2.0
		var cell := Build.box(2.0 * hw0 / float(squares), 0.06, 1.6,
			light if sq % 2 == 0 else dark)
		cell.position = baked[0] + rights[0] * f * hw0 + Vector3(0, 0.05, 0)
		cell.rotation.y = atan2(forwards[0].x, forwards[0].z)
		add_child(cell)


# ---------------- Racing-line queries ----------------
## Index of the baked centreline point nearest to `pos` (xz only).
func nearest_index(pos: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in baked.size():
		var d := Vector2(baked[i].x - pos.x, baked[i].z - pos.z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best


## True if `pos` lies on the drivable road surface.
func on_road(pos: Vector3) -> bool:
	var i := nearest_index(pos)
	var off := Vector2(pos.x - baked[i].x, pos.z - baked[i].z)
	return off.length() < width_at(i) / 2.0
