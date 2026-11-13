extends Node
## Global constants, input map and run state.

## Blender is modelled in real metres; the game world is scaled ×10 so a rat is ~1.5 units long.
const WORLD_SCALE := 10.0

## Physics layers (bit values) — keep in sync with project.godot [layer_names].
const L_WORLD := 1
const L_CAT_BLOCKER := 2      ## Walls only the cat collides with (rat holes are open for the rat).
const L_MOUSE := 4
const L_CAT := 8
const L_HIDE := 16
const L_CLIMB := 32
const L_INCENSE := 64
const L_ACOUSTIC := 128

signal objective_changed(text: String)
signal player_caught
signal item_collected(item_id: String)

var checkpoint := Transform3D.IDENTITY
var inventory: Array[String] = []
var reduce_flicker := false
## Player brightness multiplier (keys - and =), saved in user://settings.cfg.
var brightness := 1.0
signal brightness_changed(v: float)
const SETTINGS := "user://settings.cfg"

func _ready() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("run", [KEY_SHIFT])
	_bind("jump", [KEY_SPACE])
	_bind("interact", [KEY_E])
	_bind("toggle_fps", [KEY_F3])
	_bind("ui_cancel_game", [KEY_ESCAPE])
	_bind("update_game", [KEY_F9])
	_bind("brightness_down", [KEY_MINUS, KEY_KP_SUBTRACT])
	_bind("brightness_up", [KEY_EQUAL, KEY_KP_ADD])
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		brightness = float(cfg.get_value("video", "brightness", 1.0))
	if "--capture" in OS.get_cmdline_user_args():
		add_child.call_deferred(load("res://tools/capture_shots.gd").new())

func _bind(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func collect(item_id: String) -> void:
	if item_id in inventory:
		return
	inventory.append(item_id)
	item_collected.emit(item_id)

func has_item(item_id: String) -> bool:
	return item_id in inventory

func reset_run() -> void:
	inventory.clear()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("brightness_up"):
		set_brightness(brightness + 0.1)
	elif e.is_action_pressed("brightness_down"):
		set_brightness(brightness - 0.1)

func set_brightness(v: float) -> void:
	brightness = clampf(snappedf(v, 0.1), 0.5, 2.0)
	brightness_changed.emit(brightness)
	var cfg := ConfigFile.new()
	cfg.set_value("video", "brightness", brightness)
	cfg.save(SETTINGS)
