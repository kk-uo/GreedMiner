extends Node

## Integration coverage for universal chip adaptation and pulse-based area healing.

const TEST_SAVE_PATH := "user://universal_chip_healing_test.json"
const SHIP_SCENE := preload("res://Scenes/Ship/ship.tscn")
const MACHINE_GUN_PATH := "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"
const KNOCKBACK_PATH := "res://Scenes/Modules/Shield/knockback_module.tscn"
const REGENERATION_PATH := "res://Scenes/Modules/Shield/regeneration_module.tscn"
const ENERGY_PATH := "res://Scenes/Modules/Energy/energy_module.tscn"
const CANNON_PATH := "res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn"
const LASER_PATH := "res://Scenes/Modules/Weapons/Laser/laser.tscn"
const CHAINSAW_PATH := "res://Scenes/Modules/Weapons/Chainsaw/chainsaw.tscn"
const WEAPON_CELL := Vector2i(0, 0)
const KNOCKBACK_CELL := Vector2i(0, 1)
const REGEN_CELL := Vector2i(0, 2)

var _failures: Array[String] = []


class FriendlyHealingMock extends Node2D:
	var current_hp: float = 5.5
	var max_hp: float = 10.0
	var heal_calls: int = 0

	func _ready() -> void:
		add_to_group("friendly_healing_targets")

	func can_receive_healing() -> bool:
		return current_hp > 0.0 and current_hp < max_hp

	func get_healing_position() -> Vector2:
		return global_position

	func heal(amount: float) -> void:
		current_hp = minf(current_hp + amount, max_hp)
		heal_calls += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_remove_test_save()
	ProgressionStore.set_save_path_for_testing(TEST_SAVE_PATH)
	ResourceManager.reload_persistent_resources()
	ResearchManager.reload_progress()
	ChipManager.reload_progress()
	ShipLoadout.installed_modules.clear()
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 10
	ResearchManager.progress.levels["weapon_damage.dwarf_cannon"] = 10
	ResearchManager.progress.levels["weapon_damage.laser"] = 10
	ResearchManager.progress.levels["weapon_damage.chainsaw"] = 10
	ResourceManager.stored_ore = 100000.0
	ShipLoadout.install_module(1, 1, ENERGY_PATH)
	ShipLoadout.install_module(WEAPON_CELL.x, WEAPON_CELL.y, MACHINE_GUN_PATH)
	ShipLoadout.install_module(KNOCKBACK_CELL.x, KNOCKBACK_CELL.y, KNOCKBACK_PATH)
	ShipLoadout.install_module(REGEN_CELL.x, REGEN_CELL.y, REGENERATION_PATH)
	ShipLoadout.install_module(1, 0, CANNON_PATH)
	ShipLoadout.install_module(1, 2, LASER_PATH)
	ShipLoadout.install_module(2, 0, CHAINSAW_PATH)

	var ship := SHIP_SCENE.instantiate() as Ship
	ship.assembly_mode = false
	add_child(ship)
	await get_tree().process_frame
	var gun := ship.get_module_at(WEAPON_CELL.x, WEAPON_CELL.y) as MachineGun
	var knockback := ship.get_module_at(KNOCKBACK_CELL.x, KNOCKBACK_CELL.y) as KnockbackModule
	var regeneration := ship.get_module_at(REGEN_CELL.x, REGEN_CELL.y) as RegenerationModule

	_test_configuration()
	_test_shield_research(knockback, regeneration)
	_test_weapon_adaptation(gun)
	_test_all_weapon_ranges(ship)
	_test_knockback_adaptation(knockback)
	await _test_regeneration_adaptation(regeneration, ship)
	_test_compatibility_and_persistence()

	ship.queue_free()
	ShipLoadout.installed_modules.clear()
	_remove_test_save()
	await get_tree().process_frame
	_finish()


func _test_configuration() -> void:
	for id in [&"attack_chip", &"attack_speed_chip", &"damage_chip", &"range_chip", &"skill_chip"]:
		_expect(ChipManager.configuration.get_chip(id) != null, "configured chip %s" % id)
		_expect_equal(ChipManager.configuration.get_crafting_cost(id), 500, "%s costs 500 Ore" % id)
	_expect_equal(ChipManager.configuration.chips.size(), 5, "exactly five chip definitions remain available")
	_expect_equal(ChipManager.configuration.get_chip(&"attack_chip").chip_name, "Power Chip", "legacy attack_chip ID displays as Power Chip")


func _test_shield_research(knockback: KnockbackModule, regeneration: RegenerationModule) -> void:
	_expect_equal(ResearchManager.get_upgrade_cost(&"shield_power.knockback_module"), 200, "Knockback research uses normal cost curve")
	ResearchManager.progress.levels["shield_power.knockback_module"] = 2
	ResearchManager.progress.levels["shield_power.regeneration_module"] = 2
	_expect_near(knockback.get_effective_damage(), 30.0, 0.001, "Knockback research adds 20 percent of base damage per level")
	_expect_near(regeneration.get_effective_healing_amount(), 1.2, 0.001, "Regeneration research adds 20 percent of base healing per level")
	for level in [5, 9, 10, 19, 20, 29, 30]:
		ResearchManager.progress.levels["shield_power.knockback_module"] = level
		ResearchManager.progress.levels["shield_power.regeneration_module"] = level
		var expected := int(level / 10)
		_expect_equal(ChipManager.get_module_slot_count(KNOCKBACK_CELL), expected, "Knockback slots at Level %d" % level)
		_expect_equal(ChipManager.get_module_slot_count(REGEN_CELL), expected, "Regeneration slots at Level %d" % level)
	for weapon_id in [&"machine_gun", &"dwarf_cannon", &"laser", &"chainsaw"]:
		var research_id := "weapon_damage.%s" % weapon_id
		for level in [5, 9, 10, 19, 20, 29, 30]:
			ResearchManager.progress.levels[research_id] = level
			_expect_equal(ChipManager.get_unlocked_weapon_slot_count(weapon_id), int(level / 10), "%s slots at Level %d" % [weapon_id, level])
		ResearchManager.progress.levels[research_id] = 10
	ResearchManager.progress.levels["shield_power.knockback_module"] = 20
	ResearchManager.progress.levels["shield_power.regeneration_module"] = 20
	_expect_equal(ChipManager.get_module_slot_count(KNOCKBACK_CELL), 2, "Knockback Level 20 unlocks slot 2")
	_expect_equal(ChipManager.get_module_slot_count(REGEN_CELL), 2, "Regeneration Level 20 unlocks slot 2")
	ResearchManager.progress.levels["shield_power.knockback_module"] = 30
	ResearchManager.progress.levels["shield_power.regeneration_module"] = 30
	_expect_equal(ChipManager.get_module_slot_count(KNOCKBACK_CELL), 3, "Knockback Level 30 unlocks slot 3")
	_expect_equal(ChipManager.get_module_slot_count(REGEN_CELL), 3, "Regeneration Level 30 unlocks slot 3")
	ResearchManager.progress.levels["shield_power.knockback_module"] = 1
	ResearchManager.progress.levels["shield_power.regeneration_module"] = 1


func _test_weapon_adaptation(gun: MachineGun) -> void:
	var attack := _new_chip(&"attack_chip")
	var damage := _new_chip(&"damage_chip")
	var speed := _new_chip(&"attack_speed_chip")
	var range_chip := _new_chip(&"range_chip")
	_expect(ChipManager.equip_module_chip(WEAPON_CELL, 0, attack), "Attack Chip equips to weapon")
	_expect_near(gun.get_damage(), 15.0, 0.001, "weapon Attack Chip adds one after research")
	ChipManager.unequip_module_chip(WEAPON_CELL, 0)
	_expect(ChipManager.equip_module_chip(WEAPON_CELL, 0, damage), "Damage Chip equips to weapon")
	_expect_near(gun.get_damage(), 16.8, 0.001, "weapon Damage Chip applies +20 percent")
	ChipManager.unequip_module_chip(WEAPON_CELL, 0)
	_expect(ChipManager.equip_module_chip(WEAPON_CELL, 0, speed), "Attack Speed Chip equips to weapon")
	_expect_near(gun.get_fire_rate(), 6.0, 0.001, "weapon fire frequency rises 20 percent")
	ChipManager.unequip_module_chip(WEAPON_CELL, 0)
	_expect(ChipManager.equip_module_chip(WEAPON_CELL, 0, range_chip), "Range Chip equips to weapon")
	_expect_near(gun.get_modified_attack_range(gun.attack_range), gun.attack_range * 1.35, 0.001, "weapon range rises 35 percent")


func _test_all_weapon_ranges(ship: Ship) -> void:
	var cases: Array[Dictionary] = [
		{"cell": Vector2i(1, 0), "base": 200.0, "label": "Dwarf Cannon"},
		{"cell": Vector2i(1, 2), "base": 1000.0, "label": "Laser"},
		{"cell": Vector2i(2, 0), "base": 80.0, "label": "Chainsaw"},
	]
	for test_case in cases:
		var cell: Vector2i = test_case["cell"]
		var module := ship.get_module_at(cell.x, cell.y) as WeaponModule
		var chip := _new_chip(&"range_chip")
		_expect(ChipManager.equip_module_chip(cell, 0, chip), "%s accepts Range Chip" % test_case["label"])
		_expect_near(module.get_modified_attack_range(test_case["base"]), test_case["base"] * 1.35, 0.001, "%s uses effective range" % test_case["label"])


func _test_knockback_adaptation(module: KnockbackModule) -> void:
	ResearchManager.progress.levels["shield_power.knockback_module"] = 10
	var attack := _new_chip(&"attack_chip")
	var damage := _new_chip(&"damage_chip")
	var speed := _new_chip(&"attack_speed_chip")
	var range_chip := _new_chip(&"range_chip")
	_expect(ChipManager.equip_module_chip(KNOCKBACK_CELL, 0, attack), "Attack Chip equips to Knockback")
	_expect_near(module.get_effective_damage(), 71.0, 0.001, "Knockback flat damage is +1")
	ChipManager.unequip_module_chip(KNOCKBACK_CELL, 0)
	_expect(ChipManager.equip_module_chip(KNOCKBACK_CELL, 0, damage), "Damage Chip equips to Knockback")
	_expect_near(module.get_effective_damage(), 84.0, 0.001, "Knockback damage rises 20 percent after research")
	ChipManager.unequip_module_chip(KNOCKBACK_CELL, 0)
	_expect(ChipManager.equip_module_chip(KNOCKBACK_CELL, 0, speed), "Attack Speed equips to Knockback")
	_expect_near(module.get_effective_cooldown(), 2.0 / 1.2, 0.001, "Knockback cooldown frequency rises 20 percent")
	ChipManager.unequip_module_chip(KNOCKBACK_CELL, 0)
	_expect(ChipManager.equip_module_chip(KNOCKBACK_CELL, 0, range_chip), "Range Chip equips to Knockback")
	_expect_near(module.get_effective_trigger_range(), 86.4, 0.001, "Knockback trigger range rises 35 percent")
	_expect_near(module.get_effective_splash_radius(), 86.4, 0.001, "Knockback splash radius rises 35 percent")


func _test_regeneration_adaptation(module: RegenerationModule, ship: Ship) -> void:
	_expect_equal(module.max_hp_bonus, 50.0, "Regeneration keeps +50 maximum HP")
	_expect_equal(module.healing_amount, 1.0, "base healing is 1 per pulse")
	_expect_equal(module.healing_interval, 1.0, "base interval is one second")
	_expect_equal(module.healing_radius, 128.0, "base healing radius is 128")
	var friend := FriendlyHealingMock.new()
	add_child(friend)
	friend.global_position = module.global_position + Vector2(30.0, 0.0)
	var far_friend := FriendlyHealingMock.new()
	add_child(far_friend)
	far_friend.global_position = module.global_position + Vector2(400.0, 0.0)
	var full_friend := FriendlyHealingMock.new()
	full_friend.current_hp = full_friend.max_hp
	add_child(full_friend)
	full_friend.global_position = module.global_position + Vector2(20.0, 0.0)
	var destroyed_friend := FriendlyHealingMock.new()
	destroyed_friend.current_hp = 0.0
	add_child(destroyed_friend)
	destroyed_friend.global_position = module.global_position + Vector2(20.0, 0.0)
	var enemy_trap := FriendlyHealingMock.new()
	enemy_trap.add_to_group("enemies")
	add_child(enemy_trap)
	enemy_trap.global_position = module.global_position + Vector2(20.0, 0.0)
	ship.take_damage(10.5)
	var ship_before := ship.current_hp
	_expect_equal(module.apply_healing_pulse(), 2, "pulse visits ship and nearby friendly once each")
	_expect_near(ship.current_hp, ship_before + 1.0, 0.001, "ship receives pulse healing")
	_expect_near(friend.current_hp, 6.5, 0.001, "fractional friendly HP is preserved")
	_expect_equal(friend.heal_calls, 1, "friendly is not healed twice in one pulse")
	_expect_near(far_friend.current_hp, 5.5, 0.001, "out-of-range friendly is not healed")
	_expect_near(full_friend.current_hp, 10.0, 0.001, "full-health friendly remains capped")
	_expect_equal(full_friend.heal_calls, 0, "full-health friendly receives no redundant heal")
	_expect_near(destroyed_friend.current_hp, 0.0, 0.001, "destroyed friendly is not healed")
	_expect_near(enemy_trap.current_hp, 5.5, 0.001, "enemy-group target is never healed")
	ResearchManager.progress.levels["shield_power.regeneration_module"] = 10
	var attack := _new_chip(&"attack_chip")
	_expect(ChipManager.equip_module_chip(REGEN_CELL, 0, attack), "Attack Chip equips to Regeneration")
	_expect_near(module.get_effective_healing_amount(), 3.8, 0.001, "Regeneration flat healing is +1")
	ChipManager.unequip_module_chip(REGEN_CELL, 0)
	var damage := _new_chip(&"damage_chip")
	ChipManager.equip_module_chip(REGEN_CELL, 0, damage)
	_expect_near(module.get_effective_healing_amount(), 3.36, 0.001, "Regeneration healing rises 20 percent after research")
	ChipManager.unequip_module_chip(REGEN_CELL, 0)
	var speed := _new_chip(&"attack_speed_chip")
	ChipManager.equip_module_chip(REGEN_CELL, 0, speed)
	_expect_near(module.get_effective_healing_interval(), 1.0 / 1.2, 0.001, "Regeneration pulse frequency rises 20 percent")
	ChipManager.unequip_module_chip(REGEN_CELL, 0)
	var range_chip := _new_chip(&"range_chip")
	ChipManager.equip_module_chip(REGEN_CELL, 0, range_chip)
	_expect_near(module.get_effective_healing_radius(), 172.8, 0.001, "Regeneration radius rises 35 percent")
	module.set_module_active(false)
	_expect_equal(module.apply_healing_pulse(), 0, "inactive assembly module cannot heal")
	friend.queue_free()
	far_friend.queue_free()
	full_friend.queue_free()
	destroyed_friend.queue_free()
	enemy_trap.queue_free()
	await get_tree().process_frame


func _test_compatibility_and_persistence() -> void:
	var skill := _new_chip(&"skill_chip")
	_expect(not ChipManager.is_chip_compatible_with_module(WEAPON_CELL, &"skill_chip"), "Skill Chip rejects weapon without active skill")
	_expect(not ChipManager.equip_module_chip(KNOCKBACK_CELL, 0, skill), "Skill Chip rejects Knockback")
	_expect(not ChipManager.equip_module_chip(REGEN_CELL, 0, skill), "Skill Chip rejects Regeneration")
	var attack := _new_chip(&"attack_chip")
	ChipManager.unequip_module_chip(REGEN_CELL, 0)
	_expect(ChipManager.equip_module_chip(REGEN_CELL, 0, attack), "shield assignment saves")
	_expect(not ChipManager.is_instance_equipped(skill), "rejected Skill Chip remains idle")
	var stored_key := ChipManager.get_module_slot_key(REGEN_CELL, 0)
	ChipManager.set_equipment_changes_enabled(false)
	_expect(not ChipManager.unequip_module_chip(REGEN_CELL, 0), "battle guard rejects chip removal")
	_expect_equal(ChipManager.get_module_chip(REGEN_CELL, 0), attack, "battle guard preserves equipment")
	ChipManager.set_equipment_changes_enabled(true)
	ResearchManager.progress.levels["shield_power.regeneration_module"] = 20
	ResearchManager.save_progress()
	ChipManager.reload_progress()
	ResearchManager.reload_progress()
	_expect_equal(ChipManager.get_module_chip(REGEN_CELL, 0), attack, "shield chip assignment reloads")
	_expect(String(stored_key).begins_with("module."), "shield assignment uses module-instance key")
	_expect_equal(ResearchManager.get_level(&"shield_power.regeneration_module"), 20, "shield research level persists")
	ResearchManager.progress.levels["shield_power.regeneration_module"] = 5
	ResearchManager.save_progress()
	ChipManager.reload_progress()
	_expect_equal(ChipManager.get_module_slot_count(REGEN_CELL), 0, "Level 5 shield has no unlocked slots")
	_expect(ChipManager.get_module_chip(REGEN_CELL, 0).is_empty(), "legacy chip in a now-locked shield slot is unequipped")
	_expect(not ChipManager.get_chip_instance(attack).is_empty(), "legacy chip remains in inventory")
	_expect(not ChipManager.is_instance_equipped(attack), "legacy chip is available for reuse")


func _new_chip(chip_id: StringName) -> StringName:
	ChipManager.add_owned_chip(chip_id)
	var instances := ChipManager.get_owned_instances(chip_id)
	return instances[instances.size() - 1]


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _finish() -> void:
	if _failures.is_empty():
		print("UNIVERSAL_CHIP_HEALING_TEST: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("UNIVERSAL_CHIP_HEALING_TEST: " + failure)
	print("UNIVERSAL_CHIP_HEALING_TEST: FAIL (%d failures)" % _failures.size())
	get_tree().quit(1)


func _expect(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])


func _expect_near(actual: float, expected: float, tolerance: float, description: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %s ± %s, got %s)" % [description, expected, tolerance, actual])
