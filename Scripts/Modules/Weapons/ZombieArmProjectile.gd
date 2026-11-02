class_name ZombieArmProjectile
extends MachineGunProjectile

## Zombie Arm artifact projectile. Uses the standard bullet collision,
## targeting, kill attribution and hit pipeline, with a fixed artifact damage.
## Presentation (Claude sync 91): a tumbling rotting forearm whose fingers
## claw open and shut in flight, leaving an ooze trail; ZombieArmFx plays the
## launch puff, the grab-and-splat on hit and the crumble at max range.
const FX := preload("res://Scripts/VFX/ZombieArmFx.gd")
const SKIN_DARK := Color("55733F")
const SKIN := Color("7FA05F")
const SKIN_HI := Color("A9C77E")
const OOZE := Color("B9F06A")
const SLEEVE := Color("4A3A2E")
const TRAIL_POINTS: int = 7
## The arm reads larger than a plain bullet.
const ART_SCALE: float = 1.35

var maximum_distance: float = 300.0
var _origin: Vector2
var _age: float = 0.0
var _trail: Array[Vector2] = []


func arm_from_current_position() -> void:
	_origin = global_position
	_spawn_fx(&"launch")


func _ready() -> void:
	super()
	_origin = global_position
	_age = randf() * 2.0


func _process(delta: float) -> void:
	super(delta)
	_age += delta
	_trail.push_front(global_position)
	if _trail.size() > TRAIL_POINTS:
		_trail.pop_back()
	queue_redraw()
	if global_position.distance_squared_to(_origin) >= maximum_distance * maximum_distance:
		_spawn_fx(&"fade")
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var was_hit := _hit
	super(area)
	if not was_hit and _hit and area is BasicEnemy:
		_spawn_fx(&"hit")


func _spawn_fx(fx_mode: StringName) -> void:
	var parent := get_parent()
	if parent == null or not is_inside_tree():
		return
	var fx := FX.new()
	fx.mode = fx_mode
	fx.facing = direction.angle()
	parent.add_child(fx)
	fx.global_position = global_position


func _draw() -> void:
	var visual_scale := get_projectile_visual_scale()
	# Ooze trail (drawn in world-aligned local space before the rotation).
	for index in range(1, _trail.size()):
		var k := 1.0 - float(index) / float(TRAIL_POINTS)
		draw_circle(to_local(_trail[index]), (1.0 + 2.2 * k) * visual_scale, Color(OOZE, 0.45 * k))
	var wobble := sin(_age * 13.0) * 0.14
	draw_set_transform(Vector2.ZERO, direction.angle() + wobble, Vector2.ONE * visual_scale * ART_SCALE)
	draw_circle(Vector2(0, 0), 9.0, Color("9BD45A", 0.08))
	# Torn sleeve at the back.
	draw_colored_polygon(PackedVector2Array([Vector2(-17, -5.5), Vector2(-10, -6), Vector2(-12, -3), Vector2(-9, -1), Vector2(-12, 2), Vector2(-9, 5.5), Vector2(-17, 5.5)]), SLEEVE)
	# Forearm with a stitched wound.
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -3.6), Vector2(2, -3.0), Vector2(2, 3.0), Vector2(-11, 3.6)]), SKIN_DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -3.4), Vector2(2, -2.8), Vector2(2, -0.4), Vector2(-11, -0.6)]), SKIN)
	draw_circle(Vector2(-4.5, 1.2), 1.7, Color("5A1E22"))
	draw_line(Vector2(-5.6, 1.2), Vector2(-3.4, 1.2), Color("EDE3C8"), 1.2)
	draw_line(Vector2(-8.5, -2.5), Vector2(-7.5, 2.5), Color("2B2A1E"), 0.9)
	# Palm and clawing fingers.
	draw_circle(Vector2(4.5, 0), 4.6, SKIN_DARK)
	draw_circle(Vector2(4.2, -0.6), 3.6, SKIN)
	draw_circle(Vector2(3.6, -1.6), 1.4, SKIN_HI)
	var curl := 0.5 + 0.5 * sin(_age * 9.0)
	for spec in [[-0.62, 1.0], [-0.2, 1.0], [0.2, -1.0], [0.6, -1.0]]:
		var a: float = spec[0] * (1.0 - 0.45 * curl)
		var base := Vector2(4.5, 0) + Vector2.from_angle(a) * 3.8
		var mid := base + Vector2.from_angle(a) * 4.0
		var tip := mid + Vector2.from_angle(a + float(spec[1]) * (0.3 + 1.1 * curl)) * 3.4
		draw_polyline(PackedVector2Array([base, mid, tip]), SKIN_DARK, 2.6)
		draw_polyline(PackedVector2Array([base, mid, tip]), SKIN, 1.5)
		draw_circle(tip, 0.9, Color("E8DDAA"))
	# Thumb.
	draw_polyline(PackedVector2Array([Vector2(3, 3.5), Vector2(5.5, 6.0), Vector2(8.5, 6.2)]), SKIN_DARK, 2.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
