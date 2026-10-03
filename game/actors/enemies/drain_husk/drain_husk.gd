extends CharacterBody2D
class_name NightCircuitDrainHusk

signal died(enemy_id: String)

const GRAVITY := 1850.0
const MAX_FALL_SPEED := 900.0
const ATTACK_WINDUP := 0.30
const ATTACK_ACTIVE := 0.15
const ATTACK_RECOVERY := 0.48
const ATTACK_COOLDOWN := 0.45

@export var enemy_id := "drain_husk"
@export var move_speed := 82.0
@export var detection_range := 440.0
@export var attack_range := 58.0
@export var max_health := 48

var health := 48
var _hunter: Node2D
var _facing := -1
var _phase := "READY"
var _phase_timer := 0.0
var _cooldown_timer := 0.0
var _hurt_timer := 0.0
var _dead := false

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var floor_ahead_ray: RayCast2D = $FloorAheadRay

func _ready() -> void:
	health = max_health
	_hunter = get_tree().get_first_node_in_group("hunter")
	_update_attack_hitbox()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _dead:
		return

	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	_hurt_timer = maxf(0.0, _hurt_timer - delta)

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	_tick_attack(delta)

	if _phase == "READY" and _hurt_timer <= 0.0:
		_tick_hunt()

	move_and_slide()
	_update_attack_hitbox()
	queue_redraw()

func _tick_hunt() -> void:
	if _hunter == null or not is_instance_valid(_hunter):
		_hunter = get_tree().get_first_node_in_group("hunter")
		if _hunter == null:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * get_physics_process_delta_time())
			return

	var dx := _hunter.global_position.x - global_position.x
	var distance := absf(dx)

	if distance <= attack_range and absf(_hunter.global_position.y - global_position.y) < 70.0:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * get_physics_process_delta_time())
		if _cooldown_timer <= 0.0:
			_start_attack()
		return

	if distance > detection_range:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * get_physics_process_delta_time())
		return

	_facing = 1 if dx > 0.0 else -1
	floor_ahead_ray.position.x = 18.0 * float(_facing)
	floor_ahead_ray.force_raycast_update()

	if floor_ahead_ray.is_colliding():
		velocity.x = float(_facing) * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * get_physics_process_delta_time())

func _start_attack() -> void:
	_phase = "WINDUP"
	_phase_timer = ATTACK_WINDUP
	velocity.x = 0.0
	queue_redraw()

func _tick_attack(delta: float) -> void:
	if _phase == "READY":
		return

	_phase_timer -= delta

	if _phase == "WINDUP" and _phase_timer <= 0.0:
		_phase = "ACTIVE"
		_phase_timer = ATTACK_ACTIVE
		attack_hitbox.activate(
			12,
			Vector2(250.0 * float(_facing), -85.0),
			enemy_id
		)
		return

	if _phase == "ACTIVE" and _phase_timer <= 0.0:
		attack_hitbox.deactivate()
		_phase = "RECOVERY"
		_phase_timer = ATTACK_RECOVERY
		return

	if _phase == "RECOVERY" and _phase_timer <= 0.0:
		_phase = "READY"
		_phase_timer = 0.0
		_cooldown_timer = ATTACK_COOLDOWN

func receive_hit(hit: Dictionary) -> bool:
	if _dead:
		return false

	var damage := maxi(0, int(hit.get("damage", 0)))
	if damage <= 0:
		return false

	health = maxi(0, health - damage)
	_hurt_timer = 0.18
	attack_hitbox.deactivate()
	_phase = "READY"
	_phase_timer = 0.0

	var knockback = hit.get("knockback", Vector2.ZERO)
	if knockback is Vector2:
		velocity = knockback

	if health <= 0:
		_dead = true
		died.emit(enemy_id)
		queue_free()
		return true

	queue_redraw()
	return true

func _update_attack_hitbox() -> void:
	attack_hitbox.position = Vector2(30.0 * float(_facing), -5.0)

func _draw() -> void:
	var body_color := Color(0.44, 0.34, 0.35, 1.0)
	var core_color := Color(0.73, 0.29, 0.24, 1.0)

	if _hurt_timer > 0.0:
		body_color = Color(0.78, 0.56, 0.48, 1.0)

	draw_rect(Rect2(Vector2(-15.0, -23.0), Vector2(30.0, 42.0)), body_color)
	draw_circle(Vector2(0.0, -29.0), 11.0, Color(0.59, 0.50, 0.49, 1.0))
	draw_circle(Vector2(5.0 * float(_facing), -30.0), 3.0, core_color)

	if _phase == "WINDUP":
		draw_arc(Vector2.ZERO, 38.0, -1.0, 1.0, 16, Color(0.80, 0.29, 0.25, 0.9), 3.0)
	elif _phase == "ACTIVE":
		draw_line(Vector2.ZERO, Vector2(42.0 * float(_facing), -4.0), Color(0.92, 0.48, 0.34, 1.0), 5.0)
