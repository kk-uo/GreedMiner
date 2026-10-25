extends Node

const AUDIO_SETTINGS_SCRIPT := preload("res://Scripts/Core/AudioSettings.gd")
const TEST_PATH := "user://greedminer_audio_settings_test.cfg"

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_expect(TranslationServer.translate("VOLUME") == "音量", "volume label has a Chinese translation")
	TranslationServer.set_locale(original_locale)
	var bus := AudioServer.get_bus_index(&"Master")
	_expect(bus >= 0, "Master bus exists")
	if bus < 0:
		_finish()
		return

	var settings = AUDIO_SETTINGS_SCRIPT.new()
	settings.settings_path = TEST_PATH
	add_child(settings)
	_expect(settings.master_volume_percent == 100, "missing preference defaults to 100%")
	settings.set_master_volume(0)
	_expect(AudioServer.is_bus_mute(bus), "0% mutes the Master bus")
	settings.set_master_volume(50)
	_expect(not AudioServer.is_bus_mute(bus), "raising volume unmutes the Master bus")
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5)), "50% sets the expected bus level")
	settings.set_master_volume(150)
	_expect(settings.master_volume_percent == 100, "values above 100% are clamped")
	settings.set_master_volume(37)
	settings.flush()
	var saved := ConfigFile.new()
	_expect(saved.load(TEST_PATH) == OK, "audio preference was saved")
	_expect(saved.get_value("audio", "master_volume_percent", -1) == 37, "saved volume matches the selected value")
	settings.free()

	var restored = AUDIO_SETTINGS_SCRIPT.new()
	restored.settings_path = TEST_PATH
	add_child(restored)
	_expect(restored.master_volume_percent == 37, "saved volume is restored on startup")
	restored.free()

	var original_percent: int = AudioSettings.master_volume_percent
	var original_path: String = AudioSettings.settings_path
	AudioSettings.settings_path = TEST_PATH
	AudioSettings._apply_master_volume()
	var menu := SettingsMenu.new()
	menu.pause_game_when_open = true
	menu.allow_language_change = false
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu)
	var slider := _find_slider(menu)
	_expect(slider != null, "settings menu contains a volume slider")
	if slider != null:
		_expect(roundi(slider.value) == original_percent, "slider reflects saved volume")
		menu.open_menu()
		_expect(get_tree().paused, "battle settings menu pauses the game")
		var target := 0 if original_percent != 0 else 37
		slider.value = target
		_expect(AudioSettings.master_volume_percent == target, "slider updates volume while paused")
		_expect(AudioServer.is_bus_mute(bus) == (target == 0), "slider updates mute state while paused")
		menu.close_menu()
		_expect(not get_tree().paused, "closing settings resumes the game")
	menu.free()
	AudioSettings.set_master_volume(original_percent)
	AudioSettings.flush()
	AudioSettings.settings_path = original_path
	AudioSettings._apply_master_volume()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_finish()


func _find_slider(node: Node) -> HSlider:
	if node is HSlider:
		return node as HSlider
	for child in node.get_children():
		var slider := _find_slider(child)
		if slider != null:
			return slider
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("AUDIO_SETTINGS_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("AUDIO_SETTINGS_TEST: " + failure)
		get_tree().quit(1)
