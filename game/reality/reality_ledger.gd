extends Node

signal record_added(record: Dictionary)
signal record_updated(record: Dictionary)
signal contradiction_detected(record: Dictionary)
signal ledger_loaded(summary: Dictionary)

const SCHEMA := "night-circuit/reality-ledger/0.1"
const SAVE_PATH := "user://night_circuit_reality_ledger_v1.json"

const ALLOWED_RECORD_TYPES := [
	"claim",
	"observation",
	"evidence",
	"inference",
	"contradiction",
	"verified"
]

var _sequence := 0
var _records: Array = []
var _record_index: Dictionary = {}
var _fingerprints: Dictionary = {}
var _contradiction_pairs: Dictionary = {}

func _ready() -> void:
	_load_from_disk()
	ledger_loaded.emit(summary())

func record_claim(raw: Dictionary) -> Dictionary:
	var record := raw.duplicate(true)
	record["type"] = "claim"
	return append_record(record)

func record_observation(raw: Dictionary) -> Dictionary:
	var record := raw.duplicate(true)
	record["type"] = "observation"
	return append_record(record)

func record_evidence(raw: Dictionary) -> Dictionary:
	var record := raw.duplicate(true)
	record["type"] = "evidence"
	return append_record(record)

func add_inference(raw: Dictionary) -> Dictionary:
	var record := raw.duplicate(true)
	record["type"] = "inference"
	return append_record(record)

func mark_verified(raw: Dictionary) -> Dictionary:
	var record := raw.duplicate(true)
	record["type"] = "verified"
	return append_record(record)

func append_record(raw: Dictionary) -> Dictionary:
	var record_type := str(raw.get("type", "")).to_lower().strip_edges()
	if record_type not in ALLOWED_RECORD_TYPES:
		return {
			"accepted": false,
			"reason": "unsupported_record_type"
		}

	var provenance = raw.get("provenance", {})
	if not (provenance is Dictionary):
		return {
			"accepted": false,
			"reason": "provenance_must_be_dictionary"
		}

	var data = raw.get("data", {})
	if not (data is Dictionary):
		return {
			"accepted": false,
			"reason": "data_must_be_dictionary"
		}

	var normalized := {
		"schema": SCHEMA,
		"type": record_type,
		"subject": str(raw.get("subject", "")).strip_edges(),
		"value": raw.get("value", null),
		"confidence": clampf(float(raw.get("confidence", 0.5)), 0.0, 1.0),
		"provenance": provenance.duplicate(true),
		"data": data.duplicate(true),
		"first_seen_unix": int(Time.get_unix_time_from_system()),
		"last_seen_unix": int(Time.get_unix_time_from_system()),
		"repeat_count": 1
	}

	var fingerprint := str(raw.get("dedupe_key", "")).strip_edges()
	if fingerprint.is_empty():
		fingerprint = _fingerprint(normalized)

	if _fingerprints.has(fingerprint):
		return _repeat_record(str(_fingerprints[fingerprint]))

	_sequence += 1
	normalized["sequence"] = _sequence
	normalized["record_id"] = "reality-%08d" % _sequence
	normalized["fingerprint"] = fingerprint

	var index := _records.size()
	_records.append(normalized)
	_record_index[normalized["record_id"]] = index
	_fingerprints[fingerprint] = normalized["record_id"]

	_save_to_disk()
	record_added.emit(normalized.duplicate(true))

	if record_type == "claim":
		_derive_contradictions(normalized)

	return normalized.duplicate(true)

func records() -> Array:
	return _records.duplicate(true)

func latest() -> Dictionary:
	if _records.is_empty():
		return {}
	return _records[-1].duplicate(true)

func records_by_type(record_type: String) -> Array:
	var result: Array = []
	for record in _records:
		if str(record.get("type", "")) == record_type:
			result.append(record.duplicate(true))
	return result

func records_for_subject(subject: String) -> Array:
	var result: Array = []
	for record in _records:
		if str(record.get("subject", "")) == subject:
			result.append(record.duplicate(true))
	return result

func contradictions() -> Array:
	return records_by_type("contradiction")

func summary() -> Dictionary:
	var counts := {}
	for record_type in ALLOWED_RECORD_TYPES:
		counts[record_type] = 0

	var subjects := {}
	for record in _records:
		var record_type := str(record.get("type", ""))
		counts[record_type] = int(counts.get(record_type, 0)) + 1
		var subject := str(record.get("subject", ""))
		if not subject.is_empty():
			subjects[subject] = true

	var latest_record := latest()
	return {
		"schema": SCHEMA,
		"record_count": _records.size(),
		"counts": counts,
		"contradiction_count": int(counts.get("contradiction", 0)),
		"subject_count": subjects.size(),
		"latest_record_id": latest_record.get("record_id", ""),
		"latest_type": latest_record.get("type", ""),
		"latest_subject": latest_record.get("subject", "")
	}

func public_summary() -> Dictionary:
	var full := summary()
	return {
		"record_count": full["record_count"],
		"claim_count": full["counts"].get("claim", 0),
		"observation_count": full["counts"].get("observation", 0),
		"evidence_count": full["counts"].get("evidence", 0),
		"contradiction_count": full["contradiction_count"],
		"subject_count": full["subject_count"],
		"latest_type": full["latest_type"],
		"latest_subject": full["latest_subject"]
	}

func clear_all() -> void:
	_sequence = 0
	_records.clear()
	_record_index.clear()
	_fingerprints.clear()
	_contradiction_pairs.clear()
	_save_to_disk()

func _repeat_record(record_id: String) -> Dictionary:
	if not _record_index.has(record_id):
		return {
			"accepted": false,
			"reason": "dedupe_index_corrupt"
		}

	var index := int(_record_index[record_id])
	var record: Dictionary = _records[index]
	record["repeat_count"] = int(record.get("repeat_count", 1)) + 1
	record["last_seen_unix"] = int(Time.get_unix_time_from_system())
	_records[index] = record
	_save_to_disk()
	record_updated.emit(record.duplicate(true))
	return record.duplicate(true)

func _derive_contradictions(new_claim: Dictionary) -> void:
	var subject := str(new_claim.get("subject", ""))
	if subject.is_empty():
		return

	for existing in _records:
		if str(existing.get("type", "")) != "claim":
			continue
		if str(existing.get("record_id", "")) == str(new_claim.get("record_id", "")):
			continue
		if str(existing.get("subject", "")) != subject:
			continue
		if _values_equal(existing.get("value", null), new_claim.get("value", null)):
			continue

		var first_id := str(existing.get("record_id", ""))
		var second_id := str(new_claim.get("record_id", ""))
		var pair_ids := [first_id, second_id]
		pair_ids.sort()
		var pair_key := "%s|%s|%s" % [subject, pair_ids[0], pair_ids[1]]

		if _contradiction_pairs.has(pair_key):
			continue
		_contradiction_pairs[pair_key] = true

		var contradiction := append_record({
			"type": "contradiction",
			"subject": subject,
			"value": "conflict",
			"confidence": minf(
				float(existing.get("confidence", 0.5)),
				float(new_claim.get("confidence", 0.5))
			),
			"provenance": {
				"source_kind": "derived",
				"source_id": "reality_ledger",
				"method": "same_subject_different_value"
			},
			"data": {
				"record_ids": pair_ids,
				"values": [
					existing.get("value", null),
					new_claim.get("value", null)
				],
				"sources": [
					existing.get("provenance", {}).get("source_id", "unknown"),
					new_claim.get("provenance", {}).get("source_id", "unknown")
				]
			},
			"dedupe_key": "contradiction|%s" % pair_key
		})

		if str(contradiction.get("type", "")) == "contradiction":
			contradiction_detected.emit(contradiction.duplicate(true))

func _values_equal(left, right) -> bool:
	return JSON.stringify(left) == JSON.stringify(right)

func _fingerprint(record: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s" % [
		record.get("type", ""),
		record.get("subject", ""),
		JSON.stringify(record.get("value", null)),
		record.get("provenance", {}).get("source_id", ""),
		record.get("provenance", {}).get("phase", ""),
		JSON.stringify(record.get("data", {}))
	]

func _save_to_disk() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify({
		"schema": SCHEMA,
		"sequence": _sequence,
		"records": _records
	}, "\t"))

func _load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	if str(parsed.get("schema", "")) != SCHEMA:
		return

	var loaded_records = parsed.get("records", [])
	if not (loaded_records is Array):
		return

	_sequence = int(parsed.get("sequence", 0))
	_records = loaded_records.duplicate(true)
	_record_index.clear()
	_fingerprints.clear()
	_contradiction_pairs.clear()

	for index in range(_records.size()):
		var record = _records[index]
		if not (record is Dictionary):
			continue

		var record_id := str(record.get("record_id", ""))
		var fingerprint := str(record.get("fingerprint", ""))
		if not record_id.is_empty():
			_record_index[record_id] = index
		if not fingerprint.is_empty():
			_fingerprints[fingerprint] = record_id

		if str(record.get("type", "")) == "contradiction":
			var ids = record.get("data", {}).get("record_ids", [])
			if ids is Array and ids.size() == 2:
				var pair_ids := [str(ids[0]), str(ids[1])]
				pair_ids.sort()
				var pair_key := "%s|%s|%s" % [
					record.get("subject", ""),
					pair_ids[0],
					pair_ids[1]
				]
				_contradiction_pairs[pair_key] = true
