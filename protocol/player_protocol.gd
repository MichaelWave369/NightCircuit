extends Node

signal observation_created(observation: Dictionary)
signal adapter_response_created(response: Dictionary)

const Observation = preload("res://protocol/observations/observation.gd")
const AdapterContract = preload("res://protocol/adapters/adapter_contract.gd")

const PROTOCOL_VERSION := "0.3"

var _observation_sequence := 0
var _observation_providers: Dictionary = {}

func register_observer(actor_id: String, provider: Callable) -> bool:
	var normalized_id := actor_id.to_lower().strip_edges()
	if normalized_id.is_empty() or not provider.is_valid():
		return false

	_observation_providers[normalized_id] = provider
	return true

func unregister_observer(actor_id: String, provider: Callable = Callable()) -> void:
	var normalized_id := actor_id.to_lower().strip_edges()
	if not _observation_providers.has(normalized_id):
		return

	if provider.is_valid() and _observation_providers[normalized_id] != provider:
		return

	_observation_providers.erase(normalized_id)

func handle_adapter_message(source_id: String, raw_message: Dictionary) -> Dictionary:
	var message := AdapterContract.normalize(source_id, raw_message)
	var validation := AdapterContract.validate(message)

	if not bool(validation.get("valid", false)):
		return _respond(
			message.get("type", "error"),
			message.get("request_id", ""),
			false,
			{},
			str(validation.get("reason", "invalid_message"))
		)

	if not _source_allowed(str(message["source"])):
		return _respond(
			message["type"],
			message["request_id"],
			false,
			{},
			"source_not_allowed"
		)

	match str(message["type"]):
		"describe":
			return _respond(
				"describe",
				message["request_id"],
				true,
				protocol_description()
			)
		"observe":
			return _observe(message)
		"act":
			return _act(message)
		_:
			return _respond(
				message["type"],
				message["request_id"],
				false,
				{},
				"unsupported_message_type"
			)

func protocol_description() -> Dictionary:
	var actors: Array = []
	var bus := get_node_or_null("/root/ActionBus")
	if bus != null and bus.has_method("registered_actors"):
		actors = bus.registered_actors()

	var observable_actors := _observation_providers.keys()
	observable_actors.sort()

	var action_surfaces := {}
	var gate := get_node_or_null("/root/AuthorityGate")
	if gate != null and gate.has_method("actions_for_actor"):
		for actor_id in actors:
			action_surfaces[str(actor_id)] = gate.actions_for_actor(str(actor_id))

	return {
		"protocol": "phi-player-protocol",
		"version": PROTOCOL_VERSION,
		"message_schema": AdapterContract.MESSAGE_SCHEMA,
		"response_schema": AdapterContract.RESPONSE_SCHEMA,
		"observation_schema": Observation.SCHEMA,
		"message_types": AdapterContract.MESSAGE_TYPES.duplicate(),
		"registered_actors": actors,
		"observable_actors": observable_actors,
		"action_surfaces": action_surfaces
	}

func _observe(message: Dictionary) -> Dictionary:
	var actor_id := str(message["actor"])
	if not _observation_providers.has(actor_id):
		return _respond(
			"observation",
			message["request_id"],
			false,
			{},
			"observation_provider_unavailable"
		)

	var provider: Callable = _observation_providers[actor_id]
	if not provider.is_valid():
		return _respond(
			"observation",
			message["request_id"],
			false,
			{},
			"observation_provider_invalid"
		)

	var raw = provider.call(actor_id)
	if not (raw is Dictionary):
		return _respond(
			"observation",
			message["request_id"],
			false,
			{},
			"observation_provider_must_return_dictionary"
		)

	_observation_sequence += 1
	var observation := Observation.build(
		_observation_sequence,
		actor_id,
		str(raw.get("room", "unknown")),
		raw.get("visible_entities", []),
		raw.get("signals", {}),
		raw.get("state", {}),
		raw.get("capabilities", {}),
		raw.get("metadata", {})
	)

	observation_created.emit(observation.duplicate(true))

	return _respond(
		"observation",
		message["request_id"],
		true,
		{"observation": observation}
	)

func _act(message: Dictionary) -> Dictionary:
	var bus := get_node_or_null("/root/ActionBus")
	if bus == null:
		return _respond(
			"action_result",
			message["request_id"],
			false,
			{},
			"action_bus_unavailable"
		)

	var result: Dictionary = bus.submit({
		"source": message["source"],
		"actor": message["actor"],
		"action": message["action"],
		"payload": message["payload"],
		"request_id": message["request_id"]
	})

	var action_id := str(result.get("action_id", ""))
	var decision := {}
	var effect := {}

	var ledger := get_node_or_null("/root/ReceiptLedger")
	if ledger != null and ledger.has_method("receipts_for_action") and not action_id.is_empty():
		for receipt in ledger.receipts_for_action(action_id):
			match str(receipt.get("receipt_type", "")):
				"decision":
					decision = receipt
				"effect":
					effect = receipt

	return _respond(
		"action_result",
		message["request_id"],
		true,
		{
			"action_id": action_id,
			"decision": decision,
			"effect": effect
		}
	)

func _source_allowed(source_id: String) -> bool:
	var gate := get_node_or_null("/root/AuthorityGate")
	if gate == null or not gate.has_method("is_source_allowed"):
		return false
	return bool(gate.is_source_allowed(source_id))

func _respond(
	response_type: String,
	request_id: String,
	ok: bool,
	body: Dictionary = {},
	error: String = ""
) -> Dictionary:
	var response := AdapterContract.response(
		response_type,
		request_id,
		ok,
		body,
		error
	)
	adapter_response_created.emit(response.duplicate(true))
	return response
