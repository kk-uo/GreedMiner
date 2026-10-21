extends Node

## Base tutorial: hangar -> machine gun -> mining (scroll hint while the card
## is out of view) -> fill all Power with a second machine gun -> launch; no
## SKIP button. Back with ore: Laboratory -> ENERGY MODULE EXPANSION ends it.

const SAVE := preload("res://Tests/TestSave.gd")
const BASE := "res://Scenes/Base/base_main.tscn"
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("base_tutorial")
	ResourceManager.stored_ore = 0.0
	get_tree().current_scene = null
	get_tree().change_scene_to_file(BASE)
	await get_tree().create_timer(1.5).timeout
	var base := get_tree().current_scene
	var guide: Node = base.find_child("TutorialGuide", true, false)
	_expect(guide != null, "guide shown on a fresh ship")
	if guide == null:
		_end()
		return
	_expect(_find_text(guide, "SKIP") == null, "no SKIP button")
	_expect(int(guide.get("step")) == 0, "starts at OPEN THE HANGAR")
	base.call("_enter_assembly")
	await get_tree().create_timer(1.5).timeout
	_expect(int(guide.get("step")) == 1, "assembly -> INSTALL A WEAPON")
	_expect(base.call("drop_module_on_cell", &"machine_gun", Vector2i(0, 0)), "machine gun installed")
	await get_tree().create_timer(0.3).timeout
	_expect(int(guide.get("step")) == 2, "-> INSTALL MINING")
	_expect(base.call("drop_module_on_cell", &"mining_module", Vector2i(0, 1)), "mining installed")
	await get_tree().create_timer(0.3).timeout
	_expect(int(guide.get("step")) == 3, "-> USE ALL YOUR POWER (power not full yet)")
	_expect(base.call("drop_module_on_cell", &"machine_gun", Vector2i(0, 2)), "second machine gun installed")
	await get_tree().create_timer(0.3).timeout
	_expect(int(guide.get("step")) == 4, "power full -> READY FOR LAUNCH")
	_expect(bool(ProgressionStore.get_section(&"tutorial").get("done", false)), "base tutorial saved as done")
	# Back from an expedition with ore: the Laboratory part.
	ResourceManager.stored_ore = 5000.0
	get_tree().change_scene_to_file(BASE)
	await get_tree().create_timer(1.5).timeout
	base = get_tree().current_scene
	guide = base.find_child("TutorialGuide", true, false)
	_expect(guide != null and int(guide.get("step")) == 5, "back with ore -> OPEN THE LABORATORY")
	if guide != null:
		base.call("_open_laboratory")
		await get_tree().create_timer(0.5).timeout
		_expect(int(guide.get("step")) == 6, "laboratory -> RESEARCH AN UPGRADE")
		var lab: Control = base.get("laboratory_panel")
		_expect(guide.get_index() > lab.get_index(), "guide draws over the laboratory")
		var lab_view: Control = base.get("laboratory_panel")
		_expect(not is_instance_valid(lab_view.get("energy_tip")), "the old POWER FIRST tip is merged into the guide")
		lab_view.call("_select_category", &"energy")
		await get_tree().create_timer(0.4).timeout
		var tree_view: Node = lab_view.get("_research_tree_view")
		_expect(tree_view != null and tree_view.get("selected_id") == &"energy_install_slot_unlock", "guide selects ENERGY MODULE EXPANSION")
		_expect(ResearchManager.purchase_research(&"mining_install_slot_unlock") or true, "another research")
		await get_tree().process_frame
		_expect(is_instance_valid(guide) and not guide.is_queued_for_deletion(), "other research keeps the guide")
		_expect(ResearchManager.purchase_research(&"energy_install_slot_unlock"), "energy expansion researched")
		await get_tree().process_frame
		_expect(not is_instance_valid(guide) or guide.is_queued_for_deletion(), "guide finished after the energy research")
		_expect(bool(ProgressionStore.get_section(&"tutorial").get("lab_done", false)), "lab part saved as done")
	_end()


func _find_text(root: Node, text: String) -> Node:
	for child in root.get_children():
		if child is Button and (child as Button).text == text:
			return child
		var found := _find_text(child, text)
		if found != null:
			return found
	return null


func _end() -> void:
	if _failures.is_empty():
		print("BASE_TUTORIAL_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("BASE_TUTORIAL_TEST FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
