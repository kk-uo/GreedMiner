extends Node

## Volcanic Planet is back on the star map (Claude sync 88): it shares one
## carousel slot with Frozen Planet as an orbiting "fire & ice" twin system;
## clicking either planet picks that challenge.

const SELECTOR := preload("res://Scenes/PlanetSelection/planet_select.tscn")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _run() -> void:
	var visible := PlanetSelect.get_visible_planets()
	check(visible.size() == PlanetSelect.PLANETS.size(), "every registered planet is on the star map")
	check(PlanetSelect.get_planet_index(&"volcanic_planet") == 3, "Volcanic remains at its stable registry index")
	check(PlanetSelect.get_visible_planet_index(&"volcanic_planet") == 3, "Volcanic has a visible index")
	var volcanic: Dictionary = PlanetSelect.PLANETS[PlanetSelect.get_planet_index(&"volcanic_planet")]
	check(int(volcanic.get("locate_cost", 0)) == 1000, "Volcanic locate cost is preserved")
	check(bool(volcanic.get("playable", false)), "Volcanic gameplay remains registered")

	var selector := SELECTOR.instantiate() as PlanetSelect
	add_child(selector)
	await get_tree().process_frame
	check(selector.planet_layer.get_node_or_null("Planet_volcanic_planet") != null, "carousel creates the Volcanic planet")
	check(selector.planet_layer.get_child_count() == visible.size(), "carousel creates every planet")
	check(selector.get_slot_count() == visible.size() - 1, "Frozen and Volcanic share one carousel slot")
	selector._select_planet(PlanetSelect.get_visible_planet_index(&"frozen_planet"))
	var twins := selector.get_selected_slot_planets()
	check(twins.size() == 2 and twins.has(PlanetSelect.get_visible_planet_index(&"volcanic_planet")), "the Frozen slot holds the Volcanic twin")
	selector._on_planet_pressed(PlanetSelect.get_visible_planet_index(&"volcanic_planet"))
	check(selector.selected_index == PlanetSelect.get_visible_planet_index(&"volcanic_planet"), "clicking the twin selects Volcanic")
	check(selector.planet_name_label.text == tr("VOLCANIC PLANET"), "the info panel shows the clicked twin")
	selector._on_right_pressed()
	selector._on_left_pressed()
	check(selector.selected_index == PlanetSelect.get_visible_planet_index(&"volcanic_planet"), "returning to the twin slot remembers the chosen twin")

	if failures.is_empty():
		print("PLANET_VISIBILITY_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("PLANET_VISIBILITY_TEST: " + failure)
		get_tree().quit(1)
