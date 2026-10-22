class_name ShipHullVisual
extends RefCounted

## Presentation-only geometry and drawing for the ship hull ("B · forged anvil").
##
## The hull is generated from whatever set of grid cells the ship has, so it
## keeps working when the grid grows irregularly:
## - every occupied cell gets a bone floor tile;
## - a heavy forged-iron frame wraps the union of all cells, extended only on
##   sides with no neighbour, with every convex outline corner chamfered;
## - orange rune studs sit on each exposed edge;
## - a thruster pod (which doubles as a landing leg) sits on each convex corner.
## No gameplay code depends on this file.

const FRAME_GROW: float = 12.0
const FRAME_CHAMFER: float = 15.0
## The darker inner frame is shifted down-right to leave a lit rim top-left.
const INNER_SHIFT := Vector2(3.0, 3.0)
const POD_RADIUS: float = 19.0
const TILE_INSET: float = 5.0

const FRAME_RIM := Color("5A524B")
const FRAME_IRON := Color("3B3530")
const POD_BAND := Color("6A5F55")

## Selectable hull color schemes (Hangar > SHIP STYLE). Only the hull changes:
## floor tiles, forged frame, thruster pods and rune studs. Modules keep their
## own colors. The active scheme is ShipLoadout.style_id (saved with the loadout).
const DEFAULT_STYLE: StringName = &"bone_iron"
const STYLES := {
	&"bone_iron": {
		"name": "Bone & Iron", "tile": Color("E8E1D3"), "tile_shadow": Color("C2B7A3"),
		"rim": Color("5A524B"), "iron": Color("3B3530"), "band": Color("6A5F55"), "accent": Color("F08A24"),
	},
	&"charcoal_red": {
		"name": "Charcoal Red", "tile": Color("9B958F"), "tile_shadow": Color("7A746F"),
		"rim": Color("3A3532"), "iron": Color("211E1C"), "band": Color("2F2A27"), "accent": Color("E2453C"),
	},
	&"bubblegum": {
		"name": "Bubblegum", "tile": Color("FBE2ED"), "tile_shadow": Color("E2BFD0"),
		"rim": Color("E06C9F"), "iron": Color("9F3C6B"), "band": Color("B8507F"), "accent": Color("FFF2F7"),
	},
	&"deep_space": {
		"name": "Deep Space", "tile": Color("000000"), "tile_shadow": Color("1A2635"),
		"rim": Color("1F2D3D"), "iron": Color("121B26"), "band": Color("1A2635"), "accent": Color("5EF2D0"), "glow": true,
		"socket": Color("1A2635"), "socket_bolt": Color("2E4256"),
	},
}
## Display order in the style panel.
const STYLE_ORDER: Array[StringName] = [&"bone_iron", &"charcoal_red", &"bubblegum", &"deep_space"]

## Selectable hull designs (Hangar > SHIP STYLE > HULL): frame outline,
## add-on plates around it and the accent pattern on the frame. Every design is
## generated from the cell set, so irregular grids work too, and every pattern
## uses the color scheme's accent. The active design is ShipLoadout.hull_id.
## corner: how convex outline corners are cut (chamfer / step) and by how much.
## feature: add-ons per exposed edge (buttress / plates / deck).
## pattern: accent pattern on the frame (diamond / rune / hazard / runway).
## trim: pattern clearance from a corner that carries a thruster pod.
const DEFAULT_HULL: StringName = &"classic"
const HULLS := {
	&"classic": {"name": "Classic", "corner": &"chamfer", "corner_size": 15.0, "feature": &"", "pattern": &"diamond", "trim": 24.0},
	&"citadel": {"name": "Citadel", "corner": &"step", "corner_size": 44.0, "feature": &"buttress", "pattern": &"rune", "trim": 46.0},
	&"segmented": {"name": "Blade Armor", "corner": &"chamfer", "corner_size": 15.0, "feature": &"", "pattern": &"", "trim": 24.0, "armor": &"blade"},
	&"flight_deck": {"name": "Flight Deck", "corner": &"chamfer", "corner_size": 15.0, "feature": &"deck", "pattern": &"runway", "trim": 24.0},
	&"octagon": {"name": "Octagon", "corner": &"chamfer", "corner_size": 42.0, "feature": &"", "pattern": &"runway", "trim": 44.0},
}
const HULL_ORDER: Array[StringName] = [&"classic", &"citadel", &"segmented", &"flight_deck", &"octagon"]
## Dwarven rune glyphs (unit strokes) for the Citadel pattern.
const RUNE_GLYPHS := [
	[Vector2(-4, -4), Vector2(0, 4), Vector2(4, -4)],
	[Vector2(-3, 4), Vector2(-3, -4), Vector2(3, -1), Vector2(-3, 2)],
	[Vector2(0, -4), Vector2(0, 4), Vector2(-4, -1), Vector2(0, 1), Vector2(4, -1)],
	[Vector2(-4, 4), Vector2(0, -4), Vector2(4, 4)],
	[Vector2(-3, -4), Vector2(3, 4), Vector2(0, 0), Vector2(3, -4), Vector2(-3, 4)],
]


## Design entry of a hull id (falls back to Classic).
static func hull_design(hull_id: StringName) -> Dictionary:
	return HULLS.get(hull_id, HULLS[DEFAULT_HULL])


## True when the hull pattern animates (Ship then redraws every frame).
static func is_animated(geometry: Dictionary) -> bool:
	return hull_design(geometry.get("hull", DEFAULT_HULL))["pattern"] == &"runway"


## Colors of a style id (falls back to the default scheme).
static func style_colors(style_id: StringName) -> Dictionary:
	return STYLES.get(style_id, STYLES[DEFAULT_STYLE])


## Empty-cell mounting socket colors [plate, bolts] for the current scheme.
static func socket_colors() -> Array[Color]:
	var style := _current()
	return [style.get("socket", Palette.SHIP_SEAM), style.get("socket_bolt", Palette.SHIP_SHADOW)]


static func _current() -> Dictionary:
	return style_colors(ShipLoadout.style_id)


## Precomputes outlines, pods, add-on plates and pattern runs for a cell set.
## cells: Vector2i(column, row) for every hull cell. hull_id: design to build
## (empty = the player's current ShipLoadout.hull_id).
static func build(cells: Array[Vector2i], cell_size: float, hull_id: StringName = &"") -> Dictionary:
	if hull_id == &"":
		hull_id = ShipLoadout.hull_id
	var design := hull_design(hull_id)
	var corner: StringName = design["corner"]
	var corner_size: float = design["corner_size"]
	var lookup: Dictionary = {}
	for cell in cells:
		lookup[cell] = true

	var outer := _union_outline(cells, lookup, cell_size, FRAME_GROW, corner_size, corner)
	var inner := _union_outline(cells, lookup, cell_size, FRAME_GROW - 3.0, corner_size - 1.0, corner)

	var pods := PackedVector2Array()
	var pod_dirs := PackedVector2Array()
	for cell in cells:
		for dir in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			var horizontal := Vector2i(cell.x + dir.x, cell.y)
			var vertical := Vector2i(cell.x, cell.y + dir.y)
			var diagonal: Vector2i = cell + dir
			if lookup.has(horizontal) or lookup.has(vertical) or lookup.has(diagonal):
				continue
			var corner_point := Vector2(
				(cell.x + (1 if dir.x > 0 else 0)) * cell_size,
				(cell.y + (1 if dir.y > 0 else 0)) * cell_size
			)
			pods.append(corner_point + Vector2(dir) * FRAME_GROW * 0.75)
			pod_dirs.append(Vector2(dir).normalized())

	var runes: Array = []
	for cell in cells:
		var origin := Vector2(cell) * cell_size
		for side in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if lookup.has(cell + side):
				continue
			var mid := origin + Vector2.ONE * cell_size * 0.5 + Vector2(side) * (cell_size * 0.5 + FRAME_GROW * 0.5)
			runes.append([mid, side.x != 0])

	var runs := _edge_runs(cells, lookup, cell_size)
	var features := _features(runs, design["feature"], cell_size)
	return {
		"hull": hull_id, "outer": outer, "inner": inner, "pods": pods, "pod_dirs": pod_dirs, "runes": runes,
		"runs": runs, "features": features,
	}


## Ground shadow of the whole hull (pods included).
static func draw_shadow(canvas: CanvasItem, geometry: Dictionary, offset: Vector2, alpha: float) -> void:
	var color := Color(0.0, 0.0, 0.0, Palette.SHADOW_COLOR.a * alpha)
	for outline in geometry["outer"]:
		canvas.draw_colored_polygon(Palette.offset_points(outline, offset), color)
	for feature in geometry.get("features", []):
		canvas.draw_colored_polygon(Palette.offset_points(feature, offset), color)
	for pod in geometry["pods"]:
		canvas.draw_circle(pod + offset, POD_RADIUS, color)


## Selectable thruster styles (Hangar > SHIP STYLE > THRUSTERS), drawn on the
## convex hull corners (geometry "pods" / "pod_dirs"). Each has a stowed look
## (deploy 0, on the ground) and unfolds for flight (deploy 1, animated by
## ShipLaunchController) before it fires (thrust):
## - pod:     the original round pod with a glowing nozzle.
## - diamond: square blocks turn 45 degrees into diamonds and fire down.
## - ring:    an arc round each corner (convex side out) pushes outward and
##            fires down along its length.
## - stilts:  L-shaped landing frames push out on pistons; the jet is hidden
##            under the middle of the hull (glow and dust round the edges).
## - fans:    fans tucked beside each corner swing out to the diagonal and spin
##            up, blowing air rings.
const DEFAULT_THRUSTER: StringName = &"pod"
const THRUSTERS := {
	&"pod": {"name": "Round Pods"},
	&"diamond": {"name": "Diamond"},
	&"ring": {"name": "Ring"},
	&"stilts": {"name": "Stilts"},
	&"fans": {"name": "Fans"},
}
const THRUSTER_ORDER: Array[StringName] = [&"pod", &"diamond", &"ring", &"stilts", &"fans"]
const CHROME := Color("B9B2A8")


static func _thruster(thruster_id: StringName) -> StringName:
	if thruster_id == &"":
		thruster_id = ShipLoadout.thruster_id
	return thruster_id if THRUSTERS.has(thruster_id) else DEFAULT_THRUSTER


## Thrusters that move on their own (fans spin, jets flicker) need redraws.
static func thruster_needs_redraw(thrust: float, deploy: float) -> bool:
	return thrust > 0.0 or (deploy > 0.0 and deploy < 1.0)


static func _pods_center(geometry: Dictionary) -> Vector2:
	var pods: PackedVector2Array = geometry["pods"]
	var sum := Vector2.ZERO
	for pod in pods:
		sum += pod
	return sum / float(maxi(pods.size(), 1))


## Where the jets are for the current style (local space): the exhaust FX
## emits from these.
static func nozzle_points(geometry: Dictionary, thruster_id: StringName = &"", deploy: float = 1.0) -> PackedVector2Array:
	var kind := _thruster(thruster_id)
	var pods: PackedVector2Array = geometry["pods"]
	var dirs: PackedVector2Array = geometry.get("pod_dirs", PackedVector2Array())
	var out := PackedVector2Array()
	if kind == &"stilts":
		out.append(_pods_center(geometry))
		return out
	for index in range(pods.size()):
		var p: Vector2 = pods[index]
		var d: Vector2 = dirs[index] if index < dirs.size() else Vector2.ZERO
		match kind:
			&"diamond":
				out.append(p + d * 14.0 * deploy)
			&"ring":
				out.append(p - d * 25.0 + d * (34.0 + 22.0 * deploy))
			&"fans":
				out.append(_fan_position(p, d, deploy))
			_:
				out.append(p)
	return out


## Thruster pods; drawn before the frame so the hull overlaps their inner side.
## thrust 0..1 fires the jets; deploy 0..1 unfolds them (style dependent).
static func draw_pods(canvas: CanvasItem, geometry: Dictionary, thrust: float, thruster_id: StringName = &"", deploy: float = 0.0) -> void:
	var style := _current()
	var kind := _thruster(thruster_id)
	var pods: PackedVector2Array = geometry["pods"]
	var dirs: PackedVector2Array = geometry.get("pod_dirs", PackedVector2Array())
	var now := float(Time.get_ticks_msec()) * 0.001
	if kind == &"stilts":
		_draw_under_jet(canvas, geometry, thrust, now)
	for index in range(pods.size()):
		var p: Vector2 = pods[index]
		var d: Vector2 = dirs[index] if index < dirs.size() else Vector2(1, 1).normalized()
		match kind:
			&"diamond":
				_draw_diamond(canvas, p, d, thrust, deploy, style, now)
			&"ring":
				_draw_ring(canvas, p, d, thrust, deploy, style, now)
			&"stilts":
				_draw_stilt(canvas, p, d, deploy, style)
			&"fans":
				_draw_fan(canvas, p, d, thrust, deploy, style, now)
			_:
				_draw_round_pod(canvas, p, thrust, style)


static func _draw_round_pod(canvas: CanvasItem, pod: Vector2, thrust: float, style: Dictionary) -> void:
	if style.get("glow", false):
		canvas.draw_circle(pod, POD_RADIUS + 8.0, Color(style["accent"], 0.14))
	canvas.draw_circle(pod, POD_RADIUS, style["iron"])
	canvas.draw_circle(pod + Vector2(-1.0, -1.0), POD_RADIUS - 3.5, style["band"])
	canvas.draw_circle(pod, POD_RADIUS - 8.0, Palette.UI_PANEL)
	canvas.draw_arc(pod, POD_RADIUS - 8.0, 0.0, TAU, 24, style["accent"], 2.5)
	if thrust > 0.01:
		canvas.draw_circle(pod, (POD_RADIUS - 10.0) * (0.5 + 0.5 * thrust), Palette.SHOT)
		canvas.draw_circle(pod, (POD_RADIUS - 14.0) * (0.5 + 0.5 * thrust), Palette.SHOT_CORE)
	else:
		canvas.draw_circle(pod, 4.0, style["iron"])
	for index in range(4):
		var angle := PI * 0.25 + PI * 0.5 * float(index)
		var bolt: Vector2 = pod + Vector2.RIGHT.rotated(angle) * (POD_RADIUS - 2.0)
		canvas.draw_rect(Rect2(bolt - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Palette.UI_PANEL)


## A downward jet seen from above: hot core, flicker and expanding rings.
static func _draw_jet(canvas: CanvasItem, p: Vector2, r: float, k: float, now: float) -> void:
	if k <= 0.01:
		return
	var flick := 0.85 + 0.15 * sin(now * 47.0 + p.x * 0.7 + p.y)
	canvas.draw_circle(p, r * 1.8 * k * flick, Color(Palette.SHOT, 0.26 * k))
	canvas.draw_circle(p, r * k * flick, Color(Palette.SHOT, 0.9))
	canvas.draw_circle(p, r * 0.5 * k, Palette.SHOT_CORE)
	for ring in range(2):
		var ph := fposmod(now * 3.0 + float(ring) * 0.5, 1.0)
		canvas.draw_arc(p, r * (1.2 + 1.6 * ph), 0.0, TAU, 20, Color(Palette.SHOT, 0.35 * (1.0 - ph) * k), 2.0)


static func _draw_diamond(canvas: CanvasItem, pod: Vector2, d: Vector2, thrust: float, deploy: float, style: Dictionary, now: float) -> void:
	var p := pod + d * 14.0 * deploy
	var a := PI * 0.25 * deploy
	var s := 17.0 + 3.0 * deploy
	var pts := PackedVector2Array()
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pts.append(p + ((c as Vector2) * s).rotated(a))
	if style.get("glow", false):
		canvas.draw_circle(p, s + 8.0, Color(style["accent"], 0.12))
	canvas.draw_colored_polygon(pts, style["iron"])
	var inner := PackedVector2Array()
	var window := PackedVector2Array()
	for q in pts:
		inner.append(p + (q - p) * 0.72 + Vector2(-1.0, -1.0))
		window.append(p + (q - p) * 0.38)
	canvas.draw_colored_polygon(inner, style["band"])
	canvas.draw_colored_polygon(window, Palette.UI_PANEL)
	var outline := window.duplicate()
	outline.append(window[0])
	canvas.draw_polyline(outline, style["accent"], 2.0)
	_draw_jet(canvas, p, 7.0, thrust, now)


static func _draw_ring(canvas: CanvasItem, pod: Vector2, d: Vector2, thrust: float, deploy: float, style: Dictionary, now: float) -> void:
	var corner := pod - d * 25.0
	var r := 34.0 + 22.0 * deploy
	var base := d.angle()
	var a0 := base - 0.62
	var a1 := base + 0.62
	# Two short arms from the hull corner to the arc.
	for end in [a0 + 0.25, a1 - 0.25]:
		var tip := corner + Vector2.RIGHT.rotated(end) * (r - 6.0)
		canvas.draw_line(corner, tip, style["iron"], 5.0)
		canvas.draw_line(corner, tip, style["band"], 2.0)
	if thrust > 0.01:
		canvas.draw_arc(corner, r, a0, a1, 24, Color(Palette.SHOT, 0.25 * thrust), 26.0 * thrust)
	canvas.draw_arc(corner, r, a0, a1, 24, style["iron"], 12.0)
	canvas.draw_arc(corner, r + 3.0, a0 + 0.04, a1 - 0.04, 24, Color(style["band"]).lightened(0.2), 2.5)
	canvas.draw_arc(corner, r - 3.5, a0 + 0.06, a1 - 0.06, 24, style["accent"] if thrust <= 0.01 else Palette.SHOT_CORE, 2.0)
	for end in [a0, a1]:
		canvas.draw_circle(corner + Vector2.RIGHT.rotated(end) * r, 6.0, style["iron"])
		canvas.draw_circle(corner + Vector2.RIGHT.rotated(end) * r, 2.5, style["accent"])
	if thrust > 0.01:
		for j in range(5):
			var a := lerpf(a0 + 0.1, a1 - 0.1, float(j) / 4.0)
			_draw_jet(canvas, corner + Vector2.RIGHT.rotated(a) * r, 5.0, thrust, now)


static func _draw_under_jet(canvas: CanvasItem, geometry: Dictionary, thrust: float, now: float) -> void:
	if thrust <= 0.01:
		return
	var center := _pods_center(geometry)
	var reach := 0.0
	for pod in geometry["pods"]:
		reach = maxf(reach, (pod as Vector2).distance_to(center))
	var flick := 0.9 + 0.1 * sin(now * 40.0)
	for ring in range(4):
		canvas.draw_circle(center, (reach * 0.8 + 18.0 * float(ring)) * flick, Color(Palette.SHOT, 0.07 * thrust))
	for ring in range(3):
		var ph := fposmod(now * 1.5 + float(ring) / 3.0, 1.0)
		canvas.draw_arc(center, reach * 0.85 + 90.0 * ph, 0.0, TAU, 48, Color("D9C8A8", 0.35 * (1.0 - ph) * thrust), 6.0)


static func _draw_stilt(canvas: CanvasItem, pod: Vector2, d: Vector2, deploy: float, style: Dictionary) -> void:
	var axis := Vector2(signf(d.x), signf(d.y))
	var base := pod - d * 11.0
	var elbow := base + d * (8.5 + 37.0 * deploy)
	var arms := [Vector2(-axis.x, 0.0) * 38.0, Vector2(0.0, -axis.y) * 38.0]
	var iron: Color = style["iron"]
	var band: Color = style["band"]
	var band_hi := band.lightened(0.2)
	# Pistons from the hull to each arm: dark sleeve + chrome rod.
	for arm in arms:
		var anchor: Vector2 = base - d * 16.0 + (arm as Vector2) * 0.55
		var joint: Vector2 = elbow + (arm as Vector2) * 0.55
		var mid := anchor.lerp(joint, 0.45)
		canvas.draw_line(anchor, mid, iron, 8.0)
		canvas.draw_line(mid, joint, CHROME, 4.0)
		canvas.draw_circle(joint, 4.5, iron)
	for arm in arms:
		var tip: Vector2 = elbow + arm
		canvas.draw_line(elbow + Vector2(3, 4), tip + Vector2(3, 4), Color(0, 0, 0, 0.2), 13.0)
	for arm in arms:
		var tip: Vector2 = elbow + arm
		canvas.draw_line(elbow, tip, iron, 13.0)
		canvas.draw_line(elbow, tip, band, 7.0)
		canvas.draw_line(elbow, tip, band_hi, 2.0)
		canvas.draw_circle(tip, 9.0, iron)
		canvas.draw_circle(tip, 6.0, band)
		canvas.draw_circle(tip + Vector2(-1.5, -1.5), 2.5, band_hi)
	canvas.draw_circle(elbow, 11.0, iron)
	canvas.draw_circle(elbow, 8.0, Palette.UI_PANEL)
	canvas.draw_arc(elbow, 8.0, d.angle() - 1.0, d.angle() + 1.0, 12, style["accent"], 3.0)
	canvas.draw_circle(elbow, 3.0, band_hi)


static func _fan_position(pod: Vector2, d: Vector2, deploy: float) -> Vector2:
	var corner := pod - d * 6.0
	var angle := lerp_angle(d.angle() - 1.15, d.angle(), deploy)
	return corner + Vector2.RIGHT.rotated(angle) * (22.0 + 12.0 * deploy)


static func _draw_fan(canvas: CanvasItem, pod: Vector2, d: Vector2, thrust: float, deploy: float, style: Dictionary, now: float) -> void:
	var corner := pod - d * 6.0
	var p := _fan_position(pod, d, deploy)
	var r := 20.0
	var spin := now * (0.6 + 26.0 * thrust)
	var iron: Color = style["iron"]
	canvas.draw_line(corner, p, iron, 6.0)
	if style.get("glow", false):
		canvas.draw_circle(p, r + 7.0, Color(style["accent"], 0.12))
	canvas.draw_circle(p, r, iron)
	canvas.draw_circle(p, r - 3.0, Palette.UI_PANEL)
	var blade_color := Color(style["band"]).lightened(0.25)
	for b in range(5):
		var a := spin + TAU * float(b) / 5.0
		canvas.draw_colored_polygon(PackedVector2Array([
			p + Vector2.RIGHT.rotated(a) * 3.0,
			p + Vector2.RIGHT.rotated(a + 0.3) * (r - 4.0),
			p + Vector2.RIGHT.rotated(a + 0.75) * (r - 5.0),
		]), Color(blade_color, 1.0 - 0.6 * thrust))
	if thrust > 0.01:
		canvas.draw_circle(p, r - 3.0, Color(blade_color, 0.25 * thrust))
		for ring in range(2):
			var ph := fposmod(now * 2.5 + float(ring) * 0.5, 1.0)
			canvas.draw_arc(p, r + 6.0 + 26.0 * ph, 0.0, TAU, 28, Color(1, 1, 1, 0.35 * (1.0 - ph) * thrust), 2.5)
	canvas.draw_circle(p, 5.0, iron)
	canvas.draw_circle(p, 2.5, style["accent"])


## Forged frame, add-on plates, bone floor tiles and the accent pattern.
static func draw_hull(canvas: CanvasItem, geometry: Dictionary, cells: Array[Vector2i], cell_size: float) -> void:
	var style := _current()
	var design := hull_design(geometry.get("hull", DEFAULT_HULL))
	var plates: bool = design["feature"] == &"plates"
	if not plates:
		for feature in geometry.get("features", []):
			canvas.draw_colored_polygon(feature, style["rim"])
			canvas.draw_colored_polygon(Palette.offset_points(feature, Vector2(1.5, 1.5)), Color(style["band"], 0.5))
	for outline in geometry["outer"]:
		canvas.draw_colored_polygon(outline, style["rim"])
	for outline in geometry["inner"]:
		canvas.draw_colored_polygon(Palette.offset_points(outline, INNER_SHIFT), style["iron"])
	if design.get("armor", &"") != &"":
		_draw_armor(canvas, geometry, design, style, cell_size)
	if plates:
		for feature in geometry.get("features", []):
			canvas.draw_colored_polygon(feature, style["iron"])
			canvas.draw_colored_polygon(_inset(feature, 1.2), style["band"])

	for cell in cells:
		var tile := Rect2(Vector2(cell) * cell_size + Vector2.ONE * TILE_INSET, Vector2.ONE * (cell_size - TILE_INSET * 2.0))
		Palette.draw_rounded_rect(canvas, tile, 5.0, style["tile_shadow"])
		Palette.draw_rounded_rect(canvas, Rect2(tile.position, tile.size - Vector2(3.0, 4.0)), 5.0, style["tile"])

	match design["pattern"]:
		&"diamond":
			for rune in geometry["runes"]:
				var mid: Vector2 = rune[0]
				var along_y: bool = rune[1]
				var long := Vector2(0.0, 6.0) if along_y else Vector2(6.0, 0.0)
				var short := Vector2(3.5, 0.0) if along_y else Vector2(0.0, 3.5)
				canvas.draw_colored_polygon(PackedVector2Array([mid - long, mid + short, mid + long, mid - short]), style["accent"])
		_:
			if style.get("glow", false):
				_draw_pattern(canvas, geometry, design, style, cell_size, true)
			_draw_pattern(canvas, geometry, design, style, cell_size, false)


const STEEL_DARK := Color("2C3035")
const STEEL := Color("6A727A")
const STEEL_FACE := Color("858D95")
const STEEL_LIT := Color("B4BCC3")


## Bevelled metal plate: dark lower-right edge, lit upper-left edge, flat face.
static func _bevel(canvas: CanvasItem, poly: PackedVector2Array, face: Color, lit: Color, dark: Color, bevel: float = 2.0) -> void:
	canvas.draw_colored_polygon(Palette.offset_points(poly, Vector2(1.5, 2.0)), Color(0, 0, 0, 0.35))
	canvas.draw_colored_polygon(poly, dark)
	var top := _inset(poly, 0.6)
	if top.size() >= 3:
		canvas.draw_colored_polygon(Palette.offset_points(top, Vector2(-0.8, -0.8)), lit)
	var inner := _inset(poly, bevel)
	if inner.size() >= 3:
		canvas.draw_colored_polygon(inner, face)


static func _glow_line(canvas: CanvasItem, from: Vector2, to: Vector2, accent: Color) -> void:
	canvas.draw_line(from, to, Color(accent, 0.22), 5.0)
	canvas.draw_line(from, to, Color(accent, 0.95), 1.8)


static func _bolt(canvas: CanvasItem, at: Vector2, radius: float = 2.4) -> void:
	canvas.draw_circle(at + Vector2(0.6, 0.8), radius, STEEL_DARK)
	canvas.draw_circle(at, radius, STEEL_LIT)
	canvas.draw_circle(at + Vector2(0.4, 0.4), radius * 0.7, STEEL)
	canvas.draw_circle(at - Vector2(0.6, 0.6), radius * 0.3, Color(1, 1, 1, 0.8))


## Blade armour on the frame: slanted painted plates with a steel lip and a
## glowing accent seam. Local run frame: x along the run, d = distance
## outward from the cell edge (the frame spans d 0..FRAME_GROW).
static func _draw_armor(canvas: CanvasItem, geometry: Dictionary, design: Dictionary, style: Dictionary, cell_size: float) -> void:
	var kind: StringName = design["armor"]
	var trim: float = design["trim"]
	for run in geometry["runs"]:
		var start: Vector2 = run["start"]
		var along: Vector2 = run["dir"]
		var out: Vector2 = run["normal"]
		var length: float = run["length"]
		var p := func(x: float, d: float) -> Vector2: return start + along * x + out * d
		var cells: int = roundi(length / cell_size)
		var t0: float = trim if run["convex_start"] else 0.0
		var t1: float = trim if run["convex_end"] else 0.0
		match kind:
			&"blade":
				# Slanted painted blades with a steel lip and a glowing seam.
				var pf: Color = style["rim"]
				var pl: Color = Color(style["rim"]).lightened(0.3)
				var pd: Color = Color(style["iron"]).darkened(0.35)
				for index in range(cells):
					var a: float = cell_size * float(index) + 2.0
					var b: float = cell_size * float(index + 1) + 4.0
					if index == 0:
						a = maxf(a, t0 * 0.75)
					if index == cells - 1:
						b = minf(b, length - t1 * 0.75)
					var poly := PackedVector2Array([p.call(a, -1.0), p.call(a + 9.0, 17.0), p.call(b, 17.0), p.call(b - 9.0, -1.0)])
					_bevel(canvas, poly, pf, pl, pd, 2.2)
					# Steel lip on the outer edge.
					var lip := PackedVector2Array([p.call(a + 7.5, 14.0), p.call(a + 9.0, 17.0), p.call(b, 17.0), p.call(b - 1.5, 14.0)])
					canvas.draw_colored_polygon(lip, STEEL_FACE)
					canvas.draw_line(p.call(a + 8.0, 14.3), p.call(b - 1.3, 14.3), STEEL_LIT, 1.0)
					_glow_line(canvas, p.call(a + 6.0, 6.0), p.call(b - 9.0, 6.0), style["accent"])
					_bolt(canvas, p.call(a + 4.0, 2.5), 1.8)


## Accent pattern along the exposed edge runs. Local run frame: x along the
## run (clockwise), y < 0 points away from the hull, the frame band is
## centred on y = -FRAME_GROW / 2. glow: wide faint pass (Deep Space).
static func _draw_pattern(canvas: CanvasItem, geometry: Dictionary, design: Dictionary, style: Dictionary, cell_size: float, glow: bool) -> void:
	var accent: Color = style["accent"]
	if glow:
		accent = Color(accent, 0.22)
	var widen: float = 2.6 if glow else 1.0
	var band_y: float = -FRAME_GROW * 0.5
	var time: float = float(Time.get_ticks_msec()) / 1000.0
	var trim: float = design["trim"]
	var glyph_index: int = 0
	var travelled: float = 0.0
	for run in geometry.get("runs", []):
		var start: Vector2 = run["start"]
		var along: Vector2 = run["dir"]
		var out: Vector2 = run["normal"]
		var length: float = run["length"]
		var t0: float = trim if run["convex_start"] else 6.0
		var t1: float = trim if run["convex_end"] else 6.0
		var at := func(x: float, y: float) -> Vector2: return start + along * x - out * y
		match design["pattern"]:
			&"rune":
				var count: int = roundi(length / cell_size)
				for index in range(count):
					var c: float = cell_size * (float(index) + 0.5)
					var glyph: Array = RUNE_GLYPHS[glyph_index % RUNE_GLYPHS.size()]
					glyph_index += 1
					var points := PackedVector2Array()
					for point in glyph:
						points.append(at.call(c + point.x * 0.9, band_y + point.y * 0.9))
					canvas.draw_polyline(points, accent, 1.6 * widen)
					for dx in [-14.0, 14.0]:
						canvas.draw_circle(at.call(c + dx, band_y), 1.1 * widen, Color(accent, accent.a * 0.7))
			&"hazard":
				var width: float = minf(52.0, length * 0.42)
				var x0: float = length * 0.5 - width * 0.5
				var block := PackedVector2Array([at.call(x0, band_y + 4.5), at.call(x0 + width, band_y + 4.5), at.call(x0 + width, band_y - 4.5), at.call(x0, band_y - 4.5)])
				if glow:
					canvas.draw_colored_polygon(_grow_quad(block, 3.0), accent)
					continue
				canvas.draw_colored_polygon(block, accent)
				var stripe_x: float = x0 - 8.0
				while stripe_x < x0 + width:
					var stripe := PackedVector2Array([
						at.call(stripe_x, band_y + 4.5), at.call(stripe_x + 4.0, band_y - 4.5),
						at.call(stripe_x + 8.0, band_y - 4.5), at.call(stripe_x + 4.0, band_y + 4.5),
					])
					for piece in Geometry2D.intersect_polygons(stripe, block):
						canvas.draw_colored_polygon(piece, Palette.UI_PANEL)
					stripe_x += 8.0
			&"runway":
				var x0: float = t0
				var x1: float = length - t1
				if x1 - x0 < 8.0:
					travelled += length
					continue
				if not glow:
					var dash: float = x0
					while dash < x1:
						canvas.draw_line(at.call(dash, band_y), at.call(minf(dash + 5.0, x1), band_y), Color(accent, 0.55), 1.4)
						dash += 11.0
				var x: float = x0 + 6.0
				while x < x1 - 2.0:
					# A pulse of light runs clockwise around the whole hull.
					var phase: float = fposmod(time * 140.0 - (travelled + x), 260.0)
					var lit: float = clampf(1.0 - phase / 70.0, 0.0, 1.0)
					var alpha: float = 0.3 + 0.7 * lit
					canvas.draw_circle(at.call(x, band_y), (2.0 + 0.6 * lit) * widen, Color(accent, accent.a * alpha))
					x += 16.0
		travelled += length


## Exposed edges of the cell set merged into straight runs, each clockwise
## (outward normal on the left of the direction in screen space). Ends that
## sit on a convex hull corner carry a thruster pod.
static func _edge_runs(cells: Array[Vector2i], lookup: Dictionary, cell_size: float) -> Array:
	var edges: Array = []
	for cell in cells:
		var o := Vector2(cell) * cell_size
		var s := cell_size
		if not lookup.has(cell + Vector2i(0, -1)):
			edges.append([o, o + Vector2(s, 0), Vector2(0, -1)])
		if not lookup.has(cell + Vector2i(1, 0)):
			edges.append([o + Vector2(s, 0), o + Vector2(s, s), Vector2(1, 0)])
		if not lookup.has(cell + Vector2i(0, 1)):
			edges.append([o + Vector2(s, s), o + Vector2(0, s), Vector2(0, 1)])
		if not lookup.has(cell + Vector2i(-1, 0)):
			edges.append([o + Vector2(0, s), o, Vector2(-1, 0)])
	var merged := true
	while merged:
		merged = false
		for a_index in range(edges.size()):
			for b_index in range(edges.size()):
				if a_index == b_index:
					continue
				var a: Array = edges[a_index]
				var b: Array = edges[b_index]
				if a[2] == b[2] and (a[1] as Vector2).is_equal_approx(b[0]):
					a[1] = b[1]
					edges.remove_at(b_index)
					merged = true
					break
			if merged:
				break
	var runs: Array = []
	for edge in edges:
		var start: Vector2 = edge[0]
		var end: Vector2 = edge[1]
		runs.append({
			"start": start, "end": end, "dir": (end - start).normalized(), "normal": edge[2],
			"length": start.distance_to(end),
			"convex_start": _is_convex_corner(start, lookup, cell_size),
			"convex_end": _is_convex_corner(end, lookup, cell_size),
		})
	return runs


## A grid corner is a convex hull corner when exactly one cell touches it.
static func _is_convex_corner(point: Vector2, lookup: Dictionary, cell_size: float) -> bool:
	var cx: int = roundi(point.x / cell_size)
	var cy: int = roundi(point.y / cell_size)
	var count: int = 0
	for cell in [Vector2i(cx - 1, cy - 1), Vector2i(cx, cy - 1), Vector2i(cx - 1, cy), Vector2i(cx, cy)]:
		if lookup.has(cell):
			count += 1
	return count == 1


## Add-on plates outside the frame, one polygon each (hull-local pixels).
static func _features(runs: Array, kind: StringName, cell_size: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if kind == &"":
		return result
	for run in runs:
		var start: Vector2 = run["start"]
		var along: Vector2 = run["dir"]
		var out: Vector2 = run["normal"]
		var length: float = run["length"]
		var edge := func(x: float, offset: float) -> Vector2: return start + along * x + out * (FRAME_GROW + offset)
		match kind:
			&"buttress":
				for index in range(roundi(length / cell_size)):
					var c: float = cell_size * (float(index) + 0.5)
					result.append(PackedVector2Array([edge.call(c - 13.0, -2.0), edge.call(c - 8.0, 6.0), edge.call(c + 8.0, 6.0), edge.call(c + 13.0, -2.0)]))
			&"plates":
				for index in range(roundi(length / cell_size)):
					var a: float = cell_size * float(index) + 6.0
					var b: float = cell_size * float(index + 1) - 6.0
					result.append(PackedVector2Array([edge.call(a, -2.0), edge.call(a, 5.0), edge.call(b, 5.0), edge.call(b, -2.0)]))
			&"deck":
				if length >= cell_size * 2.0 - 0.5:
					var half: float = length * 0.5 - 34.0
					var mid: float = length * 0.5
					result.append(PackedVector2Array([edge.call(mid - half - 8.0, -2.0), edge.call(mid - half, 7.0), edge.call(mid + half, 7.0), edge.call(mid + half + 8.0, -2.0)]))
	return result


static func _inset(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var shrunk := Geometry2D.offset_polygon(points, -amount, Geometry2D.JOIN_MITER)
	return shrunk[0] if not shrunk.is_empty() else points


static func _grow_quad(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var grown := Geometry2D.offset_polygon(points, amount, Geometry2D.JOIN_ROUND)
	return grown[0] if not grown.is_empty() else points


## Union of per-cell rectangles (grown only on exposed sides), then chamfered.
static func _union_outline(cells: Array[Vector2i], lookup: Dictionary, cell_size: float, grow: float, chamfer: float, corner: StringName = &"chamfer") -> Array[PackedVector2Array]:
	var merged: Array[PackedVector2Array] = []
	for cell in cells:
		var left := grow if not lookup.has(cell + Vector2i(-1, 0)) else 0.0
		var top := grow if not lookup.has(cell + Vector2i(0, -1)) else 0.0
		var right := grow if not lookup.has(cell + Vector2i(1, 0)) else 0.0
		var bottom := grow if not lookup.has(cell + Vector2i(0, 1)) else 0.0
		var origin := Vector2(cell) * cell_size
		var rect := PackedVector2Array([
			origin + Vector2(-left, -top),
			origin + Vector2(cell_size + right, -top),
			origin + Vector2(cell_size + right, cell_size + bottom),
			origin + Vector2(-left, cell_size + bottom),
		])
		merged = _merge_into(merged, rect)

	var result: Array[PackedVector2Array] = []
	for outline in merged:
		# Holes (ring-shaped hulls) are skipped; tiles cover the interior anyway.
		if Geometry2D.is_polygon_clockwise(outline) != Geometry2D.is_polygon_clockwise(merged[0]):
			continue
		result.append(_step(outline, chamfer) if corner == &"step" else _chamfer(outline, chamfer))
	return result


static func _merge_into(existing: Array[PackedVector2Array], polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	var current := polygon
	var untouched: Array[PackedVector2Array] = []
	for other in existing:
		var union := Geometry2D.merge_polygons(current, other)
		if union.size() == 1:
			current = union[0]
		else:
			untouched.append(other)
	untouched.append(current)
	return untouched


## Cuts every convex corner of an outline by `size` along both edges.
static func _chamfer(outline: PackedVector2Array, size: float) -> PackedVector2Array:
	var clockwise := Geometry2D.is_polygon_clockwise(outline)
	var count := outline.size()
	var result := PackedVector2Array()
	for index in range(count):
		var prev := outline[(index - 1 + count) % count]
		var point := outline[index]
		var next := outline[(index + 1) % count]
		var to_prev := prev - point
		var to_next := next - point
		var cross := (point - prev).cross(next - point)
		if absf(cross) < 0.001:
			continue
		var convex := (cross < 0.0) if clockwise else (cross > 0.0)
		if convex and to_prev.length() > size * 1.2 and to_next.length() > size * 1.2:
			result.append(point + to_prev.normalized() * size)
			result.append(point + to_next.normalized() * size)
		else:
			result.append(point)
	return result


## Cuts every convex corner of an outline into two stair steps of size / 2.
static func _step(outline: PackedVector2Array, size: float) -> PackedVector2Array:
	var clockwise := Geometry2D.is_polygon_clockwise(outline)
	var count := outline.size()
	var result := PackedVector2Array()
	for index in range(count):
		var prev := outline[(index - 1 + count) % count]
		var point := outline[index]
		var next := outline[(index + 1) % count]
		var to_prev := prev - point
		var to_next := next - point
		var cross := (point - prev).cross(next - point)
		if absf(cross) < 0.001:
			continue
		var convex := (cross < 0.0) if clockwise else (cross > 0.0)
		if convex and to_prev.length() > size * 1.2 and to_next.length() > size * 1.2:
			var back := to_prev.normalized()
			var fwd := to_next.normalized()
			result.append(point + back * size)
			result.append(point + back * size + fwd * size * 0.5)
			result.append(point + back * size * 0.5 + fwd * size * 0.5)
			result.append(point + back * size * 0.5 + fwd * size)
			result.append(point + fwd * size)
		else:
			result.append(point)
	return result
