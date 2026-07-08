class_name Human
## Spawns the realistic humans used for the player, NPCs, cops, VIPs and guards.
##
## Backed by a small MODELS catalog (see below) so different Sketchfab/Quaternius
## rigs can be dropped in without touching the spawn call sites. The default
## "ubc" model is Quaternius's "Universal Base Characters" (CC0) — a rigged,
## textured adult body (male / female) on a UE-style skeleton. No mocap clips
## ship with the free pack, so the walk is driven PROCEDURALLY by swinging the
## real skeleton's leg/arm bones (a richer version of the old box-figure swing).
## "vip_suit" and "guard_suit" are CC-BY-4.0 Sketchfab humans (see README credits).
##
## Public API is unchanged so every spawn site keeps working:
##   * build(...) -> Node3D, same as build_model("ubc", ...).
##   * build_model(kind, ...) -> Node3D, origin at the feet, carrying a "skel"
##     meta (the Skeleton3D), a "bonemap" meta (logical -> this rig's real bone
##     name) and a "limbs" marker set (weapon holders attach to armR).
##   * animate(...) swings the bones for walk / idle. Nodes WITHOUT "skel" but
##     WITH box "limbs" (the Iron Man suit) fall back to per-limb rotation.
##     "nathan" is a further special case: it ships a baked mocap walk clip,
##     so animate() hands its calls fully to that AnimationPlayer instead of
##     posing bones itself (see the "anim_player" meta below).

const MALE: PackedScene = preload("res://assets/characters/ubc/male.gltf")
const FEMALE: PackedScene = preload("res://assets/characters/ubc/female.gltf")
const HAIR_MALE: PackedScene = preload("res://assets/characters/ubc/hair_male.gltf")
const HAIR_FEMALE: PackedScene = preload("res://assets/characters/ubc/hair_female.gltf")

const VIP_SUIT_SCENE: PackedScene = preload("res://assets/characters/vip_suit/scene.gltf")
const GUARD_SUIT_SCENE: PackedScene = preload("res://assets/characters/guard_suit/scene.gltf")
const NATHAN_SCENE: PackedScene = preload("res://assets/characters/nathan/scene.gltf")
const PETER_SCENE: PackedScene = preload("res://assets/characters/peter/scene.gltf")

const HEIGHT_SCALE := 1.05        # raw model ~1.82u tall → ~1.91u
const FACE_OFFSET := 0.0          # model already faces +Z (the game's forward)

# Bring the rest-pose arms down to the sides, skeleton-space rotation about
# _Z (radians). Every rig in MODELS has a different bind pose — "ubc" is a
# full T-pose (arms horizontal), the Sketchfab imports are partial A-poses,
# and "nathan"'s rest pose is already almost hanging — so a single fixed
# angle looks right on one rig and splays the others out to the side. Each
# rig's real angle is instead MEASURED at build time from its own rest pose
# (see _measure_arm_down) and cached per model kind in _ARM_DOWN_CACHE; this
# constant now only serves as the safety fallback when a rig's hand_r/
# upperarm_r bones fail to resolve (see build_model / MODELS.bones).
const ARM_DOWN := 1.45

const _X := Vector3(1, 0, 0)      # skeleton-space left/right axis (limb swing)
const _Z := Vector3(0, 0, 1)      # skeleton-space forward axis (arms down)

const DEFAULT_KIND := "ubc"

## The character catalog. Each entry:
##   scene         PackedScene to instantiate (null for "ubc", which picks
##                 MALE/FEMALE at build time instead).
##   height_scale  uniform scale so the model reads ~1.9u tall in-game (probed
##                 via each model's AABB — these two imports come in at
##                 non-human raw scales, see the report for the numbers).
##   face_offset   extra rotation.y (radians) so the rig walks toward +Z, this
##                 game's forward. Both Sketchfab imports already face +Z after
##                 their baked-in axis-conversion nodes (verified by comparing
##                 each rig's Left/RightHand rest-pose span against the known-
##                 good "ubc" rig), so both are 0.0 — kept as explicit fields
##                 (not folded into a shared constant) so a future model that
##                 DOES need correcting is a one-line catalog edit, not a code
##                 change.
##   clothed       true = model ships its own suit/skin textures — skip the UBC
##                 skin/shirt tint and hair-mesh swap so the real materials show.
##   bones         logical bone name -> a case-insensitive SUBSTRING to find it
##                 by, since Mixamo / Blender / RPM importers all name bones
##                 differently (and Godot may append de-dupe suffixes on top).
const MODELS := {
	"ubc": {
		"scene": null, "height_scale": HEIGHT_SCALE, "face_offset": FACE_OFFSET, "clothed": false,
		"bones": {
			"thigh_l": "thigh_l", "thigh_r": "thigh_r",
			"upperarm_l": "upperarm_l", "upperarm_r": "upperarm_r", "hand_r": "hand_r",
		},
	},
	# "Indian Man in suit" (Mixamo/RPM rig) — VIPs. Raw AABB probed at 3.316u
	# tall; 1.91 / 3.316 ≈ 0.576. Bone names come through as e.g. "RightArm_039"
	# (importer-appended index suffix) — substrings still land on the base
	# bone because it precedes its own finger children in bone index order.
	"vip_suit": {
		"scene": VIP_SUIT_SCENE, "height_scale": 0.576, "face_offset": 0.0, "clothed": true,
		"bones": {
			"thigh_l": "leftupleg", "thigh_r": "rightupleg",
			"upperarm_l": "leftarm", "upperarm_r": "rightarm", "hand_r": "righthand",
		},
	},
	# "Man Dressed In Suit" (Blender/Rigify rig) — bodyguards. Raw AABB probed
	# at 17.451u tall; 1.91 / 17.451 ≈ 0.1095.
	"guard_suit": {
		"scene": GUARD_SUIT_SCENE, "height_scale": 0.1095, "face_offset": 0.0, "clothed": true,
		"bones": {
			"thigh_l": "thigh.l", "thigh_r": "thigh.r",
			"upperarm_l": "upper_arm.l", "upperarm_r": "upper_arm.r", "hand_r": "hand.r",
		},
	},
	# "Nathan" (Renderpeople free CC-BY, photo-scanned, RP rig) — a realistic
	# casual pedestrian. Model is authored ~186.9u tall; 1.91 / 186.9 ≈ 0.0102.
	# Ships a baked "Take 001" walk clip on an AnimationPlayer — unlike the other
	# three rigs, animate() plays THAT instead of procedurally posing the bones
	# (see the "anim_player" meta in build_model / animate()); the bones/bonemap
	# below are still resolved and used for the weapon-hand marker, sit(), and
	# the idle rest pose. Bone names come through prefixed
	# "rp_nathan_animated_003_walking_*" so match by the distinctive tail:
	# "upperleg_l" lands on upperleg_l_074 (not upperleg_twist_l).
	"nathan": {
		"scene": NATHAN_SCENE, "height_scale": 0.0102, "face_offset": 0.0, "clothed": true,
		"bones": {
			"thigh_l": "upperleg_l", "thigh_r": "upperleg_r",
			"upperarm_l": "upperarm_l", "upperarm_r": "upperarm_r", "hand_r": "hand_r",
		},
	},
	# "Spider-Man Peter Parker (the photographer)" (CC-BY, Unreal-mannequin rig) —
	# a clothed, smart-casual civilian used as the PLAYER model (not in the
	# civilian mix). Skinned-mesh AABB collapses to a bind bbox, so scale is off
	# the skeleton extent instead (~1.846u raw → ~1.9u at 1.03). UE bone names:
	# "thigh_l"/"upperarm_l" land on the real bones, not their *_twist_* children
	# (those read "thigh_twist"/"upperarm_twist" — no "thigh_l"/"upperarm_l"
	# substring). Arm-down is auto-measured from the rest pose like the others.
	"peter": {
		"scene": PETER_SCENE, "height_scale": 1.03, "face_offset": 0.0, "clothed": true,
		"bones": {
			"thigh_l": "thigh_l", "thigh_r": "thigh_r",
			"upperarm_l": "upperarm_l", "upperarm_r": "upperarm_r", "hand_r": "hand_r",
		},
	},
}

## Civilians pick from this list so the street shows a mix of clothed looks
## instead of one repeated body — weighted so the tinted UBC body (which has
## the widest skin/shirt/pants/hair randomisation) is still the majority, with
## suits sprinkled in as if a few office workers were out and about. Add more
## Sketchfab model ids here (plus a MODELS entry) to widen the mix further.
const CIVILIAN_KINDS := ["ubc", "ubc", "ubc", "nathan", "nathan", "vip_suit", "guard_suit"]


## Same signature as before — the default "civilian" model, tint-driven.
static func build(skin: int, shirt: int, pants := 0x2a2a3a, hair := 0x2a1a08, hat := -1, female := false) -> Node3D:
	return build_model(DEFAULT_KIND, skin, shirt, pants, hair, hat, female)


## The general entry point: `kind` selects a MODELS catalog entry. skin/shirt/
## pants/hair/hat are only used by models with clothed == false (currently
## just "ubc") — clothed models ignore them and show their own baked textures.
static func build_model(kind: String, skin := -1, shirt := -1, pants := 0x2a2a3a, hair := 0x2a1a08, hat := -1, female := false) -> Node3D:
	var cfg: Dictionary = MODELS.get(kind, MODELS[DEFAULT_KIND])
	var g := Node3D.new()

	var model: Node3D = ((FEMALE if female else MALE) if cfg.scene == null else cfg.scene).instantiate()
	model.scale = Vector3(cfg.height_scale, cfg.height_scale, cfg.height_scale)
	model.rotation.y = cfg.face_offset
	g.add_child(model)

	var sk: Skeleton3D = _find(model, "Skeleton3D")

	if not cfg.clothed:
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
	# Clothed models (vip_suit, guard_suit) ship their own suit/skin/hair
	# textures already baked in — nothing to tint.

	# Resolve this rig's real bone names once (substring match, case-insensitive)
	# and cache them on the node so animate()/sit() don't have to re-resolve.
	var bonemap := {}
	if sk != null:
		for logical in cfg.bones:
			var idx := _find_bone_like(sk, cfg.bones[logical])
			bonemap[logical] = (sk.get_bone_name(idx) if idx >= 0 else "")

		# This rig's measured arm-down angle (see _measure_arm_down) — one
		# measurement per KIND, not per instance, since the rest pose baked
		# into the imported scene is identical for every spawn of the same kind.
		if not _ARM_DOWN_CACHE.has(kind):
			_ARM_DOWN_CACHE[kind] = _measure_arm_down(sk, bonemap)
		var arm_down: float = _ARM_DOWN_CACHE[kind]

		_pose_walk(sk, 0.0, 0.0, bonemap, arm_down)      # drop into the idle (arms-down) pose now
		g.set_meta("skel", sk)
		g.set_meta("bonemap", bonemap)
		g.set_meta("arm_down", arm_down)

		# "nathan" ships a baked mocap walk clip — hand animate() over to it
		# fully (see animate()) instead of procedurally posing its bones, since
		# a real walk cycle reads better than our swing approximation. pause()
		# stops it free-running so seek() alone drives the timeline, in lock
		# step with the game's walk phase; seek(0.0) right away replaces the
		# _pose_walk() idle drop above with the clip's own (already-natural)
		# rest frame, so there's no one-frame flash of the procedural pose.
		if kind == "nathan":
			var ap := _find(model, "AnimationPlayer") as AnimationPlayer
			var clips: PackedStringArray = (ap.get_animation_list() if ap != null else PackedStringArray())
			if ap != null and clips.size() > 0:
				var clip_name: String = clips[0]
				ap.play(clip_name)
				ap.pause()
				ap.seek(0.0, true)
				g.set_meta("anim_player", ap)
				g.set_meta("anim_length", ap.get_animation(clip_name).length)

	# Weapon hand — a marker bone-attached to the right hand so a held weapon
	# tracks the hand through the walk cycle. Weapons are modelled pointing +Z
	# with the grip at -Y, so we cancel the hand bone's orientation to make the
	# marker axis-aligned with the character (weapon then points forward).
	var armR := Node3D.new()
	var hand_bone: String = bonemap.get("hand_r", "")
	var hand_idx := (sk.find_bone(hand_bone) if sk != null and hand_bone != "" else -1)
	if sk != null and hand_idx >= 0:
		var hand_basis := sk.get_bone_global_pose(hand_idx).basis.orthonormalized()
		var ba := BoneAttachment3D.new()
		ba.bone_name = hand_bone
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
	g.set_meta("model_kind", kind)
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
## suit) still gets per-limb rotation. "nathan" is a further special case (see
## the "anim_player" meta from build_model) — its walk is a baked mocap clip,
## so it's driven by seeking that clip in proportion to `phase` instead of by
## posing bones ourselves.
static func animate(node: Node3D, phase: float, moving: bool, leg_amp := 0.7, arm_amp := 0.49) -> void:
	if node.has_meta("anim_player"):
		var ap: AnimationPlayer = node.get_meta("anim_player")
		if not is_instance_valid(ap):
			return
		# Idle always seeks the same fixed frame (0.0) so it never jitters;
		# while moving, the phase (which the caller drives from the walk
		# cycle, same as the sin(phase) rigs below) maps linearly onto the
		# clip's timeline. seek(..., true) forces an immediate re-pose instead
		# of waiting for the AnimationPlayer's own (paused, so otherwise inert)
		# process step.
		var anim_len: float = node.get_meta("anim_length", 1.0)
		var t: float = (fposmod(phase, TAU) / TAU * anim_len) if moving else 0.0
		ap.seek(t, true)
		return

	if node.has_meta("skel"):
		var sk: Skeleton3D = node.get_meta("skel")
		if not is_instance_valid(sk):
			return
		var bonemap: Dictionary = node.get_meta("bonemap", {})
		var arm_down: float = node.get_meta("arm_down", ARM_DOWN)
		var s: float = (sin(phase) if moving else 0.0)
		_pose_walk(sk, s * leg_amp, s * arm_amp, bonemap, arm_down)
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
	var bm: Dictionary = node.get_meta("bonemap", {})
	var arm_down: float = node.get_meta("arm_down", ARM_DOWN)
	_pose(sk, bm.get("thigh_r", "thigh_r"), Quaternion(_X, 0.95))
	_pose(sk, bm.get("thigh_l", "thigh_l"), Quaternion(_X, 0.95))
	_pose(sk, bm.get("upperarm_r", "upperarm_r"), Quaternion(_X, -1.05) * Quaternion(_Z, arm_down))
	_pose(sk, bm.get("upperarm_l", "upperarm_l"), Quaternion(_X, -1.05) * Quaternion(_Z, -arm_down))


## Pose the four swing bones: legs swing fore/aft about X; arms hang down (about
## Z) and swing opposite the legs about X. `bonemap` resolves the logical
## thigh_l/thigh_r/upperarm_l/upperarm_r names to this rig's real bone names
## (see build_model) — an empty string is a bone that didn't resolve, and
## _pose() below no-ops on it, so that joint just holds its rest pose instead
## of erroring (a per-joint idle fallback for a partially-mappable rig).
static func _pose_walk(sk: Skeleton3D, leg: float, arm: float, bonemap: Dictionary, arm_down := ARM_DOWN) -> void:
	_pose(sk, bonemap.get("thigh_r", "thigh_r"), Quaternion(_X, -leg))
	_pose(sk, bonemap.get("thigh_l", "thigh_l"), Quaternion(_X, leg))
	_pose(sk, bonemap.get("upperarm_r", "upperarm_r"), Quaternion(_X, arm) * Quaternion(_Z, arm_down))
	_pose(sk, bonemap.get("upperarm_l", "upperarm_l"), Quaternion(_X, -arm) * Quaternion(_Z, -arm_down))


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
		var idx := (sk.find_bone(bone) if bone != "" else -1)
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


## One measured arm-down angle (radians) per MODELS kind — see
## _measure_arm_down. Keyed by kind string rather than by Skeleton3D instance
## since every spawn of the same kind shares the same imported rest pose.
static var _ARM_DOWN_CACHE: Dictionary = {}


## Measure how far this rig's right upper-arm must rotate about the skeleton-
## space _Z axis to bring its REST-pose hand from wherever the bind pose left
## it (fully horizontal T-pose, partially-down A-pose, or "nathan"'s
## already-mostly-down baked-clip rest) to hanging straight down.
##
## Works in rest-pose WORLD space rather than any bone's local axes: the
## vector from the upperarm bone to the hand bone (both read via
## get_bone_global_rest, i.e. before any pose is applied) lives in the
## skeleton's own space no matter how each importer (Quaternius / Mixamo /
## Blender-Rigify / Renderpeople) authored that bone's local orientation. The
## hand rides passively on the end of the (as-yet unrotated) forearm/hand
## chain, so rotating that vector's X/Y (skeleton left-right vs up-down)
## component onto straight down — leaving Z (forward/back lean) alone — is
## exactly the correction _pose_walk needs to apply to the upperarm bone
## itself. _pose() already applies qc through the parent's basis, so this
## angle is correct for _pose_walk / sit() regardless of the bone's own local
## axis quirks.
##
## Falls back to the ubc-tuned ARM_DOWN constant if this rig doesn't resolve
## a hand_r/upperarm_r pair to measure (or they land on the same point).
static func _measure_arm_down(sk: Skeleton3D, bonemap: Dictionary) -> float:
	var ua_name: String = bonemap.get("upperarm_r", "")
	var hand_name: String = bonemap.get("hand_r", "")
	var ua_idx := (sk.find_bone(ua_name) if ua_name != "" else -1)
	var hand_idx := (sk.find_bone(hand_name) if hand_name != "" else -1)
	if ua_idx < 0 or hand_idx < 0:
		return ARM_DOWN
	var v: Vector3 = sk.get_bone_global_rest(hand_idx).origin - sk.get_bone_global_rest(ua_idx).origin
	if Vector2(v.x, v.y).length() < 0.001:
		return ARM_DOWN
	var current_angle := atan2(v.y, v.x)
	return wrapf(-PI * 0.5 - current_angle, -PI, PI)


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


## Find a bone by a case-insensitive substring match against its name — the
## needed workaround since Mixamo / Blender / RPM importers each name bones
## differently, and Godot's glTF importer appends de-dupe suffixes on top
## (e.g. "RightArm_039"). Scans in bone-index order, so a base bone (added
## before its finger/toe children in the source rig) wins over any accidental
## substring hit in a longer descendant name.
static func _find_bone_like(sk: Skeleton3D, needle: String) -> int:
	var n := needle.to_lower()
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).to_lower().contains(n):
			return i
	return -1
