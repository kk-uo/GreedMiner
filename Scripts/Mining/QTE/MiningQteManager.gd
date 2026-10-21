class_name MiningQteManager
extends Node2D

## Global coordinator for mining QTEs during a battle (one per BattleMain).
##
## - ONE global timer for the whole ship: first check `initial_delay` (30) s
##   after the battle starts, then every `check_interval` (30) s. Each check
##   rolls `chance_per_check` (1 = guaranteed) once; on success it picks one
##   random eligible Mining Module and one event type by weight. More modules
##   never add more events.
## - Only `max_concurrent_events` (1) event may exist at a time: an active
##   "!" marker, the Ore Burst clicking phase, the Precision warning / arc
##   check, or a chest waiting to be opened all hold the lock. A check that
##   lands while an event is active waits and starts the next event as soon as
##   the lock frees (`start_when_free`; at most one waiting, never stacked).
##   Result text and particles that outlive the event don't hold the lock.
## - Developer builds: F6 / F7 / F8 trigger Ore Burst / Precision / Salvage on
##   a random Mining Module (same global lock).
## - The lock is released when the event succeeds, fails, expires or is
##   cancelled (battle end, evacuation, triggering module removed / freed).
## Nothing here pauses combat or touches normal mining.

signal event_activated(event: MiningQteEvent)
signal event_completed(event: MiningQteEvent, outcome: StringName, reward: float)
signal event_failed(event: MiningQteEvent)
signal event_expired(event: MiningQteEvent)
signal event_cancelled(event: MiningQteEvent)

const DEFAULT_CONFIG: MiningQteConfig = preload("res://Resources/Mining/MiningQteConfig.tres")

@export var config: MiningQteConfig = DEFAULT_CONFIG
@export var ship_path: NodePath = ^"../Ship"
## Screen-space parent for the Precision skill check (falls back to an own layer).
@export var ui_parent_path: NodePath = ^"../BattleUI/UIRoot"
## Turn off random triggering (tests, debug); try_start_event still works.
@export var auto_trigger: bool = true

var ship: Ship
var _active_events: Array[MiningQteEvent] = []
var _check_timer: float = 0.0
## A check landed during an active event; start one when the lock frees.
var _pending_check: bool = false
var _shut_down: bool = false
var _fallback_layer: CanvasLayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if config == null:
		config = DEFAULT_CONFIG
	if ship == null:
		ship = get_node_or_null(ship_path) as Ship
	_check_timer = config.initial_delay


func _process(delta: float) -> void:
	_drop_invalid_events()
	if _shut_down or not auto_trigger:
		return
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = config.check_interval
		if is_event_active():
			# One waiting check at most; never stacked.
			_pending_check = config.start_when_free
		else:
			_pending_check = false
			_roll_for_event()
	elif _pending_check and not is_event_active():
		_pending_check = false
		_roll_for_event()


## Developer-only manual triggers (respect the global single-event rule).
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _shut_down:
		return
	if not DeveloperCommands.is_available():
		return
	var type: StringName = &""
	match key.keycode:
		KEY_F6:
			type = MiningQteEvent.TYPE_ORE_BURST
		KEY_F7:
			type = MiningQteEvent.TYPE_PRECISION
		KEY_F8:
			type = MiningQteEvent.TYPE_SALVAGE
	if type.is_empty():
		return
	get_viewport().set_input_as_handled()
	if try_start_event(type) == null:
		print("Mining QTE debug: %s not started (an event is active or no Mining Module)." % type)


# ==========================================
# Public API
# ==========================================

func is_event_active() -> bool:
	return _active_events.size() >= maxi(config.max_concurrent_events, 1)


func get_active_event() -> MiningQteEvent:
	return _active_events[0] if not _active_events.is_empty() else null


func get_active_event_count() -> int:
	return _active_events.size()


## Starts an event of the given type on a module (random eligible module when
## null). Returns null when the global limit is reached or nothing qualifies.
func try_start_event(event_type: StringName, source_module: MiningModule = null) -> MiningQteEvent:
	if _shut_down or is_event_active():
		return null
	if source_module == null:
		var modules := get_eligible_modules()
		if modules.is_empty():
			return null
		source_module = modules[_rng.randi() % modules.size()]
	elif not _is_eligible(source_module):
		return null
	var event := _create_event(event_type)
	if event == null:
		return null
	event.event_type = event_type
	_active_events.append(event)
	event.resolved.connect(_on_event_resolved)
	add_child(event)
	event.begin(self, source_module, config)
	event_activated.emit(event)
	return event


## Schedules the next random trigger check (tests / debug tools).
func set_next_check_in(seconds: float) -> void:
	_check_timer = maxf(seconds, 0.0)


## Battle over / evacuating / leaving the scene: cancel everything for good.
func shutdown() -> void:
	_shut_down = true
	_pending_check = false
	cancel_active_events()


func cancel_active_events() -> void:
	for event in _active_events.duplicate():
		if is_instance_valid(event):
			event.cancel()
	_active_events.clear()


func get_eligible_modules() -> Array[MiningModule]:
	var result: Array[MiningModule] = []
	if not is_instance_valid(ship) or ship.installed_modules == null:
		return result
	for child in ship.installed_modules.get_children():
		var mining := child as MiningModule
		if mining != null and _is_eligible(mining):
			result.append(mining)
	return result


## Salvage Chest reward = effective ore per second × reward_seconds.
## Kept as a float like normal mining (mission ore is fractional; the HUD floors).
static func calculate_reward(source_module: MiningModule, qte_config: MiningQteConfig) -> float:
	if qte_config == null:
		return 0.0
	return calculate_reward_for_seconds(source_module, qte_config.reward_seconds)


## Any QTE reward: triggering module's effective ore per second × seconds.
static func calculate_reward_for_seconds(source_module: MiningModule, seconds: float) -> float:
	if not is_instance_valid(source_module):
		return 0.0
	return source_module.get_effective_ore_per_second() * maxf(seconds, 0.0) * ResearchManager.get_mining_qte_ore_multiplier()


## Screen-space parent for QTE UI (Precision skill check).
func get_ui_parent() -> Control:
	var ui_parent := get_node_or_null(ui_parent_path) as Control
	if ui_parent != null:
		return ui_parent
	if _fallback_layer == null:
		_fallback_layer = CanvasLayer.new()
		_fallback_layer.layer = 5
		add_child(_fallback_layer)
		var root := Control.new()
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fallback_layer.add_child(root)
	return _fallback_layer.get_child(0) as Control


# ==========================================
# Internals
# ==========================================

func _is_eligible(source_module: MiningModule) -> bool:
	return (is_instance_valid(source_module) and source_module.is_inside_tree()
			and source_module.mining_enabled and not source_module.is_queued_for_deletion())


## One global roll per check: chance_per_check, then a random eligible module
## and a weighted event type.
func _roll_for_event() -> void:
	var modules := get_eligible_modules()
	if modules.is_empty():
		return
	if _rng.randf() >= config.chance_per_check:
		return
	try_start_event(_pick_type(), modules[_rng.randi() % modules.size()])


func _pick_type() -> StringName:
	var weights := {
		MiningQteEvent.TYPE_ORE_BURST: maxf(config.weight_ore_burst, 0.0),
		MiningQteEvent.TYPE_PRECISION: maxf(config.weight_precision, 0.0),
		MiningQteEvent.TYPE_SALVAGE: maxf(config.weight_salvage, 0.0),
	}
	var total: float = 0.0
	for weight in weights.values():
		total += weight
	if total <= 0.0:
		return MiningQteEvent.TYPE_ORE_BURST
	var roll: float = _rng.randf() * total
	for type in weights:
		roll -= weights[type]
		if roll <= 0.0:
			return type
	return MiningQteEvent.TYPE_ORE_BURST


func _create_event(event_type: StringName) -> MiningQteEvent:
	match event_type:
		MiningQteEvent.TYPE_ORE_BURST:
			return OreBurstEvent.new()
		MiningQteEvent.TYPE_PRECISION:
			return PrecisionMiningEvent.new()
		MiningQteEvent.TYPE_SALVAGE:
			return SalvageDiscoveryEvent.new()
	push_warning("MiningQteManager: unknown event type %s" % event_type)
	return null


## Releases the lock if an event's module disappeared or the node was freed
## without resolving (never leave the system permanently locked).
func _drop_invalid_events() -> void:
	for event in _active_events.duplicate():
		if not is_instance_valid(event):
			_active_events.erase(event)
		elif not event.is_resolved() and not event.is_module_valid():
			event.cancel()


func _on_event_resolved(event: MiningQteEvent, result: StringName, reward: float) -> void:
	_active_events.erase(event)
	_check_timer = maxf(_check_timer, config.cooldown_after_event)
	match result:
		MiningQteEvent.OUTCOME_SUCCESS, MiningQteEvent.OUTCOME_PERFECT:
			event_completed.emit(event, result, reward)
		MiningQteEvent.OUTCOME_FAILED:
			event_failed.emit(event)
		MiningQteEvent.OUTCOME_EXPIRED:
			event_expired.emit(event)
		_:
			event_cancelled.emit(event)


func _exit_tree() -> void:
	# Scene change: make sure nothing survives holding a lock or a reward.
	_shut_down = true
	for event in _active_events.duplicate():
		if is_instance_valid(event) and not event.is_resolved():
			event.resolve(MiningQteEvent.OUTCOME_CANCELLED)
	_active_events.clear()
