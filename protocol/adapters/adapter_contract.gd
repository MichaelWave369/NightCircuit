extends RefCounted
class_name NightCircuitAdapterContract

const MESSAGE_SCHEMA := "phi-player-protocol/message/0.3"
const RESPONSE_SCHEMA := "phi-player-protocol/response/0.3"
const MESSAGE_TYPES := ["describe", "observe", "act"]

static func normalize(source_id: String, raw: Dictionary) -> Dictionary:
	return {
		"schema": str(raw.get("schema", MESSAGE_SCHEMA)),
		"type": str(raw.get("type", "")).to_lower().strip_edges(),
		"source": source_id.to_lower().strip_edges(),
		"actor": str(raw.get("actor", "")).to_lower().strip_edges(),
		"action": str(raw.get("action", "")).to_upper().strip_edges(),
		"payload": raw.get("payload", {}),
		"request_id": str(raw.get("request_id", "")).strip_edges()
	}

static func validate(message: Dictionary) -> Dictionary:
	if str(message.get("schema", "")) != MESSAGE_SCHEMA:
		return _invalid("invalid_adapter_schema")

	var message_type := str(message.get("type", ""))
	if message_type not in MESSAGE_TYPES:
		return _invalid("unsupported_message_type")

	if str(message.get("source", "")).is_empty():
		return _invalid("missing_source")

	if message_type == "describe":
		return _valid()

	if str(message.get("actor", "")).is_empty():
		return _invalid("missing_actor")

	if message_type == "observe":
		return _valid()

	if str(message.get("action", "")).is_empty():
		return _invalid("missing_action")

	if not (message.get("payload", null) is Dictionary):
		return _invalid("payload_must_be_dictionary")

	return _valid()

static func response(
	message_type: String,
	request_id: String,
	ok: bool,
	body: Dictionary = {},
	error: String = ""
) -> Dictionary:
	return {
		"schema": RESPONSE_SCHEMA,
		"type": message_type,
		"request_id": request_id,
		"ok": ok,
		"body": body.duplicate(true),
		"error": error
	}

static func _valid() -> Dictionary:
	return {"valid": true, "reason": "valid"}

static func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
