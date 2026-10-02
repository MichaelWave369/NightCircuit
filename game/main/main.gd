extends Node2D

var _elapsed := 0.0
var _last_receipt: Dictionary = {}
@onready var receipt_label: Label = $HUD/MarginContainer/VBoxContainer/ReceiptLabel

func _ready() -> void:
	var bus := get_node_or_null("/root/ActionBus")
	if bus != null:
		_last_receipt = bus.submit({
			"source": "system",
			"actor": "system",
			"action": "BOOT",
			"payload": {"milestone": "NC-001"}
		})
		_update_receipt_label()
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
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
			"target": "skeleton_anchor",
			"room": "nc001_boot"
		}
	})
	_update_receipt_label()

func _update_receipt_label() -> void:
	if _last_receipt.is_empty():
		receipt_label.text = "RECEIPT: waiting"
		return

	var result := "ACCEPTED" if _last_receipt.get("accepted", false) else "REJECTED"
	receipt_label.text = "RECEIPT #%s: %s // %s" % [
		_last_receipt.get("sequence", "?"),
		result,
		_last_receipt.get("reason", "unknown")
	]

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("#07101b"))

	# Distant Night Circuit skyline / drainage ribs.
	for i in range(10):
		var x := 40.0 + float(i) * 132.0
		var h := 90.0 + float((i * 47) % 170)
		draw_rect(
			Rect2(Vector2(x, viewport_size.y - 150.0 - h), Vector2(72.0, h)),
			Color(0.06, 0.09, 0.14, 1.0)
		)

	# Ground and prototype actor markers.
	draw_rect(
		Rect2(Vector2(0.0, viewport_size.y - 118.0), Vector2(viewport_size.x, 118.0)),
		Color(0.035, 0.045, 0.065, 1.0)
	)
	draw_rect(
		Rect2(Vector2(0.0, viewport_size.y - 124.0), Vector2(viewport_size.x, 6.0)),
		Color(0.19, 0.29, 0.38, 1.0)
	)

	var hunter_pos := Vector2(viewport_size.x * 0.55, viewport_size.y - 164.0)
	draw_rect(Rect2(hunter_pos - Vector2(14.0, 44.0), Vector2(28.0, 44.0)), Color(0.58, 0.64, 0.72, 1.0))
	draw_circle(hunter_pos - Vector2(0.0, 53.0), 13.0, Color(0.70, 0.74, 0.80, 1.0))

	var orbit := Vector2(cos(_elapsed * 1.4), sin(_elapsed * 1.8)) * Vector2(22.0, 11.0)
	var phi_pos := hunter_pos + Vector2(90.0, -54.0) + orbit
	draw_circle(phi_pos, 20.0, Color(0.17, 0.56, 0.69, 0.22))
	draw_arc(phi_pos, 20.0, 0.0, TAU, 48, Color(0.44, 0.82, 0.93, 1.0), 3.0)
	draw_string(ThemeDB.fallback_font, phi_pos + Vector2(-9.0, 7.0), "Φ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.84, 0.96, 1.0, 1.0))
