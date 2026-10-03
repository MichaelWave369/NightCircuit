extends Node

# PixelForge Runtime Bridge v1 adapter for the live Godot runtime.
#
# Night Circuit is engine-clocked, not externally stepped like Oak Street Rumble.
# advance() therefore flushes one queued controller batch through the authoritative
# PlayerProtocol/ActionBus boundary. Godot continues to own physics advancement.

const BRIDGE_PROTOCOL := "pixelforge-runtime-bridge"
const BRIDGE_VERSION := 1
const RUNTIME_VERSION := "night-circuit/godot-0.18"

const CONTROLLER_KINDS := [
	"human",
	"gamepad",
	"bot",
	"model",
	"agent",
	"remote",
	"network",
	"replay",
	"script"
]

var _bridge_tick := 0
var _event_sequence := 0
var _controllers: Dictionary = {}
var _grants: Dictionary = {}
var _pending: Array = []
var _events: Array = []
var _frames: Array = []

func _ready() -> void:
	_bootstrap_human_seat()

func describe() -> Dictionary:
	return {
		"protocol": BRIDGE_PROTOCOL,
		"version": BRIDGE_VERSION,
		"gameId": "phi-night-circuit",
		"runtimeVersion": RUNTIME_VERSION,
		"deterministic": false,
		"clockMode": "engine",
		"advanceSemantics": "flush-controller-batch",
		"replayExact": false,
		"playerProtocol": "phi-player-protocol/0.3"
	}

func registerController(descriptor: Dictionary) -> Dictionary:
	if not _valid_controller_descriptor(descriptor):
		return {
			"ok": false,
			"reason": "invalid_controller_descriptor"
		}

	var controller_id := str(descriptor.get("id", "")).strip_edges()
	if _controllers.has(controller_id):
		return {
			"ok": false,
			"reason": "controller_already_registered"
		}

	var actor_id := str(descriptor.get("actor", "hunter")).to_lower().strip_edges()
	_controllers[controller_id] = {
		"id": controller_id,
		"kind": str(descriptor.get("kind", "")).to_lower(),
		"actor": actor_id,
		"profile": str(descriptor.get("profile", "actor_scoped")),
		"builtin": false
	}
	_grants[controller_id] = {}

	return {"ok": true}

func observe(controller_id: String, actor_id: String = "") -> Dictionary:
	if not _controllers.has(controller_id):
		return {
			"ok": false,
			"reason": "controller_not_registered"
		}

	var descriptor: Dictionary = _controllers[controller_id]
	var bound_actor := str(descriptor.get("actor", "hunter"))
	var requested_actor := actor_id.to_lower().strip_edges()
	if requested_actor.is_empty():
		requested_actor = bound_actor
	if requested_actor != bound_actor:
		return {
			"ok": false,
			"reason": "observation_outside_binding"
		}

	var protocol := get_node_or_null("/root/PlayerProtocol")
	if protocol == null or not protocol.has_method("handle_adapter_message"):
		return {
			"ok": false,
			"reason": "player_protocol_unavailable"
		}

	var source := _source_for_kind(str(descriptor.get("kind", "")))
	var response: Dictionary = protocol.handle_adapter_message(source, {
		"type": "observe",
		"actor": requested_actor,
		"request_id": "pf-observe-%s-%08d" % [controller_id, _bridge_tick]
	})

	if not bool(response.get("ok", false)):
		return {
			"ok": false,
			"reason": str(response.get("error", "observation_failed"))
		}

	var body: Dictionary = response.get("body", {})
	var observation: Dictionary = body.get("observation", {}).duplicate(true)
	observation["bridge"] = {
		"protocol": BRIDGE_PROTOCOL,
		"version": BRIDGE_VERSION,
		"controller_id": controller_id,
		"allowed_actions": _actions_for(controller_id, requested_actor),
		"clock_mode": "engine",
		"bridge_tick": _bridge_tick
	}
	return observation

func submit(controller_id: String, intent: Dictionary, tick: int = -1) -> Dictionary:
	var root_tick := _bridge_tick if tick < 0 else tick
	_pending.append({
		"controller_id": controller_id,
		"intent": intent.duplicate(true),
		"tick": root_tick
	})
	return {
		"queued": true,
		"tick": root_tick
	}

func advance(roots: Array = []) -> Array:
	var event_start := _events.size()
	var frame_roots: Array = _pending.duplicate(true)
	_pending.clear()

	for raw_root in roots:
		if raw_root is Dictionary:
			frame_roots.append(raw_root.duplicate(true))

	for raw_root in frame_roots:
		if not (raw_root is Dictionary):
			_append_event("ACTION_REJECTED", "", "", {
				"reason": "root_must_be_dictionary"
			})
			continue

		var root: Dictionary = raw_root
		_process_root(root)

	_frames.append({
		"tick": _bridge_tick,
		"roots": frame_roots.duplicate(true)
	})
	_bridge_tick += 1

	return events(event_start)

func events(since: int = 0) -> Array:
	if since < 0:
		return []
	if since >= _events.size():
		return []
	return _events.slice(since).duplicate(true)

func snapshot() -> Dictionary:
	var protocol_description := {}
	var protocol := get_node_or_null("/root/PlayerProtocol")
	if protocol != null and protocol.has_method("protocol_description"):
		protocol_description = protocol.protocol_description()

	var receipts: Array = []
	var receipt_ledger := get_node_or_null("/root/ReceiptLedger")
	if receipt_ledger != null and receipt_ledger.has_method("snapshot"):
		receipts = receipt_ledger.snapshot()

	var reality_summary := {}
	var reality := get_node_or_null("/root/RealityLedger")
	if reality != null and reality.has_method("public_summary"):
		reality_summary = reality.public_summary()

	return {
		"schema": "night-circuit/pixelforge-snapshot/0.1",
		"restorable": false,
		"bridge_tick": _bridge_tick,
		"controllers": _controllers.duplicate(true),
		"authority": authority(),
		"events": _events.duplicate(true),
		"player_protocol": protocol_description,
		"receipt_ledger": receipts,
		"reality_ledger": reality_summary
	}

func recording() -> Dictionary:
	var replay_tape := {}
	var receipt_ledger := get_node_or_null("/root/ReceiptLedger")
	if receipt_ledger != null and receipt_ledger.has_method("replay_tape"):
		replay_tape = receipt_ledger.replay_tape()

	return {
		"schema": "night-circuit/pixelforge-recording/0.1",
		"exact_replay": false,
		"clock_mode": "engine",
		"frames": _frames.duplicate(true),
		"receipt_tape": replay_tape
	}

func authority() -> Dictionary:
	return _grants.duplicate(true)

func hash() -> String:
	return JSON.stringify(_hash_state()).sha256_text()

func reset_bridge_for_test() -> void:
	_bridge_tick = 0
	_event_sequence = 0
	_pending.clear()
	_events.clear()
	_frames.clear()
	_controllers.clear()
	_grants.clear()
	_bootstrap_human_seat()

func _process_root(root: Dictionary) -> void:
	var controller_id := str(root.get("controller_id", root.get("controllerId", ""))).strip_edges()
	var root_tick := int(root.get("tick", -1))
	var intent = root.get("intent", {})

	if root_tick != _bridge_tick:
		_append_event("ACTION_REJECTED", controller_id, "", {
			"reason": "wrong_tick",
			"submitted_tick": root_tick,
			"bridge_tick": _bridge_tick
		})
		return

	if not _controllers.has(controller_id):
		_append_event("ACTION_REJECTED", controller_id, "", {
			"reason": "controller_not_registered"
		})
		return

	if not (intent is Dictionary):
		_append_event("ACTION_REJECTED", controller_id, "", {
			"reason": "intent_must_be_dictionary"
		})
		return

	var action_name := str(intent.get("action", intent.get("type", ""))).to_upper()
	var actor_id := str(intent.get("actor", intent.get("actorId", ""))).to_lower()

	if actor_id == "bridge" and action_name == "DELEGATE_CONTROLLER":
		_process_delegation(controller_id, intent)
		return

	if not _controller_can(controller_id, actor_id, action_name):
		_append_event("ACTION_REJECTED", controller_id, actor_id, {
			"reason": "bridge_authority_denied",
			"action": action_name
		})
		return

	var protocol := get_node_or_null("/root/PlayerProtocol")
	if protocol == null or not protocol.has_method("handle_adapter_message"):
		_append_event("ACTION_REJECTED", controller_id, actor_id, {
			"reason": "player_protocol_unavailable",
			"action": action_name
		})
		return

	var descriptor: Dictionary = _controllers[controller_id]
	var source := _source_for_kind(str(descriptor.get("kind", "")))
	var request_id := str(intent.get(
		"request_id",
		intent.get("correlationId", "pf-%s-%08d" % [controller_id, _event_sequence + 1])
	))
	var payload = intent.get("payload", intent.get("params", {}))
	if not (payload is Dictionary):
		payload = {}

	var response: Dictionary = protocol.handle_adapter_message(source, {
		"type": "act",
		"actor": actor_id,
		"action": action_name,
		"payload": payload,
		"request_id": request_id
	})

	var body: Dictionary = response.get("body", {})
	var decision: Dictionary = body.get("decision", {})
	var effect: Dictionary = body.get("effect", {})
	var accepted := bool(response.get("ok", false)) and bool(decision.get("accepted", false))

	_append_event(
		"ACTION_ACCEPTED" if accepted else "ACTION_REJECTED",
		controller_id,
		actor_id,
		{
			"action": action_name,
			"request_id": request_id,
			"reason": str(decision.get("reason", response.get("error", "unspecified"))),
			"action_id": str(body.get("action_id", "")),
			"effect_status": str(effect.get("status", "")),
			"effect_reason": str(effect.get("reason", ""))
		}
	)

func _process_delegation(controller_id: String, intent: Dictionary) -> void:
	if not _controller_can(controller_id, "bridge", "DELEGATE_CONTROLLER"):
		_append_event("AUTHORITY_REJECTED", controller_id, "bridge", {
			"reason": "bridge_authority_denied"
		})
		return

	var payload = intent.get("payload", intent.get("params", {}))
	if not (payload is Dictionary):
		_append_event("AUTHORITY_REJECTED", controller_id, "bridge", {
			"reason": "payload_must_be_dictionary"
		})
		return

	var target_id := str(payload.get("controller_id", payload.get("controllerId", ""))).strip_edges()
	var actor_id := str(payload.get("actor", "")).to_lower().strip_edges()
	var requested = payload.get("actions", [])

	if not _controllers.has(target_id):
		_append_event("AUTHORITY_REJECTED", controller_id, actor_id, {
			"reason": "target_controller_not_registered",
			"target_controller": target_id
		})
		return

	if not (requested is Array):
		_append_event("AUTHORITY_REJECTED", controller_id, actor_id, {
			"reason": "actions_must_be_array",
			"target_controller": target_id
		})
		return

	var source_actions := _actions_for(controller_id, actor_id)
	var runtime_actions := _runtime_actions_for_actor(actor_id)
	var granted: Array = []
	for raw_action in requested:
		var candidate := str(raw_action).to_upper()
		if candidate in source_actions and candidate in runtime_actions and candidate not in granted:
			granted.append(candidate)

	if granted.size() != requested.size():
		_append_event("AUTHORITY_REJECTED", controller_id, actor_id, {
			"reason": "delegation_exceeds_grantor_authority",
			"target_controller": target_id
		})
		return

	if not _grants.has(target_id):
		_grants[target_id] = {}
	_grants[target_id][actor_id] = granted.duplicate()

	_append_event("AUTHORITY_DELEGATED", controller_id, actor_id, {
		"target_controller": target_id,
		"actions": granted
	})

func _bootstrap_human_seat() -> void:
	var hunter_actions := _runtime_actions_for_actor("hunter")
	_controllers["human:1"] = {
		"id": "human:1",
		"kind": "human",
		"actor": "hunter",
		"profile": "actor_scoped",
		"builtin": true
	}
	_grants["human:1"] = {
		"hunter": hunter_actions,
		"bridge": ["DELEGATE_CONTROLLER"]
	}

func _valid_controller_descriptor(descriptor: Dictionary) -> bool:
	var controller_id := str(descriptor.get("id", "")).strip_edges()
	var kind := str(descriptor.get("kind", "")).to_lower().strip_edges()
	var actor_id := str(descriptor.get("actor", "hunter")).to_lower().strip_edges()

	if controller_id.is_empty() or controller_id.length() > 128:
		return false
	if kind not in CONTROLLER_KINDS:
		return false
	if actor_id not in ["hunter", "phi_bot"]:
		return false
	if _source_for_kind(kind).is_empty():
		return false
	return true

func _source_for_kind(kind: String) -> String:
	match kind.to_lower():
		"human":
			return "human"
		"gamepad":
			return "gamepad"
		"bot", "model", "agent":
			return "agent"
		"remote", "network":
			return "network"
		"replay":
			return "replay"
		"script":
			return "script"
		_:
			return ""

func _controller_can(controller_id: String, actor_id: String, action_name: String) -> bool:
	return action_name in _actions_for(controller_id, actor_id)

func _actions_for(controller_id: String, actor_id: String) -> Array:
	if not _grants.has(controller_id):
		return []
	var controller_grants = _grants[controller_id]
	if not (controller_grants is Dictionary):
		return []
	if not controller_grants.has(actor_id):
		return []
	var actions = controller_grants[actor_id]
	return actions.duplicate() if actions is Array else []

func _runtime_actions_for_actor(actor_id: String) -> Array:
	var gate := get_node_or_null("/root/AuthorityGate")
	if gate == null or not gate.has_method("actions_for_actor"):
		return []
	return gate.actions_for_actor(actor_id)

func _append_event(event_type: String, controller_id: String, actor_id: String, payload: Dictionary) -> void:
	_event_sequence += 1
	_events.append({
		"id": "pfe-%08d" % _event_sequence,
		"schema": "night-circuit/pixelforge-event/0.1",
		"bridge_tick": _bridge_tick,
		"physics_frame": Engine.get_physics_frames(),
		"type": event_type,
		"controller_id": controller_id,
		"actor": actor_id,
		"payload": payload.duplicate(true)
	})

func _hash_state() -> Dictionary:
	var receipts: Array = []
	var receipt_ledger := get_node_or_null("/root/ReceiptLedger")
	if receipt_ledger != null and receipt_ledger.has_method("snapshot"):
		for raw_receipt in receipt_ledger.snapshot():
			if not (raw_receipt is Dictionary):
				continue
			var receipt: Dictionary = raw_receipt.duplicate(true)
			receipt.erase("unix_time")
			receipt.erase("physics_frame")
			receipts.append(receipt)

	return {
		"bridge_tick": _bridge_tick,
		"controllers": _controllers.duplicate(true),
		"authority": authority(),
		"bridge_events": _events.duplicate(true),
		"receipts": receipts
	}
