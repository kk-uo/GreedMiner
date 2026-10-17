class_name Battlefield
extends Node2D

## Defines the finite world-space battlefield independently of the viewport,
## and paints the planet ground in the style-A flat look: calm low-contrast
## patches, craters and rocks, with the only saturated color reserved for ore.
## Everything is procedural and drawn once, so the map costs no texture memory.

## Total playable map size in world pixels.
@export var world_size: Vector2 = Vector2(3200.0, 2200.0)

## Ground palette key from Palette.PLANETS (rocky, frozen, volcanic).
@export var planet_theme: StringName = &"rocky"

## Seed for the decoration layout; change it for a different arrangement.
@export var map_seed: int = 7

## Radius around the map center kept free of rocks so the ship reads clearly.
@export var clear_radius: float = 220.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var colors := Palette.planet(planet_theme)
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var center := world_size * 0.5

	draw_rect(Rect2(Vector2.ZERO, world_size), colors["ground"], true)

	# Large, calm ground patches (two tones only).
	for index in range(18):
		var tone: Color = colors["ground_dark"] if index % 2 == 0 else colors["ground_light"]
		var blob_center := Vector2(rng.randf() * world_size.x, rng.randf() * world_size.y)
		draw_colored_polygon(_blob(rng, blob_center, rng.randf_range(160.0, 420.0), 0.7), tone)

	# Shallow craters: dark rim, slightly lighter floor offset toward the light.
	for index in range(9):
		var crater_center := _random_point_outside_clearing(rng, center, 120.0)
		var crater_radius := rng.randf_range(34.0, 80.0)
		draw_colored_polygon(_ellipse(crater_center, crater_radius, 0.66), colors["crater"])
		draw_colored_polygon(
			_ellipse(crater_center + Vector2(crater_radius * 0.12, crater_radius * 0.1), crater_radius * 0.78, 0.6),
			colors["crater_inner"]
		)

	# Small speckles break up flat areas without adding noise textures.
	for index in range(320):
		var dot := Vector2(rng.randf() * world_size.x, rng.randf() * world_size.y)
		var dot_color: Color = colors["crater"] if rng.randf() < 0.65 else colors["ground_light"]
		draw_circle(dot, rng.randf_range(1.5, 3.5), dot_color)

	# Ore deposits: the most saturated thing on the map ("greed" draws the eye).
	for index in range(12):
		var deposit := _random_point_outside_clearing(rng, center, 260.0)
		_draw_deposit(rng, deposit, rng.randf() < 0.75)

	# Rocks: one hard shadow, a dark body and a lit top facet.
	for index in range(46):
		var rock_center := _random_point_outside_clearing(rng, center, clear_radius)
		_draw_rock(rng, rock_center, rng.randf_range(9.0, 26.0), colors)


## Returns the map boundary in global world coordinates.
func get_world_bounds() -> Rect2:
	var top_left := to_global(Vector2.ZERO)
	var bottom_right := to_global(world_size)
	return Rect2(top_left, bottom_right - top_left).abs()


func _draw_rock(rng: RandomNumberGenerator, rock_center: Vector2, size: float, colors: Dictionary) -> void:
	var points := PackedVector2Array()
	var sides := rng.randi_range(5, 7)
	var start := rng.randf() * TAU
	for side in range(sides):
		var angle := start + TAU * float(side) / float(sides)
		points.append(rock_center + Vector2.RIGHT.rotated(angle) * size * rng.randf_range(0.75, 1.1))

	Palette.draw_shadowed_polygon(self, points, colors["rock"], Palette.SHADOW_OFFSET * (0.6 + size / 40.0))

	# Lit facet: the upper vertices plus a point pulled up from the center.
	var facet := PackedVector2Array()
	for point in points:
		if point.y <= rock_center.y + size * 0.1:
			facet.append(point)
	if facet.size() >= 2:
		facet.append(rock_center + Vector2(size * 0.1, -size * 0.15))
		draw_colored_polygon(_sorted_around(facet), colors["rock_light"])


func _draw_deposit(rng: RandomNumberGenerator, deposit_center: Vector2, gold: bool) -> void:
	var glow := Palette.GOLD if gold else Palette.COBALT
	glow.a = 0.10
	draw_circle(deposit_center, 54.0, glow)
	glow.a = 0.12
	draw_circle(deposit_center, 30.0, glow)

	var count := rng.randi_range(2, 4)
	for index in range(count):
		var offset := Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-12.0, 14.0))
		var crystal_scale := rng.randf_range(0.55, 1.15)
		draw_circle(deposit_center + offset + Vector2(2.0, 14.0 * crystal_scale), 9.0 * crystal_scale, Palette.SHADOW_COLOR)
		Palette.draw_crystal(self, deposit_center + offset, crystal_scale, rng.randf_range(-0.4, 0.4), gold)


func _random_point_outside_clearing(rng: RandomNumberGenerator, center: Vector2, keep_out: float) -> Vector2:
	for attempt in range(20):
		var point := Vector2(rng.randf_range(40.0, world_size.x - 40.0), rng.randf_range(40.0, world_size.y - 40.0))
		if point.distance_to(center) > keep_out:
			return point
	return Vector2(40.0, 40.0)


func _blob(rng: RandomNumberGenerator, blob_center: Vector2, radius: float, wobble: float) -> PackedVector2Array:
	var count := 18
	var radii: Array[float] = []
	for index in range(count):
		radii.append(rng.randf_range(1.0 - wobble * 0.4, 1.0 + wobble * 0.2))
	var points := PackedVector2Array()
	for index in range(count):
		# Averaging neighbours keeps the outline smooth and organic.
		var smoothed := (radii[index] * 2.0 + radii[(index + 1) % count] + radii[(index - 1 + count) % count]) / 4.0
		var angle := TAU * float(index) / float(count)
		points.append(blob_center + Vector2(cos(angle), sin(angle) * 0.75) * radius * smoothed)
	return points


func _ellipse(ellipse_center: Vector2, radius: float, squash: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(ellipse_center + Vector2(cos(angle), sin(angle) * squash) * radius)
	return points


func _sorted_around(points: PackedVector2Array) -> PackedVector2Array:
	var pivot := Vector2.ZERO
	for point in points:
		pivot += point
	pivot /= float(points.size())
	var list: Array = Array(points)
	list.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return (a - pivot).angle() < (b - pivot).angle()
	)
	return PackedVector2Array(list)
