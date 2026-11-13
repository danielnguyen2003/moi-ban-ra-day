extends Node3D
## M1 graybox: gian thờ (middle bay) of a three-bay northern Vietnamese house + the yard in front.
## Units: 1 unit = 10 cm (WORLD_SCALE 10). Floor at y = 0; room interior x[-18,18], z[-26,26], walls 42 tall.

var b: LevelBuilder
var nav: NavigationRegion3D
var rat: Rat
var cat: CatController
var incense: IncenseZone
var ember: OmniLight3D
var hud: Hud

const RAT_START := Vector3(4.0, 0.6, 33.0)
const CAT_START := Vector3(-4.0, 0.2, 2.0)

func _ready() -> void:
	nav = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.agent_radius = 1.25
	nm.agent_height = 2.75
	nm.agent_max_climb = 0.5
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = GameState.L_WORLD | GameState.L_CAT_BLOCKER
	nav.navigation_mesh = nm
	add_child(nav)
	b = LevelBuilder.new(nav)
	_environment()
	_architecture()
	_altar()
	_furniture()
	_yard()
	_lights()
	_gameplay()
	nav.bake_navigation_mesh(false)
	_spawn()
	hud = Hud.new()
	add_child(hud)
	GameState.player_caught.connect(_on_caught)
	GameState.objective_changed.emit("Tìm hộp diêm.")

# ---------------------------------------------------------------- environment
func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.005, 0.009)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_energy = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.5
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.85, 0.82, 0.78)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 120.0
	we.environment = env
	add_child(we)

# ---------------------------------------------------------------- house shell
func _architecture() -> void:
	var brick := b.pbr("brick_floor", 1.5, Color(0.8, 0.7, 0.65))
	var laterite := b.pbr("red_laterite_soil_stones", 1.2, Color(0.75, 0.6, 0.5))
	var earth_wall := b.pbr("patterned_clay_wall", 1.6, Color(0.8, 0.72, 0.6))
	var wood := b.pbr("dark_wood", 1.0, Color(0.7, 0.6, 0.55))
	var dark := b.pbr("bamboo_wall_02", 1.0, Color(0.25, 0.2, 0.17))
	b.box("Floor", Vector3(40, 1, 56), Vector3(0, -0.5, 0), brick, GameState.L_WORLD, "brick")
	b.box("Ceiling", Vector3(40, 1, 56), Vector3(0, 42.5, 0), dark)
	b.box("BackWall", Vector3(40, 42, 1), Vector3(0, 21, -26.5), laterite)
	b.box("RightWall", Vector3(1, 42, 56), Vector3(18.5, 21, 0), earth_wall)
	# Left: double wall (vách đất) with a rat corridor between, entered by two rat holes.
	b.box("LeftOuter", Vector3(1, 42, 56), Vector3(-18.5, 21, 0), laterite)
	b.box("CorridorFloor", Vector3(2.4, 0.2, 52), Vector3(-16.8, 0.1, 0), brick, GameState.L_WORLD, "earth")
	b.box("CorridorRoof", Vector3(2.4, 0.3, 52), Vector3(-16.8, 2.6, 0), dark)
	_wall_with_holes("LeftInner", -15.3, [-15.0, 12.0], earth_wall)
	# Front: cửa bức bàn — six panels, one left ajar so moonlight slips in.
	for i in 6:
		var x := -9.0 + 1.5 + i * 3.0
		if i == 4:
			b.box("DoorPanelAjar", Vector3(3, 30, 0.6), Vector3(x + 1.8, 15, 25.0), wood, GameState.L_WORLD, "", deg_to_rad(-35))
		else:
			b.box("DoorPanel%d" % i, Vector3(3, 30, 0.6), Vector3(x, 15, 26.0), wood)
	b.box("DoorLintel", Vector3(18, 12, 1), Vector3(0, 36, 26.5), wood)
	b.box("FrontWallL", Vector3(9, 42, 1), Vector3(-13.5, 21, 26.5), laterite)
	b.box("FrontWallR", Vector3(9, 42, 1), Vector3(13.5, 21, 26.5), laterite)
	b.box("Threshold", Vector3(18, 1.2, 1.2), Vector3(0, 0.6, 26.4), wood, GameState.L_WORLD, "wood")
	# Frame: four main columns (cột cái, climbable) and two longitudinal beams (xà) at 3 m.
	for x in [-9.0, 9.0]:
		for z in [-14.0, 10.0]:
			b.cylinder("Column_%d_%d" % [x, z], 1.1, 42, Vector3(x, 0, z), wood, GameState.L_WORLD | GameState.L_CLIMB, "wood", 1.0)
		b.box("Beam_%d" % x, Vector3(1.6, 1.8, 26), Vector3(x, 30.9, -2), wood, GameState.L_WORLD, "wood")
	b.box("CrossBeamBack", Vector3(19.6, 1.8, 1.6), Vector3(0, 30.9, -14), wood, GameState.L_WORLD, "wood")
	b.box("CrossBeamFront", Vector3(19.6, 1.8, 1.6), Vector3(0, 30.9, 10), wood, GameState.L_WORLD, "wood")

func _wall_with_holes(name: String, x: float, hole_z: Array, m: Material) -> void:
	# A wall along Z from -26 to 26 with 1.4-wide, 1.1-tall rat holes at floor level.
	var zs: Array = [-26.0]
	for z in hole_z:
		zs.append(z - 0.7); zs.append(z + 0.7)
	zs.append(26.0)
	for i in range(0, zs.size(), 2):
		var z0: float = zs[i]; var z1: float = zs[i + 1]
		b.box("%s_seg%d" % [name, i], Vector3(0.8, 42, z1 - z0), Vector3(x, 21, (z0 + z1) / 2), m)
	for z in hole_z:
		b.box("%s_above_%d" % [name, z], Vector3(0.8, 40.9, 1.4), Vector3(x, 1.1 + 20.45, z), m)
		# Cat can never squeeze through: invisible cat-only plug.
		b.invisible_wall("%s_catplug_%d" % [name, z], Vector3(0.8, 1.1, 1.4), Vector3(x, 0.55, z), GameState.L_CAT_BLOCKER)

# ---------------------------------------------------------------- altar
func _altar() -> void:
	var lacquer := b.pbr("lacquered_cherry_wood", 0.8, Color(0.6, 0.25, 0.2))
	var gilt := b.mat("gilt_dull", Color(0.45, 0.33, 0.12), 0.5, 0.7)
	var ceramic := b.mat("ceramic_glaze", Color(0.55, 0.52, 0.45), 0.3)
	var brass := b.mat("brass_tarnish", Color(0.38, 0.28, 0.12), 0.45, 0.85)
	var photo := b.mat("photo_bw", Color(0.3, 0.3, 0.3), 0.6)
	var wood := b.pbr("dark_wood", 1.0, Color(0.7, 0.6, 0.55))
	# Án thờ: top slab on four legs; legs are climbable.
	b.box("AltarTop", Vector3(20, 1, 7), Vector3(0, 10.5, -22.5), lacquer, GameState.L_WORLD, "wood")
	for x in [-9.4, 9.4]:
		for z in [-25.4, -19.6]:
			b.box("AltarLeg", Vector3(0.9, 10, 0.9), Vector3(x, 5, z), lacquer, GameState.L_WORLD | GameState.L_CLIMB, "wood")
	b.box("AltarApron", Vector3(20, 2.2, 0.4), Vector3(0, 8.9, -19.1), gilt)
	# On the altar (from back to front): photo, incense bowl, lamp + vases, offering dish, water cups.
	b.box("AncestorPhoto", Vector3(3.2, 4.2, 0.3), Vector3(0, 13.1, -25.2), photo)
	b.cylinder("IncenseBowl", 1.1, 1.6, Vector3(0, 11.0, -22.5), ceramic, GameState.L_WORLD, "", 1.4)
	b.cylinder("VaseL", 0.8, 4.0, Vector3(-6.5, 11.0, -23.5), ceramic, GameState.L_WORLD, "", 0.5)
	b.cylinder("LampBase", 0.9, 1.4, Vector3(6.5, 11.0, -22.5), brass, GameState.L_WORLD, "", 0.5)
	b.cylinder("LampChimney", 0.45, 2.2, Vector3(6.5, 12.4, -22.5), b.mat("glass_soot", Color(0.25, 0.22, 0.2), 0.1), GameState.L_WORLD, "", 0.35)
	b.cylinder("OfferingDish", 1.2, 1.1, Vector3(-3.0, 11.0, -21.0), brass, GameState.L_WORLD, "", 1.4)
	for i in 3:
		b.cylinder("WaterCup%d" % i, 0.3, 0.4, Vector3(-1.0 + i * 1.0, 11.0, -20.4), ceramic)
	# Hoành phi + câu đối (text to be verified — see docs/CULTURE_NOTES.md).
	b.box("HoanhPhi", Vector3(14, 3.6, 0.5), Vector3(0, 27, -25.7), lacquer)
	for x in [-9.0, 9.0]:
		b.box("CauDoi", Vector3(1.6, 16, 0.3), Vector3(x, 22, -12.75), lacquer)
	b.box("Shelf", Vector3(20, 0.5, 3), Vector3(0, 19.0, -24.5), wood)

# ---------------------------------------------------------------- furniture
func _furniture() -> void:
	var gu := b.pbr("rosewood_veneer1", 0.8, Color(0.55, 0.42, 0.38))
	var jar := b.mat("sanh_jar", Color(0.24, 0.17, 0.12), 0.6)
	var straw := b.mat("straw", Color(0.55, 0.45, 0.25), 1.0)
	var shard := b.mat("shards", Color(0.3, 0.22, 0.17), 0.5)
	var rope := b.mat("rope", Color(0.4, 0.33, 0.22), 1.0)
	# Sập gụ (left): low platform with carved skirt; 1.1-unit gap underneath only the rat fits through.
	b.box("SapTop", Vector3(11, 1.0, 18), Vector3(-8.5, 4.3, 2), gu, GameState.L_WORLD, "wood")
	b.box("SapSkirtFront", Vector3(11, 2.4, 0.4), Vector3(-8.5, 2.6, 11.0), gu)
	b.box("SapSkirtBack", Vector3(11, 2.4, 0.4), Vector3(-8.5, 2.6, -7.0), gu)
	b.box("SapSkirtR", Vector3(0.4, 2.4, 18), Vector3(-3.0, 2.6, 2), gu)
	b.box("SapSkirtL", Vector3(0.4, 2.4, 18), Vector3(-14.0, 2.6, 2), gu)
	for x in [-13.6, -3.4]:
		for z in [-6.6, 10.6]:
			b.box("SapLeg", Vector3(0.8, 3.8, 0.8), Vector3(x, 1.9, z), gu, GameState.L_WORLD | GameState.L_CLIMB, "wood")
	var under := b.area("HideUnderSap", Vector3(10, 1.4, 17), Vector3(-8.5, 0.7, 2), "hide_spot")
	under.set_meta("shallow", false)
	# Tủ chè (right wall), its carved front is rough enough to climb.
	b.box("TuChe", Vector3(5, 10, 16), Vector3(15.5, 5, -6), gu, GameState.L_WORLD | GameState.L_CLIMB, "wood")
	# Rope hanging from the beam (climbable) — a second route up.
	b.cylinder("Rope", 0.15, 28.5, Vector3(9.0, 1.5, 4.0), rope, GameState.L_WORLD | GameState.L_CLIMB)
	# Chum vại (front right) and the gap behind them.
	for p in [Vector3(14.0, 0, 13.0), Vector3(14.2, 0, 19.0), Vector3(8.6, 0, 20.5)]:
		b.cylinder("Chum", 2.7, 6.6, p, jar, GameState.L_WORLD, "", 1.9)
	var behind := b.area("HideBehindChum", Vector3(2.2, 2.0, 10), Vector3(17.2, 1.0, 16), "hide_spot")
	behind.set_meta("shallow", false)
	# Ổ rơm (front left): noisy, shallow hide.
	b.box("StrawPile", Vector3(7, 1.6, 6), Vector3(-12.5, 0.8, 20), straw, GameState.L_WORLD, "straw")
	var straw_hide := b.area("HideInStraw", Vector3(6, 2.4, 5), Vector3(-12.5, 1.6, 20), "hide_spot")
	straw_hide.set_meta("shallow", true)
	# Broken pottery near the door: loud floor.
	b.box("Shards", Vector3(6, 0.15, 4), Vector3(-2.0, 0.08, 21.0), shard, GameState.L_WORLD, "shard")

# ---------------------------------------------------------------- yard
func _yard() -> void:
	var earth := b.pbr("dirt_floor", 2.0, Color(0.7, 0.68, 0.65))
	var brick := b.pbr("brick_floor", 1.5, Color(0.8, 0.7, 0.65))
	var table := b.pbr("dark_wood", 1.0, Color(0.7, 0.6, 0.55))
	b.box("YardFloor", Vector3(60, 1, 30), Vector3(0, -0.5, 42), earth, GameState.L_WORLD, "earth")
	b.box("Porch", Vector3(40, 0.6, 4), Vector3(0, 0.3, 29), brick, GameState.L_WORLD, "brick")
	b.box("YardWallL", Vector3(1, 12, 30), Vector3(-30, 6, 42), b.pbr("red_laterite_soil_stones", 1.2, Color(0.75, 0.6, 0.5)))
	b.box("YardWallR", Vector3(1, 12, 30), Vector3(30, 6, 42), b.pbr("red_laterite_soil_stones", 1.2, Color(0.75, 0.6, 0.5)))
	b.box("YardWallF", Vector3(60, 12, 1), Vector3(0, 6, 57), b.pbr("red_laterite_soil_stones", 1.2, Color(0.75, 0.6, 0.5)))
	# Mâm cúng cô hồn: a low tray table outside with bowls of rice porridge, salt and rice.
	b.box("OfferingTable", Vector3(8, 4, 5), Vector3(-6, 2, 36), table, GameState.L_WORLD, "wood")
	var bowl := b.mat("ceramic_glaze", Color())
	for i in 4:
		b.cylinder("OfferingBowl%d" % i, 0.8, 0.6, Vector3(-8.5 + i * 1.7, 4.0, 36), bowl, GameState.L_WORLD, "", 1.0)

# ---------------------------------------------------------------- lights
func _lights() -> void:
	# Oil lamp on the altar (~1800 K).
	b.omni("OilLamp", Vector3(6.5, 13.6, -22.5), Color(1.0, 0.55, 0.22), 2.4, 30.0, true, "oil")
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new(); fm.radius = 0.18; fm.height = 0.6
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.7, 0.3); fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.6, 0.25); fmat.emission_energy_multiplier = 6.0
	flame.mesh = fm; flame.material_override = fmat; flame.position = Vector3(6.5, 13.0, -22.5)
	add_child(flame)
	# Failing fluorescent tube on the right wall (pale green).
	var tube := SpotLight3D.new()
	tube.name = "TubeLight"
	tube.position = Vector3(17.6, 28, 4)
	tube.rotation_degrees = Vector3(-50, 90, 0)
	tube.light_color = Color(0.82, 1.0, 0.86)
	tube.light_energy = 3.0
	tube.spot_range = 50.0
	tube.spot_angle = 62.0
	tube.shadow_enabled = true
	tube.light_volumetric_fog_energy = 0.8
	add_child(tube)
	var tf := LightFlicker.new(); tf.mode = "tube"; tube.add_child(tf)
	var tube_mesh := MeshInstance3D.new()
	var tb := BoxMesh.new(); tb.size = Vector3(0.4, 0.4, 12)
	var tmat := StandardMaterial3D.new(); tmat.emission_enabled = true
	tmat.emission = Color(0.8, 1.0, 0.85); tmat.emission_energy_multiplier = 3.0
	tube_mesh.mesh = tb; tube_mesh.material_override = tmat; tube_mesh.position = Vector3(17.7, 28, 4)
	add_child(tube_mesh)
	# Full moon over the yard; only reaches inside through the ajar door.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.66, 1.0)
	moon.light_energy = 0.55
	moon.rotation_degrees = Vector3(-32, 200, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 140.0
	moon.light_volumetric_fog_energy = 2.0
	add_child(moon)
	var moon_patch := b.area("MoonPatch", Vector3(5, 4, 14), Vector3(4.5, 2, 18), "moonlight", 0)
	moon_patch.set_meta("strength", 0.45)
	var yard_moon := b.area("MoonYard", Vector3(60, 8, 26), Vector3(0, 4, 43), "moonlight", 0)
	yard_moon.set_meta("strength", 0.8)
	# Incense ember (lights when the player finishes).
	ember = b.omni("IncenseEmber", Vector3(0, 13.3, -22.5), Color(1.0, 0.25, 0.08), 0.6, 5.0, false, "incense")
	ember.visible = false
	# Outside the gate: a single incense stick on the offering tray (they still burn for the wandering souls).
	b.omni("YardIncense", Vector3(-6, 5.2, 37.5), Color(1.0, 0.3, 0.1), 0.35, 4.0, false, "incense")

# ---------------------------------------------------------------- gameplay
func _gameplay() -> void:
	incense = IncenseZone.new()
	incense.position = Vector3(0, 0, -20)
	add_child(incense)
	# Matchbox on top of the tủ chè.
	var mb := Pickup.new()
	mb.setup("matchbox", Vector3(0.55, 0.18, 0.38), Color(0.55, 0.18, 0.12))
	mb.position = Vector3(15.0, 10.1, -8.0)
	add_child(mb)
	# Drop zone: the incense bowl.
	var dz := DropZone.new()
	dz.position = Vector3(0, 11.0, -22.0)
	dz.incense = incense
	dz.ember = ember
	add_child(dz)

func _spawn() -> void:
	rat = Rat.new()
	add_child(rat)
	rat.global_position = RAT_START
	rat.rotation.y = 0.0
	GameState.checkpoint = rat.global_transform
	cat = CatController.new()
	add_child(cat)
	cat.global_position = CAT_START
	cat.rat = rat
	cat.vigil_point = Vector3(0, 0.2, -8.0)
	cat.vigil_look = Vector3(0, 0, -22.0)
	var pts: Array[Vector3] = [Vector3(-6, 0, -8), Vector3(5, 0, -10), Vector3(10, 0, 4), Vector3(4, 0, 17), Vector3(-6, 0, 15), Vector3(-1, 0, 2)]
	cat.set_patrol(pts)
	cat.state_changed.connect(func(s): if s == CatBrain.State.CHASE and rat.camera_rig: rat.camera_rig.shake = 1.5)

func _on_caught() -> void:
	if hud.fading:
		return
	await hud.fade_out("Trốn đâu cho thoát…")
	rat.respawn(GameState.checkpoint)
	rat.carrying = null
	GameState.reset_run()
	get_tree().call_group("pickup_reset", "reset")
	cat.teleport(Transform3D(Basis(), CAT_START))
	Director.restart()
	await hud.fade_in()
