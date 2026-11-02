extends Node

const TestSave := preload("res://Tests/TestSave.gd")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("ship_expansion")
	_check(ResearchManager.configuration.get_validation_errors().is_empty(), "new ship tree validates")
	_check(ResearchManager.get_ship_hull_slot_capacity() == 0, "new save has no expansion permission")
	_check(ResearchManager.get_upgrade_cost(&"ship_hull_slot_1") == 2000, "first expansion costs 2000 Ore")
	_check(ResearchManager.get_upgrade_cost(&"ship_hull_slot_2") == 3500, "second expansion costs 3500 Ore")
	_check(not ShipLoadout.add_expansion_cell(0), "cannot expand before research")
	ResearchManager.progress.levels["ship_manual_turret_control"] = 1
	WeaponUnlockManager.completed_planet_ids["goblin_planet"] = true
	_check(ResearchManager.get_tree_node_state(&"ship_hull_slot_1") == &"LOCKED", "first slot also needs Expandable Cells")
	ResearchManager.progress.levels["energy_slot_support_1"] = 1
	_check(ResearchManager.get_tree_node_state(&"ship_hull_slot_1") == &"AVAILABLE", "first slot can unlock after Verdant and both researches")
	ResearchManager.progress.levels["ship_hull_slot_1"] = 1
	_check(ShipLoadout.add_expansion_cell(0), "north ring slot can be chosen")
	_check(not ShipLoadout.add_expansion_cell(0), "same slot cannot be added twice")
	_check(not ShipLoadout.add_expansion_cell(1), "first research permits exactly one slot")
	_check(not ShipLoadout.add_expansion_cell(-1), "outer corner cannot be chosen")
	var ship := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	ship.assembly_mode = true
	add_child(ship)
	_check(ship.get_hull_cells().size() == 10, "hull has ten cells after first expansion")
	var north_edge := ship.get_nearest_hull_boundary_world(ship.to_global(Vector2(96, -90)))
	_check(is_equal_approx(ship.to_local(north_edge).y, -Ship.CELL_SIZE), "enemy targets the new outer hull edge")
	_check(ship.get_cell_at_global(ship.to_global(ship.get_cell_center(3, 0))) == Vector2i(3, 0), "outer slot is selectable")
	var gun := load("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn") as PackedScene
	_check(ship.install_module(gun, Ship.ModuleType.Weapon, 3, 0), "expanded slot accepts a weapon")
	_check(ship.get_module_at(3, 0) != null, "expanded module exists on the ship")
	_check(ResearchManager.get_tree_node_state(&"ship_hull_slot_2") == &"LOCKED", "second slot needs Graveyard clear")
	WeaponUnlockManager.completed_planet_ids["graveyard_planet"] = true
	_check(ResearchManager.get_tree_node_state(&"ship_hull_slot_2") == &"AVAILABLE", "second slot can unlock after Graveyard")
	ResearchManager.progress.levels["ship_hull_slot_2"] = 1
	_check(ShipLoadout.add_expansion_cell(11), "second research permits another position")
	_check(not ShipLoadout.add_expansion_cell(10), "third expansion is rejected")
	_check(ship.get_hull_cells().size() == 11, "live hull rebuilds on second expansion")
	ShipLoadout.save()
	# Reparse the JSON file rather than merely reading ProgressionStore's
	# in-memory Dictionary (which still contains integer array elements).
	ProgressionStore.reload_from_disk()
	ResearchManager.reload_progress()
	ShipLoadout.load_saved()
	_check(ShipLoadout.is_valid_cell(3, 0) and ShipLoadout.is_valid_cell(3, 11), "expanded cells survive save reload")
	_check(ShipLoadout.has_module(3, 0), "expanded module survives save reload")
	ship.queue_free()
	await get_tree().process_frame
	var restored := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	restored.assembly_mode = true
	add_child(restored)
	_check(restored.get_module_at(3, 0) != null, "battle/base ship restores expanded weapon")
	restored.queue_free()
	if failures.is_empty():
		print("SHIP_EXPANSION_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SHIP_EXPANSION_TEST: " + failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
