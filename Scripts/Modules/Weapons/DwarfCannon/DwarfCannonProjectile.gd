class_name DwarfCannonProjectile
extends Area2D

## A fast cannonball that damages every enemy in a circular impact area.

@export var speed: float = 800.0
@export var damage: float = 20.0
@export var explosion_radius: float = 20.0
@export var maximum_lifetime: float = 2.0
@export var debug_hit_logging: bool = false

## Collision radius and visual-size source assigned by DwarfCannon.
var projectile_range: float = 6.0:
	set(value):
		projectile_range = maxf(value, 0.1)
		_apply_projectile_range()

var direction: Vector2 = Vector2.RIGHT
var source_weapon: WeaponModule
var _direct_target: BasicEnemy
var _remaining_lifetime: float
var _has_exploded: bool = false
var _damage_applied: bool = false
var _ghost: RefCounted
var _ghost_impacts: Array[Dictionary] = []
const GHOST_SHOT_ART := preload("res://Scripts/VFX/GhostShotArt.gd")
var _ghost_time: float = 0.0

func enable_ghost_piercing(initial_pierces: int) -> void:
	_ghost = preload("res://Scripts/Modules/Weapons/GhostProjectileState.gd").new(initial_pierces)


func _ready() -> void:
	_remaining_lifetime = maximum_lifetime
	var callback := Callable(self, "_on_area_entered")
	if not area_entered.is_connected(callback):
		area_entered.connect(callback)
	_apply_projectile_range()
	queue_redraw()


func _apply_projectile_range() -> void:
	if not is_node_ready():
		return
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.scale = Vector2.ONE * (projectile_range / 6.0)
	queue_redraw()


func get_projectile_visual_scale() -> float:
	return projectile_range / 6.0


func _draw() -> void:
	var visual_scale := get_projectile_visual_scale()
	# Ghost Bullet: a translucent spirit-shell instead (presentation).
	if _ghost != null:
		if not _has_exploded:
			GHOST_SHOT_ART.draw(self, direction, _ghost_time, 6.0 * visual_scale, float(get_instance_id() % 97))
		return
	# Style A: heavy shell with a hot core and its own hard shadow.
	draw_circle(Palette.SHADOW_OFFSET * 0.6 * visual_scale, 6.5 * visual_scale, Palette.SHADOW_COLOR)
	draw_circle(Vector2.ZERO, 6.5 * visual_scale, Palette.ACCENT)
	draw_circle(Vector2(-1.5, -1.5) * visual_scale, 3.0 * visual_scale, Palette.SHOT_CORE)


func _physics_process(delta: float) -> void:
	if _has_exploded:
		return

	global_position += direction.normalized() * speed * delta
	_remaining_lifetime -= delta
	if _ghost != null:
		_ghost_time += delta
		queue_redraw()

	if _remaining_lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	# A tree in the way: the shell bursts on it.
	if not _has_exploded and area.is_in_group(&"destructible_props"):
		_has_exploded = true
		set_physics_process(false)
		set_deferred("monitoring", false)
		call_deferred("_explode")
		return
	if _has_exploded or not area is BasicEnemy or (area as BasicEnemy).is_dying():
		return
	if _ghost != null:
		var enemy := area as BasicEnemy
		if not _ghost.register_target(enemy):
			return
		_ghost_impacts.append({"target": enemy, "position": global_position})
		if _ghost_impacts.size() == 1:
			call_deferred("_resolve_ghost_impacts")
		return

	_direct_target = area as BasicEnemy
	_has_exploded = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	call_deferred("_explode")


## Queries a circular physics shape so every overlapping enemy is damaged.
func _explode() -> void:
	if _damage_applied:
		return

	_damage_applied = true
	_explode_at(global_position, _direct_target)
	queue_free()


## Defer physics queries but preserve every impact position and collision order.
func _resolve_ghost_impacts() -> void:
	while not _ghost_impacts.is_empty() and not _has_exploded:
		var impact: Dictionary = _ghost_impacts.pop_front()
		var enemy := impact["target"] as BasicEnemy
		if not is_instance_valid(enemy) or enemy.is_dying():
			continue
		var killed := _explode_at(impact["position"], enemy)
		if not _ghost.continue_after_hit(killed):
			_has_exploded = true
			queue_free()
	_ghost_impacts.clear()


func _explode_at(impact_position: Vector2, direct_target: BasicEnemy) -> bool:
	var explosion_shape := CircleShape2D.new()
	explosion_shape.radius = explosion_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = explosion_shape
	query.transform = Transform2D(0.0, impact_position)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results := get_world_2d().direct_space_state.intersect_shape(query, 128)
	var damaged_enemy_ids: Dictionary = {}

	for result in results:
		var collider: Object = result.get("collider")
		if collider is Node and (collider as Node).is_in_group(&"destructible_props"):
			if not damaged_enemy_ids.has(collider.get_instance_id()):
				damaged_enemy_ids[collider.get_instance_id()] = true
				collider.call("take_damage", damage)
			continue
		if not collider is BasicEnemy:
			continue

		var enemy := collider as BasicEnemy
		if not enemy.is_in_group("enemies"):
			continue

		var enemy_id := enemy.get_instance_id()
		if damaged_enemy_ids.has(enemy_id):
			continue

		damaged_enemy_ids[enemy_id] = true
		var before := enemy.get_current_health()
		enemy.take_damage(damage, false, true, source_weapon if is_instance_valid(source_weapon) else null)
		if enemy == direct_target and is_instance_valid(source_weapon) and is_instance_valid(enemy):
			source_weapon.projectile_hit.emit(enemy, maxf(before - enemy.get_current_health(), 0.0))

	FlatBurst.spawn(get_parent(), impact_position, explosion_radius + 10.0, Palette.SHOT)
	if debug_hit_logging:
		print("Cannonball exploded! Enemies hit: ", damaged_enemy_ids.size())
	return not is_instance_valid(direct_target) or direct_target.is_dying()
