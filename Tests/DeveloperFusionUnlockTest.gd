extends Node

const TEST_SAVE := "user://greedminer_developer_fusion_unlock_test.json"

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	ProgressionStore.set_save_path_for_testing(TEST_SAVE)
	ProgressionStore.reload_from_disk()
	WeaponUnlockManager.reload_progress()
	ResearchManager.reload_progress()
	DeveloperCommands.set_availability_override_for_testing(1)

	var commands := DeveloperCommands.new()
	_check(not WeaponFusionRegistry.is_unlocked(), "fusion starts locked")
	var result := commands.unlock_weapon_fusion()
	_check(bool(result.get("ok", false)), "developer command succeeds")
	_check(WeaponFusionRegistry.is_unlocked(), "fusion becomes available")
	_check(not WeaponUnlockManager.has_completed_planet(WeaponFusionRegistry.REQUIRED_PLANET), "Graveyard remains uncleared")
	for recipe in WeaponFusionRegistry.RECIPES:
		var result_id: StringName = recipe["result_id"]
		_check(ResearchManager.get_weapon_research_level(result_id) == 1, "%s stays Level 1" % result_id)
		_check(ResearchManager.is_unlocked(StringName("weapon_damage.%s" % result_id)), "%s research is available" % result_id)

	ProgressionStore.reload_from_disk()
	_check(WeaponFusionRegistry.is_unlocked(), "developer unlock persists")
	DeveloperCommands.set_availability_override_for_testing(0)
	_check(not WeaponFusionRegistry.unlock_for_development(), "central guard blocks direct command")
	DeveloperCommands.set_availability_override_for_testing(1)
	_check(ProgressionStore.reset_all_progress(), "reset saves new-game state")
	_check(not WeaponFusionRegistry.is_unlocked(), "reset removes developer fusion unlock")

	DeveloperCommands.set_availability_override_for_testing(-1)
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	if failures.is_empty():
		print("DEVELOPER_FUSION_UNLOCK_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("DEVELOPER_FUSION_UNLOCK_TEST: " + failure)
		print("DEVELOPER_FUSION_UNLOCK_TEST: FAIL (%d failures)" % failures.size())
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
