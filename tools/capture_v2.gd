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
	for i in 6: g.swarm.spawn_at_random_hole(MiceSwarm.Kind.NHAT)
	for i in 50: await tree.process_frame
	await _shot(out, "02_hunt_start")
	g._end_night()
	for i in 20: await tree.process_frame
	await _shot(out, "04_summary")
	Progress.fish = 5000; g._show_shop()
	for i in 20: await tree.process_frame
	await _shot(out, "05_shop")
	# late game: many regions, kittens, swarm
	Progress.areas = 6; Progress.levels = {"kitten": 3, "spawn": 12, "luck": 4, "claw": 6}
	g._apply_stats(); g.start_night()
	for i in 160: g.swarm.spawn_at_random_hole(g._roll_kind())
	for i in 40: await tree.process_frame
	await _shot(out, "06_late_game")
	tree.quit()

func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)
