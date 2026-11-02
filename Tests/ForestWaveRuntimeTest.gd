extends Node

func _ready() -> void:
	ResourceManager.set_current_expedition_planet(&"tree_planet")
	var battle := (load("res://Scenes/Battle/BattleMain.tscn") as PackedScene).instantiate() as Node2D
	battle.get_node("WaveManager").auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var waves := battle.get_node("WaveManager") as WaveManager
	var field := battle.get_node("Battlefield") as Battlefield
	# Rings (user design, Claude sync 53/54): wave 1 raises part of ring 1
	# - one treant per tree, one pit per treant; queued treant entries no
	# longer spawn, the fairy still does.
	var terrain := field.forest_terrain
	var rings := battle.get_node("ForestRings") as ForestRingRaise
	var storms := battle.get_node("ForestStorms") as ForestStormController
	var expected_tree_quotas := [11, 12, 14, 16, 18, 20, 22, 24, 25, 27, 30, 0]
	var scheduled_total := 0
	for wave_index in range(waves.wave_config.waves.size()):
		var wave := waves.wave_config.waves[wave_index] as WaveDefinition
		if not wave.spawn_all_at_start or wave.batch_spawning_enabled or wave.wait_for_spawn_phase_end:
			_fail("forest wave %d must spawn its quota at once" % (wave_index + 1))
			return
		var trees_in_wave := 0
		for entry in wave.enemy_entries:
			if entry.enemy_id in [&"treant", &"big_treant"]:
				trees_in_wave += entry.spawn_count
		if trees_in_wave != expected_tree_quotas[wave_index]:
			_fail("wave %d tree quota: %d" % [wave_index + 1, trees_in_wave])
			return
		scheduled_total += wave.get_total_spawn_count()
	if scheduled_total != 248 or waves.wave_config.get_total_waves() != 12:
		_fail("forest has twelve scheduled waves and 248 base requests, got %d" % scheduled_total)
		return
	if not waves.wave_config.advance_on_wave_clear:
		_fail("forest waves advance immediately after clear, without a timed gap")
		return
	for wave_index in range(12):
		var wave := waves.wave_config.waves[wave_index] as WaveDefinition
		if wave.boss_wave != (wave_index == 11):
			_fail("only wave 12 is the boss wave")
			return
	var ring_one := terrain.count_ring_trees(1, expected_tree_quotas[0])
	if ring_one != expected_tree_quotas[0]:
		_fail("wave 1 reserves its complete quota from standing trees (%d)" % ring_one)
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
	rings._process(0.0)
	if terrain.used_active_trees().size() != ring_one or rings.get_pending_count() != 0:
		_fail("the full first-wave tree quota rises together")
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
	if ForestVisual.build_tree_crown(24.0, 1, false).has("shadow"):
		_fail("walking treant shadow mesh should be absent")
		return
	var scheduled := waves.get_scheduled_spawned_count()
	# Storms regrow trees on the empty spots; they never spawn enemies.
	var regrown := storms.start_storm()
	if regrown != ring_one or storms.get_pending_respawn_count() != 0 or waves.total_lifetime_spawned != ring_one + 1:
		_fail("storm regrows the ring's spots without spawning")
		return
	for tree in terrain.trees:
		tree.finish_regrow()
	if not field.forest_terrain.used_active_trees().is_empty() or waves.get_scheduled_spawned_count() != scheduled:
		_fail("every spot is a standing tree again and the quota is unchanged")
		return
	# Wave 2 raises its full scheduled quota PLUS all 11 regrown ring-1
	# trees; none of the returnees displaces a scheduled new treant.
	var expected := terrain.count_ring_trees(2, expected_tree_quotas[1])
	if expected != expected_tree_quotas[1] + ring_one:
		_fail("storm returnees must add to wave 2's quota (%d vs %d)" % [expected, expected_tree_quotas[1] + ring_one])
		return
	var raised := rings.raise_rings(2)
	rings.flush()
	if raised != expected or terrain.used_active_trees().size() != expected:
		_fail("wave 2 raises ring 2 and the regrown inner ring (%d vs %d)" % [raised, expected])
		return
	var planned := storms.start_storm()
	if planned != expected or waves.get_pending_external_spawn_count() != 0:
		_fail("a large storm regrows every spot and reserves no spawns")
		return
	for tree in terrain.trees:
		tree.finish_regrow()
	if terrain.count_ring_trees(3, expected_tree_quotas[2]) != expected_tree_quotas[2] + expected:
		_fail("second storm adds all earlier tree origins to wave 3's normal quota")
		return
	var visible_count := terrain._visible_standing_trees().size()
	var final_count := terrain.count_ring_trees(12, 0)
	if final_count <= expected_tree_quotas[10] or absf(float(final_count) / float(visible_count) - 0.5) > 0.01 or rings.raise_rings(12) != final_count:
		_fail("wave 12 raises half of visible standing trees, independent of fixed quota")
		return
	print("FOREST_WAVE_12_VISIBLE_TREES: ", final_count)
	rings.stop()
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
