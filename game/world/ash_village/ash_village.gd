extends Node2D
class_name NightCircuitAshVillage

signal room_changed(room_id: String, room_title: String)
signal checkpoint_changed(checkpoint_id: String)
signal hunter_respawned(checkpoint_id: String)
signal exit_requested(destination: String)
signal dialogue_presented(record: Dictionary)
signal schedule_applied(phase: String, slot: int)

const VillageNpcScene = preload("res://game/actors/npc/VillageNpc.tscn")

const WORLD_SIZE := Vector2(3840.0, 720.0)
const KILL_Y := 820.0
const PHASE := "DUSK"
const SCHEDULE_SLOT_SECONDS := 18.0
const INTERACT_RANGE := 150.0

const ROOMS := [
	{"id": "ash_gate", "title": "ASH GATE", "bounds": Rect2(0.0, 0.0, 1280.0, 720.0)},
	{"id": "market_square", "title": "MARKET SQUARE", "bounds": Rect2(1280.0, 0.0, 1280.0, 720.0)},
	{"id": "bell_road", "title": "BELL ROAD", "bounds": Rect2(2560.0, 0.0, 1280.0, 720.0)}
]

const CHECKPOINTS := [
	{"id": "ash_gate", "position": Vector2(180.0, 570.0), "activation_rect": Rect2(100.0, 500.0, 180.0, 140.0)},
	{"id": "market_lantern", "position": Vector2(1580.0, 570.0), "activation_rect": Rect2(1490.0, 500.0, 180.0, 140.0)}
]

const GEOMETRY := [
	Rect2(-40.0, 0.0, 40.0, 720.0),
	Rect2(3840.0, 0.0, 40.0, 720.0),
	Rect2(0.0, 620.0, 3840.0, 100.0),
	Rect2(420.0, 500.0, 330.0, 120.0),
	Rect2(910.0, 455.0, 260.0, 165.0),
	Rect2(1460.0, 500.0, 360.0, 120.0),
	Rect2(2050.0, 470.0, 300.0, 150.0),
	Rect2(2740.0, 510.0, 330.0, 110.0),
	Rect2(3270.0, 430.0, 330.0, 190.0)
]

const NPC_PROFILES := [
	{
		"id": "orin_gatekeeper",
		"name": "Orin",
		"role": "Gatekeeper",
		"move_speed": 36.0,
		"dusk_schedule": [
			{"position": Vector2(340.0, 575.0), "activity": "watching_gate"},
			{"position": Vector2(620.0, 575.0), "activity": "checking_lanterns"},
			{"position": Vector2(340.0, 575.0), "activity": "watching_gate"}
		],
		"testimony": {
			"text": "The east bridge collapsed twenty years ago. Everyone here knows that.",
			"claim_id": "bridge_destroyed_long_ago",
			"subject": "east_bridge",
			"value": "destroyed",
			"confidence": 0.92
		}
	},
	{
		"id": "tamsin_cartographer",
		"name": "Tamsin",
		"role": "Cartographer",
		"move_speed": 44.0,
		"dusk_schedule": [
			{"position": Vector2(1390.0, 575.0), "activity": "folding_maps"},
			{"position": Vector2(1760.0, 575.0), "activity": "measuring_square"},
			{"position": Vector2(1390.0, 575.0), "activity": "folding_maps"}
		],
		"testimony": {
			"text": "I crossed the east bridge at sunrise. The stones were wet, not broken.",
			"claim_id": "bridge_present_today",
			"subject": "east_bridge",
			"value": "present",
			"confidence": 0.88
		}
	},
	{
		"id": "mara_apothecary",
		"name": "Mara",
		"role": "Apothecary",
		"move_speed": 34.0,
		"dusk_schedule": [
			{"position": Vector2(2140.0, 575.0), "activity": "closing_shop"},
			{"position": Vector2(2390.0, 575.0), "activity": "collecting_herbs"},
			{"position": Vector2(2140.0, 575.0), "activity": "closing_shop"}
		],
		"testimony": {
			"text": "Three bells. Three towers. They are not supposed to agree.",
			"claim_id": "bells_must_not_agree",
			"subject": "village_bells",
			"value": "never_agree",
			"confidence": 0.81
		}
	},
	{
		"id": "nell_clock_child",
		"name": "Nell",
		"role": "Clockmaker's child",
		"move_speed": 52.0,
		"dusk_schedule": [
			{"position": Vector2(2870.0, 575.0), "activity": "drawing_chalk_door"},
			{"position": Vector2(3160.0, 575.0), "activity": "counting_bell_strokes"},
			{"position": Vector2(2870.0, 575.0), "activity": "drawing_chalk_door"}
		],
		"testimony": {
			"text": "There was a door under the clock. Mum says I dreamed it, but the hinge is still there.",
			"claim_id": "clock_door_existed",
			"subject": "clock_door",
			"value": "existed",
			"confidence": 0.67
		}
	}
]

var hunter: Node2D
var active_checkpoint_id := "ash_gate"
var active_checkpoint_position := Vector2(180.0, 570.0)
var current_room_id := ""
var _active := false
var _exit_latched := false
var _schedule_elapsed := 0.0
var _schedule_slot := 0
var _npcs: Array[Node] = []

func _ready() -> void:
	_build_geometry()
	_build_room_triggers()
	_build_checkpoints()
	_build_world_exit()
	_build_npcs()
	queue_redraw()

func set_active(enabled: bool) -> void:
	_active = enabled
	visible = enabled
	set_process(enabled)
	set_physics_process(enabled)
	if enabled:
		_exit_latched = false

func bind_hunter(target: Node2D) -> void:
	hunter = target
	_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	activate_checkpoint("ash_gate", true)
	_enter_room(ROOMS[0])

	if hunter != null and hunter.has_method("force_respawn"):
		hunter.force_respawn(global_position + active_checkpoint_position)

func world_phase() -> String:
	return PHASE

func _process(delta: float) -> void:
	if not _active:
		return

	_schedule_elapsed += delta
	var next_slot := int(floor(_schedule_elapsed / SCHEDULE_SLOT_SECONDS)) % 3
	if next_slot != _schedule_slot:
		_schedule_slot = next_slot
		_apply_schedule_slot(_schedule_slot)

func _physics_process(_delta: float) -> void:
	if not _active or hunter == null:
		return

	if hunter.global_position.y > global_position.y + KILL_Y:
		respawn_hunter()

func interact_nearest(actor: Node2D) -> Dictionary:
	var nearest: Node = null
	var nearest_distance := INF

	for npc in _npcs:
		if not is_instance_valid(npc):
			continue
		var distance := actor.global_position.distance_to(npc.global_position)
		if distance <= INTERACT_RANGE and distance < nearest_distance:
			nearest = npc
			nearest_distance = distance

	if nearest == null:
		return {
			"status": "no_target",
			"range": INTERACT_RANGE
		}

	var record: Dictionary = nearest.interaction_record(PHASE)
	record["distance"] = nearest_distance
	dialogue_presented.emit(record.duplicate(true))
	return record

func protocol_entities(observer_position: Vector2, max_range: float) -> Array:
	var result: Array = []
	for npc in _npcs:
		if not is_instance_valid(npc):
			continue
		var distance := observer_position.distance_to(npc.global_position)
		if distance <= max_range:
			result.append(npc.protocol_record(observer_position))
	return result

func protocol_signals(observer_position: Vector2, max_range: float) -> Dictionary:
	var local_anchor := Vector2(3380.0, 390.0)
	var anchor := global_position + local_anchor
	var distance := observer_position.distance_to(anchor)
	if distance > max_range:
		return {}

	return {
		"bell_tower_resonance": {
			"object_id": "bell_tower_resonance",
			"category": "temporal_resonance",
			"confidence": 0.72,
			"distance": distance,
			"relative_position": [anchor.x - observer_position.x, anchor.y - observer_position.y]
		}
	}

func activate_checkpoint(checkpoint_id: String, silent: bool = false) -> void:
	for checkpoint in CHECKPOINTS:
		if checkpoint["id"] != checkpoint_id:
			continue

		if active_checkpoint_id == checkpoint_id and not silent:
			return

		active_checkpoint_id = checkpoint_id
		active_checkpoint_position = checkpoint["position"]

		if not silent:
			checkpoint_changed.emit(active_checkpoint_id)
		queue_redraw()
		return

func respawn_hunter() -> void:
	if hunter == null:
		return

	if hunter.has_method("force_respawn"):
		hunter.force_respawn(global_position + active_checkpoint_position)

	hunter_respawned.emit(active_checkpoint_id)

func _build_geometry() -> void:
	for index in range(GEOMETRY.size()):
		_make_static_rect("VillageSolid_%02d" % index, GEOMETRY[index])

func _build_room_triggers() -> void:
	for room in ROOMS:
		var area := _make_area("Room_%s" % room["id"], room["bounds"], 4)
		area.body_entered.connect(_on_room_body_entered.bind(room))

func _build_checkpoints() -> void:
	for checkpoint in CHECKPOINTS:
		var area := _make_area("Checkpoint_%s" % checkpoint["id"], checkpoint["activation_rect"], 8)
		area.body_entered.connect(_on_checkpoint_body_entered.bind(checkpoint["id"]))

func _build_world_exit() -> void:
	var area := _make_area("DrainReturn", Rect2(0.0, 470.0, 90.0, 170.0), 4)
	area.body_entered.connect(_on_world_exit_body_entered)

func _build_npcs() -> void:
	for profile in NPC_PROFILES:
		var npc = VillageNpcScene.instantiate()
		add_child(npc)
		npc.configure(profile)
		_npcs.append(npc)
	_apply_schedule_slot(0)

func _apply_schedule_slot(slot: int) -> void:
	for npc in _npcs:
		if is_instance_valid(npc):
			npc.apply_schedule_slot(slot)
	schedule_applied.emit(PHASE, slot)

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

func _make_area(node_name: String, rect: Rect2, layer: int) -> Area2D:
	var area := Area2D.new()
	area.name = node_name
	area.position = rect.position + rect.size * 0.5
	area.collision_layer = layer
	area.collision_mask = 2

	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	area.add_child(shape_node)
	add_child(area)
	return area

func _on_room_body_entered(body: Node, room: Dictionary) -> void:
	if not _active or body != hunter:
		return
	_enter_room(room)

func _on_checkpoint_body_entered(body: Node, checkpoint_id: String) -> void:
	if not _active or body != hunter:
		return
	activate_checkpoint(checkpoint_id)

func _on_world_exit_body_entered(body: Node) -> void:
	if not _active or body != hunter or _exit_latched:
		return
	_exit_latched = true
	exit_requested.emit("sewer")

func _enter_room(room: Dictionary) -> void:
	var room_id := str(room["id"])
	if current_room_id == room_id:
		return

	current_room_id = room_id
	if hunter != null and hunter.has_method("set_camera_bounds"):
		var local_bounds: Rect2 = room["bounds"]
		hunter.set_camera_bounds(Rect2(global_position + local_bounds.position, local_bounds.size))

	room_changed.emit(room_id, str(room["title"]))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.055, 0.045, 0.060, 1.0))
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.075, 0.055, 0.060, 1.0))
	draw_rect(Rect2(1280.0, 0.0, 1280.0, 720.0), Color(0.085, 0.060, 0.060, 1.0))
	draw_rect(Rect2(2560.0, 0.0, 1280.0, 720.0), Color(0.065, 0.050, 0.070, 1.0))

	for rect in GEOMETRY:
		draw_rect(rect, Color(0.13, 0.11, 0.12, 1.0))
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.39, 0.28, 0.24, 0.9), 3.0)

	for x in range(160, 3700, 280):
		draw_line(Vector2(float(x), 145.0), Vector2(float(x), 610.0), Color(0.09, 0.08, 0.09, 0.65), 5.0)

	draw_string(ThemeDB.fallback_font, Vector2(110.0, 225.0), "ASH VILLAGE // DUSK", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Color(0.76, 0.57, 0.48, 0.8))
	draw_string(ThemeDB.fallback_font, Vector2(1400.0, 240.0), "MARKET SQUARE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 23, Color(0.70, 0.55, 0.48, 0.7))
	draw_string(ThemeDB.fallback_font, Vector2(2760.0, 235.0), "BELL ROAD", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 23, Color(0.70, 0.55, 0.48, 0.7))
	draw_string(ThemeDB.fallback_font, Vector2(3300.0, 330.0), "BELL TOWER // LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.70, 0.43, 0.43, 0.85))

	for checkpoint in CHECKPOINTS:
		var p: Vector2 = checkpoint["position"]
		var active := checkpoint["id"] == active_checkpoint_id
		var marker := Color(0.75, 0.66, 0.42, 1.0) if active else Color(0.40, 0.33, 0.25, 0.8)
		draw_line(p + Vector2(0.0, 25.0), p + Vector2(0.0, -34.0), marker, 3.0)
		draw_circle(p + Vector2(0.0, -40.0), 7.0, marker)
