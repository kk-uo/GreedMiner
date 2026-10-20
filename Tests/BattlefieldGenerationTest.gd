extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## Headless checks for procedural battlefield generation and reserved sites.

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("battlefield_generation_test")
	var a := _make(12345)
	var b := _make(12345)
	var c := _make(0)
	var d := _make(0)

	_expect_equal(a.get_map_seed(), 12345, "fixed seed is kept")
	_expect_equal(a._rocks.size(), b._rocks.size(), "same seed -> same rock count")
	_expect_equal(a._patches.size(), b._patches.size(), "same seed -> same terrain")
	_expect_equal(a.get_special_sites(), b.get_special_sites(), "same seed -> same special sites")
	_expect_true(c.get_map_seed() != 0, "seed 0 picks a real seed")
	_expect_true(c.get_map_seed() != d.get_map_seed(), "seed 0 gives a new map each time")

	var center := a.to_global(a.world_size * 0.5)
	_expect_false(a.is_area_free(center, 10.0), "ship clearing is claimed")
	var sites := a.get_special_sites()
	_expect_true(sites.size() > 0, "special sites are reserved")
	var last_distance := 0.0
	for site in sites:
		var position: Vector2 = site["position"]
		_expect_true(a.get_world_bounds().has_point(position), "site inside the map")
		_expect_true(position.distance_to(center) > a.clear_radius, "site outside the ship clearing")
		_expect_true(site["distance"] >= last_distance, "sites sorted nearest first")
		last_distance = site["distance"]
		for rock in a._rocks:
			var rock_center: Vector2 = a.to_global(Battlefield._centroid_of(rock["points"]))
			_expect_true(rock_center.distance_to(position) >= site["radius"], "no rock inside a site")
	_expect_true(a.get_interactables_root() != null, "interactables root exists")
	_expect_true(a.get_terrain_band(center) in [-1, 0, 1], "terrain band query works")

	var probe := center + Vector2(900.0, 500.0)
	if a.is_area_free(probe, 20.0):
		a.claim_area(probe, 20.0)
		_expect_false(a.is_area_free(probe, 5.0), "claim_area blocks the spot")

	if _failures.is_empty():
		print("BATTLEFIELD_GENERATION_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("BATTLEFIELD_GENERATION_TEST: " + failure)
		print("BATTLEFIELD_GENERATION_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _make(seed_value: int) -> Battlefield:
	var field := Battlefield.new()
	field.map_seed = seed_value
	add_child(field)
	return field


func _expect_true(value: bool, description: String) -> void:
	if not value and not _failures.has(description):
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	_expect_true(not value, description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
