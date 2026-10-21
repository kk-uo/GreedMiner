extends Node

## Each planet's battle map gets its mineable ore deposits (and no old
## decorative crystal deposits); the dwarves mine them like Rocky crystals.

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for theme in Battlefield.PLANET_ORES.keys():
		var field := Battlefield.new()
		field.interactive_rocky_crystals = true
		field.planet_theme = theme
		field.map_seed = 777
		add_child(field)
		await get_tree().process_frame
		var ores: Array = field.get_interactables_root().get_node("RockyCrystals").get_children()
		_expect(ores.size() >= 3, "%s has ore deposits (%d)" % [theme, ores.size()])
		for ore in ores:
			_expect(ore.get("ore_kind") in Battlefield.PLANET_ORES[theme], "%s ore kind %s belongs to the planet" % [theme, ore.get("ore_kind")])
			_expect(ore.call("can_be_mined"), "%s ore can be mined" % theme)
		if theme != &"jungle":
			_expect(field.get("_deposits").is_empty(), "%s has no old crystal deposits" % theme)
		if not ores.is_empty():
			var ore: Node2D = ores[0]
			var reward: float = ore.call("advance_mining", ore.get("MINING_DURATION") + 0.1)
			_expect(reward > 0.0, "%s ore pays out when fully mined" % theme)
			var expected: float = {&"jungle": 80.0, &"frozen": 160.0, &"volcanic": 250.0, &"graveyard": 400.0}[theme]
			_expect(is_equal_approx(reward, expected), "%s ore is worth %d (got %d)" % [theme, expected, reward])
		field.queue_free()
	var rocky := Battlefield.new()
	rocky.interactive_rocky_crystals = true
	rocky.map_seed = 777
	add_child(rocky)
	await get_tree().process_frame
	var crystals: Array = rocky.get_interactables_root().get_node("RockyCrystals").get_children()
	_expect(not crystals.is_empty() and crystals[0].get("ore_kind") == &"", "rocky keeps its crystals")
	if _failures.is_empty():
		print("PLANET_ORE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("PLANET_ORE_TEST FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
