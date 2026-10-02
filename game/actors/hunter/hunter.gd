extends CharacterBody2D
class_name NightCircuitHunter

signal locomotion_state_changed(previous_state: String, current_state: String)
signal movement_event(event_name: String, detail: Dictionary)

enum LocomotionState {
	IDLE,
	RUN,
	AIR,
	CROUCH,
	WALL_SLIDE,
	LEDGE_HANG
}

const ACTOR_ID := "hunter"

const STAND_HEIGHT := 42.0
const CROUCH_HEIGHT := 28.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER_TIME := 0.12
const LEDGE_REGRAB_LOCK := 0.20

@export var run_speed := 280.0
@export var crouch_speed := 120.0
@export var ground_acceleration := 1900.0
@export var ground_friction := 2300.0
@export var air_acceleration := 1150.0
@export var gravity_strength := 1850.0
@export var max_fall_speed := 920.0
@export var jump_speed := 610.0
@export var wall_slide_speed := 155.0
@export var wall_kick_horizontal := 390.0
@export var wall_kick_vertical := 560.0

var control_source := "human"
var authority_enabled := true

var _move_intent := 0.0
var _crouch_intent := false
var _jump_buffer_timer := 0.0
var _jump_release_pending := false
var _coyote_timer := 0.0
var _ledge_regrab_timer := 0.0
var _ledge_hanging := false
var _ledge_side := 0
var _is_crouching := false
var _facing := 1
var _state := LocomotionState.AIR

@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var left_wall_ray: RayCast2D = $Sensors/LeftWallRay
@onready var right_wall_ray: RayCast2D = $Sensors/RightWallRay
@onready var left_head_ray: RayCast2D = $Sensors/LeftHeadRay
@onready var right_head_ray: RayCast2D = $Sensors/RightHeadRay
@onready var ceiling_ray: RayCast2D = $Sensors/CeilingRay

func _ready() -> void:
	var bus := get_node_or_null("/root/ActionBus")
	if bus != null:
		var callback := Callable(self, "_on_action_accepted")
		if not bus.is_connected("action_accepted", callback):
			bus.connect("action_accepted", callback)

	_set_crouched(false)
	_force_sensor_update()
	_update_locomotion_state()
	queue_redraw()

func _physics_process(delta: float) -> void:
	_coyote_timer = COYOTE_TIME if is_on_floor() else maxf(0.0, _coyote_timer - delta)
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	_ledge_regrab_timer = maxf(0.0, _ledge_regrab_timer - delta)

	_force_sensor_update()

	if _ledge_hanging:
		_tick_ledge_hang()
		_update_locomotion_state()
		queue_redraw()
		return

	_update_crouch()
	_apply_horizontal_motion(delta)
	_apply_gravity(delta)
	_consume_jump_buffer()
	_apply_jump_cut()
	_apply_wall_slide()

	move_and_slide()

	_force_sensor_update()
	_try_begin_ledge_grab()
	_update_locomotion_state()
	queue_redraw()

func _on_action_accepted(action: Dictionary, _receipt: Dictionary) -> void:
	if str(action.get("actor", "")).to_lower() != ACTOR_ID:
		return

	var action_name := str(action.get("action", "")).to_upper()
	var payload = action.get("payload", {})
	if not (payload is Dictionary):
		return

	match action_name:
		"MOVE":
			_move_intent = clampf(float(payload.get("x", 0.0)), -1.0, 1.0)
			if absf(_move_intent) > 0.05:
				_facing = 1 if _move_intent > 0.0 else -1
		"JUMP":
			var pressed := bool(payload.get("pressed", true))
			if pressed:
				_jump_buffer_timer = JUMP_BUFFER_TIME
			else:
				_jump_release_pending = true
		"CROUCH":
			_crouch_intent = bool(payload.get("pressed", false))

func _apply_horizontal_motion(delta: float) -> void:
	var target_speed := _move_intent * (crouch_speed if _is_crouching and is_on_floor() else run_speed)
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration

	if absf(_move_intent) > 0.05:
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, air_acceleration * 0.15 * delta)

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	velocity.y = minf(velocity.y + gravity_strength * delta, max_fall_speed)

func _consume_jump_buffer() -> void:
	if _jump_buffer_timer <= 0.0:
		return

	if _is_crouching and not _try_stand():
		return

	if is_on_floor() or _coyote_timer > 0.0:
		velocity.y = -jump_speed
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		movement_event.emit("jump", {"kind": "ground"})
		return

	var wall_side := _wall_contact_side()
	if wall_side != 0:
		_perform_wall_kick(wall_side, "wall")

func _apply_jump_cut() -> void:
	if not _jump_release_pending:
		return

	if velocity.y < -jump_speed * 0.35:
		velocity.y *= 0.52

	_jump_release_pending = false

func _apply_wall_slide() -> void:
	if is_on_floor() or velocity.y <= 0.0:
		return

	var wall_side := _wall_contact_side()
	if wall_side == 0:
		return

	if _move_intent * float(wall_side) <= 0.20:
		return

	velocity.y = minf(velocity.y, wall_slide_speed)

func _update_crouch() -> void:
	if _crouch_intent and is_on_floor():
		_set_crouched(true)
		return

	if _is_crouching and not _crouch_intent:
		_try_stand()

func _try_stand() -> bool:
	if not _is_crouching:
		return true

	ceiling_ray.force_raycast_update()
	if ceiling_ray.is_colliding():
		return false

	_set_crouched(false)
	return true

func _set_crouched(enabled: bool) -> void:
	if _is_crouching == enabled and collider != null:
		return

	_is_crouching = enabled

	if collider != null and collider.shape is CapsuleShape2D:
		var capsule := collider.shape as CapsuleShape2D
		capsule.height = CROUCH_HEIGHT if enabled else STAND_HEIGHT
		collider.position.y = (STAND_HEIGHT - CROUCH_HEIGHT) * 0.5 if enabled else 0.0

	movement_event.emit("crouch_changed", {"enabled": enabled})
	queue_redraw()

func _try_begin_ledge_grab() -> bool:
	if is_on_floor() or _ledge_hanging or _ledge_regrab_timer > 0.0:
		return false

	# Do not magnetize to a ledge during the fast upward part of a jump.
	if velocity.y < -140.0:
		return false

	var side := 0
	if right_wall_ray.is_colliding() and not right_head_ray.is_colliding() and _move_intent > 0.20:
		side = 1
	elif left_wall_ray.is_colliding() and not left_head_ray.is_colliding() and _move_intent < -0.20:
		side = -1

	if side == 0:
		return false

	_ledge_hanging = true
	_ledge_side = side
	velocity = Vector2.ZERO
	_jump_buffer_timer = 0.0
	_jump_release_pending = false
	movement_event.emit("ledge_grab", {"side": side})
	return true

func _tick_ledge_hang() -> void:
	_force_sensor_update()

	var wall_ray := right_wall_ray if _ledge_side > 0 else left_wall_ray
	if not wall_ray.is_colliding():
		_release_ledge("lost_wall")
		return

	if _crouch_intent:
		_release_ledge("drop")
		return

	if _move_intent * float(_ledge_side) < -0.20:
		_release_ledge("move_away")
		return

	if _jump_buffer_timer > 0.0:
		_perform_wall_kick(_ledge_side, "ledge")
		return

	velocity = Vector2.ZERO

func _release_ledge(reason: String) -> void:
	_ledge_hanging = false
	_ledge_side = 0
	_ledge_regrab_timer = LEDGE_REGRAB_LOCK
	velocity.y = maxf(velocity.y, 60.0)
	movement_event.emit("ledge_release", {"reason": reason})

func _perform_wall_kick(wall_side: int, origin: String) -> void:
	_ledge_hanging = false
	_ledge_side = 0
	_ledge_regrab_timer = LEDGE_REGRAB_LOCK
	_set_crouched(false)

	velocity.x = -float(wall_side) * wall_kick_horizontal
	velocity.y = -wall_kick_vertical
	_facing = -wall_side
	_jump_buffer_timer = 0.0
	_jump_release_pending = false

	movement_event.emit("wall_kick", {
		"wall_side": wall_side,
		"origin": origin
	})

func _wall_contact_side() -> int:
	if left_wall_ray.is_colliding() and not right_wall_ray.is_colliding():
		return -1
	if right_wall_ray.is_colliding() and not left_wall_ray.is_colliding():
		return 1
	if left_wall_ray.is_colliding() and right_wall_ray.is_colliding():
		return _facing
	return 0

func _force_sensor_update() -> void:
	left_wall_ray.force_raycast_update()
	right_wall_ray.force_raycast_update()
	left_head_ray.force_raycast_update()
	right_head_ray.force_raycast_update()
	ceiling_ray.force_raycast_update()

func _update_locomotion_state() -> void:
	var next_state := LocomotionState.AIR

	if _ledge_hanging:
		next_state = LocomotionState.LEDGE_HANG
	elif is_on_floor():
		if _is_crouching:
			next_state = LocomotionState.CROUCH
		elif absf(velocity.x) > 12.0:
			next_state = LocomotionState.RUN
		else:
			next_state = LocomotionState.IDLE
	elif _wall_contact_side() != 0 and velocity.y > 0.0 and absf(velocity.y) <= wall_slide_speed + 1.0:
		next_state = LocomotionState.WALL_SLIDE

	if next_state == _state:
		return

	var previous_name := _state_name(_state)
	_state = next_state
	var current_name := _state_name(_state)
	locomotion_state_changed.emit(previous_name, current_name)

func _state_name(value: int) -> String:
	match value:
		LocomotionState.IDLE:
			return "IDLE"
		LocomotionState.RUN:
			return "RUN"
		LocomotionState.AIR:
			return "AIR"
		LocomotionState.CROUCH:
			return "CROUCH"
		LocomotionState.WALL_SLIDE:
			return "WALL_SLIDE"
		LocomotionState.LEDGE_HANG:
			return "LEDGE_HANG"
		_:
			return "UNKNOWN"

func actor_snapshot() -> Dictionary:
	return {
		"actor": ACTOR_ID,
		"position": [global_position.x, global_position.y],
		"velocity": [velocity.x, velocity.y],
		"control_source": control_source,
		"authority_enabled": authority_enabled,
		"locomotion": _state_name(_state),
		"facing": _facing,
		"crouching": _is_crouching,
		"ledge_hanging": _ledge_hanging
	}

func _draw() -> void:
	var body_color := Color(0.56, 0.64, 0.73, 1.0)
	var trim_color := Color(0.80, 0.88, 0.94, 1.0)
	var eye_color := Color(0.22, 0.72, 0.82, 1.0)

	if _is_crouching:
		draw_rect(Rect2(Vector2(-14.0, 0.0), Vector2(28.0, 19.0)), body_color)
		draw_circle(Vector2(4.0 * float(_facing), -4.0), 10.0, trim_color)
		draw_circle(Vector2(8.0 * float(_facing), -5.0), 2.0, eye_color)
	else:
		draw_rect(Rect2(Vector2(-12.0, -5.0), Vector2(24.0, 25.0)), body_color)
		draw_circle(Vector2(0.0, -15.0), 10.0, trim_color)
		draw_circle(Vector2(4.0 * float(_facing), -16.0), 2.0, eye_color)

	if _ledge_hanging:
		draw_arc(Vector2.ZERO, 28.0, -1.2, 1.2, 18, Color(0.38, 0.78, 0.88, 0.8), 2.0)
