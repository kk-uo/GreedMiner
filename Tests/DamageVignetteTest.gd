extends Node

## Every hull hit flashes a red screen edge (DamageVignette); shielded hits
## that never reach the hull do not; the glow fades out.

const SAVE := preload("res://Tests/TestSave.gd")
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("damage_vignette")
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://Scenes/Battle/BattleMain.tscn")
	await get_tree().create_timer(0.5).timeout
	var battle := get_tree().current_scene
	var vignette: CanvasLayer = battle.get_node_or_null("DamageVignette")
	_expect(vignette != null, "battle has a damage vignette")
	if vignette != null:
		var ship: Ship = battle.get_node("Ship")
		_expect(is_zero_approx(vignette.flash), "no glow before any hit")
		ship.take_damage(1.0)
		_expect(vignette.flash >= 0.45, "a small hit still flashes (%f)" % vignette.flash)
		ship.take_damage(ship.max_hp * 0.2)
		_expect(is_equal_approx(vignette.flash, 1.0), "a big hit flashes at full strength")
		await get_tree().create_timer(0.8).timeout
		_expect(is_zero_approx(vignette.flash), "the glow fades out")
		var block := func(_amount: float) -> float: return 0.0
		ship.register_damage_interceptor(block)
		ship.take_damage(5.0)
		_expect(is_zero_approx(vignette.flash), "fully blocked hits do not flash")
		ship.unregister_damage_interceptor(block)
	if _failures.is_empty():
		print("DAMAGE_VIGNETTE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("DAMAGE_VIGNETTE_TEST FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
