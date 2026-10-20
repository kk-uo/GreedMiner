class_name WaveManager
extends Node

## Runtime progression for a PlanetWaveConfig. Configuration remains data-only.

signal wave_preparation_started(wave_number: int, total_waves: int, duration: float)
signal preparation_time_changed(seconds_remaining: int)
signal wave_started(wave_number: int, total_waves: int, boss_wave: bool)
signal remaining_enemy_count_changed(remaining_count: int)
signal boss_health_changed(current_health: float, maximum_health: float, visible: bool)
signal planet_completed(config: PlanetWaveConfig)
signal wave_system_stopped(reason: StringName)
signal wave_configuration_blocked(wave_number: int, message: String)

enum State { IDLE, PREPARING, SPAWNING, CLEARING, BLOCKED, COMPLETED, STOPPED }

@export var wave_config: PlanetWaveConfig
@export var enemy_spawner_path: NodePath = NodePath("../EnemySpawner")
@export var enemies_container_path: NodePath = NodePath("../Enemies")
@export var auto_start: bool = true
@export var spawn_rng_seed: int = 0
@export_range(0, 5000, 1) var large_enemy_count_warning: int = 250

var _state: State = State.IDLE
var _current_wave_index: int = 0
var _preparation_time_left: float = 0.0
var _spawn_time_left: float = 0.0
var _spawn_queue: Array[WaveSpawnRequest] = []
var _timed_spawn_requests: Array[WaveSpawnRequest] = []
var _spawn_phase_elapsed: float = 0.0
var _scheduled_spawn_count: int = 0
var _scheduled_spawned_count: int = 0
var _scheduled_spawn_budget: int = 0
var _spent_spawn_budget: int = 0
var _spawn_sequence: int = 0
var _alive_enemies: Dictionary = {}
var _boss: BasicEnemy
var _last_preparation_second: int = -1
var _clear_check_queued: bool = false
var _large_count_warning_emitted: bool = false
var _last_special_events: Array[Dictionary] = []
var _executed_special_events: Array[Dictionary] = []
var _spawn_rng := RandomNumberGenerator.new()

## Kept as Node instead of a custom-class annotation so an editor that was
## already open before EnemySpawner was registered can still parse this file.
@onready var _enemy_spawner: Node = get_node_or_null(enemy_spawner_path)
@onready var _enemies_container: Node = get_node_or_null(enemies_container_path)


func _ready() -> void:
	if _enemy_spawner == null or _enemies_container == null:
		push_error("WaveManager: EnemySpawner or Enemies container path is invalid.")
		set_process(false)
		return
	var entered_callback := Callable(self, "_on_enemy_entered")
	if not _enemies_container.child_entered_tree.is_connected(entered_callback):
		_enemies_container.child_entered_tree.connect(entered_callback)
	for child in _enemies_container.get_children():
		_on_enemy_entered(child)
	if auto_start:
		start_wave_system.call_deferred()


func _process(delta: float) -> void:
	match _state:
		State.PREPARING:
			_update_preparation(delta)
		State.SPAWNING:
			_update_spawning(delta)


## Starts or restarts from Wave 1 using the assigned Resource.
func start_wave_system() -> bool:
	if wave_config == null:
		push_error("WaveManager: No PlanetWaveConfig is assigned.")
		return false
	var validation_errors := wave_config.get_validation_errors()
	if not validation_errors.is_empty():
		for message in validation_errors:
			push_error("WaveManager: " + message)
		return false

	_current_wave_index = 0
	_spawn_queue.clear()
	_timed_spawn_requests.clear()
	_scheduled_spawn_count = 0
	_scheduled_spawned_count = 0
	_scheduled_spawn_budget = 0
	_spent_spawn_budget = 0
	_spawn_sequence = 0
	_last_preparation_second = -1
	_clear_check_queued = false
	_boss = null
	_last_special_events.clear()
	_executed_special_events.clear()
	_large_count_warning_emitted = false
	if spawn_rng_seed == 0:
		_spawn_rng.randomize()
	else:
		_spawn_rng.seed = spawn_rng_seed
	_alive_enemies.clear()
	for child in _enemies_container.get_children():
		_on_enemy_entered(child)
	_enemy_spawner.call("set_spawning_enabled", true)
	set_process(true)
	_begin_preparation()
	return true


## Cancels countdowns, scheduled spawns and split death effects safely.
func stop_wave_system(reason: StringName = &"stopped") -> void:
	if _state == State.STOPPED or _state == State.COMPLETED:
		return
	_state = State.STOPPED
	_spawn_queue.clear()
	_timed_spawn_requests.clear()
	_enemy_spawner.call("set_spawning_enabled", false)
	set_process(false)
	for enemy_value in _alive_enemies.values():
		var enemy := enemy_value as BasicEnemy
		if is_instance_valid(enemy):
			enemy.set_death_effects_enabled(false)
	boss_health_changed.emit(0.0, 1.0, false)
	wave_system_stopped.emit(reason)


func _begin_preparation() -> void:
	if _current_wave_index >= wave_config.waves.size():
		_complete_planet()
		return
	var wave := wave_config.waves[_current_wave_index]
	_state = State.PREPARING
	_preparation_time_left = maxf(wave.preparation_duration, 0.0)
	_last_preparation_second = -1
	# A zero duration skips the preparation state entirely. Rocky Planet uses
	# this so the next wave begins immediately after the previous one clears.
	if _preparation_time_left <= 0.0:
		_begin_wave()
		return
	wave_preparation_started.emit(wave.wave_number, wave_config.get_total_waves(), _preparation_time_left)
	_emit_preparation_time()


func _update_preparation(delta: float) -> void:
	_preparation_time_left = maxf(_preparation_time_left - delta, 0.0)
	_emit_preparation_time()
	if _preparation_time_left <= 0.0:
		_begin_wave()


func _emit_preparation_time() -> void:
	var displayed_seconds := ceili(_preparation_time_left)
	if displayed_seconds == _last_preparation_second:
		return
	_last_preparation_second = displayed_seconds
	preparation_time_changed.emit(displayed_seconds)


func _begin_wave() -> void:
	var wave := wave_config.waves[_current_wave_index]
	if wave.configuration_pending:
		_state = State.BLOCKED
		_spawn_queue.clear()
		set_process(false)
		wave_started.emit(wave.wave_number, wave_config.get_total_waves(), wave.boss_wave)
		remaining_enemy_count_changed.emit(_alive_enemies.size())
		var message := wave.configuration_message
		push_warning("WaveManager: Wave %d is blocked: %s" % [wave.wave_number, message])
		wave_configuration_blocked.emit(wave.wave_number, message)
		return
	if not _build_spawn_queue(wave):
		_state = State.STOPPED
		set_process(false)
		return
	_state = State.SPAWNING
	_spawn_phase_elapsed = 0.0
	_spawn_time_left = maxf(wave.initial_spawn_delay, 0.0)
	wave_started.emit(wave.wave_number, wave_config.get_total_waves(), wave.boss_wave)
	_emit_remaining_count()
	if _spawn_queue.is_empty() and _timed_spawn_requests.is_empty():
		_state = State.CLEARING
		_schedule_clear_check()


func _build_spawn_queue(wave: WaveDefinition) -> bool:
	var plan := WaveSpawnPlanner.build_plan(
		wave,
		wave_config.special_spawn_rules,
		_spawn_rng
	)
	if not plan.validation_errors.is_empty():
		for message in plan.validation_errors:
			push_error("WaveManager: " + message)
		return false
	_spawn_queue = plan.requests.duplicate()
	_timed_spawn_requests = plan.timed_requests.duplicate()
	_scheduled_spawn_count = plan.total_spawn_count
	_scheduled_spawned_count = 0
	_scheduled_spawn_budget = plan.total_spawn_budget
	_spent_spawn_budget = 0
	_spawn_sequence = 0
	_last_special_events = plan.special_events.duplicate(true)
	return true


func _update_spawning(delta: float) -> void:
	var wave := wave_config.waves[_current_wave_index]
	_spawn_phase_elapsed += delta
	_execute_due_timed_requests(wave)
	if _spawn_queue.is_empty() and _timed_spawn_requests.is_empty():
		if not wave.wait_for_spawn_phase_end or _spawn_phase_elapsed >= wave.get_effective_spawn_phase_duration():
			_finish_current_wave_spawning()
		return
	if _spawn_queue.is_empty():
		return
	if wave.maximum_simultaneous_enemies > 0 and _alive_enemies.size() >= wave.maximum_simultaneous_enemies:
		return
	_spawn_time_left -= delta
	if _spawn_time_left > 0.0:
		return

	var batch_size := wave.get_spawn_batch_size()
	var spawned_this_tick := 0
	while not _spawn_queue.is_empty() and spawned_this_tick < batch_size:
		var request := _spawn_queue.pop_front() as WaveSpawnRequest
		var request_count := _execute_spawn_request(request, wave)
		spawned_this_tick += request_count
	_spawn_time_left = maxf(wave.spawn_interval, 0.05)
	_emit_remaining_count()
	if _spawn_queue.is_empty() and _timed_spawn_requests.is_empty():
		if not wave.wait_for_spawn_phase_end or _spawn_phase_elapsed >= wave.get_effective_spawn_phase_duration():
			_finish_current_wave_spawning()


func _execute_due_timed_requests(wave: WaveDefinition) -> void:
	var duration := maxf(wave.get_effective_spawn_phase_duration(), 0.001)
	var executed_any := false
	while not _timed_spawn_requests.is_empty():
		var request := _timed_spawn_requests[0] as WaveSpawnRequest
		if _spawn_phase_elapsed < duration * request.trigger_phase_fraction:
			return
		if wave.maximum_simultaneous_enemies > 0 and _alive_enemies.size() + request.spawn_count > wave.maximum_simultaneous_enemies:
			return
		_timed_spawn_requests.pop_front()
		_execute_spawn_request(request, wave)
		executed_any = true
		_executed_special_events.append({
			"event_id": request.special_event_id,
			"scheduled_fraction": request.trigger_phase_fraction,
			"actual_fraction": _spawn_phase_elapsed / duration,
		})
	if executed_any:
		_emit_remaining_count()


func _execute_spawn_request(request: WaveSpawnRequest, wave: WaveDefinition) -> int:
	if request == null or request.entry == null:
		return 0
	var spawned: Array[BasicEnemy] = []
	if request.is_formation():
		var formation: Array = _enemy_spawner.call(
			"spawn_formation",
			request.entry.resolve_scene(),
			request.spawn_count,
			request.direction,
			request.formation_spacing,
			request.with_flag_bearer
		)
		for value in formation:
			if value is BasicEnemy:
				spawned.append(value as BasicEnemy)
	elif request.is_cluster():
		var result: Array = _enemy_spawner.call(
			"spawn_cluster",
			request.entry.resolve_scene(),
			request.spawn_count,
			request.direction,
			request.cluster_radius,
			_spawn_sequence
		)
		for value in result:
			if value is BasicEnemy:
				spawned.append(value as BasicEnemy)
	else:
		var enemy := _enemy_spawner.call(
			"spawn_enemy",
			request.entry.resolve_scene(),
			request.pattern,
			_spawn_sequence,
			request.direction
		) as BasicEnemy
		if enemy != null:
			spawned.append(enemy)

	# The fixed request consumes its shared budget once, without death refunds.
	_scheduled_spawned_count += request.spawn_count
	_spent_spawn_budget += request.get_budget_cost()
	_spawn_sequence += request.spawn_count
	if spawned.size() != request.spawn_count:
		push_error("WaveManager: Spawned %d of %d '%s' requests in wave %d." % [spawned.size(), request.spawn_count, request.entry.enemy_id, wave.wave_number])
	for enemy in spawned:
		if request.entry.is_boss:
			_track_boss(enemy)
	return request.spawn_count


## Starts scheduling the next wave as soon as this wave's fixed spawn queue is
## exhausted. Living enemies from earlier waves remain tracked globally.
func _finish_current_wave_spawning() -> void:
	var wave := wave_config.waves[_current_wave_index]
	if _current_wave_index < wave_config.waves.size() - 1:
		_current_wave_index += 1
		_begin_preparation()
		return
	if wave.has_missing_reserved_boss():
		_state = State.BLOCKED
		set_process(false)
		var message := wave.missing_boss_message
		push_warning("WaveManager: Wave %d regular quota completed, but the reserved boss is missing: %s" % [wave.wave_number, message])
		wave_configuration_blocked.emit(wave.wave_number, message)
		return
	_state = State.CLEARING
	_schedule_clear_check()


func _on_enemy_entered(node: Node) -> void:
	var enemy := node as BasicEnemy
	if enemy == null or not is_instance_valid(enemy):
		return
	var instance_id := enemy.get_instance_id()
	if _alive_enemies.has(instance_id):
		return
	_alive_enemies[instance_id] = enemy
	if large_enemy_count_warning > 0 and _alive_enemies.size() >= large_enemy_count_warning and not _large_count_warning_emitted:
		_large_count_warning_emitted = true
		push_warning("WaveManager: Large active enemy count reached %d." % _alive_enemies.size())
	var exiting_callback := Callable(self, "_on_enemy_tree_exiting").bind(enemy)
	if not enemy.tree_exiting.is_connected(exiting_callback):
		enemy.tree_exiting.connect(exiting_callback, CONNECT_ONE_SHOT)
	_emit_remaining_count()


func _on_enemy_tree_exiting(enemy: BasicEnemy) -> void:
	if enemy == null:
		return
	_alive_enemies.erase(enemy.get_instance_id())
	if enemy == _boss:
		_boss = null
		boss_health_changed.emit(0.0, 1.0, false)
	_emit_remaining_count()
	_schedule_clear_check()


func _track_boss(enemy: BasicEnemy) -> void:
	_boss = enemy
	var health_callback := Callable(self, "_on_boss_health_changed")
	if not enemy.health_changed.is_connected(health_callback):
		enemy.health_changed.connect(health_callback)
	boss_health_changed.emit(enemy.get_current_health(), enemy.max_health, true)


func _on_boss_health_changed(current_health: float, maximum_health: float) -> void:
	if is_instance_valid(_boss):
		boss_health_changed.emit(current_health, maximum_health, true)


func _schedule_clear_check() -> void:
	if _clear_check_queued or _state != State.CLEARING:
		return
	_clear_check_queued = true
	call_deferred("_evaluate_wave_clear")


func _evaluate_wave_clear() -> void:
	_clear_check_queued = false
	if _state != State.CLEARING:
		return
	_update_frozen_final_enrage()
	if _scheduled_spawned_count < _scheduled_spawn_count or not _alive_enemies.is_empty():
		return
	_complete_planet()

## Use the tracked living set after deferred death-split children have entered.
## Only the final Frozen wave qualifies: once the Mega Monster boss is the only
## enemy left on the field, it sits down and cries, then enrages.
func _update_frozen_final_enrage() -> void:
	if wave_config == null or wave_config.planet_id != &"frozen_planet" or get_current_wave_number() != 10:
		return
	var bosses: Array[FrozenEnemy] = []
	for value in _alive_enemies.values():
		var enemy := value as BasicEnemy
		if not is_instance_valid(enemy) or enemy.is_dying():
			continue
		if enemy.enemy_tier != BasicEnemy.EnemyTier.BOSS:
			return
		if enemy is FrozenEnemy:
			bosses.append(enemy as FrozenEnemy)
	for boss in bosses:
		boss.begin_final_enrage()


func _complete_planet() -> void:
	if _state == State.COMPLETED:
		return
	_state = State.COMPLETED
	_enemy_spawner.call("set_spawning_enabled", false)
	set_process(false)
	remaining_enemy_count_changed.emit(0)
	boss_health_changed.emit(0.0, 1.0, false)
	planet_completed.emit(wave_config)


func _emit_remaining_count() -> void:
	remaining_enemy_count_changed.emit(get_remaining_enemy_count())


func get_current_wave_number() -> int:
	if wave_config == null or wave_config.waves.is_empty():
		return 0
	return wave_config.waves[mini(_current_wave_index, wave_config.waves.size() - 1)].wave_number


func get_total_waves() -> int:
	return wave_config.get_total_waves() if wave_config != null else 0


func get_alive_enemy_count() -> int:
	return _alive_enemies.size()


## Includes living descendants plus every scheduled enemy not yet spawned.
func get_remaining_enemy_count() -> int:
	var queued_count := 0
	for request in _spawn_queue:
		queued_count += request.spawn_count
	for request in _timed_spawn_requests:
		queued_count += request.spawn_count
	return _alive_enemies.size() + queued_count


func get_scheduled_spawn_count() -> int:
	return _scheduled_spawn_count


func get_scheduled_spawned_count() -> int:
	return _scheduled_spawned_count


func get_scheduled_spawn_budget() -> int:
	return _scheduled_spawn_budget


func get_spent_spawn_budget() -> int:
	return _spent_spawn_budget


func get_last_special_events() -> Array[Dictionary]:
	return _last_special_events.duplicate(true)


func get_executed_special_events() -> Array[Dictionary]:
	return _executed_special_events.duplicate(true)


func is_running() -> bool:
	return _state in [State.PREPARING, State.SPAWNING, State.CLEARING]


func is_completed() -> bool:
	return _state == State.COMPLETED


func is_configuration_blocked() -> bool:
	return _state == State.BLOCKED
