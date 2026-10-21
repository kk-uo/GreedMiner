extends Node

## Back at the base: after an evacuation dwarves carry ore into the
## warehouse; after the ship was destroyed it smokes and gets repaired.

const SAVE := preload("res://Tests/TestSave.gd")
const HOMECOMING := preload("res://Scripts/Base/BaseHomecoming.gd")
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("base_homecoming")
	ProgressionStore.set_section(&"tutorial", {"done": true, "lab_done": true})
	HOMECOMING.pending = {"kind": &"haul", "ore": 400.0}
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://Scenes/Base/base_main.tscn")
	await get_tree().create_timer(0.5).timeout
	var base := get_tree().current_scene
	_expect(HOMECOMING.pending.is_empty(), "pending homecoming consumed")
	var haul: Node = base.get_node_or_null("Homecoming")
	_expect(haul != null, "haul homecoming started")
	var carried := false
	var end := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < end and not carried and is_instance_valid(haul):
		await get_tree().process_frame
		for entry in haul.get("_crew"):
			if is_instance_valid(entry["dwarf"]) and entry["dwarf"].carrying:
				carried = true
	_expect(carried, "a dwarf carries ore from the ship")
	# Wrecked ship.
	HOMECOMING.pending = {"kind": &"wrecked"}
	get_tree().change_scene_to_file("res://Scenes/Base/base_main.tscn")
	await get_tree().create_timer(2.5).timeout
	base = get_tree().current_scene
	var wreck: Node = base.get_node_or_null("Homecoming")
	_expect(wreck != null and not (wreck.get("_puffs") as Array).is_empty(), "wrecked ship smokes")
	_expect(base.get("ship").modulate.r < 0.9, "wrecked hull looks scorched")
	# Every mechanic gets to the ship and works (none stuck on the way).
	var worked := {}
	end = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < end and wreck != null and is_instance_valid(wreck) and worked.size() < 4:
		await get_tree().process_frame
		for entry in wreck.get("_crew"):
			if is_instance_valid(entry["dwarf"]) and bool(entry["dwarf"].get("_working")):
				worked[entry["dwarf"].get_instance_id()] = true
	_expect(worked.size() == 4, "all 4 mechanics reach the ship and repair (%d)" % worked.size())
	if wreck != null:
		wreck.set("_repair", 1.0)
		end = Time.get_ticks_msec() + 15000
		while Time.get_ticks_msec() < end and is_instance_valid(wreck):
			await get_tree().process_frame
		_expect(not is_instance_valid(wreck), "repair crew finishes and leaves")
		_expect(is_equal_approx(base.get("ship").modulate.r, 1.0), "hull restored after repairs")
	# No homecoming without a pending return.
	get_tree().change_scene_to_file("res://Scenes/Base/base_main.tscn")
	await get_tree().create_timer(0.5).timeout
	_expect(get_tree().current_scene.get_node_or_null("Homecoming") == null, "plain visit has no homecoming")
	if _failures.is_empty():
		print("BASE_HOMECOMING_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("BASE_HOMECOMING_TEST FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
