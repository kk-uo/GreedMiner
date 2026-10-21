extends Node

## Volcanic battle maps get two lightning-shaped lava rifts away from the ship
## (no old lava streams), and every wave a pack of 5-6 demons climbs out.

const SAVE := preload("res://Tests/TestSave.gd")
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("lava_rift")
	ResourceManager.set_current_expedition_planet(&"volcanic_planet")
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://Scenes/Battle/BattleMain.tscn")
	await get_tree().create_timer(0.8).timeout
	var battle := get_tree().current_scene
	var field: Battlefield = battle.get_node("Battlefield")
	_expect(field.get_lava_fissures().size() == 2, "two lava rifts (%d)" % field.get_lava_fissures().size())
	_expect(field.get_lava_streams().is_empty(), "old lava streams removed")
	var ship: Ship = battle.get_node("Ship")
	# Every rift stays inside the opening view, on many seeds.
	var view_size := field.get_viewport_rect().size / maxf(ship.world_visual_scale, 0.1)
	for seed_value in range(1, 21):
		field.generate(seed_value)
		_expect(field.get_lava_fissures().size() == 2, "two rifts on seed %d" % seed_value)
		var view := Rect2(field.to_global(field.world_size * 0.5) - view_size * 0.5, view_size)
		for fissure in field.get_lava_fissures():
			for branch in fissure["branches"]:
				for point in branch["points"]:
					_expect(view.has_point(field.to_global(point)), "rift inside the view on seed %d" % seed_value)
	for point in field.get_lava_emerge_points():
		_expect(ship.get_distance_to_hull(point) > field.clear_radius, "rift stays out of the ship clearing")
	var emergence: Node = battle.get_node_or_null("LavaEmergence")
	_expect(emergence != null, "lava emergence runs on volcanic maps")
	if emergence != null:
		var count: int = emergence.call("emerge_pack")
		_expect(count >= 5 and count <= 6, "a pack of 5-6 demons (%d)" % count)
		await get_tree().create_timer(2.5).timeout
		var demons := 0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.get_meta("spawn_origin", &"") == &"lava_fissure":
				demons += 1
				_expect(enemy.enemy_id == &"demon", "lava pack is ordinary demons")
				_expect(enemy.is_physics_processing(), "demon moves once out of the lava")
		_expect(demons == count, "all demons climbed out (%d/%d)" % [demons, count])
	if _failures.is_empty():
		print("LAVA_RIFT_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("LAVA_RIFT_TEST FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
