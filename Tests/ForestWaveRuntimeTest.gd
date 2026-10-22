extends Node

func _ready() -> void:
	ResourceManager.set_current_expedition_planet(&"tree_planet")
	var battle := (load("res://Scenes/Battle/BattleMain.tscn") as PackedScene).instantiate() as Node2D
	battle.get_node("WaveManager").auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var waves := battle.get_node("WaveManager") as WaveManager
	var field := battle.get_node("Battlefield") as Battlefield
	if not waves.start_wave_system():
		_fail("wave system start")
		return
	for step in range(10):
		if waves.get_current_wave_number() != 1:
			break
		waves._process(2.1)
	if waves.total_lifetime_spawned != 5 or field.forest_terrain.used_active_trees().size() != 4:
		_fail("wave 1 spawned exactly four treants from trees and one fairy")
		return
	var scheduled := waves.get_scheduled_spawned_count()
	var storms := battle.get_node("ForestStorms") as ForestStormController
	# Storms regrow trees on the empty spots; they never spawn enemies.
	var regrown := storms.start_storm()
	if regrown != 4 or storms.get_pending_respawn_count() != 0 or waves.total_lifetime_spawned != 5:
		_fail("storm regrows the four spots without spawning")
		return
	for tree in field.forest_terrain.trees:
		tree.finish_regrow()
	if not field.forest_terrain.used_active_trees().is_empty() or waves.get_scheduled_spawned_count() != scheduled:
		_fail("every spot is a standing tree again and the quota is unchanged")
		return
	# The next treants can tear out of the regrown trees again.
	for index in range(24):
		field.take_forest_spawn_tree()
	var planned := storms.start_storm()
	if planned != 24 or waves.get_pending_external_spawn_count() != 0:
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
