extends Node

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var rain := ForestStormController.RainView.new()
	add_child(rain)
	rain.set_process(false)
	rain.heavy = true
	rain._process(1.0)
	_check(rain.storm_blend > 0.0 and rain.storm_blend < 1.0, "storm tint ramps in instead of switching in one frame")
	rain._process(2.0)
	_check(is_equal_approx(rain.storm_blend, 1.0), "storm reaches full intensity")
	rain.heavy = false
	rain._process(1.0)
	_check(rain.storm_blend > 0.0 and rain.storm_blend < 1.0, "storm tint ramps out instead of switching in one frame")
	rain._process(3.0)
	_check(is_zero_approx(rain.storm_blend), "light rain returns after fade")
	_check(WeatherSfx.STORM_RAIN_DB < -9.0 and WeatherSfx.LIGHT_RAIN_DB < WeatherSfx.STORM_RAIN_DB, "rain targets are quieter and light rain is softer")
	if failures.is_empty():
		print("FOREST_RAIN_TRANSITION_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("FOREST_RAIN_TRANSITION_TEST: " + failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
