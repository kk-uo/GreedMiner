extends Node

## Dragging an installed module on the ship moves it (empty slot) or swaps it
## with another module, keeps power totals, persists, and plain clicks still
## only select.

const BASE_SCENE: PackedScene = preload("res://Scenes/Base/base_main.tscn")
const TEST_SAVE_PATH: String = "user://greedminer_drag_swap_test.json"
const GUN := "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"
const LASER := "res://Scenes/Modules/Weapons/Laser/laser.tscn"

var _failures: Array[String] = []
var base: Node
var ship: Ship


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	ProgressionStore.set_save_path_for_testing(TEST_SAVE_PATH)
	ShipLoadout.installed_modules.clear()
	ShipLoadout.install_module(0, 0, GUN)
	ShipLoadout.install_module(0, 2, LASER)
	base = BASE_SCENE.instantiate()
	add_child(base)
	await get_tree().process_frame
	ship = base.ship
	base._enter_assembly()
	await get_tree().create_timer(0.9).timeout
	var power_before: int = ship.total_power_consumption

	# Real mouse drag: gun (0,0) onto laser (0,2) → swap.
	var gun_node := ship.get_module_at(0, 0)
	var laser_node := ship.get_module_at(0, 2)
	await _drag(Vector2i(0, 0), Vector2i(0, 2))
	_expect_equal(ShipLoadout.get_module(0, 2), GUN, "gun moved to (0,2)")
	_expect_equal(ShipLoadout.get_module(0, 0), LASER, "laser swapped into (0,0)")
	_expect_true(ship.get_module_at(0, 2) == gun_node and ship.get_module_at(0, 0) == laser_node, "same module instances, swapped")
	_expect_equal(ship.total_power_consumption, power_before, "power use unchanged by a swap")
	_expect_equal(Vector2i(base._selected_row, base._selected_column), Vector2i(0, 2), "dropped slot is selected")
	_expect_true(is_equal_approx(gun_node.modulate.a, 1.0), "dragged module is opaque again")
	await get_tree().create_timer(0.3).timeout
	_expect_true(gun_node.position.distance_to(ship.get_cell_center(0, 2)) < 0.5, "module slid to its new cell")

	# Drag onto an empty slot → move.
	await _drag(Vector2i(0, 2), Vector2i(2, 1))
	_expect_equal(ShipLoadout.get_module(2, 1), GUN, "gun moved to empty (2,1)")
	_expect_false(ShipLoadout.has_module(0, 2), "(0,2) is empty after the move")

	# A plain click (no movement) only selects.
	var before := ShipLoadout.installed_modules.duplicate()
	await _drag(Vector2i(0, 0), Vector2i(0, 0))
	_expect_equal(ShipLoadout.installed_modules, before, "clicking without moving changes nothing")

	# Dropping off the ship cancels.
	await _drag(Vector2i(0, 0), Vector2i(-1, -1))
	_expect_equal(ShipLoadout.installed_modules, before, "dropping off the ship cancels")
	_expect_true(is_equal_approx(ship.get_module_at(0, 0).modulate.a, 1.0), "cancelled module is opaque again")

	# Persistence.
	var saved := ShipLoadout.installed_modules.duplicate()
	ShipLoadout.installed_modules.clear()
	ProgressionStore.reload_from_disk()
	ShipLoadout.load_saved()
	_expect_equal(ShipLoadout.installed_modules, saved, "rearranged loadout is saved")

	# Works on the 45° layout too.
	ShipLoadout.set_layout_rotation(45.0)
	await get_tree().process_frame
	await _drag(Vector2i(0, 0), Vector2i(2, 2))
	_expect_equal(ShipLoadout.get_module(2, 2), LASER, "drag works on the rotated ship")

	# Right-click removes an installed module and persists the updated loadout.
	_right_click(Vector2i(2, 2))
	await get_tree().process_frame
	_expect_false(ShipLoadout.has_module(2, 2), "right-click removes the installed module")
	_expect_true(ship.get_module_at(2, 2) == null, "right-click removes the runtime module instance")
	ProgressionStore.reload_from_disk()
	ShipLoadout.load_saved()
	_expect_false(ShipLoadout.has_module(2, 2), "right-click removal is saved")
	ShipLoadout.set_layout_rotation(0.0)

	base.queue_free()
	ShipLoadout.installed_modules.clear()
	# Keep the isolated path active until this test process exits. Switching back
	# can overwrite the player's real progression during shutdown or reloads.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	await get_tree().process_frame
	if _failures.is_empty():
		print("SHIP_DRAG_SWAP_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("SHIP_DRAG_SWAP_TEST: " + failure)
		print("SHIP_DRAG_SWAP_TEST: FAIL (%d failures)" % _failures.size())
		get_tree().quit(1)


## Presses on a cell, moves in steps to another cell (or off the ship when
## target is (-1,-1)) and releases.
func _drag(from: Vector2i, to: Vector2i) -> void:
	var start := _cell_screen(from)
	var end := _cell_screen(to) if to.x >= 0 else start + Vector2(0.0, 400.0)
	_push_button(start, true)
	await get_tree().process_frame
	for step in range(1, 7):
		var motion := InputEventMouseMotion.new()
		motion.position = start.lerp(end, step / 6.0)
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().warp_mouse(motion.position)
		get_viewport().push_input(motion, true)
		await get_tree().process_frame
	_push_button(end, false)
	await get_tree().process_frame


func _push_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	get_viewport().warp_mouse(position)
	get_viewport().push_input(event, true)


func _right_click(cell: Vector2i) -> void:
	var position := _cell_screen(cell)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = position
	event.global_position = position
	get_viewport().warp_mouse(position)
	get_viewport().push_input(event, true)


func _cell_screen(cell: Vector2i) -> Vector2:
	return ship.get_global_transform_with_canvas() * ship.get_cell_center(cell.x, cell.y)


func _expect_true(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _expect_false(value: bool, description: String) -> void:
	_expect_true(not value, description)


func _expect_equal(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, expected, actual])
