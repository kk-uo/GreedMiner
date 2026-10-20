extends Node

## Integration coverage for the one-time Energy and Mining installation unlocks.

const TEST_SAVE_PATH: String = "user://greedminer_module_slot_unlock_test.json"
const SHIP_SCENE: PackedScene = preload("res://Scenes/Ship/ship.tscn")
const ENERGY_SCENE: PackedScene = preload("res://Scenes/Modules/Energy/energy_module.tscn")
const MINING_SCENE: PackedScene = preload("res://Scenes/Modules/Mining/mining_module.tscn")

var _failures: Array[String] = []
var _original_configuration: ResearchConfiguration


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_original_configuration = ResearchManager.configuration
	_remove_test_save()
	ProgressionStore.set_save_path_for_testing(TEST_SAVE_PATH)
	ResourceManager.reload_persistent_resources()
	ResearchManager.reload_progress()
	ShipLoadout.installed_modules.clear()

	await _test_locked_limits_and_legacy_loadout()
	await _test_purchases_limits_removal_and_persistence()
	_test_inspector_cost_and_repeatable_save_migration()
	_cleanup()

	if _failures.is_empty():
		print("MODULE_SLOT_UNLOCK_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("MODULE_SLOT_UNLOCK_TEST: " + failure)
		print("MODULE_SLOT_UNLOCK_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _test_locked_limits_and_legacy_loadout() -> void:
	_expect_equal(ResearchManager.get_level(&"energy_install_slot_unlock"), 0, "new save Energy unlock starts locked")
	_expect_equal(ResearchManager.get_level(&"mining_install_slot_unlock"), 0, "new save Mining unlock starts locked")
	_expect_equal(ResearchManager.get_module_installation_limit(&"energy_module"), 1, "locked Energy limit is one")
	_expect_equal(ResearchManager.get_module_installation_limit(&"mining_module"), 1, "locked Mining limit is one")

	var ship := SHIP_SCENE.instantiate() as Ship
	ship.assembly_mode = true
	add_child(ship)
	await get_tree().process_frame
	_expect_equal(ship.get_installed_module_count(&"energy_module"), 1, "new ship starts with exactly one Energy Module")
	_expect_false(ship.install_module(ENERGY_SCENE, Ship.ModuleType.Energy, 2, 2), "locked research rejects second Energy Module")
	_expect_true(ship.last_module_error.contains("installation limit"), "Energy rejection reports installation limit")
	_expect_true(ship.install_module(MINING_SCENE, Ship.ModuleType.Mining, 0, 0), "first Mining Module is allowed")
	_expect_false(ship.install_module(MINING_SCENE, Ship.ModuleType.Mining, 0, 1), "locked research rejects second Mining Module")
	ship.queue_free()
	await get_tree().process_frame

	# Compatibility: loading a pre-existing over-limit layout preserves it.
	ShipLoadout.installed_modules.clear()
	ShipLoadout.install_module(1, 1, ENERGY_SCENE.resource_path)
	ShipLoadout.install_module(2, 2, ENERGY_SCENE.resource_path)
	var legacy_ship := SHIP_SCENE.instantiate() as Ship
	legacy_ship.assembly_mode = true
	add_child(legacy_ship)
	await get_tree().process_frame
	_expect_equal(legacy_ship.get_installed_module_count(&"energy_module"), 2, "legacy over-limit Energy modules are preserved")
	_expect_false(legacy_ship.install_module(ENERGY_SCENE, Ship.ModuleType.Energy, 2, 1), "legacy over-limit loadout cannot add another Energy Module")
	legacy_ship.queue_free()
	await get_tree().process_frame
	ShipLoadout.installed_modules.clear()


func _test_purchases_limits_removal_and_persistence() -> void:
	var ship := SHIP_SCENE.instantiate() as Ship
	ship.assembly_mode = true
	add_child(ship)
	await get_tree().process_frame
	_expect_true(ship.install_module(MINING_SCENE, Ship.ModuleType.Mining, 0, 0), "first Mining Module installs before unlock")

	ResourceManager.stored_ore = 299.0
	_expect_false(ResearchManager.purchase_research(&"energy_install_slot_unlock"), "insufficient Ore rejects Energy unlock")
	_expect_equal(ResourceManager.stored_ore, 299.0, "failed Energy unlock spends no Ore")
	ResourceManager.add_stored_ore(1.0)
	_expect_equal(ResearchManager.get_upgrade_cost(&"energy_install_slot_unlock"), 300, "Energy unlock uses configured 300 Ore cost")
	_expect_true(ResearchManager.purchase_research(&"energy_install_slot_unlock"), "Energy unlock purchase succeeds")
	_expect_equal(ResourceManager.stored_ore, 0.0, "Energy unlock deducts exactly 300 Ore")
	_expect_equal(ResearchManager.get_module_installation_limit(&"energy_module"), 2, "Energy unlock raises limit to two")
	_expect_equal(ResearchManager.get_module_installation_limit(&"mining_module"), 1, "Energy unlock does not affect Mining")
	var ore_after_energy := ResourceManager.stored_ore
	_expect_false(ResearchManager.purchase_research(&"energy_install_slot_unlock"), "Energy unlock cannot be purchased twice")
	_expect_equal(ResourceManager.stored_ore, ore_after_energy, "duplicate Energy purchase spends no Ore")
	_expect_true(ship.install_module(ENERGY_SCENE, Ship.ModuleType.Energy, 2, 2), "unlocked second Energy Module installs")
	_expect_false(ship.install_module(ENERGY_SCENE, Ship.ModuleType.Energy, 2, 1), "third Energy Module is always rejected")
	_expect_false(ship.install_module(MINING_SCENE, Ship.ModuleType.Mining, 0, 1), "Mining remains independently locked")

	ResourceManager.add_stored_ore(500.0)
	_expect_equal(ResearchManager.get_upgrade_cost(&"mining_install_slot_unlock"), 500, "Mining unlock uses configured 500 Ore cost")
	_expect_true(ResearchManager.purchase_research(&"mining_install_slot_unlock"), "Mining unlock purchase succeeds")
	_expect_equal(ResourceManager.stored_ore, 0.0, "Mining unlock deducts exactly 500 Ore")
	_expect_equal(ResearchManager.get_module_installation_limit(&"mining_module"), 2, "Mining unlock raises limit to two")
	var ore_after_mining := ResourceManager.stored_ore
	_expect_false(ResearchManager.purchase_research(&"mining_install_slot_unlock"), "Mining unlock cannot be purchased twice")
	_expect_equal(ResourceManager.stored_ore, ore_after_mining, "duplicate Mining purchase spends no Ore")
	_expect_true(ship.install_module(MINING_SCENE, Ship.ModuleType.Mining, 0, 1), "unlocked second Mining Module installs")
	_expect_false(ship.install_module(MINING_SCENE, Ship.ModuleType.Mining, 0, 2), "third Mining Module is always rejected")

	_expect_true(ship.remove_module(2, 2), "second Energy Module can be removed")
	_expect_true(ship.install_module(ENERGY_SCENE, Ship.ModuleType.Energy, 2, 2), "removed Energy position can be refilled without repurchase")
	_expect_true(ship.remove_module(0, 1), "second Mining Module can be removed")
	_expect_true(ship.install_module(MINING_SCENE, Ship.ModuleType.Mining, 0, 1), "removed Mining position can be refilled without repurchase")

	ProgressionStore.reload_from_disk()
	ResearchManager.reload_progress()
	ResourceManager.reload_persistent_resources()
	_expect_equal(ResearchManager.get_level(&"energy_install_slot_unlock"), 1, "Energy unlock survives save reload")
	_expect_equal(ResearchManager.get_level(&"mining_install_slot_unlock"), 1, "Mining unlock survives save reload")
	_expect_equal(ResearchManager.get_module_installation_limit(&"energy_module"), 2, "loaded Energy permission remains two")
	_expect_equal(ResearchManager.get_module_installation_limit(&"mining_module"), 2, "loaded Mining permission remains two")

	ship.queue_free()
	await get_tree().process_frame
	ShipLoadout.installed_modules.clear()


func _test_inspector_cost_and_repeatable_save_migration() -> void:
	var custom := _original_configuration.duplicate(true) as ResearchConfiguration
	var custom_energy := custom.get_definition(&"energy_install_slot_unlock")
	custom_energy.cost_configuration.base_upgrade_cost = 375
	ResearchManager.configuration = custom
	ResearchManager.progress.levels["energy_install_slot_unlock"] = 0
	ResourceManager.stored_ore = 0.0
	ResourceManager.add_stored_ore(375.0)
	_expect_equal(ResearchManager.get_upgrade_cost(&"energy_install_slot_unlock"), 375, "Inspector cost edit changes authoritative purchase cost")
	_expect_true(ResearchManager.purchase_research(&"energy_install_slot_unlock"), "custom-cost Energy unlock purchases")
	_expect_equal(ResourceManager.stored_ore, 0.0, "custom Inspector cost is deducted exactly")

	ResearchManager.configuration = _original_configuration
	ProgressionStore.set_section(&"research", {
		"levels": {
			"energy_install_slot_unlock": 7,
			"mining_install_slot_unlock": 3,
		},
		"unlocked": {
			"energy_install_slot_unlock": true,
			"mining_install_slot_unlock": true,
		},
	})
	ResearchManager.reload_progress()
	_expect_equal(ResearchManager.get_level(&"energy_install_slot_unlock"), 1, "legacy repeatable Energy progress migrates to completed")
	_expect_equal(ResearchManager.get_level(&"mining_install_slot_unlock"), 1, "legacy repeatable Mining progress migrates to completed")
	ProgressionStore.reload_from_disk()
	ResearchManager.reload_progress()
	_expect_equal(ResearchManager.get_level(&"energy_install_slot_unlock"), 1, "normalized Energy migration persists")
	_expect_equal(ResearchManager.get_level(&"mining_install_slot_unlock"), 1, "normalized Mining migration persists")


func _cleanup() -> void:
	ResearchManager.configuration = _original_configuration
	ShipLoadout.installed_modules.clear()
	_remove_test_save()
	# Keep the isolated path active until this test process exits. Switching back
	# can overwrite the player's real progression during shutdown or reloads.
	ResourceManager.reload_persistent_resources()
	ResearchManager.reload_progress()


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	if value:
		_failures.append(description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
