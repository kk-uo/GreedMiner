extends Node

## Integration checks for Battery pricing, planet-completion weapon rewards,
## persistence, research gates, install guards, and legacy loadout safety.

const TEST_SAVE_PATH: String = "user://greedminer_weapon_unlock_test.json"
const SHIP_SCENE: PackedScene = preload("res://Scenes/Ship/ship.tscn")
const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const MACHINE_GUN_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const DWARF_CANNON_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn")
const LASER_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/Laser/laser.tscn")
const ROCKY_CONFIG: PlanetWaveConfig = preload("res://Resources/Waves/RockyPlanetWaves.tres")
const GOBLIN_CONFIG: PlanetWaveConfig = preload("res://Resources/Waves/VerdantPlanetWaves.tres")

var _failures: Array[String] = []
var _unlock_signal_count: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_remove_test_save()
	ProgressionStore.set_save_path_for_testing(TEST_SAVE_PATH)
	_reload_test_progress()
	WeaponUnlockManager.weapon_unlocked.connect(_on_weapon_unlocked)

	_test_battery_price()
	await _test_starting_unlocks_and_install_guard()
	await _test_evacuation_does_not_complete_planet()
	await _test_rocky_completion_and_notification()
	_test_persistence_and_duplicate_reward()
	_test_goblin_and_laser_rules()
	await _test_legacy_loadout_safety()
	_cleanup()

	if _failures.is_empty():
		print("WEAPON_UNLOCK_SYSTEM_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("WEAPON_UNLOCK_SYSTEM_TEST: " + failure)
		print("WEAPON_UNLOCK_SYSTEM_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _test_battery_price() -> void:
	# Expedition energy was removed: no energy economy remains on ResourceManager.
	_expect_false(ResourceManager.has_method("purchase_energy"), "energy can no longer be bought with Ore")
	_expect_false("stored_energy" in ResourceManager, "stored expedition energy no longer exists")


func _test_starting_unlocks_and_install_guard() -> void:
	_expect_true(WeaponUnlockManager.is_weapon_unlocked(&"machine_gun"), "Machine Gun starts unlocked")
	_expect_false(WeaponUnlockManager.is_weapon_unlocked(&"dwarf_cannon"), "Dwarf Cannon starts locked")
	_expect_false(WeaponUnlockManager.is_weapon_unlocked(&"chainsaw"), "Chainsaw starts locked")
	_expect_false(WeaponUnlockManager.is_weapon_unlocked(&"laser"), "Laser starts locked")
	_expect_true(ResearchManager.is_unlocked(&"weapon_damage.machine_gun"), "Machine Gun research starts available")
	_expect_false(ResearchManager.is_unlocked(&"weapon_damage.dwarf_cannon"), "Dwarf Cannon research starts locked")
	_expect_false(ResearchManager.is_unlocked(&"weapon_damage.chainsaw"), "Chainsaw research starts locked")
	_expect_false(ResearchManager.is_unlocked(&"weapon_damage.laser"), "Laser research stays locked")
	_expect_false(ResearchManager.is_unlocked(&"shield_power.knockback_module"), "Knockback research starts locked with its module")
	_expect_false(ResearchManager.is_unlocked(&"shield_power.regeneration_module"), "Regeneration research starts locked with its module")

	ProgressionStore.set_section(&"resources", {"stored_ore": 0.0, "stored_energy": 0})
	ResourceManager.reload_persistent_resources()
	ShipLoadout.installed_modules.clear()
	var ship := SHIP_SCENE.instantiate() as Ship
	ship.assembly_mode = true
	add_child(ship)
	await get_tree().process_frame
	_expect_true(ship.install_module(MACHINE_GUN_SCENE, Ship.ModuleType.Weapon, 0, 0), "unlocked Machine Gun installs")
	_expect_false(ship.install_module(DWARF_CANNON_SCENE, Ship.ModuleType.Weapon, 0, 1), "locked Dwarf Cannon cannot install")
	_expect_true(ship.last_module_error.contains("Complete Rocky Planet"), "install rejection includes unlock requirement")
	ship.queue_free()
	await get_tree().process_frame


func _test_evacuation_does_not_complete_planet() -> void:
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	add_child(battle)
	await get_tree().process_frame
	manager.stop_wave_system(&"evacuated")
	await get_tree().process_frame
	_expect_false(WeaponUnlockManager.has_completed_planet(&"rocky_planet"), "evacuation does not record planet completion")
	_expect_false(WeaponUnlockManager.is_weapon_unlocked(&"dwarf_cannon"), "evacuation does not unlock Dwarf Cannon")
	battle.queue_free()
	await get_tree().process_frame


func _test_rocky_completion_and_notification() -> void:
	ShipLoadout.installed_modules.clear()
	var battle := BATTLE_SCENE.instantiate()
	(battle.get_node("WaveManager") as WaveManager).auto_start = false
	add_child(battle)
	await get_tree().process_frame
	battle._on_planet_completed(ROCKY_CONFIG)
	await get_tree().process_frame
	_expect_true(WeaponUnlockManager.has_completed_planet(&"rocky_planet"), "Rocky victory is recorded")
	_expect_true(WeaponUnlockManager.is_weapon_unlocked(&"dwarf_cannon"), "Rocky victory unlocks Dwarf Cannon")
	_expect_true(ResearchManager.is_unlocked(&"weapon_damage.dwarf_cannon"), "Dwarf Cannon research follows weapon unlock")
	var unlock_label := battle.get_node("BattleUI/UIRoot/CompletionPanel/VBoxContainer/UnlockLabel") as Label
	_expect_true(unlock_label.visible and unlock_label.text.contains("Dwarf Cannon"), "first victory shows unlock notification")
	battle.queue_free()
	await get_tree().process_frame


func _test_persistence_and_duplicate_reward() -> void:
	ProgressionStore.reload_from_disk()
	WeaponUnlockManager.reload_progress()
	_expect_true(WeaponUnlockManager.is_weapon_unlocked(&"dwarf_cannon"), "weapon unlock survives disk reload")
	_expect_true(WeaponUnlockManager.has_completed_planet(&"rocky_planet"), "planet completion survives disk reload")
	var saved_unlocks: Dictionary = ProgressionStore.get_section(&"weapon_unlocks").get("unlocked_weapons", {})
	for definition in WeaponUnlockManager.configuration.definitions:
		if definition != null:
			_expect_true(
				saved_unlocks.has(String(definition.weapon_id)),
				"save contains explicit state for %s" % String(definition.weapon_id)
			)
	var first_signal_count := _unlock_signal_count
	var repeated := WeaponUnlockManager.record_planet_completion(&"rocky_planet")
	_expect_true(repeated.is_empty(), "repeat victory grants no duplicate weapon")
	_expect_equal(_unlock_signal_count, first_signal_count, "repeat victory emits no duplicate reward")


func _test_goblin_and_laser_rules() -> void:
	var unlocked := WeaponUnlockManager.record_planet_completion(GOBLIN_CONFIG.planet_id)
	_expect_true(unlocked.has(&"knockback_module"), "Goblin Planet (boss) completion unlocks Knockback")
	_expect_true(WeaponUnlockManager.is_weapon_unlocked(&"knockback_module"), "Knockback remains unlocked")
	_expect_true(ResearchManager.is_unlocked(&"shield_power.knockback_module"), "Knockback research follows its module unlock")
	_expect_false(unlocked.has(&"chainsaw"), "Chainsaw is planned for later, not a Goblin reward")
	_expect_false(WeaponUnlockManager.is_weapon_unlocked(&"regeneration_module"), "Regeneration is planned for later")
	_expect_false(ResearchManager.is_unlocked(&"shield_power.regeneration_module"), "Regeneration research remains locked with its module")
	_expect_false(WeaponUnlockManager.is_weapon_unlocked(&"laser"), "Laser remains locked after known planets")
	_expect_false(ResearchManager.is_unlocked(&"weapon_damage.laser"), "Laser research remains locked")


func _test_legacy_loadout_safety() -> void:
	# A locked Laser already present in an old save is restored, not deleted.
	ShipLoadout.installed_modules.clear()
	ShipLoadout.install_module(0, 0, LASER_SCENE.resource_path)
	var ship := SHIP_SCENE.instantiate() as Ship
	ship.assembly_mode = true
	add_child(ship)
	await get_tree().process_frame
	_expect_true(ShipLoadout.has_module(0, 0), "legacy locked weapon remains in loadout")
	_expect_true(ship.get_module_at(0, 0) is Laser, "legacy locked weapon is restored into the ship")
	_expect_false(ship.install_module(LASER_SCENE, Ship.ModuleType.Weapon, 0, 1), "legacy ownership does not bypass new Laser installs")
	ship.queue_free()
	await get_tree().process_frame


func _reload_test_progress() -> void:
	ProgressionStore.reload_from_disk()
	ResourceManager.reload_persistent_resources()
	WeaponUnlockManager.reload_progress()
	ResearchManager.reload_progress()
	ShipLoadout.load_saved()


func _cleanup() -> void:
	if WeaponUnlockManager.weapon_unlocked.is_connected(_on_weapon_unlocked):
		WeaponUnlockManager.weapon_unlocked.disconnect(_on_weapon_unlocked)
	ShipLoadout.installed_modules.clear()
	_remove_test_save()
	# Keep the isolated path active until this test process exits. Switching back
	# can overwrite the player's real progression during shutdown or reloads.
	ResourceManager.reload_persistent_resources()
	WeaponUnlockManager.reload_progress()
	ResearchManager.reload_progress()
	ShipLoadout.load_saved()


func _on_weapon_unlocked(_weapon_id: StringName, _display_name: String) -> void:
	_unlock_signal_count += 1


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
