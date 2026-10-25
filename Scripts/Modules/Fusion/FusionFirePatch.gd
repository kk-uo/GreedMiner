class_name FusionFirePatch
extends Node2D

@export var damage: float = 9.0
@export var duration: float = 3.0
@export var radius: float = 42.0
@export var tick_interval: float = 0.5
var source_weapon: WeaponModule
var _tick_left: float = 0.0


func _ready() -> void:
	z_index = 1
	queue_redraw()


func _physics_process(delta: float) -> void:
	duration -= delta
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left += tick_interval
		_apply_tick()
	if duration <= 0.0:
		queue_free()
	else:
		queue_redraw()


func _apply_tick() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit_ids: Dictionary = {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 256):
		var enemy := hit.get("collider") as BasicEnemy
		if enemy == null or enemy.is_dying() or hit_ids.has(enemy.get_instance_id()):
			continue
		hit_ids[enemy.get_instance_id()] = true
		enemy.take_damage(damage, false, true, source_weapon if is_instance_valid(source_weapon) else null)


func _draw() -> void:
	var pulse := 0.88 + sin(Time.get_ticks_msec() * 0.012) * 0.08
	draw_circle(Vector2.ZERO, radius * pulse, Color(0.8, 0.12, 0.03, 0.22))
	for index in range(7):
		var angle := TAU * float(index) / 7.0
		var at := Vector2.RIGHT.rotated(angle) * radius * 0.55
		draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(6, 7.0, angle), at), Color("F06A2F"))
