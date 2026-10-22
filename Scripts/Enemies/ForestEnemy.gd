class_name ForestEnemy
extends RangedEnemy

## The fairy heals ONE nearby wounded treant each pulse while moving. Once it
## reaches the ship's attack range, it commits to attacking for the rest of its life.
@export_range(0.0, 500.0, 1.0) var heal_amount: float = 50.0
@export_range(0.0, 500.0, 1.0) var heal_radius: float = 120.0
@export_range(0.1, 30.0, 0.1) var heal_interval: float = 1.0
var committed_to_attack: bool = false
var _heal_time: float = 0.0
@export_range(0.0, 5.0, 0.1) var emerge_duration: float = 0.8
var _emerge_left: float = 0.0
## Presentation: walk cycle clock and a throttled redraw (forest packs are big).
const EMERGE_FX := preload("res://Scripts/VFX/ForestEmergeFx.gd")
const REDRAW_INTERVAL: float = 1.0 / 12.0
var _anim_time: float = 0.0
var _redraw_wait: float = 0.0

func _ready() -> void:
	super()
	if enemy_id == &"fairy":
		# Keep the one-second healing rate while avoiding synchronized scans.
		_heal_time = -_dwarf_search_schedule.phase_delay(0.2)
	if enemy_id in [&"treant", &"big_treant"]:
		_emerge_left = emerge_duration
		# Spawners set the position right after add_child, so wait a frame.
		_spawn_emerge_fx.call_deferred()
	_anim_time = randf() * 10.0


func _spawn_emerge_fx() -> void:
	if is_inside_tree() and emerge_duration > 0.0:
		EMERGE_FX.spawn(get_parent(), global_position, 1.8 if enemy_id == &"big_treant" else 1.0)

func _process(delta: float) -> void:
	# Hit flash and emergence redraw every frame; the walk cycle / facing only
	# about 12 times a second so big forest packs stay cheap.
	_anim_time += delta
	if _hit_flash_time > 0.0:
		_hit_flash_time = maxf(_hit_flash_time - delta, 0.0)
		queue_redraw()
		return
	_redraw_wait -= delta
	if _redraw_wait <= 0.0:
		_redraw_wait = REDRAW_INTERVAL
		queue_redraw()

func _physics_process(delta: float) -> void:
	var battle := get_tree().current_scene
	if battle != null and battle.get("_battle_ended") == true:
		_stop_attacking()
		return
	if _emerge_left > 0.0:
		_emerge_left = maxf(0.0, _emerge_left - delta)
		queue_redraw()
		return
	if enemy_id != &"fairy":
		super(delta)
		return
	if _is_dying or not is_instance_valid(target_ship) or not target_ship is Ship:
		_stop_attacking()
		return
	var ship := target_ship as Ship
	if ship.current_hp <= 0.0:
		_stop_attacking()
		return
	var closest := _get_nearest_ship_boundary_world(ship, global_position)
	var to_ship := closest - global_position
	var distance := to_ship.length()
	if distance > 0.01:
		_facing = to_ship.angle()
	if distance <= attack_range + ATTACK_RANGE_TOLERANCE:
		committed_to_attack = true
	if committed_to_attack:
		if distance <= attack_range + ATTACK_RANGE_TOLERANCE:
			_start_attacking()
			# Keep walking tangentially instead of stopping while shooting.
			global_position += to_ship.normalized().orthogonal() * get_effective_move_speed() * delta
		else:
			_stop_attacking()
			global_position = global_position.move_toward(closest, get_effective_move_speed() * delta)
	else:
		_stop_attacking()
		global_position = global_position.move_toward(closest, get_effective_move_speed() * delta)
		_heal_time += delta
		if _heal_time >= heal_interval:
			_heal_time = 0.0
			_heal_nearest_treant()

func _heal_nearest_treant() -> void:
	var selected: ForestEnemy
	var shortest := heal_radius
	for node in get_tree().get_nodes_in_group("enemies"):
		var tree_enemy := node as ForestEnemy
		if tree_enemy == null or tree_enemy == self or tree_enemy.is_dying():
			continue
		if tree_enemy.enemy_id not in [&"treant", &"big_treant"] or tree_enemy.get_current_health() >= tree_enemy.max_health:
			continue
		var distance := global_position.distance_to(tree_enemy.global_position)
		if distance <= shortest:
			selected = tree_enemy
			shortest = distance
	if selected != null:
		selected.heal(heal_amount)

func heal(amount: float) -> float:
	if _is_dying or amount <= 0.0:
		return 0.0
	var previous := _current_health
	_current_health = minf(max_health, _current_health + amount)
	if _current_health > previous:
		health_changed.emit(_current_health, max_health)
	return _current_health - previous

func _perform_attack(ship: Ship) -> void:
	if enemy_id == &"fairy":
		super(ship)
	else:
		ship.take_damage(attack_damage)

func _on_attack_timer_timeout() -> void:
	if enemy_id == &"fairy" and is_instance_valid(target_ship):
		var closest := _get_nearest_ship_boundary_world(target_ship as Ship, global_position)
		if global_position.distance_to(closest) > attack_range + ATTACK_RANGE_TOLERANCE:
			_stop_attacking()
			return
	super()

func _get_visual_radius() -> float:
	return 10.0 if enemy_id == &"fairy" else (30.0 if enemy_id == &"big_treant" else 17.0)

func _draw() -> void:
	if enemy_id == &"fairy":
		ForestVisual.draw_fairy(self, _facing, _hit_flash_time > 0.0, _anim_time)
		return
	var rise := 1.0 - _emerge_left / maxf(emerge_duration, 0.001)
	var step := 0.0 if (_is_attacking or _emerge_left > 0.0) else sin(_anim_time * TAU * 1.4)
	ForestVisual.draw_treant(self, _facing, step, _hit_flash_time > 0.0, enemy_id == &"big_treant", rise)
