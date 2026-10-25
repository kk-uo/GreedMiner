class_name ManualTurretController
extends Node2D

## Research-unlocked battle control, independent of magic artifact equipment.
## Only one installed weapon can follow the mouse at a time.

@export_range(1.0, 100.0, 1.0) var selection_radius: float = 34.0

var ship: Ship
var _active_weapon: WeaponModule
var _indicator: Node2D


func configure(target_ship: Ship) -> void:
	ship = target_ship


func _process(_delta: float) -> void:
	if is_instance_valid(_active_weapon):
		_active_weapon.set_manual_aim_world_position(_active_weapon.get_global_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE and is_manual_control_active():
			deactivate_manual_control()
			get_viewport().set_input_as_handled()
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and is_manual_control_active():
		deactivate_manual_control()
		get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var weapon := _find_clicked_weapon()
	if weapon != null:
		activate_weapon_control(weapon)
		get_viewport().set_input_as_handled()


func _find_clicked_weapon() -> WeaponModule:
	if not is_instance_valid(ship) or ship.installed_modules == null:
		return null
	var mouse_position := ship.get_global_mouse_position()
	var nearest: WeaponModule
	var nearest_distance := selection_radius
	for child in ship.installed_modules.get_children():
		var weapon := child as WeaponModule
		if weapon == null:
			continue
		var distance := weapon.global_position.distance_to(mouse_position)
		if distance <= nearest_distance:
			nearest = weapon
			nearest_distance = distance
	return nearest


func activate_weapon_control(weapon: WeaponModule) -> void:
	if not is_instance_valid(weapon) or not is_instance_valid(ship) or not ship.is_ancestor_of(weapon):
		return
	if _active_weapon == weapon and weapon.is_manual_control_active():
		deactivate_manual_control()
		return
	deactivate_manual_control()
	_active_weapon = weapon
	_active_weapon.set_manual_control_active(true)
	_active_weapon.set_manual_aim_world_position(_active_weapon.get_global_mouse_position())
	_indicator = AimIndicator.new()
	_active_weapon.add_child(_indicator)


func deactivate_manual_control() -> void:
	if is_instance_valid(_active_weapon):
		_active_weapon.set_manual_control_active(false)
	_active_weapon = null
	if is_instance_valid(_indicator):
		_indicator.queue_free()
	_indicator = null


func is_manual_control_active() -> bool:
	return is_instance_valid(_active_weapon) and _active_weapon.is_manual_control_active()


func _exit_tree() -> void:
	deactivate_manual_control()


class AimIndicator:
	extends Node2D

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var accent := Color("8ED65C")
		draw_arc(Vector2.ZERO, 29.0, 0.0, TAU, 32, accent, 2.5, true)
		var mouse_local := to_local(get_global_mouse_position())
		if mouse_local.length_squared() > 1.0:
			draw_line(Vector2.ZERO, mouse_local.normalized() * 38.0, accent, 2.0, true)
