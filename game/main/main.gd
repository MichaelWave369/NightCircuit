extends Node2D

var _last_receipt: Dictionary = {}
var _current_checkpoint := "drain_entry"

@onready var world = $SewerTestRoom
@onready var hunter = $Hunter
@onready var room_label: Label = $HUD/MarginContainer/VBoxContainer/RoomLabel
@onready var status_label: Label = $HUD/MarginContainer/VBoxContainer/Status
@onready var movement_state_label: Label = $HUD/MarginContainer/VBoxContainer/MovementState
@onready var receipt_label: Label = $HUD/MarginContainer/VBoxContainer/ReceiptLabel

func _ready() -> void:
	var ledger := get_node_or_null("/root/ReceiptLedger")
	if ledger != null:
		var receipt_callback := Callable(self, "_on_receipt_appended")
		if not ledger.is_connected("receipt_appended", receipt_callback):
			ledger.connect("receipt_appended", receipt_callback)

	if world != null:
		world.room_changed.connect(_on_room_changed)
		world.checkpoint_changed.connect(_on_checkpoint_changed)
		world.hunter_respawned.connect(_on_hunter_respawned)
		world.bind_hunter(hunter)

	var bus := get_node_or_null("/root/ActionBus")
	if bus != null:
		_last_receipt = bus.submit({
			"source": "system",
			"actor": "system",
			"action": "BOOT",
			"payload": {"milestone": "NC-003"}
		})
		_update_receipt_label()

	_update_movement_readout()

func _process(_delta: float) -> void:
	_update_movement_readout()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_send_phi_ping()

func _send_phi_ping() -> void:
	var bus := get_node_or_null("/root/ActionBus")
	if bus == null:
		receipt_label.text = "RECEIPT: ActionBus unavailable"
		return

	var room_id := "unknown"
	if world != null:
		room_id = world.current_room_id

	_last_receipt = bus.submit({
		"source": "human",
		"actor": "phi_bot",
		"action": "PING",
		"payload": {
			"target": "sewer_test_anchor",
			"room": room_id
		}
	})
	_update_receipt_label()

func _on_room_changed(room_id: String, room_title: String) -> void:
	room_label.text = "ROOM: %s" % room_title
	status_label.text = "CHECKPOINT: %s   |   CAMERA: %s   |   RESPAWN: ARMED" % [
		_current_checkpoint,
		room_id
	]

func _on_checkpoint_changed(checkpoint_id: String) -> void:
	_current_checkpoint = checkpoint_id
	status_label.text = "CHECKPOINT: %s   |   CAMERA: %s   |   RESPAWN: ARMED" % [
		_current_checkpoint,
		world.current_room_id
	]

func _on_hunter_respawned(checkpoint_id: String) -> void:
	_current_checkpoint = checkpoint_id
	status_label.text = "RESPAWNED: %s   |   CAMERA: %s" % [
		_current_checkpoint,
		world.current_room_id
	]

func _on_receipt_appended(receipt: Dictionary) -> void:
	_last_receipt = receipt
	_update_receipt_label()

func _update_receipt_label() -> void:
	if _last_receipt.is_empty():
		receipt_label.text = "RECEIPT: waiting"
		return

	var result := "ACCEPTED" if _last_receipt.get("accepted", false) else "REJECTED"
	receipt_label.text = "RECEIPT #%s: %s // %s.%s // %s" % [
		_last_receipt.get("sequence", "?"),
		result,
		_last_receipt.get("actor", "?"),
		_last_receipt.get("action", "?"),
		_last_receipt.get("reason", "unknown")
	]

func _update_movement_readout() -> void:
	if hunter == null or not hunter.has_method("actor_snapshot"):
		movement_state_label.text = "HUNTER: unavailable"
		return

	var snapshot: Dictionary = hunter.actor_snapshot()
	var pos = snapshot.get("position", [0.0, 0.0])
	var vel = snapshot.get("velocity", [0.0, 0.0])

	movement_state_label.text = "HUNTER: %s   POS %.0f,%.0f   VEL %.0f,%.0f" % [
		snapshot.get("locomotion", "?"),
		float(pos[0]),
		float(pos[1]),
		float(vel[0]),
		float(vel[1])
	]
