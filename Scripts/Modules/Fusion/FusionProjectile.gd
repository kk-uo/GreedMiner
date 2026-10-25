class_name FusionProjectile
extends Area2D

var direction := Vector2.RIGHT
var damage: float = 5.0
var speed: float = 400.0
var maximum_distance: float = 400.0
var projectile_range: float = 4.0
var pierces_all_targets: bool = false
var aoe_radius: float = 0.0
var knockback_distance: float = 0.0
var post_knockback_aoe_radius: float = 0.0
var post_knockback_damage_ratio: float = 0.0
var post_knockback_damage: float = 0.0
var leaves_fire: bool = false
var fire_patch_duration: float = 3.0
var fire_patch_damage: float = 0.0
var fire_patch_radius: float = 42.0
var fire_patch_tick_interval: float = 0.5
var visual_kind: int = FusionWeapon.VisualKind.SCATTER
var source_weapon: WeaponModule
var _origin := Vector2.ZERO
var _resolved := false
var _spin := 0.0
var _ghost: RefCounted
var _hit_ids: Dictionary = {}


## Ghost Bullet uses the same per-projectile penetration state as the base
## Machine Gun and Dwarf Cannon. Fusion weapons opt in through the shared
## WeaponModule artifact provider, so no artifact-specific recipe code is
## required here.
func enable_ghost_piercing(initial_pierces: int) -> void:
	_ghost = preload("res://Scripts/Modules/Weapons/GhostProjectileState.gd").new(initial_pierces)


## FusionWeapon adds the projectile before assigning its world-space muzzle
## position. Re-arm afterwards so travel distance is measured from the muzzle,
## not from the scene origin captured by _ready().
func arm_from_current_position() -> void:
	_origin = global_position


func _ready() -> void:
	_origin = global_position
	area_entered.connect(_on_area_entered)
	var collision := $CollisionShape2D as CollisionShape2D
	var circle := (collision.shape as CircleShape2D).duplicate() as CircleShape2D
	circle.radius = maxf(projectile_range, 0.5)
	collision.shape = circle
	queue_redraw()


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta
	_spin = fmod(_spin + delta * 12.0, TAU)
	queue_redraw()
	if _origin.distance_to(global_position) >= maximum_distance:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _resolved:
		return
	if area.is_in_group(&"destructible_props"):
		if pierces_all_targets and _hit_ids.has(area.get_instance_id()):
			return
		_hit_ids[area.get_instance_id()] = true
		_resolved = not pierces_all_targets
		area.call("take_damage", damage)
		_finish_impact(null, pierces_all_targets)
		return
	var enemy := area as BasicEnemy
	if enemy == null or enemy.is_dying() or not enemy.is_in_group(&"enemies"):
		return
	if _hit_ids.has(enemy.get_instance_id()):
		return
	_hit_ids[enemy.get_instance_id()] = true
	if not pierces_all_targets and _ghost != null and not _ghost.register_target(enemy):
		return
	var before := enemy.get_current_health()
	enemy.take_damage(damage, false, true, source_weapon if is_instance_valid(source_weapon) else null)
	if is_instance_valid(source_weapon) and is_instance_valid(enemy):
		source_weapon.projectile_hit.emit(enemy, maxf(before - enemy.get_current_health(), 0.0))
	var continues: bool = pierces_all_targets or (_ghost != null and bool(_ghost.continue_after_hit(not is_instance_valid(enemy) or enemy.is_dying())))
	_resolved = not continues
	_finish_impact(enemy, continues)


func _finish_impact(direct_target: BasicEnemy, continues: bool = false) -> void:
	if not continues:
		set_physics_process(false)
		set_deferred("monitoring", false)
	var impact := global_position
	if is_instance_valid(direct_target) and knockback_distance > 0.0 and direct_target.enemy_tier != BasicEnemy.EnemyTier.BOSS:
		direct_target.apply_radial_knockback(impact - direction.normalized(), knockback_distance, _battlefield_bounds())
		impact = direct_target.global_position
	if aoe_radius > 0.0:
		_damage_circle(impact, aoe_radius, damage, direct_target, knockback_distance > 0.0)
	if post_knockback_aoe_radius > 0.0 and post_knockback_damage > 0.0:
		_damage_circle(impact, post_knockback_aoe_radius, post_knockback_damage, null, false)
	if leaves_fire:
		var patch := FusionFirePatch.new()
		patch.damage = fire_patch_damage
		patch.duration = fire_patch_duration
		patch.radius = fire_patch_radius
		patch.tick_interval = fire_patch_tick_interval
		patch.source_weapon = source_weapon
		get_tree().current_scene.add_child(patch)
		patch.global_position = impact
	FlatBurst.spawn(get_parent(), impact, maxf(aoe_radius, projectile_range) + 8.0, _visual_color())
	if not continues:
		queue_free()


func _damage_circle(center: Vector2, radius: float, amount: float, excluded: BasicEnemy, apply_knockback: bool) -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit_ids: Dictionary = {}
	if is_instance_valid(excluded):
		hit_ids[excluded.get_instance_id()] = true
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 256):
		var enemy := hit.get("collider") as BasicEnemy
		if enemy == null or enemy.is_dying() or not enemy.is_in_group(&"enemies") or hit_ids.has(enemy.get_instance_id()):
			continue
		hit_ids[enemy.get_instance_id()] = true
		enemy.take_damage(amount, false, true, source_weapon if is_instance_valid(source_weapon) else null)
		if apply_knockback and is_instance_valid(enemy) and not enemy.is_dying() and enemy.enemy_tier != BasicEnemy.EnemyTier.BOSS:
			enemy.apply_radial_knockback(center, knockback_distance, _battlefield_bounds())


func _battlefield_bounds() -> Rect2:
	var battlefield := get_tree().get_first_node_in_group(&"battlefield") as Battlefield
	if battlefield == null and get_tree().current_scene != null:
		battlefield = get_tree().current_scene.get_node_or_null("Battlefield") as Battlefield
	return battlefield.get_world_bounds() if battlefield != null else Rect2()


var _art_id: StringName = &""
var _age: float = 0.0


func _draw() -> void:
	if _art_id.is_empty() and is_instance_valid(source_weapon):
		_art_id = StringName(source_weapon.get("weapon_type_id"))
	_age += get_physics_process_delta_time()
	var radius := maxf(projectile_range, 2.0)
	draw_set_transform(Vector2.ZERO, direction.angle(), Vector2.ONE)
	FusionArt.draw_projectile(self, _art_id, radius, _spin, _age)


func _visual_color() -> Color:
	match visual_kind:
		FusionWeapon.VisualKind.KNOCKBACK:
			return Color("8D70D9")
		FusionWeapon.VisualKind.FLAME:
			return Color("F05A32")
		FusionWeapon.VisualKind.CANNON:
			return Palette.ACCENT
	return Palette.SHOT
