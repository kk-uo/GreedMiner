extends Node

func _ready() -> void:
	ResourceManager.set_current_expedition_planet(&"tree_planet")
	var battle := (load("res://Scenes/Battle/BattleMain.tscn") as PackedScene).instantiate() as Node2D
	battle.get_node("WaveManager").auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var waves := battle.get_node("WaveManager") as WaveManager
	var field := battle.get_node("Battlefield") as Battlefield
	# Rings (user design, Claude sync 53): wave 1 raises every tree of ring 1
	# - one treant per tree, one pit per treant; queued treant entries no
	# longer spawn, the fairy still does.
	var terrain := field.forest_terrain
	var rings := battle.get_node("ForestRings") as ForestRingRaise
	var ring_one := terrain.count_ring_trees(1)
	if ring_one < 20:
		_fail("ring 1 holds the clearing's edge row (%d trees)" % ring_one)
		return
	if not waves.start_wave_system():
		_fail("wave system start")
		return
	for step in range(40):
		if rings.raised_by_wave.has(1):
			break
		waves._process(0.25)
	if waves.get_pending_external_spawn_count() != ring_one or terrain.used_active_trees().size() != 0:
		_fail("the rising ring holds the wave open and trees stand until their treant appears")
		return
	rings.flush()
	for step in range(10):
		if waves.get_current_wave_number() != 1:
			break
		waves._process(2.1)
	var spots := terrain.used_active_trees().size()
	if spots != ring_one or waves.total_lifetime_spawned != ring_one + 1 or rings.raised_by_wave.get(1, 0) != ring_one:
		_fail("wave 1 raised the whole ring: %d spots, %d spawned (ring %d + 1 fairy)" % [spots, waves.total_lifetime_spawned, ring_one])
		return
	var treants := 0
	for node in battle.get_node("Enemies").get_children():
		if node is ForestEnemy and (node as ForestEnemy).enemy_id in [&"treant", &"big_treant"]:
			treants += 1
			if not (node as Node).has_meta("forest_crown"):
				_fail("a raised treant carries its tree's crown")
				return
	if treants != ring_one:
		_fail("one treant per raised tree (%d vs %d)" % [treants, ring_one])
		return
	var scheduled := waves.get_scheduled_spawned_count()
	var storms := battle.get_node("ForestStorms") as ForestStormController
	# Storms regrow trees on the empty spots; they never spawn enemies.
	var regrown := storms.start_storm()
	if regrown != ring_one or storms.get_pending_respawn_count() != 0 or waves.total_lifetime_spawned != ring_one + 1:
		_fail("storm regrows the ring's spots without spawning")
		return
	for tree in field.forest_terrain.trees:
		tree.finish_regrow()
	if not field.forest_terrain.used_active_trees().is_empty() or waves.get_scheduled_spawned_count() != scheduled:
		_fail("every spot is a standing tree again and the quota is unchanged")
		return
	# Wave 2 raises ring 2 plus the regrown ring-1 trees.
	var expected := terrain.count_ring_trees(2)
	var raised := rings.raise_rings(2)
	rings.flush()
	if raised != expected or terrain.used_active_trees().size() != expected:
		_fail("wave 2 raises ring 2 and the regrown inner ring (%d vs %d)" % [raised, expected])
		return
	var planned := storms.start_storm()
	if planned != expected or waves.get_pending_external_spawn_count() != 0:
		_fail("a large storm regrows every spot and reserves no spawns")
		return
	storms.stop_storms()
	if waves.get_pending_external_spawn_count() != 0:
		_fail("battle shutdown leaves no pending storm spawns")
		return
	print("FOREST WAVE RUNTIME TEST PASS")
	battle.queue_free()
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("FOREST WAVE RUNTIME TEST FAIL: " + message)
	get_tree().quit(1)
