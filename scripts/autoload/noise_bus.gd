extends Node
## Broadcasts gameplay noises (footsteps, knocked objects). Listeners (the cat) decide what they hear.

signal noise_emitted(pos: Vector3, loudness: float, source: Node)

## Loudness is the radius (world units) at which the noise is just audible in open air.
func emit_noise(pos: Vector3, loudness: float, source: Node = null) -> void:
	if loudness > 0.0:
		noise_emitted.emit(pos, loudness, source)

## Perceived strength 0..1 of a noise at a listener; walls (occluders) cut it by `wall_loss` each.
static func perceived(noise_pos: Vector3, loudness: float, listener: Vector3, walls: int, wall_loss := 0.5) -> float:
	var d := noise_pos.distance_to(listener)
	if d >= loudness:
		return 0.0
	var s := 1.0 - d / loudness
	return clampf(s * pow(1.0 - wall_loss, walls), 0.0, 1.0)
