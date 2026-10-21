extends Node

## The Laboratory's "POWER FIRST" goal (now part of the TutorialGuide) shows
## on every Laboratory visit until ENERGY MODULE EXPANSION I is researched,
## pointing at the ENERGY tab; then never again.

const SAVE := preload("res://Tests/TestSave.gd")
const BASE := "res://Scenes/Base/base_main.tscn"
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("lab_energy_tip")
	ProgressionStore.set_section(&"tutorial", {"done": true, "lab_done": true})
	ResourceManager.stored_ore = 0.0
	for visit in range(2):
		get_tree().current_scene = null
		get_tree().change_scene_to_file(BASE)
		await get_tree().create_timer(1.2).timeout
		var base := get_tree().current_scene
		var guide: Node = base.find_child("TutorialGuide", true, false)
		_expect(guide != null, "guide present on visit %d" % (visit + 1))
		if guide == null:
			continue
		_expect(not (guide.get("_caption") as Control).visible, "nothing shown outside the Laboratory")
		base.call("_open_laboratory")
		await get_tree().create_timer(0.4).timeout
		_expect((guide.get("_caption") as Control).visible, "POWER FIRST shown in the Laboratory (visit %d)" % (visit + 1))
		_expect(bool(guide.get("_has_target")), "arrow on the ENERGY tab")
		var lab: Control = base.get("laboratory_panel")
		_expect(not is_instance_valid(lab.get("energy_tip")), "no separate tip any more")
	ResourceManager.add_stored_ore(5000.0)
	_expect(ResearchManager.purchase_research(&"energy_install_slot_unlock"), "energy expansion researched")
	get_tree().change_scene_to_file(BASE)
	await get_tree().create_timer(1.2).timeout
	_expect(get_tree().current_scene.find_child("TutorialGuide", true, false) == null, "no guide once researched")
	if _failures.is_empty():
		print("LAB_ENERGY_TIP_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("LAB_ENERGY_TIP_TEST FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
