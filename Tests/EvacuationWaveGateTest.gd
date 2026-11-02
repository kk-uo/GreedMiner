extends Node

const SAVE := preload("res://Tests/TestSave.gd")
const BATTLE_SCENE := preload("res://Scenes/Battle/BattleMain.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("evacuation_wave_gate")
	ResourceManager.set_current_expedition_planet(&"rocky_planet")
	var battle := BATTLE_SCENE.instantiate()
	var waves := battle.get_node("WaveManager") as WaveManager
	waves.auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var panel := battle.get_node("BattleUI/UIRoot/EvacuationPanel") as EvacuationPanel
	_check(not panel._is_pressable(), "evacuation starts locked")
	for press in range(EvacuationPanel.REQUIRED_CLICKS):
		panel._press()
	_check(panel.get_click_count() == 0 and not panel.is_completed(), "early presses do not count")
	battle._on_evacuation_completed()
	_check(not bool(battle.get("_battle_ended")), "direct early completion cannot end the battle")
	for wave_number in [1, 2]:
		waves.wave_completed.emit(wave_number, waves.get_total_waves())
		_check(not panel._is_pressable(), "evacuation remains locked after Wave %d" % wave_number)
	waves.wave_completed.emit(3, waves.get_total_waves())
	_check(panel._is_pressable(), "evacuation unlocks when Wave 3 completes")
	panel._press()
	_check(panel.get_click_count() == 1, "button counts presses after unlock")
	panel.set_external_lock(true)
	_check(not panel._is_pressable(), "forest root lock still blocks evacuation")
	panel.set_external_lock(false)
	_check(panel._is_pressable(), "clearing root lock restores evacuation")
	battle.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("EVACUATION_WAVE_GATE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("EVACUATION_WAVE_GATE_TEST: " + failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
