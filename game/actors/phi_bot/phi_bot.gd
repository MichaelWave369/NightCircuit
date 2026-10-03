extends CharacterBody2D
class_name NightCircuitPhiBot

signal state_changed(snapshot: Dictionary)
signal inspect_result(result: Dictionary)

const ACTOR_ID := "phi_bot"
const FORM_BROKEN := "BROKEN"

const FOLLOW_OFFSET := Vector2(78.0, -58.0)
const FOLLOW_SPEED := 360.0
const FOLLOW_ACCELERATION := 1100.0
const SNAP_DISTANCE := 720.0

const MAX_ENERGY := 100.0
const LIGHT_DRAIN_PER_SECOND := 8.0
const PASSIVE_RECHARGE_PER_SECOND := 5.0
const INSPECT_COST := 10.0
const INSPECT_RANGE := 190.0

var form_id := FORM_BROKEN
var energy := MAX_ENERGY
var control_source := "system"

var _hunter: Node2D
var _mode := "FOLLOW"
var _light_enabled := false
var _bob_time := 0.0
var _last_inspection: Dictionary = {}

func _ready() -> void:
	var bus := get_node_or_null("/root/ActionBus")
	if bus != null:
		bus.register_actor(ACTOR_ID, Callable(self, "execute_action"))

	_hunter = get_tree().get_first_node_in_group("hunter")
	queue_redraw()
	_emit_state()

func _exit_tree() -> void:
	var bus := get_node_or_null("/root/ActionBus")
	if bus != null:
		bus.unregister_actor(ACTOR_ID, Callable(self, "execute_action"))

func execute_action(action: Dictionary) -> Dictionary:
	if str(action.get("actor", "")).to_lower() != ACTOR_ID:
		return _effect("refused", "actor_mismatch")

	control_source = str(action.get("source", control_source)).to_lower()
	var action_name := str(action.get("action", "")).to_upper()
	var payload = action.get("payload", {})
	if not (payload is Dictionary):
		return _effect("failed", "payload_not_dictionary")

	match action_name:
		"FOLLOW":
			_mode = "FOLLOW"
			_emit_state()
			return _effect("applied", "follow_enabled", {"mode": _mode})
		"HOLD":
			_mode = "HOLD"
			velocity = Vector2.ZERO
			_emit_state()
			return _effect("applied", "hold_enabled", {"mode": _mode})
		"LIGHT":
			return _execute_light(payload)
		"INSPECT":
			return _execute_inspect(payload)
		"MOVE":
			return _execute_move(payload)
		"PING", "SCAN", "MARK":
			return _effect("refused", "ability_unavailable_in_broken_form", {"form": form_id})
		"INTERACT":
			return _effect("refused", "interact_not_implemented")
		_:
			return _effect("refused", "action_not_implemented")

func _effect(status: String, reason: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"status": status,
		"reason": reason,
		"effect": detail
	}

func bind_hunter(target: Node2D) -> void:
	_hunter = target
	if _hunter != null and global_position.distance_to(_hunter.global_position) > SNAP_DISTANCE:
		reset_near_hunter()

func reset_near_hunter() -> void:
	if _hunter == null:
		return

	global_position = _hunter.global_position + FOLLOW_OFFSET
	velocity = Vector2.ZERO
	reset_physics_interpolation()
	_emit_state()

func _physics_process(delta: float) -> void:
	_bob_time += delta
	_tick_energy(delta)

	if _mode == "FOLLOW":
		_tick_follow(delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FOLLOW_ACCELERATION * delta)

	move_and_slide()
	queue_redraw()

func _tick_follow(delta: float) -> void:
	if _hunter == null or not is_instance_valid(_hunter):
		_hunter = get_tree().get_first_node_in_group("hunter")
		if _hunter == null:
			velocity = velocity.move_toward(Vector2.ZERO, FOLLOW_ACCELERATION * delta)
			return

	var target := _hunter.global_position + FOLLOW_OFFSET

	if _hunter.has_method("actor_snapshot"):
		var hunter_snapshot: Dictionary = _hunter.actor_snapshot()
		var facing := int(hunter_snapshot.get("facing", 1))
		target.x = _hunter.global_position.x - FOLLOW_OFFSET.x * float(facing)

	target.y += sin(_bob_time * 2.2) * 7.0

	var distance := global_position.distance_to(target)
	if distance > SNAP_DISTANCE:
		global_position = target
		velocity = Vector2.ZERO
		reset_physics_interpolation()
		return

	var desired_velocity := global_position.direction_to(target) * minf(FOLLOW_SPEED, distance * 4.0)
	velocity = velocity.move_toward(desired_velocity, FOLLOW_ACCELERATION * delta)

func _tick_energy(delta: float) -> void:
	var previous_energy := energy
	var previous_light := _light_enabled

	if _light_enabled:
		energy = maxf(0.0, energy - LIGHT_DRAIN_PER_SECOND * delta)
		if energy <= 0.0:
			_light_enabled = false
	else:
		energy = minf(MAX_ENERGY, energy + PASSIVE_RECHARGE_PER_SECOND * delta)

	if not is_equal_approx(previous_energy, energy) or previous_light != _light_enabled:
		_emit_state()

func _execute_light(payload: Dictionary) -> Dictionary:
	var requested := not _light_enabled

	if payload.has("enabled"):
		requested = bool(payload["enabled"])
	elif payload.has("toggle") and bool(payload["toggle"]):
		requested = not _light_enabled

	if requested and energy <= 0.0:
		_light_enabled = false
		_emit_state()
		return _effect("refused", "insufficient_energy", {"energy": energy})

	_light_enabled = requested
	_emit_state()
	return _effect(
		"applied",
		"light_state_updated",
		{
			"enabled": _light_enabled,
			"energy": energy
		}
	)

func _execute_inspect(payload: Dictionary) -> Dictionary:
	var result := _inspect(payload)
	var status := str(result.get("status", "unknown"))

	if status == "observed":
		return _effect("applied", "inspection_completed", {"inspection": result})

	if status == "no_target":
		return _effect("noop", "no_inspectable_in_range", {"inspection": result})

	if status == "insufficient_energy":
		return _effect("refused", "insufficient_energy", {"inspection": result})

	return _effect("failed", "inspection_failed", {"inspection": result})

func _inspect(payload: Dictionary) -> Dictionary:
	if energy < INSPECT_COST:
		_last_inspection = {
			"status": "insufficient_energy",
			"required": INSPECT_COST,
			"energy": energy
		}
		inspect_result.emit(_last_inspection.duplicate(true))
		_emit_state()
		return _last_inspection.duplicate(true)

	var requested_id := str(payload.get("target", ""))
	var best: Node2D = null
	var best_distance := INF

	for candidate in get_tree().get_nodes_in_group("inspectable"):
		if not (candidate is Node2D):
			continue

		var node := candidate as Node2D
		if requested_id != "" and node.has_method("inspection_id") and str(node.inspection_id()) != requested_id:
			continue

		var distance := global_position.distance_to(node.global_position)
		if distance <= INSPECT_RANGE and distance < best_distance:
			best = node
			best_distance = distance

	energy = maxf(0.0, energy - INSPECT_COST)

	if best == null:
		_last_inspection = {
			"status": "no_target",
			"range": INSPECT_RANGE,
			"energy": energy
		}
	else:
		var record: Dictionary = {}
		if best.has_method("inspection_record"):
			record = best.inspection_record()
		record["status"] = "observed"
		record["distance"] = best_distance
		record["observer"] = ACTOR_ID
		record["energy"] = energy
		_last_inspection = record

	inspect_result.emit(_last_inspection.duplicate(true))
	_emit_state()
	return _last_inspection.duplicate(true)

func _execute_move(payload: Dictionary) -> Dictionary:
	_mode = "HOLD"
	var target := Vector2(float(payload["x"]), float(payload["y"]))
	var offset := target - global_position

	if offset.length() > 120.0:
		offset = offset.normalized() * 120.0

	velocity = offset * 3.0
	_emit_state()

	return _effect(
		"applied",
		"move_vector_applied",
		{
			"mode": _mode,
			"target": [target.x, target.y],
			"velocity": [velocity.x, velocity.y]
		}
	)

func actor_snapshot() -> Dictionary:
	return {
		"actor": ACTOR_ID,
		"position": [global_position.x, global_position.y],
		"velocity": [velocity.x, velocity.y],
		"form": form_id,
		"mode": _mode,
		"energy": energy,
		"max_energy": MAX_ENERGY,
		"light_enabled": _light_enabled,
		"inspect_range": INSPECT_RANGE,
		"last_inspection": _last_inspection.duplicate(true),
		"control_source": control_source
	}

func _emit_state() -> void:
	state_changed.emit(actor_snapshot())
	queue_redraw()

func _draw() -> void:
	var shell := Color(0.43, 0.82, 0.93, 1.0)
	var core := Color(0.84, 0.96, 1.0, 1.0)
	var dim_shell := Color(0.27, 0.45, 0.53, 1.0)

	if energy <= 10.0:
		shell = dim_shell

	if _light_enabled:
		draw_circle(Vector2.ZERO, 92.0, Color(0.25, 0.62, 0.72, 0.08))
		draw_circle(Vector2.ZERO, 58.0, Color(0.34, 0.74, 0.82, 0.10))
		draw_arc(Vector2.ZERO, 92.0, 0.0, TAU, 64, Color(0.42, 0.82, 0.90, 0.18), 2.0)

	draw_circle(Vector2.ZERO, 18.0, Color(0.13, 0.22, 0.27, 1.0))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 40, shell, 3.0)
	draw_arc(Vector2.ZERO, 11.0, -1.15, 1.15, 24, shell, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-8.0, 7.0),
		"Φ",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		21,
		core
	)

	if _mode == "HOLD":
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 28, Color(0.84, 0.68, 0.36, 0.75), 2.0)
