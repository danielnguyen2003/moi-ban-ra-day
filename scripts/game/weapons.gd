class_name Weapons
extends Node3D
## Auto-firing weapons owned by the player cat. Each weapon reads its stats from RunDefs and hits
## through game.hit(center, r, dmg, dir, arc) so mice, the boss and the wedding palanquin all take damage.

var game                         ## the Game node (hit(), swarm, player)
var levels := {}                 ## weapon id -> level
var evolved := {}                ## weapon id -> true
var might := 1.0
var cd_mult := 1.0
var _cd := {}
var _lanterns: Array[Node3D] = []
var _lantern_angle := 0.0
var _lantern_tick := 0.0
var _projectiles: Array = []     ## [{node, kind, ...}]

func clear() -> void:
	levels.clear(); evolved.clear(); _cd.clear()
	for l in _lanterns:
		l.queue_free()
	_lanterns.clear()
	for p in _projectiles:
		if is_instance_valid(p.node):
			p.node.queue_free()
	_projectiles.clear()

func stats(id: String) -> Dictionary:
	return RunDefs.weapon_stats(id, levels[id], evolved.get(id, false))

func _physics_process(dt: float) -> void:
	if game == null or game.player == null or get_tree().paused:
		return
	for id in levels:
		_cd[id] = _cd.get(id, 0.0) - dt
		var s := stats(id)
		match id:
			"lantern":
				_update_lanterns(dt, s)
			_:
				if _cd[id] <= 0.0:
					_cd[id] = s.cd * cd_mult
					_fire(id, s)
	_update_projectiles(dt)

# ---------------------------------------------------------------- firing
func _fire(id: String, s: Dictionary) -> void:
	var p: Cat = game.player
	var at := p.global_position
	match id:
		"claw":
			# auto-aim at the nearest mouse (players kite away from the horde), else face forward
			var dir: Vector3 = p._dir
			var n = game.swarm.nearest(at, s.radius + 2.5)
			if n != null and (n - at).length() > 0.1:
				dir = (n - at).normalized(); dir.y = 0
			game.hit(at, s.radius, s.dmg * might, dir, s.arc)
			_slash_fx(at, dir, s.radius, s.arc, evolved.get(id, false))
		"cracker":
			var targets: Array = game.swarm.nearest_n(at, 12.0, s.count)
			if targets.is_empty():
				targets = [at + p._dir * 5.0]
			for t in targets:
				_throw_cracker(at, t, s)
		"yarn":
			for k in s.count:
				var a := randf() * TAU
				_spawn_yarn(at, Vector3(cos(a), 0, sin(a)), s)
		"wisp":
			var targets: Array = game.swarm.nearest_n(at, 14.0, s.count)
			for t in targets:
				_spawn_wisp(at, t, s)
		"nia":
			for k in s.count:
				var dir: Vector3 = p._dir.rotated(Vector3.UP, (k - (s.count - 1) * 0.5) * 0.6)
				_spawn_nia(at, dir, s)

# ---------------------------------------------------------------- claw
func _slash_fx(at: Vector3, dir: Vector3, r: float, arc: float, evo: bool) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new(); t.inner_radius = r * 0.75; t.outer_radius = r; t.rings = 24; t.ring_segments = 4
	mi.mesh = t
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var col := Color(1.0, 0.75, 0.3) if evo else Color(1.0, 1.0, 1.0)
	m.albedo_color = Color(col, 0.75); m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = 2.0
	mi.material_override = m
	game.add_child(mi)
	mi.global_position = at + Vector3(0, 0.5, 0)
	mi.scale = Vector3(1, 0.15, 1)
	# three claw streaks instead of a full ring when it's an arc
	if arc < TAU - 0.01:
		mi.queue_free()
		for k in 3:
			var streak := MeshInstance3D.new()
			var b := BoxMesh.new(); b.size = Vector3(0.08, 0.04, r * 0.9)
			streak.mesh = b; streak.material_override = m
			game.add_child(streak)
			var side: Vector3 = dir.rotated(Vector3.UP, (k - 1) * 0.35)
			streak.global_position = at + side * r * 0.55 + Vector3(0, 0.5, 0)
			streak.look_at(streak.global_position + side, Vector3.UP)
			streak.rotate_object_local(Vector3.UP, 0.5)
			var tw := streak.create_tween().set_parallel(true)
			tw.tween_property(streak, "scale", Vector3(1, 1, 1.4), 0.12)
			tw.tween_property(streak, "transparency", 1.0, 0.18)
			tw.chain().tween_callback(streak.queue_free)
		return
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "rotation:y", TAU, 0.2)
	tw.tween_property(mi, "transparency", 1.0, 0.22)
	tw.chain().tween_callback(mi.queue_free)

# ---------------------------------------------------------------- lantern (orbit)
func _make_star(color: Color) -> Node3D:
	# đèn ông sao: five-pointed star from 5 cones + glowing core and a short bamboo stick
	var n := Node3D.new()
	for k in 5:
		var c := MeshInstance3D.new(); c.mesh = Toon.cone(0.12, 0.36, 4)
		c.material_override = Toon.glow(color, 2.5)
		c.rotation.z = k * TAU / 5.0
		c.position = Vector3(sin(-k * TAU / 5.0), cos(k * TAU / 5.0), 0) * 0.18
		n.add_child(c)
	var core := MeshInstance3D.new(); core.mesh = Toon.sphere(0.13); core.material_override = Toon.glow(Color(1.0, 0.95, 0.6), 3.5)
	n.add_child(core)
	var l := OmniLight3D.new(); l.light_color = color; l.light_energy = 0.8; l.omni_range = 3.0
	n.add_child(l)
	return n

func _update_lanterns(dt: float, s: Dictionary) -> void:
	var want: int = s.count
	while _lanterns.size() < want:
		var n := _make_star(Color(1.0, 0.35, 0.25) if _lanterns.size() % 2 == 0 else Color(1.0, 0.8, 0.25))
		game.add_child(n); _lanterns.append(n)
	while _lanterns.size() > want:
		_lanterns.pop_back().queue_free()
	_lantern_angle += dt * s.speed
	var c: Vector3 = game.player.global_position
	for k in _lanterns.size():
		var a := _lantern_angle + k * TAU / _lanterns.size()
		var lp := c + Vector3(cos(a) * s.radius, 1.0 + sin(a * 3.0) * 0.15, sin(a) * s.radius)
		_lanterns[k].global_position = lp
		_lanterns[k].rotation = Vector3(0, -a, sin(a * 2.0) * 0.3)
	_lantern_tick -= dt
	if _lantern_tick <= 0.0:
		_lantern_tick = s.cd * cd_mult
		for l in _lanterns:
			game.hit(Vector3(l.global_position.x, 0, l.global_position.z), 0.75, s.dmg * might)

# ---------------------------------------------------------------- projectiles
func _throw_cracker(from: Vector3, to: Vector3, s: Dictionary) -> void:
	var n := Node3D.new()
	var body := Toon.part(Toon.cyl(0.12, 0.12, 0.45, 10), Color(0.85, 0.15, 0.12), Vector3.ZERO)
	body.rotation.z = PI / 2; n.add_child(body)
	var fuse := MeshInstance3D.new(); fuse.mesh = Toon.sphere(0.06); fuse.material_override = Toon.glow(Color(1, 0.8, 0.3), 5.0)
	fuse.position = Vector3(0.28, 0, 0); n.add_child(fuse)
	game.add_child(n)
	n.global_position = from + Vector3(0, 0.8, 0)
	_projectiles.append({"node": n, "kind": "cracker", "from": from, "to": to, "t": 0.0, "dur": 0.55, "s": s})

func _spawn_yarn(at: Vector3, dir: Vector3, s: Dictionary, small := false) -> void:
	var r: float = s.radius * (0.6 if small else 1.0)
	var n := Toon.part(Toon.sphere(r), [Color(0.95, 0.45, 0.55), Color(0.4, 0.7, 0.95), Color(0.95, 0.8, 0.35)][randi() % 3], Vector3.ZERO, Vector3.ONE, true, {"stripes": 18.0, "stripe_color": Color(1, 1, 1, 1), "stripe_axis": Vector3(1, 1, 0)})
	game.add_child(n)
	n.global_position = at + Vector3(0, r, 0)
	_projectiles.append({"node": n, "kind": "yarn", "vel": dir * 9.0, "life": s.life, "tick": 0.0, "s": s, "r": r, "small": small})

func _spawn_wisp(at: Vector3, target: Vector3, s: Dictionary) -> void:
	var n := Node3D.new()
	var core := MeshInstance3D.new(); core.mesh = Toon.sphere(0.2); core.material_override = Toon.glow(Color(0.45, 1.0, 0.95), 5.0)
	n.add_child(core)
	var l := OmniLight3D.new(); l.light_color = Color(0.45, 1.0, 0.95); l.light_energy = 0.8; l.omni_range = 3.0; n.add_child(l)
	game.add_child(n)
	n.global_position = at + Vector3(0, 1.4, 0)
	_projectiles.append({"node": n, "kind": "wisp", "target": target, "s": s, "chain": s.chain, "life": 3.0})

func _spawn_nia(at: Vector3, dir: Vector3, s: Dictionary) -> void:
	var n := Node3D.new()
	var disc := Toon.part(Toon.cyl(0.6, 0.45, 0.12, 20), Color(0.85, 0.72, 0.45), Vector3.ZERO, Vector3.ONE, true, {"stripes": 40.0, "stripe_color": Color(0.65, 0.5, 0.28), "stripe_axis": Vector3(1, 0, 1)})
	n.add_child(disc)
	if evolved.get("nia", false):
		disc.material_override = Toon.mat(Color(1.0, 0.82, 0.3), true, {"stripes": 40.0, "stripe_color": Color(0.85, 0.6, 0.2), "stripe_axis": Vector3(1, 0, 1)})
	game.add_child(n)
	n.global_position = at + Vector3(0, 0.6, 0)
	_projectiles.append({"node": n, "kind": "nia", "origin": at, "dir": dir.normalized(), "t": 0.0, "s": s, "tick": 0.0})

func _update_projectiles(dt: float) -> void:
	var keep := []
	for p in _projectiles:
		var n: Node3D = p.node
		if not is_instance_valid(n):
			continue
		var alive := true
		match p.kind:
			"cracker":
				p.t += dt
				var k: float = p.t / p.dur
				var flat: Vector3 = p.from.lerp(p.to, k)
				n.global_position = flat + Vector3(0, 0.8 + sin(k * PI) * 2.5, 0)
				n.rotation.z += dt * 12.0
				if k >= 1.0:
					_explode(p.to, p.s)
					if p.s.cluster:
						for c in 4:
							var a := c * TAU / 4.0 + randf()
							_explode(p.to + Vector3(cos(a), 0, sin(a)) * p.s.radius * 1.1, p.s, 0.6)
					alive = false
			"yarn":
				p.life -= dt
				var v: Vector3 = p.vel
				var np: Vector3 = n.global_position + v * dt
				if not game.village.inside(np):
					# bounce off the map edge; the evolved ball splits in two
					var c: Vector3 = game.village.clamp_inside(np)
					var nrm: Vector3 = c - np; nrm.y = 0
					if nrm.length() > 0.001:
						v = v.bounce(nrm.normalized())
					np = n.global_position
					if p.s.split and not p.small:
						_spawn_yarn(np, v.rotated(Vector3.UP, 0.7).normalized(), p.s, true)
				p.vel = v
				n.global_position = np
				if v.length() > 0.01:
					n.rotate(v.cross(Vector3.UP).normalized(), -v.length() * dt / p.r)
				p.tick -= dt
				if p.tick <= 0.0:
					p.tick = 0.25
					game.hit(np, p.r + 0.25, p.s.dmg * might)
				if p.life <= 0.0:
					alive = false
			"wisp":
				p.life -= dt
				var t: Vector3 = p.target + Vector3(0, 0.4, 0)
				var to := t - n.global_position
				n.global_position += to.normalized() * minf(16.0 * dt, to.length())
				if to.length() < 0.35:
					game.hit(p.target, 0.9, p.s.dmg * might)
					Juice.burst(game, p.target, Color(0.45, 1.0, 0.95))
					if p.chain > 0:
						var nxt = game.swarm.nearest(p.target + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), 6.0)
						if nxt != null:
							p.target = nxt; p.chain -= 1
						else:
							alive = false
					else:
						alive = false
				if p.life <= 0.0:
					alive = false
			"nia":
				p.t += dt
				var dur := 1.0
				var k: float = p.t / dur
				var out: float = sin(minf(k, 1.0) * PI) * p.s.range
				var origin: Vector3 = game.player.global_position if k > 0.5 else p.origin
				n.global_position = origin + p.dir * out + Vector3(0, 0.6, 0)
				n.rotation.y += dt * 18.0
				p.tick -= dt
				if p.tick <= 0.0:
					p.tick = 0.12
					game.hit(n.global_position, p.s.radius, p.s.dmg * might)
				if k >= 1.0:
					alive = false
		if alive:
			keep.append(p)
		else:
			n.queue_free()
	_projectiles = keep

func _explode(at: Vector3, s: Dictionary, scale := 1.0) -> void:
	game.hit(at, s.radius * scale, s.dmg * might * scale, Vector3.ZERO, TAU, 4.0)
	Juice.ring(game, at, s.radius * scale)
	Juice.burst(game, at, Color(1.0, 0.55, 0.2))
	game.sfx.play("pop", -6.0, 0.6)
	game.shake(0.12)
