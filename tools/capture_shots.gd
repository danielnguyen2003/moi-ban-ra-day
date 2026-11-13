extends SceneTree
## Renders still frames of the level from preset cameras for visual review.
## usage: xvfb-run -a godot --path . -s tools/capture_shots.gd -- <out_dir> [shot_name]

const SHOTS := {
	"yard_door": [Vector3(4, 2.0, 38), Vector3(4, 4, 20)],
	"altar_wide": [Vector3(0, 9, 14), Vector3(0, 9, -24)],
	"altar_ratview": [Vector3(3, 1.2, -6), Vector3(0, 9, -22)],
	"sap_under": [Vector3(-2, 0.6, 14), Vector3(-8, 0.5, 2)],
	"cat_close": [Vector3(-1, 1.8, 9), Vector3(-4, 1.5, 2)],
	"beam_top": [Vector3(9, 33, 8), Vector3(0, 12, -20)],
}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shots"
	var only: String = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var level: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(level)
	root.get_node("Director").set("enabled", false)
	for i in 30:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cam := Camera3D.new()
	cam.fov = 70
	cam.near = 0.03
	level.add_child(cam)
	for name in SHOTS:
		if only != "" and name != only:
			continue
		var s: Array = SHOTS[name]
		cam.global_position = s[0]
		cam.look_at(s[1])
		cam.current = true
		for i in 12:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/%s.png" % [out, name])
		print("SHOT ", name)
	quit()
