extends Node2D
class_name NightCircuitVillageNpc

var npc_id := "unknown"
var display_name := "Unknown"
var role_name := "Villager"
var move_speed := 42.0
var activity := "idle"

var _schedule: Array = []
var _target_position := Vector2.ZERO
var _testimony: Dictionary = {}

func configure(profile: Dictionary) -> void:
	npc_id = str(profile.get("id", "unknown"))
	display_name = str(profile.get("name", "Unknown"))
	role_name = str(profile.get("role", "Villager"))
	move_speed = float(profile.get("move_speed", 42.0))
	_schedule = profile.get("dusk_schedule", []).duplicate(true)
	_testimony = profile.get("testimony", {}).duplicate(true)

	if not _schedule.is_empty():
		var first: Dictionary = _schedule[0]
		position = first.get("position", Vector2.ZERO)
		apply_schedule_slot(0)

	queue_redraw()

func apply_schedule_slot(slot: int) -> void:
	if _schedule.is_empty():
		return

	var entry: Dictionary = _schedule[posmod(slot, _schedule.size())]
	_target_position = entry.get("position", position)
	activity = str(entry.get("activity", "idle"))
	queue_redraw()

func _process(delta: float) -> void:
	if position.distance_to(_target_position) <= 1.0:
		return
	position = position.move_toward(_target_position, move_speed * delta)

func interaction_record(phase: String) -> Dictionary:
	return {
		"status": "observed",
		"npc_id": npc_id,
		"speaker": display_name,
		"role": role_name,
		"activity": activity,
		"phase": phase,
		"text": str(_testimony.get("text", "...")),
		"claim_id": str(_testimony.get("claim_id", "")),
		"claim_subject": str(_testimony.get("subject", "")),
		"claim_value": _testimony.get("value", null),
		"confidence": float(_testimony.get("confidence", 0.5))
	}

func protocol_record(observer_position: Vector2) -> Dictionary:
	return {
		"id": npc_id,
		"kind": "npc",
		"name": display_name,
		"role": role_name,
		"activity": activity,
		"distance": global_position.distance_to(observer_position),
		"position": [global_position.x, global_position.y]
	}

func _draw() -> void:
	var body := Color(0.43, 0.39, 0.42, 1.0)
	var trim := Color(0.72, 0.61, 0.52, 1.0)
	var text_color := Color(0.78, 0.78, 0.74, 0.85)

	draw_rect(Rect2(Vector2(-10.0, -23.0), Vector2(20.0, 40.0)), body)
	draw_circle(Vector2(0.0, -30.0), 9.0, trim)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-34.0, -47.0),
		display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		68.0,
		12,
		text_color
	)
