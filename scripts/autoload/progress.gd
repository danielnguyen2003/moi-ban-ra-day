extends Node
## Persistent meta progression + settings (user://save.json).

signal changed
signal brightness_changed(v: float)

const SAVE := "user://save.json"

var fish := 0.0
var lifetime_fish := 0.0
var meta := {}                    ## RunDefs.META id -> level
var chars_owned := ["muop"]
var character := "muop"
var stages_open := 1              ## how many stages are unlocked (1..5)
var stage := 0                    ## selected stage index
var heat := 0                     ## endless difficulty after clearing the last stage ("Đêm rằm +N")
var best := {}                    ## "stage:heat" -> {"time": s, "kills": n, "won": bool}
var nights := 0
var total_kills := 0
var brightness := 1.0

func _ready() -> void:
	_bind("move_up", [KEY_W, KEY_UP]); _bind("move_down", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT]); _bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("pounce", [KEY_SPACE]); _bind("pause", [KEY_ESCAPE])
	_bind("pick_1", [KEY_1, KEY_KP_1]); _bind("pick_2", [KEY_2, KEY_KP_2]); _bind("pick_3", [KEY_3, KEY_KP_3])
	_bind("reroll", [KEY_R])
	_bind("update_game", [KEY_F9])
	_bind("brightness_down", [KEY_MINUS, KEY_KP_SUBTRACT]); _bind("brightness_up", [KEY_EQUAL, KEY_KP_ADD])
	var mb := InputEventMouseButton.new(); mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("pounce", mb)
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()
	if "--capture-map" in OS.get_cmdline_user_args():
		add_child.call_deferred(load("res://tools/capture_map.gd").new())
	elif "--capture" in OS.get_cmdline_user_args():
		add_child.call_deferred(load("res://tools/capture_v2.gd").new())

func _bind(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new(); ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func mlv(id: String) -> int:
	return int(meta.get(id, 0))

func buy_meta(id: String) -> bool:
	var c := RunDefs.meta_cost(id, mlv(id))
	if fish < c:
		return false
	fish -= c
	meta[id] = mlv(id) + 1
	save_game(); changed.emit()
	return true

func buy_or_select_char(id: String) -> bool:
	if id in chars_owned:
		character = id
	elif fish >= RunDefs.CHARACTERS[id].cost:
		fish -= RunDefs.CHARACTERS[id].cost
		chars_owned.append(id)
		character = id
	else:
		return false
	save_game(); changed.emit()
	return true

func select_stage(i: int) -> void:
	stage = clampi(i, 0, stages_open - 1)
	save_game(); changed.emit()

func add_fish(v: float) -> void:
	fish += v
	lifetime_fish += v
	changed.emit()

## Called when a night ends. Returns true if something new was unlocked.
func end_night(won: bool, seconds: float, kills: int) -> bool:
	nights += 1
	total_kills += kills
	var key := "%d:%d" % [stage, heat]
	var b: Dictionary = best.get(key, {"time": 0.0, "kills": 0, "won": false})
	b.time = maxf(b.time, seconds); b.kills = maxi(b.kills, kills); b.won = b.won or won
	best[key] = b
	var unlocked := false
	if won:
		if stage == stages_open - 1 and stages_open < RunDefs.STAGES.size():
			stages_open += 1; unlocked = true
		elif stage == RunDefs.STAGES.size() - 1 and stages_open == RunDefs.STAGES.size():
			heat += 1; unlocked = true
	save_game(); changed.emit()
	return unlocked

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
	return {"v": 3, "fish": fish, "lifetime_fish": lifetime_fish, "meta": meta, "chars_owned": chars_owned,
		"character": character, "stages_open": stages_open, "stage": stage, "heat": heat, "best": best,
		"nights": nights, "total_kills": total_kills, "brightness": brightness}

func from_dict(d: Dictionary) -> void:
	fish = float(d.get("fish", 0.0)); lifetime_fish = float(d.get("lifetime_fish", 0.0))
	meta = d.get("meta", {}); chars_owned = d.get("chars_owned", ["muop"]); character = d.get("character", "muop")
	stages_open = int(d.get("stages_open", 1)); stage = int(d.get("stage", 0)); heat = int(d.get("heat", 0))
	best = d.get("best", {}); nights = int(d.get("nights", 0)); total_kills = int(d.get("total_kills", 0))
	brightness = float(d.get("brightness", 1.0))
	if int(d.get("v", 3)) < 3:      # v2 save: keep the fish as a welcome gift, reset the rest
		fish = float(d.get("fish", 0.0))

func save_game() -> void:
	if "--no-save" in OS.get_cmdline_user_args():
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
