extends Node

signal event_recorded(event: Dictionary)
signal summary_exported(path: String)

const SCHEMA := "night-circuit/playtest-event/0.1"
const SUMMARY_SCHEMA := "night-circuit/playtest-summary/0.1"
const DIRECTORY := "user://playtests"

var _enabled := false
var _session_id := ""
var _session_started_unix := 0
var _session_started_ticks := 0
var _sequence := 0
var _event_counts: Dictionary = {}
var _log_path := ""
var _file: FileAccess

func _ready() -> void:
	_enabled = OS.is_debug_build() or OS.get_environment("NIGHT_CIRCUIT_PLAYTEST") == "1"
	if not _enabled:
		return

	_session_started_unix = int(Time.get_unix_time_from_system())
	_session_started_ticks = Time.get_ticks_msec()
	_session_id = "pt-%s" % _session_started_unix

	var absolute_dir := ProjectSettings.globalize_path(DIRECTORY)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	_log_path = "%s/night_circuit_%s.ndjson" % [DIRECTORY, _session_id]
	_file = FileAccess.open(_log_path, FileAccess.WRITE)

	_connect_sources()
	record_event("session.start", {
		"debug_build": OS.is_debug_build(),
		"platform": OS.get_name(),
		"engine": Engine.get_version_info()
	})

func _exit_tree() -> void:
	if not _enabled:
		return
	record_event("session.end", summary())
	flush()
	if _file != null:
		_file.close()

func is_enabled() -> bool:
	return _enabled

func current_log_path() -> String:
	return _log_path

func event_count() -> int:
	return _sequence

func record_event(event_name: String, data: Dictionary = {}) -> Dictionary:
	if not _enabled:
		return {}

	_sequence += 1
	var event := {
		"schema": SCHEMA,
		"session_id": _session_id,
		"sequence": _sequence,
		"event": event_name,
		"elapsed_ms": Time.get_ticks_msec() - _session_started_ticks,
		"unix_time": int(Time.get_unix_time_from_system()),
		"data": data.duplicate(true)
	}

	_event_counts[event_name] = int(_event_counts.get(event_name, 0)) + 1

	if _file != null:
		_file.store_line(JSON.stringify(event))
		_file.flush()

	event_recorded.emit(event.duplicate(true))
	return event

func mark(label: String, context: Dictionary = {}) -> Dictionary:
	var data := context.duplicate(true)
	data["label"] = label
	return record_event("tester.marker", data)

func flush() -> void:
	if _file != null:
		_file.flush()

func summary() -> Dictionary:
	return {
		"schema": SUMMARY_SCHEMA,
		"session_id": _session_id,
		"started_unix": _session_started_unix,
		"elapsed_ms": Time.get_ticks_msec() - _session_started_ticks if _session_started_ticks > 0 else 0,
		"event_count": _sequence,
		"event_counts": _event_counts.duplicate(true),
		"log_path": _log_path
	}

func export_summary() -> String:
	if not _enabled:
		return ""

	var path := "%s/night_circuit_%s_summary.json" % [DIRECTORY, _session_id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""

	file.store_string(JSON.stringify(summary(), "\t"))
	file.flush()
	file.close()
	summary_exported.emit(path)
	return path

func _connect_sources() -> void:
	var receipts := get_node_or_null("/root/ReceiptLedger")
	if receipts != null:
		receipts.receipt_appended.connect(_on_receipt_appended)

	var reality := get_node_or_null("/root/RealityLedger")
	if reality != null:
		reality.record_added.connect(_on_reality_record_added)
		reality.contradiction_detected.connect(_on_contradiction_detected)

	var run_save := get_node_or_null("/root/RunSave")
	if run_save != null:
		run_save.save_written.connect(_on_save_written)
		run_save.save_loaded.connect(_on_save_loaded)
		run_save.save_failed.connect(_on_save_failed)

	var protocol := get_node_or_null("/root/PlayerProtocol")
	if protocol != null:
		protocol.observation_created.connect(_on_observation_created)
		protocol.adapter_response_created.connect(_on_adapter_response_created)

func _on_receipt_appended(receipt: Dictionary) -> void:
	if str(receipt.get("receipt_type", "")) != "effect":
		return
	record_event("action.effect", {
		"action_id": receipt.get("action_id", ""),
		"source": receipt.get("source", ""),
		"actor": receipt.get("actor", ""),
		"action": receipt.get("action", ""),
		"status": receipt.get("status", ""),
		"reason": receipt.get("reason", "")
	})

func _on_reality_record_added(record: Dictionary) -> void:
	record_event("reality.record_added", {
		"record_id": record.get("record_id", ""),
		"type": record.get("type", ""),
		"subject": record.get("subject", ""),
		"confidence": record.get("confidence", 0.0),
		"source_kind": record.get("provenance", {}).get("source_kind", ""),
		"source_id": record.get("provenance", {}).get("source_id", "")
	})

func _on_contradiction_detected(record: Dictionary) -> void:
	record_event("reality.contradiction", {
		"record_id": record.get("record_id", ""),
		"subject": record.get("subject", ""),
		"confidence": record.get("confidence", 0.0)
	})

func _on_save_written(snapshot: Dictionary) -> void:
	record_event("run_save.written", {
		"world_id": snapshot.get("world_id", ""),
		"checkpoint": snapshot.get("checkpoint", "")
	})

func _on_save_loaded(snapshot: Dictionary) -> void:
	record_event("run_save.loaded", {
		"world_id": snapshot.get("world_id", ""),
		"checkpoint": snapshot.get("checkpoint", "")
	})

func _on_save_failed(reason: String) -> void:
	record_event("run_save.failed", {"reason": reason})

func _on_observation_created(observation: Dictionary) -> void:
	record_event("p3.observation", {
		"observation_id": observation.get("observation_id", ""),
		"actor": observation.get("actor", ""),
		"room": observation.get("room", ""),
		"visible_count": observation.get("visible_entities", []).size(),
		"signal_count": observation.get("signals", {}).size()
	})

func _on_adapter_response_created(response: Dictionary) -> void:
	if bool(response.get("ok", false)):
		return
	record_event("p3.error_response", {
		"type": response.get("type", ""),
		"request_id": response.get("request_id", ""),
		"error": response.get("error", "")
	})
