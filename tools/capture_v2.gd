extends Node
## Screenshot rig for visual review: xvfb-run -a godot --path . -- --no-save --capture <dir>
## (Progress attaches this node when it sees --capture.)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[args.find("--capture") + 1]
	DirAccess.make_dir_recursive_absolute(out)
	var tree := get_tree()
	for i in 20: await tree.process_frame
	var g = tree.current_scene
	# early hunt
	g.start_night()
	for i in 60: await tree.process_frame
	await _shot(out, "02_hunt_start")
	Progress.fish = 5000; Progress.areas = 3; g._show_shop()
	for i in 20: await tree.process_frame
	await _shot(out, "05_shop")
	# late game: many regions, kittens, swarm
	Progress.areas = 6; Progress.levels = {"kitten": 3, "spawn": 12, "luck": 4, "claw": 6, "trap": 3, "owl": 2, "wave": 3}
	Progress.skins_owned.append("nonla"); Progress.skin = "nonla"; g.player.apply_skin("nonla")
	g._apply_stats(); g.start_night()
	for i in 160: g.swarm.spawn_at_random_hole(g._roll_kind())
	for i in 40: await tree.process_frame
	await _shot(out, "06_late_game")
	g.cam.global_position = g.player.global_position + Vector3(0, 3.2, 4.5); g.phase = g.Phase.SHOP
	g.cam.look_at(g.player.global_position + Vector3(0, 0.8, 0))
	for i in 3: await tree.process_frame
	await _shot(out, "07_closeup")
	tree.quit()

func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)
