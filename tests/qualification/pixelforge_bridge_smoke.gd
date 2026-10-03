extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("NC-018 PixelForge bridge smoke: START")

	var bridge := root.get_node_or_null("PixelForgeBridge")
	var bus := root.get_node_or_null("ActionBus")
	var protocol := root.get_node_or_null("PlayerProtocol")
	var receipts := root.get_node_or_null("ReceiptLedger")

	_expect(bridge != null, "PixelForgeBridge autoload missing")
	_expect(bus != null, "ActionBus autoload missing")
	_expect(protocol != null, "PlayerProtocol autoload missing")
	_expect(receipts != null, "ReceiptLedger autoload missing")

	if not _failures.is_empty():
		_finish()
		return

	bridge.reset_bridge_for_test()
	receipts.clear()

	_expect(
		bus.register_actor("hunter", Callable(self, "_execute_hunter")),
		"failed to register Hunter executor"
	)
	_expect(
		protocol.register_observer("hunter", Callable(self, "_observe_hunter")),
		"failed to register Hunter observer"
	)

	var descriptor: Dictionary = bridge.describe()
	_expect(str(descriptor.get("protocol", "")) == "pixelforge-runtime-bridge", "wrong bridge protocol")
	_expect(int(descriptor.get("version", -1)) == 1, "wrong bridge version")
	_expect(str(descriptor.get("gameId", "")) == "phi-night-circuit", "wrong gameId")
	_expect(bool(descriptor.get("deterministic", true)) == false, "live Godot bridge must not claim deterministic stepping")
	_expect(str(descriptor.get("clockMode", "")) == "engine", "clock mode not declared")

	var registered: Dictionary = bridge.registerController({
		"id": "script:pixelforge",
		"kind": "script",
		"actor": "hunter"
	})
	_expect(bool(registered.get("ok", false)), "script registration failed")

	var before: Dictionary = bridge.observe("script:pixelforge")
	_expect(str(before.get("actor", "")) == "hunter", "script observation did not reach PlayerProtocol")
	_expect(
		before.get("bridge", {}).get("allowed_actions", []) == [],
		"registration incorrectly granted action authority"
	)

	var denied_receipt: Dictionary = bridge.submit("script:pixelforge", {
		"actor": "hunter",
		"action": "MOVE",
		"payload": {"x": 1.0}
	})
	_expect(bool(denied_receipt.get("queued", false)), "unauthorized action was not queued for decision")
	var denied_events: Array = bridge.advance()
	_expect(denied_events.size() == 1, "unauthorized bridge action produced unexpected event count")
	if denied_events.size() == 1:
		_expect(str(denied_events[0].get("type", "")) == "ACTION_REJECTED", "unauthorized action was not rejected")
		_expect(
			str(denied_events[0].get("payload", {}).get("reason", "")) == "bridge_authority_denied",
			"unauthorized rejection reason changed"
		)

	bridge.submit("human:1", {
		"actor": "bridge",
		"action": "DELEGATE_CONTROLLER",
		"payload": {
			"controller_id": "script:pixelforge",
			"actor": "hunter",
			"actions": ["MOVE", "LIGHT_ATTACK"]
		}
	})
	var grant_events: Array = bridge.advance()
	_expect(
		grant_events.any(func(event): return str(event.get("type", "")) == "AUTHORITY_DELEGATED"),
		"human seat did not delegate bridge authority"
	)

	var after: Dictionary = bridge.observe("script:pixelforge")
	var allowed: Array = after.get("bridge", {}).get("allowed_actions", [])
	_expect("MOVE" in allowed, "delegated MOVE missing from observation")
	_expect("LIGHT_ATTACK" in allowed, "delegated LIGHT_ATTACK missing from observation")
	_expect("HEAVY_ATTACK" not in allowed, "undelegated HEAVY_ATTACK leaked into observation")

	var move_receipt: Dictionary = bridge.submit("script:pixelforge", {
		"actor": "hunter",
		"action": "MOVE",
		"payload": {"x": 0.75},
		"correlationId": "nc018-move"
	})
	_expect(bool(move_receipt.get("queued", false)), "authorized MOVE was not queued")

	var move_events: Array = bridge.advance()
	var accepted := false
	for event in move_events:
		if str(event.get("type", "")) == "ACTION_ACCEPTED":
			accepted = true
			_expect(str(event.get("controller_id", "")) == "script:pixelforge", "controller identity lost at bridge event")
			_expect(str(event.get("payload", {}).get("action", "")) == "MOVE", "accepted action name changed")
	_expect(accepted, "authorized MOVE did not reach Night Circuit ActionBus")

	var latest_decision: Dictionary = receipts.latest_decision()
	_expect(bool(latest_decision.get("accepted", false)), "Night Circuit ReceiptLedger did not accept bridged MOVE")
	_expect(str(latest_decision.get("source", "")) == "script", "controller kind did not map to Night Circuit script source")
	_expect(str(latest_decision.get("actor", "")) == "hunter", "bridged actor changed")
	_expect(str(latest_decision.get("action", "")) == "MOVE", "bridged action changed")

	var grants: Dictionary = bridge.authority()
	_expect(
		grants.get("script:pixelforge", {}).get("hunter", []) == ["MOVE", "LIGHT_ATTACK"],
		"bridge authority snapshot differs from delegation"
	)

	var snap: Dictionary = bridge.snapshot()
	_expect(str(snap.get("schema", "")) == "night-circuit/pixelforge-snapshot/0.1", "snapshot schema missing")
	_expect(bool(snap.get("restorable", true)) == false, "bridge snapshot falsely claims exact restore")

	var tape: Dictionary = bridge.recording()
	_expect(str(tape.get("schema", "")) == "night-circuit/pixelforge-recording/0.1", "recording schema missing")
	_expect(bool(tape.get("exact_replay", true)) == false, "engine-clock recording falsely claims exact replay")
	_expect(not str(bridge.hash()).is_empty(), "bridge hash missing")

	bus.unregister_actor("hunter", Callable(self, "_execute_hunter"))
	protocol.unregister_observer("hunter", Callable(self, "_observe_hunter"))
	bridge.reset_bridge_for_test()
	receipts.clear()

	_finish()

func _observe_hunter(_actor_id: String) -> Dictionary:
	return {
		"room": "nc018_test_room",
		"visible_entities": [],
		"signals": {},
		"state": {
			"position": [12.0, 34.0],
			"health": 100
		},
		"capabilities": {
			"movement": true,
			"combat": true
		},
		"metadata": {
			"fixture": "nc018"
		}
	}

func _execute_hunter(action: Dictionary) -> Dictionary:
	return {
		"status": "applied",
		"reason": "nc018_fixture_applied",
		"effect": {
			"action": action.get("action", ""),
			"payload": action.get("payload", {}).duplicate(true)
		}
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("NC-018 PixelForge bridge smoke: PASS")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("NC-018 PixelForge bridge smoke: FAIL (%d)" % _failures.size())
	quit(1)
