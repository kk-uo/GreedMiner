extends Node

## Headless checks for linear (200 x L) costs, milestone slots, independent levels,
## persistence, safe unfinished categories, chip interfaces, and Laboratory UI.

const TEST_SAVE_PATH: String = "user://greedminer_progression_test.json"
const BASE_SCENE: PackedScene = preload("res://Scenes/Base/base_main.tscn")
const MACHINE_GUN_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const DWARF_CANNON_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn")

var _failures: Array[String] = []
var _original_research_configuration: ResearchConfiguration
var _original_chip_configuration: ChipConfiguration


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_original_research_configuration = ResearchManager.configuration
	_original_chip_configuration = ChipManager.configuration
	_remove_test_save()
	ProgressionStore.set_save_path_for_testing(TEST_SAVE_PATH)
	ResourceManager.reload_persistent_resources()
	ResearchManager.reload_progress()
	ChipManager.reload_progress()

	_test_categories_and_costs()
	_test_weapon_damage_and_purchases()
	_test_unimplemented_category_safety()
	_test_chip_framework()
	await _test_laboratory_ui()
	_cleanup()

	if _failures.is_empty():
		print("LABORATORY_SYSTEM_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("LABORATORY_SYSTEM_TEST: " + failure)
		print("LABORATORY_SYSTEM_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _test_categories_and_costs() -> void:
	var expected_ids := [&"weapon", &"mining", &"shield", &"energy", &"ship", &"weapon_skills", &"chips"]
	_expect_equal(ResearchManager.get_categories().size(), 7, "seven research categories exist")
	for category_id in expected_ids:
		_expect_true(ResearchManager.configuration.get_category(category_id) != null, "category exists: %s" % category_id)

	var expected_normal_costs := [200, 400, 600, 800, 1000, 1200, 1400, 1600]
	var definition := ResearchManager.get_definition(&"weapon_damage.machine_gun")
	_expect_true(definition != null, "Machine Gun research definition loads")
	if definition != null:
		_expect_equal(definition.max_level, 30, "weapon max level")
		var effect := definition.effect as WeaponDamageResearchEffect
		_expect_true(effect != null, "weapon damage effect is configured")
		if effect != null:
			_expect_equal(effect.damage_bonus_per_level, 0.2, "damage bonus coefficient")
		for index in range(expected_normal_costs.size()):
			_expect_equal(definition.cost_configuration.get_upgrade_cost(index + 1), expected_normal_costs[index], "normal cost level %d" % (index + 1))
		var breakthrough := definition.get_milestone(10)
		_expect_true(breakthrough != null, "Level 10 breakthrough is configured")
		if breakthrough != null:
			_expect_equal(breakthrough.upgrade_cost_override, -1, "Level 10 uses the normal linear cost")
			_expect_equal(breakthrough.weapon_chip_slots_unlocked, 1, "breakthrough unlocks one chip slot")


func _test_weapon_damage_and_purchases() -> void:
	var machine_gun := MACHINE_GUN_SCENE.instantiate() as MachineGun
	var cannon := DWARF_CANNON_SCENE.instantiate() as DwarfCannon
	_expect_equal(machine_gun.basic_damage, 5.0, "Machine Gun base damage remains 5")
	_expect_equal(machine_gun.get_damage(), 5.0, "Machine Gun level 1 damage")
	_expect_equal(machine_gun.attack_interval, 0.2, "Machine Gun attack interval unchanged")
	_expect_equal(machine_gun.attack_range, 400.0, "Machine Gun range unchanged")
	_expect_equal(cannon.get_damage(), 30.0, "Cannon begins at independent level 1")

	ResourceManager.stored_ore = 9000.0
	var total_spent := 0
	for target_level in range(2, 11):
		var cost := ResearchManager.get_upgrade_cost(&"weapon_damage.machine_gun")
		if target_level == 10:
			_expect_equal(cost, 1800, "Level 9 to 10 costs 200 x 9")
			ResourceManager.stored_ore = 1799.0
			_expect_false(ResearchManager.purchase_research(&"weapon_damage.machine_gun"), "Level 10 upgrade rejects insufficient ore")
			_expect_equal(ResearchManager.get_level(&"weapon_damage.machine_gun"), 9, "failed Level 10 upgrade keeps Level 9")
			_expect_equal(ResourceManager.stored_ore, 1799.0, "failed Level 10 upgrade spends no ore")
			ResourceManager.add_stored_ore(1.0)
		total_spent += cost
		_expect_true(ResearchManager.purchase_research(&"weapon_damage.machine_gun"), "purchase Machine Gun level %d" % target_level)
		_expect_equal(ResearchManager.get_level(&"weapon_damage.machine_gun"), target_level, "Machine Gun reaches level %d" % target_level)
		_expect_equal(machine_gun.get_damage(), 5.0 + float(target_level - 1), "Machine Gun additive damage at level %d" % target_level)

	_expect_equal(total_spent, 9000, "total linear cost (200 x L) to reach Level 10")
	_expect_equal(ResourceManager.stored_ore, 0.0, "ore deducted exactly once")
	_expect_equal(cannon.get_damage(), 30.0, "Cannon research remains independent")
	_expect_equal(ResearchManager.get_weapon_chip_slot_count(&"machine_gun"), 1, "Machine Gun breakthrough unlocks one type-level chip slot")
	_expect_equal(ResearchManager.get_weapon_chip_slot_count(&"dwarf_cannon"), 0, "Cannon chip slot remains independently locked")
	_expect_true(ChipManager.is_weapon_chip_slot_unlocked(&"machine_gun"), "configured Machine Gun slot derives unlocked state")
	_expect_false(ChipManager.is_weapon_chip_slot_unlocked(&"dwarf_cannon"), "configured Cannon slot remains locked")
	var new_machine_gun := MACHINE_GUN_SCENE.instantiate() as MachineGun
	_expect_equal(new_machine_gun.get_damage(), 14.0, "new Machine Gun inherits global Level 10 damage")
	new_machine_gun.free()
	var ore_before_unaffordable_attempt := ResourceManager.stored_ore
	_expect_false(ResearchManager.purchase_research(&"weapon_damage.machine_gun"), "unaffordable Level 11 purchase is blocked")
	_expect_equal(ResourceManager.stored_ore, ore_before_unaffordable_attempt, "blocked purchase spends no ore")

	ProgressionStore.reload_from_disk()
	ResearchManager.reload_progress()
	ResourceManager.reload_persistent_resources()
	_expect_equal(ResearchManager.get_level(&"weapon_damage.machine_gun"), 10, "research persists after disk reload")
	_expect_equal(ResourceManager.stored_ore, 0.0, "spent ore persists after disk reload")
	machine_gun.free()
	cannon.free()


func _test_unimplemented_category_safety() -> void:
	var custom_configuration := _original_research_configuration.duplicate(true) as ResearchConfiguration
	var placeholder := ResearchDefinition.new()
	placeholder.research_id = &"mining.placeholder"
	placeholder.category_id = &"mining"
	placeholder.display_name = "Mining Placeholder"
	placeholder.max_level = 10
	placeholder.cost_configuration = ResearchCostConfig.new()
	placeholder.unlocked_by_default = true
	placeholder.enabled = true
	placeholder.implemented = false
	custom_configuration.definitions.append(placeholder)
	ResearchManager.configuration = custom_configuration
	ResearchManager.reload_progress()
	ResourceManager.stored_ore = 1000.0
	_expect_false(ResearchManager.purchase_research(placeholder.research_id), "unfinished research cannot be purchased")
	_expect_equal(ResourceManager.stored_ore, 1000.0, "unfinished research spends no ore")
	ResearchManager.configuration = _original_research_configuration
	ResearchManager.reload_progress()


func _test_chip_framework() -> void:
	var config := ChipConfiguration.new()
	var chip := ChipDefinition.new()
	chip.chip_id = &"test_chip"
	chip.chip_name = "Test Chip"
	chip.category_id = &"test"
	config.chips = [chip]
	var slot := ChipSlotDefinition.new()
	slot.slot_id = &"weapon.machine_gun"
	slot.display_name = "Machine Gun Chip Slot"
	slot.scope_id = "weapon_type"
	slot.target_id = &"machine_gun"
	var locked_slot := ChipSlotDefinition.new()
	locked_slot.slot_id = &"weapon.dwarf_cannon"
	locked_slot.display_name = "Dwarf Cannon Chip Slot"
	locked_slot.scope_id = "weapon_type"
	locked_slot.target_id = &"dwarf_cannon"
	config.slots = [slot, locked_slot]
	ChipManager.configuration = config
	ChipManager.reload_progress()
	ShipLoadout.load_saved()
	ShipLoadout.install_module(0, 0, MACHINE_GUN_SCENE.resource_path)
	ShipLoadout.install_module(0, 1, DWARF_CANNON_SCENE.resource_path)
	_expect_true(ChipManager.add_owned_chip(&"test_chip"), "configured chip can be owned")
	var instance_id := ChipManager.get_owned_instances(&"test_chip")[0]
	_expect_false(ChipManager.equip_turret_chip(Vector2i(2, 2), 0, instance_id), "empty cell fails safely")
	_expect_false(ChipManager.equip_turret_chip(Vector2i(0, 1), 0, instance_id), "below-breakthrough weapon socket rejects equipment")
	_expect_true(ChipManager.is_weapon_chip_slot_unlocked(&"machine_gun"), "Level 10 weapon slot reports unlocked")
	_expect_true(ChipManager.equip_turret_chip(Vector2i(0, 0), 0, instance_id), "unlocked compatible turret socket equips chip")
	_expect_equal(ChipManager.get_turret_chip(Vector2i(0, 0), 0), instance_id, "turret chip assignment is readable")
	_expect_true(ChipManager.get_stat_modifiers({"cell": Vector2i(0, 0), "stat_id": &"damage"}).is_empty(), "chip without effects is inert")
	ProgressionStore.reload_from_disk()
	ChipManager.reload_progress()
	_expect_equal(ChipManager.get_turret_chip(Vector2i(0, 0), 0), instance_id, "turret chip assignment persists")
	ShipLoadout.load_saved()


func _test_laboratory_ui() -> void:
	ResearchManager.configuration = _original_research_configuration
	ResearchManager.reload_progress()
	ChipManager.configuration = _original_chip_configuration
	ChipManager.reload_progress()
	var base := BASE_SCENE.instantiate()
	add_child(base)
	await get_tree().process_frame
	var panel := base.get_node("BaseUI/UIRoot/LaboratoryPanel") as LaboratoryPanel
	panel.open_panel()
	_expect_equal(panel.category_buttons.get_child_count(), 7, "Laboratory exposes seven category buttons")
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 9
	ResourceManager.stored_ore = 1799.0
	panel._select_category(&"chips")
	_expect_true(_tree_contains_text(panel, "CHIP LABORATORY LOCKED"), "Chip Laboratory UI is locked before Level 10")
	panel._select_category(&"weapon")
	_expect_true(panel.upgrade_button.text.contains("UPGRADE TO LEVEL 10"), "Level 9 UI identifies breakthrough")
	_expect_true(panel.upgrade_button.text.contains("1,800 ORE"), "Level 9 UI shows the 200 x L upgrade cost")
	_expect_true(panel.upgrade_button.disabled, "unaffordable Level 10 button is disabled")
	_expect_true(_tree_contains_text(panel, "UNLOCKS 1 WEAPON CHIP SLOT"), "Level 9 UI shows chip-slot reward")
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 10
	panel._select_category(&"weapon")
	_expect_true(panel.upgrade_button.text.contains("2,000"), "Level 10 UI offers the 200 x L Level 11 cost")
	_expect_true(_tree_contains_text(panel, "1 / 3 CHIP SLOTS"), "Level 10 UI displays one of three unlocked slots")
	panel._select_category(&"chips")
	_expect_true(_tree_contains_text(panel, "BLUEPRINTS"), "Level 10 unlocks the Chip Laboratory UI")
	_expect_true(_tree_contains_text_fragment(panel, "POWER CHIP"), "Chip Laboratory shows the selected blueprint")
	_expect_true(panel.craft_button != null and panel.craft_button.text.contains("500"), "blueprint offers CRAFT for 500 Ore")
	_expect_false(_tree_contains_text_fragment(panel, "EQUIP"), "Chip Laboratory no longer installs chips")
	var owned_before := ChipManager.get_owned_count(&"attack_chip")
	ResourceManager.stored_ore = 600.0
	panel._refresh_category()
	panel.craft_button.pressed.emit()
	_expect_equal(ChipManager.get_owned_count(&"attack_chip"), owned_before + 1, "CRAFT button crafts one chip")
	ResourceManager.stored_ore = 2999.0
	panel._select_category(&"mining")
	_expect_true(panel._research_tree_view != null, "Mining category exposes its research tree")
	_expect_true(_tree_node_shows(panel, &"mining_install_slot_unlock", "Mining Module Expansion I"), "Mining expansion appears in tree")
	panel._select_category(&"energy")
	_expect_true(_tree_node_shows(panel, &"energy_install_slot_unlock", "Energy Module Expansion I"), "Energy expansion appears in tree")
	panel._select_category(&"ship")
	_expect_true(_tree_node_shows(panel, &"ship_max_hp_1", "Ship HP +50"), "Ship root appears in tree")
	_expect_true(_tree_node_shows(panel, &"ship_auto_regeneration_1", "Auto Regeneration I"), "Ship regeneration branch appears")
	_expect_true(_tree_node_shows(panel, &"ship_magic_slot_1", "Magic Item Slot I"), "Ship magic slot branch appears")

	# Shield research follows the permanent module unlock state. Locked modules
	# must not expose a purchasable research button even when Ore is available.
	panel._select_category(&"shield")
	var knockback_card = panel._cards.get(&"shield_power.knockback_module")
	var regeneration_card = panel._cards.get(&"shield_power.regeneration_module")
	_expect_true(knockback_card != null and knockback_card.button.disabled, "locked Knockback research card is disabled")
	_expect_true(knockback_card != null and knockback_card.button.text == "LOCKED", "locked Knockback research card says LOCKED")
	_expect_true(regeneration_card != null and regeneration_card.button.disabled, "locked Regeneration research card is disabled")
	_expect_true(regeneration_card != null and regeneration_card.button.text == "LOCKED", "locked Regeneration research card says LOCKED")

	# Unlocking one module opens only its own research project.
	WeaponUnlockManager.unlocked_weapon_ids["knockback_module"] = true
	panel._refresh_category()
	knockback_card = panel._cards.get(&"shield_power.knockback_module")
	regeneration_card = panel._cards.get(&"shield_power.regeneration_module")
	_expect_true(knockback_card != null and not knockback_card.button.disabled, "unlocked Knockback research becomes purchasable")
	_expect_true(regeneration_card != null and regeneration_card.button.disabled, "Regeneration research remains independently locked")
	WeaponUnlockManager.unlocked_weapon_ids["regeneration_module"] = true
	ResearchManager.progress.levels["shield_power.regeneration_module"] = 5
	panel._refresh_category()
	regeneration_card = panel._cards.get(&"shield_power.regeneration_module")
	_expect_true(_tree_contains_text(regeneration_card, "0 / 3 CHIP SLOTS"), "Level 5 Regeneration UI shows no unlocked slots")
	ResearchManager.progress.levels["shield_power.regeneration_module"] = 10
	panel._refresh_category()
	regeneration_card = panel._cards.get(&"shield_power.regeneration_module")
	_expect_true(_tree_contains_text(regeneration_card, "1 / 3 CHIP SLOTS"), "Level 10 Regeneration UI shows one unlocked slot")
	WeaponUnlockManager.unlocked_weapon_ids.erase("regeneration_module")
	WeaponUnlockManager.unlocked_weapon_ids.erase("knockback_module")
	base.queue_free()
	await get_tree().process_frame


func _tree_contains_text(root: Node, expected_text: String) -> bool:
	if root is Label and (root as Label).text == expected_text:
		return true
	for child in root.get_children():
		if _tree_contains_text(child, expected_text):
			return true
	return false


## The research tree shows one icon per node; selecting a node puts its name
## in the bottom strip.
func _tree_node_shows(panel: Node, research_id: StringName, expected_text: String) -> bool:
	var view: ResearchTreeView = panel._research_tree_view
	if view == null or not view._nodes.has(research_id):
		return false
	view.select_node(research_id)
	return _tree_contains_text(view, expected_text)


func _tree_contains_text_fragment(root: Node, expected_text: String) -> bool:
	if root is Label and (root as Label).text.contains(expected_text):
		return true
	for child in root.get_children():
		if _tree_contains_text_fragment(child, expected_text):
			return true
	return false


func _cleanup() -> void:
	ResearchManager.configuration = _original_research_configuration
	ChipManager.configuration = _original_chip_configuration
	_remove_test_save()
	# Keep the isolated path active until this test process exits. Switching back
	# can overwrite the player's real progression during shutdown or reloads.
	ResourceManager.reload_persistent_resources()
	ResearchManager.reload_progress()
	ChipManager.reload_progress()


func _remove_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	if value:
		_failures.append(description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
