extends Node

signal receipt_appended(receipt: Dictionary)

const MAX_RECEIPTS := 1000
const REPLAY_SCHEMA := "night-circuit/replay-tape/0.1"

var _receipts: Array[Dictionary] = []

func append_receipt(receipt: Dictionary) -> void:
	var stored := receipt.duplicate(true)
	_receipts.append(stored)

	if _receipts.size() > MAX_RECEIPTS:
		_receipts.pop_front()

	receipt_appended.emit(stored.duplicate(true))

func snapshot() -> Array[Dictionary]:
	return _receipts.duplicate(true)

func latest() -> Dictionary:
	if _receipts.is_empty():
		return {}
	return _receipts[-1].duplicate(true)

func latest_decision() -> Dictionary:
	return _latest_type("decision")

func latest_effect() -> Dictionary:
	return _latest_type("effect")

func receipts_for_action(action_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for receipt in _receipts:
		if str(receipt.get("action_id", "")) == action_id:
			result.append(receipt.duplicate(true))
	return result

func replay_tape() -> Dictionary:
	var entries: Array[Dictionary] = []

	for receipt in _receipts:
		if str(receipt.get("receipt_type", "")) != "decision":
			continue
		if not bool(receipt.get("accepted", false)):
			continue
		if str(receipt.get("actor", "")) == "system":
			continue

		entries.append({
			"schema": "night-circuit/replay-entry/0.1",
			"replay_of": receipt.get("action_id", ""),
			"sequence": receipt.get("sequence", 0),
			"original_source": receipt.get("source", "unknown"),
			"actor": receipt.get("actor", "unknown"),
			"action": receipt.get("action", "UNKNOWN"),
			"payload": receipt.get("payload", {}).duplicate(true)
		})

	return {
		"schema": REPLAY_SCHEMA,
		"entry_count": entries.size(),
		"entries": entries
	}

func clear() -> void:
	_receipts.clear()

func _latest_type(receipt_type: String) -> Dictionary:
	for index in range(_receipts.size() - 1, -1, -1):
		var receipt: Dictionary = _receipts[index]
		if str(receipt.get("receipt_type", "")) == receipt_type:
			return receipt.duplicate(true)
	return {}
