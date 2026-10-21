extends Node

## The curved research bench follows the hall wall and is the LAB hotspot
## along its whole length (and not in the middle of the hall).

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var hangar: AsteroidHangar = AsteroidHangar.new()
	add_child(hangar)
	await get_tree().process_frame
	var path := ResearchLab.bench_path_mock()
	_expect(path.size() > 50, "bench path built (%d points)" % path.size())
	for f in [0.05, 0.3, 0.5, 0.7, 0.95]:
		var mock: Vector2 = path[int(f * float(path.size() - 1))]
		var global := hangar.to_global(AsteroidHangar.mock_to_local(mock))
		_expect(hangar.get_hotspot_at(global) == AsteroidHangar.HOTSPOT_LAB, "bench at %.2f is the LAB hotspot" % f)
		_expect(Geometry2D.is_point_in_polygon(mock, PackedVector2Array(AsteroidHangar.HALL)), "bench at %.2f is inside the hall" % f)
	_expect(hangar.get_hotspot_at(hangar.to_global(AsteroidHangar.mock_to_local(Vector2(450.0, 400.0)))) != AsteroidHangar.HOTSPOT_LAB, "open floor is not the lab")
	_expect(hangar.get_hotspot_at(hangar.get_hotspot_center(AsteroidHangar.HOTSPOT_LAB)) == AsteroidHangar.HOTSPOT_LAB, "lab hotspot centre is on the bench")
	if _failures.is_empty():
		print("LAB_BENCH_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("LAB_BENCH_TEST FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
