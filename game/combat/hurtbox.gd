extends Area2D
class_name NightCircuitHurtbox

@export var team := "neutral"

func _ready() -> void:
	monitoring = false
	monitorable = true

func accept_hit(hit: Dictionary) -> bool:
	if str(hit.get("source_team", "neutral")) == team:
		return false

	var receiver := get_parent()
	if receiver == null or not receiver.has_method("receive_hit"):
		return false

	return bool(receiver.receive_hit(hit))
