class_name MachineGunProjectile
extends Area2D

## Represents a projectile fired by the MachineGun.
##
## The projectile moves in a specified direction,
## detects collisions with enemies, deals damage,
## and disappears after hitting an enemy.

# ==========================================
# Projectile Statistics
# ==========================================

# Movement speed in pixels per second.
@export var speed: float = 400.0

# Collision radius and visual-size source assigned by MachineGun.
var projectile_range: float = 4.0:
	set(value):
		projectile_range = maxf(value, 0.1)
		_apply_projectile_range()

# Direction in which the projectile travels.
# Default direction is right (1, 0).
var direction: Vector2 = Vector2.RIGHT

# Damage dealt when the projectile hits an enemy.
# The MachineGun assigns its own damage when firing.
var damage: float = 5.0
@export var debug_hit_logging: bool = false
var source_weapon: WeaponModule
var _hit: bool = false
var _ghost: RefCounted
var _ghost_visual_enabled: bool = false
var _homing_target: BasicEnemy
var _homing_ignored: Dictionary = {}
const GHOST_SHOT_ART := preload("res://Scripts/VFX/GhostShotArt.gd")
var _ghost_time: float = 0.0

func enable_ghost_piercing(initial_pierces: int, replenish_on_kill: bool = true, ghost_visual: bool = true) -> void:
	_ghost = preload("res://Scripts/Modules/Weapons/GhostProjectileState.gd").new(initial_pierces, replenish_on_kill)
	_ghost_visual_enabled = ghost_visual


# ==========================================
# Initialization
# ==========================================

func _ready() -> void:
	# Connect the area_entered signal to our
	# collision detection method.
	#
	# This signal is triggered when another
	# Area2D enters this projectile's collision area.
	area_entered.connect(_on_area_entered)
	_apply_projectile_range()


func _apply_projectile_range() -> void:
	if not is_node_ready():
		return
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.scale = Vector2.ONE * (projectile_range / 4.0)
	queue_redraw()


func get_projectile_visual_scale() -> float:
	return projectile_range / 4.0


# ==========================================
# Projectile Rendering
# ==========================================

func _draw() -> void:
	var visual_scale := get_projectile_visual_scale()
	# Ghost Bullet: a translucent spirit-shot instead (presentation).
	if _ghost_visual_enabled:
		GHOST_SHOT_ART.draw(self, direction, _ghost_time, 3.0 * visual_scale, float(get_instance_id() % 97))
		return
	# Style A: a short warm capsule aligned with its flight direction.
	draw_set_transform(Vector2.ZERO, direction.angle(), Vector2.ONE * visual_scale)
	draw_rect(Rect2(-5.0, -2.5, 10.0, 5.0), Palette.SHOT)
	draw_circle(Vector2(-5.0, 0.0), 2.5, Palette.SHOT)
	draw_circle(Vector2(5.0, 0.0), 2.5, Palette.SHOT_CORE)


# ==========================================
# Projectile Movement
# ==========================================

func _process(delta: float) -> void:
	# Move the projectile every frame.
	#
	# normalized() ensures consistent speed.
	# delta makes movement frame-rate independent.
	if is_instance_valid(source_weapon):
		var turn_rate := source_weapon.get_artifact_projectile_homing_turn_rate()
		if turn_rate > 0.0:
			var steering := source_weapon.get_homing_steering(global_position, direction, _homing_target, _homing_ignored, delta, turn_rate)
			_homing_target = steering["target"] as BasicEnemy
			direction = steering["direction"]
	position += direction.normalized() * speed * delta
	if _ghost != null:
		_ghost_time += delta
		queue_redraw()


# ==========================================
# Collision Detection
# ==========================================

func _on_area_entered(area: Area2D) -> void:
	# A tree (or other destructible prop) in the way stops the bullet.
	if not _hit and area.is_in_group(&"destructible_props"):
		_hit = true
		area.call("take_damage", damage)
		queue_free()
		return
	# Check whether the collided Area2D
	# is an instance of BasicEnemy.
	if not _hit and area is BasicEnemy and not (area as BasicEnemy).is_dying():
		var enemy := area as BasicEnemy
		if is_instance_valid(source_weapon) and not source_weapon.can_target_enemy(enemy):
			return
		if _ghost != null and not _ghost.register_target(enemy):
			return
		var before := enemy.get_current_health()

		# Apply projectile damage to the enemy.
		enemy.take_damage(damage, false, true, source_weapon if is_instance_valid(source_weapon) else null)
		if is_instance_valid(source_weapon) and is_instance_valid(enemy):
			source_weapon.projectile_hit.emit(enemy, maxf(before - enemy.get_current_health(), 0.0))

		if debug_hit_logging:
			print("Projectile hit enemy! Damage: %s" % damage)

		# A kill replenishes one penetration before this impact consumes it.
		var continues: bool = _ghost != null and bool(_ghost.continue_after_hit(not is_instance_valid(enemy) or enemy.is_dying()))
		if continues:
			_homing_ignored[enemy.get_instance_id()] = true
			_homing_target = null
		else:
			_hit = true
			queue_free()
