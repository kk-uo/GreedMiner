class_name FusionKnockbackWave
extends Node2D

## A travelling, 100px-wide shock front. Damage after contact is dealt once
## per second while the wave exists, even if the first impact knocked a target
## out of the front. A target can only receive the initial hit once per wave.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 250.0
var maximum_distance: float = 1000.0
var wave_length: float = 100.0
var wave_thickness: float = 20.0
var initial_damage: float = 15.0
var damage_per_second: float = 1.0
var knockback_distance: float = 200.0
var source_weapon: WeaponModule

var _origin: Vector2
var _contacts: Dictionary = {}


func arm_from_current_position() -> void:
	_origin = global_position


func _ready() -> void:
	_origin = global_position
	queue_redraw()


func _physics_process(delta: float) -> void:
	var travel := direction.normalized()
	global_position += travel * speed * delta
	if _origin.distance_to(global_position) >= maximum_distance:
		queue_free()
		return

	var shape := RectangleShape2D.new()
	shape.size = Vector2(wave_thickness, wave_length)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(travel.angle(), global_position)
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_shape(query, 256):
		var enemy := result.get("collider") as BasicEnemy
		if enemy == null or enemy.is_dying() or not enemy.is_in_group(&"enemies"):
			continue
		var key := enemy.get_instance_id()
		if not _contacts.has(key):
			_contacts[key] = {"enemy": enemy, "elapsed": 0.0}
			_apply_initial_hit(enemy, travel)

	for key in _contacts.keys():
		var state: Dictionary = _contacts[key]
		var enemy: BasicEnemy = state["enemy"]
		if not is_instance_valid(enemy) or enemy.is_dying():
			_contacts.erase(key)
			continue
		state["elapsed"] = float(state["elapsed"]) + delta
		while float(state["elapsed"]) >= 1.0:
			state["elapsed"] = float(state["elapsed"]) - 1.0
			enemy.take_damage(damage_per_second, false, true, source_weapon if is_instance_valid(source_weapon) else null)
			if enemy.is_dying():
				break
	queue_redraw()


func _apply_initial_hit(enemy: BasicEnemy, travel: Vector2) -> void:
	var before := enemy.get_current_health()
	enemy.take_damage(initial_damage, false, true, source_weapon if is_instance_valid(source_weapon) else null)
	if is_instance_valid(source_weapon) and is_instance_valid(enemy):
		source_weapon.projectile_hit.emit(enemy, maxf(before - enemy.get_current_health(), 0.0))
	if enemy.is_dying() or enemy.enemy_tier == BasicEnemy.EnemyTier.BOSS:
		return
	var battlefield := get_tree().get_first_node_in_group(&"battlefield") as Battlefield
	var bounds := battlefield.get_world_bounds() if battlefield != null else Rect2()
	enemy.apply_radial_knockback(enemy.global_position - travel * 10.0, knockback_distance, bounds)


func _draw() -> void:
	var half_length := wave_length * 0.5
	draw_set_transform(Vector2.ZERO, direction.angle(), Vector2.ONE)
	FusionArt.draw_wave(self, half_length, wave_thickness, float(Time.get_ticks_msec()) * 0.001)
