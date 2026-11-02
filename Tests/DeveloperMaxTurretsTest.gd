extends Node

const SAVE := preload("res://Tests/TestSave.gd")
const PANEL := preload("res://Scenes/UI/developer_panel.tscn")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("developer_max_turrets")
	var commands := DeveloperCommands.new()
	var starting_ore := ResourceManager.stored_ore
	var non_weapon_levels: Dictionary = {}
	var weapon_count := 0
	for definition in ResearchManager.configuration.get_all_definitions():
		if definition == null or not definition.enabled or not definition.implemented:
			continue
		if definition.effect is WeaponDamageResearchEffect and definition.category_id in [&"weapon", &"fusion_weapon"]:
			weapon_count += 1
		else:
			non_weapon_levels[definition.research_id] = ResearchManager.get_level(definition.research_id)
	_check(weapon_count > 0, "weapon research definitions exist")
	DeveloperCommands.set_availability_override_for_testing(0)
	_check(not bool(commands.maximize_all_turrets().get("ok", false)), "disabled Developer Mode rejects command")
	_check(ResearchManager.get_weapon_research_level(&"machine_gun") == 1, "disabled command leaves levels unchanged")
	DeveloperCommands.set_availability_override_for_testing(1)
	var result := commands.maximize_all_turrets()
	_check(bool(result.get("ok", false)), "command succeeds")
	_check(int((result.get("message_args", []) as Array)[0]) == weapon_count, "every turret type is counted")
	for definition in ResearchManager.configuration.get_all_definitions():
		if definition == null or not definition.enabled or not definition.implemented:
			continue
		if definition.effect is WeaponDamageResearchEffect and definition.category_id in [&"weapon", &"fusion_weapon"]:
			_check(ResearchManager.get_level(definition.research_id) == definition.max_level, "%s is maxed" % definition.research_id)
	for research_id in non_weapon_levels:
		_check(ResearchManager.get_level(research_id) == non_weapon_levels[research_id], "%s is unchanged" % research_id)
	_check(ResourceManager.stored_ore == starting_ore, "command spends no Ore")
	_check(not WeaponUnlockManager.is_weapon_unlocked(&"laser"), "command does not unlock Laser")
	_check(not WeaponFusionRegistry.is_unlocked(), "command does not unlock fusion")
	ProgressionStore.reload_from_disk()
	ResearchManager.reload_progress()
	_check(ResearchManager.get_weapon_research_level(&"machine_gun") == 30, "base turret level persists")
	_check(ResearchManager.get_weapon_research_level(&"scatter_machine_gun") == 30, "fusion turret level persists")
	_check(String(commands.maximize_all_turrets().get("message", "")).contains("already"), "repeat command is idempotent")
	var panel := PANEL.instantiate() as DeveloperPanel
	add_child(panel)
	_check(panel.max_turrets_button != null and panel.max_turrets_button.text == "Max All Turrets", "base panel exposes command")
	panel.queue_free()
	await get_tree().process_frame
	var battle_panel := PANEL.instantiate() as DeveloperPanel
	battle_panel.battle_mode = true
	add_child(battle_panel)
	_check(not battle_panel.max_turrets_button.visible, "battle panel hides progression command")
	battle_panel.queue_free()
	DeveloperCommands.set_availability_override_for_testing(-1)
	if failures.is_empty():
		print("DEVELOPER_MAX_TURRETS_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("DEVELOPER_MAX_TURRETS_TEST: " + failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
