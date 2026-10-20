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
var source_weapon: WeaponModule
var _hit: bool = false


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


# ==========================================
# Collision Detection
# ==========================================

func _on_area_entered(area: Area2D) -> void:
	# Check whether the collided Area2D
	# is an instance of BasicEnemy.
	if not _hit and area is BasicEnemy and not (area as BasicEnemy).is_dying():
		var enemy := area as BasicEnemy
		_hit = true
		var before := enemy.get_current_health()

		# Apply projectile damage to the enemy.
		enemy.take_damage(damage, false, true, source_weapon if is_instance_valid(source_weapon) else null)
		if is_instance_valid(source_weapon) and is_instance_valid(enemy):
			source_weapon.projectile_hit.emit(enemy, maxf(before - enemy.get_current_health(), 0.0))

		# Print a debug message.
		print("Projectile hit enemy! Damage: %s" % damage)

		# Remove the projectile after impact.
		queue_free()
