class_name ForestPerformanceMonitor
extends Node

## Lightweight sampling for the forest's spawn spike and sustained load.
## Enable logging in ForestPlanetSettings for playtests; snapshots are also
## available to automated tests and the remote inspector.
var log_enabled: bool = false
var sample_interval: float = 2.0
var latest_snapshot: Dictionary = {}
var peak_spawn_ms: float = 0.0
var peak_spawn_count: int = 0
var peak_frame_ms: float = 0.0
## First sustained (<30 FPS for three consecutive frames) population after
## five seconds of play. -1 means no such slowdown has been observed.
var first_sustained_stutter_treants: int = -1
var first_sustained_stutter_enemies: int = -1
var _elapsed: float = 0.0
var _runtime: float = 0.0
var _last_frame_ms: float = 0.0
var _stutter_streak: int = 0


func _process(delta: float) -> void:
	_last_frame_ms = delta * 1000.0
	peak_frame_ms = maxf(peak_frame_ms, _last_frame_ms)
	_runtime += delta
	if _runtime >= 5.0 and _last_frame_ms >= 1000.0 / 30.0:
		_stutter_streak += 1
	else:
		_stutter_streak = 0
	if first_sustained_stutter_treants < 0 and _stutter_streak >= 3:
		var population := _population()
		first_sustained_stutter_treants = population[0]
		first_sustained_stutter_enemies = population[1]
		if log_enabled:
			print("FOREST FIRST SUSTAINED STUTTER: treants=", population[0], " enemies=", population[1], " frame_ms=", _last_frame_ms)
	_elapsed += delta
	if _elapsed < sample_interval:
		return
	_elapsed = 0.0
	sample_now()


func sample_now() -> void:
	var population := _population()
	latest_snapshot = {
		"treants": population[0],
		"active_enemies": population[1],
		"first_sustained_stutter_treants": first_sustained_stutter_treants,
		"first_sustained_stutter_enemies": first_sustained_stutter_enemies,
		"frame_ms": _last_frame_ms,
		"peak_frame_ms": peak_frame_ms,
		"script_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"collision_pairs": int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)),
		"peak_spawn_ms": peak_spawn_ms,
		"peak_spawn_count": peak_spawn_count,
	}
	if log_enabled:
		print("FOREST PERF ", latest_snapshot)


func _population() -> Array[int]:
	var enemies := get_parent().get_node_or_null("Enemies")
	if enemies == null:
		return [0, 0]
	var treants := 0
	for node in enemies.get_children():
		if node is ForestEnemy and (node as ForestEnemy).enemy_id in [&"treant", &"big_treant"]:
			treants += 1
	return [treants, enemies.get_child_count()]


func record_spawn_batch(elapsed_us: int, count: int) -> void:
	if elapsed_us > peak_spawn_ms * 1000.0:
		peak_spawn_ms = elapsed_us / 1000.0
		peak_spawn_count = count
