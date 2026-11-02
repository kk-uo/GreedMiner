extends Node

const TestSave := preload("res://Tests/TestSave.gd")
const BASE_SCENE: PackedScene = preload("res://Scenes/Base/base_main.tscn")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("ship_expansion_ui")
	ResearchManager.progress.levels["energy_slot_support_1"] = 1
	ResearchManager.progress.levels["ship_hull_slot_1"] = 1
	var base := BASE_SCENE.instantiate()
	add_child(base)
	await get_tree().process_frame
	base._enter_assembly()
	await get_tree().create_timer(0.9).timeout
	_check(base._expansion_panel.visible, "expansion control appears on Hangar left")
	_check(base._expansion_guide.visible, "first-unlock guide appears")
	base._on_expansion_button_pressed()
	_check(base.ship.expansion_selection_enabled, "button shows dashed selectable ring")
	base._on_expansion_cell_requested(0)
	_check(ShipLoadout.is_valid_cell(3, 0), "choosing ring cell adds a module slot")
	_check(not base._expansion_guide.visible, "first placement completes guide")
	_check(bool(ProgressionStore.get_section(&"ship_expansion_guide").get("completed", false)), "guide completion persists")
	_check(base._selected_row == 3 and base._selected_column == 0, "new slot is selected for installation")
	base.queue_free()
	if failures.is_empty():
		print("SHIP_EXPANSION_UI_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SHIP_EXPANSION_UI_TEST: " + failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
