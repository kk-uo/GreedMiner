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
	# Draw a temporary yellow circle.
	# The circle is centered on the projectile.
	draw_circle(
		Vector2.ZERO,
		4.0,
		Color.YELLOW
	)


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
	if area is BasicEnemy:
		var enemy := area as BasicEnemy

		# Apply projectile damage to the enemy.
		enemy.take_damage(damage)

		# Print a debug message.
		print("Projectile hit enemy! Damage: %s" % damage)

		# Remove the projectile after impact.
		queue_free()
