class_name ForestBoss
extends ForestEnemy

## Captured logging ship. The saw acquires a target at windup start and NEVER
## homing-adjusts afterward. A dwarf chopping a tree/root is the preferred aim.
@export var saw_scene: PackedScene = preload("res://Scenes/Enemies/forest_saw_projectile.tscn")
@export_range(0.5, 60.0, 0.1) var saw_interval: float = 8.0
@export_range(0.1, 10.0, 0.1) var saw_windup: float = 1.3
@export_range(0.0, 1000.0, 1.0) var dwarf_lure_range: float = 550.0
@export_range(0.0, 200.0, 1.0) var saw_side_offset: float = 45.0
@export_range(0.0, 200.0, 1.0) var saw_forward_offset: float = 45.0
var _saw_cooldown: float = 0.0
var _windup_left: float = 0.0
var _locked_direction := Vector2.ZERO
var _locked_aim := Vector2.ZERO

## Presentation (user pick B, the treant on a hover saw-rig): heading of the
## rig (turns to the locked aim while winding up), reload of the blades.
const RELOAD_TIME: float = 1.4
var _rig_rot: float = 0.0
var _reload: float = 1.0
var _rig_crown: Dictionary = {}

func _ready() -> void:
	super()
	_saw_cooldown = saw_interval
	_rig_rot = _facing


func _process(delta: float) -> void:
	super(delta)
	var heading := _locked_direction.angle() if _windup_left > 0.0 and _locked_direction != Vector2.ZERO else _facing
	_rig_rot = lerp_angle(_rig_rot, heading, 1.0 - exp(-delta * (6.0 if _windup_left > 0.0 else 2.5)))
	_reload = minf(_reload + delta / RELOAD_TIME, 1.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var battle := get_tree().current_scene
	if battle != null and battle.get("_battle_ended") == true:
		_stop_attacking()
		return
	super(delta)
	if _is_dying or not is_instance_valid(target_ship) or (target_ship as Ship).current_hp <= 0.0:
		return
	if _windup_left > 0.0:
		_windup_left -= delta
		if _windup_left <= 0.0:
			_fire_saw()
		return
	_saw_cooldown -= delta
	if _saw_cooldown <= 0.0:
		_begin_saw_windup()

func _begin_saw_windup() -> void:
	EnemySfx.play(self, preload("res://Assets/Audio/Enemies/Forest/boss_saw_windup.wav"), -5.0, 0.0)
	var aim: Vector2 = (target_ship as Ship).to_global(Ship.SHIP_SIZE * 0.5)
	var nearest := dwarf_lure_range
	for node in get_tree().get_nodes_in_group("mining_dwarves"):
		if not is_instance_valid(node) or not node.has_method("is_enemy_targetable") or not node.call("is_enemy_targetable"):
			continue
		var site: Variant = node.get("crystal")
		if not site is ForestChopSite:
			continue
		var target: Vector2 = node.call("get_enemy_target_position")
		var distance := global_position.distance_to(target)
		if distance < nearest:
			nearest = distance
			aim = target
	_locked_direction = global_position.direction_to(aim)
	_locked_aim = aim
	_windup_left = saw_windup
	queue_redraw()

func _fire_saw() -> void:
	EnemySfx.play(self, preload("res://Assets/Audio/Enemies/Forest/boss_saw_fire.wav"), -4.0, 0.04)
	_saw_cooldown = saw_interval
	_reload = 0.0
	if saw_scene == null or _locked_direction == Vector2.ZERO:
		return
	var scene := get_tree().current_scene
	var sideways := _locked_direction.orthogonal()
	for side in [-1.0, 1.0]:
		var saw := saw_scene.instantiate() as HostileProjectile
		if saw == null:
			continue
		var launch_position: Vector2 = global_position + _locked_direction * saw_forward_offset + sideways * saw_side_offset * side
		# Both saws converge on the target chosen at windup; moving the
		# target afterward does not turn them into homing projectiles.
		saw.direction = launch_position.direction_to(_locked_aim)
		saw.target_ship = target_ship as Ship
		(scene if scene != null else get_parent()).add_child(saw)
		saw.global_position = launch_position
	queue_redraw()

func _get_visual_radius() -> float:
	return 60.0 * ForestVisual.RIG_SCALE

func _draw() -> void:
	if _rig_crown.is_empty():
		_rig_crown = ForestVisual.build_tree_crown(ForestVisual.RIG_CROWN_RADIUS, ForestVisual.RIG_CROWN_SEED, false)
	var rev := 0.0
	if _windup_left > 0.0:
		rev = clampf(1.0 - _windup_left / maxf(saw_windup, 0.01), 0.0, 1.0)
		# Aim line toward the locked target, brighter as the saws spin up.
		var from := _locked_direction * 70.0 * ForestVisual.RIG_SCALE
		var to := _locked_direction * 600.0
		draw_line(from, to, Color(0.97, 0.45, 0.27, 0.25 + 0.4 * rev), 2.0 + 2.0 * rev)
	ForestVisual.draw_saw_rig(self, _rig_crown, _rig_rot, _anim_time, rev, _reload, _is_flashing())
