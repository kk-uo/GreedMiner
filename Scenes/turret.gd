extends Node2D

## Represents the visual appearance of a rotating machine gun turret.
##
## This script only handles rendering.
## Target detection, rotation, and firing are controlled by MachineGun.gd.
##
## The turret faces local positive X (right) by default.


# ==========================================
# Turret Visual Configuration
# ==========================================

## Main body color.
@export var body_color: Color = Color.RED

## Barrel color.
@export var barrel_color: Color = Color.DARK_RED


# ==========================================
# Initialization
# ==========================================

func _ready() -> void:
	# Request the initial turret drawing.
	queue_redraw()


# ==========================================
# Turret Rendering
# ==========================================

func _draw() -> void:
	# Draw the main turret body (24x24 pixels).
	# The body is centered at the turret's origin.
	draw_rect(
		Rect2(-12.0, -12.0, 24.0, 24.0),
		body_color
	)

	# Draw the gun barrel (20x8 pixels).
	# The barrel points toward local positive X.
	# It rotates automatically with the Turret node.
	draw_rect(
		Rect2(0.0, -4.0, 20.0, 8.0),
		barrel_color
	)

	# Draw a small dark center to show the rotation axis.
	draw_circle(
		Vector2.ZERO,
		5.0,
		Color.DARK_GRAY
	)
