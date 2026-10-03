extends Node2D
class_name NightCircuitFallenArena

signal room_changed(room_id: String, room_title: String)
signal checkpoint_changed(checkpoint_id: String)
signal hunter_respawned(checkpoint_id: String)
signal exit_requested(destination: String)
signal boss_state_changed(snapshot: Dictionary)
signal boss_anomaly(event: Dictionary)
signal boss_defeated(snapshot: Dictionary)

const WORLD_SIZE := Vector2(1280.0, 720.0)
const KILL_Y := 820.0
const SPAWN_POSITION := Vector2(150.0, 570.0)
const RETURN_POSITION := Vector2(95.0, 570.0)
const VIGIL_CACHE_POSITION := Vector2(205.0, 540.0)
const SCOUT_CORE_POSITION := Vector2(660.0, 520.0)
const INTERACT_RANGE := 125.0

const GEOMETRY := [
	Rect2(-40.0, 0.0, 40.0, 720.0),
	Rect2(1280.0, 0.0, 40.0, 720.0),
	Rect2(0.0, 620.0, 1280.0, 100.0),
	Rect2(320.0, 515.0, 150.0, 24.0),
	Rect2(810.0, 485.0, 150.0, 24.0),
	Rect2(1040.0, 405.0, 140.0, 24.0)
]

var hunter: Node2D
var active_checkpoint_id := "fallen_threshold"
var current_room_id := "fallen_cistern"

var _active := false
var _boss_defeated := false
var _vigil_cache_used := false
var _last_anomaly: Dictionary = {}
var _anomaly_timer := 0.0

@onready var boss = $TheFallen

func _ready() -> void:
	_build_geometry()

	boss.health_changed.connect(_on_boss_health_changed)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.attack_telegraphed.connect(_on_boss_attack_telegraphed)
	boss.anomaly_detected.connect(_on_boss_anomaly)
	boss.defeated.connect(_on_boss_defeated)

	set_active(false)
	queue_redraw()

func set_active(enabled: bool) -> void:
	_active = enabled
	visible = enabled
	set_process(enabled)
	set_physics_process(enabled)

	if boss != null:
		boss.set_encounter_active(enabled and hunter != null and not _boss_defeated)

	if enabled:
		queue_redraw()

func bind_hunter(target: Node2D) -> void:
	hunter = target
	_active = true
	visible = true
	set_process(true)
	set_physics_process(true)

	if hunter != null and hunter.has_method("set_camera_bounds"):
		hunter.set_camera_bounds(Rect2(global_position, WORLD_SIZE))
	if hunter != null and hunter.has_method("force_respawn"):
		hunter.force_respawn(global_position + SPAWN_POSITION)

	if not _boss_defeated:
		boss.set_encounter_active(true)
		boss.reset_encounter()
		boss.start_encounter(hunter)

	room_changed.emit(current_room_id, "THE FALLEN // CISTERN")
	checkpoint_changed.emit(active_checkpoint_id)
	_emit_boss_state()
	queue_redraw()

func world_phase() -> String:
	return "CISTERN"

func world_state_snapshot() -> Dictionary:
	var snapshot := {
		"phase": "CISTERN",
		"boss_defeated": _boss_defeated,
		"vigil_cache_used": _vigil_cache_used,
		"reward_state": "SCOUT_CORE_UNCLAIMED" if _boss_defeated else "LOCKED"
	}

	if boss != null and boss.has_method("actor_snapshot"):
		snapshot["boss"] = boss.actor_snapshot()

	return snapshot

func protocol_signals(observer_position: Vector2, max_range: float) -> Dictionary:
	var result := {}

	if _anomaly_timer > 0.0 and not _last_anomaly.is_empty():
		var damage_source = _last_anomaly.get("damage_source", [])
		if damage_source is Array and damage_source.size() == 2:
			var source_position := Vector2(float(damage_source[0]), float(damage_source[1]))
			var distance := observer_position.distance_to(source_position)
			if distance <= max_range:
				result["fallen_causal_attack"] = {
					"object_id": "fallen_causal_attack",
					"category": "causal_anomaly",
					"classification": "NO_PHYSICAL_SOURCE",
					"confidence": 0.99,
					"attack": _last_anomaly.get("attack", "CAUSAL_ECHO"),
					"physical_source": false,
					"distance": distance,
					"relative_position": [
						source_position.x - observer_position.x,
						source_position.y - observer_position.y
					]
				}

	if _boss_defeated:
		var core_global := global_position + SCOUT_CORE_POSITION
		var core_distance := observer_position.distance_to(core_global)
		if core_distance <= max_range:
			result["scout_core_unclaimed"] = {
				"object_id": "scout_core_unclaimed",
				"category": "compatible_core",
				"confidence": 0.97,
				"distance": core_distance,
				"relative_position": [
					core_global.x - observer_position.x,
					core_global.y - observer_position.y
				]
			}

	return result

func interact_nearest(actor: Node2D) -> Dictionary:
	if not _active:
		return {"status": "no_target"}

	var cache_global := global_position + VIGIL_CACHE_POSITION
	var cache_distance := actor.global_position.distance_to(cache_global)
	if not _vigil_cache_used and cache_distance <= INTERACT_RANGE:
		_vigil_cache_used = true
		if actor.has_method("restore_full_health"):
			actor.restore_full_health()
		queue_redraw()
		return {
			"status": "world_event",
			"event": "vigil_cache",
			"detail": "Hidden Night War ration restored full health.",
			"distance": cache_distance
		}

	if _boss_defeated:
		var return_global := global_position + RETURN_POSITION
		var return_distance := actor.global_position.distance_to(return_global)
		if return_distance <= INTERACT_RANGE:
			exit_requested.emit("sewer_from_fallen")
			return {
				"status": "world_event",
				"event": "leave_fallen_cistern",
				"detail": "Return to Cistern Approach.",
				"distance": return_distance
			}

	return {"status": "no_target", "range": INTERACT_RANGE}

func respawn_hunter() -> void:
	if hunter == null:
		return

	if hunter.has_method("force_respawn"):
		hunter.force_respawn(global_position + SPAWN_POSITION)

	if not _boss_defeated:
		boss.set_encounter_active(true)
		boss.reset_encounter()
		boss.start_encounter(hunter)

	hunter_respawned.emit(active_checkpoint_id)
	_emit_boss_state()

func _process(delta: float) -> void:
	if not _active:
		return

	_anomaly_timer = maxf(0.0, _anomaly_timer - delta)

func _physics_process(_delta: float) -> void:
	if not _active or hunter == null:
		return

	if hunter.global_position.y > global_position.y + KILL_Y:
		respawn_hunter()

func _on_boss_health_changed(_health: int, _max_health: int) -> void:
	_emit_boss_state()

func _on_boss_phase_changed(_phase: int) -> void:
	_emit_boss_state()

func _on_boss_attack_telegraphed(_event: Dictionary) -> void:
	_emit_boss_state()

func _on_boss_anomaly(event: Dictionary) -> void:
	_last_anomaly = event.duplicate(true)
	_anomaly_timer = 1.0
	boss_anomaly.emit(event.duplicate(true))
	_emit_boss_state()

func _on_boss_defeated(snapshot: Dictionary) -> void:
	_boss_defeated = true
	_last_anomaly = {}
	_anomaly_timer = 0.0
	boss_defeated.emit(snapshot.duplicate(true))
	_emit_boss_state()
	queue_redraw()

func _emit_boss_state() -> void:
	if boss != null and boss.has_method("actor_snapshot"):
		boss_state_changed.emit(boss.actor_snapshot())

func _build_geometry() -> void:
	for index in range(GEOMETRY.size()):
		_make_static_rect("ArenaSolid_%02d" % index, GEOMETRY[index])

func _make_static_rect(node_name: String, rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = 1
	body.collision_mask = 0

	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)
	return body

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.026, 0.022, 0.035, 1.0))

	for rect in GEOMETRY:
		draw_rect(rect, Color(0.10, 0.085, 0.11, 1.0))
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.32, 0.24, 0.31, 1.0), 3.0)

	for x in range(90, 1220, 150):
		draw_line(Vector2(float(x), 60.0), Vector2(float(x), 210.0), Color(0.12, 0.09, 0.14, 0.9), 9.0)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(455.0, 180.0),
		"THE FALLEN // CISTERN",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		28,
		Color(0.66, 0.45, 0.49, 0.8)
	)

	# Suspicious masonry only. The label is deliberately absent.
	if not _vigil_cache_used:
		draw_rect(Rect2(VIGIL_CACHE_POSITION + Vector2(-24.0, -32.0), Vector2(48.0, 64.0)), Color(0.11, 0.10, 0.12, 1.0), false, 2.0)
		draw_line(VIGIL_CACHE_POSITION + Vector2(-18.0, -8.0), VIGIL_CACHE_POSITION + Vector2(14.0, 13.0), Color(0.26, 0.22, 0.23, 0.8), 2.0)

	if _boss_defeated:
		draw_circle(SCOUT_CORE_POSITION, 18.0, Color(0.46, 0.76, 0.86, 0.95))
		draw_arc(SCOUT_CORE_POSITION, 31.0, 0.0, TAU, 32, Color(0.62, 0.82, 0.93, 0.8), 3.0)
		draw_string(
			ThemeDB.fallback_font,
			SCOUT_CORE_POSITION + Vector2(-105.0, -52.0),
			"SCOUT CORE // UNCLAIMED",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			16,
			Color(0.58, 0.82, 0.92, 0.9)
		)
		draw_string(
			ThemeDB.fallback_font,
			RETURN_POSITION + Vector2(-55.0, -55.0),
			"R // RETURN",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			15,
			Color(0.60, 0.72, 0.78, 0.9)
		)
