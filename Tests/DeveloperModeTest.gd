extends Node

## Headless validation for Developer Mode grants, confirmation safety, complete
## progression reset, persistence, and the production command guard.

const TEST_SAVE_PATH: String = "user://greedminer_developer_mode_test.json"
const PANEL_SCENE: PackedScene = preload("res://Scenes/UI/developer_panel.tscn")
const TEST_MODULE_PATH: String = "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_remove_test_save()
	ProgressionStore.set_save_path_for_testing(TEST_SAVE_PATH)
	DeveloperCommands.set_availability_override_for_testing(1)
	_reset_runtime_from_test_save()

	_test_project_setting_guard()
	_test_grants_and_validation()
	_test_unlock_all_weapons()
	_test_unlock_all_artifacts()
	_test_unlock_all_planets()
	await _test_confirmation_and_complete_reset()
	_test_disabled_guard()
	_cleanup()

	if _failures.is_empty():
		print("DEVELOPER_MODE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("DEVELOPER_MODE_TEST: " + failure)
		print("DEVELOPER_MODE_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _test_grants_and_validation() -> void:
	var commands := DeveloperCommands.new()
	var starting_ore := ResourceManager.stored_ore
	var result := commands.grant_resource_from_text(&"ore", "1000")
	_expect_true(bool(result.get("ok", false)), "granting 1000 Ore succeeds")
	_expect_equal(ResourceManager.stored_ore, starting_ore + 1000.0, "grant adds exactly 1000 Ore")

	ProgressionStore.reload_from_disk()
	ResourceManager.reload_persistent_resources()
	_expect_equal(ResourceManager.stored_ore, starting_ore + 1000.0, "granted Ore persists after disk reload")

	var unchanged := ResourceManager.stored_ore
	for invalid in ["", "-1", "1.5", "ore", "999999999999999999999999999999"]:
		result = commands.grant_resource_from_text(&"ore", invalid)
		_expect_false(bool(result.get("ok", false)), "invalid amount is rejected: %s" % invalid)
		_expect_equal(ResourceManager.stored_ore, unchanged, "invalid amount does not change Ore: %s" % invalid)
	result = commands.grant_resource_from_text(&"gems", "10")
	_expect_false(bool(result.get("ok", false)), "unsupported future currency is rejected")
	_expect_equal(ResourceManager.stored_ore, unchanged, "unsupported currency does not change Ore")


func _test_project_setting_guard() -> void:
	# The build type is deliberately not part of the guard: this lets a shared
	# playtest/release build expose Developer Mode when its project setting is on.
	DeveloperCommands.set_availability_override_for_testing(-1)
	_expect_true(DeveloperCommands.is_available(), "project configuration enables Developer Mode")
	ProjectSettings.set_setting(DeveloperCommands.ENABLE_SETTING, false)
	_expect_false(DeveloperCommands.is_available(), "disabled project setting hides Developer Mode")
	ProjectSettings.set_setting(DeveloperCommands.ENABLE_SETTING, true)
	_expect_true(DeveloperCommands.is_available(), "enabled project setting allows Developer Mode in this build")
	DeveloperCommands.set_availability_override_for_testing(1)


func _test_unlock_all_weapons() -> void:
	var commands := DeveloperCommands.new()
	_expect_false(WeaponUnlockManager.is_weapon_unlocked(&"laser"), "Laser starts locked before developer unlock")
	var result := commands.unlock_all_weapons()
	_expect_true(bool(result.get("ok", false)), "developer command unlocks all weapons")
	for definition in WeaponUnlockManager.configuration.definitions:
		if definition != null:
			_expect_true(WeaponUnlockManager.is_weapon_unlocked(definition.weapon_id), "%s is unlocked" % definition.display_name)
	_expect_true(ResearchManager.is_unlocked(&"weapon_damage.laser"), "weapon research follows developer unlock")

	ProgressionStore.reload_from_disk()
	WeaponUnlockManager.reload_progress()
	for definition in WeaponUnlockManager.configuration.definitions:
		if definition != null:
			_expect_true(WeaponUnlockManager.is_weapon_unlocked(definition.weapon_id), "%s unlock persists" % definition.display_name)

	result = commands.unlock_all_weapons()
	_expect_true(bool(result.get("ok", false)), "unlock-all is harmless when already complete")
	_expect_true(String(result.get("message", "")).contains("already"), "repeat unlock reports existing state")


func _test_unlock_all_artifacts() -> void:
	var commands := DeveloperCommands.new()
	_expect_true(ArtifactManager.get_owned_artifact_ids().is_empty(), "artifacts start locked before developer unlock")
	var result := commands.unlock_all_artifacts()
	_expect_true(bool(result.get("ok", false)), "developer command unlocks all magic artifacts")
	for definition in ArtifactManager.get_all_definitions():
		if definition != null:
			_expect_true(ArtifactManager.owns_artifact(definition.artifact_id), "%s artifact is unlocked" % definition.display_name)
	_expect_true(ArtifactManager.is_stall_unlocked(), "artifact unlock opens Magic Stall")
	_expect_true(ArtifactManager.ship_slots.all(func(id: StringName) -> bool: return id.is_empty()), "artifact unlock does not auto-equip")

	ProgressionStore.reload_from_disk()
	ArtifactManager.reload_progress()
	for definition in ArtifactManager.get_all_definitions():
		if definition != null:
			_expect_true(ArtifactManager.owns_artifact(definition.artifact_id), "%s artifact unlock persists" % definition.display_name)
	result = commands.unlock_all_artifacts()
	_expect_true(bool(result.get("ok", false)), "artifact unlock is harmless when already complete")
	_expect_true(String(result.get("message", "")).contains("already"), "repeat artifact unlock reports existing state")


func _test_unlock_all_planets() -> void:
	var commands := DeveloperCommands.new()
	var starting_ore := ResourceManager.stored_ore
	_expect_false(WeaponUnlockManager.is_planet_located(&"frozen_planet", 500), "Frozen starts unlocated before developer unlock")
	_expect_false(ResearchManager.is_planet_in_range(&"frozen_planet"), "Frozen access research starts incomplete")

	var result := commands.unlock_all_planets()
	_expect_true(bool(result.get("ok", false)), "developer command unlocks all planets")
	for planet in PlanetSelect.PLANETS:
		var planet_id := StringName(planet.get("id", &""))
		var locate_cost := int(planet.get("locate_cost", 0))
		_expect_true(WeaponUnlockManager.is_planet_located(planet_id, locate_cost), "%s is located" % planet_id)
		_expect_true(ResearchManager.is_planet_in_range(planet_id), "%s access research is complete" % planet_id)
	_expect_equal(ResourceManager.stored_ore, starting_ore, "planet developer unlock spends no Ore")
	_expect_true(WeaponUnlockManager.completed_planet_ids.is_empty(), "planet developer unlock does not mark planets cleared")

	ProgressionStore.reload_from_disk()
	WeaponUnlockManager.reload_progress()
	ResearchManager.reload_progress()
	for planet in PlanetSelect.PLANETS:
		var planet_id := StringName(planet.get("id", &""))
		var locate_cost := int(planet.get("locate_cost", 0))
		_expect_true(WeaponUnlockManager.is_planet_located(planet_id, locate_cost), "%s developer location persists" % planet_id)
		_expect_true(ResearchManager.is_planet_in_range(planet_id), "%s access research persists" % planet_id)
	result = commands.unlock_all_planets()
	_expect_true(bool(result.get("ok", false)), "unlock-all-planets is harmless when already complete")
	_expect_true(String(result.get("message", "")).contains("already"), "repeat planet unlock reports existing state")


func _test_confirmation_and_complete_reset() -> void:
	_seed_all_progression()
	var panel := PANEL_SCENE.instantiate() as DeveloperPanel
	panel.return_to_base_after_reset = false
	add_child(panel)
	await get_tree().process_frame

	# Opening and then canceling the confirmation must not invoke the command.
	panel.open_panel()
	panel._on_reset_requested()
	panel.reset_confirmation.hide()
	_expect_equal(ResourceManager.stored_ore, 4321.0, "canceling reset leaves resources unchanged")
	_expect_true(ShipLoadout.has_module(0, 1), "canceling reset leaves loadout unchanged")
	_expect_equal(ResearchManager.get_level(&"weapon_damage.machine_gun"), 5, "canceling reset leaves research unchanged")

	panel._on_reset_requested()
	panel._on_reset_confirmed()
	_expect_equal(ResourceManager.stored_ore, 0.0, "reset restores Ore default")
	_expect_equal(ResourceManager.mission_ore, 0.0, "reset clears transient mission Ore")
	_expect_true(ShipLoadout.installed_modules.is_empty(), "reset clears saved ship modules")
	_expect_equal(ShipLoadout.style_id, &"bone_iron", "reset restores default hull style")
	_expect_equal(ShipLoadout.layout_rotation, 0.0, "reset restores default hull rotation")
	_expect_equal(ResearchManager.get_level(&"weapon_damage.machine_gun"), 1, "reset restores research starting level")
	_expect_true(ChipManager.owned_chips.is_empty(), "reset clears owned chips")
	_expect_true(ChipManager.loadout.assignments.is_empty(), "reset clears equipped chips")
	_expect_true(ArtifactManager.get_owned_artifact_ids().is_empty(), "reset clears owned magic artifacts")
	_expect_false(ArtifactManager.is_stall_unlocked(), "reset locks the Magic Stall")
	_expect_true(ArtifactManager.ship_slots.all(func(id: StringName) -> bool: return id.is_empty()), "reset clears ship artifact slots")
	_expect_true(ArtifactManager.module_slots.is_empty(), "reset clears module artifact slots")
	_expect_true(WeaponUnlockManager.is_weapon_unlocked(&"machine_gun"), "reset restores starting Machine Gun unlock")
	_expect_false(WeaponUnlockManager.is_weapon_unlocked(&"dwarf_cannon"), "reset locks progression weapons")
	_expect_true(WeaponUnlockManager.completed_planet_ids.is_empty(), "reset clears planet completions")
	for section in [&"resources", &"loadout", &"research", &"chips", &"magic_artifacts"]:
		_expect_true(ProgressionStore.get_section(section).is_empty(), "reset removes persisted %s section" % section)
	# The starting Machine Gun is immediately migrated into a fresh unlock section.
	_expect_false(ProgressionStore.get_section(&"weapon_unlocks").is_empty(), "reset persists starting weapon defaults")

	panel.queue_free()
	await get_tree().process_frame


func _test_disabled_guard() -> void:
	var commands := DeveloperCommands.new()
	ResourceManager.add_stored_ore(50.0)
	var before := ResourceManager.stored_ore
	DeveloperCommands.set_availability_override_for_testing(0)
	var result := commands.grant_resource_from_text(&"ore", "1000")
	_expect_false(bool(result.get("ok", false)), "disabled guard blocks resource grant")
	_expect_equal(ResourceManager.stored_ore, before, "blocked grant changes no resources")
	result = commands.reset_all_progress()
	_expect_false(bool(result.get("ok", false)), "disabled guard blocks progression reset")
	_expect_equal(ResourceManager.stored_ore, before, "blocked reset preserves progression")
	result = commands.unlock_all_weapons()
	_expect_false(bool(result.get("ok", false)), "disabled guard blocks weapon unlock")
	_expect_false(WeaponUnlockManager.is_weapon_unlocked(&"dwarf_cannon"), "blocked unlock preserves weapon progression")
	result = commands.unlock_all_artifacts()
	_expect_false(bool(result.get("ok", false)), "disabled guard blocks artifact unlock")
	_expect_true(ArtifactManager.get_owned_artifact_ids().is_empty(), "blocked artifact unlock preserves collection")
	result = commands.unlock_all_planets()
	_expect_false(bool(result.get("ok", false)), "disabled guard blocks planet unlock")
	_expect_false(WeaponUnlockManager.is_planet_located(&"frozen_planet", 500), "blocked planet unlock preserves locations")
	_expect_false(WeaponUnlockManager.locate_planet_for_development(&"frozen_planet"), "disabled guard blocks direct developer planet location")
	_expect_false(ResearchManager.complete_research_for_development(&"energy_range_1"), "disabled guard blocks direct developer research completion")

	var panel := PANEL_SCENE.instantiate() as DeveloperPanel
	add_child(panel)
	panel.open_panel()
	_expect_false(panel.visible, "disabled guard prevents panel from opening")
	panel.queue_free()
	DeveloperCommands.set_availability_override_for_testing(1)


func _seed_all_progression() -> void:
	ProgressionStore.set_section(&"resources", {"stored_ore": 4321.0, "stored_energy": 7})
	ProgressionStore.set_section(&"loadout", {
		"cells": {"0,1": TEST_MODULE_PATH},
		"style": "deep_space",
		"rotation": 45.0,
	})
	var research_data := ResearchManager.progress.export_data()
	research_data["levels"]["weapon_damage.machine_gun"] = 5
	ProgressionStore.set_section(&"research", research_data)
	ProgressionStore.set_section(&"chips", {
		"owned": {"test_chip": 2},
		"equipped": {"test_slot": "test_chip"},
	})
	ProgressionStore.set_section(&"weapon_unlocks", {
		"unlocked_weapons": {"machine_gun": true, "dwarf_cannon": true},
		"completed_planets": {"rocky_planet": true},
	})
	ProgressionStore.set_section(&"magic_artifacts", {
		"version": 1,
		"owned": {"stone_heart": true},
		"ship_slots": ["stone_heart", "", ""],
		"module_slots": {},
		"stall_unlocked": true,
		"tutorial_pending": true,
		"tutorial_completed": false,
		"first_artifact_id": "stone_heart",
	})
	_reset_runtime_from_test_save()


func _reset_runtime_from_test_save() -> void:
	ProgressionStore.reload_from_disk()
	ResourceManager.start_new_mission()
	ResourceManager.reload_persistent_resources()
	WeaponUnlockManager.reload_progress()
	ShipLoadout.load_saved()
	ResearchManager.reload_progress()
	ChipManager.reload_progress()
	ArtifactManager.reload_progress()


func _cleanup() -> void:
	DeveloperCommands.set_availability_override_for_testing(-1)
	_remove_test_save()
	# Keep the isolated path active until this test process exits. Switching back
	# can overwrite the player's real progression during shutdown or reloads.
	ResourceManager.reload_persistent_resources()
	WeaponUnlockManager.reload_progress()
	ShipLoadout.load_saved()
	ResearchManager.reload_progress()
	ChipManager.reload_progress()
	ArtifactManager.reload_progress()


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	_expect_true(not value, description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
