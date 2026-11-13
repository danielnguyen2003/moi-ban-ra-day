extends Node
## Persistent progression + settings (user://save.json).

signal changed
signal brightness_changed(v: float)

const SAVE := "user://save.json"

var fish := 0.0
var lifetime_fish := 0.0
var levels := {}            ## upgrade id -> level
var areas := 1              ## number of unlocked regions
var souls := 0              ## prestige currency (Chín kiếp)
var lives_used := 0
var best_night := 0         ## most mice in one night
var nights := 0
var brightness := 1.0

func _ready() -> void:
	_bind("move_up", [KEY_W, KEY_UP]); _bind("move_down", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT]); _bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("pounce", [KEY_SPACE]); _bind("pause", [KEY_ESCAPE])
	_bind("update_game", [KEY_F9])
	_bind("brightness_down", [KEY_MINUS, KEY_KP_SUBTRACT]); _bind("brightness_up", [KEY_EQUAL, KEY_KP_ADD])
	var mb := InputEventMouseButton.new(); mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("pounce", mb)
	load_game()

func _bind(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new(); ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func lv(id: String) -> int:
	return int(levels.get(id, 0))

func can_buy(id: String) -> bool:
	return Upgrades.DEFS[id].unlock < areas and fish >= Upgrades.cost(id, lv(id))

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	fish -= Upgrades.cost(id, lv(id))
	levels[id] = lv(id) + 1
	save_game(); changed.emit()
	return true

func next_area_cost() -> float:
	return Upgrades.area_cost(areas)

func buy_area() -> bool:
	if areas >= Upgrades.AREAS.size() or fish < next_area_cost():
		return false
	fish -= next_area_cost()
	areas += 1
	save_game(); changed.emit()
	return true

func add_fish(v: float) -> void:
	fish += v
	lifetime_fish += v
	changed.emit()

func end_night(caught: int) -> void:
	nights += 1
	best_night = maxi(best_night, caught)
	save_game(); changed.emit()

func reincarnate() -> int:
	var s := Upgrades.souls_for(lifetime_fish)
	if s <= 0:
		return 0
	souls += s
	lives_used += 1
	fish = 0.0; lifetime_fish = 0.0; levels = {}; areas = 1
	save_game(); changed.emit()
	return s

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("brightness_up"):
		set_brightness(brightness + 0.1)
	elif e.is_action_pressed("brightness_down"):
		set_brightness(brightness - 0.1)

func set_brightness(v: float) -> void:
	brightness = clampf(snappedf(v, 0.1), 0.5, 2.0)
	brightness_changed.emit(brightness)
	save_game()

func to_dict() -> Dictionary:
	return {"v": 2, "fish": fish, "lifetime_fish": lifetime_fish, "levels": levels, "areas": areas,
		"souls": souls, "lives_used": lives_used, "best_night": best_night, "nights": nights, "brightness": brightness}

func from_dict(d: Dictionary) -> void:
	fish = float(d.get("fish", 0.0)); lifetime_fish = float(d.get("lifetime_fish", 0.0))
	levels = d.get("levels", {}); areas = int(d.get("areas", 1)); souls = int(d.get("souls", 0))
	lives_used = int(d.get("lives_used", 0)); best_night = int(d.get("best_night", 0))
	nights = int(d.get("nights", 0)); brightness = float(d.get("brightness", 1.0))

func save_game() -> void:
	if OS.has_feature("editor_hint") or "--no-save" in OS.get_cmdline_user_args():
		return
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))

func load_game() -> void:
	if "--no-save" in OS.get_cmdline_user_args() or not FileAccess.file_exists(SAVE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if d is Dictionary:
		from_dict(d)

func reset_all() -> void:
	from_dict({})
	save_game(); changed.emit()
