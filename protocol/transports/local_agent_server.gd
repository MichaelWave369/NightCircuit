extends Node
class_name NightCircuitLocalAgentServer

signal server_state_changed(snapshot: Dictionary)
signal message_processed(summary: Dictionary)

const BIND_ADDRESS := "127.0.0.1"
const PORT := 36970
const SOURCE_ID := "agent"
const SEAT_ACTOR := "phi_bot"

const MAX_CLIENTS := 1
const MAX_LINE_CHARS := 65536
const MAX_MESSAGES_PER_FRAME := 16
const MIN_ACTION_INTERVAL_MS := 50

var _server := TCPServer.new()
var _clients: Array = []
var _buffers: Dictionary = {}
var _last_action_ms: Dictionary = {}
var _request_sequence := 0
var _state := "stopped"
var _last_message := "idle"

func _ready() -> void:
	start_server()

func _exit_tree() -> void:
	stop_server()

func start_server() -> bool:
	if _state == "listening":
		return true

	var error := _server.listen(PORT, BIND_ADDRESS)
	if error != OK:
		_state = "error"
		_last_message = "listen_failed:%s" % error
		_emit_state()
		return false

	_state = "listening"
	_last_message = "ready"
	_emit_state()
	return true

func stop_server() -> void:
	for peer in _clients:
		if peer is StreamPeerTCP:
			peer.disconnect_from_host()

	_clients.clear()
	_buffers.clear()
	_last_action_ms.clear()

	if _server.is_listening():
		_server.stop()

	_state = "stopped"
	_last_message = "stopped"
	_emit_state()

func _process(_delta: float) -> void:
	if _state != "listening":
		return

	_accept_connections()

	for index in range(_clients.size() - 1, -1, -1):
		var peer = _clients[index]
		if not (peer is StreamPeerTCP):
			_drop_client(index)
			continue

		peer.poll()

		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_drop_client(index)
			continue

		var available := peer.get_available_bytes()
		if available <= 0:
			continue

		var peer_id := peer.get_instance_id()
		var buffer := str(_buffers.get(peer_id, ""))
		buffer += peer.get_utf8_string(available)
		_buffers[peer_id] = buffer

		if not _drain_peer(peer):
			_drop_client(index)

func server_snapshot() -> Dictionary:
	return {
		"state": _state,
		"bind": BIND_ADDRESS,
		"port": PORT,
		"source": SOURCE_ID,
		"seat_actor": SEAT_ACTOR,
		"clients": _clients.size(),
		"last_message": _last_message,
		"max_clients": MAX_CLIENTS,
		"min_action_interval_ms": MIN_ACTION_INTERVAL_MS
	}

func _accept_connections() -> void:
	while _server.is_connection_available():
		var peer = _server.take_connection()
		if peer == null:
			continue

		if _clients.size() >= MAX_CLIENTS:
			_send_transport_error(peer, "", "seat_occupied")
			peer.disconnect_from_host()
			continue

		_clients.append(peer)
		_buffers[peer.get_instance_id()] = ""
		_last_message = "client_connected"
		_emit_state()

func _drain_peer(peer: StreamPeerTCP) -> bool:
	var peer_id := peer.get_instance_id()
	var buffer := str(_buffers.get(peer_id, ""))
	var processed := 0

	while processed < MAX_MESSAGES_PER_FRAME:
		var newline := buffer.find("\n")
		if newline < 0:
			break

		var line := buffer.substr(0, newline).strip_edges()
		buffer = buffer.substr(newline + 1)

		if line.is_empty():
			continue

		_process_line(peer, line)
		processed += 1

	_buffers[peer_id] = buffer

	if buffer.length() > MAX_LINE_CHARS:
		_send_transport_error(peer, "", "message_too_large")
		peer.disconnect_from_host()
		return false

	return true

func _process_line(peer: StreamPeerTCP, line: String) -> void:
	if line.length() > MAX_LINE_CHARS:
		_send_transport_error(peer, "", "message_too_large")
		return

	var json := JSON.new()
	var parse_error := json.parse(line)
	if parse_error != OK:
		_send_transport_error(peer, "", "invalid_json")
		return

	var parsed = json.data
	if not (parsed is Dictionary):
		_send_transport_error(peer, "", "message_must_be_object")
		return

	var message: Dictionary = parsed.duplicate(true)
	var request_id := str(message.get("request_id", "")).strip_edges()
	if request_id.is_empty():
		_request_sequence += 1
		request_id = "local-%08d" % _request_sequence
		message["request_id"] = request_id

	var message_type := str(message.get("type", "")).to_lower().strip_edges()

	if message_type == "observe" or message_type == "act":
		var requested_actor := str(message.get("actor", "")).to_lower().strip_edges()
		if not requested_actor.is_empty() and requested_actor != SEAT_ACTOR:
			_send_transport_error(peer, request_id, "seat_actor_mismatch")
			return
		message["actor"] = SEAT_ACTOR

	if message_type == "act" and not _action_rate_allowed(peer):
		_send_transport_error(peer, request_id, "action_rate_limited")
		return

	var protocol := get_node_or_null("/root/PlayerProtocol")
	if protocol == null:
		_send_transport_error(peer, request_id, "player_protocol_unavailable")
		return

	var response: Dictionary = protocol.handle_adapter_message(SOURCE_ID, message)
	response = _augment_response(response, message_type)
	_send(peer, response)

	_last_message = _message_summary(message, response)
	message_processed.emit({
		"request_id": request_id,
		"type": message_type,
		"actor": message.get("actor", ""),
		"action": message.get("action", ""),
		"ok": response.get("ok", false)
	})
	_emit_state()

func _augment_response(response: Dictionary, message_type: String) -> Dictionary:
	var augmented := response.duplicate(true)

	if message_type == "describe" and bool(augmented.get("ok", false)):
		var body: Dictionary = augmented.get("body", {}).duplicate(true)
		var surfaces: Dictionary = body.get("action_surfaces", {})
		body["seat"] = {
			"transport": "tcp-jsonl",
			"bind": BIND_ADDRESS,
			"port": PORT,
			"source": SOURCE_ID,
			"actor": SEAT_ACTOR,
			"observe_actor": SEAT_ACTOR,
			"act_actor": SEAT_ACTOR,
			"action_surface": surfaces.get(SEAT_ACTOR, [])
		}
		augmented["body"] = body

	return augmented

func _action_rate_allowed(peer: StreamPeerTCP) -> bool:
	var peer_id := peer.get_instance_id()
	var now := Time.get_ticks_msec()
	var last := int(_last_action_ms.get(peer_id, -1000000))

	if now - last < MIN_ACTION_INTERVAL_MS:
		return false

	_last_action_ms[peer_id] = now
	return true

func _message_summary(message: Dictionary, response: Dictionary) -> String:
	var message_type := str(message.get("type", "unknown"))
	if message_type == "act":
		return "%s:%s:%s" % [
			message_type,
			message.get("action", "?"),
			"ok" if response.get("ok", false) else "error"
		]

	return "%s:%s" % [
		message_type,
		"ok" if response.get("ok", false) else "error"
	]

func _send_transport_error(peer: StreamPeerTCP, request_id: String, reason: String) -> void:
	_send(peer, {
		"schema": "phi-player-protocol/response/0.3",
		"type": "transport_error",
		"request_id": request_id,
		"ok": false,
		"body": {
			"transport": "tcp-jsonl",
			"seat_actor": SEAT_ACTOR
		},
		"error": reason
	})
	_last_message = "error:%s" % reason
	_emit_state()

func _send(peer: StreamPeerTCP, response: Dictionary) -> void:
	var encoded := (JSON.stringify(response) + "\n").to_utf8_buffer()
	peer.put_data(encoded)

func _drop_client(index: int) -> void:
	if index < 0 or index >= _clients.size():
		return

	var peer = _clients[index]
	if peer is StreamPeerTCP:
		var peer_id := peer.get_instance_id()
		_buffers.erase(peer_id)
		_last_action_ms.erase(peer_id)
		peer.disconnect_from_host()

	_clients.remove_at(index)
	_last_message = "client_disconnected"
	_emit_state()

func _emit_state() -> void:
	server_state_changed.emit(server_snapshot())
