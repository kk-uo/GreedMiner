extends RefCounted

## Presentation for magic artifacts (Magic Stall, Compendium, hangar slots):
## rarity colors, procedural artifact icons and the small stat icons used
## instead of long descriptions. Load with preload(); no class_name.

const RARITY_COLORS: Array[Color] = [Color("A89C88"), Color("5FB0FF"), Color("B69CFF"), Color("FFD23F")]
const RARITY_NAMES: Array[String] = ["COMMON", "RARE", "EPIC", "LEGENDARY"]
const SILHOUETTE := Color("0E0B09")

## effect_parameters key -> [stat icon, value suffix].
const STAT_FORMATS := {
	&"armor_hp": [&"shield", ""],
	&"shockwave_damage": [&"burst", ""],
	&"regeneration_delay": [&"clock", "s"],
	&"shockwave_radius": [&"ring", ""],
	&"knockback_distance": [&"push", ""],
}


## Rarity index (0 common .. 3 legendary) from a definition's rarity string.
static func rarity_index(definition: MagicArtifactDefinition) -> int:
	if definition == null:
		return 0
	var index := RARITY_NAMES.find(String(definition.rarity).strip_edges().to_upper())
	return maxi(index, 0)


static func rarity_color(rarity: int) -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]


static func rarity_name(rarity: int) -> String:
	return RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)]


## [icon id, text] chips for a definition (at most three).
static func stat_chips(definition: MagicArtifactDefinition) -> Array:
	var chips: Array = []
	if definition == null:
		return chips
	for key in definition.stat_keys:
		if chips.size() >= 3 or not definition.effect_parameters.has(key):
			continue
		var format: Array = STAT_FORMATS.get(key, [&"burst", ""])
		var value: float = float(definition.effect_parameters[key])
		var text := str(int(round(value))) if absf(value - round(value)) < 0.05 else "%.1f" % value
		chips.append([format[0], text + String(format[1])])
	return chips


## Draws an artifact icon centred on `center`, `size` = its diameter.
## silhouette: undiscovered (solid dark shape only).
static func draw_icon(canvas: CanvasItem, center: Vector2, size: float, artifact_id: StringName, rarity: int, silhouette: bool = false) -> void:
	var s: float = size / 64.0
	canvas.draw_set_transform(center, 0.0, Vector2.ONE * s)
	match artifact_id:
		&"stone_heart":
			_stone_heart(canvas, silhouette)
		&"angry_stone":
			_angry_stone(canvas, silhouette)
		&"goblin_flag":
			_goblin_flag(canvas, silhouette)
		&"goblin_horn":
			_goblin_horn(canvas, silhouette)
		&"demon_prism":
			_demon_prism(canvas, silhouette)
		&"ghost_bullet":
			_ghost_bullet(canvas, silhouette)
		&"red_crystal":
			_red_crystal(canvas, silhouette)
		_:
			_gem(canvas, rarity_color(rarity), silhouette)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _stone_heart(canvas: CanvasItem, silhouette: bool) -> void:
	var outer := _heart(22.0, Vector2.ZERO)
	if silhouette:
		canvas.draw_colored_polygon(outer, SILHOUETTE)
		return
	canvas.draw_colored_polygon(_heart(22.0, Vector2(2.5, 3.0)), Color(0, 0, 0, 0.3))
	canvas.draw_colored_polygon(outer, Palette.STONE_DARK)
	canvas.draw_colored_polygon(_heart(18.5, Vector2(-0.6, -1.0)), Palette.STONE_MID)
	canvas.draw_polyline(PackedVector2Array([Vector2(-15, -11), Vector2(-10, -14), Vector2(-4, -9)]), Palette.STONE_HI, 3.0)
	# Glowing crack and core.
	canvas.draw_circle(Vector2(0, 1), 9.0, Color(Palette.ACCENT, 0.22))
	canvas.draw_polyline(PackedVector2Array([Vector2(0, -9), Vector2(-4, -2), Vector2(3, 3), Vector2(-2, 10)]), Palette.ACCENT, 2.6)
	canvas.draw_circle(Vector2(0, 0.5), 3.6, Palette.SHOT)
	canvas.draw_circle(Vector2(-0.8, -0.3), 1.5, Palette.SHOT_CORE)


## A scowling red rock (Angry Stone).
static func _angry_stone(canvas: CanvasItem, silhouette: bool) -> void:
	var body := PackedVector2Array([Vector2(-19, -9), Vector2(-6, -19), Vector2(12, -17), Vector2(21, -4), Vector2(17, 14), Vector2(2, 20), Vector2(-15, 15), Vector2(-22, 3)])
	if silhouette:
		canvas.draw_colored_polygon(body, SILHOUETTE)
		return
	canvas.draw_colored_polygon(Palette.offset_points(body, Vector2(2.5, 3.0)), Color(0, 0, 0, 0.3))
	canvas.draw_colored_polygon(body, Color("6E1424"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-17, -8), Vector2(-5, -17), Vector2(11, -15), Vector2(19, -3), Vector2(15, 12), Vector2(1, 17), Vector2(-13, 13), Vector2(-19, 3)]), Color("B3203A"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-15, -7), Vector2(-5, -15), Vector2(6, -14), Vector2(-2, -8)]), Color("FF6078"))
	# Furrowed brows, glowing eyes and a frown.
	canvas.draw_line(Vector2(-12, -5), Vector2(-3, -1), Palette.UI_PANEL, 3.0)
	canvas.draw_line(Vector2(12, -5), Vector2(3, -1), Palette.UI_PANEL, 3.0)
	canvas.draw_circle(Vector2(-7, 3), 2.4, Palette.SHOT_CORE)
	canvas.draw_circle(Vector2(7, 3), 2.4, Palette.SHOT_CORE)
	canvas.draw_polyline(PackedVector2Array([Vector2(-6, 12), Vector2(0, 8), Vector2(6, 12)]), Palette.UI_PANEL, 2.4)
	# A few grey stone flecks.
	canvas.draw_circle(Vector2(13, -9), 1.8, Color("8C7866"))
	canvas.draw_circle(Vector2(-14, 9), 1.5, Color("8C7866"))


## Goblin Flag: a tattered red war banner on a crooked wooden pole with a
## bone tusk emblem.
static func _goblin_flag(canvas: CanvasItem, silhouette: bool) -> void:
	var cloth := PackedVector2Array([Vector2(-10, -20), Vector2(20, -15), Vector2(14, -8), Vector2(21, -1), Vector2(15, 4), Vector2(19, 11), Vector2(-10, 9)])
	if silhouette:
		canvas.draw_line(Vector2(-12, -24), Vector2(-14, 24), SILHOUETTE, 5.0)
		canvas.draw_colored_polygon(cloth, SILHOUETTE)
		return
	canvas.draw_colored_polygon(Palette.offset_points(cloth, Vector2(2.5, 3.0)), Color(0, 0, 0, 0.3))
	canvas.draw_line(Vector2(-9.5, -22), Vector2(-11.5, 26), Color(0, 0, 0, 0.3), 5.0)
	# Pole with a spear tip and a binding.
	canvas.draw_line(Vector2(-12, -22), Vector2(-14, 24), Palette.GOBLIN_WOOD_DARK, 5.0)
	canvas.draw_line(Vector2(-12.6, -20), Vector2(-14.4, 22), Palette.GOBLIN_WOOD, 2.4)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-15, -21), Vector2(-11.5, -31), Vector2(-9, -21)]), Palette.GOBLIN_IRON_LIGHT)
	canvas.draw_line(Vector2(-16, 14), Vector2(-11, 15), Palette.GOBLIN_LEATHER, 3.0)
	# Banner.
	canvas.draw_colored_polygon(cloth, Color("7A2418"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-10, -20), Vector2(20, -15), Vector2(14, -8), Vector2(19, -2), Vector2(14, 2), Vector2(17, 7), Vector2(-10, 6)]), Palette.GOBLIN_CLOTH)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-10, -20), Vector2(20, -15), Vector2(16, -12), Vector2(-10, -15)]), Color("E06A4C"))
	# Tusk emblem.
	canvas.draw_polyline(PackedVector2Array([Vector2(-2, -9), Vector2(1, -3), Vector2(6, -1), Vector2(10, -4)]), Palette.GOBLIN_BONE, 3.0)
	canvas.draw_polyline(PackedVector2Array([Vector2(-1, 2), Vector2(3, 0), Vector2(7, 1)]), Palette.GOBLIN_BONE, 2.2)
	canvas.draw_circle(Vector2(3, -5), 1.6, Palette.GOBLIN_EYE)


## Goblin Horn: a curved bone war horn with iron bands and a leather strap,
## sound waves blasting from its bell.
static func _goblin_horn(canvas: CanvasItem, silhouette: bool) -> void:
	var horn := PackedVector2Array()
	var inner := PackedVector2Array()
	for index in range(13):
		var t := float(index) / 12.0
		var spine := Vector2(-20 + 32 * t, 14 - 30 * t + 18 * t * t)
		var half := lerpf(2.4, 10.0, t * t)
		horn.append(spine + Vector2(0, -half))
		inner.insert(0, spine + Vector2(0, half))
	horn.append_array(inner)
	if silhouette:
		canvas.draw_colored_polygon(horn, SILHOUETTE)
		return
	canvas.draw_colored_polygon(Palette.offset_points(horn, Vector2(2.5, 3.0)), Color(0, 0, 0, 0.3))
	# Leather strap behind.
	canvas.draw_polyline(PackedVector2Array([Vector2(-14, 10), Vector2(-6, 20), Vector2(6, 16), Vector2(8, 4)]), Palette.GOBLIN_LEATHER, 2.6)
	canvas.draw_colored_polygon(horn, Color("A89A7C"))
	var lit := PackedVector2Array()
	for index in range(13):
		var t := float(index) / 12.0
		var spine := Vector2(-20 + 32 * t, 14 - 30 * t + 18 * t * t)
		lit.append(spine + Vector2(0, -lerpf(2.4, 10.0, t * t)))
	for index in range(12, -1, -1):
		var t := float(index) / 12.0
		var spine := Vector2(-20 + 32 * t, 14 - 30 * t + 18 * t * t)
		lit.append(spine + Vector2(0, -lerpf(2.4, 10.0, t * t) * 0.15))
	canvas.draw_colored_polygon(lit, Palette.GOBLIN_BONE)
	# Bell opening and iron bands.
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(11, -12), Vector2(14, -14), Vector2(14, 6), Vector2(11, 4)]), Palette.GOBLIN_WOOD_DARK)
	for t in [0.3, 0.62]:
		var spine := Vector2(-20 + 32 * t, 14 - 30 * t + 18 * t * t)
		var half := lerpf(2.4, 10.0, t * t) + 1.2
		canvas.draw_line(spine + Vector2(0, -half), spine + Vector2(0, half), Palette.GOBLIN_IRON, 3.0)
	canvas.draw_circle(Vector2(-20, 14), 2.6, Palette.GOBLIN_IRON_DARK)
	# Sound waves.
	for k in range(3):
		var r := 6.0 + 5.0 * float(k)
		canvas.draw_arc(Vector2(14, -4), r, -0.7, 0.7, 10, Color(Palette.GOBLIN_SKIN_LIGHT, 0.9 - 0.25 * float(k)), 2.0)


## Demon Prism: a tall black-crimson triangular prism with two small horns,
## a slit demon eye in its molten core and a beam fanning out into a wide
## crimson spread (the range it grants).
static func _demon_prism(canvas: CanvasItem, silhouette: bool) -> void:
	var body := PackedVector2Array([Vector2(-4, -24), Vector2(15, 18), Vector2(-17, 18)])
	var horn_l := PackedVector2Array([Vector2(-11, -4), Vector2(-17, -14), Vector2(-21, -26), Vector2(-12, -18), Vector2(-5, -14)])
	var horn_r := PackedVector2Array([Vector2(0, -14), Vector2(8, -19), Vector2(15, -28), Vector2(12, -15), Vector2(6, -4)])
	if silhouette:
		canvas.draw_colored_polygon(horn_l, SILHOUETTE)
		canvas.draw_colored_polygon(horn_r, SILHOUETTE)
		canvas.draw_colored_polygon(body, SILHOUETTE)
		return
	# Refracted beam: a thin ray in from the left, a wide fan out to the right.
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(4, -2), Vector2(30, -16), Vector2(31, 14), Vector2(4, 6)]), Color("FF3B2F", 0.22))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(30, -8), Vector2(30, 7), Vector2(4, 4)]), Color("FF7A1A", 0.35))
	canvas.draw_line(Vector2(-30, 6), Vector2(-8, 2), Color("FFC061", 0.9), 2.0)
	canvas.draw_colored_polygon(Palette.offset_points(body, Vector2(2.5, 3.0)), Color(0, 0, 0, 0.3))
	canvas.draw_colored_polygon(horn_l, Color("5A1A26"))
	canvas.draw_colored_polygon(horn_r, Color("4A1520"))
	canvas.draw_polyline(PackedVector2Array([Vector2(-19, -23), Vector2(-15, -14), Vector2(-9, -9)]), Color("A8404E"), 1.6)
	canvas.draw_polyline(PackedVector2Array([Vector2(13, -25), Vector2(8, -16), Vector2(3, -12)]), Color("A8404E"), 1.6)
	canvas.draw_colored_polygon(body, Color("3A0A12"))
	# Lit left facet and darker right facet.
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-4, -24), Vector2(-3, 18), Vector2(-17, 18)]), Color("8E1626"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-4, -24), Vector2(-7, 4), Vector2(-14, 15)]), Color("D2334A"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-4, -24), Vector2(15, 18), Vector2(-3, 18)]), Color("5C0E1C"))
	# Molten core with a slit eye.
	canvas.draw_circle(Vector2(-3, 7), 8.5, Color("FF3B2F", 0.3))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-10, 7), Vector2(-3, 2), Vector2(4, 7), Vector2(-3, 12)]), Color("FF7A1A"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-7, 7), Vector2(-3, 4), Vector2(1, 7), Vector2(-3, 10)]), Color("FFC061"))
	canvas.draw_line(Vector2(-3, 3.5), Vector2(-3, 10.5), Color("2A0F14"), 1.8)
	# Edge glints.
	canvas.draw_line(Vector2(-4, -24), Vector2(-16, 17), Color("FF8C9A", 0.8), 1.2)
	canvas.draw_circle(Vector2(-6, -15), 1.4, Color("FFE0E4"))


## Ghost Bullet: a pale see-through bullet flying up-right, its tail
## unravelling into a wavy ghost wisp.
static func _ghost_bullet(canvas: CanvasItem, silhouette: bool) -> void:
	var dir := Vector2(1, -0.62).normalized()
	var side := dir.orthogonal()
	# Wisp: a tapering wavy ribbon from the bullet's base back down-left.
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for k in range(13):
		var t := float(k) / 12.0
		var spine := -dir * (2.0 + 24.0 * t) + side * sin(t * 7.0) * 4.0 * t
		var half := lerpf(7.5, 1.0, t)
		top.append(spine + side * half)
		bottom.insert(0, spine - side * half)
	var wisp := top.duplicate()
	wisp.append_array(bottom)
	var tip := dir * 20.0
	var bullet := PackedVector2Array([tip, dir * 12.0 + side * 6.5, -dir * 4.0 + side * 7.0, -dir * 4.0 - side * 7.0, dir * 12.0 - side * 6.5])
	if silhouette:
		canvas.draw_colored_polygon(wisp, SILHOUETTE)
		canvas.draw_colored_polygon(bullet, SILHOUETTE)
		return
	canvas.draw_circle(dir * 6.0, 19.0, Color("8FE3FF", 0.10))
	canvas.draw_colored_polygon(wisp, Color("8FE3FF", 0.42))
	# Inner brighter strand of the wisp.
	var strand := PackedVector2Array()
	for k in range(10):
		var t := float(k) / 9.0
		strand.append(-dir * (2.0 + 20.0 * t) + side * sin(t * 7.0) * 4.0 * t)
	canvas.draw_polyline(strand, Color("DDF8FF", 0.6), 2.0)
	# Translucent bullet body with a lit flank and a glowing tip.
	canvas.draw_colored_polygon(bullet, Color("9EDCF0", 0.7))
	canvas.draw_colored_polygon(PackedVector2Array([tip, dir * 12.0 + side * 6.5, -dir * 4.0 + side * 7.0, -dir * 4.0 + side * 1.0, dir * 12.0]), Color("E6FBFF", 0.8))
	canvas.draw_circle(tip - dir * 3.0, 3.6, Color(1, 1, 1, 0.95))
	canvas.draw_circle(tip - dir * 3.0, 6.5, Color(1, 1, 1, 0.18))
	# Drifting motes.
	canvas.draw_circle(-dir * 20.0 + side * 10.0, 1.5, Color("DDF8FF", 0.7))
	canvas.draw_circle(-dir * 12.0 - side * 11.0, 1.2, Color("DDF8FF", 0.55))


## Red Crystal: a cluster of three faceted blood-red crystals on a dark rock,
## glowing, with red sparks rising off it.
static func _red_crystal(canvas: CanvasItem, silhouette: bool) -> void:
	var rock := PackedVector2Array([Vector2(-20, 14), Vector2(-12, 8), Vector2(10, 8), Vector2(21, 15), Vector2(14, 21), Vector2(-14, 21)])
	var shards := [
		[Vector2(-1, 12), 26.0, 7.5, -0.12],
		[Vector2(-10, 13), 17.0, 5.5, -0.55],
		[Vector2(10, 13), 15.0, 5.0, 0.5],
	]
	if silhouette:
		canvas.draw_colored_polygon(rock, SILHOUETTE)
		for shard in shards:
			canvas.draw_colored_polygon(_shard_points(shard), SILHOUETTE)
		return
	canvas.draw_circle(Vector2(0, -2), 21.0, Color("FF3348", 0.12))
	canvas.draw_colored_polygon(Palette.offset_points(rock, Vector2(2.5, 3.0)), Color(0, 0, 0, 0.3))
	canvas.draw_colored_polygon(rock, Color("3A302B"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-18, 14), Vector2(-12, 10), Vector2(9, 10), Vector2(-2, 15)]), Color("5A4C43"))
	# Back shards first, the tall one in front.
	for index in [1, 2, 0]:
		var shard: Array = shards[index]
		var pts := _shard_points(shard)
		canvas.draw_colored_polygon(pts, Color("7A0F1E"))
		# Lit left facet and a bright edge.
		var foot := (pts[2] + pts[3]) * 0.5
		canvas.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], foot]), Color("D7263D"))
		canvas.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], (pts[1] + foot) * 0.5]), Color("FF6B7D"))
	canvas.draw_line(Vector2(-3, -12), Vector2(-4, -3), Color(1, 1, 1, 0.75), 1.6)
	# Rising red sparks.
	for spark in [[Vector2(-15, -10), 1.8], [Vector2(15, -6), 1.5], [Vector2(8, -20), 1.3], [Vector2(-8, -21), 1.1]]:
		canvas.draw_circle(spark[0], float(spark[1]) * 1.9, Color("FF3348", 0.25))
		canvas.draw_circle(spark[0], spark[1], Color("FFB3BC"))


## [base, height, half width, lean] -> a five-point crystal:
## tip, shoulder A, base A, base B, shoulder B.
static func _shard_points(shard: Array) -> PackedVector2Array:
	var base: Vector2 = shard[0]
	var height: float = shard[1]
	var half: float = shard[2]
	var lean: float = shard[3]
	var up := Vector2.UP.rotated(lean)
	var across := up.orthogonal()
	var tip := base + up * height
	return PackedVector2Array([
		tip,
		base + up * height * 0.72 + across * half,
		base + across * half * 0.85,
		base - across * half * 0.85,
		base + up * height * 0.72 - across * half,
	])


static func _heart(radius: float, offset: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(40):
		var t: float = TAU * float(index) / 40.0
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(offset + Vector2(x, y + 1.5) * radius / 17.0)
	return points


## Generic faceted gem in the rarity color (artifacts without custom art).
static func _gem(canvas: CanvasItem, color: Color, silhouette: bool) -> void:
	var body := PackedVector2Array([Vector2(0, -20), Vector2(16, -4), Vector2(10, 16), Vector2(-10, 16), Vector2(-16, -4)])
	if silhouette:
		canvas.draw_colored_polygon(body, SILHOUETTE)
		return
	canvas.draw_colored_polygon(Palette.offset_points(body, Vector2(2.5, 3.0)), Color(0, 0, 0, 0.3))
	canvas.draw_colored_polygon(body, color.darkened(0.45))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -20), Vector2(16, -4), Vector2(0, 2), Vector2(-16, -4)]), color)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -20), Vector2(-16, -4), Vector2(-2, -6)]), color.lightened(0.5))


## Small monochrome stat icon (about `size` px).
static func draw_stat_icon(canvas: CanvasItem, center: Vector2, size: float, kind: StringName, color: Color) -> void:
	var r: float = size * 0.5
	match kind:
		&"shield":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-r * 0.8, -r * 0.8), center + Vector2(r * 0.8, -r * 0.8),
				center + Vector2(r * 0.8, 0.0), center + Vector2(0.0, r), center + Vector2(-r * 0.8, 0.0),
			]), color)
		&"burst":
			for index in range(8):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
				canvas.draw_line(center + direction * r * 0.3, center + direction * r * (1.0 if index % 2 == 0 else 0.7), color, 2.0)
		&"clock":
			canvas.draw_arc(center, r * 0.85, 0.0, TAU, 20, color, 2.0)
			canvas.draw_line(center, center + Vector2(0, -r * 0.55), color, 2.0)
			canvas.draw_line(center, center + Vector2(r * 0.4, 0), color, 2.0)
		&"ring":
			canvas.draw_arc(center, r * 0.85, 0.0, TAU, 20, color, 2.0)
			canvas.draw_circle(center, r * 0.25, color)
		&"push":
			canvas.draw_line(center + Vector2(-r * 0.8, 0), center + Vector2(r * 0.6, 0), color, 2.2)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(r, 0), center + Vector2(r * 0.3, -r * 0.5), center + Vector2(r * 0.3, r * 0.5)]), color)
		_:
			canvas.draw_circle(center, r * 0.5, color)


## Equip-target glyph: ship (square) or module (turret circle).
static func draw_target_icon(canvas: CanvasItem, center: Vector2, size: float, module_target: bool, color: Color) -> void:
	var r: float = size * 0.5
	if module_target:
		canvas.draw_arc(center, r * 0.75, 0.0, TAU, 18, color, 1.8)
		canvas.draw_line(center, center + Vector2(r, 0), color, 2.2)
	else:
		var rect := Rect2(center - Vector2.ONE * r * 0.85, Vector2.ONE * r * 1.7)
		canvas.draw_rect(rect, color, false, 1.8)
		canvas.draw_rect(Rect2(center - Vector2.ONE * r * 0.3, Vector2.ONE * r * 0.6), color)


## Control that shows one artifact icon (optionally as a silhouette).
class IconView:
	extends Control

	var artifact_id: StringName = &""
	var rarity: int = 0
	var silhouette: bool = false
	var glow: bool = false
	var _visual: GDScript = load("res://Scripts/UI/Artifacts/ArtifactVisual.gd")

	func _init(icon_size: float = 64.0) -> void:
		custom_minimum_size = Vector2.ONE * icon_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		var diameter: float = minf(size.x, size.y)
		if glow and not silhouette:
			var color: Color = _visual.rarity_color(rarity)
			draw_circle(center, diameter * 0.5, Color(color, 0.12))
			draw_circle(center, diameter * 0.36, Color(color, 0.14))
		_visual.draw_icon(self, center, diameter * 0.82, artifact_id, rarity, silhouette)
