extends Area2D
class_name NightCircuitHitbox

signal hit_landed(target: Node, damage: int)

@export var team := "neutral"

var _active := false
var _damage := 0
var _knockback := Vector2.ZERO
var _source_id := "unknown"
var _already_hit: Dictionary = {}

func _ready() -> void:
	monitoring = false
	monitorable = false

func activate(damage: int, knockback: Vector2, source_id: String) -> void:
	_damage = maxi(0, damage)
	_knockback = knockback
	_source_id = source_id
	_already_hit.clear()
	_active = true
	monitoring = true

func deactivate() -> void:
	_active = false
	monitoring = false
	_already_hit.clear()

func is_active() -> bool:
	return _active

func _physics_process(_delta: float) -> void:
	if not _active:
		return

	for area in get_overlapping_areas():
		if not area.has_method("accept_hit"):
			continue

		var instance_id := area.get_instance_id()
		if _already_hit.has(instance_id):
			continue

		var accepted := bool(area.accept_hit({
			"source_id": _source_id,
			"source_team": team,
			"damage": _damage,
			"knockback": _knockback,
			"source_position": global_position
		}))

		if accepted:
			_already_hit[instance_id] = true
			hit_landed.emit(area, _damage)
