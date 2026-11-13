class_name Toon
extends RefCounted
## Material factory for the toon look. Cached so identical looks share one material.

const TOON := preload("res://scripts/shaders/toon.gdshader")
const OUTLINE := preload("res://scripts/shaders/outline.gdshader")
static var _cache := {}

static func mat(color: Color, outline := true, extra := {}) -> ShaderMaterial:
	var key := "%s|%s|%s" % [color.to_html(), outline, str(extra)]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	if outline:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("width", extra.get("outline_width", 0.035))
		m.next_pass = o
	_cache[key] = m
	return m

static func glow(color: Color, energy := 3.0) -> StandardMaterial3D:
	var key := "glow|%s|%s" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m

## Convenience: a MeshInstance3D with a primitive mesh and toon material.
static func part(mesh: Mesh, color: Color, pos := Vector3.ZERO, scale := Vector3.ONE, outline := true, extra := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, outline, extra)
	mi.position = pos
	mi.scale = scale
	return mi

static func sphere(r := 0.5, rings := 16, segs := 24) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.rings = rings; s.radial_segments = segs
	return s

static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new(); c.radius = r; c.height = h; c.rings = 8; c.radial_segments = 20
	return c

static func cyl(top: float, bottom: float, h: float, segs := 16) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = top; c.bottom_radius = bottom; c.height = h; c.radial_segments = segs
	return c

static func cone(r: float, h: float, segs := 12) -> CylinderMesh:
	return cyl(0.0, r, h, segs)

static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = size
	return b
