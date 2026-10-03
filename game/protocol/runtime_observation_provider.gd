extends Node
class_name NightCircuitRuntimeObservationProvider

const HUNTER_VISIBLE_RANGE := 620.0
const PHI_VISIBLE_RANGE := 520.0
const PHI_SIGNAL_RANGE := 300.0

var _world: Node
var _hunter: Node2D
var _phi_bot: Node2D
var _registered := false

func bind(world: Node, hunter: Node2D, phi_bot: Node2D) -> void:
	_world = world
	_hunter = hunter
	_phi_bot = phi_bot
	_register()

func set_world(world: Node) -> void:
	_world = world

func _exit_tree() -> void:
	var protocol := get_node_or_null("/root/PlayerProtocol")
	if protocol == null:
		return

	protocol.unregister_observer("hunter", Callable(self, "build_observation"))
	protocol.unregister_observer("phi_bot", Callable(self, "build_observation"))

func build_observation(actor_id: String) -> Dictionary:
	var actor := _actor_for_id(actor_id)
	if actor == null:
		return {}

	var state := {}
	if actor.has_method("actor_snapshot"):
		state = actor.actor_snapshot()

	var capabilities := {}
	if actor.has_method("protocol_capabilities"):
		capabilities = actor.protocol_capabilities()

	return {
		"room": _room_id(),
		"visible_entities": _visible_entities(actor_id, actor),
		"signals": _signals(actor_id, actor),
		"state": state,
		"capabilities": capabilities,
		"metadata": {
			"scope": actor_id,
			"checkpoint": _checkpoint_id(),
			"world_layer": "baseline",
			"world_phase": _world_phase(),
			"world_state": _world_state_snapshot(),
			"reality_ledger": _ledger_summary(),
			"visibility_policy": "actor_scoped"
		}
	}

func _register() -> void:
	if _registered:
		return

	var protocol := get_node_or_null("/root/PlayerProtocol")
	if protocol == null:
		return

	var hunter_ok := protocol.register_observer(
		"hunter",
		Callable(self, "build_observation")
	)
	var phi_ok := protocol.register_observer(
		"phi_bot",
		Callable(self, "build_observation")
	)
	_registered = hunter_ok and phi_ok

func _actor_for_id(actor_id: String) -> Node2D:
	match actor_id:
		"hunter":
			return _hunter
		"phi_bot":
			return _phi_bot
		_:
			return null

func _room_id() -> String:
	if _world != null:
		return str(_world.get("current_room_id"))
	return "unknown"

func _checkpoint_id() -> String:
	if _world != null:
		return str(_world.get("active_checkpoint_id"))
	return "unknown"

func _world_phase() -> String:
	if _world != null and _world.has_method("world_phase"):
		return str(_world.world_phase())
	return "unknown"

func _world_state_snapshot() -> Dictionary:
	if _world != null and _world.has_method("world_state_snapshot"):
		return _world.world_state_snapshot()
	return {}

func _ledger_summary() -> Dictionary:
	var ledger := get_node_or_null("/root/RealityLedger")
	if ledger != null and ledger.has_method("public_summary"):
		return ledger.public_summary()
	return {}

func _visible_entities(actor_id: String, actor: Node2D) -> Array:
	var result: Array = []
	var max_range := HUNTER_VISIBLE_RANGE if actor_id == "hunter" else PHI_VISIBLE_RANGE

	var counterpart: Node2D = _phi_bot if actor_id == "hunter" else _hunter
	if counterpart != null:
		var counterpart_distance := actor.global_position.distance_to(counterpart.global_position)
		if counterpart_distance <= max_range:
			result.append(_entity_record(
				counterpart,
				"phi_bot" if actor_id == "hunter" else "hunter",
				counterpart_distance
			))

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		if not enemy_node.is_visible_in_tree():
			continue
		var distance := actor.global_position.distance_to(enemy_node.global_position)
		if distance > max_range:
			continue
		result.append(_entity_record(enemy_node, "enemy", distance))

	if _world != null and _world.has_method("protocol_entities"):
		for world_entity in _world.protocol_entities(actor.global_position, max_range):
			result.append(world_entity)

	return result

func _signals(actor_id: String, actor: Node2D) -> Dictionary:
	if actor_id != "phi_bot":
		return {}

	var result := {}
	if _world != null and _world.has_method("protocol_signals"):
		var world_signals: Dictionary = _world.protocol_signals(actor.global_position, PHI_SIGNAL_RANGE)
		for signal_id in world_signals:
			result[signal_id] = world_signals[signal_id]

	for candidate in get_tree().get_nodes_in_group("inspectable"):
		if not (candidate is Node2D):
			continue

		var node := candidate as Node2D
		if not node.is_visible_in_tree():
			continue
		var distance := actor.global_position.distance_to(node.global_position)
		if distance > PHI_SIGNAL_RANGE:
			continue

		if node.has_method("protocol_signal"):
			var signal_record: Dictionary = node.protocol_signal(actor.global_position)
			var signal_id := str(signal_record.get("object_id", node.name))
			result[signal_id] = signal_record

	return result

func _entity_record(node: Node2D, kind: String, distance: float) -> Dictionary:
	var record := {
		"id": str(node.name),
		"kind": kind,
		"distance": distance,
		"position": [node.global_position.x, node.global_position.y]
	}

	if node.has_method("actor_snapshot"):
		var snapshot: Dictionary = node.actor_snapshot()
		if snapshot.has("combat"):
			record["combat"] = snapshot["combat"]
		if snapshot.has("mode"):
			record["mode"] = snapshot["mode"]
		if snapshot.has("health"):
			record["health"] = snapshot["health"]
		if snapshot.has("max_health"):
			record["max_health"] = snapshot["max_health"]
		if snapshot.has("boss_phase"):
			record["boss_phase"] = snapshot["boss_phase"]
		if snapshot.has("attack"):
			record["attack"] = snapshot["attack"]
		if snapshot.has("physical_source"):
			record["physical_source"] = snapshot["physical_source"]

	return record
