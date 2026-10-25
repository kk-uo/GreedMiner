class_name ForestTerrain
extends Node2D

## Deterministic forest for one battle (user design): the map is packed with
## trees round one big clearing, and EVERY tree is a ForestTree that can turn
## into a treant. A scheduled treant tears itself out of a standing tree
## (preferably one in view) and leaves an empty spot; rainstorms regrow the
## spots (ForestStormController); dwarves can dig a tree or a spot out for
## good. Only mining dwarves can fell trees.
@export_range(40, 8000, 1) var maximum_trees: int = 6000
@export_range(30.0, 300.0, 1.0) var tree_spacing: float = 46.0
@export_range(0.0, 1000.0, 1.0) var empty_radius: float = 200.0
@export_range(0.0, 600.0, 1.0) var sparse_ring_width: float = 200.0
@export_range(0.0, 1.0, 0.01) var sparse_ring_density: float = 0.06
## Treants prefer trees within this distance of the map centre (in view).
@export_range(100.0, 3000.0, 10.0) var spawn_view_radius: float = 950.0
## Rings (user design): ring 1 is the row of trees on the clearing's edge
## (plus the sparse trees inside it), ring 2 the row behind it, ... Wave N
## raises every standing tree of rings 1..N (ring N, plus inner trees that a
## storm regrew). 0 = one tree row (tree_spacing).
@export_range(0.0, 400.0, 1.0) var ring_width: float = 0.0
## True: ForestRingRaise owns every treant spawn and the wave queue's treant
## entries only set how many of the raised trees become big treants.
var rings_own_treants: bool = true

const TREE := preload("res://Scripts/Battle/Forest/ForestTree.gd")
const CANOPY_LAYER := preload("res://Scripts/Battle/Forest/ForestCanopyLayer.gd")
const TREE_CHUNKS := preload("res://Scripts/Battle/Forest/ForestTreeChunks.gd")
var trees: Array[ForestTree] = []
var escape_root: ForestTree
## Presentation: forest floor, clearing rim and border crowns (static), and
## the chunked renderer of all trees.
var canopy_layer: Node2D
var tree_chunks: Node2D
var _rng := RandomNumberGenerator.new()
var _center := Vector2.ZERO


func generate(field: Battlefield, seed_value: int) -> void:
	for tree in trees:
		if is_instance_valid(tree):
			tree.queue_free()
	trees.clear()
	for layer in [canopy_layer, tree_chunks]:
		if is_instance_valid(layer):
			layer.queue_free()
	_rng.seed = seed_value ^ 0x46525354
	var center := field.world_size * 0.5
	_center = center
	var bounds := Rect2(Vector2(60.0, 60.0), field.world_size - Vector2(120.0, 120.0))
	var phase := _rng.randf() * TAU
	var candidates: Array[Vector2] = []
	var y := bounds.position.y
	while y < bounds.end.y:
		var x := bounds.position.x
		while x < bounds.end.x:
			var point := Vector2(x, y) + Vector2(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35)) * tree_spacing
			var distance := point.distance_to(center)
			# A wobbly, natural clearing edge.
			var a := (point - center).angle()
			var wobble := 1.0 + 0.10 * sin(a * 3.0 + phase) + 0.06 * sin(a * 7.0 + phase * 2.0)
			var inner := empty_radius * maxf(wobble, 1.0)
			var outer := (empty_radius + sparse_ring_width) * wobble
			if distance >= inner and (distance >= outer or _rng.randf() <= sparse_ring_density):
				candidates.append(point)
			x += tree_spacing
		y += tree_spacing
	for index in range(candidates.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var value := candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = value
	var band := ring_width if ring_width > 0.0 else tree_spacing
	for point in candidates.slice(0, maximum_trees):
		var tree := TREE.new() as ForestTree
		tree.position = point
		var pa: float = (point - center).angle()
		var pw: float = 1.0 + 0.10 * sin(pa * 3.0 + phase) + 0.06 * sin(pa * 7.0 + phase * 2.0)
		var depth: float = (point as Vector2).distance_to(center) - (empty_radius + sparse_ring_width) * pw
		tree.ring = 1 + maxi(0, floori(depth / band))
		var far: bool = (point as Vector2).distance_to(center) > empty_radius + sparse_ring_width + 140.0
		if far and _rng.randf() < 0.05:
			tree.kind = &"giant"
			tree.canopy_radius = _rng.randf_range(48.0, 58.0)
		else:
			tree.canopy_radius = _rng.randf_range(21.0, 30.0)
		add_child(tree)
		trees.append(tree)
		tree.state_changed.connect(_on_tree_state)
	_pool_dirty = true
	canopy_layer = CANOPY_LAYER.new()
	canopy_layer.name = "ForestFloor"
	add_child(canopy_layer)
	move_child(canopy_layer, 0)
	canopy_layer.call("build", field.world_size, center, (empty_radius + sparse_ring_width) * 0.82, seed_value, bounds)
	tree_chunks = TREE_CHUNKS.new()
	tree_chunks.name = "Trees"
	add_child(tree_chunks)
	move_child(tree_chunks, 1)
	tree_chunks.call("setup", trees)


## A scheduled treant tears itself out of a standing tree - preferably one in
## view - and leaves an empty spot there. Returns null when none is left.
func take_spawn_tree() -> ForestTree:
	if _pool_dirty:
		_rebuild_pools()
	var pool := _near if not _near.is_empty() else _standing
	if pool.is_empty():
		return null
	var index := _rng.randi_range(0, pool.size() - 1)
	var picked: ForestTree = pool[index]
	_remove_from_pools(picked)
	if not picked.is_standing():
		_pool_dirty = true
		return take_spawn_tree()
	picked.uproot()
	return picked


## Cached standing trees (all / in view); rebuilt only after a regrow or a
## chop, so a whole wave can pick spawn trees cheaply.
var _near: Array[ForestTree] = []
var _standing: Array[ForestTree] = []
var _pool_dirty: bool = true


func _rebuild_pools() -> void:
	_pool_dirty = false
	_near.clear()
	_standing.clear()
	var view_sq := spawn_view_radius * spawn_view_radius
	for tree in trees:
		if not is_instance_valid(tree) or not tree.is_standing():
			continue
		_standing.append(tree)
		if tree.position.distance_squared_to(_center) <= view_sq:
			_near.append(tree)


func _remove_from_pools(tree: ForestTree) -> void:
	for pool in [_near, _standing]:
		var at: int = pool.find(tree)
		if at >= 0:
			pool[at] = pool[pool.size() - 1]
			pool.pop_back()


func _on_tree_state(tree: ForestTree) -> void:
	# Uprooting removes itself from the pools; regrowing / chopping rebuilds.
	if tree.is_standing() or tree.chopped:
		_pool_dirty = true


## Reserves every standing tree of rings 1..wave_number (the wave's own ring
## plus inner trees a storm regrew) and returns them sorted by angle round
## the clearing. Each one becomes exactly one treant: ForestRingRaise calls
## uproot() on it the moment its treant appears (tree -> pit, same frame).
func take_ring_trees(wave_number: int) -> Array[ForestTree]:
	var picked: Array[ForestTree] = []
	for tree in trees:
		if is_instance_valid(tree) and tree.is_standing() and tree.ring <= wave_number:
			picked.append(tree)
	var c := _center
	picked.sort_custom(func(a: ForestTree, b: ForestTree) -> bool:
		return (a.position - c).angle() < (b.position - c).angle())
	for tree in picked:
		_remove_from_pools(tree)
		tree.reserved = true
	return picked


## Number of standing trees a wave would raise (UI / tests).
func count_ring_trees(wave_number: int) -> int:
	var count := 0
	for tree in trees:
		if is_instance_valid(tree) and tree.is_standing() and tree.ring <= wave_number:
			count += 1
	return count


func get_center() -> Vector2:
	return _center


func has_spawn_trees() -> bool:
	for tree in trees:
		if is_instance_valid(tree) and tree.is_standing():
			return true
	return false


## Empty spots a storm can regrow (a treant left them, not dug out).
func used_active_trees() -> Array[ForestTree]:
	var result: Array[ForestTree] = []
	for tree in trees:
		if is_instance_valid(tree) and tree.uprooted and not tree.chopped:
			result.append(tree)
	return result


func choppable_in(world_position: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if is_instance_valid(escape_root) and escape_root.can_be_chopped() and escape_root.global_position.distance_to(world_position) <= radius:
		result.append(escape_root)
	for tree in trees:
		if is_instance_valid(tree) and tree.can_be_chopped() and tree.global_position.distance_to(world_position) <= radius:
			result.append(tree)
	return result
