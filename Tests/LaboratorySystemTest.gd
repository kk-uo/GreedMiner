extends Node

## Headless checks for linear (200 x L) costs, milestone slots, independent levels,
## persistence, safe unfinished categories, artifact-slot milestones, and Laboratory UI.

const TEST_SAVE_PATH: String = "user://greedminer_progression_test.json"
const BASE_SCENE: PackedScene = preload("res://Scenes/Base/base_main.tscn")
const MACHINE_GUN_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const DWARF_CANNON_SCENE: PackedScene = preload("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn")

var _failures: Array[String] = []
var _original_research_configuration: ResearchConfiguration


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_original_research_configuration = ResearchManager.configuration
	_remove_test_save()
	ProgressionStore.set_save_path_for_testing(TEST_SAVE_PATH)
	ResourceManager.reload_persistent_resources()
	ResearchManager.reload_progress()

	_test_categories_and_costs()
	_test_weapon_damage_and_purchases()
	_test_unimplemented_category_safety()
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
	_expect_false(ResearchManager.configuration.get_category(&"chips").enabled, "retired chip category is disabled")

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
			_expect_equal(breakthrough.weapon_chip_slots_unlocked, 1, "breakthrough unlocks one artifact slot")


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
	_expect_equal(ResearchManager.get_weapon_artifact_slot_count(&"machine_gun"), 1, "Machine Gun breakthrough unlocks one type-level artifact slot")
	_expect_equal(ResearchManager.get_weapon_artifact_slot_count(&"dwarf_cannon"), 0, "Cannon artifact slot remains independently locked")
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


func _test_laboratory_ui() -> void:
	ResearchManager.configuration = _original_research_configuration
	ResearchManager.reload_progress()
	var base := BASE_SCENE.instantiate()
	add_child(base)
	await get_tree().process_frame
	var panel := base.get_node("BaseUI/UIRoot/LaboratoryPanel") as LaboratoryPanel
	panel.open_panel()
	_expect_equal(panel.category_buttons.get_child_count(), 6, "Laboratory hides the retired chip category")
	WeaponUnlockManager.unlocked_weapon_ids["machine_gun"] = true
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 9
	panel._select_category(&"weapon")
	var machine_card = panel._cards.get(&"weapon_damage.machine_gun")
	_expect_true(machine_card != null, "Machine Gun research card remains available")
	_expect_true(_tree_contains_text(machine_card, "UNLOCKS 1 WEAPON ARTIFACT SLOT"), "Level 9 UI shows artifact-slot reward")
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 10
	panel._refresh_category()
	machine_card = panel._cards.get(&"weapon_damage.machine_gun")
	_expect_true(_tree_contains_text(machine_card, "1 / 3 ARTIFACT SLOTS"), "Level 10 UI displays one of three unlocked artifact slots")

	# Shield modules use the same 10/20/30 artifact-slot milestones.
	WeaponUnlockManager.unlocked_weapon_ids["knockback_module"] = true
	WeaponUnlockManager.unlocked_weapon_ids["regeneration_module"] = true
	ResearchManager.progress.levels["shield_power.regeneration_module"] = 5
	panel._select_category(&"shield")
	var regeneration_card = panel._cards.get(&"shield_power.regeneration_module")
	_expect_true(_tree_contains_text(regeneration_card, "0 / 3 ARTIFACT SLOTS"), "Level 5 Regeneration UI shows no unlocked slots")
	ResearchManager.progress.levels["shield_power.regeneration_module"] = 10
	panel._refresh_category()
	regeneration_card = panel._cards.get(&"shield_power.regeneration_module")
	_expect_true(_tree_contains_text(regeneration_card, "1 / 3 ARTIFACT SLOTS"), "Level 10 Regeneration UI shows one unlocked slot")
	WeaponUnlockManager.unlocked_weapon_ids.erase("machine_gun")
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
	_remove_test_save()
	# Keep the isolated path active until this test process exits. Switching back
	# can overwrite the player's real progression during shutdown or reloads.
	ResourceManager.reload_persistent_resources()
	ResearchManager.reload_progress()


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
