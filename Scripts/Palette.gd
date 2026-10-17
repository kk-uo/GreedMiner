class_name Palette
extends RefCounted

## GreedMiner "flat geometric" art direction (style A).
##
## Every _draw() in the game takes its colors from here. Rules:
## - 3 flat tones per material (base, shadow, highlight). No gradients, no outlines.
## - Light comes from the top-left. Every object casts the same hard drop shadow
##   (SHADOW_OFFSET, SHADOW_COLOR), drawn first, using the object's own silhouette.
## - Ship = rectangles / chamfers, enemies = curves / spikes / jagged stone,
##   minerals = hexagonal facets.
## - Only minerals are fully saturated. Enemies are dark silhouettes whose only
##   bright color is the THREAT core.


# ==========================================
# Shared lighting
# ==========================================

const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.28)
## Shadow offset in world space (light from the top-left).
const SHADOW_OFFSET := Vector2(5.0, 7.0)


# ==========================================
# Ship (bone white + gunmetal + one safety-orange accent)
# ==========================================

const SHIP_BODY := Color("E8E1D3")
const SHIP_SHADOW := Color("C2B7A3")
const SHIP_SEAM := Color("CBC1AE")
const SHIP_PART := Color("CFC5B2")
const SHIP_PART_EDGE := Color("B3A893")
const MECH := Color("3B3530")
const MECH_LIGHT := Color("5A524B")
const ACCENT := Color("F08A24")
const ACCENT_LIGHT := Color("FFE2C2")


# ==========================================
# Combat colors
# ==========================================

## Player projectiles and muzzle flashes.
const SHOT := Color("FFC061")
const SHOT_CORE := Color("FFF2C2")
## Enemy silhouettes.
const ENEMY := Color("2B1F1C")
const ENEMY_LIGHT := Color("46342D")
## The one bright color an enemy may carry, also used for danger UI.
const THREAT := Color("FF3D5A")
const HIT_FLASH := Color("FFFFFF")


# ==========================================
# Minerals (the most saturated objects in the game)
# ==========================================

const GOLD := Color("FFD23F")
const GOLD_SHADOW := Color("DC9D17")
const GOLD_LIGHT := Color("FFF2B0")
const COBALT := Color("5FB0FF")
const COBALT_SHADOW := Color("2F78CC")
const COBALT_LIGHT := Color("D6EDFF")


# ==========================================
# UI
# ==========================================

const UI_PANEL := Color("1D1714")
const UI_PANEL_RAISED := Color("2A231E")
const UI_TEXT := Color("F2EAD9")
const UI_MUTED := Color("A89C88")


# ==========================================
# Planet ground palettes: base, dark patch, light patch, rock, rock light,
# crater, crater inner. Only this table changes between planets.
# ==========================================

const PLANETS := {
	&"rocky": {
		"ground": Color("8A6A4D"),
		"ground_dark": Color("7D5F45"),
		"ground_light": Color("967558"),
		"rock": Color("6A4D3A"),
		"rock_light": Color("A07F62"),
		"crater": Color("7A5C42"),
		"crater_inner": Color("83644A"),
	},
	&"frozen": {
		"ground": Color("7F93A0"),
		"ground_dark": Color("71848F"),
		"ground_light": Color("8FA3AF"),
		"rock": Color("56636D"),
		"rock_light": Color("A9BAC4"),
		"crater": Color("6C7E89"),
		"crater_inner": Color("778A95"),
	},
	&"volcanic": {
		"ground": Color("4A3B37"),
		"ground_dark": Color("3F322F"),
		"ground_light": Color("56453F"),
		"rock": Color("2F2624"),
		"rock_light": Color("6B5650"),
		"crater": Color("3A2E2B"),
		"crater_inner": Color("45362F"),
	},
}


## Returns the ground palette for a planet theme, falling back to rocky.
static func planet(theme: StringName) -> Dictionary:
	return PLANETS.get(theme, PLANETS[&"rocky"])


# ==========================================
# Geometry helpers
# ==========================================

## Returns a copy of points moved by offset.
static func offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	result.resize(points.size())
	for index in range(points.size()):
		result[index] = points[index] + offset
	return result


## Returns a regular polygon centered on the origin.
static func regular_polygon(sides: int, radius: float, rotation: float = 0.0) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in range(sides):
		result.append(Vector2.RIGHT.rotated(rotation + TAU * float(index) / float(sides)) * radius)
	return result


## Returns a rectangle outline with rounded corners.
static func rounded_rect_points(rect: Rect2, radius: float, corner_segments: int = 3) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var result := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI * 0.5],
		[rect.end - Vector2(r, r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5],
		[rect.position + Vector2(r, r), PI],
	]
	for corner in corners:
		for step in range(corner_segments + 1):
			var angle: float = corner[1] + PI * 0.5 * float(step) / float(corner_segments)
			result.append((corner[0] as Vector2) + Vector2.RIGHT.rotated(angle) * r)
	return result


## Shadow offset expressed in a rotated node's local space, so the shadow
## always falls toward the bottom-right of the screen.
static func local_shadow_offset(node: Node2D) -> Vector2:
	return SHADOW_OFFSET.rotated(-node.global_rotation)


# ==========================================
# Drawing helpers
# ==========================================

## Draws a polygon's drop shadow followed by the polygon itself.
static func draw_shadowed_polygon(
	canvas: CanvasItem,
	points: PackedVector2Array,
	color: Color,
	shadow_offset: Vector2 = SHADOW_OFFSET
) -> void:
	canvas.draw_colored_polygon(offset_points(points, shadow_offset), SHADOW_COLOR)
	canvas.draw_colored_polygon(points, color)


## Draws a rounded rectangle as a flat polygon.
static func draw_rounded_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(rounded_rect_points(rect, radius), color)


## Round mounting plate shared by every rotating weapon.
static func draw_turret_base(canvas: CanvasItem, radius: float, shadow_offset: Vector2 = SHADOW_OFFSET) -> void:
	canvas.draw_circle(shadow_offset * 0.6, radius, SHADOW_COLOR)
	canvas.draw_circle(Vector2.ZERO, radius, SHIP_PART_EDGE)
	canvas.draw_circle(Vector2(-0.8, -0.8), radius - 2.0, SHIP_PART)


## Hexagonal faceted crystal pointing up, used for ore everywhere.
static func draw_crystal(
	canvas: CanvasItem,
	center: Vector2,
	scale: float,
	rotation: float = 0.0,
	gold: bool = true
) -> void:
	var light := GOLD if gold else COBALT
	var dark := GOLD_SHADOW if gold else COBALT_SHADOW
	var shine := GOLD_LIGHT if gold else COBALT_LIGHT
	var xf := Transform2D(rotation, Vector2.ONE * scale, 0.0, center)
	canvas.draw_colored_polygon(PackedVector2Array([
		xf * Vector2(0.0, -22.0), xf * Vector2(8.0, -12.0),
		xf * Vector2(8.0, 6.0), xf * Vector2(0.0, 14.0),
	]), dark)
	canvas.draw_colored_polygon(PackedVector2Array([
		xf * Vector2(0.0, -22.0), xf * Vector2(-8.0, -12.0),
		xf * Vector2(-8.0, 6.0), xf * Vector2(0.0, 14.0),
	]), light)
	canvas.draw_colored_polygon(PackedVector2Array([
		xf * Vector2(0.0, -22.0), xf * Vector2(-8.0, -12.0), xf * Vector2(0.0, -9.0),
	]), shine)


## Builds a StyleBoxFlat in the house UI style.
static func make_panel_style(
	bg: Color,
	radius: int = 6,
	margin_h: float = 12.0,
	margin_v: float = 8.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	return style
