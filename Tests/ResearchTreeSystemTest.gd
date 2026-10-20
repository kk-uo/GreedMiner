extends Node

const TEST_SAVE := "user://research_tree_system_test.json"
const SHIP_SCENE := preload("res://Scenes/Ship/ship.tscn")
const KNOCKBACK_SCENE := preload("res://Scenes/Modules/Shield/knockback_module.tscn")
const REGENERATION_SCENE := preload("res://Scenes/Modules/Shield/regeneration_module.tscn")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	ProgressionStore.set_save_path_for_testing(TEST_SAVE)
	ProgressionStore.reset_all_progress()
	ShipLoadout.load_saved()
	ResourceManager.reload_persistent_resources()
	ResearchManager.reload_progress()
	ArtifactManager.reload_progress()
	_check(ResearchManager.configuration.get_validation_errors().is_empty(), "valid default trees")
	for id in [&"energy", &"mining", &"ship"]:
		var tree := ResearchManager.configuration.get_tree(id)
		_check(tree != null, "%s tree loads" % id)
		if tree != null:
			var view := ResearchTreeView.new()
			add_child(view)
			view.setup(tree)
			_check(view._nodes.size() == tree.nodes.size(), "%s tree displays configured nodes" % id)
			view.queue_free()
	_check(ResearchManager.get_tree_node_state(&"ship_auto_regeneration_1") == &"LOCKED", "regeneration begins locked")
	_check(ResearchManager.get_tree_node_state(&"ship_magic_slot_1") == &"LOCKED", "magic begins locked")
	ResourceManager.add_stored_ore(1000)
	_check(not ResearchManager.purchase_research(&"ship_magic_slot_1"), "direct locked purchase rejected")
	_check(ResourceManager.stored_ore == 1000, "locked purchase spends nothing")
	var ship := SHIP_SCENE.instantiate() as Ship
	ship.assembly_mode = true
	add_child(ship)
	await get_tree().process_frame
	var original_max := ship.max_hp
	var original_hp := ship.current_hp
	_check(original_max == 50.0 and original_hp == 50.0, "new ship starts with 50 HP")
	_check(ResearchManager.purchase_research(&"ship_max_hp_1"), "root purchased")
	_check(ship.max_hp == original_max + 50 and ship.current_hp == original_hp, "HP bonus applies once without healing")
	WeaponUnlockManager.unlocked_weapon_ids["knockback_module"] = true
	WeaponUnlockManager.unlocked_weapon_ids["regeneration_module"] = true
	_check(ship.install_module(KNOCKBACK_SCENE, Ship.ModuleType.Shield, 0, 0), "Knockback can be installed")
	_check(ship.install_module(REGENERATION_SCENE, Ship.ModuleType.Shield, 0, 1), "Regeneration can be installed")
	_check(ship.max_hp == original_max + 150 and ship.current_hp == original_hp, "shield and research HP bonuses stack without healing")
	_check(ResearchManager.get_tree_node_state(&"ship_magic_slot_1") == &"AVAILABLE", "magic branch available")
	_check(ResearchManager.get_tree_node_state(&"ship_auto_regeneration_1") == &"AVAILABLE", "regeneration branch available")
	_check(not ResearchManager.purchase_research(&"ship_max_hp_1"), "duplicate purchase rejected")
	_check(ResourceManager.stored_ore == 900, "root costs exactly 100")
	_check(not ArtifactManager.is_ship_slot_unlocked(0), "magic slot initially locked")
	_check(ResearchManager.purchase_research(&"ship_magic_slot_1"), "magic branch purchased independently")
	_check(ArtifactManager.is_ship_slot_unlocked(0) and not ArtifactManager.is_ship_slot_unlocked(1), "only first magic slot unlocks")
	_check(ResearchManager.purchase_research(&"ship_auto_regeneration_1"), "regeneration branch purchased")
	_check(not ResearchManager.purchase_research(&"mining_install_slot_unlock"), "insufficient ore blocks expansion")
	_check(ResourceManager.stored_ore == 300, "failed purchase leaves ore unchanged")
	_check(ResearchManager.get_tree_node_state(&"energy_core_1") == &"LOCKED", "Energy Core waits for the extra battery")
	_check(ResearchManager.get_tree_node_state(&"energy_range_1") == &"LOCKED", "Long-Range Cells wait for the extra battery")
	_check(ResearchManager.purchase_research(&"energy_install_slot_unlock"), "energy root purchased")
	_check(ResourceManager.stored_ore == 0, "extra battery costs exactly 300")
	_check(ResearchManager.get_tree_node_state(&"energy_core_1") == &"AVAILABLE", "Energy Core opens after the extra battery")
	_check(ResearchManager.get_tree_node_state(&"energy_range_1") == &"AVAILABLE", "Long-Range Cells open after the extra battery")
	_check(not ResearchManager.is_planet_in_range(&"goblin_planet"), "Verdant is out of range before Long-Range Cells")
	ResourceManager.add_stored_ore(250)
	_check(ResearchManager.purchase_research(&"energy_range_1"), "Long-Range Cells purchased")
	_check(ResearchManager.is_planet_in_range(&"goblin_planet"), "Verdant comes into range")
	_check(not ResearchManager.is_planet_in_range(&"frozen_planet"), "Frozen still needs Air Conditioning")
	_check(ResearchManager.get_planet_access_research(&"frozen_planet") == &"ship_air_conditioning_1", "Air Conditioning is the missing Frozen research")
	_check(not ResearchManager.is_planet_in_range(&"volcanic_planet"), "Volcanic needs Air Conditioning")
	_check(ResearchManager.is_planet_in_range(&"rocky_planet"), "Rocky never needs range research")
	ResourceManager.add_stored_ore(500)
	_check(ResearchManager.purchase_research(&"mining_install_slot_unlock"), "mining root purchased")
	_check(ResourceManager.stored_ore == 0, "mining expansion costs exactly 500")
	# Ship branches: Air Conditioning after regeneration; power cell and
	# ship style after the magic slot.
	_check(ResearchManager.get_tree_node_state(&"ship_air_conditioning_1") == &"AVAILABLE", "Air Conditioning follows regeneration")
	_check(ResearchManager.get_tree_node_state(&"ship_power_1") == &"AVAILABLE", "power cell follows the magic slot")
	_check(ResearchManager.get_tree_node_state(&"ship_style_unlock") == &"AVAILABLE", "ship style follows the magic slot")
	_check(not ResearchManager.is_ship_style_unlocked(), "ship style starts locked")
	var capacity_before := ship.total_power_capacity
	ResourceManager.add_stored_ore(950)
	_check(ResearchManager.purchase_research(&"ship_air_conditioning_1"), "Air Conditioning purchased")
	_check(ResearchManager.is_planet_in_range(&"frozen_planet") and ResearchManager.is_planet_in_range(&"volcanic_planet"), "Frozen and Volcanic come into range")
	_check(ResearchManager.purchase_research(&"ship_power_1"), "power cell purchased")
	_check(ship.total_power_capacity == capacity_before + 1, "power cell adds one ship power")
	_check(ResearchManager.purchase_research(&"ship_style_unlock"), "ship style purchased")
	_check(ResearchManager.is_ship_style_unlocked(), "ship style unlocked")
	_check(ResourceManager.stored_ore == 0, "ship branches cost 250 + 200 + 500")
	_check(ResearchManager.get_module_installation_limit(&"energy_module") == 2, "energy limit becomes two")
	_check(ResearchManager.get_module_installation_limit(&"mining_module") == 2, "mining limit becomes two")
	_check(not ResearchManager.purchase_research(&"mining_install_slot_unlock"), "completed expansion cannot be repurchased")
	ship.assembly_mode = false
	ship.take_damage(20.0)
	var damaged := ship.current_hp
	ship._process(9.9)
	_check(ship.current_hp == damaged, "no early regeneration")
	ship._process(0.2)
	_check(ship.current_hp == damaged + 5.0, "five HP after ten seconds")
	var regeneration := ship.get_module_at(0, 1) as RegenerationModule
	regeneration.set_module_active(true)
	regeneration.apply_healing_pulse()
	_check(ship.current_hp == damaged + 6.0, "area healing coexists with passive ship regeneration")
	ship.heal(10000.0)
	_check(ship.current_hp == ship.max_hp, "healing capped at maximum")
	ship.set_all_modules_active(false)
	ship.take_damage(10)
	var paused_hp := ship.current_hp
	ship._process(20)
	_check(ship.current_hp == paused_hp, "battle-end pause stops regeneration")
	ProgressionStore.reload_from_disk()
	ResearchManager.reload_progress()
	_check(ResearchManager.is_research_completed(&"ship_max_hp_1") and ResearchManager.is_research_completed(&"ship_magic_slot_1"), "research persists")
	_check(ResearchManager.get_tree_node_state(&"energy_install_slot_unlock") == &"COMPLETED", "saved energy expansion displays completed")
	_check(ResearchManager.get_tree_node_state(&"mining_install_slot_unlock") == &"COMPLETED", "saved mining expansion displays completed")
	ship._recalculate_health_stats()
	_check(ship.max_hp == original_max + 150, "reload does not duplicate HP bonus")
	_check(ship.remove_module(0, 1), "Regeneration module can be removed")
	ship.set_all_modules_active(true)
	ship.take_damage(10)
	var without_module := ship.current_hp
	ship._process(10.0)
	_check(ship.current_hp == without_module + 5.0, "ship regeneration works without a Regeneration Module")
	var config := ResearchManager.configuration.duplicate(true) as ResearchConfiguration
	var tree := config.get_tree(&"ship")
	var root := tree.get_node(&"ship_max_hp_1")
	root.prerequisite_ids = [&"missing_id"]
	_check(not config.get_validation_errors().is_empty(), "missing prerequisite rejected")
	root.prerequisite_ids = [&"ship_magic_slot_1"]
	_check(not config.get_validation_errors().is_empty(), "cycle rejected")
	root.prerequisite_ids = []
	var extra := ResearchTreeNode.new()
	extra.research_id = &"energy_test_extension"
	extra.tree_category = &"energy"
	extra.display_name = "Test expansion"
	extra.prerequisite_ids = [&"energy_install_slot_unlock"]
	var extra_definition := ResearchDefinition.new()
	extra_definition.research_id = extra.research_id
	extra_definition.category_id = &"energy"
	extra_definition.starting_level = 0
	extra_definition.max_level = 1
	extra_definition.implemented = true
	extra_definition.cost_configuration = ResearchCostConfig.new()
	extra_definition.cost_configuration.base_upgrade_cost = 17
	extra_definition.effect = ModuleInstallationLimitResearchEffect.new()
	extra.definition = extra_definition
	config.get_tree(&"energy").nodes.append(extra)
	_check(config.get_validation_errors().is_empty(), "Inspector-defined descendant validates")
	var original_configuration := ResearchManager.configuration
	ResearchManager.configuration = config
	ResourceManager.add_stored_ore(17)
	_check(ResearchManager.purchase_research(extra.research_id), "new definition attached to tree can be purchased")
	_check(ResourceManager.stored_ore == 0, "new node uses its configured cost")
	ResearchManager.configuration = original_configuration
	ship.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("RESEARCH_TREE_SYSTEM_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("RESEARCH_TREE_SYSTEM_TEST: " + failure)
		get_tree().quit(1)


func _check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
