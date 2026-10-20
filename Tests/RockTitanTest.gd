extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Headless checks for the Rock Titan boss: stats, boss wave, boss bar and split.

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("rock_titan_test")
	ShipLoadout.installed_modules.clear()
	var battle := BATTLE_SCENE.instantiate()
	var manager := battle.get_node("WaveManager") as WaveManager
	manager.auto_start = false
	add_child(battle)
	await get_tree().process_frame

	var spawner := battle.get_node("EnemySpawner")
	var enemies := battle.get_node("Enemies")
	var boss_bar := battle.get_node("BattleUI/UIRoot/BossHealthBar") as BossHealthBar
	_expect_equal(_count_titans(enemies), 0, "no titan before explicit spawn")
	spawner.spawn_enemy_by_id(&"rock_titan")
	_expect_equal(_count_titans(enemies), 1, "catalog spawns one titan")

	var titan: RockTitan = null
	for child in enemies.get_children():
		if child is RockTitan:
			titan = child
	_expect_true(titan != null, "titan instance found")
	if titan != null:
		_expect_equal(titan.max_health, 2000.0, "titan HP")
		_expect_equal(titan.reward_ore, 200.0, "titan reward")
		_expect_equal(titan.move_speed, 10.0, "titan speed")
		_expect_equal(titan.attack_damage, 20.0, "titan contact damage")
		_expect_equal(titan.attack_interval, 1.0, "titan attack interval")
		_expect_equal(titan.attack_range, 50.0, "titan attack range")
		_expect_equal(titan.enemy_tier, BasicEnemy.EnemyTier.BOSS, "titan is boss tier")

		for _frame in range(30):
			await get_tree().process_frame
		_expect_true(boss_bar.visible and boss_bar.modulate.a > 0.5, "boss bar shows while the titan lives")

		# Clear the other enemies so the split can be counted exactly.
		for child in enemies.get_children():
			if child != titan:
				child.free()
		var death_position := titan.global_position
		var ore_before := ResourceManager.mission_ore
		titan.take_damage(100000.0)
		_expect_equal(ResourceManager.mission_ore, ore_before + 200.0, "killing the titan adds 200 mission ore")
		await get_tree().process_frame
		await get_tree().process_frame
		var golems := 0
		for child in enemies.get_children():
			if child is RockGolem and is_instance_valid(child):
				golems += 1
				_expect_true(child.global_position.distance_to(death_position) < 100.0, "golem appears at the titan")
		_expect_equal(golems, 4, "titan splits into 4 rock golems")
		_expect_equal(_count_titans(enemies), 0, "titan is removed after death")

		for _frame in range(40):
			await get_tree().process_frame
		_expect_false(boss_bar.visible, "boss bar hides after the titan dies")

	if _failures.is_empty():
		print("ROCK_TITAN_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("ROCK_TITAN_TEST: " + failure)
		print("ROCK_TITAN_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _count_titans(enemies: Node) -> int:
	var count := 0
	for child in enemies.get_children():
		if child is RockTitan and not (child as RockTitan).is_dying():
			count += 1
	return count


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	if value:
		_failures.append(description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
