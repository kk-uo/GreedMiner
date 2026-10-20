extends Node

## Runs against a throwaway save, never the player's real progression.
const TestSave := preload("res://Tests/TestSave.gd")

## The 45° ship layout rotates gameplay too: contact edges, slot picking and
## module positions follow the hull, while the hull center stays in place.

const BATTLE_SCENE: PackedScene = preload("res://Scenes/Battle/BattleMain.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestSave.isolate("ship_rotation_test")
	ShipLoadout.installed_modules.clear()
	ShipLoadout.layout_rotation = 0.0
	var battle := BATTLE_SCENE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var ship := battle.get_node("Ship") as Ship
	var center_flat := ship.to_global(Ship.SHIP_SIZE * 0.5)
	var half := Ship.SHIP_SIZE.x * 0.5

	var enemy := EnemyCatalog.instantiate_enemy(&"little_rock")
	enemy.target_ship = ship
	battle.get_node("Enemies").add_child(enemy)
	var probe := center_flat + Vector2(400.0, 0.0)
	var edge_flat: Vector2 = enemy._get_nearest_ship_boundary_world(ship, probe)
	_expect_near(edge_flat.distance_to(center_flat), half, "flat ship: side edge is half a hull away")

	ShipLoadout.set_layout_rotation(45.0)
	await get_tree().process_frame
	var center_rotated := ship.to_global(Ship.SHIP_SIZE * 0.5)
	_expect_near(center_rotated.distance_to(center_flat), 0.0, "rotation keeps the hull center in place")
	_expect_near(ship.rotation_degrees, 45.0, "ship node is rotated 45 degrees")
	var edge_axis: Vector2 = enemy._get_nearest_ship_boundary_world(ship, probe)
	_expect_near(edge_axis.distance_to(center_rotated), half * sqrt(2.0), "45°: along a world axis the enemy meets a corner")
	var diagonal_probe := center_rotated + Vector2(1.0, 1.0).normalized() * 400.0
	var edge_diagonal: Vector2 = enemy._get_nearest_ship_boundary_world(ship, diagonal_probe)
	_expect_near(edge_diagonal.distance_to(center_rotated), half, "45°: along the diagonal the enemy meets a side")

	var top_left_center := ship.to_global(ship.get_cell_center(0, 0))
	_expect_equal(ship.get_cell_at_global(top_left_center), Vector2i(0, 0), "slot picking follows the rotation")
	_expect_near(top_left_center.x, center_rotated.x, "45°: top-left slot sits straight above the center")

	ShipLoadout.set_layout_rotation(30.0)
	_expect_near(ShipLoadout.layout_rotation, 45.0, "only 0 and 45 degrees are allowed")
	ShipLoadout.set_layout_rotation(0.0)
	await get_tree().process_frame
	_expect_near(ship.to_global(Ship.SHIP_SIZE * 0.5).distance_to(center_flat), 0.0, "rotating back restores the layout")

	battle.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("SHIP_ROTATION_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("SHIP_ROTATION_TEST: " + failure)
		print("SHIP_ROTATION_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


func _expect_near(actual: float, expected: float, description: String) -> void:
	if absf(actual - expected) > 0.5:
		_failures.append("%s (expected %.2f, got %.2f)" % [description, expected, actual])


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
