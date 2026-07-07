class_name Human
## Spawns the realistic human used for the player, NPCs, cops, VIPs and guards.
##
## Backed by Quaternius's "Universal Base Characters" (CC0) — a rigged, textured
## adult body (male / female) on a UE-style skeleton. No mocap clips ship with
## the free pack, so the walk is driven PROCEDURALLY by swinging the real
## skeleton's leg/arm bones (a richer version of the old box-figure swing).
##
## Public API is unchanged so every spawn site keeps working:
##   * build(...) -> Node3D, origin at the feet, carrying a "skel" meta (the
##     Skeleton3D) and a "limbs" marker set (weapon holders attach to armR).
##   * animate(...) swings the bones for walk / idle. Nodes WITHOUT "skel" but
##     WITH box "limbs" (the Iron Man suit) fall back to per-limb rotation.

const MALE: PackedScene = preload("res://assets/characters/ubc/male.gltf")
const FEMALE: PackedScene = preload("res://assets/characters/ubc/female.gltf")
const HAIR_MALE: PackedScene = preload("res://assets/characters/ubc/hair_male.gltf")
const HAIR_FEMALE: PackedScene = preload("res://assets/characters/ubc/hair_female.gltf")

const HEIGHT_SCALE := 1.05        # raw model ~1.82u tall → ~1.91u
const FACE_OFFSET := 0.0          # model already faces +Z (the game's forward)
const ARM_DOWN := 1.45            # bring T-pose arms down to the sides (radians)

const _X := Vector3(1, 0, 0)      # skeleton-space left/right axis (limb swing)
const _Z := Vector3(0, 0, 1)      # skeleton-space forward axis (arms down)


static func build(skin: int, shirt: int, pants := 0x2a2a3a, hair := 0x2a1a08, hat := -1, female := false) -> Node3D:
	var g := Node3D.new()

	var model: Node3D = (FEMALE if female else MALE).instantiate()
	model.scale = Vector3(HEIGHT_SCALE, HEIGHT_SCALE, HEIGHT_SCALE)
	model.rotation.y = FACE_OFFSET
	g.add_child(model)

	var sk: Skeleton3D = _find(model, "Skeleton3D")
	# The UBC body is one full-body material, so per-garment tinting isn't
	# possible — blend the SHIRT colour into the body tone instead. Cops read
	# navy, SWAT near-black, guards charcoal, VIPs cream, civilians earthy;
	# a pure skin wash made every faction an identical pale civilian.
	var body := Build.hex(skin).lerp(Build.hex(shirt), 0.5).lerp(Color.WHITE, 0.35)
	_tint(model, body, 0.32, 0.32, 0.32)

	# Hair — a static mesh authored at the head's rest position, so parenting it
	# under the (scaled) model drops it onto the head. Tinted after the body so it
	# takes the hair colour, not the skin tone. A hat colour (uniform headgear —
	# police caps etc.) overrides the hair colour so it reads as a dark cap.
	var hair_node: Node3D = (HAIR_FEMALE if female else HAIR_MALE).instantiate()
	model.add_child(hair_node)
	var head_col := Build.hex(hat) if hat >= 0 else Build.hex(hair).lerp(Color.WHITE, 0.25)
	_tint(hair_node, head_col, 0.05, 0.05, 0.05)

	if sk != null:
		_pose_walk(sk, 0.0, 0.0)          # drop into the idle (arms-down) pose now
		g.set_meta("skel", sk)

	# Weapon hand — a marker bone-attached to the right hand so a held weapon
	# tracks the hand through the walk cycle. Weapons are modelled pointing +Z
	# with the grip at -Y, so we cancel the hand bone's orientation to make the
	# marker axis-aligned with the character (weapon then points forward).
	var armR := Node3D.new()
	if sk != null and sk.find_bone("hand_r") >= 0:
		var hb := sk.find_bone("hand_r")
		var hand_basis := sk.get_bone_global_pose(hb).basis.orthonormalized()
		var ba := BoneAttachment3D.new()
		ba.bone_name = "hand_r"
		sk.add_child(ba)
		ba.add_child(armR)
		armR.transform = Transform3D(hand_basis.inverse(), Vector3(0.0, 0.0, 0.08))
	else:
		armR.position = Vector3(-0.25, 1.2, 0.15)
		g.add_child(armR)

	# Remaining markers exist only so legacy code (sitting pose pokes, armL
	# holders) keeps working; rotating them has no visible effect on the rig.
	var armL := _marker(g, Vector3(0.25, 1.2, 0.15))
	var legL := _marker(g, Vector3(0.12, 0.95, 0.0))
	var legR := _marker(g, Vector3(-0.12, 0.95, 0.0))
	var headG := _marker(g, Vector3(0.0, 1.6, 0.0))
	g.set_meta("limbs", {"armL": armL, "armR": armR, "legL": legL, "legR": legR, "headG": headG})
	return g


static func _marker(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## Multiply every material under `node` by `tone` (clamped to per-channel floors
## so it never goes muddy). Used for subtle per-character skin and hair variation.
static func _tint(node: Node3D, tone: Color, rmin: float, gmin: float, bmin: float) -> void:
	var c := Color(clampf(tone.r, rmin, 1.0), clampf(tone.g, gmin, 1.0), clampf(tone.b, bmin, 1.0))
	for mi in _all(node, "MeshInstance3D"):
		var inst := mi as MeshInstance3D
		var surfaces: int = (inst.mesh.get_surface_count() if inst.mesh != null else 0)
		for s in surfaces:
			var base := inst.get_active_material(s)
			if base is StandardMaterial3D:
				var m := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.albedo_color = c
				inst.set_surface_override_material(s, m)


# =====================================================================
# Animation
# =====================================================================
## Walk / idle. Rigged figures swing real bones; the legacy box figure (Iron Man
## suit) still gets per-limb rotation.
static func animate(node: Node3D, phase: float, moving: bool, leg_amp := 0.7, arm_amp := 0.49) -> void:
	if node.has_meta("skel"):
		var sk: Skeleton3D = node.get_meta("skel")
		if not is_instance_valid(sk):
			return
		var s: float = (sin(phase) if moving else 0.0)
		_pose_walk(sk, s * leg_amp, s * arm_amp)
		return

	# ---- Legacy box-figure fallback (the Iron Man suit) ----
	if not node.has_meta("limbs"):
		return
	var lim: Dictionary = node.get_meta("limbs")
	var sw: float = (sin(phase) if moving else 0.0)
	lim.legL.rotation.x = sw * leg_amp
	lim.legR.rotation.x = -sw * leg_amp
	lim.armL.rotation.x = -sw * arm_amp
	lim.armR.rotation.x = sw * arm_amp


## Seated riding pose for the rigged figure — thighs tucked forward to the
## pegs, arms reaching the handlebars. Same bones as the walk cycle, so the
## next animate() call recovers the standing pose. The bone-attached weapon
## marker (armR) is deliberately untouched.
static func sit(node: Node3D) -> void:
	if not node.has_meta("skel"):
		return
	var sk: Skeleton3D = node.get_meta("skel")
	if not is_instance_valid(sk):
		return
	_pose(sk, "thigh_r", Quaternion(_X, 0.95))
	_pose(sk, "thigh_l", Quaternion(_X, 0.95))
	_pose(sk, "upperarm_r", Quaternion(_X, -1.05) * Quaternion(_Z, ARM_DOWN))
	_pose(sk, "upperarm_l", Quaternion(_X, -1.05) * Quaternion(_Z, -ARM_DOWN))


## Pose the four swing bones: legs swing fore/aft about X; arms hang down (about
## Z) and swing opposite the legs about X.
static func _pose_walk(sk: Skeleton3D, leg: float, arm: float) -> void:
	_pose(sk, "thigh_r", Quaternion(_X, -leg))
	_pose(sk, "thigh_l", Quaternion(_X, leg))
	_pose(sk, "upperarm_r", Quaternion(_X, arm) * Quaternion(_Z, ARM_DOWN))
	_pose(sk, "upperarm_l", Quaternion(_X, -arm) * Quaternion(_Z, -ARM_DOWN))


## Apply a skeleton-space rotation `qc` to a bone, on top of its rest pose, by
## converting through the (un-animated) parent's basis. Robust to whatever the
## bone's own local axes happen to be.
##
## The bone index, parent rotation and rest rotation are all constant for a
## given skeleton (the parents are never animated), so they're cached on the
## skeleton after the first lookup — find_bone() is a linear name scan and
## get_bone_global_pose() forces a full dirty-pose recompute, which at 40+
## animated NPCs × 4 bones per frame was a real frame-time cost.
static func _pose(sk: Skeleton3D, bone: String, qc: Quaternion) -> void:
	var cache: Dictionary
	if sk.has_meta("pose_cache"):
		cache = sk.get_meta("pose_cache")
	else:
		cache = {}
		sk.set_meta("pose_cache", cache)
	var e: Dictionary = cache.get(bone, {})
	if e.is_empty():
		var idx := sk.find_bone(bone)
		if idx < 0:
			cache[bone] = {"idx": -1}
			return
		var p := sk.get_bone_parent(idx)
		e = {
			"idx": idx,
			"pb": sk.get_bone_global_pose(p).basis.get_rotation_quaternion(),
			"rest": sk.get_bone_rest(idx).basis.get_rotation_quaternion(),
		}
		cache[bone] = e
	if e.idx < 0:
		return
	var pb: Quaternion = e.pb
	sk.set_bone_pose_rotation(e.idx, pb.inverse() * qc * pb * e.rest)


# =====================================================================
# Helpers
# =====================================================================
static func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null


static func _all(n: Node, cls: String, acc: Array = []) -> Array:
	if n.get_class() == cls:
		acc.append(n)
	for c in n.get_children():
		_all(c, cls, acc)
	return acc
