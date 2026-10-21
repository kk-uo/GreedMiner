extends Node

## Clicking a locked weapon names the planet that unlocks it; a battery over
## the installation limit points at the Laboratory research (BaseMain notices).

const TestSave := preload("res://Tests/TestSave.gd")
const BASE_SCENE: PackedScene = preload("res://Scenes/Base/base_main.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("loadout_notice")
	TranslationServer.set_locale("en")
	var base := BASE_SCENE.instantiate()
	add_child(base)
	for index in range(4):
		await get_tree().process_frame

	var locked: String = base.get_module_notice(&"flamethrower")
	_expect(locked.begins_with("LOCKED") and locked.contains("Volcanic"), "locked weapon notice names its planet: %s" % locked)
	_expect(String(base.get_module_notice(&"machine_gun")).is_empty(), "unlocked weapon has no notice")

	var count: int = base.ship.get_installed_module_count(&"energy_module")
	var limit: int = ResearchManager.get_module_installation_limit(&"energy_module")
	_expect(count >= limit, "new game starts with the battery limit reached (%d/%d)" % [count, limit])
	var battery: String = base.get_module_notice(&"energy_module")
	_expect(battery.begins_with("BATTERY LIMIT REACHED") and battery.contains("Laboratory"), "battery notice points at the Laboratory: %s" % battery)

	# Clicking the card shows the toast.
	base.loadout_panel.module_card_pressed.emit(&"energy_module")
	var toast: Control = base.get("_toast")
	_expect(toast != null and (toast.get_node("Text") as Label).text == battery, "card click shows the notice as a toast")

	TranslationServer.set_locale("zh_CN")
	var chinese: String = base.get_module_notice(&"flamethrower")
	_expect(chinese.contains("火山星球"), "notice is translated: %s" % chinese)
	TranslationServer.set_locale("en")

	ResearchManager.progress.unlocked["energy_install_slot_unlock"] = true
	ResearchManager.progress.levels["energy_install_slot_unlock"] = 1
	_expect(String(base.get_module_notice(&"energy_module")).is_empty(), "after the research a second battery is allowed")

	base.queue_free()
	if _failures.is_empty():
		print("LOADOUT_NOTICE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("LOADOUT_NOTICE_TEST FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
