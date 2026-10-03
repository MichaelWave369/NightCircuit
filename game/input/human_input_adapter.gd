extends Node
class_name NightCircuitHumanInputAdapter

@export var actor_id := "hunter"
@export var phi_actor_id := "phi_bot"
@export var source_id := "human"

const INPUT_LEFT := "nc_move_left"
const INPUT_RIGHT := "nc_move_right"
const INPUT_JUMP := "nc_jump"
const INPUT_CROUCH := "nc_crouch"
const INPUT_LIGHT_ATTACK := "nc_light_attack"
const INPUT_HEAVY_ATTACK := "nc_heavy_attack"
const INPUT_DODGE := "nc_dodge"
const INPUT_INTERACT := "nc_interact"

const INPUT_PHI_FOLLOW := "nc_phi_follow"
const INPUT_PHI_HOLD := "nc_phi_hold"
const INPUT_PHI_LIGHT := "nc_phi_light"
const INPUT_PHI_INSPECT := "nc_phi_inspect"
const INPUT_PHI_PING := "nc_phi_ping"
const INPUT_PHI_SCAN := "nc_phi_scan"
const INPUT_PHI_MARK := "nc_phi_mark"

var _last_move := 999.0
var _last_jump := false
var _last_crouch := false

func _ready() -> void:
	_ensure_keyboard_actions()
	_publish_current_state(true)

func _physics_process(_delta: float) -> void:
	_publish_current_state(false)

	if Input.is_action_just_pressed(INPUT_LIGHT_ATTACK):
		_submit(actor_id, "LIGHT_ATTACK", {})

	if Input.is_action_just_pressed(INPUT_HEAVY_ATTACK):
		_submit(actor_id, "HEAVY_ATTACK", {})

	if Input.is_action_just_pressed(INPUT_DODGE):
		_submit(actor_id, "DODGE", {})

	if Input.is_action_just_pressed(INPUT_INTERACT):
		_submit(actor_id, "INTERACT", {})

	if Input.is_action_just_pressed(INPUT_PHI_FOLLOW):
		_submit(phi_actor_id, "FOLLOW", {})

	if Input.is_action_just_pressed(INPUT_PHI_HOLD):
		_submit(phi_actor_id, "HOLD", {})

	if Input.is_action_just_pressed(INPUT_PHI_LIGHT):
		_submit(phi_actor_id, "LIGHT", {"toggle": true})

	if Input.is_action_just_pressed(INPUT_PHI_INSPECT):
		_submit(phi_actor_id, "INSPECT", {})

	if Input.is_action_just_pressed(INPUT_PHI_PING):
		_submit(phi_actor_id, "PING", {})

	if Input.is_action_just_pressed(INPUT_PHI_SCAN):
		_submit(phi_actor_id, "SCAN", {"mode": "enemy_read"})

	if Input.is_action_just_pressed(INPUT_PHI_MARK):
		_submit(phi_actor_id, "MARK", {})

func _publish_current_state(force: bool) -> void:
	var move_axis := Input.get_axis(INPUT_LEFT, INPUT_RIGHT)
	if absf(move_axis) < 0.05:
		move_axis = 0.0

	var jump_pressed := Input.is_action_pressed(INPUT_JUMP)
	var crouch_pressed := Input.is_action_pressed(INPUT_CROUCH)

	if force or not is_equal_approx(move_axis, _last_move):
		_submit(actor_id, "MOVE", {"x": move_axis})
		_last_move = move_axis

	if force or jump_pressed != _last_jump:
		_submit(actor_id, "JUMP", {"pressed": jump_pressed})
		_last_jump = jump_pressed

	if force or crouch_pressed != _last_crouch:
		_submit(actor_id, "CROUCH", {"pressed": crouch_pressed})
		_last_crouch = crouch_pressed

func _submit(target_actor_id: String, action_name: String, payload: Dictionary) -> void:
	var bus := get_node_or_null("/root/ActionBus")
	if bus == null:
		return

	bus.submit({
		"source": source_id,
		"actor": target_actor_id,
		"action": action_name,
		"payload": payload
	})

func _ensure_keyboard_actions() -> void:
	_ensure_key_action(INPUT_LEFT, [KEY_A, KEY_LEFT])
	_ensure_key_action(INPUT_RIGHT, [KEY_D, KEY_RIGHT])
	_ensure_key_action(INPUT_JUMP, [KEY_SPACE, KEY_W, KEY_UP])
	_ensure_key_action(INPUT_CROUCH, [KEY_S, KEY_DOWN])
	_ensure_key_action(INPUT_LIGHT_ATTACK, [KEY_J, KEY_Z])
	_ensure_key_action(INPUT_HEAVY_ATTACK, [KEY_K, KEY_X])
	_ensure_key_action(INPUT_DODGE, [KEY_C, KEY_L])
	_ensure_key_action(INPUT_INTERACT, [KEY_R])

	_ensure_key_action(INPUT_PHI_FOLLOW, [KEY_F])
	_ensure_key_action(INPUT_PHI_HOLD, [KEY_H])
	_ensure_key_action(INPUT_PHI_LIGHT, [KEY_Q])
	_ensure_key_action(INPUT_PHI_INSPECT, [KEY_E])
	_ensure_key_action(INPUT_PHI_PING, [KEY_P])
	_ensure_key_action(INPUT_PHI_SCAN, [KEY_T])
	_ensure_key_action(INPUT_PHI_MARK, [KEY_G])

func _ensure_key_action(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	if not InputMap.action_get_events(action_name).is_empty():
		return

	for keycode in keycodes:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(keycode)
		InputMap.action_add_event(action_name, key_event)
