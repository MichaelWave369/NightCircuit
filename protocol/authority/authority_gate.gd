extends Node

# CAPABILITY != AUTHORITY
# A source being able to propose an action never means it is allowed to execute it.

const ALLOWED_SOURCES := [
	"human",
	"gamepad",
	"agent",
	"network",
	"replay",
	"script",
	"system"
]

const ACTOR_ACTIONS := {
	"system": ["BOOT"],
	"hunter": [
		"MOVE",
		"JUMP",
		"CROUCH",
		"LEDGE_GRAB",
		"WALL_KICK",
		"LIGHT_ATTACK",
		"HEAVY_ATTACK",
		"DODGE",
		"INTERACT"
	],
	"phi_bot": [
		"FOLLOW",
		"HOLD",
		"MOVE",
		"LIGHT",
		"INSPECT",
		"SCAN",
		"PING",
		"MARK",
		"INTERACT"
	]
}

func evaluate(action: Dictionary) -> Dictionary:
	var source := str(action.get("source", "unknown")).to_lower()
	var actor := str(action.get("actor", "unknown")).to_lower()
	var action_name := str(action.get("action", "UNKNOWN")).to_upper()
	var payload = action.get("payload", {})

	if source not in ALLOWED_SOURCES:
		return _deny("source_not_allowed")

	if actor not in ACTOR_ACTIONS:
		return _deny("actor_not_registered")

	if action_name not in ACTOR_ACTIONS[actor]:
		return _deny("action_not_allowed_for_actor")

	if not (payload is Dictionary):
		return _deny("payload_must_be_dictionary")

	return {
		"accepted": true,
		"reason": "authorized"
	}

func _deny(reason: String) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason
	}
