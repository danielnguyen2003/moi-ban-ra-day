class_name MeshKit
extends RefCounted
## Bakes several primitive meshes (each with its own transform and colour) into one vertex-coloured
## ArrayMesh, so foliage and props can be drawn with MultiMesh in a single draw call.

## parts: Array of [Mesh, Transform3D, Color]
static func merge(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var mesh: Mesh = p[0]
		var xf: Transform3D = p[1]
		var col: Color = p[2]
		var arr := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx = arr[Mesh.ARRAY_INDEX]
		var nb := xf.basis.inverse().transposed()
		var order: PackedInt32Array = idx if idx != null and idx.size() > 0 else PackedInt32Array(range(verts.size()))
		for k in order:
			st.set_color(col)
			st.set_normal((nb * norms[k]).normalized())
			st.add_vertex(xf * verts[k])
	return st.commit()

static func xf(pos: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scale), pos)

## A MultiMeshInstance3D scattering `mesh` at the given transforms.
static func scatter(mesh: Mesh, xforms: Array, material: Material, shadows := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
