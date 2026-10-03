extends Node

signal save_written(snapshot: Dictionary)
signal save_loaded(snapshot: Dictionary)
signal save_failed(reason: String)

const SCHEMA := "night-circuit/run-save/0.1"
const SAVE_PATH := "user://night_circuit_run_save_v1.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_snapshot(snapshot: Dictionary) -> Dictionary:
	var normalized := snapshot.duplicate(true)
	normalized["schema"] = SCHEMA
	normalized["saved_unix"] = int(Time.get_unix_time_from_system())

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var failed := {
			"ok": false,
			"reason": "save_open_failed"
		}
		save_failed.emit(failed["reason"])
		return failed

	file.store_string(JSON.stringify(normalized, "\t"))
	file.flush()
	save_written.emit(normalized.duplicate(true))

	return {
		"ok": true,
		"snapshot": normalized
	}

func load_snapshot() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {
			"ok": false,
			"reason": "save_missing"
		}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"reason": "save_open_failed"
		}

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {
			"ok": false,
			"reason": "save_invalid_json"
		}

	if str(parsed.get("schema", "")) != SCHEMA:
		return {
			"ok": false,
			"reason": "save_schema_mismatch",
			"found_schema": parsed.get("schema", "")
		}

	var snapshot: Dictionary = parsed.duplicate(true)
	save_loaded.emit(snapshot.duplicate(true))
	return {
		"ok": true,
		"snapshot": snapshot
	}

func clear_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true
	return DirAccess.remove_absolute(SAVE_PATH) == OK
