extends Node

## Graveyard Planet presentation: the map is 200 px bigger per axis around
## the same center, tombstone clusters are placed (with emerge points), and
## the weather overlay plays lightning (blackout signals) and a blood moon.
const TestSave := preload("res://Tests/TestSave.gd")
const BATTLE_SCENE := preload("res://Scenes/Battle/BattleMain.tscn")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)


## 3 clusters of 9 (one 200-300 px from the hull), >= 5 single stones
## 100-200 px from the hull, about 20 more; every stone is a spawn point.
func _check_layout(field: Battlefield, seed_value: int) -> void:
	var tombs := field.get_interactables_root().get_node("GraveyardTombstones")
	var fences: Array = tombs.get("plots")
	var stones: Array = tombs.get("stones")
	check(fences.size() == 3, "seed %d: three tombstone clusters (%d)" % [seed_value, fences.size()])
	var near_cluster := 0
	var cluster_stones := 0
	for fence in fences:
		var rect: Rect2 = fence["rect"]
		var d := field.get_ship_hull_distance(tombs.to_global(rect.get_center()))
		if d >= 200.0 and d <= 300.0:
			near_cluster += 1
		var inside := 0
		for stone in stones:
			if rect.has_point(stone["pos"]):
				inside += 1
		check(inside == 9, "seed %d: a cluster holds nine stones (%d)" % [seed_value, inside])
		cluster_stones += inside
	check(near_cluster >= 1, "seed %d: one cluster 200-300 px from the ship" % seed_value)
	var near_stones := 0
	for stone in stones:
		var in_cluster := false
		for fence in fences:
			if (fence["rect"] as Rect2).has_point(stone["pos"]):
				in_cluster = true
		var d := field.get_ship_hull_distance(tombs.to_global(stone["pos"]))
		if not in_cluster and d >= 100.0 and d <= 200.0:
			near_stones += 1
		check(d > 60.0, "seed %d: no stone on the ship" % seed_value)
	check(near_stones >= 5, "seed %d: at least five stones 100-200 px from the ship (%d)" % [seed_value, near_stones])
	var singles := stones.size() - cluster_stones
	check(singles >= 23 and singles <= 26, "seed %d: about 25 single stones (%d)" % [seed_value, singles])
	check(field.get_grave_emerge_points().size() == stones.size(), "seed %d: every stone is a spawn point" % seed_value)


func _run() -> void:
	TestSave.isolate("graveyard_map_test")
	var battle := BATTLE_SCENE.instantiate()
	(battle.get_node("WaveManager") as WaveManager).auto_start = false
	(battle.get_node("MiningQteManager") as MiningQteManager).auto_trigger = false
	add_child(battle)
	await get_tree().process_frame
	var field := battle.get_node("Battlefield") as Battlefield
	var ship := battle.get_node("Ship") as Ship
	var size_before := field.world_size
	var center_before := field.get_world_bounds().get_center()
	check(field.get_grave_emerge_points().is_empty(), "no graves on a rocky map")
	field.planet_theme = &"graveyard"
	field.generate(4242)
	check(field.world_size == size_before + Vector2(200.0, 200.0), "graveyard map is 200 px bigger per axis")
	check(field.get_world_bounds().get_center().distance_to(center_before) < 0.01, "map grows around the same center")
	check(ship.to_global(Ship.SHIP_SIZE * 0.5).distance_to(center_before) < 1.0, "ship stays in the middle")
	for seed_value in [4242, 1, 77, 9001, 31337, 555, 2024, 8]:
		field.generate(seed_value)
		_check_layout(field, seed_value)
	field.generate(4242)
	var points := field.get_grave_emerge_points()
	check(points.size() >= 50, "about 52 tombstones placed (%d)" % points.size())
	var inside := true
	for p in points:
		if not field.get_world_bounds().has_point(p):
			inside = false
	check(inside, "every grave is inside the map")
	field.generate(4242)
	check(field.world_size == size_before + Vector2(200.0, 200.0), "regenerating does not grow the map twice")
	field.planet_theme = &"rocky"
	field.generate(4242)
	check(field.world_size == size_before and field.get_world_bounds().get_center().distance_to(center_before) < 0.01, "other themes restore the normal map")
	check(field.get_grave_emerge_points().is_empty(), "graves removed on other themes")
	# The bigger graveyard map is also shown: the camera sees 200 px more.
	var camera := ship.world_camera
	var width_before: float = battle.get_viewport_rect().size.x / camera.zoom.x
	battle.call("apply_planet_view", &"graveyard")
	var width_after: float = battle.get_viewport_rect().size.x / camera.zoom.x
	check(absf(width_after - width_before - 200.0) < 0.5, "graveyard view is 200 px wider (%.1f -> %.1f)" % [width_before, width_after])
	battle.call("apply_planet_view", &"graveyard")
	check(absf(battle.get_viewport_rect().size.x / camera.zoom.x - width_after) < 0.01, "view widening applies once")
	# Weather overlay.
	var weather := battle.get_node("WeatherManager") as WeatherManager
	var fx := weather.get_graveyard_weather()
	var log: Array[String] = []
	fx.connect("blackout_started", func(): log.append("dark"))
	fx.connect("blackout_ended", func(): log.append("light"))
	weather.play_graveyard_lightning()
	check(fx.call("is_lightning_playing"), "lightning starts")
	await get_tree().create_timer(1.0).timeout
	check(fx.call("is_blacked_out") and log == ["dark"], "blackout after the flashes")
	await get_tree().create_timer(2.6).timeout
	check(log == ["dark", "light"], "light returns with a reveal flash")
	check(not fx.call("is_lightning_playing"), "lightning finishes")
	weather.set_blood_moon(true)
	await get_tree().create_timer(0.3).timeout
	check(bool(fx.get("blood_moon")), "blood moon on")
	weather.set_blood_moon(false)
	battle.queue_free()
	if failures.is_empty():
		print("GRAVEYARD_MAP_TEST: PASS")
	else:
		for f in failures:
			push_error("GRAVEYARD_MAP_TEST: " + f)
	get_tree().quit(1 if not failures.is_empty() else 0)
