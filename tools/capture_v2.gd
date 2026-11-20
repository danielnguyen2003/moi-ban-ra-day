extends Node
## Screenshot rig: xvfb-run -a godot --path . -- --no-save --capture <dir>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[args.find("--capture") + 1]
	DirAccess.make_dir_recursive_absolute(out)
	var tree := get_tree()
	for i in 15: await tree.process_frame
	var g = tree.current_scene
	g.pause_on_levelup = false
	g.start_run()
	# 1) mouse line-up: every kind, frozen, close camera
	g.ui.visible = false
	g.swarm.clear()
	var base: Vector3 = g.player.global_position + Vector3(0, 0, -6)
	var kinds := MiceSwarm.KINDS.keys()
	for i in kinds.size():
		g.swarm.spawn(kinds[i], base + Vector3((i - kinds.size() / 2.0) * 1.9, 0, 0))
	for i in g.swarm.count(): g.swarm.spawn_in[i] = 0.0; g.swarm.vel[i] = Vector3(0, 0, 0.3)
	g.swarm.frozen = true
	g.cam_hold = true
	g.cam.global_position = base + Vector3(0, 3.2, 7.5)
	g.cam.look_at(base + Vector3(0, 0.5, 0))
	for i in 20: await tree.process_frame
	await _shot(out, "01_mice_lineup")
	# 2) the cat close-up
	g.cam.global_position = g.player.global_position + Vector3(2.0, 2.2, 4.0)
	g.cam.look_at(g.player.global_position + Vector3(0, 0.8, 0))
	for i in 10: await tree.process_frame
	await _shot(out, "02_cat_closeup")
	# 3) mid-night action with a full build
	g.swarm.frozen = false; g.swarm.clear(); g.cam_hold = false; g.ui.visible = true
	g.won = true
	g.weapons.levels = {"claw": 6, "lantern": 6, "cracker": 6, "wisp": 5}
	g.weapons.evolved = {"cracker": true}
	g.passives = {"might": 3, "bowl": 2}
	g._apply_stats()
	g.t = 170.0
	for i in 90: g._spawn_one()
	for i in 100: await tree.process_frame
	await _shot(out, "03_action")
	for i in 25: await tree.process_frame
	await _shot(out, "04_action_b")
	tree.quit()

func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)
