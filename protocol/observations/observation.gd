extends RefCounted
class_name NightCircuitObservation

static func build(
	actor_id: String,
	room_id: String,
	visible_entities: Array,
	signals: Dictionary = {},
	state: Dictionary = {}
) -> Dictionary:
	return {
		"schema": "phi-player-protocol/observation/0.1",
		"actor": actor_id,
		"room": room_id,
		"visible_entities": visible_entities.duplicate(true),
		"signals": signals.duplicate(true),
		"state": state.duplicate(true)
	}
