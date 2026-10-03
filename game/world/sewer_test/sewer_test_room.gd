extends Node2D
class_name NightCircuitSewerTestRoom

signal room_changed(room_id: String, room_title: String)
signal checkpoint_changed(checkpoint_id: String)
signal hunter_respawned(checkpoint_id: String)

const WORLD_SIZE := Vector2(3840.0, 720.0)
const KILL_Y := 820.0

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

func _ready() -> void:
	_build_geometry()
	_build_room_triggers()
	_build_checkpoints()
	queue_redraw()

func bind_hunter(target: Node2D) -> void:
	hunter = target
	activate_checkpoint("drain_entry", true)
	_enter_room(ROOMS[0])
	if hunter != null and hunter.has_method("force_respawn"):
		hunter.force_respawn(active_checkpoint_position)

func _physics_process(_delta: float) -> void:
	if hunter == null:
		return

	if hunter.global_position.y > KILL_Y:
		respawn_hunter()

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

func _build_geometry() -> void:
	for index in range(GEOMETRY.size()):
		_make_static_rect("SewerSolid_%02d" % index, GEOMETRY[index])

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

	# Collision geometry.
	for rect in GEOMETRY:
		draw_rect(rect, Color(0.075, 0.10, 0.13, 1.0))
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.22, 0.34, 0.40, 1.0), 3.0)

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

	# Room labels, only greybox signage for now.
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

	# Future boss boundary.
	draw_line(Vector2(3810.0, 140.0), Vector2(3810.0, 620.0), Color(0.55, 0.20, 0.22, 0.8), 6.0)
	draw_string(ThemeDB.fallback_font, Vector2(3585.0, 125.0), "THE FALLEN // LOCKED UNTIL NC-012", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.68, 0.37, 0.39, 0.9))
