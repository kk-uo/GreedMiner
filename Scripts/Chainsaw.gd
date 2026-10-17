class_name Chainsaw
extends WeaponModule

## A continuous melee weapon that damages every enemy touching its saw area.

## Damage applied to each overlapping enemy per tick.
@export var basic_damage: float = 10.0

## Seconds between circular melee damage ticks.
@export var attack_interval: float = 0.1

## Radius of the independently adjustable circular attack region.
@export var attack_radius: float = 80.0

## Visual blade speed in radians per second during battle.
@export var blade_rotation_speed: float = 10.0

@onready var _attack_area: Area2D = $AttackArea
@onready var _attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D

var _attack_cooldown: float = 0.0
var _blade_rotation: float = 0.0


func get_damage() -> float:
	return basic_damage


func get_fire_rate() -> float:
	if attack_interval <= 0.0:
		return 0.0

	return 1.0 / attack_interval


func _ready() -> void:
	# Give every Chainsaw its own editable collision shape resource.
	var circle := _attack_shape.shape.duplicate() as CircleShape2D
	if circle == null:
		push_error("Chainsaw: AttackArea requires a CircleShape2D.")
		return

	circle.radius = maxf(attack_radius, 0.0)
	_attack_shape.shape = circle
	queue_redraw()


func _process(delta: float) -> void:
	# The blade remains visible but stationary in the assembly base.
	if assembly_mode:
		return

	_blade_rotation = fmod(
		_blade_rotation + blade_rotation_speed * delta,
		TAU
	)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if assembly_mode or attack_interval <= 0.0:
		_attack_cooldown = 0.0
		return

	_attack_cooldown -= delta
	while _attack_cooldown <= 0.0:
		fire()
		_attack_cooldown += attack_interval


## Damages every enemy whose collision shape overlaps the circular saw area.
func fire() -> void:
	if assembly_mode or not is_inside_tree():
		return

	var damaged_enemy_ids: Dictionary = {}

	for area in _attack_area.get_overlapping_areas():
		if not area is BasicEnemy:
			continue

		var enemy := area as BasicEnemy
		if not enemy.is_in_group("enemies"):
			continue

		var enemy_id := enemy.get_instance_id()
		if damaged_enemy_ids.has(enemy_id):
			continue

		damaged_enemy_ids[enemy_id] = true
		enemy.take_damage(basic_damage)


func _exit_tree() -> void:
	# Prevent any further ticks as soon as the module leaves the scene tree.
	set_physics_process(false)
	_attack_cooldown = 0.0


## Draws a compact industrial saw blade centered in one 64x64 cell.
func _draw() -> void:
	# Style A: flat saw blade on a gunmetal mount, one hard shadow.
	draw_circle(Palette.SHADOW_OFFSET * 0.6, 25.0, Palette.SHADOW_COLOR)
	draw_circle(Vector2.ZERO, 26.0, Palette.MECH)

	draw_set_transform(Vector2.ZERO, _blade_rotation, Vector2.ONE)
	var teeth := PackedVector2Array()
	var tooth_count: int = 12
	for point_index in range(tooth_count * 2):
		var radius := 23.0 if point_index % 2 == 0 else 18.0
		var angle := TAU * float(point_index) / float(tooth_count * 2)
		teeth.append(Vector2.RIGHT.rotated(angle) * radius)

	draw_colored_polygon(teeth, Palette.SHIP_SHADOW)
	draw_circle(Vector2.ZERO, 16.0, Palette.SHIP_BODY)
	draw_rect(Rect2(-12.0, -2.0, 24.0, 4.0), Palette.SHIP_SEAM)
	draw_rect(Rect2(-2.0, -12.0, 4.0, 24.0), Palette.SHIP_SEAM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The hub does not spin, so its highlight stays top-left.
	draw_circle(Vector2.ZERO, 8.0, Palette.MECH)
	draw_circle(Vector2(-2.0, -2.0), 3.0, Palette.MECH_LIGHT)
	draw_circle(Vector2(1.5, 1.5), 2.5, Palette.ACCENT)
