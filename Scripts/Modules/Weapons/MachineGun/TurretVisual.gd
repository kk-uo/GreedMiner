extends Node2D

## Machine gun turret visual (style A). Rendering only; MachineGun.gd aims and fires.
## The barrel points along local +X so the Turret node can rotate freely.

var _drawn_rotation: float = INF


func _ready() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	# The shadow is fixed in world space, so redraw only when the aim changes.
	if not is_equal_approx(global_rotation, _drawn_rotation):
		queue_redraw()


func _draw() -> void:
	_drawn_rotation = global_rotation
	var shadow := Palette.local_shadow_offset(self)
	Palette.draw_turret_base(self, 18.0, shadow)

	# Twin barrels with safety-orange muzzles.
	var barrels := [Rect2(4.0, -7.0, 22.0, 5.0), Rect2(4.0, 2.0, 22.0, 5.0)]
	for barrel in barrels:
		draw_rect(Rect2((barrel as Rect2).position + shadow * 0.5, (barrel as Rect2).size), Palette.SHADOW_COLOR)
	for barrel in barrels:
		draw_rect(barrel, Palette.MECH)
		draw_rect(Rect2((barrel as Rect2).position + Vector2(18.0, -0.5), Vector2(5.0, 6.0)), Palette.ACCENT)

	# Square receiver with a top-left highlight.
	Palette.draw_rounded_rect(self, Rect2(-11.0, -11.0, 22.0, 22.0), 4.0, Palette.MECH)
	Palette.draw_rounded_rect(self, Rect2(-9.0, -9.0, 9.0, 9.0), 2.0, Palette.MECH_LIGHT)
