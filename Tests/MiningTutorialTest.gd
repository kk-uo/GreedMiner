extends Node

## First battle with a Mining Module: the mining tutorial appears, holds the
## first wave until a dwarf is sent, follows the dwarf and saves itself done.

const SAVE := preload("res://Tests/TestSave.gd")
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("mining_tutorial")
	ShipLoadout.installed_modules[Vector2i(2, 1)] = "res://Scenes/Modules/Mining/mining_module.tscn"
	ResourceManager.set_current_expedition_planet(&"rocky_planet")
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://Scenes/Battle/BattleMain.tscn")
	await get_tree().create_timer(3.0).timeout
	var battle := get_tree().current_scene
	var tutorial: Node = battle.get_node_or_null("BattleUI/UIRoot/MiningTutorial")
	_expect(tutorial != null, "tutorial shown in the first battle with a mining module")
	_expect(get_tree().get_nodes_in_group("enemies").is_empty(), "first wave holds while the tutorial waits")
	if tutorial != null:
		var controller: Node2D = battle.get("_dwarf_mining")
		var module: Node2D = tutorial.call("_first_module", controller)
		var crystal: Node2D = tutorial.call("_nearest_crystal", module.global_position)
		_expect(controller.call("dispatch", module, crystal), "dwarf dispatched")
		await get_tree().create_timer(0.3).timeout
		_expect(int(tutorial.get("step")) == 1, "tutorial moves to the mining step")
		_expect(battle.get_node("WaveManager").is_processing(), "waves resume after the first dwarf")
		tutorial.call("finish")
	_expect(bool(ProgressionStore.get_section(&"mining_tutorial").get("done", false)), "tutorial saved as done")
	if _failures.is_empty():
		print("MINING_TUTORIAL_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("MINING_TUTORIAL_TEST FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
