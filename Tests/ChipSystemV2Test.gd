extends Node

## Headless integration coverage for Chip System V2 instances, crafting,
## migration, qualities, per-turret sockets, swaps, scrapping, stat effects,
## and research milestones.

const TEST_SAVE_PATH := "user://greedminer_chip_v2_test.json"
const MACHINE_GUN_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const SHIP_SCENE: PackedScene = preload("res://Scenes/Ship/ship.tscn")
const MACHINE_GUN_PATH := "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"
const CANNON_PATH := "res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn"
const ENERGY_PATH := "res://Scenes/Modules/Energy/energy_module.tscn"
const TURRET_A := Vector2i(0, 0)
const TURRET_B := Vector2i(0, 1)
const CANNON_CELL := Vector2i(0, 2)
const EMPTY_CELL := Vector2i(2, 2)

var _failures: Array[String] = []
var _original_chip_configuration: ChipConfiguration
var _ship: Ship


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_original_chip_configuration = ChipManager.configuration
	_remove_test_save()
	ProgressionStore.set_save_path_for_testing(TEST_SAVE_PATH)
	ResourceManager.reload_persistent_resources()
	ResearchManager.reload_progress()
	ChipManager.configuration = _original_chip_configuration
	ChipManager.reload_progress()
	ShipLoadout.load_saved()
	ShipLoadout.install_module(1, 1, ENERGY_PATH)
	ShipLoadout.install_module(TURRET_A.x, TURRET_A.y, MACHINE_GUN_PATH)
	ShipLoadout.install_module(TURRET_B.x, TURRET_B.y, MACHINE_GUN_PATH)
	ShipLoadout.install_module(CANNON_CELL.x, CANNON_CELL.y, CANNON_PATH)
	_ship = SHIP_SCENE.instantiate() as Ship
	_ship.assembly_mode = true
	add_child(_ship)
	await get_tree().process_frame

	_test_configuration_and_milestones()
	_test_crafting_and_instances()
	_test_equipment_and_stats()
	_test_quality_and_persistence()
	await _test_hangar_and_warehouse_ui()
	_test_legacy_flat_damage_migration()
	_cleanup()

	if _failures.is_empty():
		print("CHIP_SYSTEM_V2_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("CHIP_SYSTEM_V2_TEST: " + failure)
		print("CHIP_SYSTEM_V2_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _test_configuration_and_milestones() -> void:
	for chip_id in [&"attack_chip", &"attack_speed_chip", &"damage_chip", &"range_chip", &"skill_chip"]:
		_expect_true(ChipManager.configuration.get_chip(chip_id) != null, "configured chip: %s" % chip_id)
		_expect_equal(ChipManager.configuration.get_crafting_cost(chip_id), 500, "500 Ore recipe: %s" % chip_id)
	_expect_false(ChipManager.is_chip_laboratory_unlocked(), "Chip Laboratory starts locked")
	_expect_true(ChipManager.craft_chip(&"attack_chip").is_empty(), "locked Laboratory rejects crafting")

	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 10
	_expect_true(ChipManager.is_chip_laboratory_unlocked(), "first Level 10 weapon unlocks Chip Laboratory")
	_expect_equal(ResearchManager.get_weapon_chip_slot_count(&"machine_gun"), 1, "Level 10 unlocks one slot")
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 20
	_expect_equal(ResearchManager.get_weapon_chip_slot_count(&"machine_gun"), 2, "Level 20 unlocks two slots")
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 30
	_expect_equal(ResearchManager.get_weapon_chip_slot_count(&"machine_gun"), 3, "Level 30 unlocks three slots")
	_expect_equal(ResearchManager.get_level(&"weapon_damage.machine_gun"), 30, "weapon research reaches Level 30")
	ResourceManager.stored_ore = 1000000.0
	_expect_false(ResearchManager.purchase_research(&"weapon_damage.machine_gun"), "weapon research cannot exceed Level 30")
	ResearchManager.save_progress()


func _test_crafting_and_instances() -> void:
	ProgressionStore.set_section(&"resources", {"stored_ore": 2500.0, "stored_energy": 0})
	ResourceManager.reload_persistent_resources()
	var ids: Array[StringName] = []
	for chip_id in [&"attack_chip", &"attack_speed_chip", &"damage_chip", &"range_chip", &"skill_chip"]:
		var instance_id := ChipManager.craft_chip(chip_id)
		_expect_false(instance_id.is_empty(), "craft succeeds: %s" % chip_id)
		ids.append(instance_id)
	_expect_equal(ids.duplicate().reduce(func(accum: Dictionary, value: StringName) -> Dictionary:
		accum[String(value)] = true
		return accum
	, {}).size(), 5, "crafted chips have distinct instance IDs")
	_expect_equal(ResourceManager.stored_ore, 0.0, "five chips cost exactly 2500 Ore")
	_expect_true(ChipManager.craft_chip(&"attack_chip").is_empty(), "insufficient Ore prevents crafting")

	ProgressionStore.set_section(&"resources", {"stored_ore": 1500.0, "stored_energy": 0})
	ResourceManager.reload_persistent_resources()
	for _index in range(3):
		_expect_false(ChipManager.craft_chip(&"attack_chip").is_empty(), "repeated unlimited crafting succeeds")
	_expect_equal(ChipManager.get_owned_count(&"attack_chip"), 4, "multiple copies accumulate without a cap")


func _test_equipment_and_stats() -> void:
	var attack := ChipManager.get_owned_instances(&"attack_chip")[0]
	var percent := ChipManager.get_owned_instances(&"damage_chip")[0]
	var speed := ChipManager.get_owned_instances(&"attack_speed_chip")[0]
	var skill := ChipManager.get_owned_instances(&"skill_chip")[0]
	var range_chip := ChipManager.get_owned_instances(&"range_chip")[0]
	_expect_equal(ChipManager.get_turret_weapon_type(TURRET_A), &"machine_gun", "cell resolves its weapon type")
	_expect_equal(ChipManager.get_turret_slot_count(TURRET_A), 3, "turret sockets follow weapon research")
	_expect_equal(ChipManager.get_turret_slot_count(CANNON_CELL), 0, "unresearched weapon has no sockets")
	_expect_equal(ChipManager.get_turret_slot_count(Vector2i(1, 1)), 0, "non-weapon modules have no sockets")
	_expect_true(ChipManager.equip_turret_chip(TURRET_A, 0, attack), "flat Attack Chip installs on turret A")
	_expect_true(ChipManager.equip_turret_chip(TURRET_A, 1, percent), "percentage Damage Chip installs on turret A")
	_expect_true(ChipManager.equip_turret_chip(TURRET_A, 2, attack), "installing an installed chip moves it")
	_expect_equal(ChipManager.get_turret_chip(TURRET_A, 0), &"", "moved chip leaves its old socket")
	_expect_equal(ChipManager.get_instance_slot_index(attack), 2, "moved chip reports its new socket")
	_expect_true(ChipManager.equip_turret_chip(TURRET_A, 0, attack), "chip moves back")
	_expect_equal(ChipManager.get_instance_location(attack), TURRET_A, "instance location is the turret cell")

	var gun_a := _ship.get_module_at(TURRET_A.x, TURRET_A.y) as MachineGun
	var gun_b := _ship.get_module_at(TURRET_B.x, TURRET_B.y) as MachineGun
	# Level 30 research damage is 34: (34 + 1 flat) * 1.2 = 42.
	_expect_approx(gun_a.get_damage(), 42.0, "flat damage applies before percentage damage")
	_expect_approx(gun_b.get_damage(), 34.0, "chips only affect the weapon instance where installed")
	_expect_equal(ChipManager.get_stat_modifiers({"stat_id": &"damage", "cell": TURRET_B}).size(), 0, "second turret has independent chip assignments")
	var loose := MACHINE_GUN_SCENE.instantiate() as MachineGun
	_expect_approx(loose.get_damage(), 34.0, "a weapon outside the ship gets no chip bonus")
	loose.free()
	_expect_true(ChipManager.unequip_turret_chip(TURRET_A, 1), "percentage chip uninstalls")
	_expect_true(ChipManager.equip_turret_chip(TURRET_A, 1, speed), "Attack Speed Chip installs")
	_expect_approx(gun_a.get_fire_rate(), 6.0, "Attack Speed Chip raises 5 attacks/s to 6")
	_expect_approx(gun_b.get_fire_rate(), 5.0, "the other turret keeps its own fire rate")
	_expect_false(ChipManager.equip_turret_chip(TURRET_A, 2, skill), "Skill Chip rejects a weapon without an active skill")
	_expect_approx(gun_a.get_modified_skill_cast_time(0.5), 0.5, "incompatible Skill Chip does not modify cast time")
	_expect_true(ChipManager.equip_turret_chip(TURRET_A, 2, range_chip), "Range Chip installs")
	_expect_approx(gun_a.get_modified_attack_range(gun_a.attack_range), gun_a.attack_range * 1.35, "Range Chip raises targeting range")
	_expect_false(ChipManager.equip_turret_chip(CANNON_CELL, 0, percent), "locked weapon socket rejects chips")
	_expect_false(ChipManager.equip_turret_chip(Vector2i(1, 1), 0, percent), "energy module rejects chips")

	# Swapping a module carries its instance chips with it.
	_expect_true(_ship.swap_modules(TURRET_A.x, TURRET_A.y, EMPTY_CELL.x, EMPTY_CELL.y), "turret moves to an empty cell")
	_expect_equal(ChipManager.get_turret_chips(EMPTY_CELL).size(), 3, "chips follow the moved turret")
	_expect_true(ChipManager.get_turret_chips(TURRET_A).is_empty(), "old cell keeps no chips")
	_expect_approx(gun_a.get_damage(), 35.0, "moved turret keeps its chip bonus")
	_expect_true(_ship.swap_modules(EMPTY_CELL.x, EMPTY_CELL.y, TURRET_A.x, TURRET_A.y), "turret moves back")
	_expect_equal(ChipManager.get_turret_chip(TURRET_A, 0), attack, "chips return with the turret")

	# Removing one turret returns that instance's chips to the Warehouse.
	_expect_true(ChipManager.equip_turret_chip(TURRET_B, 0, percent), "Damage Chip installs on turret B")
	_expect_true(_ship.remove_module(TURRET_B.x, TURRET_B.y), "turret B is removed")
	_expect_equal(ChipManager.get_instance_location(percent), Vector2i(-1, -1), "removed turret's chip becomes idle")
	_expect_false(ChipManager.is_instance_equipped(percent), "removed instance no longer equips its chip")

	# Scrapping: idle only, half of the Ore invested.
	var ore_before := ResourceManager.stored_ore
	_expect_equal(ChipManager.scrap_chip(attack), -1, "installed chips cannot be scrapped")
	_expect_equal(ChipManager.get_scrap_refund(percent), 250, "scrap refund is 50% of the recipe")
	_expect_equal(ChipManager.scrap_chip(percent), 250, "idle chip scraps")
	_expect_approx(ResourceManager.stored_ore, ore_before + 250.0, "scrap refunds Ore")
	_expect_true(ChipManager.get_chip_instance(percent).is_empty(), "scrapped instance is gone")
	_expect_equal(ChipManager.get_owned_count(&"damage_chip"), 0, "owned count drops after scrapping")


func _test_quality_and_persistence() -> void:
	var attack := ChipManager.get_turret_chip(TURRET_A, 0)
	_expect_false(ChipManager.can_upgrade_quality(attack), "unconfigured higher quality is unavailable")
	var custom := _original_chip_configuration.duplicate(true) as ChipConfiguration
	var attack_definition := custom.get_chip(&"attack_chip")
	var quality := ChipQualityTier.new()
	quality.quality_id = &"configured_test_quality"
	quality.display_name = "Configured Test Quality"
	quality.upgrade_cost = 100
	var effect := ChipStatEffect.new()
	effect.effect_id = &"flat_damage_quality_test"
	effect.stat_id = &"damage"
	effect.flat_bonus = 2.0
	quality.effects = [effect]
	attack_definition.qualities.append(quality)
	ChipManager.configuration = custom
	ProgressionStore.set_section(&"resources", {"stored_ore": 100.0, "stored_energy": 0})
	ResourceManager.reload_persistent_resources()
	_expect_true(ChipManager.upgrade_chip_quality(attack), "configured quality upgrade succeeds")
	_expect_equal(ChipManager.get_instance_quality_index(attack), 1, "quality advances independently")
	_expect_equal(ChipManager.get_instance_ore_invested(attack), 600, "invested Ore counts recipe and upgrades")
	ProgressionStore.reload_from_disk()
	ChipManager.reload_progress()
	_expect_equal(ChipManager.get_instance_quality_index(attack), 1, "quality persists after reload")
	_expect_equal(ChipManager.get_turret_chip(TURRET_A, 0), attack, "turret sockets persist after reload")
	_expect_equal(ResearchManager.get_weapon_chip_slot_count(&"machine_gun"), 3, "reload does not duplicate milestone slots")
	ChipManager.configuration = _original_chip_configuration


func _test_hangar_and_warehouse_ui() -> void:
	ProgressionStore.set_section(&"resources", {"stored_ore": 0.0, "stored_energy": 0})
	ResourceManager.reload_persistent_resources()
	var idle := ChipManager.add_owned_chip(&"damage_chip")
	_expect_true(idle, "UI test chip is owned")
	var panel := LoadoutPanel.new()
	panel.size = Vector2(LoadoutPanel.PANEL_WIDTH, 860.0)
	add_child(panel)
	await get_tree().process_frame
	panel.set_slot(TURRET_A.x, TURRET_A.y, &"machine_gun")
	await get_tree().process_frame
	var sockets := _find_all(panel, "ChipSocket")
	_expect_equal(sockets.size(), 3, "hangar detail shows three chip sockets")
	ChipManager.unequip_turret_chip(TURRET_A, 1)
	await get_tree().process_frame
	panel._open_picker(1)
	_expect_true(panel.is_picker_open(), "clicking a socket opens the picker drawer")
	var install_row: Node = null
	for row in panel.get_picker_rows():
		if row.get("chip_id") == &"damage_chip" and row.get("action") == "INSTALL":
			install_row = row
	_expect_true(install_row != null, "picker lists the idle Damage Chip")
	if install_row != null:
		install_row.activate()
	_expect_equal(ChipManager.get_instance_chip_type(ChipManager.get_turret_chip(TURRET_A, 1)), &"damage_chip", "INSTALL puts the chip into the chosen socket")
	_expect_false(panel.is_picker_open(), "picker closes after installing")
	panel.queue_free()

	var warehouse: Control = preload("res://Scripts/UI/WarehousePanel.gd").new()
	add_child(warehouse)
	await get_tree().process_frame
	warehouse.open_panel()
	warehouse.select_tab(2)
	var installed := ChipManager.get_turret_chip(TURRET_A, 0)
	warehouse.select_item(&"chip", installed)
	_expect_true(warehouse.scrap_button.disabled, "warehouse blocks scrapping installed chips")
	var spare := ChipManager.add_owned_chip(&"skill_chip")
	_expect_true(spare, "spare chip is owned")
	var spare_id: StringName = &""
	for instance_id in ChipManager.get_owned_instances(&"skill_chip"):
		if not ChipManager.is_instance_equipped(instance_id):
			spare_id = instance_id
	warehouse.select_item(&"chip", spare_id)
	warehouse.scrap_button.pressed.emit()
	_expect_false(ChipManager.get_chip_instance(spare_id).is_empty(), "first SCRAP click only arms the button")
	warehouse.scrap_button.pressed.emit()
	_expect_true(ChipManager.get_chip_instance(spare_id).is_empty(), "second SCRAP click scraps the idle chip")
	_expect_approx(ResourceManager.stored_ore, 250.0, "warehouse scrap refunds 250 Ore")
	warehouse.queue_free()
	await get_tree().process_frame


## Chip sockets are LoadoutPanel.ChipSocket buttons (they carry locked_text).
func _find_all(root: Node, _kind: String) -> Array[Node]:
	var found: Array[Node] = []
	for child in root.get_children():
		if child is Button and "locked_text" in child:
			found.append(child)
		found.append_array(_find_all(child, _kind))
	return found


func _test_legacy_flat_damage_migration() -> void:
	ProgressionStore.set_section(&"chips", {
		"owned": {"damage_chip": 2},
		"equipped": {"weapon.machine_gun": "damage_chip"},
	})
	ChipManager.reload_progress()
	_expect_equal(ChipManager.get_owned_count(&"attack_chip"), 2, "legacy flat damage_chip migrates to Attack Chip")
	_expect_equal(ChipManager.get_owned_count(&"damage_chip"), 0, "legacy flat chips do not become percentage chips")
	_expect_equal(ChipManager.get_instance_chip_type(ChipManager.get_turret_chip(TURRET_A, 0)), &"attack_chip", "V1 equipped chip lands on the first Machine Gun turret")

	ProgressionStore.set_section(&"chips", {
		"version": 2,
		"instances": {"speed-1": {"chip_type_id": "attack_speed_chip", "quality": 0}, "skill-2": {"chip_type_id": "skill_chip", "quality": 0}},
		"equipped": {"weapon.machine_gun.1": "speed-1", "weapon.laser.0": "skill-2"},
	})
	ChipManager.reload_progress()
	_expect_equal(ChipManager.get_turret_chip(TURRET_A, 1), &"speed-1", "V2 weapon-type socket migrates to the first turret of that type")
	_expect_false(ChipManager.is_instance_equipped(&"skill-2"), "incompatible legacy Skill Chip becomes idle safely")
	_expect_equal(ChipManager.get_owned_count(&"skill_chip"), 1, "migration keeps idle chips")


func _cleanup() -> void:
	if is_instance_valid(_ship):
		_ship.free()
	ChipManager.configuration = _original_chip_configuration
	_remove_test_save()
	# Keep the isolated path active until this test process exits. Switching back
	# can overwrite the player's real progression during shutdown or reloads.
	ResourceManager.reload_persistent_resources()
	ResearchManager.reload_progress()
	ShipLoadout.load_saved()
	ChipManager.reload_progress()


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


func _expect_approx(actual: float, expected: float, description: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
