extends Node2D

var world: Node = null
var _current_checkpoint := "drain_entry"
var _last_inspection: Dictionary = {}
var _last_decision: Dictionary = {}
var _last_effect: Dictionary = {}
var _protocol_observe_count := 0
var _last_dialogue: Dictionary = {}
var _boss_warning_timer := 0.0

@onready var sewer_world = $SewerTestRoom
@onready var ash_village = $AshVillage
@onready var fallen_arena = $FallenArena
@onready var hunter = $Hunter
@onready var phi_bot = $PhiBot
@onready var runtime_observation_provider = $RuntimeObservationProvider
@onready var local_agent_server = $LocalAgentServer
@onready var room_label: Label = $HUD/MarginContainer/VBoxContainer/RoomLabel
@onready var status_label: Label = $HUD/MarginContainer/VBoxContainer/Status
@onready var movement_state_label: Label = $HUD/MarginContainer/VBoxContainer/MovementState
@onready var combat_state_label: Label = $HUD/MarginContainer/VBoxContainer/CombatState
@onready var phi_state_label: Label = $HUD/MarginContainer/VBoxContainer/PhiState
@onready var inspection_state_label: Label = $HUD/MarginContainer/VBoxContainer/InspectionState
@onready var receipt_label: Label = $HUD/MarginContainer/VBoxContainer/ReceiptLabel
@onready var replay_state_label: Label = $HUD/MarginContainer/VBoxContainer/ReplayState
@onready var protocol_state_label: Label = $HUD/MarginContainer/VBoxContainer/ProtocolState
@onready var agent_seat_state_label: Label = $HUD/MarginContainer/VBoxContainer/AgentSeatState
@onready var dialogue_state_label: Label = $HUD/MarginContainer/VBoxContainer/DialogueState
@onready var world_state_label: Label = $HUD/MarginContainer/VBoxContainer/WorldState
@onready var ledger_state_label: Label = $HUD/MarginContainer/VBoxContainer/LedgerState
@onready var boss_state_label: Label = $HUD/MarginContainer/VBoxContainer/BossState
@onready var scout_state_label: Label = $HUD/MarginContainer/VBoxContainer/ScoutState

func _ready() -> void:
	var receipt_ledger := get_node_or_null("/root/ReceiptLedger")
	if receipt_ledger != null:
		var receipt_callback := Callable(self, "_on_receipt_appended")
		if not receipt_ledger.is_connected("receipt_appended", receipt_callback):
			receipt_ledger.connect("receipt_appended", receipt_callback)

	var reality_ledger := get_node_or_null("/root/RealityLedger")
	if reality_ledger != null:
		var added_callback := Callable(self, "_on_reality_record_changed")
		var updated_callback := Callable(self, "_on_reality_record_changed")
		var contradiction_callback := Callable(self, "_on_contradiction_detected")
		if not reality_ledger.is_connected("record_added", added_callback):
			reality_ledger.connect("record_added", added_callback)
		if not reality_ledger.is_connected("record_updated", updated_callback):
			reality_ledger.connect("record_updated", updated_callback)
		if not reality_ledger.is_connected("contradiction_detected", contradiction_callback):
			reality_ledger.connect("contradiction_detected", contradiction_callback)

	_connect_world(sewer_world)
	_connect_world(ash_village)
	_connect_world(fallen_arena)

	world = sewer_world
	sewer_world.set_active(true)
	ash_village.set_active(false)
	fallen_arena.set_active(false)
	sewer_world.bind_hunter(hunter)

	if hunter != null:
		hunter.defeated.connect(_on_hunter_defeated)
		hunter.interaction_requested.connect(_on_hunter_interaction_requested)

	if phi_bot != null:
		phi_bot.bind_hunter(hunter)
		phi_bot.bind_world(world)
		phi_bot.inspect_result.connect(_on_phi_inspect_result)
		phi_bot.scout_result.connect(_on_phi_scout_result)
		phi_bot.form_changed.connect(_on_phi_form_changed)

	if runtime_observation_provider != null:
		runtime_observation_provider.bind(world, hunter, phi_bot)

	if local_agent_server != null:
		local_agent_server.server_state_changed.connect(_on_agent_server_state_changed)
		local_agent_server.message_processed.connect(_on_agent_message_processed)

	var bus := get_node_or_null("/root/ActionBus")
	if bus != null:
		bus.submit({
			"source": "system",
			"actor": "system",
			"action": "BOOT",
			"payload": {"milestone": "NC-013"}
		})

	_update_readout()
	_update_receipt_readout()
	_update_replay_readout()
	_update_protocol_description()
	_update_agent_seat_readout()
	_update_dialogue_readout()
	_update_world_state_readout()
	_update_ledger_readout()
	_update_boss_readout()

func _connect_world(target: Node) -> void:
	if target == null:
		return

	if target.has_signal("room_changed"):
		target.room_changed.connect(_on_room_changed)
	if target.has_signal("checkpoint_changed"):
		target.checkpoint_changed.connect(_on_checkpoint_changed)
	if target.has_signal("hunter_respawned"):
		target.hunter_respawned.connect(_on_hunter_respawned)
	if target.has_signal("exit_requested"):
		target.exit_requested.connect(_on_world_exit_requested)
	if target.has_signal("dialogue_presented"):
		target.dialogue_presented.connect(_on_dialogue_presented)
	if target.has_signal("phase_changed"):
		target.phase_changed.connect(_on_phase_changed)
	if target.has_signal("boss_state_changed"):
		target.boss_state_changed.connect(_on_boss_state_changed)
	if target.has_signal("boss_anomaly"):
		target.boss_anomaly.connect(_on_boss_anomaly)
	if target.has_signal("boss_defeated"):
		target.boss_defeated.connect(_on_boss_defeated)
	if target.has_signal("scout_core_claimed"):
		target.scout_core_claimed.connect(_on_scout_core_claimed)

func _process(delta: float) -> void:
	_boss_warning_timer = maxf(0.0, _boss_warning_timer - delta)
	_update_readout()
	_update_world_state_readout()
	_update_boss_readout()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if event.keycode == KEY_O:
		_request_phi_observation()

func _request_phi_observation() -> void:
	var protocol := get_node_or_null("/root/PlayerProtocol")
	if protocol == null:
		protocol_state_label.text = "P3 OBSERVATION: protocol unavailable"
		return

	_protocol_observe_count += 1
	var response: Dictionary = protocol.handle_adapter_message(
		"agent",
		{
			"type": "observe",
			"actor": "phi_bot",
			"request_id": "hud-observe-%04d" % _protocol_observe_count
		}
	)

	if not bool(response.get("ok", false)):
		protocol_state_label.text = "P3 OBSERVATION: ERROR // %s" % response.get("error", "unknown")
		return

	var body: Dictionary = response.get("body", {})
	var observation: Dictionary = body.get("observation", {})
	var visible: Array = observation.get("visible_entities", [])
	var signals: Dictionary = observation.get("signals", {})
	var metadata: Dictionary = observation.get("metadata", {})

	protocol_state_label.text = "P3 %s // room=%s visible=%d signals=%d phase=%s" % [
		observation.get("observation_id", "?"),
		observation.get("room", "?"),
		visible.size(),
		signals.size(),
		metadata.get("world_phase", "?")
	]

func _update_protocol_description() -> void:
	var protocol := get_node_or_null("/root/PlayerProtocol")
	if protocol == null:
		return

	var response: Dictionary = protocol.handle_adapter_message(
		"agent",
		{
			"type": "describe",
			"request_id": "hud-describe"
		}
	)

	if bool(response.get("ok", false)):
		var body: Dictionary = response.get("body", {})
		protocol_state_label.text = "P3 v%s READY // observe=%s" % [
			body.get("version", "?"),
			",".join(body.get("observable_actors", []))
		]

func _on_world_exit_requested(destination: String) -> void:
	match destination:
		"ash_village":
			sewer_world.set_active(false)
			fallen_arena.set_active(false)
			ash_village.set_active(true)
			world = ash_village
			ash_village.bind_hunter(hunter)
			_current_checkpoint = str(ash_village.get("active_checkpoint_id"))
		"sewer":
			ash_village.set_active(false)
			fallen_arena.set_active(false)
			sewer_world.set_active(true)
			world = sewer_world
			sewer_world.enter_from_village(hunter)
			_current_checkpoint = str(sewer_world.get("active_checkpoint_id"))
		"fallen_arena":
			ash_village.set_active(false)
			sewer_world.set_active(false)
			fallen_arena.set_active(true)
			world = fallen_arena
			fallen_arena.bind_hunter(hunter)
			_current_checkpoint = str(fallen_arena.get("active_checkpoint_id"))
		"sewer_from_fallen":
			ash_village.set_active(false)
			fallen_arena.set_active(false)
			sewer_world.set_active(true)
			world = sewer_world
			sewer_world.enter_from_boss(hunter)
			_current_checkpoint = str(sewer_world.get("active_checkpoint_id"))
		_:
			return

	if runtime_observation_provider != null:
		runtime_observation_provider.set_world(world)
	if phi_bot != null:
		phi_bot.bind_world(world)
		phi_bot.reset_near_hunter()
	_last_dialogue = {}
	_update_dialogue_readout()
	_update_status(str(world.get("current_room_id")))
	_update_world_state_readout()
	_update_boss_readout()

func _on_hunter_interaction_requested(_context: Dictionary) -> void:
	if world == null or not world.has_method("interact_nearest"):
		_last_dialogue = {"status": "no_target"}
		_update_dialogue_readout()
		return

	var result: Dictionary = world.interact_nearest(hunter)
	if str(result.get("status", "")) != "observed":
		_last_dialogue = result
		_update_dialogue_readout()

func _on_dialogue_presented(record: Dictionary) -> void:
	_last_dialogue = record.duplicate(true)
	_record_testimony(record)
	_update_dialogue_readout()

func _record_testimony(record: Dictionary) -> void:
	var ledger := get_node_or_null("/root/RealityLedger")
	if ledger == null:
		return

	var source_id := str(record.get("npc_id", "unknown"))
	var phase := str(record.get("phase", _active_phase()))
	ledger.record_claim({
		"subject": str(record.get("claim_subject", "")),
		"value": record.get("claim_value", null),
		"confidence": float(record.get("confidence", 0.5)),
		"provenance": {
			"source_kind": "npc_testimony",
			"source_id": source_id,
			"speaker": record.get("speaker", "unknown"),
			"role": record.get("role", "unknown"),
			"room": _active_room(),
			"phase": phase
		},
		"data": {
			"claim_id": record.get("claim_id", ""),
			"text": record.get("text", ""),
			"activity": record.get("activity", "")
		},
		"dedupe_key": "claim|%s|%s|%s" % [
			record.get("claim_id", ""),
			source_id,
			phase
		]
	})

func _on_phase_changed(
	previous_phase: String,
	current_phase: String,
	previous_consistency: int,
	current_consistency: int
) -> void:
	world_state_label.text = "BELL EVENT // %s → %s // LIGHT %s // HOSTILES %s // GEOMETRY CHANGED // REALITY %s%% → %s%%" % [
		previous_phase,
		current_phase,
		"↓" if current_phase == "NIGHT" else "↑",
		"↑" if current_phase == "NIGHT" else "↓",
		previous_consistency,
		current_consistency
	]
	_last_dialogue = {
		"status": "world_event",
		"event": "bell",
		"phase": current_phase,
		"reality_consistency": current_consistency
	}
	_update_dialogue_readout()
	_record_phase_observation(
		previous_phase,
		current_phase,
		previous_consistency,
		current_consistency
	)
	_update_status(str(world.get("current_room_id")))

func _update_world_state_readout() -> void:
	if world == null:
		world_state_label.text = "WORLD: unavailable"
		return

	var phase := "?"
	var consistency := -1
	var shop := "?"
	var geometry_revision := 0
	var hostiles := false

	if world.has_method("world_state_snapshot"):
		var snapshot: Dictionary = world.world_state_snapshot()
		phase = str(snapshot.get("phase", "?"))
		if not snapshot.has("reality_consistency"):
			world_state_label.text = "WORLD: %s // REWARD %s // BOSS ARENA %s" % [
				phase,
				snapshot.get("reward_state", "N/A"),
				"COMPLETE" if snapshot.get("boss_defeated", false) else "ACTIVE"
			]
			return
		consistency = int(snapshot.get("reality_consistency", -1))
		shop = str(snapshot.get("shop_state", "?"))
		geometry_revision = int(snapshot.get("geometry_revision", 0))
		hostiles = bool(snapshot.get("hostiles_active", false))
	elif world.has_method("world_phase"):
		phase = str(world.world_phase())
		world_state_label.text = "WORLD: %s // PHASE DIAGNOSTICS INACTIVE" % phase
		return

	world_state_label.text = "WORLD: %s // REALITY %s%% // SHOP %s // HOSTILES %s // GEO REV %s" % [
		phase,
		consistency,
		shop,
		"ACTIVE" if hostiles else "QUIET",
		geometry_revision
	]

func _record_phase_observation(
	previous_phase: String,
	current_phase: String,
	previous_consistency: int,
	current_consistency: int
) -> void:
	var ledger := get_node_or_null("/root/RealityLedger")
	if ledger == null:
		return

	var world_snapshot := {}
	if world != null and world.has_method("world_state_snapshot"):
		world_snapshot = world.world_state_snapshot()

	ledger.record_observation({
		"subject": "ash_village_world_state",
		"value": current_phase,
		"confidence": 1.0,
		"provenance": {
			"source_kind": "direct_world_event",
			"source_id": "bell_event",
			"actor": "hunter",
			"room": _active_room(),
			"phase": current_phase
		},
		"data": {
			"previous_phase": previous_phase,
			"current_phase": current_phase,
			"previous_consistency": previous_consistency,
			"current_consistency": current_consistency,
			"world_state": world_snapshot
		},
		"dedupe_key": "observation|bell|%s|%s|%s" % [
			previous_phase,
			current_phase,
			world_snapshot.get("geometry_revision", 0)
		]
	})

func _on_reality_record_changed(_record: Dictionary) -> void:
	_update_ledger_readout()

func _on_contradiction_detected(record: Dictionary) -> void:
	ledger_state_label.text = "LEDGER: CONTRADICTION // subject=%s // confidence=%.2f" % [
		record.get("subject", "unknown"),
		float(record.get("confidence", 0.0))
	]

func _update_ledger_readout() -> void:
	var ledger := get_node_or_null("/root/RealityLedger")
	if ledger == null or not ledger.has_method("summary"):
		ledger_state_label.text = "LEDGER: unavailable"
		return

	var snapshot: Dictionary = ledger.summary()
	var counts: Dictionary = snapshot.get("counts", {})
	ledger_state_label.text = "LEDGER: %s records // claims=%s evidence=%s observations=%s contradictions=%s // latest=%s:%s" % [
		snapshot.get("record_count", 0),
		counts.get("claim", 0),
		counts.get("evidence", 0),
		counts.get("observation", 0),
		snapshot.get("contradiction_count", 0),
		snapshot.get("latest_type", "none"),
		snapshot.get("latest_subject", "")
	]

func _active_room() -> String:
	if world == null:
		return "unknown"
	return str(world.get("current_room_id"))

func _active_phase() -> String:
	if world != null and world.has_method("world_phase"):
		return str(world.world_phase())
	return "unknown"

func _on_boss_state_changed(snapshot: Dictionary) -> void:
	_update_boss_readout(snapshot)

func _on_boss_anomaly(event: Dictionary) -> void:
	_boss_warning_timer = 1.1
	boss_state_label.text = "Φ-BOT WARNING // ATTACK DETECTED: NO PHYSICAL SOURCE // %s" % event.get("attack", "?")

	var ledger := get_node_or_null("/root/RealityLedger")
	if ledger != null:
		ledger.record_observation({
			"subject": "the_fallen_attack_source",
			"value": "no_physical_source",
			"confidence": float(event.get("confidence", 0.99)),
			"provenance": {
				"source_kind": "phi_bot_combat_warning",
				"source_id": "phi_bot",
				"actor": "phi_bot",
				"room": _active_room(),
				"phase": _active_phase()
			},
			"data": event.duplicate(true),
			"dedupe_key": "observation|the_fallen|no_physical_source"
		})

func _on_boss_defeated(snapshot: Dictionary) -> void:
	boss_state_label.text = "THE FALLEN // DEFEATED // SCOUT CORE DETECTED"

	var ledger := get_node_or_null("/root/RealityLedger")
	if ledger != null:
		ledger.record_evidence({
			"subject": "the_fallen",
			"value": "defeated",
			"confidence": 1.0,
			"provenance": {
				"source_kind": "direct_combat_result",
				"source_id": "hunter",
				"actor": "hunter",
				"room": _active_room(),
				"phase": _active_phase()
			},
			"data": snapshot.duplicate(true),
			"dedupe_key": "evidence|the_fallen|defeated"
		})

func _update_boss_readout(snapshot: Dictionary = {}) -> void:
	if world == fallen_arena and _boss_warning_timer > 0.0:
		return

	if world != fallen_arena:
		boss_state_label.text = "BOSS: not engaged"
		return

	var boss_snapshot := snapshot
	var arena_state := {}
	if fallen_arena != null and fallen_arena.has_method("world_state_snapshot"):
		arena_state = fallen_arena.world_state_snapshot()
		if boss_snapshot.is_empty():
			boss_snapshot = arena_state.get("boss", {})

	if bool(arena_state.get("boss_defeated", false)) and boss_snapshot.is_empty():
		boss_state_label.text = "THE FALLEN // DEFEATED // %s" % arena_state.get("reward_state", "REWARD UNKNOWN")
		return

	if boss_snapshot.is_empty():
		boss_state_label.text = "THE FALLEN: state unavailable"
		return

	if bool(boss_snapshot.get("defeated", false)):
		boss_state_label.text = "THE FALLEN // DEFEATED // SCOUT CORE UNCLAIMED"
		return

	boss_state_label.text = "THE FALLEN // HP %s/%s // PHASE %s // %s // ATTACK %s" % [
		boss_snapshot.get("health", "?"),
		boss_snapshot.get("max_health", "?"),
		boss_snapshot.get("boss_phase", "?"),
		boss_snapshot.get("combat", "?"),
		boss_snapshot.get("attack", "none")
	]

func _on_scout_core_claimed(record: Dictionary) -> void:
	if phi_bot != null and phi_bot.has_method("install_scout_core"):
		phi_bot.install_scout_core(record)

	var ledger := get_node_or_null("/root/RealityLedger")
	if ledger != null:
		ledger.mark_verified({
			"subject": "phi_bot_form",
			"value": "SCOUT",
			"confidence": float(record.get("compatibility", 0.97)),
			"provenance": {
				"source_kind": "core_installation",
				"source_id": str(record.get("core_id", "scout_core_01")),
				"actor": "phi_bot",
				"room": _active_room(),
				"phase": _active_phase()
			},
			"data": {
				"compatibility": record.get("compatibility", 0.97),
				"abilities": [
					"RESONANCE_PING",
					"ANCHOR_MARK",
					"ENEMY_READ",
					"CONTRADICTION_SENSE"
				]
			},
			"dedupe_key": "verified|phi_bot_form|SCOUT"
		})

	_last_dialogue = record.duplicate(true)
	_update_dialogue_readout()
	_update_phi_readout()

func _on_phi_form_changed(previous_form: String, current_form: String) -> void:
	scout_state_label.text = "SCOUT CORE // %s → %s // PING MARK ENEMY_READ CONTRADICTION_SENSE ONLINE" % [
		previous_form,
		current_form
	]

func _on_phi_scout_result(result: Dictionary) -> void:
	var ability := str(result.get("ability", "SCOUT"))
	var status := str(result.get("status", "unknown"))

	match ability:
		"RESONANCE_PING":
			scout_state_label.text = "SCOUT // PING // %s signals // energy %.0f" % [
				result.get("signal_count", 0),
				float(result.get("energy", 0.0))
			]
		"ANCHOR_MARK":
			scout_state_label.text = "SCOUT // MARK // %s // %s" % [
				result.get("target", "none"),
				result.get("category", "unknown")
			]
		"ENEMY_READ":
			scout_state_label.text = "SCOUT // ENEMY READ // %s // %s // CONF %.2f" % [
				result.get("target", "none"),
				result.get("classification", "unknown"),
				float(result.get("confidence", 0.0))
			]
		"CONTRADICTION_SENSE":
			scout_state_label.text = "SCOUT // CONTRADICTION SENSE // %s conflicts" % result.get("contradiction_count", 0)
		_:
			scout_state_label.text = "SCOUT // %s // %s" % [ability, status]

func _on_agent_server_state_changed(_snapshot: Dictionary) -> void:
	_update_agent_seat_readout()

func _on_agent_message_processed(_summary: Dictionary) -> void:
	_update_agent_seat_readout()

func _update_agent_seat_readout() -> void:
	if local_agent_server == null or not local_agent_server.has_method("server_snapshot"):
		agent_seat_state_label.text = "AGENT SEAT: unavailable"
		return

	var snapshot: Dictionary = local_agent_server.server_snapshot()
	agent_seat_state_label.text = "AGENT SEAT: %s // %s:%s // actor=%s // clients=%s // last=%s" % [
		str(snapshot.get("state", "?")).to_upper(),
		snapshot.get("bind", "?"),
		snapshot.get("port", "?"),
		snapshot.get("seat_actor", "?"),
		snapshot.get("clients", 0),
		snapshot.get("last_message", "idle")
	]

func _on_room_changed(room_id: String, room_title: String) -> void:
	if world == null:
		return
	if room_id != str(world.get("current_room_id")):
		return
	room_label.text = "ROOM: %s" % room_title
	_update_status(room_id)

func _on_checkpoint_changed(checkpoint_id: String) -> void:
	if world == null:
		return
	_current_checkpoint = checkpoint_id
	_update_status(str(world.get("current_room_id")))

func _on_hunter_respawned(checkpoint_id: String) -> void:
	_current_checkpoint = checkpoint_id
	if phi_bot != null and phi_bot.has_method("reset_near_hunter"):
		phi_bot.reset_near_hunter()
	if world != null:
		_update_status(str(world.get("current_room_id")))

func _on_hunter_defeated() -> void:
	if world != null and world.has_method("respawn_hunter"):
		world.respawn_hunter()

func _on_phi_inspect_result(result: Dictionary) -> void:
	_last_inspection = result.duplicate(true)
	if str(result.get("status", "")) == "observed":
		var ledger := get_node_or_null("/root/RealityLedger")
		if ledger != null:
			var object_id := str(result.get("object_id", "unknown"))
			ledger.record_evidence({
				"subject": object_id,
				"value": str(result.get("category", "observation")),
				"confidence": float(result.get("confidence", 0.5)),
				"provenance": {
					"source_kind": "phi_bot_inspection",
					"source_id": "phi_bot",
					"actor": "phi_bot",
					"room": _active_room(),
					"phase": _active_phase()
				},
				"data": {
					"title": result.get("title", "unknown"),
					"finding": result.get("finding", ""),
					"category": result.get("category", "unknown"),
					"world_position": result.get("world_position", [])
				},
				"dedupe_key": "evidence|%s|%s" % [object_id, _active_phase()]
			})
	_update_inspection_readout()

func _on_receipt_appended(receipt: Dictionary) -> void:
	match str(receipt.get("receipt_type", "")):
		"decision":
			_last_decision = receipt.duplicate(true)
			_last_effect = {}
		"effect":
			_last_effect = receipt.duplicate(true)

	_update_receipt_readout()
	_update_replay_readout()

func _update_status(room_id: String) -> void:
	var mode := "?"
	var form := "?"
	var phase := "?"
	if phi_bot != null and phi_bot.has_method("actor_snapshot"):
		var snapshot: Dictionary = phi_bot.actor_snapshot()
		mode = str(snapshot.get("mode", "?"))
		form = str(snapshot.get("form", "?"))
	if world != null and world.has_method("world_phase"):
		phase = str(world.world_phase())

	status_label.text = "CHECKPOINT: %s   |   ROOM: %s   |   PHASE: %s   |   Φ-BOT: %s / %s" % [
		_current_checkpoint,
		room_id,
		phase,
		mode,
		form
	]

func _update_receipt_readout() -> void:
	if _last_decision.is_empty():
		receipt_label.text = "RECEIPT: waiting"
		return

	var decision_text := "ACCEPTED" if _last_decision.get("accepted", false) else "REJECTED"
	var action_id := str(_last_decision.get("action_id", "?"))

	if not bool(_last_decision.get("accepted", false)):
		receipt_label.text = "%s  %s.%s  DECISION: %s (%s)" % [
			action_id,
			_last_decision.get("actor", "?"),
			_last_decision.get("action", "?"),
			decision_text,
			_last_decision.get("reason", "unknown")
		]
		return

	if _last_effect.is_empty() or str(_last_effect.get("action_id", "")) != action_id:
		receipt_label.text = "%s  %s.%s  DECISION: %s  |  EFFECT: pending" % [
			action_id,
			_last_decision.get("actor", "?"),
			_last_decision.get("action", "?"),
			decision_text
		]
		return

	receipt_label.text = "%s  %s.%s  DECISION: %s  |  EFFECT: %s (%s)" % [
		action_id,
		_last_decision.get("actor", "?"),
		_last_decision.get("action", "?"),
		decision_text,
		str(_last_effect.get("status", "?")).to_upper(),
		_last_effect.get("reason", "unknown")
	]

func _update_replay_readout() -> void:
	var ledger := get_node_or_null("/root/ReceiptLedger")
	if ledger == null or not ledger.has_method("replay_tape"):
		replay_state_label.text = "REPLAY TAPE: unavailable"
		return

	var tape: Dictionary = ledger.replay_tape()
	replay_state_label.text = "REPLAY TAPE: %s accepted actions" % tape.get("entry_count", 0)

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

	if str(snapshot.get("form", "")) == "SCOUT" and scout_state_label.text == "SCOUT: locked":
		scout_state_label.text = "SCOUT: ONLINE // PING P // ENEMY READ T // MARK G // CONTRADICTION SENSE PASSIVE"

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

func _update_dialogue_readout() -> void:
	if _last_dialogue.is_empty():
		dialogue_state_label.text = "DIALOGUE: no testimony"
		return

	var status := str(_last_dialogue.get("status", ""))
	if status == "world_event":
		var event_name := str(_last_dialogue.get("event", "event")).to_upper()
		if event_name == "BELL":
			dialogue_state_label.text = "WORLD EVENT: BELL // phase=%s // reality=%s%%" % [
				_last_dialogue.get("phase", "?"),
				_last_dialogue.get("reality_consistency", "?")
			]
		else:
			dialogue_state_label.text = "WORLD EVENT: %s // %s" % [
				event_name,
				_last_dialogue.get("detail", "")
			]
		return
	if status != "observed":
		dialogue_state_label.text = "DIALOGUE: no one nearby"
		return

	dialogue_state_label.text = "%s [%s]: %s // claim=%s" % [
		_last_dialogue.get("speaker", "?"),
		_last_dialogue.get("activity", "?"),
		_last_dialogue.get("text", "..."),
		_last_dialogue.get("claim_id", "none")
	]
