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
const GHOST_SHOT_ART := preload("res://Scripts/VFX/GhostShotArt.gd")
var _ghost_time: float = 0.0

func enable_ghost_piercing(initial_pierces: int) -> void:
	_ghost = preload("res://Scripts/Modules/Weapons/GhostProjectileState.gd").new(initial_pierces)


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


# ==========================================
# Projectile Rendering
# ==========================================

func _draw() -> void:
	# Ghost Bullet: a translucent spirit-shot instead (presentation).
	if _ghost != null:
		GHOST_SHOT_ART.draw(self, direction, _ghost_time, 3.0, float(get_instance_id() % 97))
		return
	# Style A: a short warm capsule aligned with its flight direction.
	draw_set_transform(Vector2.ZERO, direction.angle(), Vector2.ONE)
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
		if _ghost == null or not _ghost.continue_after_hit(not is_instance_valid(enemy) or enemy.is_dying()):
			_hit = true
			queue_free()
