extends Node

## Covers the chip-to-artifact socket migration without touching player data.

const SAVE := preload("res://Tests/TestSave.gd")
const GUN := "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _run() -> void:
	SAVE.isolate("artifact_slots_v2")
	ArtifactManager.set_equipment_changes_enabled(true)
	ShipLoadout.install_module(0, 0, GUN)
	var cell := Vector2i(0, 0)
	for artifact_id in [&"goblin_flag", &"goblin_horn", &"demon_prism"]:
		check(ArtifactManager.grant_artifact(artifact_id), "grant %s" % artifact_id)

	check(ArtifactManager.get_module_artifact_slot_count(cell) == 0, "level 1 has zero artifact slots")
	check(not ArtifactManager.equip_module_artifact(cell, &"goblin_flag"), "locked slot rejects equipment")

	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 10
	check(ArtifactManager.get_module_artifact_slot_count(cell) == 1, "level 10 unlocks slot one")
	check(ArtifactManager.equip_module_artifact(cell, &"goblin_flag", 0), "equip first artifact")
	check(not ArtifactManager.equip_module_artifact(cell, &"goblin_horn", 1), "level 10 keeps slot two locked")

	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 20
	check(ArtifactManager.get_module_artifact_slot_count(cell) == 2, "level 20 unlocks slot two")
	check(ArtifactManager.equip_module_artifact(cell, &"goblin_horn", 1), "equip second artifact")

	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 30
	check(ArtifactManager.get_module_artifact_slot_count(cell) == 3, "level 30 unlocks slot three")
	check(ArtifactManager.equip_module_artifact(cell, &"demon_prism", 2), "equip third artifact")
	check(ResearchManager.save_progress(), "save research progress")
	ArtifactManager.reload_progress()
	check(ArtifactManager.get_module_artifacts(cell) == [&"goblin_flag", &"goblin_horn", &"demon_prism"], "three slots persist in order")

	var ship := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	var gun := ship.get_module_at(0, 0) as WeaponModule
	var base_rate := gun.get_fire_rate()
	var base_range := gun.get_modified_attack_range(200.0)
	ArtifactManager.attach_battle_effects(ship)
	check(ship.get_node("MagicArtifactEffects").get_child_count() == 3, "all three module effects attach")
	check(is_equal_approx(gun.get_fire_rate(), base_rate * 1.25), "flag bonus applies")
	check(is_equal_approx(gun.get_modified_attack_range(200.0), base_range * 2.0), "range artifact applies")
	ArtifactManager.record_battle_activity(gun, 2000.0)
	check(is_equal_approx(gun.get_fire_rate(), base_rate * 1.26), "two fire-rate artifacts stack additively")
	ArtifactManager.clear_battle_effects(ship)
	check(is_equal_approx(gun.get_fire_rate(), base_rate), "battle cleanup removes every provider")

	# Version 1 stored a single String per cell. It migrates into slot zero.
	ProgressionStore.set_section(&"magic_artifacts", {
		"owned": {"goblin_flag": true},
		"module_slots": {"0,0": "goblin_flag"},
		"stall_unlocked": true,
	})
	ArtifactManager.reload_progress()
	check(ArtifactManager.get_module_artifact(cell, 0) == &"goblin_flag", "legacy single slot migrates")
	check(ArtifactManager.get_module_artifact(cell, 1).is_empty(), "legacy migration does not duplicate")

	if failures.is_empty():
		print("ARTIFACT_SLOTS_V2_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("ARTIFACT_SLOTS_V2_TEST: " + failure)
		get_tree().quit(1)
