extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Battle clicks: a COMMON enemy pops after CLICKS_TO_POP clicks (each click
## swells it), LARGE/BOSS enemies ignore clicks, and clicking a weapon shows
## its attack-range ring (clicking it again / empty ground hides it).

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://Scenes/Enemies/goblin.tscn")
const ELITE_SCENE: PackedScene = preload("res://Scenes/Enemies/elite_goblin.tscn")
const MACHINE_GUN_SCENE_PATH: String = "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"

var _failures: Array[String] = []
var battle: Node2D
var ship: Ship


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("battle_click_test")
	ShipLoadout.installed_modules.clear()
	ShipLoadout.install_module(0, 0, MACHINE_GUN_SCENE_PATH)
	battle = BATTLE_SCENE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	add_child(battle)
	await get_tree().process_frame
	ship = battle.get_node("Ship") as Ship
	var enemies := battle.get_node("Enemies")

	# Common goblin far from the ship (won't reach it during the test).
	var goblin := GOBLIN_SCENE.instantiate() as BasicEnemy
	goblin.move_speed = 0.0
	enemies.add_child(goblin)
	goblin.global_position = _ship_center() + Vector2(0.0, -420.0)
	var elite := ELITE_SCENE.instantiate() as BasicEnemy
	elite.move_speed = 0.0
	enemies.add_child(elite)
	elite.global_position = _ship_center() + Vector2(0.0, 420.0)
	await get_tree().process_frame

	# Goblins pay 0 ore by default now; give this one some so the payout is visible.
	goblin.reward_ore = 1.0
	var ore_before := ResourceManager.mission_ore
	for index in range(BasicEnemy.CLICKS_TO_POP - 1):
		_click_world(goblin.global_position)
		if index == 0:
			# The swell is a short tween (frame hitches can skip its peak).
			_expect_true(goblin._click_tween != null and goblin._click_tween.is_valid(), "a click starts the swell animation")
		await get_tree().process_frame
	_expect_equal(goblin.click_count, BasicEnemy.CLICKS_TO_POP - 1, "each click is counted")
	_expect_false(goblin.is_dying(), "goblin survives %d clicks" % (BasicEnemy.CLICKS_TO_POP - 1))
	await get_tree().create_timer(0.3).timeout
	_expect_true(is_equal_approx(goblin.scale.x, 1.0), "swell settles back to normal size")
	_click_world(goblin.global_position)
	await get_tree().process_frame
	_expect_true(not is_instance_valid(goblin) or goblin.is_dying(), "8th click pops the goblin")
	_expect_true(ResourceManager.mission_ore > ore_before, "popped goblin still pays its ore")

	for index in range(BasicEnemy.CLICKS_TO_POP + 2):
		_click_world(elite.global_position)
		await get_tree().process_frame
	_expect_false(elite.is_dying(), "LARGE enemies ignore clicks")
	_expect_equal(elite.click_count, 0, "LARGE enemy click count stays 0")

	# Turret range ring.
	var gun := ship.get_module_at(0, 0) as WeaponModule
	var indicator: Node2D = battle.get_node("TurretRangeIndicator")
	_expect_false(indicator.visible, "no range ring at first")
	_click_world(gun.global_position)
	await get_tree().process_frame
	_expect_true(indicator.visible, "clicking a turret shows its range ring")
	_expect_equal(indicator.radius, float(gun.get("attack_range")), "ring radius = turret attack range")
	_expect_true(indicator.global_position.distance_to(gun.global_position) < 0.5, "ring centred on the turret")
	_click_world(gun.global_position)
	await get_tree().process_frame
	_expect_false(indicator.visible, "clicking the same turret again hides the ring")
	_click_world(gun.global_position)
	await get_tree().process_frame
	_click_world(_ship_center() + Vector2(300.0, 300.0))
	await get_tree().process_frame
	_expect_false(indicator.visible, "clicking empty ground hides the ring")

	# Rotated ship: hit test follows the 45° layout.
	ShipLoadout.set_layout_rotation(45.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_click_world(gun.global_position)
	await get_tree().process_frame
	_expect_true(indicator.visible, "range ring works on the rotated ship")
	ShipLoadout.set_layout_rotation(0.0)

	battle.queue_free()
	ShipLoadout.installed_modules.clear()
	await get_tree().process_frame
	if _failures.is_empty():
		print("BATTLE_CLICK_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("BATTLE_CLICK_TEST: " + failure)
		print("BATTLE_CLICK_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _ship_center() -> Vector2:
	return ship.global_position + ship.get_cell_center(1, 1)


func _click_world(world: Vector2) -> void:
	var screen: Vector2 = get_viewport().get_canvas_transform() * world
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = screen
	event.global_position = screen
	get_viewport().push_input(event, true)
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	get_viewport().push_input(release, true)


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	_expect_true(not value, description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
