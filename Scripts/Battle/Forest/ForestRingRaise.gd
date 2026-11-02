class_name ForestRingRaise
extends Node


## Tree Planet treant waves: when wave N starts, its configured new-tree quota
## PLUS every storm-regrown tree tears out of the ground in a sweep.
## Prefer ring N for the quota; use outer never-raised trees when it needs
## more origins. Wave 12 instead raises a configurable share of visible trees. Each becomes
## ONE treant and leaves exactly one pit (ForestTree.uproot). The wave queue's
## treant entries no longer spawn (EnemySpawner frees them); their combined
## count is the new-tree quota and big_treant count picks its largest new trees.
## BattleMain creates this next to ForestStormController.

const TREANT := preload("res://Scenes/Enemies/treant.tscn")
const BIG_TREANT := preload("res://Scenes/Enemies/big_treant.tscn")
const PENDING_SOURCE := &"forest_rings"

var terrain: ForestTerrain
var wave_manager: WaveManager
var enemies: Node2D
var ship: Ship
var treant_batch: Node2D
var treant_scheduler: Node
var performance_monitor: Node
var raise_duration: float = 0.0
## Creation and tree-chunk invalidation are deliberately spread over frames.
var maximum_raises_per_frame: int = 64
## Trees raised this battle (tests / balance logs).
var total_raised: int = 0
## Last raise: wave number -> trees raised.
var raised_by_wave: Dictionary = {}

var _queue: Array[Dictionary] = []
var _elapsed: float = 0.0
var _cursor: int = 0


func _ready() -> void:
	if wave_manager != null and not wave_manager.wave_started.is_connected(_on_wave_started):
		wave_manager.wave_started.connect(_on_wave_started)
	set_process(false)


## Raises wave_number's trees now. Returns how many treants will appear.
func raise_rings(wave_number: int) -> int:
	if not is_instance_valid(terrain):
		return 0
	var trees := terrain.take_ring_trees(wave_number, _tree_quota(wave_number))
	var big := _big_count(wave_number)
	# Scheduled big-treant quota applies only to newly raised trees. Regrown
	# trees retain the type they had before the storm; the final wave uses
	# each untouched tree's natural size instead of a fixed quota.
	var by_size: Array[ForestTree] = []
	for tree in trees:
		if not tree.has_spawned_treant:
			by_size.append(tree)
	by_size.sort_custom(func(a: ForestTree, b: ForestTree) -> bool: return a.canopy_radius > b.canopy_radius)
	var big_set: Dictionary = {}
	if wave_number == terrain.final_canopy_wave:
		for tree in by_size:
			if tree.kind == &"giant":
				big_set[tree] = true
	else:
		for i in range(mini(big, by_size.size())):
			big_set[by_size[i]] = true
	# Start the sweep at a random angle so rings do not always rise the same way.
	var start := randi_range(0, maxi(trees.size() - 1, 0))
	for i in range(trees.size()):
		var tree: ForestTree = trees[(start + i) % trees.size()]
		_queue.append({"tree": tree, "big": big_set.has(tree) or (tree.has_spawned_treant and tree.spawned_enemy_id == &"big_treant"), "regrown": tree.has_spawned_treant, "at": raise_duration * float(i) / float(maxi(trees.size(), 1))})
	total_raised += trees.size()
	if not trees.is_empty() and is_instance_valid(terrain):
		EnemySfx.play(terrain.get_center(), preload("res://Assets/Audio/Forest/ring_rise.wav"), -3.0, 0.0)
	raised_by_wave[wave_number] = trees.size()
	_update_pending()
	set_process(not _queue.is_empty())
	return trees.size()


## Spawns everything still queued at once (tests / battle end).
func flush() -> void:
	_elapsed = INF
	while not _queue.is_empty():
		_process(0.0)


func stop() -> void:
	for i in range(_cursor, _queue.size()):
		var tree: ForestTree = _queue[i]["tree"]
		if is_instance_valid(tree):
			tree.reserved = false
	_queue.clear()
	_cursor = 0
	_elapsed = 0.0
	_update_pending()
	set_process(false)


func get_pending_count() -> int:
	return _queue.size() - _cursor


func _on_wave_started(wave_number: int, _total: int, _boss: bool) -> void:
	raise_rings(wave_number)


func _process(delta: float) -> void:
	var started_us := Time.get_ticks_usec()
	_elapsed += delta
	var raised_this_frame := 0
	while _cursor < _queue.size() and float(_queue[_cursor]["at"]) <= _elapsed and raised_this_frame < maxi(maximum_raises_per_frame, 1):
		_spawn(_queue[_cursor])
		_cursor += 1
		raised_this_frame += 1
	if _cursor >= _queue.size():
		_queue.clear()
		_cursor = 0
		_elapsed = 0.0
		set_process(false)
	_update_pending()
	if raised_this_frame > 0 and is_instance_valid(performance_monitor):
		performance_monitor.call("record_spawn_batch", Time.get_ticks_usec() - started_us, raised_this_frame)


func _spawn(entry: Dictionary) -> void:
	var tree: ForestTree = entry["tree"]
	if not is_instance_valid(tree) or not is_instance_valid(enemies):
		return
	if tree.chopped:
		# Dwarves dug it out while the ring was rising: no treant.
		tree.reserved = false
		return
	# Tree -> pit and tree -> treant in the same frame: one for one.
	tree.uproot()
	var big: bool = entry["big"]
	var enemy := (BIG_TREANT if big else TREANT).instantiate() as BasicEnemy
	tree.spawned_enemy_id = enemy.enemy_id
	enemy.set_meta("forest_tree_spawn", tree.get_instance_id())
	enemy.set_meta("spawn_origin", &"extra_weather" if entry["regrown"] else &"forest_ring")
	# The treant IS this tree: same crown, same seed (ForestVisual).
	enemy.set_meta("forest_crown", {
		"radius": tree.get_crown_radius(),
		"seed": tree.get_crown_seed(),
		"giant": tree.kind == &"giant",
	})
	enemy.target_ship = ship
	enemies.add_child(enemy)
	enemy.global_position = tree.global_position
	if is_instance_valid(treant_scheduler):
		treant_scheduler.call("register", enemy)
	if is_instance_valid(treant_batch):
		treant_batch.call("register", enemy)


func _big_count(wave_number: int) -> int:
	return _entry_count(wave_number, &"big_treant")


func _tree_quota(wave_number: int) -> int:
	return _entry_count(wave_number, &"treant") + _big_count(wave_number)


func _entry_count(wave_number: int, enemy_id: StringName) -> int:
	if wave_manager == null or wave_manager.wave_config == null:
		return 0
	var waves := wave_manager.wave_config.waves
	if wave_number < 1 or wave_number > waves.size():
		return 0
	var count := 0
	for entry in waves[wave_number - 1].enemy_entries:
		if entry != null and entry.enemy_id == enemy_id:
			count += entry.spawn_count
	return count


func _update_pending() -> void:
	if wave_manager != null:
		wave_manager.set_pending_external_spawns(PENDING_SOURCE, get_pending_count())
