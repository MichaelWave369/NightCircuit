extends Node

signal action_received(action: Dictionary)
signal action_accepted(action: Dictionary, receipt: Dictionary)
signal action_rejected(action: Dictionary, receipt: Dictionary)

var _sequence := 0

func submit(action: Dictionary) -> Dictionary:
	_sequence += 1

	var normalized := action.duplicate(true)
	normalized["source"] = str(normalized.get("source", "unknown")).to_lower()
	normalized["actor"] = str(normalized.get("actor", "unknown")).to_lower()
	normalized["action"] = str(normalized.get("action", "UNKNOWN")).to_upper()
	normalized["payload"] = normalized.get("payload", {})
	normalized["sequence"] = _sequence

	action_received.emit(normalized)

	var gate := get_node_or_null("/root/AuthorityGate")
	var decision := {
		"accepted": false,
		"reason": "authority_gate_unavailable"
	}
	if gate != null:
		decision = gate.evaluate(normalized)

	var receipt := {
		"sequence": _sequence,
		"accepted": bool(decision.get("accepted", false)),
		"reason": str(decision.get("reason", "unspecified")),
		"source": normalized["source"],
		"actor": normalized["actor"],
		"action": normalized["action"],
		"payload": normalized["payload"],
		"unix_time": int(Time.get_unix_time_from_system())
	}

	var ledger := get_node_or_null("/root/ReceiptLedger")
	if ledger != null:
		ledger.append_receipt(receipt)

	if receipt["accepted"]:
		action_accepted.emit(normalized, receipt)
	else:
		action_rejected.emit(normalized, receipt)

	return receipt
