extends Node2D
class_name NightCircuitInspectable

@export var object_id := "unknown"
@export var title := "Unknown object"
@export_multiline var finding := "No finding recorded."
@export var category := "environment"
@export_range(0.0, 1.0, 0.01) var confidence := 1.0
@export var prototype_visible := true

func inspection_id() -> String:
	return object_id

func inspection_record() -> Dictionary:
	return {
		"object_id": object_id,
		"title": title,
		"finding": finding,
		"category": category,
		"confidence": confidence,
		"world_position": [global_position.x, global_position.y]
	}

func protocol_signal(observer_position: Vector2) -> Dictionary:
	var delta := global_position - observer_position
	return {
		"object_id": object_id,
		"category": category,
		"confidence": confidence,
		"distance": delta.length(),
		"relative_position": [delta.x, delta.y]
	}

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if not prototype_visible:
		return

	var marker := Color(0.48, 0.72, 0.76, 0.38)
	draw_rect(Rect2(Vector2(-12.0, -12.0), Vector2(24.0, 24.0)), marker, false, 2.0)
	draw_line(Vector2(-17.0, 0.0), Vector2(17.0, 0.0), marker, 1.0)
	draw_line(Vector2(0.0, -17.0), Vector2(0.0, 17.0), marker, 1.0)
