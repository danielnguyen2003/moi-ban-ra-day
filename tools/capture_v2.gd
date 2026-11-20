extends Node
## Screenshot rig for visual review: xvfb-run -a godot --path . -- --no-save --capture <dir>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[args.find("--capture") + 1]
	DirAccess.make_dir_recursive_absolute(out)
	var tree := get_tree()
	for i in 15: await tree.process_frame
	var g = tree.current_scene
	g.pause_on_levelup = false
	Progress.fish = 2500.0
	g.show_select()
	for i in 10: await tree.process_frame
	await _shot(out, "01_select")
	g.start_run()
	g.weapons.levels = {"claw": 4, "lantern": 5, "cracker": 3, "yarn": 3}
	g.passives = {"might": 2, "speed": 1}
	g._apply_stats()
	g.t = 95.0
	g.won = true            # suppress level-up overlays for the action shots
	for i in 70: g._spawn_one()
	for i in 90: await tree.process_frame
	await _shot(out, "02_hunt_weapons")
	g.won = false
	g._open_levelup()
	for i in 10: await tree.process_frame
	await _shot(out, "03_levelup")
	g.pick_card(0)
	g.won = true; g.pending_levels = 0
	g.t = RunDefs.WEDDING_AT
	for i in 70: await tree.process_frame
	await _shot(out, "04_wedding")
	if is_instance_valid(g.wedding): g.wedding.queue_free()
	g.t = RunDefs.NIGHT_SECONDS
	for i in 80: await tree.process_frame
	await _shot(out, "05_boss")
	tree.quit()

func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)
