class_name Sfx
extends Node
## Tiny polyphonic SFX player + looping night ambience.

const SOUNDS := {
	"pop": "res://assets/audio/synth/sfx/pop.wav",
	"whoosh": "res://assets/audio/synth/sfx/whoosh.wav",
	"chime": "res://assets/audio/synth/sfx/chime.wav",
	"coin": "res://assets/audio/synth/sfx/coin.wav",
	"click": "res://assets/audio/synth/sfx/click.wav",
	"unlock": "res://assets/audio/synth/sfx/unlock.wav",
}
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _i := 0

func _ready() -> void:
	for k in SOUNDS:
		_streams[k] = load(SOUNDS[k])
	for i in 10:
		var p := AudioStreamPlayer.new(); add_child(p); _players.append(p)
	var amb := AudioStreamPlayer.new()
	var st := load("res://assets/audio/commons/night_rain_sea/night_rain_sea.ogg") as AudioStreamOggVorbis
	if st:
		st.loop = true
		amb.stream = st; amb.volume_db = -20.0
		add_child(amb); amb.play()

func play(name: String, db := 0.0, pitch := 1.0) -> void:
	var p := _players[_i]
	_i = (_i + 1) % _players.size()
	p.stream = _streams.get(name)
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()
