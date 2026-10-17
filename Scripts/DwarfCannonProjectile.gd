class_name DwarfCannonProjectile
extends Area2D

## A fast cannonball that damages every enemy in a circular impact area.

@export var speed: float = 800.0
@export var damage: float = 20.0
@export var explosion_radius: float = 20.0
@export var maximum_lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var _remaining_lifetime: float
var _has_exploded: bool = false
var _damage_applied: bool = false


func _ready() -> void:
	_remaining_lifetime = maximum_lifetime
	var callback := Callable(self, "_on_area_entered")
	if not area_entered.is_connected(callback):
		area_entered.connect(callback)
	queue_redraw()


func _draw() -> void:
	# Style A: heavy shell with a hot core and its own hard shadow.
	draw_circle(Palette.SHADOW_OFFSET * 0.6, 6.5, Palette.SHADOW_COLOR)
	draw_circle(Vector2.ZERO, 6.5, Palette.ACCENT)
	draw_circle(Vector2(-1.5, -1.5), 3.0, Palette.SHOT_CORE)


func _physics_process(delta: float) -> void:
	if _has_exploded:
		return

	global_position += direction.normalized() * speed * delta
	_remaining_lifetime -= delta

	if _remaining_lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _has_exploded or not area is BasicEnemy:
		return

	_has_exploded = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	call_deferred("_explode")


## Queries a circular physics shape so every overlapping enemy is damaged.
func _explode() -> void:
	if _damage_applied:
		return

	_damage_applied = true
	var explosion_shape := CircleShape2D.new()
	explosion_shape.radius = explosion_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = explosion_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results := get_world_2d().direct_space_state.intersect_shape(query, 128)
	var damaged_enemy_ids: Dictionary = {}

	for result in results:
		var collider: Object = result.get("collider")
		if not collider is BasicEnemy:
			continue

		var enemy := collider as BasicEnemy
		if not enemy.is_in_group("enemies"):
			continue

		var enemy_id := enemy.get_instance_id()
		if damaged_enemy_ids.has(enemy_id):
			continue

		damaged_enemy_ids[enemy_id] = true
		enemy.take_damage(damage)

	FlatBurst.spawn(get_parent(), global_position, explosion_radius + 10.0, Palette.SHOT)
	print("Cannonball exploded! Enemies hit: ", damaged_enemy_ids.size())
	queue_free()
