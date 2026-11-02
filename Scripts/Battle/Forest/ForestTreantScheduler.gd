extends Node

## Removes distant treants from Godot's per-enemy physics callback list.
## Six staggered groups use simple direct-to-ship movement at 10 Hz;
## enemies near the hull or a targetable dwarf retain full 60 Hz AI.
const BUCKET_COUNT: int = 6

var _buckets: Array[Array] = []
var _tick: int = 0
var _ship: Ship


func _ready() -> void:
	for _i in range(BUCKET_COUNT):
		_buckets.append([])


func register(enemy: ForestEnemy) -> void:
	if enemy == null or enemy.enemy_id not in [&"treant", &"big_treant"]:
		return
	var bucket := int(enemy.get_instance_id() % BUCKET_COUNT)
	_buckets[bucket].append(enemy)
	if not is_instance_valid(_ship):
		_ship = enemy.target_ship as Ship
	# A dwarf within reach is detected on this bucket's next tick (<= 0.1 s).
	# Avoid a scene-tree group scan for every one of a wave's 1,000+ spawns.
	var simple := enemy.is_far_from_ship()
	enemy.set_physics_process(not simple)
	enemy._scheduler_far = simple


func _physics_process(delta: float) -> void:
	var bucket := _tick % BUCKET_COUNT
	_tick += 1
	var kept: Array = []
	var dwarves := get_tree().get_nodes_in_group("mining_dwarves")
	for entry in _buckets[bucket]:
		if not is_instance_valid(entry):
			continue
		var enemy := entry as ForestEnemy
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		kept.append(enemy)
		var simple := enemy.is_far_from_ship() and not _has_nearby_dwarf(enemy, dwarves)
		if simple != enemy._scheduler_far:
			enemy._scheduler_far = simple
			enemy.set_physics_process(not simple)
			if simple:
				enemy._stop_attacking()
		if simple and enemy.can_process() and not enemy.is_dying():
			if enemy._emerge_left > 0.0:
				enemy._emerge_left = maxf(0.0, enemy._emerge_left - delta * BUCKET_COUNT)
			elif is_instance_valid(_ship) and _ship.current_hp > 0.0:
				var destination := _ship.to_global(Ship.SHIP_SIZE * 0.5)
				var direction := enemy.global_position.direction_to(destination)
				enemy._facing = direction.angle()
				enemy.global_position += direction * enemy.get_effective_move_speed() * delta * BUCKET_COUNT
	_buckets[bucket] = kept


func _has_nearby_dwarf(enemy: ForestEnemy, dwarves: Array[Node]) -> bool:
	if dwarves.is_empty():
		return false
	var reach := maxf(ResearchManager.get_dwarf_detection_range(enemy.mining_target_range), 0.0) + enemy.get_collision_radius()
	var reach_squared := reach * reach
	for dwarf in dwarves:
		if not is_instance_valid(dwarf) or not dwarf.has_method("is_enemy_targetable") or not dwarf.call("is_enemy_targetable"):
			continue
		var at: Vector2 = dwarf.call("get_enemy_target_position")
		if enemy.global_position.distance_squared_to(at) < reach_squared:
			return true
	return false


func get_scheduled_count() -> int:
	var count := 0
	for bucket in _buckets:
		for entry in bucket:
			if is_instance_valid(entry) and (entry as ForestEnemy)._scheduler_far:
				count += 1
	return count
