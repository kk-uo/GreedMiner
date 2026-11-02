extends Node

const TestSave := preload("res://Tests/TestSave.gd")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("energy_tree_v2")
	_check(ResearchManager.configuration.get_validation_errors().is_empty(), "energy tree configuration validates")
	_check(ResearchManager.get_module_installation_limit(&"energy_module") == 1, "first battery is the initial limit")
	_check(not ResearchManager.is_planet_in_range(&"tree_planet"), "Tree Planet starts out of range")
	_check(not WeaponFusionRegistry.is_unlocked(), "fusion starts locked")
	_check(ResearchManager.purchase_research(&"energy_install_slot_unlock"), "second battery is free")
	_check(ResearchManager.get_module_installation_limit(&"energy_module") == 2, "second battery limit applies")
	_check(ResearchManager.get_tree_node_state(&"energy_core_half") == &"LOCKED", "half-power node needs both upper branches")
	ResourceManager.add_stored_ore(2750)
	for id in [&"energy_core_1", &"energy_range_1", &"energy_range_2", &"energy_slot_support_1"]:
		_check(ResearchManager.purchase_research(id), "%s can be researched" % id)
	_check(ResearchManager.get_tree_node_state(&"energy_core_half") == &"LOCKED", "shielded cells still required")
	_check(ResearchManager.purchase_research(&"energy_shielded_cells_1"), "shielded cells can be researched")
	_check(ResourceManager.stored_ore == 0, "existing branch costs are unchanged")
	_check(ResearchManager.get_tree_node_state(&"energy_core_half") == &"AVAILABLE", "half-power node unlocks after both branches")
	var battery := load("res://Scenes/Modules/Energy/energy_module.tscn").instantiate() as EnergyModule
	_check(is_equal_approx(battery.get_power_capacity(), 5.0), "first core gives 5 Power")
	ResourceManager.add_stored_ore(2500)
	_check(ResearchManager.purchase_research(&"energy_core_half"), "half-power upgrade costs 2500 Ore")
	_check(is_equal_approx(battery.get_power_capacity(), 5.5), "one battery supplies exactly 5.5 Power")
	_check(is_equal_approx(float(ModuleCatalog.get_stats(&"energy_module").get("power_capacity", 0.0)), 5.5), "catalog retains half Power")
	var batteries: Array[ShipModule] = [battery, battery.duplicate() as EnergyModule]
	var profile := ShipEnergySystem.new().calculate_profile(batteries)
	_check(is_equal_approx(float(profile.total_power_capacity), 11.0), "two batteries supply 11 Power")
	_check(not ShipEnergySystem.is_profile_operational({"energy_module_count": 1, "total_power_consumption": 6, "total_power_capacity": 5.5}), "half Power cannot pay a full six-Power load")
	_check(ResearchManager.get_tree_node_state(&"energy_fusion_unlock") == &"LOCKED", "Fusion Energy needs Graveyard clear and Level 30 weapons")
	_check(not ResearchManager.purchase_research(&"energy_fusion_unlock"), "Fusion Energy cannot be bought early")
	WeaponUnlockManager.completed_planet_ids["graveyard_planet"] = true
	_check(ResearchManager.get_tree_node_state(&"energy_fusion_unlock") == &"LOCKED", "Graveyard alone is insufficient")
	for weapon_id in WeaponFusionRegistry.BASE_WEAPONS:
		var definition := ResearchManager.get_weapon_research_definition(weapon_id)
		if definition != null:
			ResearchManager.progress.levels[String(definition.research_id)] = 30
	_check(ResearchManager.get_tree_node_state(&"energy_fusion_unlock") == &"AVAILABLE", "all original fusion prerequisites are preserved")
	ResourceManager.add_stored_ore(5000)
	_check(ResearchManager.purchase_research(&"energy_fusion_unlock"), "Fusion Energy costs 5000 Ore")
	_check(WeaponFusionRegistry.is_unlocked(), "completed fusion research enables recipes")
	_check(ResearchManager.get_module_installation_limit(&"energy_module") == 2, "third battery not granted by fusion alone")
	ResourceManager.add_stored_ore(4000)
	_check(ResearchManager.purchase_research(&"energy_install_slot_3"), "third battery costs 2500 Ore")
	_check(ResearchManager.get_module_installation_limit(&"energy_module") == 3, "third battery limit applies")
	var ship := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	ship.assembly_mode = true
	add_child(ship)
	var battery_scene := load("res://Scenes/Modules/Energy/energy_module.tscn") as PackedScene
	_check(ship.install_module(battery_scene, Ship.ModuleType.Energy, 0, 0), "second battery installs")
	_check(ship.install_module(battery_scene, Ship.ModuleType.Energy, 0, 1), "third battery installs")
	_check(is_equal_approx(ship.total_power_capacity, 16.5), "three installed batteries supply 16.5 Power")
	_check(not ship.install_module(battery_scene, Ship.ModuleType.Energy, 0, 2), "fourth battery remains forbidden")
	_check(not ResearchManager.is_planet_in_range(&"tree_planet"), "Tree Planet still needs Super-Range Cells")
	WeaponUnlockManager.located_planet_ids["tree_planet"] = true
	_check(ResearchManager.is_planet_in_range(&"tree_planet"), "previously located Tree Planet stays reachable on an old save")
	WeaponUnlockManager.located_planet_ids.erase("tree_planet")
	WeaponUnlockManager.completed_planet_ids["tree_planet"] = true
	_check(ResearchManager.is_planet_in_range(&"tree_planet"), "previously cleared Tree Planet stays reachable on an old save")
	WeaponUnlockManager.completed_planet_ids.erase("tree_planet")
	_check(not ResearchManager.is_planet_in_range(&"tree_planet"), "uncleared Tree Planet remains gated")
	_check(ResearchManager.purchase_research(&"energy_range_3"), "Super-Range Cells cost 1500 Ore")
	_check(ResearchManager.is_planet_in_range(&"tree_planet"), "Tree Planet becomes reachable")
	_check(ResourceManager.stored_ore == 0, "late branch costs total 4000 Ore")
	ResearchManager.reload_progress()
	_check(ResearchManager.is_research_completed(&"energy_core_half"), "half-power research persists")
	_check(ResearchManager.get_module_installation_limit(&"energy_module") == 3, "third battery permission persists")
	_check(ResearchManager.is_planet_in_range(&"tree_planet"), "Tree Planet range persists")
	for module in batteries:
		module.free()
	ship.queue_free()
	if failures.is_empty():
		print("ENERGY_TREE_V2_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("ENERGY_TREE_V2_TEST: " + failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
