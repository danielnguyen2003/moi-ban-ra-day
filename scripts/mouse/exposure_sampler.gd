class_name ExposureSampler
extends RefCounted
## Estimates how lit the rat is (0..1) from all lights in group "game_lights".

## Contribution of one point light: smooth falloff inside its range.
static func light_contribution(dist: float, light_range: float, energy: float) -> float:
	if dist >= light_range or light_range <= 0.0:
		return 0.0
	var f := 1.0 - dist / light_range
	return energy * f * f

static func sample(world: World3D, pos: Vector3, tree: SceneTree, exclude: Array[RID] = []) -> float:
	var total := 0.0
	var space := world.direct_space_state
	for l in tree.get_nodes_in_group("game_lights"):
		var light := l as Light3D
		if light == null or not light.visible or light.light_energy <= 0.01:
			continue
		var lp := light.global_position
		var rng := 0.0
		if light is OmniLight3D:
			rng = (light as OmniLight3D).omni_range
		elif light is SpotLight3D:
			rng = (light as SpotLight3D).spot_range
			var dir := -light.global_transform.basis.z
			var ang := rad_to_deg(dir.angle_to((pos - lp).normalized()))
			if ang > (light as SpotLight3D).spot_angle:
				continue
		else:
			continue
		var c := light_contribution(lp.distance_to(pos), rng, light.light_energy)
		if c <= 0.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(lp, pos + Vector3.UP * 0.2, GameState.L_WORLD)
		q.exclude = exclude
		if not space.intersect_ray(q).is_empty():
			continue  # occluded
		total += c
	# Moonlight shafts: Area3D volumes in group "moonlight".
	for a in tree.get_nodes_in_group("moonlight"):
		var area := a as Area3D
		if area and area.has_meta("strength") and _inside(area, pos):
			total += float(area.get_meta("strength"))
	return clampf(total / 1.5, 0.0, 1.0)

static func _inside(area: Area3D, pos: Vector3) -> bool:
	for c in area.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D:
			var local: Vector3 = c.global_transform.affine_inverse() * pos
			var h: Vector3 = (c.shape as BoxShape3D).size * 0.5
			if absf(local.x) <= h.x and absf(local.y) <= h.y and absf(local.z) <= h.z:
				return true
	return false
