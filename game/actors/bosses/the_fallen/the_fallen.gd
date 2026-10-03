extends CharacterBody2D
class_name NightCircuitTheFallen

signal health_changed(current_health: int, max_health: int)
signal phase_changed(phase: int)
signal attack_telegraphed(event: Dictionary)
signal anomaly_detected(event: Dictionary)
signal defeated(snapshot: Dictionary)

enum BossState {
	DORMANT,
	READY,
	WINDUP,
	ACTIVE,
	RECOVERY,
	DEAD
}

const PHASE_TWO_THRESHOLD := 0.50
const PHYSICAL_ATTACKS := [
	"WHIP_STRIKE",
	"GROUND_SWEEP",
	"CROSS_THROW",
	"BELL_LEAP"
]
const PHASE_TWO_ATTACKS := [
	"WHIP_STRIKE",
	"CAUSAL_ECHO",
	"GROUND_SWEEP",
	"CROSS_THROW",
	"CAUSAL_ECHO",
	"BELL_LEAP"
]

@export var max_health := 420
@export var gravity_strength := 1850.0
@export var max_fall_speed := 900.0

var health := 420

var _target: Node2D
var _encounter_active := false
var _state := BossState.DORMANT
var _boss_phase := 1
var _active_attack := ""
var _attack_elapsed := 0.0
var _cooldown := 0.75
var _attack_index := 0
var _facing := -1
var _spawn_position := Vector2.ZERO
var _projectile_velocity := Vector2.ZERO
var _target_history: Array = []
var _causal_target := Vector2.ZERO

@onready var physical_hitbox: Area2D = $PhysicalHitbox
@onready var projectile_hitbox: Area2D = $ProjectileHitbox
@onready var causal_hitbox: Area2D = $CausalHitbox

func _ready() -> void:
	_spawn_position = position
	health = max_health
	_deactivate_hitboxes()
	set_encounter_active(false)
	queue_redraw()

func bind_target(target: Node2D) -> void:
	_target = target

func start_encounter(target: Node2D) -> void:
	bind_target(target)
	if _state == BossState.DEAD:
		visible = true
		return

	set_encounter_active(true)
	_state = BossState.READY
	_cooldown = 0.75
	queue_redraw()

func set_encounter_active(enabled: bool) -> void:
	_encounter_active = enabled
	visible = enabled
	set_physics_process(enabled and _state != BossState.DEAD)

	if not enabled:
		_deactivate_hitboxes()
		if _state != BossState.DEAD:
			_state = BossState.DORMANT
		velocity = Vector2.ZERO

func reset_encounter() -> void:
	position = _spawn_position
	velocity = Vector2.ZERO
	health = max_health
	_boss_phase = 1
	_state = BossState.READY if _encounter_active else BossState.DORMANT
	_active_attack = ""
	_attack_elapsed = 0.0
	_cooldown = 0.85
	_attack_index = 0
	_target_history.clear()
	_causal_target = Vector2.ZERO
	_deactivate_hitboxes()
	health_changed.emit(health, max_health)
	phase_changed.emit(_boss_phase)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not _encounter_active or _state == BossState.DEAD:
		return

	_capture_target_history()

	if _target != null:
		var dx := _target.global_position.x - global_position.x
		if absf(dx) > 8.0:
			_facing = 1 if dx > 0.0 else -1

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity_strength * delta, max_fall_speed)

	match _state:
		BossState.READY:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_cooldown -= delta
			if _cooldown <= 0.0:
				_begin_next_attack()
		BossState.WINDUP:
			_attack_elapsed += delta
			if _attack_elapsed >= _windup_duration(_active_attack):
				_activate_attack()
		BossState.ACTIVE:
			_attack_elapsed += delta
			_tick_active_attack(delta)
			if _attack_elapsed >= _active_duration(_active_attack):
				_finish_active_attack()
		BossState.RECOVERY:
			_attack_elapsed += delta
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			if _attack_elapsed >= _recovery_duration(_active_attack):
				_state = BossState.READY
				_active_attack = ""
				_attack_elapsed = 0.0
				_cooldown = 0.35 if _boss_phase == 2 else 0.55
				queue_redraw()

	move_and_slide()

func receive_hit(hit: Dictionary) -> bool:
	if not _encounter_active or _state == BossState.DEAD:
		return false

	var damage := maxi(0, int(hit.get("damage", 0)))
	if damage <= 0:
		return false

	health = maxi(0, health - damage)
	health_changed.emit(health, max_health)

	var knockback = hit.get("knockback", Vector2.ZERO)
	if knockback is Vector2:
		velocity.x += float(knockback.x) * 0.12

	if health <= 0:
		_defeat()
		return true

	if _boss_phase == 1 and float(health) / float(max_health) <= PHASE_TWO_THRESHOLD:
		_boss_phase = 2
		phase_changed.emit(_boss_phase)

	queue_redraw()
	return true

func actor_snapshot() -> Dictionary:
	return {
		"actor": "the_fallen",
		"boss": true,
		"position": [global_position.x, global_position.y],
		"combat": _state_name(_state),
		"health": health,
		"max_health": max_health,
		"boss_phase": _boss_phase,
		"attack": _active_attack,
		"physical_source": _active_attack != "CAUSAL_ECHO",
		"encounter_active": _encounter_active,
		"defeated": _state == BossState.DEAD
	}

func _begin_next_attack() -> void:
	var attacks := PHYSICAL_ATTACKS if _boss_phase == 1 else PHASE_TWO_ATTACKS
	_active_attack = str(attacks[_attack_index % attacks.size()])
	_attack_index += 1
	_state = BossState.WINDUP
	_attack_elapsed = 0.0
	_deactivate_hitboxes()

	if _active_attack == "CAUSAL_ECHO":
		_causal_target = _historical_target_position(34)

	attack_telegraphed.emit({
		"boss": "the_fallen",
		"attack": _active_attack,
		"boss_phase": _boss_phase,
		"physical_source": _active_attack != "CAUSAL_ECHO",
		"visible_source": [global_position.x, global_position.y],
		"predicted_damage_source": [
			_causal_target.x,
			_causal_target.y
		] if _active_attack == "CAUSAL_ECHO" else []
	})
	queue_redraw()

func _activate_attack() -> void:
	_state = BossState.ACTIVE
	_attack_elapsed = 0.0

	match _active_attack:
		"WHIP_STRIKE":
			_configure_rect(physical_hitbox, Vector2(118.0, 42.0))
			physical_hitbox.position = Vector2(72.0 * float(_facing), -8.0)
			physical_hitbox.activate(
				18,
				Vector2(340.0 * float(_facing), -80.0),
				"the_fallen.whip_strike"
			)
		"GROUND_SWEEP":
			_configure_rect(physical_hitbox, Vector2(168.0, 28.0))
			physical_hitbox.position = Vector2(58.0 * float(_facing), 18.0)
			physical_hitbox.activate(
				15,
				Vector2(300.0 * float(_facing), -45.0),
				"the_fallen.ground_sweep"
			)
		"CROSS_THROW":
			_configure_rect(projectile_hitbox, Vector2(34.0, 34.0))
			projectile_hitbox.position = Vector2(42.0 * float(_facing), -22.0)
			_projectile_velocity = Vector2(520.0 * float(_facing), 0.0)
			projectile_hitbox.activate(
				16,
				Vector2(260.0 * float(_facing), -70.0),
				"the_fallen.cross_throw"
			)
		"BELL_LEAP":
			_configure_rect(physical_hitbox, Vector2(104.0, 34.0))
			physical_hitbox.position = Vector2(0.0, 24.0)
			velocity = Vector2(270.0 * float(_facing), -430.0)
			physical_hitbox.activate(
				20,
				Vector2(230.0 * float(_facing), -150.0),
				"the_fallen.bell_leap"
			)
		"CAUSAL_ECHO":
			_configure_rect(causal_hitbox, Vector2(78.0, 78.0))
			causal_hitbox.global_position = _causal_target
			causal_hitbox.activate(
				22,
				Vector2(0.0, -175.0),
				"the_fallen.causal_echo"
			)
			anomaly_detected.emit({
				"boss": "the_fallen",
				"attack": "CAUSAL_ECHO",
				"classification": "NO_PHYSICAL_SOURCE",
				"confidence": 0.99,
				"physical_source": false,
				"visible_source": [global_position.x, global_position.y],
				"damage_source": [_causal_target.x, _causal_target.y],
				"history_offset_frames": 34
			})

	queue_redraw()

func _tick_active_attack(delta: float) -> void:
	if _active_attack == "CROSS_THROW":
		projectile_hitbox.position += _projectile_velocity * delta

func _finish_active_attack() -> void:
	_deactivate_hitboxes()
	projectile_hitbox.position = Vector2.ZERO
	_projectile_velocity = Vector2.ZERO
	_state = BossState.RECOVERY
	_attack_elapsed = 0.0
	queue_redraw()

func _defeat() -> void:
	_deactivate_hitboxes()
	_state = BossState.DEAD
	_active_attack = ""
	velocity = Vector2.ZERO
	set_physics_process(false)
	queue_redraw()
	defeated.emit(actor_snapshot())

func _capture_target_history() -> void:
	if _target == null:
		return

	_target_history.append(_target.global_position)
	if _target_history.size() > 120:
		_target_history.pop_front()

func _historical_target_position(frames_back: int) -> Vector2:
	if _target_history.is_empty():
		return _target.global_position if _target != null else global_position

	var index := maxi(0, _target_history.size() - 1 - frames_back)
	return _target_history[index]

func _configure_rect(hitbox: Area2D, size: Vector2) -> void:
	var shape_node := hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is RectangleShape2D):
		return
	var shape := shape_node.shape as RectangleShape2D
	shape.size = size

func _deactivate_hitboxes() -> void:
	if physical_hitbox != null:
		physical_hitbox.deactivate()
	if projectile_hitbox != null:
		projectile_hitbox.deactivate()
	if causal_hitbox != null:
		causal_hitbox.deactivate()

func _windup_duration(attack: String) -> float:
	match attack:
		"WHIP_STRIKE":
			return 0.38
		"GROUND_SWEEP":
			return 0.46
		"CROSS_THROW":
			return 0.52
		"BELL_LEAP":
			return 0.58
		"CAUSAL_ECHO":
			return 0.62
		_:
			return 0.40

func _active_duration(attack: String) -> float:
	match attack:
		"WHIP_STRIKE":
			return 0.15
		"GROUND_SWEEP":
			return 0.16
		"CROSS_THROW":
			return 0.82
		"BELL_LEAP":
			return 0.52
		"CAUSAL_ECHO":
			return 0.14
		_:
			return 0.15

func _recovery_duration(attack: String) -> float:
	match attack:
		"WHIP_STRIKE":
			return 0.38
		"GROUND_SWEEP":
			return 0.46
		"CROSS_THROW":
			return 0.42
		"BELL_LEAP":
			return 0.58
		"CAUSAL_ECHO":
			return 0.55
		_:
			return 0.40

func _state_name(value: int) -> String:
	match value:
		BossState.DORMANT:
			return "DORMANT"
		BossState.READY:
			return "READY"
		BossState.WINDUP:
			return "WINDUP"
		BossState.ACTIVE:
			return "ACTIVE"
		BossState.RECOVERY:
			return "RECOVERY"
		BossState.DEAD:
			return "DEAD"
		_:
			return "UNKNOWN"

func _draw() -> void:
	var armor := Color(0.25, 0.24, 0.28, 1.0)
	var flesh := Color(0.46, 0.20, 0.22, 1.0)
	var core := Color(0.70, 0.52, 0.30, 1.0)

	if _boss_phase == 2:
		armor = Color(0.20, 0.18, 0.31, 1.0)
		core = Color(0.56, 0.46, 0.86, 1.0)

	if _state == BossState.DEAD:
		draw_rect(Rect2(Vector2(-34.0, 10.0), Vector2(68.0, 18.0)), armor)
		draw_circle(Vector2(24.0, 4.0), 12.0, flesh)
		return

	draw_rect(Rect2(Vector2(-24.0, -24.0), Vector2(48.0, 58.0)), armor)
	draw_circle(Vector2(0.0, -35.0), 18.0, flesh)
	draw_circle(Vector2(7.0 * float(_facing), -38.0), 3.0, core)
	draw_line(Vector2(-20.0, 8.0), Vector2(-42.0, 28.0), core, 5.0)
	draw_line(Vector2(20.0, 8.0), Vector2(42.0, 28.0), core, 5.0)

	var health_ratio := float(health) / float(max_health)
	draw_rect(Rect2(Vector2(-58.0, -72.0), Vector2(116.0, 8.0)), Color(0.08, 0.08, 0.10, 0.95))
	draw_rect(Rect2(Vector2(-58.0, -72.0), Vector2(116.0 * health_ratio, 8.0)), flesh)

	if _state == BossState.WINDUP:
		if _active_attack == "CAUSAL_ECHO":
			var visible_side := -_facing
			draw_arc(
				Vector2.ZERO,
				72.0,
				-0.8 if visible_side > 0 else PI - 0.8,
				0.8 if visible_side > 0 else PI + 0.8,
				20,
				Color(0.66, 0.55, 0.92, 0.9),
				4.0
			)
		else:
			draw_arc(
				Vector2.ZERO,
				64.0,
				-0.7 if _facing > 0 else PI - 0.7,
				0.7 if _facing > 0 else PI + 0.7,
				18,
				Color(0.88, 0.62, 0.38, 0.85),
				3.0
			)
