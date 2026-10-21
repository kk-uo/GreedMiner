extends Node

const CRYSTAL := preload("res://Scripts/Battle/RockyCrystal.gd")
const CONTROLLER := preload("res://Scripts/Mining/DwarfMiningController.gd")
const MODULE := preload("res://Scenes/Modules/Mining/mining_module.tscn")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	ProgressionStore.set_save_path_for_testing("user://mining_research_tree_test.json")
	ProgressionStore.reset_all_progress()
	ResearchManager.reload_progress()
	ResourceManager.reload_persistent_resources()
	_check(ResearchManager.configuration.get_validation_errors().is_empty(), "tree validates")
	_check(ResearchManager.get_upgrade_cost(&"mining_install_slot_unlock") == 200, "root cost")
	_check(ResearchManager.get_tree_node_state(&"mining_value_1") == &"LOCKED", "root prerequisite")
	_check(ResearchManager.get_crystal_respawn_seconds() == 0.0, "no initial regrowth")
	_check(ResearchManager.get_dwarf_max_hp() == 50.0, "initial dwarf hp")
	_check(ResearchManager.get_crystal_mining_seconds() == 10.0, "initial mining time")
	_check(ResearchManager.get_upgrade_cost(&"mining_worker") == 1000, "second dwarf cost")
	_check(ResearchManager.get_upgrade_cost(&"mining_hp_2") == 175, "second health cost")
	_check(ResearchManager.get_upgrade_cost(&"mining_hp_3") == 325, "third health cost")
	_check(ResearchManager.get_upgrade_cost(&"mining_detection") == 500, "stealth cost")
	_check(ResearchManager.get_upgrade_cost(&"mining_move_speed") == 1500, "movement cost")
	_check(ResearchManager.get_tree_node_state(&"mining_move_speed") == &"LOCKED", "movement initially locked")
	ResearchManager.progress.levels["mining_worker"] = 1
	_check(ResearchManager.get_tree_node_state(&"mining_move_speed") == &"LOCKED", "one prerequisite insufficient")
	ResearchManager.progress.levels["mining_detection"] = 1
	_check(ResearchManager.get_tree_node_state(&"mining_move_speed") == &"AVAILABLE", "both prerequisites required")
	_check(ResearchManager.get_dwarf_detection_range(200.0) == 175.0, "stealth range")
	_check(ResearchManager.get_dwarf_detection_range(150.0) == 150.0, "stealth does not increase shorter ranges")
	ResearchManager.progress.levels["mining_move_speed"] = 1
	_check(ResearchManager.get_dwarf_movement_speed_bonus() == 5.0, "movement speed bonus")
	var crystal := CRYSTAL.new()
	crystal.configure(1.0, 0.0, true, false)
	add_child(crystal)
	_check(crystal.advance_mining(5.0) == 0.0, "partial mining has no reward")
	_check(crystal.advance_mining(5.0) == 30.0, "base gold reward")
	_check(crystal.advance_mining(1.0) == 0.0, "no duplicate reward")
	for id in [&"mining_value_1", &"mining_value_2", &"mining_respawn_1", &"mining_hp_1", &"mining_hp_2", &"mining_hp_3", &"mining_time_1", &"mining_time_2", &"mining_qte", &"mining_passive", &"mining_worker"]:
		ResearchManager.progress.levels[String(id)] = 1
	_check(is_equal_approx(ResearchManager.get_crystal_value_multiplier(), 1.1), "additive crystal bonus")
	_check(ResearchManager.get_crystal_respawn_seconds() == 150.0, "first regrowth")
	_check(ResearchManager.get_dwarf_max_hp() == 80.0, "three dwarf hp bonuses")
	_check(ResearchManager.get_crystal_mining_seconds() == 9.0, "both time bonuses")
	_check(ResearchManager.get_mining_qte_ore_multiplier() == 1.25, "qte ore bonus")
	var ore := CRYSTAL.new()
	ore.configure(1.0, 0.0, true, false)
	add_child(ore)
	_check(ore.advance_mining(4.5) == 0.0, "first worker contributes shared progress")
	_check(is_equal_approx(ore.advance_mining(4.5), 33.0), "second worker completes one boosted reward")
	_check(not ore.can_be_mined() and not ore.visible, "depleted crystal hidden")
	_check(ore.advance_mining(1.0) == 0.0, "completed crystal pays only once")
	ore._regrow()
	_check(ore.can_be_mined() and ore.mining_progress == 0.0 and ore.visible, "regrows in place")
	ResearchManager.progress.levels["mining_respawn_2"] = 1
	_check(ResearchManager.get_crystal_respawn_seconds() == 140.0, "second regrowth")
	_check(ResearchManager.save_progress(), "research progress saves")
	ResearchManager.reload_progress()
	_check(is_equal_approx(ResearchManager.get_crystal_value_multiplier(), 1.1) and ResearchManager.get_crystal_respawn_seconds() == 140.0, "research progress restores")
	_check(ResearchManager.get_dwarf_max_hp() == 80.0 and ResearchManager.get_dwarf_movement_speed_bonus() == 5.0, "new research progress restores")
	var module := MODULE.instantiate() as MiningModule
	add_child(module)
	_check(is_equal_approx(module.get_effective_ore_per_second(), 1.5), "passive output bonus")
	_check(is_equal_approx(MiningQteManager.calculate_reward_for_seconds(module, 10.0), 18.75), "qte output bonus")
	var controller := CONTROLLER.new()
	controller.battle = Node2D.new()
	add_child(controller.battle)
	add_child(controller)
	_check(controller.dispatch(module, ore), "first dwarf dispatch")
	_check(controller.dispatch(module, ore), "second dwarf dispatch")
	_check(not controller.dispatch(module, ore), "third dwarf rejected")
	var first: Node2D = controller.workers.get(module)
	var second: Node2D = controller.extra_workers.get(module)
	_check(first != second and first != null and second != null, "workers independent")
	controller._worker_returned(first, module)
	_check(controller.extra_workers.get(module) == second, "returning one preserves other")
	_check(ResearchManager.get_tree_node_state(&"mining_worker") == &"COMPLETED", "research progress exposed")
	if failures.is_empty():
		print("MINING_RESEARCH_TREE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("MINING_RESEARCH_TREE_TEST: " + failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
