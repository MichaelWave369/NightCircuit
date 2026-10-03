extends RefCounted
class_name NightCircuitObservation

const SCHEMA := "phi-player-protocol/observation/0.3"

static func build(
	sequence: int,
	actor_id: String,
	room_id: String,
	visible_entities: Array,
	signals: Dictionary,
	state: Dictionary,
	capabilities: Dictionary,
	metadata: Dictionary = {}
) -> Dictionary:
	return {
		"schema": SCHEMA,
		"observation_id": "obs-%08d" % sequence,
		"actor": actor_id,
		"room": room_id,
		"physics_frame": Engine.get_physics_frames(),
		"unix_time": int(Time.get_unix_time_from_system()),
		"visible_entities": visible_entities.duplicate(true),
		"signals": signals.duplicate(true),
		"state": state.duplicate(true),
		"capabilities": capabilities.duplicate(true),
		"metadata": metadata.duplicate(true)
	}
