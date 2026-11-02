extends Node

const SAVE := preload("res://Tests/TestSave.gd")
const PANEL := preload("res://Scenes/UI/developer_panel.tscn")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("developer_research_unlock")
	var commands := DeveloperCommands.new()
	var starting_ore := ResourceManager.stored_ore
	var first_level := ResearchManager.get_level(&"weapon_damage.machine_gun")
	DeveloperCommands.set_availability_override_for_testing(0)
	_check(not bool(commands.unlock_all_research().get("ok", false)), "disabled Developer Mode rejects research command")
	_check(ResearchManager.get_level(&"weapon_damage.machine_gun") == first_level, "disabled command leaves research unchanged")
	DeveloperCommands.set_availability_override_for_testing(1)
	var result := commands.unlock_all_research()
	_check(bool(result.get("ok", false)), "developer command completes research")
	_check(int((result.get("message_args", []) as Array)[0]) > 0, "command reports completed projects")
	for definition in ResearchManager.configuration.get_all_definitions():
		if definition == null or not definition.enabled or not definition.implemented:
			continue
		var category := ResearchManager.configuration.get_category(definition.category_id)
		if category == null or not category.enabled or not category.implemented:
			continue
		_check(ResearchManager.get_level(definition.research_id) == definition.max_level, "%s reaches max level" % definition.research_id)
	for tree in ResearchManager.configuration.trees:
		if tree == null:
			continue
		for node in tree.nodes:
			if node != null and node.enabled:
				_check(ResearchManager.get_tree_node_state(node.research_id) == &"COMPLETED", "%s tree node is complete" % node.research_id)
	_check(ResourceManager.stored_ore == starting_ore, "research command spends no Ore")
	_check(WeaponUnlockManager.completed_planet_ids.is_empty(), "research command does not forge planet clears")
	_check(not WeaponUnlockManager.is_weapon_unlocked(&"laser"), "research command does not grant locked weapons")
	_check(ArtifactManager.get_owned_artifact_ids().is_empty(), "research command does not grant artifacts")
	ProgressionStore.reload_from_disk()
	ResearchManager.reload_progress()
	_check(ResearchManager.is_research_completed(&"ship_hull_slot_2"), "tree research persists after disk reload")
	_check(ResearchManager.get_weapon_research_level(&"machine_gun") == 30, "weapon research persists after disk reload")
	_check(String(commands.unlock_all_research().get("message", "")).contains("already"), "repeat command is idempotent")
	var panel := PANEL.instantiate() as DeveloperPanel
	add_child(panel)
	_check(panel.unlock_research_button != null and panel.unlock_research_button.text == "Complete All Research", "base developer panel exposes research button")
	panel.queue_free()
	await get_tree().process_frame
	var battle_panel := PANEL.instantiate() as DeveloperPanel
	battle_panel.battle_mode = true
	add_child(battle_panel)
	_check(not battle_panel.unlock_research_button.visible, "battle developer panel hides progression command")
	battle_panel.queue_free()
	DeveloperCommands.set_availability_override_for_testing(-1)
	if failures.is_empty():
		print("DEVELOPER_RESEARCH_UNLOCK_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("DEVELOPER_RESEARCH_UNLOCK_TEST: " + failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
