extends Node

## Integration coverage for "precise locate" planet unlocks (paid once with
## Ore), launch eligibility without expedition energy/fuel, and launching.

const TEST_SAVE_PATH: String = "user://greedminer_planet_locate_test.json"
const ENERGY_SCENE: PackedScene = preload("res://Scenes/Modules/Energy/energy_module.tscn")
const PLANET_SELECT_SCENE: PackedScene = preload("res://Scenes/PlanetSelection/planet_select.tscn")
const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")

var _failures: Array[String] = []
var _saved_loadout: Dictionary


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_saved_loadout = ShipLoadout.installed_modules.duplicate()
	_remove_test_save()
	ProgressionStore.set_save_path_for_testing(TEST_SAVE_PATH)
	ResourceManager.reload_persistent_resources()
	WeaponUnlockManager.reload_progress()
	ResearchManager.reload_progress()
	ShipLoadout.installed_modules.clear()

	_test_range_research()
	_test_requirements()
	_test_locate_transaction_and_persistence()
	await _test_planet_select_flow()
	await _test_battle_uses_selected_planet()
	_cleanup()

	if _failures.is_empty():
		print("PLANET_LOCATE_LAUNCH_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("PLANET_LOCATE_LAUNCH_TEST: " + failure)
		print("PLANET_LOCATE_LAUNCH_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _profile(energy_modules: int, consumption: int = 0) -> Dictionary:
	return {
		"energy_module_count": energy_modules,
		"total_power_capacity": energy_modules * 5,
		"total_power_consumption": consumption,
	}


## Verdant needs Long-Range Cells (Energy); Frozen also needs Air Conditioning
## (Ship); Volcanic needs Air Conditioning and Long-Long-Range Cells (Energy).
func _test_range_research() -> void:
	var verdant: Dictionary = PlanetSelect.PLANETS[1]
	var status := PlanetSelect.evaluate_launch_requirements(verdant, _profile(1), 99999.0)
	_expect_false(status.in_range, "Verdant starts out of range")
	_expect_false(status.can_locate, "out-of-range Verdant cannot be located")
	_expect_equal(status.range_research, &"energy_range_1", "Long-Range Cells gate Verdant")
	_expect_true(PlanetSelect.evaluate_launch_requirements(PlanetSelect.PLANETS[0], _profile(1), 0.0).in_range, "Rocky is always in range")
	var volcanic_status := PlanetSelect.evaluate_launch_requirements(PlanetSelect.PLANETS[3], _profile(1), 0.0)
	_expect_false(volcanic_status.in_range, "Volcanic starts out of range")
	var volcanic_gates := ResearchManager.get_planet_access_researches(&"volcanic_planet")
	_expect_true(volcanic_gates.has(&"ship_air_conditioning_1") and volcanic_gates.has(&"energy_range_2"), "Air Conditioning and Long-Long-Range Cells gate Volcanic")
	var frozen: Dictionary = PlanetSelect.PLANETS[2]
	_expect_false(PlanetSelect.evaluate_launch_requirements(frozen, _profile(1), 500.0).can_locate, "Frozen requires both research upgrades")
	ResearchManager.progress.levels["energy_range_1"] = 1
	_expect_false(PlanetSelect.evaluate_launch_requirements(frozen, _profile(1), 500.0).can_locate, "Frozen requires Air Conditioning")
	ResearchManager.progress.levels["energy_range_1"] = 0
	ResearchManager.progress.levels["ship_air_conditioning_1"] = 1
	_expect_false(PlanetSelect.evaluate_launch_requirements(frozen, _profile(1), 500.0).can_locate, "Frozen requires Long-Range Cells")
	# The rest of this test runs with the research done.
	ResearchManager.progress.levels["energy_range_1"] = 1
	ResearchManager.progress.levels["ship_air_conditioning_1"] = 1
	ResearchManager.progress.levels["energy_range_2"] = 1
	_expect_true(PlanetSelect.evaluate_launch_requirements(verdant, _profile(1), 0.0).in_range, "Long-Range Cells bring Verdant into range")


func _test_requirements() -> void:
	var rocky: Dictionary = PlanetSelect.PLANETS[0]
	var verdant: Dictionary = PlanetSelect.PLANETS[1]
	var frozen: Dictionary = PlanetSelect.PLANETS[2]
	var volcanic: Dictionary = PlanetSelect.PLANETS[3]
	_expect_equal(PlanetSelect.get_locate_cost(rocky), 0, "Rocky Planet is free")
	_expect_equal(PlanetSelect.get_locate_cost(verdant), 250, "Verdant Planet costs 250 Ore to locate")
	_expect_equal(PlanetSelect.get_locate_cost(frozen), 500, "Frozen Planet costs 500 Ore to locate")
	_expect_equal(PlanetSelect.get_locate_cost(volcanic), 1000, "Volcanic Planet costs 1000 Ore to locate")
	_expect_true(PlanetSelect.evaluate_launch_requirements(rocky, _profile(1), 0.0).eligible, "Rocky launches with no Ore and no energy")
	var uncharted := PlanetSelect.evaluate_launch_requirements(verdant, _profile(1), 249.0)
	_expect_false(uncharted.eligible, "uncharted Verdant cannot launch")
	_expect_false(uncharted.can_locate, "249 Ore cannot locate Verdant")
	_expect_equal(uncharted.missing_ore, 1, "missing Ore is reported")
	_expect_true(PlanetSelect.evaluate_launch_requirements(verdant, _profile(1), 250.0).can_locate, "250 Ore can locate Verdant")
	_expect_false(PlanetSelect.evaluate_launch_requirements(rocky, _profile(0), 0.0).eligible, "a loadout without an Energy Module cannot launch")
	_expect_false(PlanetSelect.evaluate_launch_requirements(rocky, _profile(1, 6), 0.0).eligible, "an over-powered loadout cannot launch")
	_expect_false(PlanetSelect.evaluate_launch_requirements(frozen, _profile(1), 499.0).can_locate, "499 Ore cannot locate Frozen")
	_expect_true(PlanetSelect.evaluate_launch_requirements(frozen, _profile(1), 500.0).can_locate, "500 Ore can locate Frozen after both researches")
	_expect_false(PlanetSelect.evaluate_launch_requirements(volcanic, _profile(1), 999.0).can_locate, "999 Ore cannot locate Volcanic")
	_expect_true(PlanetSelect.evaluate_launch_requirements(volcanic, _profile(1), 1000.0).can_locate, "1000 Ore can locate Volcanic")


func _test_locate_transaction_and_persistence() -> void:
	_set_ore(499.0)
	_expect_false(WeaponUnlockManager.locate_planet(&"frozen_planet", 500), "Frozen locate fails without 500 Ore")
	_expect_equal(ResourceManager.stored_ore, 499.0, "failed Frozen locate spends nothing")
	_set_ore(600.0)
	_expect_true(WeaponUnlockManager.locate_planet(&"frozen_planet", 500), "Frozen locate succeeds")
	_expect_equal(ResourceManager.stored_ore, 100.0, "Frozen locate deducts exactly 500 Ore")
	_expect_true(WeaponUnlockManager.locate_planet(&"frozen_planet", 500), "repeated Frozen locate is a no-op")
	_expect_equal(ResourceManager.stored_ore, 100.0, "repeated Frozen locate is free")
	ProgressionStore.reload_from_disk()
	WeaponUnlockManager.reload_progress()
	_expect_true(WeaponUnlockManager.is_planet_located(&"frozen_planet", 500), "Frozen location survives reload")
	_expect_true(PlanetSelect.evaluate_launch_requirements(PlanetSelect.PLANETS[2], _profile(1), 0.0).eligible, "located Frozen is playable")
	_set_ore(200.0)
	_expect_false(WeaponUnlockManager.locate_planet(&"goblin_planet", 250), "locating without enough Ore fails")
	_expect_equal(ResourceManager.stored_ore, 200.0, "failed locate spends no Ore")
	_set_ore(300.0)
	_expect_true(WeaponUnlockManager.locate_planet(&"goblin_planet", 250), "locating with 300 Ore succeeds")
	_expect_equal(ResourceManager.stored_ore, 50.0, "locate deducts exactly 250 Ore")
	_expect_true(WeaponUnlockManager.locate_planet(&"goblin_planet", 250), "locating again is a no-op success")
	_expect_equal(ResourceManager.stored_ore, 50.0, "locating again spends nothing")
	ProgressionStore.reload_from_disk()
	WeaponUnlockManager.reload_progress()
	_expect_true(WeaponUnlockManager.is_planet_located(&"goblin_planet", 250), "located planet survives reload")
	# Legacy saves: a planet already cleared counts as located.
	ProgressionStore.set_section(&"weapon_unlocks", {"completed_planets": {"goblin_planet": true}})
	WeaponUnlockManager.reload_progress()
	_expect_true(WeaponUnlockManager.is_planet_located(&"goblin_planet", 250), "a cleared planet is located for free")
	ProgressionStore.set_section(&"weapon_unlocks", {})
	WeaponUnlockManager.reload_progress()
	_set_ore(1000.0)
	_expect_true(WeaponUnlockManager.locate_planet(&"volcanic_planet", 1000), "Volcanic locate succeeds at 1000 Ore")
	_expect_equal(ResourceManager.stored_ore, 0.0, "Volcanic locate deducts exactly 1000 Ore")
	_expect_true(WeaponUnlockManager.is_planet_located(&"volcanic_planet", 1000), "Volcanic locate is persisted")
	var volcanic_status := PlanetSelect.evaluate_launch_requirements(PlanetSelect.PLANETS[3], _profile(1), 0.0)
	_expect_true(volcanic_status.eligible, "located Volcanic can deploy with its wave configuration")


func _test_planet_select_flow() -> void:
	_set_ore(260.0)
	ShipLoadout.installed_modules.clear()
	ShipLoadout.install_module(1, 1, ENERGY_SCENE.resource_path)
	ResourceManager.set_current_expedition_planet(&"goblin_planet")
	var selector := PLANET_SELECT_SCENE.instantiate() as PlanetSelect
	selector.battle_scene_path = "res://Scenes/does_not_exist.tscn"
	add_child(selector)
	await get_tree().process_frame
	_expect_equal(selector.selected_index, 1, "star map reopens on the last deployed planet")
	_expect_equal(PlanetSelect.get_planet_index(&"volcanic_planet"), 3, "planet IDs resolve to carousel indexes")
	_expect_equal(PlanetSelect.get_planet_index(&"removed_planet"), 0, "unknown planet IDs fall back to Rocky")
	selector.selected_index = 2
	_set_ore(500.0)
	ResearchManager.progress.levels["ship_air_conditioning_1"] = 0
	selector._update_planet_information()
	_expect_true(selector.deploy_button.disabled, "Frozen button is disabled without Air Conditioning")
	_expect_false(selector.locate_selected_planet(), "direct Frozen locate rejects missing research")
	_expect_equal(ResourceManager.stored_ore, 500.0, "missing research does not spend Ore")
	ResearchManager.progress.levels["ship_air_conditioning_1"] = 1
	selector._update_planet_information()
	_expect_false(selector.deploy_button.disabled, "Frozen locate button is enabled with research and Ore")
	await selector._on_deploy_pressed()
	_expect_equal(ResourceManager.stored_ore, 0.0, "Frozen selector deducts 500 Ore")
	_expect_equal(selector.deploy_button.text, "DEPLOY", "located Frozen offers deployment")
	selector.selected_index = 1
	_set_ore(260.0)
	selector._update_planet_information()
	_expect_true(selector.deploy_button.text.contains("LOCATE"), "uncharted Verdant offers PRECISE LOCATE")
	_expect_false(selector.deploy_button.disabled, "locate button is enabled with enough Ore")
	await selector._on_deploy_pressed()
	_expect_true(WeaponUnlockManager.is_planet_located(&"goblin_planet", 250), "pressing locate pinpoints Verdant")
	_expect_equal(ResourceManager.stored_ore, 10.0, "locate from the selector costs 250 Ore")
	_expect_equal(selector.deploy_button.text, "DEPLOY", "located Verdant can now be deployed")
	ResourceManager.set_current_expedition_planet(&"rocky_planet")
	await selector._on_deploy_pressed()
	_expect_equal(ResourceManager.current_expedition_planet_id, &"rocky_planet", "failed transition restores the previous destination")
	selector.queue_free()
	await get_tree().process_frame


func _test_battle_uses_selected_planet() -> void:
	ResourceManager.set_current_expedition_planet(&"goblin_planet")
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	add_child(battle)
	await get_tree().process_frame
	_expect_equal(manager.wave_config.planet_id, &"goblin_planet", "Verdant launch selects the Verdant wave configuration")
	_expect_equal((battle.get_node("Battlefield") as Battlefield).planet_theme, &"jungle", "Verdant launch selects the jungle battlefield")
	battle.queue_free()
	await get_tree().process_frame

	ResourceManager.set_current_expedition_planet(&"frozen_planet")
	battle = BATTLE_SCENE.instantiate()
	manager = battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	add_child(battle)
	await get_tree().process_frame
	_expect_equal(manager.wave_config.planet_id, &"frozen_planet", "Frozen launch selects its wave configuration")
	_expect_equal((battle.get_node("Battlefield") as Battlefield).planet_theme, &"frozen", "Frozen launch selects its battlefield theme")
	battle.queue_free()
	await get_tree().process_frame

	ResourceManager.set_current_expedition_planet(&"volcanic_planet")
	battle = BATTLE_SCENE.instantiate()
	manager = battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	add_child(battle)
	await get_tree().process_frame
	_expect_equal(manager.wave_config.planet_id, &"volcanic_planet", "Volcanic launch selects the Volcanic wave configuration")
	_expect_equal((battle.get_node("Battlefield") as Battlefield).planet_theme, &"volcanic", "Volcanic launch selects the volcanic battlefield")
	battle.queue_free()
	await get_tree().process_frame


func _set_ore(ore: float) -> void:
	ProgressionStore.set_section(&"resources", {"stored_ore": ore})
	ResourceManager.reload_persistent_resources()


func _cleanup() -> void:
	ShipLoadout.installed_modules = _saved_loadout.duplicate()
	ResourceManager.set_current_expedition_planet(&"rocky_planet")
	_remove_test_save()
	ResourceManager.reload_persistent_resources()
	WeaponUnlockManager.reload_progress()


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
