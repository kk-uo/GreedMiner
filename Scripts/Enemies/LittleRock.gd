class_name LittleRock
extends BasicEnemy

## Small common melee enemy used by the Rocky Planet enemy family.


const BODY := [
	Vector2(-12.0, -4.0), Vector2(-7.0, -10.0), Vector2(2.0, -11.0),
	Vector2(9.0, -7.0), Vector2(14.0, 0.0), Vector2(9.0, 7.0),
	Vector2(2.0, 11.0), Vector2(-7.0, 10.0), Vector2(-12.0, 4.0),
]
const LEGS := [
	[Vector2(-4.0, -9.0), Vector2(-1.0, -15.0), Vector2(3.0, -9.0)],
	[Vector2(-4.0, 9.0), Vector2(-1.0, 15.0), Vector2(3.0, 9.0)],
]
const FACET := [
	Vector2(-7.0, -10.0), Vector2(2.0, -11.0), Vector2(9.0, -7.0),
	Vector2(3.0, -4.0), Vector2(-6.0, -5.0),
]


## Style A: dark stone silhouette facing the ship, one red threat core.
func _draw() -> void:
	draw_set_transform(Palette.SHADOW_OFFSET * 0.7, _facing, Vector2.ONE)
	_draw_silhouette(Palette.SHADOW_COLOR)

	draw_set_transform(Vector2.ZERO, _facing, Vector2.ONE)
	_draw_silhouette(_flash(Palette.ENEMY))
	if not _is_flashing():
		draw_colored_polygon(PackedVector2Array(FACET), Palette.ENEMY_LIGHT)
		draw_circle(Vector2(5.0, 0.0), 3.2, Palette.THREAT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_silhouette(color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(BODY), color)
	for leg in LEGS:
		draw_colored_polygon(PackedVector2Array(leg), color)
