extends CharacterBody2D
class_name NightCircuitHunter

const ACTOR_ID := "hunter"

var control_source := "human"
var authority_enabled := true

func actor_snapshot() -> Dictionary:
	return {
		"actor": ACTOR_ID,
		"position": [global_position.x, global_position.y],
		"velocity": [velocity.x, velocity.y],
		"control_source": control_source,
		"authority_enabled": authority_enabled
	}
