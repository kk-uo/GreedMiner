extends Node

const SAVE := preload("res://Tests/TestSave.gd")
const BATTLE := preload("res://Scenes/Battle/BattleMain.tscn")
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SAVE.isolate("dwarf_ground_order")
	ResourceManager.set_current_expedition_planet(&"goblin_planet")
	ShipLoadout.installed_modules[Vector2i(2, 1)] = "res://Scenes/Modules/Mining/mining_module.tscn"
	var battle := BATTLE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	add_child(battle)
	await get_tree().process_frame
	var controller: Node2D = battle.get("_dwarf_mining")
	var ship: Ship = battle.get_node("Ship")
	var module: MiningModule
	for child in ship.installed_modules.get_children():
		if child is MiningModule:
			module = child
	_check(controller != null, "controller is available on every planet")
	_check(module != null, "mining module is installed")
	if controller != null and module != null:
		var point := module.global_position + Vector2(90.0, 0.0)
		_check(controller.dispatch_to_point(module, point), "empty ground accepts a dwarf order")
		_check(not controller.dispatch_to_point(module, point + Vector2(20.0, 0.0)), "worker limit still applies")
		var dwarf: Node2D = controller.workers.get(module)
		dwarf._physics_process(1.0)
		_check(is_instance_valid(dwarf) and dwarf.global_position.distance_to(point) <= dwarf.ARRIVAL_DISTANCE, "dwarf reaches the marked point")
		_check(dwarf.state == dwarf.State.RETURNING and not dwarf.is_enemy_targetable(), "empty waypoint immediately starts return")
		_check(dwarf.ore == 0.0, "empty ground produces no mining reward")
		dwarf._physics_process(1.0)
		await get_tree().process_frame
		_check(controller.workers.is_empty(), "return trip frees the worker slot")
	_check(not controller.dispatch_to_point(module, Vector2(-10000.0, -10000.0)), "off-map target is rejected")
	if failures.is_empty():
		print("DWARF_GROUND_ORDER_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("DWARF_GROUND_ORDER_TEST: " + failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
