extends Node

## Headless integration checks for the new forest-only systems. This test
## disables scheduled waves so every observed enemy is an explicit test spawn.
func _ready() -> void:
	ResourceManager.set_current_expedition_planet(&"tree_planet")
	var packed := load("res://Scenes/Battle/BattleMain.tscn") as PackedScene
	var battle := packed.instantiate() as Node2D
	battle.get_node("WaveManager").auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var field := battle.get_node("Battlefield") as Battlefield
	var ship := battle.get_node("Ship") as Ship
	var waves := battle.get_node("WaveManager") as WaveManager
	_assert(field.planet_theme == &"forest", "tree planet theme")
	_assert(field.world_size == Vector2(3500.0, 2500.0), "forest map extends by 300 px on each axis")
	var visible_width := get_viewport().get_visible_rect().size.x / ship.world_camera.zoom.x
	var original_width := get_viewport().get_visible_rect().size.x / ship.world_visual_scale
	_assert(absf(visible_width - original_width - 300.0) < 1.0, "forest camera shows 300 more world pixels")
	_assert(waves.wave_config.planet_id == &"tree_planet" and waves.wave_config.get_total_waves() == 10, "tree wave config")
	_assert(waves.wave_config.get_validation_errors().is_empty(), "wave entries resolve")
	_assert(field.forest_terrain != null and field.forest_terrain.trees.size() > 20, "forest layout")
	var center := field.world_size * 0.5
	for tree in field.forest_terrain.trees:
		_assert(tree.position.distance_to(center) >= field.forest_terrain.empty_radius, "ship clearing")
	var first := field.take_forest_spawn_tree()
	var second := field.take_forest_spawn_tree()
	_assert(first != null and second != null and first != second, "distinct spawn trees")
	_assert(first.uprooted and second.uprooted and not second.is_standing(), "a treant leaves an empty spot")
	var target: Array[Node2D] = [first]
	var site := ForestChopSite.new()
	site.setup(target)
	field.get_interactables_root().add_child(site)
	site.advance_mining(site.dig_duration())
	_assert(first.chopped and not first.can_be_chopped(), "one felled tree closes point")
	var storms := battle.get_node("ForestStorms") as ForestStormController
	var before := waves.total_lifetime_spawned
	var scheduled_before := waves.get_scheduled_spawned_count()
	var regrown := storms.start_storm()
	_assert(regrown == 1 and not second.is_standing(), "storm regrows the empty spot (animated), not the dug one")
	second.finish_regrow()
	_assert(second.is_standing() and not second.uprooted, "the spot grows back into a standing tree")
	_assert(first.chopped and not first.is_standing(), "a dug spot never regrows")
	_assert(waves.total_lifetime_spawned == before and storms.get_pending_respawn_count() == 0, "storm spawns no enemies itself")
	_assert(waves.get_scheduled_spawned_count() == scheduled_before, "storm did not consume wave quota")
	var fairy := EnemyCatalog.instantiate_enemy(&"fairy") as ForestEnemy
	var treant := EnemyCatalog.instantiate_enemy(&"treant") as ForestEnemy
	var big_treant := EnemyCatalog.instantiate_enemy(&"big_treant") as ForestEnemy
	var boss_stats := EnemyCatalog.instantiate_enemy(&"chainsaw_spaceship_treant") as ForestBoss
	_assert(fairy.max_health == 300.0 and fairy.move_speed == 10.0, "fairy V2 health and move speed")
	_assert(fairy.attack_damage == 50.0 and fairy.attack_interval == 1.0 and fairy.attack_range == 150.0, "fairy V2 combat stats")
	_assert(fairy.heal_amount == fairy.attack_damage * 2.0, "fairy healing is twice its attack damage")
	_assert(treant.max_health == 1000.0 and treant.move_speed == 30.0 and treant.attack_damage == 10.0, "treant V2 stats")
	_assert(big_treant.max_health == 3000.0 and big_treant.move_speed == 30.0 and big_treant.attack_damage == 15.0, "big treant V2 stats")
	_assert(boss_stats.max_health == 50000.0 and boss_stats.move_speed == 15.0 and boss_stats.attack_damage == 10.0, "forest boss V2 stats")
	big_treant.queue_free()
	boss_stats.queue_free()
	fairy.target_ship = ship
	treant.target_ship = ship
	battle.get_node("Enemies").add_child(fairy)
	battle.get_node("Enemies").add_child(treant)
	fairy.global_position = field.to_global(Vector2(500.0, 500.0))
	treant.global_position = fairy.global_position + Vector2(25.0, 0.0)
	treant.take_damage(100.0)
	fairy._heal_nearest_treant()
	_assert(is_equal_approx(treant.get_current_health(), 1000.0), "fairy heals 100")
	treant.take_damage(50.0)
	fairy.global_position = ship.to_global(Ship.SHIP_SIZE * 0.5) + Vector2(150.0, 0.0)
	treant.global_position = fairy.global_position + Vector2(20.0, 0.0)
	fairy._physics_process(1.1)
	_assert(fairy.committed_to_attack, "fairy permanently targets ship in range")
	_assert(is_equal_approx(treant.get_current_health(), 950.0), "committed fairy stops healing")
	_assert(is_equal_approx(fairy.attack_damage, 50.0), "fairy attack damage")
	var boss := EnemyCatalog.instantiate_enemy(&"chainsaw_spaceship_treant") as ForestBoss
	boss.target_ship = ship
	battle.get_node("Enemies").add_child(boss)
	var mining_module: MiningModule
	for child in ship.installed_modules.get_children():
		if child is MiningModule:
			mining_module = child
			break
	_assert(mining_module != null, "mining module available for forest")
	var third := field.forest_terrain.trees[10]
	var dwarf_controller := battle.get("_dwarf_mining") as Node2D
	_assert(dwarf_controller.call("dispatch_to_trees", mining_module, third.global_position), "dwarf dispatch to tree")
	var worker := dwarf_controller.get("workers").get(mining_module) as Node2D
	worker.set("state", 1)
	worker.global_position = third.global_position
	boss.global_position = worker.global_position + Vector2(250.0, 0.0)
	boss._begin_saw_windup()
	var locked_direction := boss.get("_locked_direction") as Vector2
	_assert(locked_direction.dot(boss.global_position.direction_to(worker.global_position)) > 0.99, "saw prefers chopping dwarf")
	worker.global_position += Vector2(0.0, 100.0)
	_assert(boss.get("_locked_direction") == locked_direction, "saw direction remains locked")
	boss._fire_saw()
	var saw: HostileProjectile
	for child in get_children():
		if child is HostileProjectile:
			saw = child
	_assert(saw != null, "boss launches a saw")
	if saw != null:
		var dwarf_target: Vector2 = worker.call("get_enemy_target_position")
		saw.global_position = dwarf_target - locked_direction * 20.0
		var dwarf_hp_before := float(worker.get("hp"))
		saw._physics_process(0.1)
		_assert(float(worker.get("hp")) < dwarf_hp_before, "saw damages intercepting dwarf")
	await get_tree().process_frame
	battle.call("_on_evacuation_completed")
	var root := battle.get("_forest_root") as ForestRoot
	_assert(root != null and not root.chopped, "boss stops first escape attempt")
	var root_site := ForestChopSite.new()
	root_site.setup([root] as Array[Node2D])
	field.get_interactables_root().add_child(root_site)
	root_site.advance_mining(root_site.dig_duration())
	_assert(root.chopped, "dwarf can clear escape root")
	_assert(not battle.get_node("BattleUI/UIRoot/EvacuationPanel").get("_external_lock"), "escape unlocked after root")
	worker.global_position = ship.to_global(Ship.SHIP_SIZE * 0.5) + Vector2(300.0, 0.0)
	battle.call("_show_stranded_dwarves")
	_assert(battle.get_node_or_null("StrandedDwarfVisual") != null, "stranded dwarf effect is visual only")
	print("FOREST PLANET TEST PASS")
	battle.queue_free()
	get_tree().quit()

func _assert(condition: bool, label: String) -> void:
	if not condition:
		push_error("FOREST PLANET TEST FAIL: " + label)
		get_tree().quit(1)
