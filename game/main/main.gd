extends Node2D

var _last_receipt: Dictionary = {}
var _current_checkpoint := "drain_entry"
var _last_inspection: Dictionary = {}

@onready var world = $SewerTestRoom
@onready var hunter = $Hunter
@onready var phi_bot = $PhiBot
@onready var room_label: Label = $HUD/MarginContainer/VBoxContainer/RoomLabel
@onready var status_label: Label = $HUD/MarginContainer/VBoxContainer/Status
@onready var movement_state_label: Label = $HUD/MarginContainer/VBoxContainer/MovementState
@onready var combat_state_label: Label = $HUD/MarginContainer/VBoxContainer/CombatState
@onready var phi_state_label: Label = $HUD/MarginContainer/VBoxContainer/PhiState
@onready var inspection_state_label: Label = $HUD/MarginContainer/VBoxContainer/InspectionState
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

	if hunter != null:
		hunter.defeated.connect(_on_hunter_defeated)

	if phi_bot != null:
		phi_bot.bind_hunter(hunter)
		phi_bot.inspect_result.connect(_on_phi_inspect_result)

	var bus := get_node_or_null("/root/ActionBus")
	if bus != null:
		_last_receipt = bus.submit({
			"source": "system",
			"actor": "system",
			"action": "BOOT",
			"payload": {"milestone": "NC-005"}
		})
		_update_receipt_label()

	_update_readout()

func _process(_delta: float) -> void:
	_update_readout()

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
	_update_status(room_id)

func _on_checkpoint_changed(checkpoint_id: String) -> void:
	_current_checkpoint = checkpoint_id
	_update_status(world.current_room_id)

func _on_hunter_respawned(checkpoint_id: String) -> void:
	_current_checkpoint = checkpoint_id
	if phi_bot != null and phi_bot.has_method("reset_near_hunter"):
		phi_bot.reset_near_hunter()
	_update_status(world.current_room_id)

func _on_hunter_defeated() -> void:
	if world != null:
		world.respawn_hunter()

func _on_phi_inspect_result(result: Dictionary) -> void:
	_last_inspection = result.duplicate(true)
	_update_inspection_readout()

func _on_receipt_appended(receipt: Dictionary) -> void:
	_last_receipt = receipt
	_update_receipt_label()

func _update_status(room_id: String) -> void:
	var mode := "?"
	var form := "?"
	if phi_bot != null and phi_bot.has_method("actor_snapshot"):
		var snapshot: Dictionary = phi_bot.actor_snapshot()
		mode = str(snapshot.get("mode", "?"))
		form = str(snapshot.get("form", "?"))

	status_label.text = "CHECKPOINT: %s   |   CAMERA: %s   |   Φ-BOT: %s / %s" % [
		_current_checkpoint,
		room_id,
		mode,
		form
	]

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

func _update_readout() -> void:
	_update_hunter_readout()
	_update_phi_readout()
	_update_inspection_readout()

func _update_hunter_readout() -> void:
	if hunter == null or not hunter.has_method("actor_snapshot"):
		movement_state_label.text = "HUNTER: unavailable"
		combat_state_label.text = "COMBAT: unavailable"
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

	combat_state_label.text = "HP: %s/%s   COMBAT: %s   INVULN: %s" % [
		snapshot.get("health", "?"),
		snapshot.get("max_health", "?"),
		snapshot.get("combat", "?"),
		"YES" if snapshot.get("invulnerable", false) else "NO"
	]

func _update_phi_readout() -> void:
	if phi_bot == null or not phi_bot.has_method("actor_snapshot"):
		phi_state_label.text = "Φ-BOT: unavailable"
		return

	var snapshot: Dictionary = phi_bot.actor_snapshot()
	phi_state_label.text = "Φ-BOT: %s   MODE: %s   ENERGY: %.0f/%.0f   LIGHT: %s   SOURCE: %s" % [
		snapshot.get("form", "?"),
		snapshot.get("mode", "?"),
		float(snapshot.get("energy", 0.0)),
		float(snapshot.get("max_energy", 0.0)),
		"ON" if snapshot.get("light_enabled", false) else "OFF",
		snapshot.get("control_source", "?")
	]

func _update_inspection_readout() -> void:
	if _last_inspection.is_empty():
		inspection_state_label.text = "INSPECT: no observation"
		return

	var status := str(_last_inspection.get("status", "unknown"))
	if status == "observed":
		inspection_state_label.text = "INSPECT: %s // %s // CONF %.2f" % [
			_last_inspection.get("title", "unknown"),
			_last_inspection.get("category", "unknown"),
			float(_last_inspection.get("confidence", 0.0))
		]
	else:
		inspection_state_label.text = "INSPECT: %s" % status
