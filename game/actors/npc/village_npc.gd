extends Node2D
class_name NightCircuitVillageNpc

var npc_id := "unknown"
var display_name := "Unknown"
var role_name := "Villager"
var move_speed := 42.0
var activity := "idle"
var current_phase := "DUSK"

var _schedules: Dictionary = {}
var _testimony_by_phase: Dictionary = {}
var _presence_by_phase: Dictionary = {}
var _target_position := Vector2.ZERO

func configure(profile: Dictionary) -> void:
	npc_id = str(profile.get("id", "unknown"))
	display_name = str(profile.get("name", "Unknown"))
	role_name = str(profile.get("role", "Villager"))
	move_speed = float(profile.get("move_speed", 42.0))
	_schedules = profile.get("schedules", {}).duplicate(true)
	_testimony_by_phase = profile.get("testimony_by_phase", {}).duplicate(true)
	_presence_by_phase = profile.get("presence_by_phase", {}).duplicate(true)

	apply_phase("DUSK", 0, true)
	queue_redraw()

func apply_phase(phase: String, slot: int, snap: bool = false) -> void:
	current_phase = phase
	var present := bool(_presence_by_phase.get(phase, true))
	visible = present
	set_process(present)

	if not present:
		activity = "absent"
		queue_redraw()
		return

	var schedule = _schedules.get(phase, [])
	if not (schedule is Array) or schedule.is_empty():
		activity = "idle"
		queue_redraw()
		return

	var entry: Dictionary = schedule[posmod(slot, schedule.size())]
	_target_position = entry.get("position", position)
	activity = str(entry.get("activity", "idle"))

	if snap:
		position = _target_position

	queue_redraw()

func apply_schedule_slot(slot: int) -> void:
	apply_phase(current_phase, slot)

func _process(delta: float) -> void:
	if not visible:
		return
	if position.distance_to(_target_position) <= 1.0:
		return
	position = position.move_toward(_target_position, move_speed * delta)

func interaction_record(phase: String) -> Dictionary:
	var testimony: Dictionary = _testimony_by_phase.get(
		phase,
		_testimony_by_phase.get("DUSK", {})
	)

	return {
		"status": "observed",
		"npc_id": npc_id,
		"speaker": display_name,
		"role": role_name,
		"activity": activity,
		"phase": phase,
		"text": str(testimony.get("text", "...")),
		"claim_id": str(testimony.get("claim_id", "")),
		"claim_subject": str(testimony.get("subject", "")),
		"claim_value": testimony.get("value", null),
		"confidence": float(testimony.get("confidence", 0.5))
	}

func protocol_record(observer_position: Vector2) -> Dictionary:
	return {
		"id": npc_id,
		"kind": "npc",
		"name": display_name,
		"role": role_name,
		"activity": activity,
		"phase": current_phase,
		"distance": global_position.distance_to(observer_position),
		"position": [global_position.x, global_position.y]
	}

func _draw() -> void:
	if not visible:
		return

	var body := Color(0.43, 0.39, 0.42, 1.0)
	var trim := Color(0.72, 0.61, 0.52, 1.0)
	var text_color := Color(0.78, 0.78, 0.74, 0.85)

	if current_phase == "NIGHT":
		body = Color(0.26, 0.25, 0.34, 1.0)
		trim = Color(0.55, 0.58, 0.76, 1.0)
	elif current_phase == "DAY":
		body = Color(0.48, 0.40, 0.34, 1.0)
		trim = Color(0.82, 0.68, 0.48, 1.0)

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
