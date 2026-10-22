extends Node

## Drag-and-drop installs and loadout persistence across sessions.

const BASE_SCENE: PackedScene = preload("res://Scenes/Base/base_main.tscn")
const TEST_SAVE_PATH: String = "user://greedminer_loadout_test.json"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	ProgressionStore.set_save_path_for_testing(TEST_SAVE_PATH)
	ProgressionStore.set_section(&"weapon_unlocks", {
		"unlocked_weapons": {"machine_gun": true, "laser": true},
		"completed_planets": {},
	})
	WeaponUnlockManager.reload_progress()
	ShipLoadout.installed_modules.clear()

	var base := BASE_SCENE.instantiate()
	add_child(base)
	await get_tree().process_frame
	base._enter_assembly()
	await get_tree().create_timer(0.8).timeout

	var laser_id := &"laser"
	_expect_true(ModuleCatalog.get_scene(laser_id) != null, "laser is in the catalog")
	_expect_true(base.drop_module_on_cell(laser_id, Vector2i(0, 2)), "dropping the laser on slot (0,2) installs it")
	_expect_equal(ShipLoadout.get_module(0, 2), ModuleCatalog.get_scene(laser_id).resource_path, "loadout records the dropped module")
	_expect_equal(base._selected_row, 0, "drop selects the slot row")
	_expect_equal(base._selected_column, 2, "drop selects the slot column")
	_expect_equal(base.loadout_panel._view, LoadoutPanel.View.LIST, "panel stays on the module list after a drop")
	_expect_false(base.drop_module_on_cell(laser_id, Vector2i(5, 5)), "dropping outside the grid does nothing")

	# The save survives a "restart": reload from disk into an empty loadout.
	var saved := ShipLoadout.installed_modules.duplicate()
	ShipLoadout.installed_modules.clear()
	ProgressionStore.reload_from_disk()
	ShipLoadout.load_saved()
	_expect_equal(ShipLoadout.installed_modules, saved, "saved loadout is restored after reload")

	# The hull color scheme is saved with the loadout.
	ShipLoadout.set_style(&"deep_space")
	ShipLoadout.save()
	ShipLoadout.style_id = &"bone_iron"
	ProgressionStore.reload_from_disk()
	ShipLoadout.load_saved()
	_expect_equal(ShipLoadout.style_id, &"deep_space", "ship style is restored after reload")
	ShipLoadout.set_style(&"not_a_style")
	_expect_equal(ShipLoadout.style_id, &"deep_space", "unknown styles are ignored")
	ShipLoadout.set_style(&"bone_iron")

	# The hull design is saved with the loadout and rebuilds the ship outline.
	ShipLoadout.set_hull(&"citadel")
	ShipLoadout.save()
	_expect_equal(base.ship._hull_geometry.get("hull"), &"citadel", "ship rebuilds with the new hull design")
	ShipLoadout.hull_id = &"classic"
	ProgressionStore.reload_from_disk()
	ShipLoadout.load_saved()
	_expect_equal(ShipLoadout.hull_id, &"citadel", "hull design is restored after reload")
	ShipLoadout.set_hull(&"not_a_hull")
	_expect_equal(ShipLoadout.hull_id, &"citadel", "unknown hull designs are ignored")
	ShipLoadout.set_hull(&"classic")
	ShipLoadout.save()

	# The thruster style is saved too, and every style draws and has nozzles.
	_expect_equal(ShipLoadout.thruster_id, &"pod", "round pods are the default thrusters")
	for thruster_id in ShipHullVisual.THRUSTER_ORDER:
		ShipLoadout.set_thruster(thruster_id)
		base.ship.thruster_deploy = 1.0
		base.ship.thruster_power = 1.0
		_expect_true(base.ship.get_thruster_ground_positions().size() > 0, "%s has nozzles for the exhaust" % thruster_id)
	base.ship.thruster_power = 0.0
	base.ship.thruster_deploy = 0.0
	ShipLoadout.set_thruster(&"ring")
	ShipLoadout.save()
	ShipLoadout.thruster_id = &"pod"
	ProgressionStore.reload_from_disk()
	ShipLoadout.load_saved()
	_expect_equal(ShipLoadout.thruster_id, &"ring", "thruster style is restored after reload")
	ShipLoadout.set_thruster(&"jetpack")
	_expect_equal(ShipLoadout.thruster_id, &"ring", "unknown thruster styles are ignored")
	ShipLoadout.set_thruster(&"pod")
	ShipLoadout.save()

	# Removing through the panel flow is saved too.
	base.ship.select_cell(0, 2)
	base._on_remove_requested()
	ShipLoadout.installed_modules.clear()
	ProgressionStore.reload_from_disk()
	ShipLoadout.load_saved()
	_expect_false(ShipLoadout.has_module(0, 2), "removal is saved")

	base.queue_free()
	ShipLoadout.installed_modules.clear()
	# Keep the isolated path active until this test process exits. Switching back
	# can overwrite the player's real progression during shutdown or reloads.
	WeaponUnlockManager.reload_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

	if _failures.is_empty():
		print("LOADOUT_PERSISTENCE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("LOADOUT_PERSISTENCE_TEST: " + failure)
		print("LOADOUT_PERSISTENCE_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	_expect_true(not value, description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
