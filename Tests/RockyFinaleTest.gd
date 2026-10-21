extends Node

## Boss finisher + Rocky Planet finale (first Rock Titan defeat):
## the killing blow plays the cinema finisher, the titan does not split, the
## battle ends, the finale builds rubble and dwarves, pulls the camera back,
## then a click returns to base with the planet recorded as cleared. A second
## kill (finale already seen) splits as usual.

const SAVE := preload("res://Tests/TestSave.gd")
const FINALE := preload("res://Scripts/Battle/RockyFinale.gd")
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("rocky_finale")
	ProgressionStore.set_section(&"mining_tutorial", {"done": true})
	ResourceManager.set_current_expedition_planet(&"rocky_planet")
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://Scenes/Battle/BattleMain.tscn")
	await get_tree().create_timer(2.0).timeout
	var battle := get_tree().current_scene
	_expect(not FINALE.has_been_seen(), "finale not seen yet")
	var titan := _spawn_titan(battle)
	var camera: Camera2D = battle.get("ship").world_camera
	var zoom_before := camera.zoom.x
	await get_tree().process_frame
	titan.take_damage(999999.0, true)
	await get_tree().process_frame
	_expect(Engine.time_scale < 0.5, "killing blow freezes / slows time")
	_expect(battle.get_node_or_null("RockyFinale") != null, "finale started")
	_expect(bool(battle.get("_battle_ended")), "battle ended")
	_expect(not battle.get_node("BattleUI").visible, "HUD hidden")
	await _real_wait(2.2)
	_expect(is_equal_approx(Engine.time_scale, 1.0), "time scale restored")
	var golems := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			golems += 1
	_expect(golems == 0, "titan did not split, no enemies left (%d)" % golems)
	_expect(camera.zoom.x < zoom_before, "camera pulling back")
	var finale: Node = battle.get_node("RockyFinale")
	finale.call("return_to_base")
	_expect(FINALE.has_been_seen(), "finale saved as seen")
	_expect(WeaponUnlockManager.has_completed_planet(&"rocky_planet"), "rocky planet recorded")
	await get_tree().create_timer(1.0).timeout
	_expect(get_tree().current_scene.scene_file_path.contains("base"), "back at base")
	# Second time: normal split.
	ResourceManager.set_current_expedition_planet(&"rocky_planet")
	get_tree().change_scene_to_file("res://Scenes/Battle/BattleMain.tscn")
	await get_tree().create_timer(2.0).timeout
	battle = get_tree().current_scene
	titan = _spawn_titan(battle)
	await get_tree().process_frame
	titan.take_damage(999999.0, true)
	await _real_wait(2.2)
	_expect(battle.get_node_or_null("RockyFinale") == null, "finale only plays once")
	var split := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is BasicEnemy and enemy.enemy_id == &"rock_golem":
			split += 1
	_expect(split > 0, "second kill splits into golems (%d)" % split)
	_expect(is_equal_approx(Engine.time_scale, 1.0), "finisher restores time scale")
	if _failures.is_empty():
		print("ROCKY_FINALE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("ROCKY_FINALE_TEST FAIL: " + failure)
		get_tree().quit(1)


func _spawn_titan(battle: Node) -> BasicEnemy:
	var titan: BasicEnemy = load("res://Scenes/Enemies/rock_titan.tscn").instantiate()
	titan.target_ship = battle.get("ship")
	battle.get_node("Enemies").add_child(titan)
	titan.global_position = battle.get("ship").global_position + Vector2(380, 0)
	return titan


func _real_wait(seconds: float) -> void:
	var end := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < end:
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
