class_name ForestBoss
extends ForestEnemy

## Captured logging ship. The saw acquires a target at windup start and NEVER
## homing-adjusts afterward. A dwarf chopping a tree/root is the preferred aim.
@export var saw_scene: PackedScene = preload("res://Scenes/Enemies/forest_saw_projectile.tscn")
@export_range(0.5, 60.0, 0.1) var saw_interval: float = 8.0
@export_range(0.1, 10.0, 0.1) var saw_windup: float = 1.3
@export_range(0.0, 1000.0, 1.0) var dwarf_lure_range: float = 550.0
var _saw_cooldown: float = 0.0
var _windup_left: float = 0.0
var _locked_direction := Vector2.ZERO

func _ready() -> void:
	super()
	_saw_cooldown = saw_interval

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
	_windup_left = saw_windup
	queue_redraw()

func _fire_saw() -> void:
	_saw_cooldown = saw_interval
	if saw_scene == null or _locked_direction == Vector2.ZERO:
		return
	var saw := saw_scene.instantiate() as HostileProjectile
	if saw == null:
		return
	saw.direction = _locked_direction
	saw.target_ship = target_ship as Ship
	var scene := get_tree().current_scene
	(scene if scene != null else get_parent()).add_child(saw)
	saw.global_position = global_position + _locked_direction * 32.0
	queue_redraw()

func _get_visual_radius() -> float:
	return 50.0

func _draw() -> void:
	var hull := Rect2(-48.0, -28.0, 96.0, 56.0)
	draw_rect(hull, _flash(Color("5D4936")))
	draw_rect(Rect2(-42.0, -22.0, 84.0, 44.0), Color("344737"))
	draw_circle(Vector2(0.0, 0.0), 19.0, Color("496B43"))
	draw_circle(Vector2(36.0, 0.0), 16.0, Color("A7AAA2"))
	if _windup_left > 0.0:
		draw_line(_locked_direction * 32.0, _locked_direction * 600.0, Color(0.97, 0.45, 0.27, 0.55), 3.0)
