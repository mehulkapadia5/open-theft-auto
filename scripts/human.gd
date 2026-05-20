class_name Human
## Builds the blocky humanoid used for the player, NPCs and cops.
## Returns a Node3D; limb sub-groups are stored in meta "limbs" for walk animation.

static func build(skin: int, shirt: int, pants := 0x2a2a3a, hair := 0x2a1a08, hat := -1) -> Node3D:
	var g := Node3D.new()
	var skin_m := Build.mat(Build.hex(skin), 0.65)
	var shirt_m := Build.mat(Build.hex(shirt), 0.75)
	var pants_m := Build.mat(Build.hex(pants), 0.8)
	var hair_m := Build.mat(Build.hex(hair), 0.6)
	var shoe_m := Build.mat(Build.hex(0x111111), 0.5)
	var eye_m := Build.mat(Build.hex(0x0a0a0a), 0.3)

	var torso := Build.box(0.55, 0.7, 0.32, shirt_m)
	torso.position.y = 1.35
	g.add_child(torso)
	var shoulders := Build.box(0.74, 0.18, 0.36, shirt_m)
	shoulders.position.y = 1.69
	g.add_child(shoulders)
	var neck := Build.cyl(0.09, 0.1, 0.14, 8, skin_m)
	neck.position.y = 1.78
	g.add_child(neck)

	var head_g := Node3D.new()
	head_g.position.y = 1.92
	g.add_child(head_g)
	var head := Build.box(0.34, 0.34, 0.32, skin_m)
	head_g.add_child(head)
	var hair_box := Build.box(0.36, 0.18, 0.34, hair_m)
	hair_box.position = Vector3(0, 0.13, -0.02)
	head_g.add_child(hair_box)
	for ex in [-0.07, 0.07]:
		var eye := Build.box(0.045, 0.045, 0.02, eye_m)
		eye.position = Vector3(ex, 0.02, 0.16)
		head_g.add_child(eye)
	if hat >= 0:
		var hm := Build.mat(Build.hex(hat), 0.8)
		var brim := Build.cyl(0.23, 0.23, 0.03, 14, hm)
		brim.position = Vector3(0, 0.2, 0.04)
		head_g.add_child(brim)
		var top := Build.cyl(0.16, 0.18, 0.14, 14, hm)
		top.position = Vector3(0, 0.3, 0.04)
		head_g.add_child(top)

	var arm_l := _arm(-1, shirt_m, skin_m)
	var arm_r := _arm(1, shirt_m, skin_m)
	var leg_l := _leg(-1, pants_m, shoe_m)
	var leg_r := _leg(1, pants_m, shoe_m)
	g.add_child(arm_l)
	g.add_child(arm_r)
	g.add_child(leg_l)
	g.add_child(leg_r)
	g.set_meta("limbs", {"armL": arm_l, "armR": arm_r, "legL": leg_l, "legR": leg_r, "headG": head_g})
	return g

static func _arm(side: int, shirt_m: Material, skin_m: Material) -> Node3D:
	var ag := Node3D.new()
	ag.position = Vector3(side * 0.38, 1.7, 0)
	var upper := Build.box(0.16, 0.4, 0.16, shirt_m)
	upper.position.y = -0.2
	ag.add_child(upper)
	var fore := Build.box(0.14, 0.36, 0.14, skin_m)
	fore.position.y = -0.6
	ag.add_child(fore)
	var hand := Build.box(0.14, 0.12, 0.14, skin_m)
	hand.position.y = -0.84
	ag.add_child(hand)
	return ag

static func _leg(side: int, pants_m: Material, shoe_m: Material) -> Node3D:
	var lg := Node3D.new()
	lg.position = Vector3(side * 0.14, 1.0, 0)
	var upper := Build.box(0.22, 0.45, 0.24, pants_m)
	upper.position.y = -0.225
	lg.add_child(upper)
	var lower := Build.box(0.2, 0.45, 0.22, pants_m)
	lower.position.y = -0.675
	lg.add_child(lower)
	var shoe := Build.box(0.22, 0.1, 0.36, shoe_m)
	shoe.position = Vector3(0, -0.95, 0.05)
	lg.add_child(shoe)
	return lg

## Drive the walk-cycle animation on a built human.
static func animate(node: Node3D, phase: float, moving: bool, leg_amp := 0.7, arm_amp := 0.49) -> void:
	if not node.has_meta("limbs"):
		return
	var lim: Dictionary = node.get_meta("limbs")
	var s: float = (sin(phase) if moving else 0.0)
	lim.legL.rotation.x = s * leg_amp
	lim.legR.rotation.x = -s * leg_amp
	lim.armL.rotation.x = -s * arm_amp
	lim.armR.rotation.x = s * arm_amp
