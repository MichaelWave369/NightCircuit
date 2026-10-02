extends Node2D

var _elapsed := 0.0
var _last_receipt: Dictionary = {}

@onready var hunter = $Hunter
@onready var movement_state_label: Label = $HUD/MarginContainer/VBoxContainer/MovementState
@onready var receipt_label: Label = $HUD/MarginContainer/VBoxContainer/ReceiptLabel

func _ready() -> void:
	var ledger := get_node_or_null("/root/ReceiptLedger")
	if ledger != null:
		var callback := Callable(self, "_on_receipt_appended")
		if not ledger.is_connected("receipt_appended", callback):
			ledger.connect("receipt_appended", callback)

	var bus := get_node_or_null("/root/ActionBus")
	if bus != null:
		_last_receipt = bus.submit({
			"source": "system",
			"actor": "system",
			"action": "BOOT",
			"payload": {"milestone": "NC-002"}
		})
		_update_receipt_label()

	_update_movement_readout()
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	_update_movement_readout()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_send_phi_ping()

func _send_phi_ping() -> void:
	var bus := get_node_or_null("/root/ActionBus")
	if bus == null:
		receipt_label.text = "RECEIPT: ActionBus unavailable"
		return

	_last_receipt = bus.submit({
		"source": "human",
		"actor": "phi_bot",
		"action": "PING",
		"payload": {
			"target": "movement_lab_anchor",
			"room": "nc002_movement_lab"
		}
	})
	_update_receipt_label()

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

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("#07101b"))

	# Distant drainage ribs.
	for i in range(10):
		var x := 40.0 + float(i) * 132.0
		var h := 90.0 + float((i * 47) % 170)
		draw_rect(
			Rect2(Vector2(x, viewport_size.y - 150.0 - h), Vector2(72.0, h)),
			Color(0.06, 0.09, 0.14, 1.0)
		)

	# Collision geometry for the NC-002 movement lab.
	draw_rect(Rect2(Vector2(0.0, 620.0), Vector2(1280.0, 100.0)), Color(0.035, 0.045, 0.065, 1.0))
	draw_rect(Rect2(Vector2(790.0, 460.0), Vector2(280.0, 160.0)), Color(0.08, 0.105, 0.14, 1.0))
	draw_rect(Rect2(Vector2(1080.0, 368.0), Vector2(180.0, 24.0)), Color(0.09, 0.12, 0.16, 1.0))
	draw_line(Vector2(0.0, 620.0), Vector2(1280.0, 620.0), Color(0.19, 0.29, 0.38, 1.0), 5.0)
	draw_line(Vector2(790.0, 460.0), Vector2(1070.0, 460.0), Color(0.29, 0.48, 0.58, 1.0), 4.0)

	draw_string(ThemeDB.fallback_font, Vector2(804.0, 447.0), "LEDGE GRAB", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.52, 0.70, 0.79, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(1090.0, 354.0), "WALL-KICK SHELF", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.52, 0.70, 0.79, 1.0))

	# Φ-Bot is still only a reserved seat in NC-002.
	if hunter != null:
		var orbit := Vector2(cos(_elapsed * 1.4), sin(_elapsed * 1.8)) * Vector2(22.0, 11.0)
		var phi_pos := hunter.global_position + Vector2(82.0, -58.0) + orbit
		draw_circle(phi_pos, 20.0, Color(0.17, 0.56, 0.69, 0.18))
		draw_arc(phi_pos, 20.0, 0.0, TAU, 48, Color(0.44, 0.82, 0.93, 0.72), 2.0)
		draw_string(ThemeDB.fallback_font, phi_pos + Vector2(-9.0, 7.0), "Φ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.84, 0.96, 1.0, 0.85))
