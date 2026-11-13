extends Node
## Renders still frames of the level from preset cameras for visual review.
## usage: xvfb-run -a godot --path . --audio-driver Dummy -- --capture <out_dir> [shot_name]
## (GameState attaches this node when it sees --capture.)

const SHOTS := {
	"yard_door": [Vector3(4, 2.0, 38), Vector3(4, 4, 20)],
	"altar_wide": [Vector3(0, 9, 14), Vector3(0, 9, -24)],
	"altar_ratview": [Vector3(3, 0.8, -12), Vector3(0, 11, -22)],
	"sap_under": [Vector3(-2, 0.6, 14), Vector3(-8, 0.5, 2)],
	"cat_close": [Vector3(6, 1.2, 4), Vector3(1, 2.2, -8)],
	"beam_top": [Vector3(7.5, 33.5, 5), Vector3(0, 10, -20)],
}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i0 := args.find("--capture")
	var out: String = args[i0 + 1] if args.size() > i0 + 1 else "user://shots"
	var only: String = args[i0 + 2] if args.size() > i0 + 2 else ""
	DirAccess.make_dir_recursive_absolute(out)
	var tree := get_tree()
	Director.enabled = false
	for i in 20:
		await tree.process_frame
	var level := tree.current_scene as Node3D
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
			await tree.process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out, name])
		print("SHOT ", name)
	tree.quit()
