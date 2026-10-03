extends CharacterBody2D
class_name NightCircuitPhiBot

signal state_changed(snapshot: Dictionary)
signal inspect_result(result: Dictionary)
signal scout_result(result: Dictionary)
signal form_changed(previous_form: String, current_form: String)

const ACTOR_ID := "phi_bot"
const FORM_BROKEN := "BROKEN"
const FORM_SCOUT := "SCOUT"

const FOLLOW_OFFSET := Vector2(78.0, -58.0)
const FOLLOW_SPEED := 360.0
const FOLLOW_ACCELERATION := 1100.0
const SNAP_DISTANCE := 720.0

const MAX_ENERGY := 100.0
const LIGHT_DRAIN_PER_SECOND := 8.0
const PASSIVE_RECHARGE_PER_SECOND := 5.0
const INSPECT_COST := 10.0
const INSPECT_RANGE := 190.0

const PING_COST := 12.0
const PING_RANGE := 360.0
const MARK_COST := 8.0
const SCAN_COST := 10.0
const ENEMY_READ_RANGE := 430.0

var form_id := FORM_BROKEN
var energy := MAX_ENERGY
var control_source := "system"

var _hunter: Node2D
var _world: Node
var _mode := "FOLLOW"
var _light_enabled := false
var _bob_time := 0.0
var _last_inspection: Dictionary = {}
var _last_ping: Dictionary = {}
var _last_scout_result: Dictionary = {}
var _marked_target := ""
var _marked_world_position := Vector2.ZERO
var _has_marked_position := false

func _ready() -> void:
	var bus := get_node_or_null("/root/ActionBus")
	if bus != null:
		bus.register_actor(ACTOR_ID, Callable(self, "execute_action"))

	_hunter = get_tree().get_first_node_in_group("hunter")
	_restore_form_from_ledger()
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
		"PING":
			return _execute_ping(payload)
		"SCAN":
			return _execute_scan(payload)
		"MARK":
			return _execute_mark(payload)
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

func bind_world(world: Node) -> void:
	_world = world
	_last_ping = {}
	_marked_target = ""
	_has_marked_position = false
	_emit_state()

func install_scout_core(core_record: Dictionary = {}) -> bool:
	if form_id == FORM_SCOUT:
		return false

	var previous := form_id
	form_id = FORM_SCOUT
	energy = MAX_ENERGY
	_last_ping = {}
	_marked_target = ""
	_has_marked_position = false
	_last_scout_result = {
		"status": "installed",
		"ability": "SCOUT_CORE",
		"compatibility": float(core_record.get("compatibility", 0.97)),
		"abilities": [
			"RESONANCE_PING",
			"ANCHOR_MARK",
			"ENEMY_READ",
			"CONTRADICTION_SENSE"
		]
	}
	form_changed.emit(previous, form_id)
	scout_result.emit(_last_scout_result.duplicate(true))
	_emit_state()
	return true

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
		if not node.is_visible_in_tree():
			continue
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

func _execute_ping(_payload: Dictionary) -> Dictionary:
	if form_id != FORM_SCOUT:
		return _scout_unavailable()
	if energy < PING_COST:
		return _effect("refused", "insufficient_energy", {"required": PING_COST, "energy": energy})

	energy = maxf(0.0, energy - PING_COST)
	var signals := _collect_ping_signals()
	_last_ping = {
		"status": "observed",
		"ability": "RESONANCE_PING",
		"range": PING_RANGE,
		"signal_count": signals.size(),
		"signals": signals,
		"origin": [global_position.x, global_position.y],
		"energy": energy
	}
	_last_scout_result = _last_ping.duplicate(true)
	scout_result.emit(_last_scout_result.duplicate(true))
	_emit_state()

	return _effect("applied", "resonance_ping_completed", {"ping": _last_ping.duplicate(true)})

func _collect_ping_signals() -> Dictionary:
	var result := {}

	if _world != null and _world.has_method("protocol_signals"):
		var world_signals: Dictionary = _world.protocol_signals(global_position, PING_RANGE)
		for signal_id in world_signals:
			result[signal_id] = world_signals[signal_id]

	for candidate in get_tree().get_nodes_in_group("inspectable"):
		if not (candidate is Node2D):
			continue
		var node := candidate as Node2D
		if not node.is_visible_in_tree():
			continue
		var distance := global_position.distance_to(node.global_position)
		if distance > PING_RANGE:
			continue
		if node.has_method("protocol_signal"):
			var signal_record: Dictionary = node.protocol_signal(global_position)
			var signal_id := str(signal_record.get("object_id", node.name))
			result[signal_id] = signal_record

	return result

func _execute_mark(payload: Dictionary) -> Dictionary:
	if form_id != FORM_SCOUT:
		return _scout_unavailable()
	if energy < MARK_COST:
		return _effect("refused", "insufficient_energy", {"required": MARK_COST, "energy": energy})

	var signals = _last_ping.get("signals", {})
	if not (signals is Dictionary) or signals.is_empty():
		return _effect("noop", "no_ping_signal_to_mark")

	var requested_id := str(payload.get("target", "")).strip_edges()
	var target_id := requested_id
	var target_record: Dictionary = {}

	if not requested_id.is_empty() and signals.has(requested_id):
		var selected = signals[requested_id]
		if selected is Dictionary:
			target_record = selected
	else:
		var nearest_distance := INF
		for signal_id in signals:
			var candidate = signals[signal_id]
			if not (candidate is Dictionary):
				continue
			var distance := float(candidate.get("distance", INF))
			if distance < nearest_distance:
				nearest_distance = distance
				target_id = str(signal_id)
				target_record = candidate

	if target_id.is_empty() or target_record.is_empty():
		return _effect("noop", "mark_target_not_found")

	energy = maxf(0.0, energy - MARK_COST)
	_marked_target = target_id
	_has_marked_position = false

	var relative = target_record.get("relative_position", [])
	var ping_origin = _last_ping.get("origin", [global_position.x, global_position.y])
	if relative is Array and relative.size() == 2 and ping_origin is Array and ping_origin.size() == 2:
		_marked_world_position = Vector2(float(ping_origin[0]), float(ping_origin[1])) + Vector2(
			float(relative[0]),
			float(relative[1])
		)
		_has_marked_position = true

	_last_scout_result = {
		"status": "marked",
		"ability": "ANCHOR_MARK",
		"target": _marked_target,
		"category": target_record.get("category", "unknown"),
		"confidence": target_record.get("confidence", 0.0),
		"energy": energy
	}

	if _world != null and _world.has_method("apply_scout_mark"):
		var world_effect: Dictionary = _world.apply_scout_mark(_marked_target, global_position)
		if not world_effect.is_empty():
			_last_scout_result["world_effect"] = world_effect
			if str(world_effect.get("status", "")) == "applied":
				_last_scout_result["status"] = "applied"
				_last_scout_result["world_event"] = world_effect.get("event", "")

	scout_result.emit(_last_scout_result.duplicate(true))
	_emit_state()

	return _effect("applied", "anchor_mark_locked", {"mark": _last_scout_result.duplicate(true)})

func _execute_scan(payload: Dictionary) -> Dictionary:
	if form_id != FORM_SCOUT:
		return _scout_unavailable()
	if energy < SCAN_COST:
		return _effect("refused", "insufficient_energy", {"required": SCAN_COST, "energy": energy})

	var mode := str(payload.get("mode", "enemy_read")).to_lower().strip_edges()
	var result: Dictionary

	match mode:
		"enemy_read":
			result = _enemy_read()
		"contradiction":
			result = _contradiction_read()
		_:
			return _effect("refused", "unsupported_scan_mode", {"mode": mode})

	if str(result.get("status", "")) == "no_target":
		return _effect("noop", "scan_no_target", {"scan": result})

	energy = maxf(0.0, energy - SCAN_COST)
	result["energy"] = energy
	_last_scout_result = result.duplicate(true)
	scout_result.emit(_last_scout_result.duplicate(true))
	_emit_state()

	return _effect("applied", "scout_scan_completed", {"scan": result})

func _enemy_read() -> Dictionary:
	var nearest: Node2D = null
	var nearest_distance := INF

	for candidate in get_tree().get_nodes_in_group("enemy"):
		if not (candidate is Node2D):
			continue
		var enemy := candidate as Node2D
		if not enemy.is_visible_in_tree():
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= ENEMY_READ_RANGE and distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance

	if nearest == null:
		return {
			"status": "no_target",
			"ability": "ENEMY_READ",
			"range": ENEMY_READ_RANGE
		}

	var snapshot := {}
	if nearest.has_method("actor_snapshot"):
		snapshot = nearest.actor_snapshot()

	var health := int(snapshot.get("health", -1))
	var max_health := int(snapshot.get("max_health", -1))
	var health_ratio := -1.0
	if health >= 0 and max_health > 0:
		health_ratio = float(health) / float(max_health)

	return {
		"status": "observed",
		"ability": "ENEMY_READ",
		"target": str(nearest.name),
		"distance": nearest_distance,
		"classification": "boss" if bool(snapshot.get("boss", false)) else "hostile",
		"combat": snapshot.get("combat", "unknown"),
		"attack": snapshot.get("attack", ""),
		"boss_phase": snapshot.get("boss_phase", 0),
		"health_ratio": health_ratio,
		"confidence": 0.91
	}

func _contradiction_read() -> Dictionary:
	var ledger := get_node_or_null("/root/RealityLedger")
	if ledger == null or not ledger.has_method("contradiction_sense"):
		return {
			"status": "no_target",
			"ability": "CONTRADICTION_SENSE",
			"reason": "ledger_unavailable"
		}

	var contradictions: Array = ledger.contradiction_sense(6)
	if contradictions.is_empty():
		return {
			"status": "no_target",
			"ability": "CONTRADICTION_SENSE",
			"contradictions": []
		}

	return {
		"status": "observed",
		"ability": "CONTRADICTION_SENSE",
		"contradiction_count": contradictions.size(),
		"contradictions": contradictions,
		"confidence": 1.0
	}

func _scout_unavailable() -> Dictionary:
	return _effect("refused", "ability_unavailable_in_broken_form", {"form": form_id})

func _restore_form_from_ledger() -> void:
	var ledger := get_node_or_null("/root/RealityLedger")
	if ledger == null or not ledger.has_method("has_record"):
		return

	if ledger.has_record("phi_bot_form", FORM_SCOUT, "verified"):
		form_id = FORM_SCOUT

func _contradiction_snapshot() -> Array:
	if form_id != FORM_SCOUT:
		return []

	var ledger := get_node_or_null("/root/RealityLedger")
	if ledger != null and ledger.has_method("contradiction_sense"):
		return ledger.contradiction_sense(3)
	return []

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
		"last_ping": _last_ping.duplicate(true),
		"last_scout_result": _last_scout_result.duplicate(true),
		"marked_target": _marked_target,
		"contradiction_sense": _contradiction_snapshot(),
		"control_source": control_source
	}

func _emit_state() -> void:
	state_changed.emit(actor_snapshot())
	queue_redraw()

func protocol_capabilities() -> Dictionary:
	var scout := form_id == FORM_SCOUT
	return {
		"FOLLOW": {"available": true},
		"HOLD": {"available": true},
		"MOVE": {"available": true},
		"LIGHT": {
			"available": _light_enabled or energy > 0.0,
			"reason": "" if _light_enabled or energy > 0.0 else "insufficient_energy"
		},
		"INSPECT": {
			"available": energy >= INSPECT_COST,
			"reason": "" if energy >= INSPECT_COST else "insufficient_energy"
		},
		"PING": {
			"available": scout and energy >= PING_COST,
			"reason": "" if scout and energy >= PING_COST else _scout_capability_reason(PING_COST)
		},
		"SCAN": {
			"available": scout and energy >= SCAN_COST,
			"reason": "" if scout and energy >= SCAN_COST else _scout_capability_reason(SCAN_COST),
			"modes": ["enemy_read", "contradiction"]
		},
		"MARK": {
			"available": scout and energy >= MARK_COST and _has_ping_signals(),
			"reason": "" if scout and energy >= MARK_COST and _has_ping_signals() else _mark_capability_reason()
		},
		"INTERACT": {"available": false, "reason": "not_implemented"}
	}

func _scout_capability_reason(cost: float) -> String:
	if form_id != FORM_SCOUT:
		return "ability_unavailable_in_broken_form"
	if energy < cost:
		return "insufficient_energy"
	return ""

func _has_ping_signals() -> bool:
	var signals = _last_ping.get("signals", {})
	return signals is Dictionary and not signals.is_empty()

func _mark_capability_reason() -> String:
	if form_id != FORM_SCOUT:
		return "ability_unavailable_in_broken_form"
	if energy < MARK_COST:
		return "insufficient_energy"
	if not _has_ping_signals():
		return "ping_required"
	return ""

func _draw() -> void:
	var shell := Color(0.43, 0.82, 0.93, 1.0)
	var core := Color(0.84, 0.96, 1.0, 1.0)
	var dim_shell := Color(0.27, 0.45, 0.53, 1.0)

	if form_id == FORM_SCOUT:
		shell = Color(0.53, 0.88, 0.98, 1.0)
		core = Color(0.93, 0.99, 1.0, 1.0)

	if energy <= 10.0:
		shell = dim_shell

	if _light_enabled:
		draw_circle(Vector2.ZERO, 92.0, Color(0.25, 0.62, 0.72, 0.08))
		draw_circle(Vector2.ZERO, 58.0, Color(0.34, 0.74, 0.82, 0.10))
		draw_arc(Vector2.ZERO, 92.0, 0.0, TAU, 64, Color(0.42, 0.82, 0.90, 0.18), 2.0)

	if form_id == FORM_SCOUT:
		draw_arc(Vector2.ZERO, 28.0, _bob_time * 0.8, _bob_time * 0.8 + PI * 1.35, 32, shell, 2.0)
		draw_arc(Vector2.ZERO, 34.0, -_bob_time * 0.55, -_bob_time * 0.55 + PI * 1.10, 32, Color(0.44, 0.68, 0.94, 0.85), 2.0)
		draw_line(Vector2(-7.0, -19.0), Vector2(-14.0, -34.0), shell, 2.0)
		draw_line(Vector2(7.0, -19.0), Vector2(14.0, -34.0), shell, 2.0)
		draw_circle(Vector2(-14.0, -35.0), 2.5, core)
		draw_circle(Vector2(14.0, -35.0), 2.5, core)

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

	if form_id == FORM_SCOUT and _has_marked_position:
		var local_mark := to_local(_marked_world_position)
		if local_mark.length() <= 520.0:
			draw_line(Vector2.ZERO, local_mark, Color(0.45, 0.76, 0.95, 0.42), 1.5)
			draw_arc(local_mark, 13.0, 0.0, TAU, 24, Color(0.48, 0.82, 1.0, 0.85), 2.0)
