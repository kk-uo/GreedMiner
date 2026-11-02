extends Node

class TargetableDwarf extends Node2D:
	func is_enemy_targetable() -> bool:
		return true
	func get_enemy_target_position() -> Vector2:
		return global_position

func _ready() -> void:
	ResourceManager.set_current_expedition_planet(&"tree_planet")
	var battle := (load("res://Scenes/Battle/BattleMain.tscn") as PackedScene).instantiate() as Node2D
	battle.get_node("WaveManager").auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var field := battle.get_node("Battlefield") as Battlefield
	var rings := battle.get_node("ForestRings") as ForestRingRaise
	var batch := battle.get_node("ForestTreantBatch") as Node2D
	var scheduler := battle.get_node("ForestTreantScheduler") as Node
	var monitor := battle.get_node("ForestPerformanceMonitor") as Node
	var chunks := field.forest_terrain.tree_chunks
	if chunks == null:
		_fail("missing forest chunks")
		return
	var views: Dictionary = chunks.get("_views")
	if views.is_empty():
		_fail("missing per-chunk draw views")
		return
	var first_key: Vector2i = views.keys()[0]
	var untouched_key: Vector2i = views.keys()[-1]
	var untouched_view: Node2D = views[untouched_key][&"crown"]
	var dirty_view: Node2D = views[first_key][&"crown"]
	var untouched_draws := [0]
	var dirty_draws := [0]
	untouched_view.draw.connect(func() -> void: untouched_draws[0] += 1)
	dirty_view.draw.connect(func() -> void: dirty_draws[0] += 1)
	var changed_tree: ForestTree = chunks.get("_chunks")[first_key]["trees"][0]
	changed_tree.uproot()
	chunks._process(0.0)
	await get_tree().process_frame
	if dirty_draws[0] < 1 or untouched_draws[0] != 0:
		_fail("a tree state change must redraw only its own chunk")
		return
	var total := rings.raise_rings(12)
	var start_us := Time.get_ticks_usec()
	rings.flush()
	var spawn_ms := (Time.get_ticks_usec() - start_us) / 1000.0
	var ordinary: Array[ForestEnemy] = []
	var all_treants := 0
	for node in battle.get_node("Enemies").get_children():
		var enemy := node as ForestEnemy
		if enemy != null and enemy.enemy_id in [&"treant", &"big_treant"]:
			enemy._emerge_left = 0.0
			all_treants += 1
			if enemy.enemy_id == &"treant":
				ordinary.append(enemy)
	batch._process(0.1)
	var ship := battle.get_node("Ship") as Ship
	# Claude sync 75: every treant, near or far, big or small, is drawn by the
	# MultiMesh batch (about 16 draw calls for the whole army).
	if total < 500 or batch.get_batched_count() != all_treants or ordinary.is_empty():
		_fail("wave 12 batch must draw every treant (%d of %d)" % [batch.get_batched_count(), all_treants])
		return
	for node in battle.get_node("Enemies").get_children():
		var tree_enemy := node as ForestEnemy
		if tree_enemy != null and tree_enemy.enemy_id in [&"treant", &"big_treant"] and not tree_enemy._batch_crown_visible:
			_fail("a treant is still drawn individually")
			return
	var hit_target: ForestEnemy = ordinary[0]
	hit_target.take_damage(1.0)
	if not hit_target._batch_crown_visible or not hit_target.is_processing():
		_fail("a hit treant stays batched and only ticks its hit feedback")
		return
	for _step in range(60):
		await get_tree().process_frame
	monitor.call("sample_now")
	var steady_snapshot: Dictionary = (monitor.get("latest_snapshot") as Dictionary).duplicate(true)
	if int(steady_snapshot.get("treants", 0)) < 400 or int(steady_snapshot.get("active_enemies", 0)) < int(steady_snapshot.get("treants", 0)):
		_fail("performance snapshot must expose the live tree/enemy population")
		return
	var victim: ForestEnemy = null
	for enemy in ordinary:
		if enemy._batch_crown_visible:
			victim = enemy
			break
	if victim == null:
		_fail("no batched treant available for independent-health test")
		return
	if scheduler.call("get_scheduled_count") < 400 or victim.is_physics_processing():
		_fail("distant trees must leave individual physics processing")
		return
	var before_step := victim.global_position
	for _step in range(6):
		scheduler.call("_physics_process", 1.0 / 60.0)
	if victim.global_position == before_step:
		_fail("scheduled distant treant must still move toward the ship")
		return
	victim.global_position = ship.to_global(Ship.SHIP_SIZE * 0.5) + Vector2(300.0, 0.0)
	for _step in range(6):
		scheduler.call("_physics_process", 1.0 / 60.0)
	if not victim.is_physics_processing():
		_fail("near treant must resume full-rate AI")
		return
	victim.global_position = ship.to_global(Ship.SHIP_SIZE * 0.5) + Vector2(800.0, 0.0)
	for _step in range(6):
		scheduler.call("_physics_process", 1.0 / 60.0)
	if victim.is_physics_processing():
		_fail("distant treant must return to scheduled AI")
		return
	var dwarf := TargetableDwarf.new()
	battle.add_child(dwarf)
	dwarf.global_position = victim.global_position
	dwarf.add_to_group("mining_dwarves")
	for _step in range(6):
		scheduler.call("_physics_process", 1.0 / 60.0)
	if not victim.is_physics_processing():
		_fail("a mining dwarf must wake a distant treant's full AI")
		return
	dwarf.remove_from_group("mining_dwarves")
	dwarf.queue_free()
	for _step in range(6):
		scheduler.call("_physics_process", 1.0 / 60.0)
	if victim.is_physics_processing():
		_fail("distant treant must return to scheduled AI after dwarf leaves")
		return
	var shared_a := ForestVisual.shared_distant_crown(42)
	var shared_b := ForestVisual.shared_distant_crown(42)
	if shared_a["crown"] != shared_b["crown"]:
		_fail("distant crowns must reuse the same mesh resource")
		return
	var hp := victim.get_current_health()
	victim.take_damage(1.0)
	if victim.get_current_health() >= hp:
		_fail("batched treants must retain independent damage")
		return
	if monitor.get("peak_spawn_count") < 1:
		_fail("wave-12 spawn batches were not profiled")
		return
	var peak_batch_ms: float = monitor.get("peak_spawn_ms")
	print("FOREST PERF WAVE12: raised=", total, " batch_crowns=", batch.get_batched_count(), " total_spawn_ms=", spawn_ms, " peak_batch_ms=", peak_batch_ms)
	print("FOREST PERF SUSTAINED HEADLESS: ", steady_snapshot)
	print("FOREST PERFORMANCE TEST PASS")
	battle.queue_free()
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("FOREST PERFORMANCE TEST FAIL: " + message)
	get_tree().quit(1)
