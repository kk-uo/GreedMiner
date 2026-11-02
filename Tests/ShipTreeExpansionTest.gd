extends Node

const TestSave := preload("res://Tests/TestSave.gd")
const SHIP_SCENE := preload("res://Scenes/Ship/ship.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("ship_tree_expansion")
	check(ResearchManager.configuration.get_validation_errors().is_empty(), "research trees validate")
	check(not ResearchManager.is_planet_in_range(&"dragon_nest_planet"), "Dragon Nest initially requires Gold Detector")
	check(not ArtifactManager.is_ship_slot_unlocked(1), "second magic slot begins locked")
	check(ResearchManager.get_tree_node_state(&"ship_gold_detector") == &"LOCKED", "Gold Detector waits for Spirit Detector")
	check(ResearchManager.get_tree_node_state(&"ship_magic_slot_2") == &"LOCKED", "second magic slot waits for hull expansion")
	check(ResearchManager.get_tree_node_state(&"ship_max_hp_5") == &"LOCKED", "+20 HP waits for both branches")
	ResourceManager.add_stored_ore(30000)
	for id in [&"ship_max_hp_1", &"ship_auto_regeneration_1", &"ship_air_conditioning_1", &"ship_max_hp_2", &"ship_max_hp_3", &"ship_max_hp_4", &"ship_spirit_detector"]:
		check(ResearchManager.purchase_research(id), "ship HP branch buys %s" % id)
	check(ResearchManager.get_tree_node_state(&"ship_gold_detector") == &"AVAILABLE", "Gold Detector available after Spirit Detector")
	check(ResearchManager.get_tree_node_state(&"ship_spirit_power_half") == &"AVAILABLE", "half-power research available after Spirit Detector")
	check(ResearchManager.get_upgrade_cost(&"ship_spirit_power_half") == 1500, "half-power research costs 1500 Ore")
	var ore_before_purchase := ResourceManager.stored_ore
	check(ResearchManager.purchase_research(&"ship_spirit_power_half"), "half-power research purchases")
	check(ResourceManager.stored_ore == ore_before_purchase - 1500.0, "half-power research spends exactly 1500 Ore")
	check(is_equal_approx(ResearchManager.get_ship_base_power_bonus(), 0.5), "ship power adds half point")
	var profile := ShipEnergySystem.new().calculate_profile([])
	check(is_equal_approx(float(profile.total_power_capacity), 0.5), "energy profile accepts fractional built-in power")
	check(ResearchManager.get_upgrade_cost(&"ship_gold_detector") == 2000, "Gold Detector costs 2000 Ore")
	check(ResearchManager.purchase_research(&"ship_gold_detector"), "Gold Detector purchases")
	check(ResearchManager.is_planet_in_range(&"dragon_nest_planet"), "Gold Detector unlocks Dragon Nest range")
	check(ResearchManager.get_tree_node_state(&"ship_max_hp_5") == &"LOCKED", "Gold Detector alone cannot buy +20 HP")
	for id in [&"ship_magic_slot_1", &"ship_power_1", &"ship_style_unlock", &"ship_manual_turret_control", &"energy_install_slot_unlock", &"energy_core_1", &"energy_slot_support_1"]:
		check(ResearchManager.purchase_research(id), "expansion preparation buys %s" % id)
	WeaponUnlockManager.completed_planet_ids["goblin_planet"] = true
	check(ResearchManager.purchase_research(&"ship_hull_slot_1"), "first hull expansion purchases")
	WeaponUnlockManager.completed_planet_ids["graveyard_planet"] = true
	check(ResearchManager.purchase_research(&"ship_hull_slot_2"), "second hull expansion purchases")
	check(ResearchManager.get_tree_node_state(&"ship_magic_slot_2") == &"AVAILABLE", "second magic slot follows hull expansion")
	check(ResearchManager.get_upgrade_cost(&"ship_magic_slot_2") == 5000, "second magic slot costs 5000 Ore")
	check(ResearchManager.purchase_research(&"ship_magic_slot_2"), "second magic slot purchases")
	check(ArtifactManager.is_ship_slot_unlocked(1) and not ArtifactManager.is_ship_slot_unlocked(2), "only second ship magic slot unlocks")
	check(ResearchManager.get_tree_node_state(&"ship_max_hp_5") == &"AVAILABLE", "+20 HP now has both prerequisites")
	check(ResearchManager.get_upgrade_cost(&"ship_max_hp_5") == 2500, "+20 HP costs 2500 Ore")
	var ship := SHIP_SCENE.instantiate() as Ship
	ship.assembly_mode = true
	add_child(ship)
	var hp_before := ship.max_hp
	check(ResearchManager.purchase_research(&"ship_max_hp_5"), "+20 HP purchases")
	check(is_equal_approx(ship.max_hp, hp_before + 20.0), "+20 HP updates live ship")
	ProgressionStore.reload_from_disk()
	ResearchManager.reload_progress()
	check(ResearchManager.is_research_completed(&"ship_gold_detector") and ResearchManager.is_research_completed(&"ship_magic_slot_2"), "new research persists")
	check(is_equal_approx(ResearchManager.get_ship_base_power_bonus(), 1.5), "half and whole built-in power survive reload")
	check(ArtifactManager.is_ship_slot_unlocked(1), "second magic slot survives reload")
	check(ResearchManager.get_tree_node_state(&"ship_max_hp_5") == &"COMPLETED", "+20 HP survives reload")
	ship.queue_free()
	if failures.is_empty():
		print("SHIP_TREE_EXPANSION_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SHIP_TREE_EXPANSION_TEST: " + failure)
		print("SHIP_TREE_EXPANSION_TEST: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
