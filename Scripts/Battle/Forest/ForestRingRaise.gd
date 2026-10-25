class_name ForestRingRaise
extends Node

## Tree Planet treant waves (user design): when wave N starts, every standing
## tree of rings 1..N tears itself out of the ground at once - a sweep round
## the clearing - and marches in. Ring N is the wave's own row of trees;
## inner trees that a storm regrew come along too. Each tree becomes exactly
## ONE treant and leaves exactly one pit (ForestTree.uproot). The wave queue's
## treant entries no longer spawn (EnemySpawner frees them); its big_treant
## count picks how many of the raised trees (the biggest) become big treants.
## BattleMain creates this next to ForestStormController.

const TREANT := preload("res://Scenes/Enemies/treant.tscn")
const BIG_TREANT := preload("res://Scenes/Enemies/big_treant.tscn")
const PENDING_SOURCE := &"forest_rings"

var terrain: ForestTerrain
var wave_manager: WaveManager
var enemies: Node2D
var ship: Ship
var raise_duration: float = 1.6
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


## Raises rings 1..wave_number now. Returns how many treants will appear.
func raise_rings(wave_number: int) -> int:
	if not is_instance_valid(terrain):
		return 0
	var trees := terrain.take_ring_trees(wave_number)
	var big := _big_count(wave_number)
	# The biggest crowns become big treants.
	var by_size := trees.duplicate()
	by_size.sort_custom(func(a: ForestTree, b: ForestTree) -> bool: return a.canopy_radius > b.canopy_radius)
	var big_set: Dictionary = {}
	for i in range(mini(big, by_size.size())):
		big_set[by_size[i]] = true
	# Start the sweep at a random angle so rings do not always rise the same way.
	var start := randi_range(0, maxi(trees.size() - 1, 0))
	for i in range(trees.size()):
		var tree: ForestTree = trees[(start + i) % trees.size()]
		_queue.append({"tree": tree, "big": big_set.has(tree), "at": raise_duration * float(i) / float(maxi(trees.size(), 1))})
	total_raised += trees.size()
	raised_by_wave[wave_number] = trees.size()
	_update_pending()
	set_process(not _queue.is_empty())
	return trees.size()


## Spawns everything still queued at once (tests / battle end).
func flush() -> void:
	_elapsed = INF
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
	_elapsed += delta
	while _cursor < _queue.size() and float(_queue[_cursor]["at"]) <= _elapsed:
		_spawn(_queue[_cursor])
		_cursor += 1
	if _cursor >= _queue.size():
		_queue.clear()
		_cursor = 0
		_elapsed = 0.0
		set_process(false)
	_update_pending()


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
	enemy.set_meta("spawn_origin", &"forest_ring")
	# The treant IS this tree: same crown, same seed (ForestVisual).
	enemy.set_meta("forest_crown", {
		"radius": tree.get_crown_radius(),
		"seed": tree.get_crown_seed(),
		"giant": tree.kind == &"giant",
	})
	enemy.target_ship = ship
	enemies.add_child(enemy)
	enemy.global_position = tree.global_position


func _big_count(wave_number: int) -> int:
	if wave_manager == null or wave_manager.wave_config == null:
		return 0
	var waves := wave_manager.wave_config.waves
	if wave_number < 1 or wave_number > waves.size():
		return 0
	var count := 0
	for entry in waves[wave_number - 1].enemy_entries:
		if entry != null and entry.enemy_id == &"big_treant":
			count += entry.spawn_count
	return count


func _update_pending() -> void:
	if wave_manager != null:
		wave_manager.set_pending_external_spawns(PENDING_SOURCE, get_pending_count())
