extends Node

## Volcanic Planet is temporarily hidden from the player-facing carousel while
## remaining in the complete registry used by progression and content systems.

const SELECTOR := preload("res://Scenes/PlanetSelection/planet_select.tscn")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _run() -> void:
	var visible := PlanetSelect.get_visible_planets()
	check(visible.size() == PlanetSelect.PLANETS.size() - 1, "only one registered planet is hidden")
	check(not visible.any(func(planet: Dictionary) -> bool: return StringName(planet.get("id", &"")) == &"volcanic_planet"), "Volcanic is absent from visible data")
	check(PlanetSelect.get_planet_index(&"volcanic_planet") == 3, "Volcanic remains at its stable registry index")
	check(PlanetSelect.get_visible_planet_index(&"volcanic_planet") == 0, "hidden previous planet falls back to Rocky")
	var volcanic: Dictionary = PlanetSelect.PLANETS[PlanetSelect.get_planet_index(&"volcanic_planet")]
	check(int(volcanic.get("locate_cost", 0)) == 1000, "Volcanic locate cost is preserved")
	check(bool(volcanic.get("playable", false)), "Volcanic gameplay remains registered")

	var selector := SELECTOR.instantiate() as PlanetSelect
	add_child(selector)
	await get_tree().process_frame
	check(selector.planet_layer.get_node_or_null("Planet_volcanic_planet") == null, "carousel creates no Volcanic node")
	check(selector.planet_layer.get_child_count() == visible.size(), "carousel creates every other planet")

	if failures.is_empty():
		print("PLANET_VISIBILITY_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("PLANET_VISIBILITY_TEST: " + failure)
		get_tree().quit(1)
