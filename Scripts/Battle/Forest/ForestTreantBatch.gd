class_name ForestTreantBatch
extends Node2D

## Draws EVERY treant and big treant with a handful of MultiMeshes, so the
## whole forest army costs at most 112 draw calls (7 groups x 16 layers)
## instead of ~30 canvas commands per tree (the cause of the forest stutter, Claude sync 75):
##   legs  - 3 step poses, rotated to face where the treant walks
##   crowns - 9 ordinary + 3 giant variants, world-lit so never rotated
##   eyes  - one mesh, rotated, fading in as the roots tear free
## Per instance and every frame: position, facing, walk step, emergence
## (shudder, roots tearing out, big-treant swell), hit wobble / squash (read
## from the node's rotation / scale, BasicEnemy hit feedback) and hit
## brightening (node self_modulate x modulate as the instance colour).
## Collision, health, AI and rewards stay on each treant node.
const VARIANTS := 9
const GIANT_VARIANTS := 3
const BASE_RADIUS := 40.0
const GIANT_RADIUS := 46.0
const STEP_RATE := 1.4
const BIG_CROWN_SCALE := 1.4

## Treants near the ship or still rising redraw every frame; distant walking
## ones are split into FAR_GROUPS groups refreshed one group per frame (each
## at 60 / FAR_GROUPS Hz = the 10 Hz at which ForestTreantScheduler moves
## them, same instance-id buckets), so the per-frame cost stays flat. Moving a treant
## between groups refreshes both groups that frame (no gaps or doubles).
const FAR_GROUPS := 6
const NEAR := FAR_GROUPS

## [enemy, crown_index, radius, big, phase, group]
var _entries: Array = []
var _registered_ids: Dictionary = {}
## FAR_GROUPS far groups, then the near group (drawn last, on top).
var _groups: Array[Group] = []
var _time: float = 0.0
var _frame: int = 0


class Group extends Node2D:
	var legs: Array[MultiMesh] = []
	## 0..VARIANTS-1 ordinary crowns, then the giant crowns.
	var crowns: Array[MultiMesh] = []
	var eyes: MultiMesh
	var all: Array[MultiMesh] = []
	var count: int = 0

	func _init() -> void:
		for pose in range(3):
			legs.append(_layer(ForestVisual.batch_legs_mesh(pose)))
		for variant in range(VARIANTS):
			crowns.append(_layer(ForestVisual.shared_distant_crown(variant, false)["crown"]))
		for variant in range(GIANT_VARIANTS):
			crowns.append(_layer(ForestVisual.shared_distant_crown(variant, true)["crown"]))
		eyes = _layer(ForestVisual.batch_eyes_mesh())

	func _layer(mesh: Mesh) -> MultiMesh:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_2D
		multi.use_colors = true
		multi.mesh = mesh
		multi.instance_count = 16
		multi.visible_instance_count = 0
		var view := MultiMeshInstance2D.new()
		view.multimesh = multi
		add_child(view)
		all.append(multi)
		return multi


func _ready() -> void:
	add_to_group(&"forest_treant_batch")
	for index in range(FAR_GROUPS + 1):
		var group := Group.new()
		group.name = "Near" if index == NEAR else "Far%d" % index
		add_child(group)
		_groups.append(group)
	set_process(false)


func register(enemy: ForestEnemy) -> void:
	if enemy == null or enemy.enemy_id not in [&"treant", &"big_treant"]:
		return
	var id := enemy.get_instance_id()
	if _registered_ids.has(id):
		return
	_registered_ids[id] = true
	var info: Dictionary = enemy.get_meta("forest_crown", {})
	var big := enemy.enemy_id == &"big_treant"
	var giant := big and bool(info.get("giant", false))
	var seed_value := int(info.get("seed", id % 100000))
	var crown_index := VARIANTS + posmod(seed_value, GIANT_VARIANTS) if giant else posmod(seed_value, VARIANTS)
	var radius := float(info.get("radius", GIANT_RADIUS if big else BASE_RADIUS))
	_entries.append([enemy, crown_index, radius, big, randf() * 10.0, -1])
	enemy.set_batch_crown_visible(true)
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_frame += 1
	var members: Array[Array] = []
	for _i in range(FAR_GROUPS + 1):
		members.append([])
	var dirty: Array[bool] = []
	dirty.resize(FAR_GROUPS + 1)
	dirty.fill(false)
	dirty[NEAR] = true
	dirty[_frame % FAR_GROUPS] = true
	var live: Array = []
	for entry: Array in _entries:
		# Check validity before casting: casting a freed treant is an error.
		if not is_instance_valid(entry[0]) or (entry[0] as Node).is_queued_for_deletion():
			if int(entry[5]) >= 0:
				dirty[int(entry[5])] = true
			continue
		var enemy := entry[0] as ForestEnemy
		live.append(entry)
		var group := NEAR
		if enemy._scheduler_far and enemy._emerge_left <= 0.0 and not enemy.is_dying():
			group = enemy.get_instance_id() % FAR_GROUPS
		if group != int(entry[5]):
			if int(entry[5]) >= 0:
				dirty[int(entry[5])] = true
			dirty[group] = true
			entry[5] = group
		members[group].append(entry)
	_entries = live
	var to_local_xf := global_transform.affine_inverse()
	for index in range(FAR_GROUPS + 1):
		if dirty[index]:
			_rebuild(_groups[index], members[index], to_local_xf)
	if _entries.is_empty():
		set_process(false)


func _rebuild(group: Group, entries: Array, to_local_xf: Transform2D) -> void:
	var needed := entries.size()
	for multi in group.all:
		if multi.instance_count < needed:
			multi.instance_count = maxi(needed, multi.instance_count * 2)
	var leg_counts: Array[int] = [0, 0, 0]
	var crown_counts: Array[int] = []
	crown_counts.resize(group.crowns.size())
	crown_counts.fill(0)
	var eye_count := 0
	for entry: Array in entries:
		var enemy: ForestEnemy = entry[0]
		if enemy.is_dying():
			continue
		var radius: float = entry[2]
		var big: bool = entry[3]
		var t: float = _time + float(entry[4])
		var rise := 1.0 - enemy._emerge_left / maxf(enemy.emerge_duration, 0.001)
		var tear := clampf((rise - 0.45) / 0.55, 0.0, 1.0)
		tear = 1.0 - pow(1.0 - tear, 3.0)
		var offset := Vector2.ZERO
		if rise < 0.45:
			offset = Vector2(sin(t * 61.0), cos(t * 47.0)) * 2.2 * clampf(rise / 0.45, 0.0, 1.0)
		var hop := sin(PI * tear) * 0.12 if rise < 1.0 else 0.0
		var swell := 1.0 + (BIG_CROWN_SCALE - 1.0) * clampf((rise - 0.45) / 0.55, 0.0, 1.0) if big else 1.0
		var r := radius * swell
		offset.y -= r * hop * 0.25
		var wobble := enemy.rotation
		var squash := enemy.scale
		var at := to_local_xf * enemy.global_position
		var tint := enemy.self_modulate * enemy.modulate
		# Crown: world-lit, only the hit wobble turns it.
		var crown_index: int = entry[1]
		var crown_base := GIANT_RADIUS if crown_index >= VARIANTS else BASE_RADIUS
		var crown_multi := group.crowns[crown_index]
		crown_multi.set_instance_transform_2d(crown_counts[crown_index], Transform2D(wobble, squash * (r / crown_base) * (1.0 + hop * 0.15), 0.0, at + offset))
		crown_multi.set_instance_color(crown_counts[crown_index], tint)
		crown_counts[crown_index] += 1
		if tear <= 0.0:
			continue
		var turn := enemy._facing + wobble
		var body := squash * (r / ForestVisual.BATCH_RADIUS)
		# Legs: the step pose from the walk cycle; standing while attacking or
		# still rising. Roots reach out as they tear free.
		var pose := 0
		if not enemy._is_attacking and rise >= 1.0:
			var step := sin(t * TAU * STEP_RATE)
			pose = 1 if step > 0.35 else (2 if step < -0.35 else 0)
		var legs_multi := group.legs[pose]
		legs_multi.set_instance_transform_2d(leg_counts[pose], Transform2D(turn, body * (0.55 + 0.45 * tear), 0.0, at))
		legs_multi.set_instance_color(leg_counts[pose], tint)
		leg_counts[pose] += 1
		group.eyes.set_instance_transform_2d(eye_count, Transform2D(turn, body, 0.0, at + offset))
		group.eyes.set_instance_color(eye_count, Color(tint, tint.a * tear))
		eye_count += 1
	var total := 0
	for pose in range(3):
		group.legs[pose].visible_instance_count = leg_counts[pose]
	for index in range(group.crowns.size()):
		group.crowns[index].visible_instance_count = crown_counts[index]
		total += crown_counts[index]
	group.eyes.visible_instance_count = eye_count
	group.count = total


## Treants currently drawn by the batch (one crown each).
func get_batched_count() -> int:
	var total := 0
	for group in _groups:
		total += group.count
	return total
