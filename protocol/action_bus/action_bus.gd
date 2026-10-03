extends Node

signal action_received(action: Dictionary)
signal decision_recorded(action: Dictionary, receipt: Dictionary)
signal effect_recorded(action: Dictionary, receipt: Dictionary)
signal action_accepted(action: Dictionary, receipt: Dictionary)
signal action_rejected(action: Dictionary, receipt: Dictionary)

const ActionContract = preload("res://protocol/actions/action_contract.gd")

var _sequence := 0
var _actor_executors: Dictionary = {}
var _seen_request_ids: Dictionary = {}

func _ready() -> void:
	register_actor("system", Callable(self, "_execute_system_action"))

func register_actor(actor_id: String, executor: Callable) -> bool:
	var normalized_id := actor_id.to_lower().strip_edges()
	if normalized_id.is_empty() or not executor.is_valid():
		return false

	_actor_executors[normalized_id] = executor
	return true

func unregister_actor(actor_id: String, executor: Callable = Callable()) -> void:
	var normalized_id := actor_id.to_lower().strip_edges()
	if not _actor_executors.has(normalized_id):
		return

	if executor.is_valid() and _actor_executors[normalized_id] != executor:
		return

	_actor_executors.erase(normalized_id)

func submit(raw_action: Dictionary) -> Dictionary:
	_sequence += 1
	var action := ActionContract.normalize(raw_action, _sequence)
	action_received.emit(action.duplicate(true))

	var shape := ActionContract.validate(action)
	var decision := _decision_receipt(
		action,
		bool(shape.get("valid", false)),
		str(shape.get("reason", "invalid_action"))
	)

	if decision["accepted"]:
		var duplicate := _duplicate_request(action)
		if duplicate["duplicate"]:
			decision["accepted"] = false
			decision["reason"] = "duplicate_request_id"
			decision["duplicate_of"] = duplicate["action_id"]

	if decision["accepted"]:
		var gate := get_node_or_null("/root/AuthorityGate")
		var authority := {
			"accepted": false,
			"reason": "authority_gate_unavailable"
		}
		if gate != null:
			authority = gate.evaluate(action)

		decision["accepted"] = bool(authority.get("accepted", false))
		decision["reason"] = str(authority.get("reason", "unspecified"))

		if decision["accepted"]:
			_remember_request(action)

	_append_receipt(decision)
	decision_recorded.emit(action.duplicate(true), decision.duplicate(true))

	if not decision["accepted"]:
		action_rejected.emit(action.duplicate(true), decision.duplicate(true))
		return decision

	action_accepted.emit(action.duplicate(true), decision.duplicate(true))

	var effect := _dispatch(action)
	_append_receipt(effect)
	effect_recorded.emit(action.duplicate(true), effect.duplicate(true))

	# Preserve the convenient NC-001 return shape while exposing the new effect.
	decision["effect_status"] = effect["status"]
	decision["effect_reason"] = effect["reason"]
	decision["effect"] = effect["effect"].duplicate(true)
	return decision

func submit_replay_entry(entry: Dictionary) -> Dictionary:
	return submit({
		"source": "replay",
		"actor": entry.get("actor", "unknown"),
		"action": entry.get("action", "UNKNOWN"),
		"payload": entry.get("payload", {}),
		"replay_of": entry.get("replay_of", entry.get("action_id", ""))
	})

func registered_actors() -> Array:
	var actors := _actor_executors.keys()
	actors.sort()
	return actors

func _dispatch(action: Dictionary) -> Dictionary:
	var actor_id := str(action["actor"])

	if not _actor_executors.has(actor_id):
		return _effect_receipt(
			action,
			ActionContract.effect("failed", "actor_executor_unavailable")
		)

	var executor: Callable = _actor_executors[actor_id]
	if not executor.is_valid():
		return _effect_receipt(
			action,
			ActionContract.effect("failed", "actor_executor_invalid")
		)

	var raw_result = executor.call(action.duplicate(true))
	if not (raw_result is Dictionary):
		return _effect_receipt(
			action,
			ActionContract.effect("failed", "actor_effect_must_be_dictionary")
		)

	return _effect_receipt(
		action,
		ActionContract.validate_effect_result(raw_result)
	)

func _decision_receipt(action: Dictionary, accepted: bool, reason: String) -> Dictionary:
	return {
		"schema": ActionContract.DECISION_RECEIPT_SCHEMA,
		"receipt_type": "decision",
		"action_id": action["action_id"],
		"sequence": action["sequence"],
		"accepted": accepted,
		"reason": reason,
		"source": action["source"],
		"actor": action["actor"],
		"action": action["action"],
		"payload": action["payload"].duplicate(true) if action["payload"] is Dictionary else action["payload"],
		"request_id": action["request_id"],
		"replay_of": action["replay_of"],
		"physics_frame": Engine.get_physics_frames(),
		"unix_time": int(Time.get_unix_time_from_system())
	}

func _effect_receipt(action: Dictionary, result: Dictionary) -> Dictionary:
	return {
		"schema": ActionContract.EFFECT_RECEIPT_SCHEMA,
		"receipt_type": "effect",
		"action_id": action["action_id"],
		"sequence": action["sequence"],
		"source": action["source"],
		"actor": action["actor"],
		"action": action["action"],
		"status": result["status"],
		"reason": result["reason"],
		"effect": result["effect"].duplicate(true),
		"physics_frame": Engine.get_physics_frames(),
		"unix_time": int(Time.get_unix_time_from_system())
	}

func _append_receipt(receipt: Dictionary) -> void:
	var ledger := get_node_or_null("/root/ReceiptLedger")
	if ledger != null:
		ledger.append_receipt(receipt)

func _duplicate_request(action: Dictionary) -> Dictionary:
	var request_id := str(action.get("request_id", ""))
	if request_id.is_empty():
		return {
			"duplicate": false,
			"action_id": ""
		}

	var key := "%s|%s" % [action["source"], request_id]
	if not _seen_request_ids.has(key):
		return {
			"duplicate": false,
			"action_id": ""
		}

	return {
		"duplicate": true,
		"action_id": str(_seen_request_ids[key])
	}

func _remember_request(action: Dictionary) -> void:
	var request_id := str(action.get("request_id", ""))
	if request_id.is_empty():
		return

	var key := "%s|%s" % [action["source"], request_id]
	_seen_request_ids[key] = action["action_id"]

func _execute_system_action(action: Dictionary) -> Dictionary:
	return ActionContract.effect(
		"applied",
		"system_action_recorded",
		{
			"payload": action["payload"].duplicate(true)
		}
	)
