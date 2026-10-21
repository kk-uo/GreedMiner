extends Node

const SAVE := preload("res://Tests/TestSave.gd")
const CRYSTAL := preload("res://Scripts/Battle/RockyCrystal.gd")
var failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	SAVE.isolate("red_crystal_mining")
	ResourceManager.start_new_mission()
	var crystal := CRYSTAL.new()
	crystal.configure(1.0, 0.0, false, true)
	add_child(crystal)
	check(crystal.can_be_mined(), "red crystal can be mined")
	check(crystal.advance_mining(9.0) == 0.0, "no early reward")
	check(not ArtifactManager.owns_artifact(&"red_crystal"), "no early artifact")
	check(crystal.advance_mining(1.0) == 30.0, "first red crystal yields 30 carried ore")
	check(ArtifactManager.owns_artifact(&"red_crystal"), "first mining grants artifact")
	check(ResourceManager.mission_ore == 0.0, "ore is not credited at the mine")
	check(crystal.advance_mining(10.0) == 0.0, "completed crystal cannot reward twice")
	ArtifactManager.reload_progress()
	check(ArtifactManager.owns_artifact(&"red_crystal"), "artifact ownership persists")
	var repeat := CRYSTAL.new()
	repeat.configure(1.0, 0.0, true, true)
	add_child(repeat)
	check(repeat.advance_mining(10.0) == 100.0, "repeat red crystal yields 100 carried ore")
	if failures.is_empty():
		print("RED_CRYSTAL_MINING_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("RED_CRYSTAL_MINING_TEST: " + failure)
		get_tree().quit(1)
