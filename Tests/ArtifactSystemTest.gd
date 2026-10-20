extends Node

## Headless integration coverage for permanent ownership/equipment, Rock Titan
## first-kill grants, base access, save migration and Stone Heart combat rules.

const TEST_SAVE_PATH := "user://greedminer_artifact_system_test.json"
const BASE_SCENE: PackedScene = preload("res://Scenes/Base/base_main.tscn")
const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const TITAN_SCENE: PackedScene = preload("res://Scenes/Enemies/rock_titan.tscn")
const LITTLE_ROCK_SCENE: PackedScene = preload("res://Scenes/Enemies/little_rock.tscn")
const ELITE_SCENE: PackedScene = preload("res://Scenes/Enemies/elite_goblin.tscn")

var _failures: Array[String] = []
var _grant_count: int = 0
var _shatter_count: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_remove_test_save()
	ProgressionStore.set_save_path_for_testing(TEST_SAVE_PATH)
	ProgressionStore.reset_all_progress()
	ShipLoadout.load_saved()
	ResearchManager.reload_progress()
	ArtifactManager.reload_progress()
	ArtifactManager.set_equipment_changes_enabled(true)

	await _test_new_game_and_locked_stall()
	_test_old_save_compatibility()
	await _test_rock_titan_first_kill()
	_test_equipment_and_persistence()
	_test_invalid_save_assignments()
	await _test_unlocked_stall_and_guide()
	await _test_stone_heart_combat()
	_cleanup()

	if _failures.is_empty():
		print("ARTIFACT_SYSTEM_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("ARTIFACT_SYSTEM_TEST: " + failure)
		print("ARTIFACT_SYSTEM_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _test_new_game_and_locked_stall() -> void:
	_expect_false(ArtifactManager.owns_artifact(&"stone_heart"), "new player does not own Stone Heart")
	_expect_false(ArtifactManager.is_stall_unlocked(), "Magic Stall starts locked")
	_expect_equal(ArtifactManager.get_owned_artifact_ids().size(), 0, "new collection is empty")
	var base := BASE_SCENE.instantiate() as Node2D
	add_child(base)
	await get_tree().process_frame
	_expect_true(base.magic_stall_panel != null, "base builds the functional Magic Stall panel")
	base.open_magic_stall()
	_expect_equal(base.get_view_state_name(), &"OVERVIEW", "locked stall cannot open")
	base.queue_free()
	await get_tree().process_frame


func _test_old_save_compatibility() -> void:
	ProgressionStore.set_section(&"resources", {"stored_ore": 77.0})
	ArtifactManager.reload_progress()
	_expect_false(ArtifactManager.owns_artifact(&"stone_heart"), "save without artifact section loads empty defaults")
	_expect_equal(float(ProgressionStore.get_section(&"resources").get("stored_ore", 0.0)), 77.0, "artifact load preserves unrelated save sections")
	ProgressionStore.set_section(&"magic_artifacts", {"owned": {}, "ship_slots": ["stone_heart"]})
	ArtifactManager.reload_progress()
	_expect_true(ArtifactManager.get_ship_artifact(0).is_empty(), "unowned artifact cannot be restored as equipment")
	ProgressionStore.set_section(&"magic_artifacts", {})
	ArtifactManager.reload_progress()


func _test_rock_titan_first_kill() -> void:
	if not ArtifactManager.artifact_granted.is_connected(_on_artifact_granted):
		ArtifactManager.artifact_granted.connect(_on_artifact_granted)
	var host := Node2D.new()
	add_child(host)
	var titan := TITAN_SCENE.instantiate() as RockTitan
	titan.split_enemy_scene = null
	host.add_child(titan)
	await get_tree().process_frame
	titan.take_damage(100000.0)
	await get_tree().process_frame
	_expect_true(ArtifactManager.owns_artifact(&"stone_heart"), "first Rock Titan defeat grants Stone Heart")
	_expect_equal(_grant_count, 1, "first artifact emits one acquisition event")
	_expect_true(ArtifactManager.is_stall_unlocked(), "first artifact permanently unlocks Magic Stall")
	_expect_true(ArtifactManager.tutorial_pending, "first artifact queues the base guide")
	_expect_false(ArtifactManager.is_artifact_equipped(&"stone_heart"), "boss reward enters collection without auto-equipping")

	var duplicate := TITAN_SCENE.instantiate() as RockTitan
	duplicate.split_enemy_scene = null
	host.add_child(duplicate)
	await get_tree().process_frame
	duplicate.take_damage(100000.0)
	await get_tree().process_frame
	_expect_equal(_grant_count, 1, "repeat Rock Titan defeat grants no duplicate")
	_expect_equal(ArtifactManager.get_owned_artifact_ids().size(), 1, "collection remains globally unique")
	host.queue_free()
	await get_tree().process_frame


func _test_equipment_and_persistence() -> void:
	_expect_false(ArtifactManager.equip_ship_artifact(0, &"stone_heart"), "ship artifact slot requires research")
	ResearchManager.progress.levels["ship_magic_slot_1"] = 1
	ResearchManager.save_progress()
	_expect_true(ArtifactManager.equip_ship_artifact(0, &"stone_heart"), "Stone Heart equips to ship slot 1")
	_expect_equal(ArtifactManager.get_ship_artifact(0), &"stone_heart", "ship slot 1 stores Stone Heart")
	_expect_false(ArtifactManager.equip_ship_artifact(2, &"stone_heart"), "future ship slot remains locked")
	var equipped_count := 0
	for artifact_id in ArtifactManager.ship_slots:
		if artifact_id == &"stone_heart":
			equipped_count += 1
	_expect_equal(equipped_count, 1, "same artifact cannot occupy two slots")
	_expect_false(ArtifactManager.equip_module_artifact(Vector2i(1, 1), &"stone_heart"), "ship-only Stone Heart is rejected by module slot")

	ArtifactManager.set_equipment_changes_enabled(false)
	_expect_false(ArtifactManager.unequip_ship_artifact(0), "battle equipment guard blocks unequip")
	_expect_equal(ArtifactManager.get_ship_artifact(0), &"stone_heart", "blocked battle change preserves equipment")
	ArtifactManager.set_equipment_changes_enabled(true)
	ArtifactManager.reload_progress()
	_expect_true(ArtifactManager.owns_artifact(&"stone_heart"), "ownership survives save reload")
	_expect_equal(ArtifactManager.get_ship_artifact(0), &"stone_heart", "ship equipment survives save reload")
	_expect_true(ArtifactManager.is_stall_unlocked(), "stall unlock survives save reload")
	var legacy := ProgressionStore.get_section(&"magic_artifacts")
	legacy["ship_slots"] = ["", "", "stone_heart"]
	ProgressionStore.set_section(&"magic_artifacts", legacy)
	ArtifactManager.reload_progress()
	_expect_equal(ArtifactManager.get_ship_artifact(2), &"stone_heart", "legacy equipped third slot is preserved")
	_expect_true(ArtifactManager.is_ship_slot_unlocked(2), "legacy occupied slot remains accessible")
	_expect_true(ArtifactManager.equip_ship_artifact(0, &"stone_heart"), "legacy artifact can move to researched slot")
	_expect_true(ArtifactManager.get_ship_artifact(2).is_empty(), "moving artifact clears legacy slot")


func _test_invalid_save_assignments() -> void:
	ProgressionStore.set_section(&"magic_artifacts", {
		"owned": {"stone_heart": true},
		"ship_slots": ["stone_heart", "stone_heart", "stone_heart"],
		"module_slots": {"9,9": "stone_heart", "1,1": "stone_heart"},
		"tutorial_pending": true,
		"first_artifact_id": "stone_heart",
	})
	ArtifactManager.reload_progress()
	_expect_equal(ArtifactManager.get_ship_artifact(0), &"stone_heart", "valid first assignment survives sanitization")
	_expect_true(ArtifactManager.get_ship_artifact(1).is_empty(), "duplicate ship assignment is removed")
	_expect_true(ArtifactManager.get_ship_artifact(2).is_empty(), "additional duplicate assignment is removed")
	_expect_true(ArtifactManager.module_slots.is_empty(), "invalid or incompatible module assignments are removed")
	var stored := ProgressionStore.get_section(&"magic_artifacts")
	_expect_equal(stored.get("ship_slots", []), ["stone_heart", "", ""], "sanitized assignments are persisted")
	_expect_true((stored.get("module_slots", {}) as Dictionary).is_empty(), "sanitized module assignments are persisted")


func _test_unlocked_stall_and_guide() -> void:
	var base := BASE_SCENE.instantiate() as Node2D
	add_child(base)
	await get_tree().process_frame
	_expect_true(base.artifact_tutorial_hint != null, "pending first-artifact guide appears after returning to base")
	base.open_magic_stall()
	_expect_equal(base.get_view_state_name(), &"MAGIC_STALL", "unlocked Magic Stall opens")
	_expect_true(base.magic_stall_panel.visible, "artifact collection panel is visible")
	_expect_equal(base.magic_stall_panel.selected_artifact_id, &"stone_heart", "first artifact is automatically selected")
	_expect_true(ArtifactManager.tutorial_completed, "visiting the Magic Stall completes the first-artifact guide")
	_expect_equal(ArtifactManager.get_acquisition_index(&"stone_heart"), 0, "acquisition order is recorded")
	_expect_equal(ArtifactManager.get_definition(&"stone_heart").rarity, "Epic", "Stone Heart is epic")
	base.magic_stall_panel.set_tab(MagicStallPanel.Tab.COMPENDIUM)
	_expect_true(base.magic_stall_panel._compendium_rows.get_child_count() > 0, "compendium lists artifacts by planet")
	base.magic_stall_panel.set_tab(MagicStallPanel.Tab.COLLECTION)
	_expect_equal(base.magic_stall_panel._grid.get_child_count(), 1, "collection shows every owned artifact")
	ArtifactManager.complete_tutorial()
	ArtifactManager.reload_progress()
	_expect_true(ArtifactManager.tutorial_completed, "completed or skipped guide persists")
	_expect_false(ArtifactManager.tutorial_pending, "completed guide never remains pending")
	base.queue_free()
	await get_tree().process_frame


func _test_stone_heart_combat() -> void:
	ArtifactManager.set_equipment_changes_enabled(true)
	ArtifactManager.equip_ship_artifact(0, &"stone_heart")
	ResourceManager.set_current_expedition_planet(&"rocky_planet")
	var battle := BATTLE_SCENE.instantiate() as Node2D
	var wave_manager := battle.get_node("WaveManager") as WaveManager
	wave_manager.auto_start = false
	add_child(battle)
	await get_tree().process_frame
	await get_tree().physics_frame
	var ship := battle.get_node("Ship") as Ship
	var effect := ship.get_node_or_null("MagicArtifactEffects/StoneHeart") as StoneHeartEffect
	_expect_true(effect != null, "equipped Stone Heart creates one battle runtime effect")
	if effect == null:
		battle.queue_free()
		return
	_expect_near(effect.current_armor, 30.0, "battle starts with 30 Rock Armor")
	_expect_near(effect.regeneration_delay, 30.0, "configured armor regeneration delay is 30 seconds")
	var initial_hull := ship.current_hp
	ship.take_damage(20.0)
	_expect_near(effect.current_armor, 10.0, "partial hit removes only Rock Armor")
	_expect_near(ship.current_hp, initial_hull, "partial armor damage does not harm hull")
	await get_tree().create_timer(0.08).timeout
	_expect_near(effect.current_armor, 10.0, "partially damaged armor does not regenerate")

	var enemies := battle.get_node("Enemies") as Node2D
	var ship_center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	var common := _spawn_durable_enemy(LITTLE_ROCK_SCENE, enemies, ship_center + Vector2(90.0, 0.0), 100.0)
	var elite := _spawn_durable_enemy(ELITE_SCENE, enemies, ship_center + Vector2(-90.0, 0.0), 200.0)
	var boss := _spawn_durable_enemy(TITAN_SCENE, enemies, ship_center + Vector2(180.0, 0.0), 2000.0)
	(boss as RockTitan).split_enemy_scene = null
	await get_tree().physics_frame
	await get_tree().physics_frame
	var common_before := common.global_position
	var elite_before := elite.global_position
	var boss_before := boss.global_position
	_shatter_count = 0
	effect.armor_shattered.connect(_on_armor_shattered)
	effect.regeneration_delay = 0.12
	ship.take_damage(25.0)
	_expect_near(effect.current_armor, 0.0, "breaking hit consumes remaining armor")
	_expect_near(ship.current_hp, initial_hull - 15.0, "overflow damage reaches hull")
	_expect_equal(_shatter_count, 1, "one break emits exactly one shatter")
	_expect_near(common.get_current_health(), 75.0, "common enemy takes one 25-damage shockwave hit")
	_expect_near(elite.get_current_health(), 175.0, "elite enemy takes one 25-damage shockwave hit")
	_expect_near(boss.get_current_health(), 1975.0, "Boss takes one 25-damage shockwave hit")
	_expect_true(common.global_position.distance_to(common_before) >= 90.0, "common enemy is knocked back about 100 px")
	_expect_true(elite.global_position.distance_to(elite_before) >= 90.0, "elite enemy is knocked back about 100 px")
	_expect_near(boss.global_position.distance_to(boss_before), 0.0, "Boss is completely immune to knockback")
	var countdown_before := effect.get_regeneration_remaining()
	ship.take_damage(5.0)
	_expect_near(ship.current_hp, initial_hull - 20.0, "damage during recharge goes directly to hull")
	_expect_true(effect.get_regeneration_remaining() <= countdown_before, "later damage does not reset regeneration countdown")
	_expect_equal(_shatter_count, 1, "damage while broken cannot retrigger shockwave")
	await get_tree().create_timer(0.16).timeout
	_expect_near(effect.current_armor, 30.0, "broken armor fully restores after countdown")
	ship.take_damage(30.0)
	_expect_equal(_shatter_count, 2, "restored armor can shatter and trigger again")

	ArtifactManager.clear_battle_effects(ship)
	await get_tree().process_frame
	var hull_before_cleanup_hit := ship.current_hp
	ship.take_damage(5.0)
	_expect_near(ship.current_hp, hull_before_cleanup_hit - 5.0, "battle cleanup removes Stone Heart interception immediately")
	battle.queue_free()
	await get_tree().process_frame
	ArtifactManager.set_equipment_changes_enabled(true)
	_expect_true(ArtifactManager.unequip_ship_artifact(0), "Stone Heart can be unequipped at base")
	var unprotected_battle := BATTLE_SCENE.instantiate() as Node2D
	(unprotected_battle.get_node("WaveManager") as WaveManager).auto_start = false
	add_child(unprotected_battle)
	await get_tree().process_frame
	var unprotected_ship := unprotected_battle.get_node("Ship") as Ship
	_expect_true(unprotected_ship.get_node_or_null("MagicArtifactEffects/StoneHeart") == null, "unequipped Stone Heart has no battle effect")
	unprotected_battle.queue_free()
	await get_tree().process_frame


func _spawn_durable_enemy(scene: PackedScene, parent: Node2D, position: Vector2, health: float) -> BasicEnemy:
	var enemy := scene.instantiate() as BasicEnemy
	enemy.max_health = health
	enemy.target_ship = null
	parent.add_child(enemy)
	enemy.global_position = position
	return enemy


func _on_artifact_granted(_definition: MagicArtifactDefinition, _first: bool) -> void:
	_grant_count += 1


func _on_armor_shattered() -> void:
	_shatter_count += 1


func _cleanup() -> void:
	ArtifactManager.set_equipment_changes_enabled(true)
	_remove_test_save()
	ProgressionStore.restore_default_save_path()
	ShipLoadout.load_saved()
	ArtifactManager.reload_progress()


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


func _expect_near(actual: float, expected: float, description: String, tolerance: float = 0.01) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [description, expected, actual])

