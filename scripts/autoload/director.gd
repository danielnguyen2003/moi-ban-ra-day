extends Node
## Pacing: the nursery rhyme is the public clock (singing = the cat keeps vigil, silence = it hunts),
## plus a hidden menace gauge that nudges the cat toward a player who has been safe too long.

signal rhyme_line(text: String)
signal rhyme_state_changed(singing: bool)

const LINES := [
	"Mèo đuổi chuột", "Mời bạn ra đây", "Tay nắm chặt tay", "Đứng thành vòng rộng",
	"Chuột luồn lỗ hổng", "Chạy vội chạy mau", "Mèo đuổi đằng sau", "Trốn đâu cho thoát",
]
@export var sing_duration := 32.0
@export var silence_duration := 70.0
@export var line_interval := 3.6

var rhyme_singing := true
var enabled := true
var menace := 0.0              ## 0 = player relaxed, 1 = under heavy pressure
var _t := 0.0
var _line_t := 0.0
var _line_i := 0
var _calm_t := 0.0

func _process(dt: float) -> void:
	if not enabled:
		return
	_t += dt
	if rhyme_singing:
		_line_t -= dt
		if _line_t <= 0.0:
			_line_t = line_interval
			rhyme_line.emit(LINES[_line_i % LINES.size()])
			_line_i += 1
		if _t >= sing_duration:
			_set_singing(false)
	elif _t >= silence_duration:
		_set_singing(true)

func _set_singing(v: bool) -> void:
	rhyme_singing = v
	_t = 0.0
	_line_t = 0.0
	rhyme_state_changed.emit(v)
	if not v:
		rhyme_line.emit("")

func report_cat_state(state: int, dist_to_rat: float) -> void:
	var pressure := 0.0
	if state == CatBrain.State.CHASE:
		pressure = 1.0
	elif dist_to_rat < 15.0:
		pressure = 0.5
	menace = lerpf(menace, pressure, 0.01)
	if pressure < 0.1 and not rhyme_singing:
		_calm_t += get_process_delta_time()
	else:
		_calm_t = 0.0
	# Player safe for 40 s during the hunt: the cat "hears something" near them.
	if _calm_t > 40.0:
		_calm_t = 0.0
		var rat := get_tree().get_first_node_in_group("player") as Node3D
		if rat:
			var jitter := Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
			NoiseBus.emit_noise(rat.global_position + jitter, 200.0, self)

func restart() -> void:
	_t = 0.0
	_line_i = 0
	_set_singing(true)
