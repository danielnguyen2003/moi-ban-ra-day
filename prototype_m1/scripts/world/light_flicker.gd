class_name LightFlicker
extends Node
## Attach under a Light3D. Modes: "oil" (soft flame), "incense" (breathing ember), "tube" (failing fluorescent).

@export_enum("oil", "incense", "tube") var mode := "oil"
var base_energy := 1.0
var _light: Light3D
var _noise := FastNoiseLite.new()
var _t := randf() * 100.0
var _tube_off_t := 0.0

func _ready() -> void:
	_light = get_parent() as Light3D
	base_energy = _light.light_energy
	_noise.frequency = 1.0
	_light.add_to_group("game_lights")

func _process(dt: float) -> void:
	_t += dt
	var calm := GameState.reduce_flicker
	match mode:
		"oil":
			var n := _noise.get_noise_1d(_t * 6.0) * 0.5 + _noise.get_noise_1d(_t * 23.0) * 0.12
			_light.light_energy = base_energy * (1.0 + (n * 0.3 if calm else n))
		"incense":
			_light.light_energy = base_energy * (0.75 + 0.25 * sin(_t * 1.3))
		"tube":
			if _tube_off_t > 0.0:
				_tube_off_t -= dt
				_light.light_energy = 0.0
				return
			var r := randf()
			if not calm and r < 0.004:
				_tube_off_t = randf_range(0.4, 3.0)   # dies for a moment
			elif not calm and r < 0.06:
				_light.light_energy = base_energy * randf_range(0.1, 0.6)
			else:
				_light.light_energy = base_energy * (0.97 + 0.03 * sin(_t * 314.0))
