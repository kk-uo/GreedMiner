extends RefCounted

## Dwarven-tech vault door set into the asteroid's bottom-right wall: the base
## entrance to the Warehouse. Drawn by AsteroidHangar in mock coordinates.
## Load with preload(); no class_name on purpose.
##
## Local frame: x runs along the wall, y > 0 goes into the rock, y < 0 faces
## the hall floor. Plain stone octagon frame with four runes, a bronze door
## ring with locking bolts and a hinge, a steel door with a three-spoke
## handwheel and a cyan core. Hovering swings the door open.

## Door centre on the 1280x720 mock canvas and the wall direction there.
const CENTER := Vector2(1049.0, 564.0)
const ANGLE: float = -0.675
## Local drawing units to mock units.
const DRAW_SCALE: float = 1.2
const HIT_RADIUS: float = 52.0
## Seconds for the door to swing fully open / closed.
const OPEN_TIME: float = 0.45

const STONE_DARK := Color("3E3128")
const STONE := Color("6E5D4F")
const STONE_LIGHT := Color("8C7866")
const BRONZE_DARK := Color("8A4F22")
const BRONZE := Color("B87333")
const BRONZE_LIGHT := Color("E0A15A")
const STEEL_DARK := Color("33363A")
const STEEL := Color("575C63")
const STEEL_LIGHT := Color("7D838B")
const RUNE := Color("5FE6EE")
const RUNE_DIM := Color("2C7F86")

## Simple angular rune strokes (local, about ±6 units).
const RUNES := [
	[Vector2(-4, -6), Vector2(0, 6), Vector2(4, -6)],
	[Vector2(-3, 6), Vector2(-3, -6), Vector2(3, -2), Vector2(-3, 2)],
	[Vector2(0, -6), Vector2(0, 6), Vector2(-4, -2), Vector2(0, 1), Vector2(4, -2)],
	[Vector2(-4, 6), Vector2(0, -6), Vector2(4, 6)],
	[Vector2(-3, -6), Vector2(3, 6), Vector2(0, 0), Vector2(3, -6), Vector2(-3, 6)],
]


## Unit vector from the door toward the hall floor (mock space).
static func floor_direction() -> Vector2:
	return Vector2(0.0, -1.0).rotated(ANGLE)


static func contains(mock_point: Vector2) -> bool:
	return mock_point.distance_to(CENTER) <= HIT_RADIUS


## Draws the vault. `open_amount` (0..1) swings the door open on its hinge:
## the locking bolts retract first, then the door turns away from the wall and
## reveals the lit store room behind it. `hovered` adds the white hover frame.
static func draw(canvas: CanvasItem, layout_scale: float, _time: float, open_amount: float, hovered: bool) -> void:
	var base := Transform2D(ANGLE, Vector2.ONE * layout_scale * DRAW_SCALE, 0.0, CENTER * layout_scale)
	canvas.draw_set_transform_matrix(base)
	var open := clampf(open_amount, 0.0, 1.0)
	var swing := smoothstep(0.25, 1.0, open)
	var retract := smoothstep(0.0, 0.3, open)
	var rune_color := RUNE_DIM.lerp(RUNE, open)

	# Shadow, then a stepped stone threshold on the floor side.
	_octagon(canvas, Vector2(5.0, 6.0), 42.0, Color(0.0, 0.0, 0.0, 0.3))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-30, -48), Vector2(30, -48), Vector2(36, -38), Vector2(-36, -38)]), STONE_LIGHT)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-36, -38), Vector2(36, -38), Vector2(40, -30), Vector2(-40, -30)]), STONE)

	# Plain stone frame with four runes.
	_octagon(canvas, Vector2.ZERO, 42.0, STONE_DARK)
	_octagon(canvas, Vector2.ZERO, 38.0, STONE)
	for index in range(4):
		var angle := TAU * float(index) / 4.0 + PI / 4.0
		_rune(canvas, Vector2.RIGHT.rotated(angle) * 35.0, angle + PI * 0.5, 0.42, rune_color, index)

	# The store room behind the door: a dark round opening with cyan light and
	# a couple of crates, revealed as the door swings away.
	canvas.draw_circle(Vector2.ZERO, 30.0, Color("17110D"))
	if swing > 0.0:
		canvas.draw_circle(Vector2(4.0, 4.0), 24.0, Color(RUNE, 0.10 * swing))
		canvas.draw_circle(Vector2(4.0, 4.0), 14.0, Color(RUNE, 0.12 * swing))
		_crate(canvas, Vector2(-2.0, 8.0), Color(1.0, 1.0, 1.0, swing))
		_crate(canvas, Vector2(12.0, -6.0), Color(1.0, 1.0, 1.0, swing * 0.85))

	# Hinge straps on the left edge (fixed to the frame).
	for y in [-13.0, 9.0]:
		Palette.draw_rounded_rect(canvas, Rect2(Vector2(-45.0, y), Vector2(16.0, 6.0)), 1.5, STEEL_DARK)
	Palette.draw_rounded_rect(canvas, Rect2(Vector2(-47.0, -16.0), Vector2(6.0, 30.0)), 2.0, STEEL)

	# The door itself, drawn through a hinge transform: as it opens it narrows
	# toward the hinge and tips out toward the hall floor.
	var hinge_x := -31.0
	var c := cos(swing * 1.35)
	var lift := sin(swing * 1.35) * 0.45
	var door := Transform2D(Vector2(c, -lift), Vector2(0.0, 1.0), Vector2(hinge_x - c * hinge_x, lift * hinge_x))
	canvas.draw_set_transform_matrix(base * door)
	if swing > 0.0:
		# Door thickness, visible once it turns.
		canvas.draw_circle(Vector2(2.5, 3.5), 31.0, Color(0.0, 0.0, 0.0, 0.35 * swing))
		canvas.draw_circle(Vector2(-3.0 * swing, 0.0), 31.0, BRONZE_DARK.darkened(0.3))

	# Locking bolts slide back into the door before it swings.
	var bolt_reach := lerpf(37.0, 27.0, retract)
	for index in range(8):
		var angle := TAU * float(index) / 8.0 + PI / 8.0
		if absf(angle_difference(angle, PI)) < 0.5:
			continue  # the hinge side has no bolts
		var direction := Vector2.RIGHT.rotated(angle)
		var side := direction.orthogonal() * 3.0
		canvas.draw_colored_polygon(PackedVector2Array([direction * 26.0 - side, direction * bolt_reach - side, direction * bolt_reach + side, direction * 26.0 + side]), STEEL_LIGHT)

	canvas.draw_circle(Vector2.ZERO, 31.0, BRONZE_DARK)
	canvas.draw_circle(Vector2(-0.8, -0.8), 29.0, BRONZE)
	canvas.draw_circle(Vector2.ZERO, 23.0, STEEL_DARK)
	canvas.draw_circle(Vector2(-0.6, -0.6), 22.0, STEEL)

	# Three-spoke handwheel; it turns while the bolts retract.
	var spin := 0.35 + retract * 2.2
	for index in range(3):
		var direction := Vector2.RIGHT.rotated(spin + TAU * float(index) / 3.0)
		canvas.draw_line(direction * 4.0, direction * 15.0, STEEL_DARK, 3.6)
		canvas.draw_circle(direction * 16.0, 3.2, BRONZE_LIGHT)
	canvas.draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 40, STEEL_DARK, 1.8)

	# Hexagonal core, glowing brighter as the vault unlocks.
	var hexagon := PackedVector2Array()
	var inner_hexagon := PackedVector2Array()
	for index in range(6):
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 6.0)
		hexagon.append(direction * 6.5)
		inner_hexagon.append(direction * 4.2)
	canvas.draw_colored_polygon(hexagon, STEEL_DARK)
	canvas.draw_colored_polygon(inner_hexagon, rune_color)

	canvas.draw_set_transform_matrix(base)
	if hovered:
		var octagon := _octagon_points(Vector2.ZERO, 47.0)
		octagon.append(octagon[0])
		Palette.draw_hover_outline(canvas, octagon, 2.4)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _crate(canvas: CanvasItem, at: Vector2, tint: Color) -> void:
	Palette.draw_rounded_rect(canvas, Rect2(at - Vector2(8.0, 6.0), Vector2(16.0, 12.0)), 2.0, Palette.GOBLIN_WOOD * tint)
	canvas.draw_rect(Rect2(at - Vector2(1.5, 6.0), Vector2(3.0, 12.0)), Palette.GOBLIN_IRON_DARK * tint)


static func _octagon(canvas: CanvasItem, offset: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(_octagon_points(offset, radius), color)


static func _octagon_outline(canvas: CanvasItem, radius: float, color: Color, width: float) -> void:
	var points := _octagon_points(Vector2.ZERO, radius)
	points.append(points[0])
	canvas.draw_polyline(points, color, width)


static func _octagon_points(offset: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(8):
		points.append(offset + Vector2.RIGHT.rotated(TAU * float(index) / 8.0 + PI / 8.0) * radius)
	return points


static func _rune(canvas: CanvasItem, at: Vector2, rotation: float, glyph_scale: float, color: Color, index: int) -> void:
	var points := PackedVector2Array()
	for point in RUNES[index % RUNES.size()]:
		points.append(at + (point as Vector2).rotated(rotation) * glyph_scale)
	canvas.draw_polyline(points, color, 1.1)
