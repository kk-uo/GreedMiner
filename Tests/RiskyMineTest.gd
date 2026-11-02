extends Node

const SAVE := preload("res://Tests/TestSave.gd")
const BATTLE := preload("res://Scenes/Battle/BattleMain.tscn")
const RISKY_CRYSTAL := preload("res://Scripts/Battle/RiskyRockyCrystal.gd")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("risky_mine")
	ResourceManager.set_current_expedition_planet(&"rocky_planet")
	var battle := BATTLE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	var field := battle.get_node("Battlefield") as Battlefield
	field.map_seed = 12345
	add_child(battle)
	await get_tree().process_frame
	var deposits: Array = field._deposits
	_check(deposits.size() >= 3, "two ordinary deposits remain beside risky mine")
	var risky: Node2D
	for child in field.get_interactables_root().get_node("RockyCrystals").get_children():
		if child.get_script() == RISKY_CRYSTAL:
			risky = child
			break
	_check(risky != null, "one risky mine generated on Rocky Planet")
	if risky != null:
		var initial_distance := risky.position.distance_squared_to(field.world_size * 0.5)
		for deposit in deposits:
			_check(initial_distance >= (deposit["position"] as Vector2).distance_squared_to(field.world_size * 0.5), "risky mine is the most distant deposit")
		var enemies := battle.get_node("Enemies")
		_check(enemies.get_child_count() == 0, "dormant guards are not active enemies")
		risky.call("on_miner_arrived")
		_check(enemies.get_child_count() == 1, "arrival wakes one Rock Golem")
		var duration := ResearchManager.get_crystal_mining_seconds()
		var multiplier := ResearchManager.get_crystal_value_multiplier()
		_check(is_equal_approx(float(risky.call("advance_mining", duration)), 30.0 * multiplier), "first segment pays carried ore")
		_check(bool(risky.call("continues_after_reward")), "dwarf can keep mining after first segment")
		_check(enemies.get_child_count() == 1, "next group waits for decision window")
		risky.call("advance_mining", float(risky.get("decision_seconds")) + 0.01)
		_check(enemies.get_child_count() == 4, "second stage adds three Rock Golems")
		_check(is_equal_approx(float(risky.call("advance_mining", duration)), 80.0 * multiplier), "second segment pays more ore")
		risky.call("advance_mining", float(risky.get("decision_seconds")) + 0.01)
		_check(enemies.get_child_count() == 9, "third stage adds five Rock Golems")
		_check(is_equal_approx(float(risky.call("advance_mining", duration)), 160.0 * multiplier), "final segment pays highest ore")
		_check(not bool(risky.call("continues_after_reward")), "mine ends after three segments")
	if failures.is_empty():
		print("RISKY_MINE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("RISKY_MINE_TEST: " + failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
