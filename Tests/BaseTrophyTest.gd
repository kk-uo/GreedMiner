extends Node

## Defeating the Frozen Planet boss (Mega Monster) puts a snowman in the base.

const SAVE := preload("res://Tests/TestSave.gd")
const TROPHIES := preload("res://Scripts/Base/BaseTrophies.gd")
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("base_trophy")
	_expect(not TROPHIES.has_trophy(&"snowman"), "no snowman in a new game")
	var boss := EnemyCatalog.instantiate_enemy(&"mega_monster")
	add_child(boss)
	await get_tree().process_frame
	boss.take_damage(9999999.0)
	await get_tree().process_frame
	_expect(TROPHIES.has_trophy(&"snowman"), "killing the Mega Monster earns the snowman")
	var base: Node = load("res://Scenes/Base/base_main.tscn").instantiate()
	add_child(base)
	await get_tree().process_frame
	_expect(base.find_child("TrophySnowman", true, false) != null, "the base shows the trophy snowman")
	base.queue_free()
	if _failures.is_empty():
		print("BASE_TROPHY_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("BASE_TROPHY_TEST FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
