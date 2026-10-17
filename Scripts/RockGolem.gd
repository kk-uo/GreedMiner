class_name RockGolem
extends BasicEnemy

## Large melee enemy that splits into two Little Rocks when killed.

## Scene created by this enemy's death effect.
@export var split_enemy_scene: PackedScene

## Local offsets keep the two spawned enemies from overlapping completely.
@export var split_offset: float = 18.0


## Spawns exactly two fully initialized Little Rocks at the death position.
func _perform_death_effect() -> void:
	if split_enemy_scene == null:
		push_warning("Rock Golem: Little Rock split scene is missing.")
		return

	var spawn_parent := get_parent()
	if spawn_parent == null:
		return

	var death_position := global_position
	var offsets := [
		Vector2(-split_offset, 0.0),
		Vector2(split_offset, 0.0),
	]

	for offset in offsets:
		var little_rock := split_enemy_scene.instantiate() as LittleRock
		if little_rock == null:
			push_error("Rock Golem: Split scene must use LittleRock.gd.")
			continue

		little_rock.target_ship = target_ship
		little_rock.position = spawn_parent.to_local(death_position + offset)
		# Deferred insertion is safe even when death occurs inside a physics query.
		spawn_parent.call_deferred("add_child", little_rock)


const BODY := [
	Vector2(-24.0, -8.0), Vector2(-17.0, -21.0), Vector2(-2.0, -26.0),
	Vector2(13.0, -22.0), Vector2(22.0, -12.0), Vector2(25.0, 0.0),
	Vector2(22.0, 12.0), Vector2(13.0, 22.0), Vector2(-2.0, 26.0),
	Vector2(-17.0, 21.0), Vector2(-24.0, 8.0),
]
## Fists in front, stone spikes on the back.
const PARTS := [
	[Vector2(12.0, -27.0), Vector2(25.0, -23.0), Vector2(30.0, -12.0), Vector2(19.0, -12.0)],
	[Vector2(12.0, 27.0), Vector2(25.0, 23.0), Vector2(30.0, 12.0), Vector2(19.0, 12.0)],
	[Vector2(-17.0, -17.0), Vector2(-29.0, -22.0), Vector2(-23.0, -10.0)],
	[Vector2(-17.0, 17.0), Vector2(-29.0, 22.0), Vector2(-23.0, 10.0)],
	[Vector2(-23.0, -4.0), Vector2(-33.0, 0.0), Vector2(-23.0, 4.0)],
]
const FACET := [
	Vector2(-17.0, -21.0), Vector2(-2.0, -26.0), Vector2(13.0, -22.0),
	Vector2(6.0, -12.0), Vector2(-10.0, -12.0),
]
const FIST_FACET := [
	Vector2(12.0, -27.0), Vector2(25.0, -23.0), Vector2(22.0, -19.0), Vector2(14.0, -21.0),
]


func _get_visual_radius() -> float:
	return 28.0


## Style A: big dark stone silhouette, fists forward, two red threat cores.
func _draw() -> void:
	draw_set_transform(Palette.SHADOW_OFFSET * 1.2, _facing, Vector2.ONE)
	_draw_silhouette(Palette.SHADOW_COLOR)

	draw_set_transform(Vector2.ZERO, _facing, Vector2.ONE)
	_draw_silhouette(_flash(Palette.ENEMY))
	if not _is_flashing():
		draw_colored_polygon(PackedVector2Array(FACET), Palette.ENEMY_LIGHT)
		draw_colored_polygon(PackedVector2Array(FIST_FACET), Palette.ENEMY_LIGHT)
		draw_polyline(PackedVector2Array([
			Vector2(-12.0, 3.0), Vector2(-4.0, 9.0), Vector2(-8.0, 18.0),
		]), Palette.ENEMY_LIGHT, 2.0)
		draw_circle(Vector2(12.0, -7.0), 4.5, Palette.THREAT)
		draw_circle(Vector2(12.0, 7.0), 4.5, Palette.THREAT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_silhouette(color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(BODY), color)
	for part in PARTS:
		draw_colored_polygon(PackedVector2Array(part), color)
