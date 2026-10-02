extends Node
class_name NightCircuitHumanInputAdapter

@export var actor_id := "hunter"
@export var source_id := "human"

const INPUT_LEFT := "nc_move_left"
const INPUT_RIGHT := "nc_move_right"
const INPUT_JUMP := "nc_jump"
const INPUT_CROUCH := "nc_crouch"

var _last_move := 999.0
var _last_jump := false
var _last_crouch := false

func _ready() -> void:
	_ensure_keyboard_actions()
	_publish_current_state(true)

func _physics_process(_delta: float) -> void:
	_publish_current_state(false)

func _publish_current_state(force: bool) -> void:
	var move_axis := Input.get_axis(INPUT_LEFT, INPUT_RIGHT)
	if absf(move_axis) < 0.05:
		move_axis = 0.0

	var jump_pressed := Input.is_action_pressed(INPUT_JUMP)
	var crouch_pressed := Input.is_action_pressed(INPUT_CROUCH)

	if force or not is_equal_approx(move_axis, _last_move):
		_submit("MOVE", {"x": move_axis})
		_last_move = move_axis

	if force or jump_pressed != _last_jump:
		_submit("JUMP", {"pressed": jump_pressed})
		_last_jump = jump_pressed

	if force or crouch_pressed != _last_crouch:
		_submit("CROUCH", {"pressed": crouch_pressed})
		_last_crouch = crouch_pressed

func _submit(action_name: String, payload: Dictionary) -> void:
	var bus := get_node_or_null("/root/ActionBus")
	if bus == null:
		return

	bus.submit({
		"source": source_id,
		"actor": actor_id,
		"action": action_name,
		"payload": payload
	})

func _ensure_keyboard_actions() -> void:
	_ensure_key_action(INPUT_LEFT, [KEY_A, KEY_LEFT])
	_ensure_key_action(INPUT_RIGHT, [KEY_D, KEY_RIGHT])
	_ensure_key_action(INPUT_JUMP, [KEY_SPACE, KEY_W, KEY_UP])
	_ensure_key_action(INPUT_CROUCH, [KEY_S, KEY_DOWN])

func _ensure_key_action(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	if not InputMap.action_get_events(action_name).is_empty():
		return

	for keycode in keycodes:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(keycode)
		InputMap.action_add_event(action_name, key_event)
