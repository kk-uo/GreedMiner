extends Node

## Every planet's battle map has at least one ore deposit to mine, for any
## map seed (Rocky crystals and each planet's own ore).

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var themes: Array = [&"rocky"]
	themes.append_array(Battlefield.PLANET_ORES.keys())
	var field := Battlefield.new()
	field.interactive_rocky_crystals = true
	add_child(field)
	await get_tree().process_frame
	var empty_before := 0
	for theme in themes:
		field.planet_theme = theme
		for seed_value in range(1, 121):
			field.generate(seed_value)
			var count := 0
			for child in field.get_interactables_root().get_node("RockyCrystals").get_children():
				if not child.is_queued_for_deletion():
					count += 1
			if count == 0:
				_failures.append("%s seed %d has no ore" % [theme, seed_value])
	if _failures.is_empty():
		print("ORE_GUARANTEE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures.slice(0, 10):
			push_error("ORE_GUARANTEE_TEST FAIL: " + failure)
		get_tree().quit(1)
