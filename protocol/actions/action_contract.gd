extends RefCounted
class_name NightCircuitActionContract

const ACTION_SCHEMA := "night-circuit/action/0.2"
const DECISION_RECEIPT_SCHEMA := "night-circuit/receipt/decision/0.2"
const EFFECT_RECEIPT_SCHEMA := "night-circuit/receipt/effect/0.2"
const REPLAY_ENTRY_SCHEMA := "night-circuit/replay-entry/0.1"

const EFFECT_STATUSES := [
	"applied",
	"noop",
	"refused",
	"failed"
]

static func normalize(raw: Dictionary, sequence: int) -> Dictionary:
	var action_id := str(raw.get("action_id", "")).strip_edges()
	if action_id == "":
		action_id = "act-%08d" % sequence

	return {
		"schema": ACTION_SCHEMA,
		"action_id": action_id,
		"sequence": sequence,
		"source": str(raw.get("source", "unknown")).to_lower(),
		"actor": str(raw.get("actor", "unknown")).to_lower(),
		"action": str(raw.get("action", "UNKNOWN")).to_upper(),
		"payload": raw.get("payload", {}),
		"request_id": str(raw.get("request_id", "")).strip_edges(),
		"replay_of": str(raw.get("replay_of", "")).strip_edges()
	}

static func validate(action: Dictionary) -> Dictionary:
	if str(action.get("schema", "")) != ACTION_SCHEMA:
		return _invalid("invalid_action_schema")

	if str(action.get("action_id", "")).is_empty():
		return _invalid("missing_action_id")

	if str(action.get("source", "")).is_empty():
		return _invalid("missing_source")

	if str(action.get("actor", "")).is_empty():
		return _invalid("missing_actor")

	if str(action.get("action", "")).is_empty():
		return _invalid("missing_action")

	var payload = action.get("payload", null)
	if not (payload is Dictionary):
		return _invalid("payload_must_be_dictionary")

	var actor := str(action["actor"])
	var action_name := str(action["action"])

	if actor == "hunter":
		match action_name:
			"MOVE":
				if not payload.has("x") or not _is_number(payload["x"]):
					return _invalid("hunter_move_requires_numeric_x")
			"JUMP", "CROUCH":
				if not payload.has("pressed") or typeof(payload["pressed"]) != TYPE_BOOL:
					return _invalid("%s_requires_boolean_pressed" % action_name.to_lower())
			_:
				pass

	if actor == "phi_bot":
		match action_name:
			"MOVE":
				if not payload.has("x") or not payload.has("y"):
					return _invalid("phi_move_requires_x_y")
				if not _is_number(payload["x"]) or not _is_number(payload["y"]):
					return _invalid("phi_move_requires_numeric_x_y")
			"LIGHT":
				if payload.has("enabled") and typeof(payload["enabled"]) != TYPE_BOOL:
					return _invalid("phi_light_enabled_must_be_boolean")
				if payload.has("toggle") and typeof(payload["toggle"]) != TYPE_BOOL:
					return _invalid("phi_light_toggle_must_be_boolean")
			"SCAN":
				if payload.has("mode") and typeof(payload["mode"]) != TYPE_STRING:
					return _invalid("phi_scan_mode_must_be_string")
				if payload.has("mode") and str(payload["mode"]) not in ["enemy_read", "contradiction"]:
					return _invalid("phi_scan_mode_unsupported")
			"MARK":
				if payload.has("target") and typeof(payload["target"]) != TYPE_STRING:
					return _invalid("phi_mark_target_must_be_string")
			_:
				pass

	return {
		"valid": true,
		"reason": "valid"
	}

static func validate_effect_result(result: Dictionary) -> Dictionary:
	var status := str(result.get("status", "failed")).to_lower()
	if status not in EFFECT_STATUSES:
		return {
			"status": "failed",
			"reason": "invalid_effect_status",
			"effect": {}
		}

	var effect = result.get("effect", {})
	if not (effect is Dictionary):
		return {
			"status": "failed",
			"reason": "effect_must_be_dictionary",
			"effect": {}
		}

	return {
		"status": status,
		"reason": str(result.get("reason", "unspecified")),
		"effect": effect.duplicate(true)
	}

static func effect(status: String, reason: String, detail: Dictionary = {}) -> Dictionary:
	return validate_effect_result({
		"status": status,
		"reason": reason,
		"effect": detail
	})

static func _is_number(value) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

static func _invalid(reason: String) -> Dictionary:
	return {
		"valid": false,
		"reason": reason
	}
