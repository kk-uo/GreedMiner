extends Node

const TestSave := preload("res://Tests/TestSave.gd")
const RESEARCH_ID := &"weapon_damage.flamethrower"
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _run() -> void:
	TestSave.isolate("flamethrower_research")
	var definition := ResearchManager.get_weapon_research_definition(&"flamethrower")
	check(definition != null, "flamethrower research exists")
	if definition == null:
		get_tree().quit(1)
		return
	check(ResearchManager.get_definitions_for_category(&"weapon").size() == 5, "five weapon research projects")
	check(definition.max_level == 30, "maximum level is 30")
	check(not ResearchManager.is_unlocked(RESEARCH_ID), "research locked before weapon unlock")
	ResourceManager.add_stored_ore(1000.0)
	var panel := LaboratoryPanel.new()
	add_child(panel)
	panel._select_category(&"weapon")
	var card: Variant = panel._cards.get(RESEARCH_ID)
	check(card != null and card.button.disabled, "laboratory displays locked flamethrower research")
	check(not ResearchManager.purchase_research(RESEARCH_ID), "locked research cannot be purchased")
	check(is_equal_approx(ResourceManager.stored_ore, 1000.0), "locked purchase spends no ore")
	WeaponUnlockManager.record_planet_completion(&"volcanic_planet")
	check(ResearchManager.is_unlocked(RESEARCH_ID), "volcanic completion unlocks research")
	panel._refresh_category()
	card = panel._cards.get(RESEARCH_ID)
	check(card != null and not card.button.disabled, "laboratory enables unlocked flamethrower research")
	var weapon := load("res://Scenes/Modules/Weapons/Flamethrower/flamethrower.tscn").instantiate() as Flamethrower
	var base_damage := weapon.basic_damage
	check(is_equal_approx(weapon.get_damage(), base_damage), "level one damage")
	check(ResearchManager.get_upgrade_cost(RESEARCH_ID) == 200, "first upgrade costs 200")
	check(ResearchManager.purchase_research(RESEARCH_ID), "research upgrade succeeds")
	check(is_equal_approx(weapon.get_damage(), base_damage * 1.2), "upgrade increases weapon damage 20 percent")
	check(is_equal_approx(ResourceManager.stored_ore, 800.0), "upgrade spends 200 ore")
	check(ResearchManager.get_upgrade_cost(RESEARCH_ID) == 400, "second upgrade costs 400")
	ResearchManager.reload_progress()
	check(ResearchManager.get_level(RESEARCH_ID) == 2, "research level persists")
	var cell := Vector2i(0, 0)
	ShipLoadout.install_module(cell.x, cell.y, "res://Scenes/Modules/Weapons/Flamethrower/flamethrower.tscn")
	check(ChipManager.configuration.get_weapon_slot(&"flamethrower") != null, "flamethrower chip slot registered")
	for pair in [[5, 0], [10, 1], [20, 2], [30, 3]]:
		ResearchManager.progress.levels[String(RESEARCH_ID)] = pair[0]
		check(ResearchManager.get_weapon_chip_slot_count(&"flamethrower") == pair[1], "chip slots at level %d" % pair[0])
		check(ChipManager.get_module_slot_count(cell) == pair[1], "installed flamethrower sockets at level %d" % pair[0])
	ResearchManager.progress.levels[String(RESEARCH_ID)] = 10
	ResourceManager.add_stored_ore(500.0)
	var chip := ChipManager.craft_chip(&"damage_chip")
	check(not chip.is_empty(), "damage chip crafted")
	check(ChipManager.equip_module_chip(cell, 0, chip), "damage chip equipped in flamethrower")
	check(ChipManager.get_module_chip(cell, 0) == chip, "installed chip is assigned to the module")
	check(ChipManager.get_stat_modifiers({"stat_id": &"damage", "cell": cell}).size() > 0, "equipped chip supplies damage modifier")
	ChipManager.reload_progress()
	check(ChipManager.get_module_chip(cell, 0) == chip, "equipped chip persists")
	ResearchManager.progress.levels[String(RESEARCH_ID)] = 30
	check(is_equal_approx(weapon.get_damage(), base_damage * 6.8), "level 30 damage")
	check(ResearchManager.get_upgrade_cost(RESEARCH_ID) == 0, "maximum level has no upgrade cost")
	weapon.free()
	panel.queue_free()
	if failures.is_empty():
		print("FLAMETHROWER_RESEARCH_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("FLAMETHROWER_RESEARCH_TEST: " + failure)
		get_tree().quit(1)
