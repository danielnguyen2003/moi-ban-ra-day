extends Node
## Aerial tour of the village for visual review: godot --path . -- --no-save --capture-map <dir>

const SHOTS := [
	["m1_overview", Vector3(0, 150, 150), Vector3(0, 0, 0)],
	["m2_home", Vector3(0, 22, 30), Vector3(0, 0, -4)],
	["m3_fields", Vector3(60, 24, 20), Vector3(75, 0, -15)],
	["m4_pond", Vector3(-55, 22, 35), Vector3(-78, 0, 5)],
	["m5_dinh", Vector3(10, 22, 52), Vector3(0, 2, 84)],
	["m6_graves", Vector3(0, 20, -60), Vector3(0, 0, -95)],
	["m7_banana_bamboo", Vector3(98, 5, 2), Vector3(114, 2.5, -16)],
	["m8_home_close", Vector3(8, 7, 10), Vector3(0, 2.5, -14)],
]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[args.find("--capture-map") + 1]
	DirAccess.make_dir_recursive_absolute(out)
	var tree := get_tree()
	for i in 15: await tree.process_frame
	var g = tree.current_scene
	g.ui.visible = false
	g.cam_hold = true
	for s in SHOTS:
		g.cam.global_position = s[1]
		g.cam.look_at(s[2], Vector3.UP)
		for i in 8: await tree.process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, s[0]])
		print("SHOT ", s[0])
	tree.quit()
