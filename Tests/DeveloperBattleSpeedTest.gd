extends Node

const SAVE := preload("res://Tests/TestSave.gd")
const BATTLE := preload("res://Scenes/Battle/BattleMain.tscn")
const FINISHER := preload("res://Scripts/VFX/BossFinisher.gd")
var failures: Array[String] = []

class FakeBossQte extends Node:
	func is_boss_qte_active() -> bool:
		return true

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	SAVE.isolate("developer_battle_speed")
	DeveloperCommands.set_availability_override_for_testing(1)
	var battle := BATTLE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	battle.get_node("MiningQteManager").auto_trigger = false
	battle.get_node("ShipLaunchController").play_landing_on_ready = false
	add_child(battle)
	await get_tree().process_frame
	var speed := battle.get_node("DeveloperBattleSpeed") as DeveloperBattleSpeed
	var panel := battle.get_node("BattleUI/UIRoot/DeveloperPanel") as DeveloperPanel
	panel.open_panel()
	check(panel.visible and panel.speed_button.visible, "battle developer speed control is available")
	panel._on_speed_pressed()
	check(speed.selected_speed == 2.0 and Engine.time_scale == 2.0, "button selects 2x")
	check(not speed.set_speed(3.0), "unsupported speed rejected")
	get_tree().paused = true
	speed._process(0.0)
	check(get_tree().paused and Engine.time_scale == 2.0, "pause preserves selected speed")
	get_tree().paused = false
	var mining := battle.get_node("MiningQteManager") as MiningQteManager
	var event := MiningQteEvent.new()
	mining._active_events.append(event)
	speed._process(0.0)
	check(Engine.time_scale == 1.0, "mining QTE restores 1x")
	mining._active_events.clear()
	event.free()
	speed._process(0.0)
	check(Engine.time_scale == 2.0, "speed restored after mining QTE")
	var qte := FakeBossQte.new()
	add_child(qte)
	qte.add_to_group("boss_qte_targets")
	speed._process(0.0)
	check(Engine.time_scale == 1.0, "boss QTE restores 1x")
	qte.free()
	var weather := battle.get_node("WeatherManager") as WeatherManager
	weather.freeze_input(2.0)
	speed._process(0.0)
	check(Engine.time_scale == 1.0, "freeze QTE restores 1x")
	weather.clear_transient_effects()
	speed._process(0.0)
	check(Engine.time_scale == 2.0, "speed restored after freeze")
	var cinematic := Node.new()
	add_child(cinematic)
	FINISHER._active = cinematic
	Engine.time_scale = 0.2
	speed._process(0.0)
	check(Engine.time_scale == 0.2, "boss finisher owns time")
	FINISHER._active = null
	cinematic.free()
	speed._process(0.0)
	check(Engine.time_scale == 2.0, "speed restored after cinematic")
	DeveloperCommands.set_availability_override_for_testing(0)
	check(not speed.set_speed(2.0), "disabled developer mode rejects command")
	speed._process(0.0)
	check(Engine.time_scale == 1.0, "disabled developer mode restores 1x")
	DeveloperCommands.set_availability_override_for_testing(1)
	speed.set_speed(2.0)
	battle.queue_free()
	await get_tree().process_frame
	check(Engine.time_scale == 1.0, "leaving battle restores 1x")
	DeveloperCommands.set_availability_override_for_testing(-1)
	if failures.is_empty():
		print("DEVELOPER_BATTLE_SPEED_TEST: PASS")
	else:
		for failure in failures:
			push_error("DEVELOPER_BATTLE_SPEED_TEST: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)
