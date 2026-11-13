extends GutTest
## Integration: build the altar room and check the cat's navmesh respects rat-only spaces.

var level: Node3D

func before_all() -> void:
	level = load("res://scenes/main.tscn").instantiate()
	add_child(level)
	await wait_physics_frames(5)

func after_all() -> void:
	level.free()

func _closest(p: Vector3) -> Vector3:
	var map := level.get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, p)

func test_navmesh_exists_on_room_floor() -> void:
	var c := _closest(Vector3(0, 0, 0))
	assert_lt(c.distance_to(Vector3(0, 0, 0)), 1.0, "open floor is walkable for the cat")

func test_cat_cannot_path_into_rat_corridor() -> void:
	var inside := Vector3(-16.8, 0.3, 0.0)
	var c := _closest(inside)
	assert_gt(Vector2(c.x, c.z).distance_to(Vector2(inside.x, inside.z)), 1.0, "corridor between walls is not on the cat navmesh")

func _path_end(from: Vector3, to: Vector3) -> Vector3:
	var map := level.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	return path[path.size() - 1] if path.size() > 0 else from

func test_cat_cannot_path_under_sap() -> void:
	var under := Vector3(-8.5, 0.3, 2.0)
	var end := _path_end(Vector3(0, 0, 0), under)
	assert_gt(Vector2(end.x, end.z).distance_to(Vector2(under.x, under.z)), 3.0, "space under the sập is rat-only")

func test_cat_cannot_path_into_corridor_from_room() -> void:
	var inside := Vector3(-16.8, 0.3, 0.0)
	var end := _path_end(Vector3(0, 0, 0), inside)
	assert_gt(Vector2(end.x, end.z).distance_to(Vector2(inside.x, inside.z)), 1.5)

func test_cat_never_crosses_threshold_to_yard() -> void:
	# Design rule (GDD): the thing in the cat never steps over the door sill; the yard is the tutorial safe zone.
	var yard := Vector3(10, 0, 40)
	var end := _path_end(Vector3(0, 0, 0), yard)
	assert_lt(end.z, 26.0, "cat path stops inside the house")

func test_incense_zone_blocks_only_when_lit() -> void:
	var z: IncenseZone = level.incense
	assert_false(z.contains(Vector3(0, 0, -18)))
	z.light_up()
	assert_true(z.contains(Vector3(0, 0, -18)))
	assert_false(z.contains(Vector3(0, 0, 5)))

func test_rat_and_cat_spawned() -> void:
	assert_not_null(level.rat)
	assert_not_null(level.cat)
	assert_eq(level.cat.rat, level.rat)
