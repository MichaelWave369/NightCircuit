extends Node2D
class_name NightCircuitSewerTestRoom

signal room_changed(room_id: String, room_title: String)
signal checkpoint_changed(checkpoint_id: String)
signal hunter_respawned(checkpoint_id: String)
signal exit_requested(destination: String)
signal backtrack_route_opened(record: Dictionary)
signal backtrack_discovery(record: Dictionary)

const WORLD_SIZE := Vector2(3840.0, 720.0)
const KILL_Y := 820.0
const BOSS_GATE_POSITION := Vector2(3310.0, 570.0)
const BOSS_GATE_RANGE := 145.0

const BACKTRACK_ANCHOR_ID := "intake_anchor_01"
const BACKTRACK_ANCHOR_POSITION := Vector2(1115.0, 420.0)
const BACKTRACK_ANCHOR_RANGE := 420.0
const SERVICE_VEIN_ID := "service_vein_01"
const SERVICE_VEIN_POSITION := Vector2(470.0, 145.0)
const SERVICE_VEIN_DISCOVERY_RECT := Rect2(355.0, 80.0, 250.0, 150.0)

const BACKTRACK_GEOMETRY := [
	Rect2(1010.0, 390.0, 145.0, 24.0),
	Rect2(810.0, 320.0, 150.0, 24.0),
	Rect2(610.0, 250.0, 150.0, 24.0),
	Rect2(390.0, 185.0, 175.0, 24.0)
]

const ROOMS := [
	{
		"id": "intake_shaft",
		"title": "INTAKE SHAFT",
		"bounds": Rect2(0.0, 0.0, 1280.0, 720.0)
	},
	{
		"id": "spillway",
		"title": "SPILLWAY",
		"bounds": Rect2(1280.0, 0.0, 1280.0, 720.0)
	},
	{
		"id": "cistern_approach",
		"title": "CISTERN APPROACH",
		"bounds": Rect2(2560.0, 0.0, 1280.0, 720.0)
	}
]

const CHECKPOINTS := [
	{
		"id": "drain_entry",
		"position": Vector2(180.0, 570.0),
		"activation_rect": Rect2(110.0, 500.0, 140.0, 140.0)
	},
	{
		"id": "spillway_ladder",
		"position": Vector2(1540.0, 570.0),
		"activation_rect": Rect2(1470.0, 500.0, 140.0, 140.0)
	},
	{
		"id": "cistern_gate",
		"position": Vector2(2780.0, 570.0),
		"activation_rect": Rect2(2710.0, 500.0, 140.0, 140.0)
	}
]

const GEOMETRY := [
	Rect2(-40.0, 0.0, 40.0, 720.0),
	Rect2(3840.0, 0.0, 40.0, 720.0),

	# Room 1: Intake Shaft
	Rect2(0.0, 620.0, 720.0, 100.0),
	Rect2(900.0, 620.0, 380.0, 100.0),
	Rect2(520.0, 500.0, 170.0, 24.0),
	Rect2(980.0, 470.0, 180.0, 24.0),

	# Room 2: Spillway
	Rect2(1280.0, 620.0, 360.0, 100.0),
	Rect2(1840.0, 620.0, 720.0, 100.0),
	Rect2(1660.0, 455.0, 46.0, 165.0),
	Rect2(1790.0, 360.0, 46.0, 260.0),
	Rect2(1970.0, 470.0, 210.0, 24.0),
	Rect2(2240.0, 385.0, 220.0, 24.0),

	# Room 3: Cistern Approach
	Rect2(2560.0, 620.0, 440.0, 100.0),
	Rect2(3210.0, 620.0, 630.0, 100.0),
	Rect2(2980.0, 520.0, 180.0, 24.0),
	Rect2(3220.0, 440.0, 170.0, 24.0),
	Rect2(3460.0, 355.0, 190.0, 24.0),
	Rect2(3710.0, 260.0, 130.0, 24.0)
]

var hunter: Node2D
var active_checkpoint_id := "drain_entry"
var active_checkpoint_position := Vector2(180.0, 570.0)
var current_room_id := ""
var _checkpoint_areas: Array[Area2D] = []
var _backtrack_geometry: Array[StaticBody2D] = []
var _active := true
var _exit_latched := false
var _backtrack_route_open := false
var _backtrack_discovered := false

func _ready() -> void:
	_build_geometry()
	_build_backtrack_geometry()
	_build_room_triggers()
	_build_checkpoints()
	_build_world_exit()
	_build_backtrack_discovery()
	_restore_backtrack_progress()
	_sync_backtrack_geometry()
	queue_redraw()

func bind_hunter(target: Node2D) -> void:
	hunter = target
	_active = true
	_exit_latched = false
	activate_checkpoint("drain_entry", true)
	_enter_room(ROOMS[0])
	if hunter != null and hunter.has_method("force_respawn"):
		hunter.force_respawn(active_checkpoint_position)

func _physics_process(_delta: float) -> void:
	if not _active or hunter == null:
		return

	if hunter.global_position.y > KILL_Y:
		respawn_hunter()

func set_active(enabled: bool) -> void:
	_active = enabled
	visible = enabled
	if enabled:
		_exit_latched = false

func enter_from_village(target: Node2D) -> void:
	hunter = target
	_active = true
	visible = true
	_exit_latched = false
	activate_checkpoint("cistern_gate", true)
	_enter_room(ROOMS[2])
	if hunter != null and hunter.has_method("force_respawn"):
		hunter.force_respawn(Vector2(3480.0, 570.0))

func enter_from_boss(target: Node2D) -> void:
	hunter = target
	_active = true
	visible = true
	_exit_latched = false
	activate_checkpoint("cistern_gate", true)
	_enter_room(ROOMS[2])
	if hunter != null and hunter.has_method("force_respawn"):
		hunter.force_respawn(Vector2(3225.0, 570.0))

func world_phase() -> String:
	return "DRAIN"

func world_state_snapshot() -> Dictionary:
	return {
		"phase": "DRAIN",
		"backtrack_route_open": _backtrack_route_open,
		"backtrack_discovered": _backtrack_discovered,
		"anchor_id": BACKTRACK_ANCHOR_ID,
		"service_vein_id": SERVICE_VEIN_ID,
		"scout_unlocked": _scout_unlocked()
	}

func protocol_signals(observer_position: Vector2, max_range: float) -> Dictionary:
	var result := {}
	if not _scout_unlocked():
		return result

	if not _backtrack_route_open:
		var anchor_distance := observer_position.distance_to(BACKTRACK_ANCHOR_POSITION)
		if anchor_distance <= max_range:
			result[BACKTRACK_ANCHOR_ID] = {
				"object_id": BACKTRACK_ANCHOR_ID,
				"category": "anchor_resonance",
				"classification": "dormant_geometry_anchor",
				"confidence": 0.96,
				"markable": true,
				"distance": anchor_distance,
				"relative_position": [
					BACKTRACK_ANCHOR_POSITION.x - observer_position.x,
					BACKTRACK_ANCHOR_POSITION.y - observer_position.y
				]
			}

	if _backtrack_route_open and not _backtrack_discovered:
		var vein_distance := observer_position.distance_to(SERVICE_VEIN_POSITION)
		if vein_distance <= max_range:
			result["service_vein_trace"] = {
				"object_id": "service_vein_trace",
				"category": "hidden_route",
				"classification": "geometry_recovered",
				"confidence": 0.94,
				"distance": vein_distance,
				"relative_position": [
					SERVICE_VEIN_POSITION.x - observer_position.x,
					SERVICE_VEIN_POSITION.y - observer_position.y
				]
			}

	if _backtrack_discovered:
		var residue_position := SERVICE_VEIN_POSITION + Vector2(-18.0, -22.0)
		var residue_distance := observer_position.distance_to(residue_position)
		if residue_distance <= max_range:
			result["keyhole_residue_01"] = {
				"object_id": "keyhole_residue_01",
				"category": "causal_residue",
				"classification": "cause_unknown",
				"confidence": 0.71,
				"distance": residue_distance,
				"relative_position": [
					residue_position.x - observer_position.x,
					residue_position.y - observer_position.y
				]
			}

	return result

func apply_scout_mark(target_id: String, observer_position: Vector2) -> Dictionary:
	if target_id != BACKTRACK_ANCHOR_ID:
		return {}

	if not _scout_unlocked():
		return {
			"status": "refused",
			"reason": "scout_form_required",
			"target": target_id
		}

	if _backtrack_route_open:
		return {
			"status": "noop",
			"reason": "route_already_open",
			"target": target_id
		}

	var distance := observer_position.distance_to(BACKTRACK_ANCHOR_POSITION)
	if distance > BACKTRACK_ANCHOR_RANGE:
		return {
			"status": "refused",
			"reason": "anchor_out_of_range",
			"target": target_id,
			"distance": distance
		}

	_backtrack_route_open = true
	_sync_backtrack_geometry()

	var record := {
		"status": "applied",
		"event": "backtrack_route_opened",
		"target": BACKTRACK_ANCHOR_ID,
		"route": SERVICE_VEIN_ID,
		"detail": "Dormant Intake geometry accepted the Scout anchor and reconstructed an upper service route.",
		"distance": distance
	}
	backtrack_route_opened.emit(record.duplicate(true))
	queue_redraw()
	return record

func interact_nearest(actor: Node2D) -> Dictionary:
	if not _active:
		return {"status": "no_target"}

	var gate_distance := actor.global_position.distance_to(BOSS_GATE_POSITION)
	if gate_distance <= BOSS_GATE_RANGE:
		exit_requested.emit("fallen_arena")
		return {
			"status": "world_event",
			"event": "enter_fallen_cistern",
			"detail": "The cistern seal opens.",
			"distance": gate_distance
		}

	if _backtrack_discovered:
		var vein_distance := actor.global_position.distance_to(SERVICE_VEIN_POSITION)
		if vein_distance <= 140.0:
			return {
				"status": "world_event",
				"event": "service_vein_observed",
				"detail": "The passage is older than the visible Intake wall. A keyhole-shaped residue remains with no obvious mechanism.",
				"distance": vein_distance
			}

	return {"status": "no_target", "range": BOSS_GATE_RANGE}

func _build_world_exit() -> void:
	var area := _make_area(
		"AshVillageLift",
		Rect2(3500.0, 470.0, 220.0, 170.0),
		4
	)
	area.body_entered.connect(_on_world_exit_body_entered)

func _build_backtrack_discovery() -> void:
	var area := _make_area(
		"ServiceVeinDiscovery",
		SERVICE_VEIN_DISCOVERY_RECT,
		4
	)
	area.body_entered.connect(_on_backtrack_discovery_body_entered)

func _on_world_exit_body_entered(body: Node) -> void:
	if not _active or body != hunter or _exit_latched:
		return
	_exit_latched = true
	exit_requested.emit("ash_village")

func _on_backtrack_discovery_body_entered(body: Node) -> void:
	if not _active or body != hunter:
		return
	if not _backtrack_route_open or _backtrack_discovered:
		return

	_backtrack_discovered = true
	var record := {
		"status": "observed",
		"event": "backtrack_discovery",
		"subject": SERVICE_VEIN_ID,
		"value": "discovered",
		"confidence": 1.0,
		"detail": "Hunter entered the reconstructed Service Vein above Intake Shaft."
	}
	backtrack_discovery.emit(record.duplicate(true))
	queue_redraw()

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
		hunter.force_respawn(active_checkpoint_position)

	hunter_respawned.emit(active_checkpoint_id)

func _scout_unlocked() -> bool:
	var ledger := get_node_or_null("/root/RealityLedger")
	if ledger == null or not ledger.has_method("has_record"):
		return false
	return ledger.has_record("phi_bot_form", "SCOUT", "verified")

func _restore_backtrack_progress() -> void:
	var ledger := get_node_or_null("/root/RealityLedger")
	if ledger == null or not ledger.has_method("has_record"):
		return

	_backtrack_route_open = ledger.has_record(BACKTRACK_ANCHOR_ID, "route_open", "verified")
	_backtrack_discovered = ledger.has_record(SERVICE_VEIN_ID, "discovered", "evidence")

func _sync_backtrack_geometry() -> void:
	for body in _backtrack_geometry:
		if is_instance_valid(body):
			body.collision_layer = 1 if _backtrack_route_open else 0
	queue_redraw()

func _build_geometry() -> void:
	for index in range(GEOMETRY.size()):
		_make_static_rect("SewerSolid_%02d" % index, GEOMETRY[index])

func _build_backtrack_geometry() -> void:
	for index in range(BACKTRACK_GEOMETRY.size()):
		var body := _make_static_rect("ScoutRoute_%02d" % index, BACKTRACK_GEOMETRY[index])
		_backtrack_geometry.append(body)

func _build_room_triggers() -> void:
	for room in ROOMS:
		var area := _make_area(
			"Room_%s" % room["id"],
			room["bounds"],
			4
		)
		area.body_entered.connect(_on_room_body_entered.bind(room))

func _build_checkpoints() -> void:
	for checkpoint in CHECKPOINTS:
		var area := _make_area(
			"Checkpoint_%s" % checkpoint["id"],
			checkpoint["activation_rect"],
			8
		)
		area.body_entered.connect(_on_checkpoint_body_entered.bind(checkpoint["id"]))
		_checkpoint_areas.append(area)

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
	if body != hunter:
		return
	_enter_room(room)

func _on_checkpoint_body_entered(body: Node, checkpoint_id: String) -> void:
	if body != hunter:
		return
	activate_checkpoint(checkpoint_id)

func _enter_room(room: Dictionary) -> void:
	var room_id := str(room["id"])
	if current_room_id == room_id:
		return

	current_room_id = room_id

	if hunter != null and hunter.has_method("set_camera_bounds"):
		hunter.set_camera_bounds(room["bounds"])

	room_changed.emit(room_id, str(room["title"]))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#07101b"))

	# Room washes make the three camera cells legible without requiring final art.
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.020, 0.045, 0.070, 1.0))
	draw_rect(Rect2(1280.0, 0.0, 1280.0, 720.0), Color(0.025, 0.052, 0.070, 1.0))
	draw_rect(Rect2(2560.0, 0.0, 1280.0, 720.0), Color(0.035, 0.045, 0.067, 1.0))

	# Drain ribs and hanging conduits.
	for x in range(80, 3840, 180):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), 150.0 + float((x * 7) % 90)), Color(0.07, 0.12, 0.16, 1.0), 12.0)

	# Base collision geometry.
	for rect in GEOMETRY:
		draw_rect(rect, Color(0.075, 0.10, 0.13, 1.0))
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.22, 0.34, 0.40, 1.0), 3.0)

	# Scout-gated geometry only exists after the anchor is marked.
	if _backtrack_route_open:
		for rect in BACKTRACK_GEOMETRY:
			draw_rect(rect, Color(0.075, 0.15, 0.19, 1.0))
			draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.37, 0.70, 0.82, 0.95), 3.0)
		draw_arc(BACKTRACK_ANCHOR_POSITION, 23.0, 0.0, TAU, 32, Color(0.45, 0.82, 0.95, 0.85), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(365.0, 130.0), "SERVICE VEIN // UNMAPPED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(0.48, 0.78, 0.88, 0.78))
	elif _scout_unlocked():
		# The human only gets a suspicious seam. Scout's Ping carries the actual anchor signal.
		draw_line(Vector2(1148.0, 392.0), Vector2(1148.0, 452.0), Color(0.13, 0.20, 0.24, 0.75), 2.0)

	if _backtrack_discovered:
		draw_arc(SERVICE_VEIN_POSITION + Vector2(-18.0, -22.0), 10.0, 0.0, TAU, 20, Color(0.54, 0.72, 0.92, 0.55), 1.5)

	# Pit water / failure spaces.
	for pit in [
		Rect2(720.0, 642.0, 180.0, 78.0),
		Rect2(1640.0, 642.0, 200.0, 78.0),
		Rect2(3000.0, 642.0, 210.0, 78.0)
	]:
		draw_rect(pit, Color(0.05, 0.17, 0.22, 1.0))
		for wave_x in range(int(pit.position.x) + 12, int(pit.end.x), 28):
			draw_line(
				Vector2(float(wave_x), pit.position.y + 8.0),
				Vector2(float(wave_x + 14), pit.position.y + 8.0),
				Color(0.22, 0.53, 0.61, 0.8),
				2.0
			)

	# Room labels.
	draw_string(ThemeDB.fallback_font, Vector2(90.0, 250.0), "01 // INTAKE SHAFT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.38, 0.56, 0.66, 0.65))
	draw_string(ThemeDB.fallback_font, Vector2(1390.0, 250.0), "02 // SPILLWAY", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.38, 0.56, 0.66, 0.65))
	draw_string(ThemeDB.fallback_font, Vector2(2680.0, 250.0), "03 // CISTERN APPROACH", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.38, 0.56, 0.66, 0.65))

	# Checkpoints.
	for checkpoint in CHECKPOINTS:
		var p: Vector2 = checkpoint["position"]
		var active := checkpoint["id"] == active_checkpoint_id
		var marker_color := Color(0.38, 0.85, 0.74, 1.0) if active else Color(0.25, 0.43, 0.48, 0.8)
		draw_line(p + Vector2(0.0, 28.0), p + Vector2(0.0, -38.0), marker_color, 4.0)
		draw_circle(p + Vector2(0.0, -45.0), 9.0, marker_color)

	# Boss threshold and village lift.
	draw_line(Vector2(3810.0, 140.0), Vector2(3810.0, 620.0), Color(0.55, 0.20, 0.22, 0.8), 6.0)
	draw_circle(BOSS_GATE_POSITION + Vector2(0.0, -24.0), 18.0, Color(0.50, 0.22, 0.26, 0.9))
	draw_arc(BOSS_GATE_POSITION + Vector2(0.0, -24.0), 29.0, 0.0, TAU, 30, Color(0.72, 0.40, 0.42, 0.85), 3.0)
	draw_string(ThemeDB.fallback_font, BOSS_GATE_POSITION + Vector2(-112.0, -72.0), "R // ENTER FALLEN CISTERN", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.78, 0.49, 0.50, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(3450.0, 190.0), "LIFT // ASH VILLAGE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.46, 0.72, 0.76, 0.9))
