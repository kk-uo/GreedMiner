extends Node

## Zombie graves can't be clicked away; a dwarf sent to them digs up every
## grave inside the circle in half the crystal mining time, then walks home.

const SAVE := preload("res://Tests/TestSave.gd")
const SITE := preload("res://Scripts/Battle/Graveyard/GraveDigSite.gd")
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("grave_dig")
	ShipLoadout.installed_modules[Vector2i(2, 1)] = "res://Scenes/Modules/Mining/mining_module.tscn"
	var done := ProgressionStore.get_section(&"mining_tutorial")
	done["done"] = true
	ProgressionStore.set_section(&"mining_tutorial", done)
	ResourceManager.set_current_expedition_planet(&"graveyard_planet")
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://Scenes/Battle/BattleMain.tscn")
	await get_tree().create_timer(0.8).timeout
	var battle := get_tree().current_scene
	battle.get_node("WaveManager").set_process(false)
	var field: Battlefield = battle.get_node("Battlefield")
	var ship: Ship = battle.get_node("Ship")
	var spot := ship.global_position + Vector2(0, 260)
	for offset in [Vector2(-30, 0), Vector2(25, 10), Vector2(0, -35)]:
		field.add_zombie_grave(spot + offset)
	field.add_zombie_grave(spot + Vector2(200, 0))
	await get_tree().process_frame
	_expect(field.get_zombie_grave_points().size() == 4, "four graves placed")
	_expect(not field.try_click_zombie_grave(spot + Vector2(-30, 0)), "clicking a grave does nothing")
	_expect(field.get_zombie_grave_points().size() == 4, "graves survive clicks")
	var controller: Node = battle.get("_dwarf_mining")
	var module: MiningModule
	for child in ship.installed_modules.get_children():
		if child is MiningModule:
			module = child
	# Exercise both preview branches through actual draw notifications.
	var crystals := field.get_interactables_root().get_node_or_null("RockyCrystals")
	if crystals == null:
		crystals = Node2D.new()
		crystals.name = "RockyCrystals"
		field.get_interactables_root().add_child(crystals)
	var crystal := preload("res://Scripts/Battle/RockyCrystal.gd").new()
	crystals.add_child(crystal)
	crystal.global_position = spot + Vector2(400, 0)
	controller.set("dragging", module)
	controller.set("drag_position", crystal.global_position)
	controller.queue_redraw()
	await get_tree().process_frame
	controller.set("drag_position", spot)
	controller.queue_redraw()
	await get_tree().process_frame
	controller.set("dragging", null)
	crystal.queue_free()
	_expect(controller.call("dispatch_to_graves", module, spot), "dwarf sent to the graves")
	_expect(not controller.call("dispatch_to_graves", module, spot + Vector2(200, 0)), "one dwarf per module")
	var walk := ship.global_position.distance_to(spot) / 120.0
	await get_tree().create_timer(walk + SITE.dig_duration() + 0.6).timeout
	_expect(field.get_zombie_grave_points().size() == 1, "every grave inside the circle dug up, the far one stays (%d left)" % field.get_zombie_grave_points().size())
	_expect(is_equal_approx(SITE.dig_duration(), 5.0), "digging takes half the crystal time")
	await get_tree().create_timer(walk + 1.0).timeout
	_expect((controller.get("workers") as Dictionary).is_empty(), "the dwarf walked home")
	if _failures.is_empty():
		print("GRAVE_DIG_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("GRAVE_DIG_TEST FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
