extends SceneTree

const RunSaveScript = preload("res://game/save/run_save.gd")
const RealityLedgerScript = preload("res://game/reality/reality_ledger.gd")
const MainScript = preload("res://game/main/main.gd")

var _failures: Array[String] = []

func _init() -> void:
	print("NC-017 runtime integration smoke: START")
	_test_run_save_roundtrip()
	_test_reality_contradiction()

	if _failures.is_empty():
		print("NC-017 runtime integration smoke: PASS")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("NC-017 runtime integration smoke: FAIL (%d)" % _failures.size())
	quit(1)

func _test_run_save_roundtrip() -> void:
	var save = RunSaveScript.new()
	root.add_child(save)
	save.clear_save()

	var write_result: Dictionary = save.save_snapshot({
		"world_id": "ash_village",
		"checkpoint": "market_lantern",
		"hunter_position": [1510.0, 570.0],
		"hunter_health": 73,
		"village_phase": "NIGHT"
	})

	_expect(bool(write_result.get("ok", false)), "RunSave write failed")

	var load_result: Dictionary = save.load_snapshot()
	_expect(bool(load_result.get("ok", false)), "RunSave load failed")
	var snapshot: Dictionary = load_result.get("snapshot", {})
	_expect(str(snapshot.get("world_id", "")) == "ash_village", "RunSave world_id mismatch")
	_expect(str(snapshot.get("checkpoint", "")) == "market_lantern", "RunSave checkpoint mismatch")
	_expect(int(snapshot.get("hunter_health", -1)) == 73, "RunSave health mismatch")
	_expect(str(snapshot.get("village_phase", "")) == "NIGHT", "RunSave phase mismatch")

	save.clear_save()
	save.queue_free()

func _test_reality_contradiction() -> void:
	var ledger = RealityLedgerScript.new()
	root.add_child(ledger)
	ledger.clear_all()

	var first: Dictionary = ledger.record_claim({
		"subject": "integration_bridge",
		"value": "destroyed",
		"confidence": 0.92,
		"provenance": {
			"source_kind": "integration_test",
			"source_id": "source_a"
		},
		"data": {"claim_id": "integration_a"}
	})
	var second: Dictionary = ledger.record_claim({
		"subject": "integration_bridge",
		"value": "present",
		"confidence": 0.88,
		"provenance": {
			"source_kind": "integration_test",
			"source_id": "source_b"
		},
		"data": {"claim_id": "integration_b"}
	})

	_expect(str(first.get("type", "")) == "claim", "RealityLedger first claim failed")
	_expect(str(second.get("type", "")) == "claim", "RealityLedger second claim failed")
	var contradictions: Array = ledger.contradictions()
	_expect(contradictions.size() == 1, "RealityLedger did not derive exactly one contradiction")

	if contradictions.size() == 1:
		var contradiction: Dictionary = contradictions[0]
		_expect(str(contradiction.get("subject", "")) == "integration_bridge", "Contradiction subject mismatch")
		var sources = contradiction.get("data", {}).get("sources", [])
		_expect(sources is Array and sources.size() == 2, "Contradiction source provenance missing")

	ledger.clear_all()
	ledger.queue_free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
