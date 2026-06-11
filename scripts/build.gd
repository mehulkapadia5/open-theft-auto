class_name Build
## Static helpers for procedural mesh construction.

static func hex(h: int) -> Color:
	return Color(((h >> 16) & 0xFF) / 255.0, ((h >> 8) & 0xFF) / 255.0, (h & 0xFF) / 255.0)

static var _mat_cache: Dictionary = {}

static func mat(color: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

## Shared cached material — one instance per unique (color, rough, metal).
## Callers must treat the result as immutable; use mat() for a private copy.
static func cmat(color: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var key := color.to_rgba32() * 1000003 + int(rough * 100.0) * 101 + int(metal * 100.0)
	if not _mat_cache.has(key):
		_mat_cache[key] = mat(color, rough, metal)
	return _mat_cache[key]

static func emissive(color: Color, emit: Color, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = emit
	m.emission_energy_multiplier = energy
	return m

static func box(w: float, h: float, d: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	if material:
		mi.material_override = material
	return mi

static func cyl(top: float, bot: float, h: float, sides: int, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bot
	cm.height = h
	cm.radial_segments = sides
	mi.mesh = cm
	if material:
		mi.material_override = material
	return mi

static func sphere(r: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	if material:
		mi.material_override = material
	return mi

static func plane(w: float, d: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, d)
	mi.mesh = pm
	if material:
		mi.material_override = material
	return mi
