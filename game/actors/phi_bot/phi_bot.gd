extends CharacterBody2D
class_name NightCircuitPhiBot

const ACTOR_ID := "phi_bot"

var form_id := "BROKEN"
var energy := 100.0
var control_source := "system"

func actor_snapshot() -> Dictionary:
	return {
		"actor": ACTOR_ID,
		"position": [global_position.x, global_position.y],
		"velocity": [velocity.x, velocity.y],
		"form": form_id,
		"energy": energy,
		"control_source": control_source
	}
