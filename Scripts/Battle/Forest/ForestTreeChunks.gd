extends Node2D

## Draws every ForestTree of the map (thousands) as a few baked meshes per
## map chunk: ground pass (empty spots, dug spots, stumps), shadow pass,
## crown pass. A tree changing state (uprooted / regrown / chopped) re-bakes
## only its chunk, once per frame. Presentation only.
## Load with preload(); no class_name on purpose.

const ART := preload("res://Scripts/Battle/Forest/ForestArt.gd")
const CHUNK: float = 300.0
const MAX_REBUILDS_PER_FRAME: int = 2

## Vector2i -> {"trees": Array, "ground": ArrayMesh, "shadow": ArrayMesh, "crown": ArrayMesh}
var _chunks: Dictionary = {}
var _dirty: Dictionary = {}
var _views: Dictionary = {}
var _passes: Dictionary = {}


class ChunkPass extends Node2D:
	var mesh: ArrayMesh
	func _draw() -> void:
		if mesh != null:
			draw_mesh(mesh, null)


func _ready() -> void:
	set_process(false)


func setup(trees: Array) -> void:
	for pass_node in _passes.values():
		pass_node.hide()
		pass_node.queue_free()
	_passes.clear()
	_views.clear()
	_chunks.clear()
	_cache.clear()
	for layer in [&"ground", &"shadow", &"crown"]:
		var pass_node := Node2D.new()
		pass_node.name = String(layer).capitalize() + "Pass"
		add_child(pass_node)
		_passes[layer] = pass_node
	for tree in trees:
		var key := _key((tree as Node2D).position)
		if not _chunks.has(key):
			_chunks[key] = {"trees": [], "ground": null, "shadow": null, "crown": null}
		_chunks[key]["trees"].append(tree)
		(tree as Node2D).connect("state_changed", _on_tree_changed)
	for key in _chunks.keys():
		_views[key] = {}
		for layer in [&"ground", &"shadow", &"crown"]:
			var view := ChunkPass.new()
			view.name = "Chunk_%d_%d" % [key.x, key.y]
			_passes[layer].add_child(view)
			_views[key][layer] = view
		_bake(key)


func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))


func _on_tree_changed(tree: Node2D) -> void:
	_dirty[_key(tree.position)] = true
	set_process(true)


func _process(_delta: float) -> void:
	var rebuilt := 0
	for key in _dirty.keys():
		if _chunks.has(key):
			_bake(key)
		_dirty.erase(key)
		rebuilt += 1
		if rebuilt >= MAX_REBUILDS_PER_FRAME:
			break
	if _dirty.is_empty():
		set_process(false)


## Per tree, per state: cached triangles {pass: [vertices, colors]} so a
## chunk re-bake only concatenates arrays (no re-triangulating).
var _cache: Dictionary = {}


func _piece(tree: Node2D, state: StringName) -> Dictionary:
	var per: Dictionary = _cache.get(tree, {})
	if per.has(state):
		return per[state]
	var p: Vector2 = tree.position
	var r: float = tree.call("get_crown_radius")
	var seed := int(p.x * 7.0 + p.y * 13.0)
	var ground := MeshBatch2D.new()
	var shadow := MeshBatch2D.new()
	var crown := MeshBatch2D.new()
	match state:
		&"dug": ART.dug(ground, p, r, seed)
		&"stump": ART.stump(ground, p, maxf(9.0, r * 0.32), seed)
		# A vacated origin stays in gameplay state for storm regrowth, but no
		# longer paints a persistent hole on the ground.
		&"spot": pass
		_:
			if tree.kind == &"giant":
				ART.canopy_shadow(shadow, p, r, seed, 9)
				ART.giant_oak(crown, p, r, seed, false)
			else:
				ART.canopy_shadow(shadow, p, r, seed, 7)
				ART.canopy(crown, p, r, seed, ART.OAK if seed % 3 != 0 else ART.OAK_DEEP, 7, false)
	var piece := {
		"ground": [ground._vertices, ground._colors],
		"shadow": [shadow._vertices, shadow._colors],
		"crown": [crown._vertices, crown._colors],
	}
	per[state] = piece
	_cache[tree] = per
	return piece


static func _state(tree: Node2D) -> StringName:
	if tree.chopped:
		return &"dug" if tree.uprooted else &"stump"
	return &"spot" if tree.uprooted else &"standing"


func _bake(key: Vector2i) -> void:
	var chunk: Dictionary = _chunks[key]
	var lists := {"ground": [PackedVector2Array(), PackedColorArray()], "shadow": [PackedVector2Array(), PackedColorArray()], "crown": [PackedVector2Array(), PackedColorArray()]}
	var standing: Array = []
	for tree in chunk["trees"]:
		if not is_instance_valid(tree):
			continue
		var state := _state(tree)
		if state == &"standing":
			standing.append(tree)
			continue
		var piece := _piece(tree, state)
		lists["ground"][0].append_array(piece["ground"][0])
		lists["ground"][1].append_array(piece["ground"][1])
	# Small crowns first, big ones on top.
	standing.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.canopy_radius < b.canopy_radius)
	for tree in standing:
		var piece := _piece(tree, &"standing")
		for layer in ["shadow", "crown"]:
			lists[layer][0].append_array(piece[layer][0])
			lists[layer][1].append_array(piece[layer][1])
	for layer in ["ground", "shadow", "crown"]:
		chunk[layer] = _mesh(lists[layer][0], lists[layer][1])
		var view: ChunkPass = _views[key][StringName(layer)]
		view.mesh = chunk[layer]
		view.queue_redraw()


static func _mesh(vertices: PackedVector2Array, colors: PackedColorArray) -> ArrayMesh:
	if vertices.is_empty():
		return null
	var batch := MeshBatch2D.new()
	batch._vertices = vertices
	batch._colors = colors
	return batch.build()
