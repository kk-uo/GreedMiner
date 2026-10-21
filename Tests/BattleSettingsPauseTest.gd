extends Node

const TestSave := preload("res://Tests/TestSave.gd")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _run() -> void:
	TestSave.isolate("battle_settings_pause")
	var battle := load("res://Scenes/Battle/BattleMain.tscn").instantiate() as Node2D
	# The test harness itself runs while paused; battle must retain normal mode.
	battle.process_mode = Node.PROCESS_MODE_PAUSABLE
	battle.get_node("WaveManager").auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var menu := battle.get_node("BattleUI/UIRoot/SettingsMenu") as SettingsMenu
	var ship := battle.get_node("Ship") as Ship
	var enemy := load("res://Scenes/Enemies/little_rock.tscn").instantiate() as BasicEnemy
	enemy.target_ship = ship
	battle.get_node("Enemies").add_child(enemy)
	enemy.global_position = ship.global_position + Vector2(500.0, 0.0)
	await get_tree().physics_frame
	check(not menu.is_open() and not get_tree().paused, "battle starts unpaused")
	menu._gear.pressed.emit()
	check(menu.is_open() and get_tree().paused, "gear opens and pauses")
	check(menu.can_process(), "settings remain interactive while paused")
	check(not menu.allow_language_change, "language changes disabled in battle settings")
	check(menu.find_children("*", "OptionButton", true, false).is_empty(), "battle settings have no language selector")
	var stopped := enemy.global_position
	await get_tree().create_timer(0.2).timeout
	check(enemy.global_position.is_equal_approx(stopped), "enemies stop while paused")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	menu._unhandled_input(escape)
	check(not menu.is_open() and not get_tree().paused, "escape closes and resumes")
	menu._unhandled_input(escape)
	check(menu.is_open() and get_tree().paused, "escape opens and pauses")
	menu._unhandled_input(escape)
	check(not menu.is_open() and not get_tree().paused, "second escape closes and resumes")
	await get_tree().create_timer(0.2).timeout
	check(not enemy.global_position.is_equal_approx(stopped), "enemies resume")
	menu.open_menu()
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	menu._catcher.gui_input.emit(outside)
	check(not menu.is_open() and not get_tree().paused, "outside click closes and resumes")
	get_tree().paused = true
	menu.open_menu()
	menu.close_menu()
	check(get_tree().paused, "pre-existing pause is preserved")
	get_tree().paused = false
	menu.open_menu()
	battle.queue_free()
	await get_tree().process_frame
	check(not get_tree().paused, "scene exit releases its own pause")
	var base_menu := SettingsMenu.new()
	add_child(base_menu)
	check(not base_menu.find_children("*", "OptionButton", true, false).is_empty(), "base settings retain language selector")
	base_menu.open_menu()
	check(not get_tree().paused, "base settings do not pause by default")
	base_menu.close_menu()
	if failures.is_empty():
		print("BATTLE_SETTINGS_PAUSE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("BATTLE_SETTINGS_PAUSE_TEST: " + failure)
		get_tree().quit(1)
