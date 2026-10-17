class_name MiningModule
extends Node2D

## Amount of ore produced per second.
@export var mining_rate: float = 1.0


## Draws the drill module (style A): bone plate, gunmetal drill, orange chevrons.
func _draw() -> void:
	var plate := Rect2(-22.0, -22.0, 44.0, 44.0)
	Palette.draw_rounded_rect(self, Rect2(plate.position + Palette.SHADOW_OFFSET * 0.6, plate.size), 6.0, Palette.SHADOW_COLOR)
	Palette.draw_rounded_rect(self, plate, 6.0, Palette.SHIP_PART_EDGE)
	Palette.draw_rounded_rect(self, Rect2(-22.0, -22.0, 42.0, 41.0), 6.0, Palette.SHIP_PART)

	# Drill head points toward local +X, like every other module.
	draw_circle(Vector2.ZERO, 14.0, Palette.MECH)
	draw_circle(Vector2(-4.0, -4.0), 5.0, Palette.MECH_LIGHT)
	for x in [-5.0, 3.0]:
		draw_polyline(PackedVector2Array([
			Vector2(x, -7.0), Vector2(x + 6.0, 0.0), Vector2(x, 7.0),
		]), Palette.ACCENT, 3.0)

	# A gold glint marks an active drill: the only saturated color on the ship.
	if mining_enabled:
		Palette.draw_crystal(self, Vector2(15.0, -15.0), 0.3)


func _on_mining_timer_timeout() -> void:
	if not mining_enabled:
		return

	ResourceManager.add_mission_ore(mining_rate)


## Whether this module is currently producing ore.
@export var mining_enabled: bool = true

## Enables or disables ore production.
func set_mining_enabled(enabled: bool) -> void:
	mining_enabled = enabled

	queue_redraw()
	if mining_enabled:
		$MiningTimer.start()
	else:
		$MiningTimer.stop()
