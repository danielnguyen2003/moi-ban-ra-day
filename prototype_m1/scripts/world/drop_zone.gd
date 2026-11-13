class_name DropZone
extends Node3D
## The incense bowl on the altar. Delivering the matchbox lights one incense stick.

var incense: IncenseZone
var ember: OmniLight3D

func _ready() -> void:
	add_to_group("dropzone")

func deliver(item: Node3D) -> void:
	if item.get_meta("item_id", "") == "matchbox":
		item.visible = false
		item.reparent(self)
		item.position = Vector3.ZERO
		incense.light_up(ember)
		GameState.objective_changed.emit("Nén hương đã cháy. Mèo không lại gần bàn thờ… trong chốc lát.")
		get_tree().call_group("hud", "show_ending")
