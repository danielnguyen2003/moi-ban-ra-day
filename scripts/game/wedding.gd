class_name RatWedding
extends Node3D
## "Đám cưới chuột" (after the Đông Hồ folk print): a procession carries a red palanquin across
## the village. Escorts play drums and wave flags; break the palanquin before it leaves to win a chest.

signal opened(at: Vector3)
signal escaped

var game
var hp := 400.0
var max_hp := 400.0
var _path: Array[Vector3] = []
var _seg := 0
var _kieu: Node3D
var _escorts: Array[Node3D] = []
var _t := 0.0
var _flash := 0.0
var _label: Label3D

func setup(g, from: Vector3, to: Vector3, hp_: float) -> void:
	game = g
	hp = hp_; max_hp = hp_
	var mid := (from + to) / 2.0 + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	_path = [from, mid, to]
	_build()
	global_position = from

func _mouse(color: Color, s := 1.0) -> Node3D:
	var n := Node3D.new()
	n.add_child(Toon.part(Toon.sphere(0.22), color, Vector3(0, 0.22, 0), Vector3(1, 0.9, 1.3) * s))
	n.add_child(Toon.part(Toon.sphere(0.16), color, Vector3(0, 0.38 * s, -0.25 * s), Vector3.ONE * s))
	for sx in [-1.0, 1.0]:
		n.add_child(Toon.part(Toon.sphere(0.08), Color(0.95, 0.6, 0.65), Vector3(0.11 * sx * s, 0.53 * s, -0.22 * s), Vector3(1, 1, 0.3) * s, false))
	return n

func _build() -> void:
	# palanquin: red lacquer box, gold roof, two carrying poles on four bearers
	_kieu = Node3D.new(); add_child(_kieu)
	_kieu.add_child(Toon.part(Toon.box(Vector3(1.1, 0.9, 1.3)), Color(0.8, 0.12, 0.12), Vector3(0, 1.25, 0)))
	_kieu.add_child(Toon.part(Toon.cone(1.0, 0.6, 4), Color(1.0, 0.78, 0.25), Vector3(0, 2.0, 0), Vector3(1, 1, 1.15)))
	_kieu.add_child(Toon.part(Toon.box(Vector3(0.5, 0.5, 0.05)), Color(1.0, 0.85, 0.4), Vector3(0, 1.3, -0.66), Vector3.ONE, false))
	for sx in [-0.45, 0.45]:
		_kieu.add_child(Toon.part(Toon.cyl(0.04, 0.04, 3.0, 6), Color(0.5, 0.35, 0.2), Vector3(sx, 0.75, 0)))
		_kieu.get_child(_kieu.get_child_count() - 1).rotation.x = PI / 2
	for p in [Vector3(-0.45, 0, -1.1), Vector3(0.45, 0, -1.1), Vector3(-0.45, 0, 1.1), Vector3(0.45, 0, 1.1)]:
		var m := _mouse(Color(0.78, 0.74, 0.72))
		m.position = p; _kieu.add_child(m)
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.5, 0.3); l.light_energy = 1.5; l.omni_range = 6.0; l.position = Vector3(0, 2.0, 0)
	_kieu.add_child(l)
	# escorts ahead and behind: groom on a "horse" (a bigger mouse), drummers with red hats, flag bearers
	for k in 8:
		var e := _mouse(Color(0.75, 0.7, 0.68) if k % 2 == 0 else Color(0.62, 0.55, 0.5))
		var hat := Toon.part(Toon.cyl(0.0, 0.14, 0.16, 8), Color(0.85, 0.15, 0.15), Vector3(0, 0.6, -0.25))
		e.add_child(hat)
		if k % 3 == 0:
			var flag := Toon.part(Toon.box(Vector3(0.02, 0.3, 0.4)), Color(1.0, 0.8, 0.25), Vector3(0.15, 0.95, 0))
			e.add_child(flag)
			e.add_child(Toon.part(Toon.cyl(0.015, 0.015, 0.9, 4), Color(0.4, 0.3, 0.2), Vector3(0.15, 0.6, 0)))
		else:
			e.add_child(Toon.part(Toon.cyl(0.12, 0.12, 0.12, 12), Color(0.85, 0.2, 0.15), Vector3(0, 0.3, -0.42)))   # drum
		add_child(e); _escorts.append(e)
	_label = Label3D.new(); _label.text = "Đám cưới chuột"
	_label.font = preload("res://assets/fonts/google/bevietnampro/BeVietnamPro-ExtraBold.ttf")
	_label.font_size = 80; _label.outline_size = 22; _label.pixel_size = 0.01
	_label.modulate = Color(1.0, 0.85, 0.45); _label.outline_modulate = Color(0.25, 0.05, 0.05)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _label.position = Vector3(0, 3.2, 0)
	add_child(_label)

func try_hit(center: Vector3, r: float, dmg: float) -> bool:
	if Vector2(center.x - global_position.x, center.z - global_position.z).length() < r + 1.2:
		hp -= dmg
		_flash = 1.0
		_label.text = "Đám cưới chuột  %d%%" % int(100.0 * maxf(hp, 0.0) / max_hp)
		if hp <= 0.0:
			opened.emit(global_position)
			for e in _escorts:
				game.swarm.spawn(MiceSwarm.Kind.VANG, e.global_position)   # escorts scatter as golden mice
			queue_free()
		return true
	return false

func _physics_process(dt: float) -> void:
	if game == null or get_tree().paused:
		return
	_t += dt
	_flash = maxf(0.0, _flash - dt * 5.0)
	if _seg >= _path.size() - 1:
		escaped.emit(); queue_free(); return
	var target: Vector3 = _path[_seg + 1]
	var to := target - global_position; to.y = 0
	if to.length() < 0.5:
		_seg += 1
		return
	var dir := to.normalized()
	global_position += dir * 2.6 * dt
	_kieu.rotation.y = atan2(-dir.x, -dir.z)
	_kieu.position.y = absf(sin(_t * 6.0)) * 0.12
	_kieu.scale = Vector3.ONE * (1.0 + 0.1 * _flash)
	for k in _escorts.size():
		var off := (k - 3.5) * 1.3 + (1.5 if k >= 4 else -1.5)
		var e := _escorts[k]
		e.position = Vector3(sin(_t * 2.0 + k) * 0.3, absf(sin(_t * 8.0 + k)) * 0.15, 0) + Vector3(-dir.x, 0, -dir.z) * off
		e.rotation.y = atan2(-dir.x, -dir.z)
