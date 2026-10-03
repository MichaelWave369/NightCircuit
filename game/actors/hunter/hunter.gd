extends CharacterBody2D
class_name NightCircuitHunter

signal locomotion_state_changed(previous_state: String, current_state: String)
signal movement_event(event_name: String, detail: Dictionary)
signal health_changed(current_health: int, max_health: int)
signal defeated
signal interaction_requested(context: Dictionary)

enum LocomotionState {
	IDLE,
	RUN,
	AIR,
	CROUCH,
	WALL_SLIDE,
	LEDGE_HANG
}

enum CombatState {
	READY,
	LIGHT,
	HEAVY,
	DODGE,
	HURT,
	DEAD
}

const ACTOR_ID := "hunter"

const STAND_HEIGHT := 42.0
const CROUCH_HEIGHT := 28.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER_TIME := 0.12
const LEDGE_REGRAB_LOCK := 0.20

const LIGHT_DURATION := 0.28
const LIGHT_ACTIVE_START := 0.07
const LIGHT_ACTIVE_END := 0.17
const HEAVY_DURATION := 0.52
const HEAVY_ACTIVE_START := 0.17
const HEAVY_ACTIVE_END := 0.34
const DODGE_DURATION := 0.30
const HURT_DURATION := 0.22
const DAMAGE_INVULNERABILITY := 0.62

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
@export var dodge_speed := 460.0
@export var max_health := 100

var control_source := "human"
var authority_enabled := true
var health := 100

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

var _combat_state := CombatState.READY
var _combat_elapsed := 0.0
var _damage_invulnerability_timer := 0.0
var _attack_hitbox_live := false

@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var left_wall_ray: RayCast2D = $Sensors/LeftWallRay
@onready var right_wall_ray: RayCast2D = $Sensors/RightWallRay
@onready var left_head_ray: RayCast2D = $Sensors/LeftHeadRay
@onready var right_head_ray: RayCast2D = $Sensors/RightHeadRay
@onready var ceiling_ray: RayCast2D = $Sensors/CeilingRay
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	health = max_health

	var bus := get_node_or_null("/root/ActionBus")
	if bus != null:
		bus.register_actor(ACTOR_ID, Callable(self, "execute_action"))

	camera.enabled = true
	_set_crouched(false)
	_force_sensor_update()
	_update_locomotion_state()
	_update_attack_hitbox_transform()
	health_changed.emit(health, max_health)
	queue_redraw()

func _exit_tree() -> void:
	var bus := get_node_or_null("/root/ActionBus")
	if bus != null:
		bus.unregister_actor(ACTOR_ID, Callable(self, "execute_action"))

func execute_action(action: Dictionary) -> Dictionary:
	if str(action.get("actor", "")).to_lower() != ACTOR_ID:
		return _effect("refused", "actor_mismatch")

	control_source = str(action.get("source", control_source)).to_lower()
	var action_name := str(action.get("action", "")).to_upper()
	var payload = action.get("payload", {})
	if not (payload is Dictionary):
		return _effect("failed", "payload_not_dictionary")

	match action_name:
		"MOVE":
			_move_intent = clampf(float(payload.get("x", 0.0)), -1.0, 1.0)
			if absf(_move_intent) > 0.05:
				_facing = 1 if _move_intent > 0.0 else -1
			return _effect("applied", "move_intent_updated", {"x": _move_intent})
		"JUMP":
			var pressed := bool(payload.get("pressed", true))
			if pressed:
				_jump_buffer_timer = JUMP_BUFFER_TIME
				return _effect("applied", "jump_buffered", {"buffer_seconds": JUMP_BUFFER_TIME})
			_jump_release_pending = true
			return _effect("applied", "jump_release_queued")
		"CROUCH":
			_crouch_intent = bool(payload.get("pressed", false))
			return _effect("applied", "crouch_intent_updated", {"pressed": _crouch_intent})
		"LIGHT_ATTACK":
			if not _can_start_attack():
				return _effect("refused", "combat_action_unavailable")
			_start_attack(CombatState.LIGHT)
			return _effect("applied", "light_attack_started")
		"HEAVY_ATTACK":
			if not _can_start_attack():
				return _effect("refused", "combat_action_unavailable")
			_start_attack(CombatState.HEAVY)
			return _effect("applied", "heavy_attack_started")
		"DODGE":
			if not _can_start_dodge():
				return _effect("refused", "dodge_unavailable")
			_start_dodge()
			return _effect("applied", "dodge_started", {"invulnerability_seconds": DODGE_DURATION})
		"LEDGE_GRAB", "WALL_KICK":
			return _effect("refused", "derived_movement_event_not_command")
		"INTERACT":
			if _combat_state == CombatState.DEAD or _combat_state == CombatState.HURT:
				return _effect("refused", "interaction_unavailable")
			var context := {
				"position": [global_position.x, global_position.y],
				"facing": _facing,
				"source": control_source
			}
			interaction_requested.emit(context)
			return _effect("applied", "interaction_requested", context)
		_:
			return _effect("refused", "action_not_implemented")

func _effect(status: String, reason: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"status": status,
		"reason": reason,
		"effect": detail
	}

func _can_start_attack() -> bool:
	return _combat_state == CombatState.READY and not _ledge_hanging and not _is_crouching

func _can_start_dodge() -> bool:
	if _combat_state != CombatState.READY or _ledge_hanging:
		return false
	if _is_crouching:
		ceiling_ray.force_raycast_update()
		if ceiling_ray.is_colliding():
			return false
	return true

func _physics_process(delta: float) -> void:
	_damage_invulnerability_timer = maxf(0.0, _damage_invulnerability_timer - delta)
	_tick_combat(delta)

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

	if _combat_state != CombatState.HURT and _combat_state != CombatState.DEAD:
		_consume_jump_buffer()

	_apply_jump_cut()
	_apply_wall_slide()

	move_and_slide()

	_force_sensor_update()

	if _combat_state == CombatState.READY:
		_try_begin_ledge_grab()

	_update_locomotion_state()
	_update_attack_hitbox_transform()
	queue_redraw()

func _start_attack(kind: int) -> void:
	if not _can_start_attack():
		return

	if kind != CombatState.LIGHT and kind != CombatState.HEAVY:
		return

	_combat_state = kind
	_combat_elapsed = 0.0
	_attack_hitbox_live = false
	attack_hitbox.deactivate()
	queue_redraw()

func _start_dodge() -> void:
	if not _can_start_dodge():
		return

	if _is_crouching and not _try_stand():
		return

	_combat_state = CombatState.DODGE
	_combat_elapsed = 0.0
	_damage_invulnerability_timer = maxf(_damage_invulnerability_timer, DODGE_DURATION)
	velocity.x = float(_facing) * dodge_speed
	attack_hitbox.deactivate()
	_attack_hitbox_live = false
	movement_event.emit("dodge", {"facing": _facing})
	queue_redraw()

func _tick_combat(delta: float) -> void:
	if _combat_state == CombatState.READY or _combat_state == CombatState.DEAD:
		return

	_combat_elapsed += delta

	match _combat_state:
		CombatState.LIGHT:
			_tick_attack_window(
				LIGHT_DURATION,
				LIGHT_ACTIVE_START,
				LIGHT_ACTIVE_END,
				14,
				Vector2(230.0 * float(_facing), -55.0)
			)
		CombatState.HEAVY:
			_tick_attack_window(
				HEAVY_DURATION,
				HEAVY_ACTIVE_START,
				HEAVY_ACTIVE_END,
				28,
				Vector2(360.0 * float(_facing), -95.0)
			)
		CombatState.DODGE:
			velocity.x = float(_facing) * dodge_speed
			if _combat_elapsed >= DODGE_DURATION:
				_finish_combat_action()
		CombatState.HURT:
			if _combat_elapsed >= HURT_DURATION:
				_finish_combat_action()

func _tick_attack_window(
	total_duration: float,
	active_start: float,
	active_end: float,
	damage: int,
	knockback: Vector2
) -> void:
	if not _attack_hitbox_live and _combat_elapsed >= active_start and _combat_elapsed < active_end:
		attack_hitbox.activate(damage, knockback, ACTOR_ID)
		_attack_hitbox_live = true

	if _attack_hitbox_live and _combat_elapsed >= active_end:
		attack_hitbox.deactivate()
		_attack_hitbox_live = false

	if _combat_elapsed >= total_duration:
		_finish_combat_action()

func _finish_combat_action() -> void:
	attack_hitbox.deactivate()
	_attack_hitbox_live = false
	_combat_state = CombatState.READY
	_combat_elapsed = 0.0
	queue_redraw()

func receive_hit(hit: Dictionary) -> bool:
	if _combat_state == CombatState.DEAD:
		return false

	if _combat_state == CombatState.DODGE or _damage_invulnerability_timer > 0.0:
		return false

	var damage := maxi(0, int(hit.get("damage", 0)))
	if damage <= 0:
		return false

	health = maxi(0, health - damage)
	health_changed.emit(health, max_health)

	attack_hitbox.deactivate()
	_attack_hitbox_live = false
	_ledge_hanging = false
	_ledge_side = 0
	_set_crouched(false)

	var knockback = hit.get("knockback", Vector2.ZERO)
	if knockback is Vector2:
		velocity = knockback

	_damage_invulnerability_timer = DAMAGE_INVULNERABILITY

	if health <= 0:
		_combat_state = CombatState.DEAD
		_combat_elapsed = 0.0
		defeated.emit()
	else:
		_combat_state = CombatState.HURT
		_combat_elapsed = 0.0

	queue_redraw()
	return true

func restore_full_health() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func restore_health_for_load(saved_health: int) -> void:
	health = clampi(saved_health, 1, max_health)
	_combat_state = CombatState.READY
	_damage_invulnerability_timer = 0.0
	health_changed.emit(health, max_health)

func _apply_horizontal_motion(delta: float) -> void:
	if _combat_state == CombatState.DODGE or _combat_state == CombatState.HURT or _combat_state == CombatState.DEAD:
		return

	var speed_scale := 0.45 if _combat_state == CombatState.LIGHT or _combat_state == CombatState.HEAVY else 1.0
	var target_speed := _move_intent * (crouch_speed if _is_crouching and is_on_floor() else run_speed) * speed_scale
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
	if is_on_floor() or velocity.y <= 0.0 or _combat_state == CombatState.DODGE:
		return

	var wall_side := _wall_contact_side()
	if wall_side == 0:
		return

	if _move_intent * float(wall_side) <= 0.20:
		return

	velocity.y = minf(velocity.y, wall_slide_speed)

func _update_crouch() -> void:
	if _combat_state != CombatState.READY:
		return

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

func _combat_state_name(value: int) -> String:
	match value:
		CombatState.READY:
			return "READY"
		CombatState.LIGHT:
			return "LIGHT"
		CombatState.HEAVY:
			return "HEAVY"
		CombatState.DODGE:
			return "DODGE"
		CombatState.HURT:
			return "HURT"
		CombatState.DEAD:
			return "DEAD"
		_:
			return "UNKNOWN"

func _update_attack_hitbox_transform() -> void:
	attack_hitbox.position = Vector2(34.0 * float(_facing), -5.0)

func set_camera_bounds(bounds: Rect2) -> void:
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.position.x + bounds.size.x)
	camera.limit_bottom = int(bounds.position.y + bounds.size.y)

func force_respawn(world_position: Vector2) -> void:
	global_position = world_position
	velocity = Vector2.ZERO
	_move_intent = 0.0
	_crouch_intent = false
	_jump_buffer_timer = 0.0
	_jump_release_pending = false
	_coyote_timer = 0.0
	_ledge_hanging = false
	_ledge_side = 0
	_ledge_regrab_timer = LEDGE_REGRAB_LOCK
	_damage_invulnerability_timer = 0.0
	attack_hitbox.deactivate()
	_attack_hitbox_live = false
	_combat_state = CombatState.READY
	_combat_elapsed = 0.0
	_set_crouched(false)
	restore_full_health()
	reset_physics_interpolation()
	movement_event.emit("respawn", {"position": [world_position.x, world_position.y]})

func actor_snapshot() -> Dictionary:
	return {
		"actor": ACTOR_ID,
		"position": [global_position.x, global_position.y],
		"velocity": [velocity.x, velocity.y],
		"control_source": control_source,
		"authority_enabled": authority_enabled,
		"locomotion": _state_name(_state),
		"combat": _combat_state_name(_combat_state),
		"health": health,
		"max_health": max_health,
		"invulnerable": _combat_state == CombatState.DODGE or _damage_invulnerability_timer > 0.0,
		"facing": _facing,
		"crouching": _is_crouching,
		"ledge_hanging": _ledge_hanging
	}


func protocol_capabilities() -> Dictionary:
	var alive := _combat_state != CombatState.DEAD
	return {
		"MOVE": {"available": alive},
		"JUMP": {"available": alive and _combat_state != CombatState.HURT},
		"CROUCH": {"available": alive and _combat_state == CombatState.READY},
		"LIGHT_ATTACK": {"available": _can_start_attack()},
		"HEAVY_ATTACK": {"available": _can_start_attack()},
		"DODGE": {"available": _can_start_dodge()},
		"INTERACT": {"available": alive and _combat_state != CombatState.HURT},
		"LEDGE_GRAB": {"available": false, "reason": "derived_world_event"},
		"WALL_KICK": {"available": false, "reason": "derived_world_event"}
	}

func _draw() -> void:
	var body_color := Color(0.56, 0.64, 0.73, 1.0)
	var trim_color := Color(0.80, 0.88, 0.94, 1.0)
	var eye_color := Color(0.22, 0.72, 0.82, 1.0)

	if _combat_state == CombatState.HURT:
		body_color = Color(0.86, 0.40, 0.38, 1.0)
	elif _combat_state == CombatState.DODGE:
		body_color = Color(0.38, 0.72, 0.80, 0.65)

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

	if _combat_state == CombatState.LIGHT or _combat_state == CombatState.HEAVY:
		var reach := 44.0 if _combat_state == CombatState.LIGHT else 58.0
		var start_angle := -0.9 if _facing > 0 else PI - 0.9
		var end_angle := 0.9 if _facing > 0 else PI + 0.9
		draw_arc(Vector2.ZERO, reach, start_angle, end_angle, 18, Color(0.86, 0.82, 0.58, 0.9), 3.0)
