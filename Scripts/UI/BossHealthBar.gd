class_name BossHealthBar
extends Control

## Top-center boss health bar, design B "crystal segments".
##
## A hexagonal stone portrait of the boss sits on the left; health is a row of
## purple crystal cells. Lost health first turns into a pale "chip" that drains
## after a short delay, and every cell that empties shatters into shards.
## The bar appears (cells fill
## in one by one) while any enemy of tier BOSS is alive and fades out after it
## dies. Reads BasicEnemy.max_health / get_current_health() and
## never changes gameplay state.

const CELL_COUNT: int = 20
const PANEL_SIZE := Vector2(540.0, 72.0)
## Space left of the panel for the portrait badge.
const LEFT_PAD: float = 48.0
const TOP: float = 14.0
const BADGE_RADIUS: float = 40.0
const CELL_ORIGIN := Vector2(58.0, 40.0)
const CELL_SIZE := Vector2(21.0, 18.0)
const CELL_GAP: float = 2.4
const CELL_SLANT: float = 5.0

const FADE_SPEED: float = 4.0
## The pale chip waits this long, then drains at CHIP_SPEED (fraction/s).
const CHIP_DELAY: float = 0.45
const CHIP_SPEED: float = 0.5
## Seconds for the cells to fill when the boss appears.
const INTRO_TIME: float = 0.9

## Subtitles shown next to a boss's name, by enemy_id.
const SUBTITLES := {
	&"rock_titan": "THE WALKING MOUNTAIN",
	&"goblin_giant_chariot": "THE WARBAND WAGON",
	&"demon_lord": "SOVEREIGN OF THE INFERNO",
	&"giant_frank": "THE STITCHED COLOSSUS",
	&"mega_monster": "KING OF THE BLIZZARD",
}

var _boss: BasicEnemy
var _ratio: float = 1.0
var _chip_ratio: float = 1.0
var _chip_wait: float = 0.0
var _intro: float = 1.0
var _hit_flash: float = 0.0
var _name: String = ""
var _subtitle: String = ""
var _health_text: String = ""
var _last_full_cells: int = CELL_COUNT
var _shards: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _theme: Dictionary = {}

## Per-boss colour themes (cells, shards, badge). Unknown bosses use the default.
const THEMES := {
	&"default": {
		"badge": &"stone",
		"chip": Palette.ENEMY_EYE_GLOW,
		"body": Palette.ENEMY_EYE_DEEP,
		"top": Palette.ENEMY_EYE,
	},
	&"goblin_giant_chariot": {
		"badge": &"chariot",
		"chip": Color("E4F59A"),
		"body": Color("4F8A2A"),
		"top": Color("8CCB45"),
	},
	&"giant_frank": {
		"badge": &"frank",
		"chip": Color("B8E8FF"),
		"body": Color("3E6B3A"),
		"top": Color("8DBA7A"),
	},
	&"demon_lord": {
		"badge": &"demon",
		"chip": Color("FFD23F"),
		"body": Color("A82A26"),
		"top": Color("FF6A3D"),
	},
	&"mega_monster": {
		"badge": &"yeti",
		"chip": Color("E8FBFF"),
		"body": Color("2B8FB0"),
		"top": Color("9FE7FF"),
	},
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	var width: float = LEFT_PAD + PANEL_SIZE.x
	offset_left = -(LEFT_PAD + PANEL_SIZE.x * 0.5)
	offset_right = offset_left + width
	offset_top = TOP - 10.0
	offset_bottom = offset_top + PANEL_SIZE.y + 20.0
	modulate.a = 0.0
	_theme = THEMES[&"default"]
	_rng.randomize()


func _process(delta: float) -> void:
	if not is_instance_valid(_boss) or _boss.is_dying():
		var found := _find_boss()
		if found != null and found != _boss:
			_start(found)
		elif found == null:
			_boss = null

	var alive: bool = is_instance_valid(_boss) and not _boss.is_dying()
	modulate.a = move_toward(modulate.a, 1.0 if alive else 0.0, FADE_SPEED * delta)
	visible = modulate.a > 0.001 or not _shards.is_empty()

	var previous: float = _ratio
	if alive:
		_ratio = clampf(_boss.get_current_health() / maxf(_boss.max_health, 1.0), 0.0, 1.0)
		_health_text = "%d / %d" % [ceili(_boss.get_current_health()), int(_boss.max_health)]
	else:
		_ratio = 0.0
	if _ratio < previous - 0.0001:
		_chip_wait = CHIP_DELAY
		_hit_flash = 0.12

	_intro = minf(_intro + delta / INTRO_TIME, 1.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if _chip_wait > 0.0:
		_chip_wait -= delta
	else:
		_chip_ratio = move_toward(_chip_ratio, _ratio, CHIP_SPEED * delta)
	_chip_ratio = maxf(_chip_ratio, _ratio)

	# Every cell that empties shatters.
	var full_cells: int = int(floor(_ratio * CELL_COUNT + 0.0001))
	if full_cells < _last_full_cells and _intro >= 1.0:
		for cell in range(full_cells, _last_full_cells):
			_shatter(cell)
	_last_full_cells = full_cells

	var gravity := Vector2(0.0, 260.0)
	for index in range(_shards.size() - 1, -1, -1):
		var shard := _shards[index]
		shard["age"] += delta
		if shard["age"] >= shard["life"]:
			_shards.remove_at(index)
			continue
		shard["vel"] += gravity * delta
		shard["pos"] += shard["vel"] * delta
		shard["rot"] += shard["spin"] * delta
	queue_redraw()


func _start(boss: BasicEnemy) -> void:
	_boss = boss
	_name = boss.enemy_name.to_upper()
	_subtitle = SUBTITLES.get(boss.enemy_id, "")
	_theme = THEMES.get(boss.enemy_id, THEMES[&"default"])
	_ratio = 1.0
	_chip_ratio = 1.0
	_chip_wait = 0.0
	_intro = 0.0
	_last_full_cells = CELL_COUNT
	_shards.clear()


func _find_boss() -> BasicEnemy:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as BasicEnemy
		if enemy != null and enemy.enemy_tier == BasicEnemy.EnemyTier.BOSS and not enemy.is_dying():
			return enemy
	return null


# ==========================================
# Drawing
# ==========================================

func _draw() -> void:
	var origin := Vector2(LEFT_PAD, 10.0)
	var font := get_theme_default_font()

	# Panel.
	draw_style_box(_panel_style(), Rect2(origin, PANEL_SIZE))
	_draw_badge(origin + Vector2(6.0, PANEL_SIZE.y * 0.5))

	# Name, subtitle, numbers.
	var text_y: float = origin.y + 27.0
	draw_string(font, Vector2(origin.x + CELL_ORIGIN.x, text_y), _spaced(_name), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.UI_TEXT)
	var name_width: float = font.get_string_size(_spaced(_name), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	if _subtitle != "":
		draw_string(font, Vector2(origin.x + CELL_ORIGIN.x + name_width + 16.0, text_y), _subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.UI_MUTED)
	draw_string(font, Vector2(origin.x + PANEL_SIZE.x - 14.0 - 140.0, text_y), _health_text, HORIZONTAL_ALIGNMENT_RIGHT, 140, 11, Palette.UI_MUTED)

	# Crystal cells.
	var visible_cells: float = _intro * CELL_COUNT
	for cell in range(CELL_COUNT):
		_draw_cell(origin, cell, visible_cells)

	# Shards from broken cells.
	for shard in _shards:
		var t: float = shard["age"] / shard["life"]
		var size: float = shard["size"]
		var diamond := PackedVector2Array([
			Vector2(0.0, -size), Vector2(size * 0.6, 0.0), Vector2(0.0, size), Vector2(-size * 0.6, 0.0),
		])
		draw_set_transform(origin + shard["pos"], shard["rot"], Vector2.ONE)
		draw_colored_polygon(diamond, Color(shard["color"], 1.0 - t))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _cell_points(origin: Vector2, cell: int) -> PackedVector2Array:
	var x0: float = origin.x + CELL_ORIGIN.x + float(cell) * (CELL_SIZE.x + CELL_GAP)
	var y0: float = origin.y + CELL_ORIGIN.y
	return PackedVector2Array([
		Vector2(x0 + CELL_SLANT, y0), Vector2(x0 + CELL_SIZE.x, y0),
		Vector2(x0 + CELL_SIZE.x - CELL_SLANT, y0 + CELL_SIZE.y), Vector2(x0, y0 + CELL_SIZE.y),
	])


func _draw_cell(origin: Vector2, cell: int, visible_cells: float) -> void:
	var points := _cell_points(origin, cell)
	var filled: float = clampf(_ratio * CELL_COUNT - float(cell), 0.0, 1.0)
	var chipped: float = clampf(_chip_ratio * CELL_COUNT - float(cell), 0.0, 1.0)
	if float(cell) >= visible_cells:
		filled = 0.0
		chipped = 0.0

	# Empty socket with a small crack line.
	draw_colored_polygon(points, Color(Palette.UI_PANEL_RAISED, 0.8))
	if filled <= 0.0 and chipped <= 0.0:
		var x0: float = points[3].x
		draw_colored_polygon(PackedVector2Array([
			Vector2(x0 + 7.0, points[0].y + 3.0), Vector2(x0 + 10.0, points[0].y + 3.0), Vector2(x0 + 6.0, points[3].y - 3.0),
		]), Palette.MECH)
		return

	if chipped > filled:
		draw_colored_polygon(_cell_slice(points, chipped), Color(_theme["chip"], 0.85))
	if filled > 0.0:
		var body := _cell_slice(points, filled)
		var flash: float = clampf(_hit_flash / 0.12, 0.0, 1.0) if filled < 1.0 or cell == int(_ratio * CELL_COUNT) - 1 else 0.0
		draw_colored_polygon(body, (_theme["body"] as Color).lerp(_theme["chip"], flash * 0.6))
		# Lit upper half of the crystal.
		var mid_y: float = (points[0].y + points[3].y) * 0.5
		var top_half := PackedVector2Array([body[0], body[1], Vector2(body[1].x - CELL_SLANT * 0.5, mid_y), Vector2(body[0].x - CELL_SLANT * 0.5, mid_y)])
		draw_colored_polygon(top_half, (_theme["top"] as Color).lerp(_theme["chip"], flash))


## The left `amount` (0..1) of a slanted cell.
func _cell_slice(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	if amount >= 0.999:
		return points
	var width: float = (CELL_SIZE.x - CELL_SLANT) * amount
	return PackedVector2Array([
		points[0], Vector2(points[0].x + width, points[0].y),
		Vector2(points[3].x + width, points[3].y), points[3],
	])


func _shatter(cell: int) -> void:
	var points := _cell_points(Vector2.ZERO, cell)
	var center: Vector2 = (points[0] + points[2]) * 0.5
	for index in range(5):
		_shards.append({
			"pos": center + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-4.0, 4.0)),
			"vel": Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(-120.0, -30.0)),
			"size": _rng.randf_range(2.5, 4.5),
			"rot": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-10.0, 10.0),
			"life": _rng.randf_range(0.45, 0.8),
			"age": 0.0,
			"color": _theme["chip"] if index % 2 == 0 else _theme["top"],
		})


func _draw_badge(center: Vector2) -> void:
	if _theme.get("badge", &"stone") == &"chariot":
		_draw_chariot_badge(center)
	elif _theme.get("badge", &"stone") == &"yeti":
		_draw_yeti_badge(center)
	elif _theme.get("badge", &"stone") == &"demon":
		_draw_demon_badge(center)
	elif _theme.get("badge", &"stone") == &"frank":
		_draw_frank_badge(center)
	else:
		_draw_stone_badge(center)


## Goblin Giant Chariot portrait: an armoured war boar's head, front-on, on a
## battered wooden plate with an iron rim, a goblin war banner behind it.
func _draw_chariot_badge(center: Vector2) -> void:
	var hexagon := PackedVector2Array()
	for index in range(6):
		hexagon.append(center + Vector2.RIGHT.rotated(PI / 6.0 + PI / 3.0 * float(index)) * BADGE_RADIUS)
	draw_colored_polygon(Palette.offset_points(hexagon, Vector2(4.0, 6.0)), Palette.SHADOW_COLOR)
	draw_colored_polygon(hexagon, Palette.GOBLIN_IRON_DARK)
	var inner := PackedVector2Array()
	for point in hexagon:
		inner.append(center + (point - center) * 0.84)
	draw_colored_polygon(inner, Color("2F4A22"))
	# Planks and a crack.
	for plank_x in [-12.0, 12.0]:
		draw_line(center + Vector2(plank_x, -30.0), center + Vector2(plank_x, 30.0), Color("223618"), 2.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-30.0, -10.0), center + Vector2(-12.0, -26.0), center + Vector2(-4.0, -22.0), center + Vector2(-26.0, -2.0),
	]), Color("3E5E2C"))
	draw_polyline(PackedVector2Array([center + Vector2(20.0, -28.0), center + Vector2(24.0, -18.0), center + Vector2(19.0, -10.0)]), Color("223618"), 1.5)
	# Rivets on the rim.
	for point in hexagon:
		draw_circle(center + (point - center) * 0.92, 2.0, Palette.GOBLIN_IRON_LIGHT)
	# Red goblin banner tip behind the head.
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(14.0, -32.0), center + Vector2(32.0, -26.0), center + Vector2(22.0, -20.0), center + Vector2(30.0, -12.0), center + Vector2(14.0, -14.0),
	]), Palette.GOBLIN_CLOTH)
	draw_line(center + Vector2(14.0, -34.0), center + Vector2(14.0, -4.0), Palette.GOBLIN_WOOD_DARK, 2.0)

	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)
	var c: Vector2 = center + Vector2(0.0, 4.0)
	# Ears.
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(side * 12.0, -14.0), c + Vector2(side * 26.0, -24.0), c + Vector2(side * 20.0, -8.0),
		]), Palette.GOBLIN_FUR)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(side * 14.0, -14.0), c + Vector2(side * 23.0, -20.0), c + Vector2(side * 19.0, -10.0),
		]), Palette.GOBLIN_LEATHER)
	# Head.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-17.0, -16.0), c + Vector2(17.0, -16.0), c + Vector2(20.0, 2.0), c + Vector2(13.0, 18.0),
		c + Vector2(-13.0, 18.0), c + Vector2(-20.0, 2.0),
	]), Palette.GOBLIN_FUR)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-17.0, -16.0), c + Vector2(17.0, -16.0), c + Vector2(8.0, -6.0), c + Vector2(-8.0, -6.0),
	]), Palette.GOBLIN_FUR_LIGHT)
	# Iron chanfron down the forehead.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-8.0, -19.0), c + Vector2(8.0, -19.0), c + Vector2(6.0, 4.0), c + Vector2(-6.0, 4.0),
	]), Palette.GOBLIN_IRON)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-8.0, -19.0), c + Vector2(0.0, -19.0), c + Vector2(0.0, 4.0), c + Vector2(-6.0, 4.0),
	]), Palette.GOBLIN_IRON_LIGHT)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-3.0, -19.0), c + Vector2(3.0, -19.0), c + Vector2(0.0, -27.0)]), Palette.GOBLIN_IRON_LIGHT)
	# Angry red eyes.
	for side in [-1.0, 1.0]:
		var eye: Vector2 = c + Vector2(side * 12.0, -4.0)
		draw_circle(eye, 5.5, Color(Palette.GOBLIN_EYE, 0.22 + 0.2 * pulse))
		draw_colored_polygon(PackedVector2Array([
			eye + Vector2(-side * 4.0, -2.5), eye + Vector2(side * 4.0, -0.5), eye + Vector2(side * 2.0, 2.5), eye + Vector2(-side * 3.0, 1.5),
		]), Palette.GOBLIN_EYE)
	# Snout.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-10.0, 6.0), c + Vector2(10.0, 6.0), c + Vector2(11.0, 16.0), c + Vector2(-11.0, 16.0),
	]), Palette.GOBLIN_LEATHER)
	draw_circle(c + Vector2(-4.5, 11.0), 2.2, Palette.GOBLIN_WOOD_DARK)
	draw_circle(c + Vector2(4.5, 11.0), 2.2, Palette.GOBLIN_WOOD_DARK)
	# Tusks curling up.
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(side * 9.0, 16.0), c + Vector2(side * 14.0, 15.0), c + Vector2(side * 21.0, 2.0),
		]), Palette.GOBLIN_BONE)


## Mega Monster portrait: a shaggy white yeti face, front-on, with an ice
## crown, ram horns and glowing cyan eyes, on a frosted ice plate.
func _draw_yeti_badge(center: Vector2) -> void:
	var hexagon := PackedVector2Array()
	for index in range(6):
		hexagon.append(center + Vector2.RIGHT.rotated(PI / 6.0 + PI / 3.0 * float(index)) * BADGE_RADIUS)
	draw_colored_polygon(Palette.offset_points(hexagon, Vector2(4.0, 6.0)), Palette.SHADOW_COLOR)
	draw_colored_polygon(hexagon, Color("1F4E66"))
	var inner := PackedVector2Array()
	for point in hexagon:
		inner.append(center + (point - center) * 0.84)
	draw_colored_polygon(inner, Color("3E7FA0"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-30.0, -8.0), center + Vector2(-8.0, -30.0), center + Vector2(4.0, -26.0), center + Vector2(-26.0, 2.0),
	]), Color("5E9DBD"))
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)
	var c: Vector2 = center + Vector2(0.0, 5.0)
	# Ram horns curling out to the sides.
	for side in [-1.0, 1.0]:
		var horn := PackedVector2Array()
		for k in range(12):
			var a := float(k) / 11.0 * 4.2
			horn.append(c + Vector2(side * (14.0 + 9.0 * sin(a * 0.75)), -10.0 + 7.0 * (1.0 - cos(a * 0.75))) + Vector2(side * cos(a) * 2.0, sin(a) * 2.0))
		draw_polyline(horn, Color("B9AE98"), 5.0)
		draw_polyline(horn, Color("E8E0CF"), 2.0)
	# Shaggy head.
	var fur := PackedVector2Array()
	for k in range(24):
		var a := TAU * float(k) / 24.0
		var r := 21.0 if k % 2 == 0 else 17.5
		fur.append(c + Vector2(cos(a) * r, sin(a) * r * 0.95))
	draw_colored_polygon(fur, Color("BCD3E2"))
	draw_circle(c + Vector2(-5.0, -7.0), 9.0, Color("E8F3FA"))
	# Blue face.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-12.0, -4.0), c + Vector2(12.0, -4.0), c + Vector2(10.0, 12.0), c + Vector2(0.0, 16.0), c + Vector2(-10.0, 12.0),
	]), Color("4A7393"))
	# Ice crown.
	for spec in [[-12.0, 10.0], [-6.0, 14.0], [0.0, 17.0], [6.0, 14.0], [12.0, 10.0]]:
		var base: Vector2 = c + Vector2(spec[0], -17.0)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-3.2, 2.0), base + Vector2(0.0, -spec[1]), base + Vector2(3.2, 2.0)]), Color("2B8FB0"))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-1.4, 1.0), base + Vector2(0.0, -spec[1] + 3.0), base + Vector2(1.6, 1.0)]), Color("9FE7FF"))
	# Glowing eyes, heavy brows, fangs.
	for side in [-1.0, 1.0]:
		var eye: Vector2 = c + Vector2(side * 6.0, 2.0)
		draw_circle(eye, 5.0, Color("7FF3FF", 0.25 + 0.2 * pulse))
		draw_circle(eye, 2.6, Color("7FF3FF"))
		draw_line(eye + Vector2(-side * 1.0, -5.0), eye + Vector2(side * 5.0, -2.0), Color("14202B"), 2.4)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-5.0, 9.0), c + Vector2(5.0, 9.0), c + Vector2(4.0, 13.0), c + Vector2(-4.0, 13.0)]), Color("1A2633"))
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(side * 4.5, 9.0), c + Vector2(side * 2.0, 9.0), c + Vector2(side * 3.2, 13.5)]), Color.WHITE)


## Giant Frank portrait: the classic flat-topped green giant, front-on -
## black hair with a jagged fringe, a stitched brow, neck bolts and pale
## glowing eyes, on a lab-steel plate crackling with blue electricity.
func _draw_frank_badge(center: Vector2) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(t * 2.2)
	var hexagon := PackedVector2Array()
	for index in range(6):
		hexagon.append(center + Vector2.RIGHT.rotated(PI / 6.0 + PI / 3.0 * float(index)) * BADGE_RADIUS)
	draw_colored_polygon(Palette.offset_points(hexagon, Vector2(4.0, 6.0)), Palette.SHADOW_COLOR)
	draw_colored_polygon(hexagon, Color("1C2226"))
	var inner := PackedVector2Array()
	for point in hexagon:
		inner.append(center + (point - center) * 0.84)
	draw_colored_polygon(inner, Color("2E3A40"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-30.0, -10.0), center + Vector2(-10.0, -30.0), center + Vector2(0.0, -27.0), center + Vector2(-26.0, -1.0),
	]), Color("3E4C54"))
	var c: Vector2 = center + Vector2(0.0, 4.0)
	# Neck and bolts.
	draw_rect(Rect2(c + Vector2(-9.0, 12.0), Vector2(18.0, 10.0)), Color("3E6B3A"))
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(c + Vector2(side * 9.0 - (5.0 if side < 0 else 0.0), 14.0), Vector2(5.0, 4.0)), Color("8A9097"))
		draw_circle(c + Vector2(side * 15.0, 16.0), 3.2, Color("4A4E53"))
		draw_circle(c + Vector2(side * 15.0, 16.0), 2.0, Color("C9CED3"))
	# Square green face.
	draw_rect(Rect2(c + Vector2(-15.0, -16.0), Vector2(30.0, 30.0)), Color("3E6B3A"))
	draw_rect(Rect2(c + Vector2(-13.0, -15.0), Vector2(26.0, 27.0)), Color("5E8F52"))
	draw_rect(Rect2(c + Vector2(-13.0, -15.0), Vector2(9.0, 27.0)), Color("8DBA7A", 0.55))
	# Flat-top black hair with a jagged fringe.
	draw_rect(Rect2(c + Vector2(-16.0, -24.0), Vector2(32.0, 11.0)), Color("141414"))
	var fringe := PackedVector2Array([c + Vector2(-16.0, -13.0)])
	for k in range(9):
		fringe.append(c + Vector2(-16.0 + 4.0 * float(k), -13.0 + (4.0 if k % 2 == 1 else 0.0)))
	fringe.append(c + Vector2(16.0, -13.0))
	fringe.append(c + Vector2(16.0, -14.0))
	fringe.append(c + Vector2(-16.0, -14.0))
	draw_colored_polygon(fringe, Color("141414"))
	draw_line(c + Vector2(-14.0, -21.0), c + Vector2(10.0, -21.0), Color("3A3A42"), 1.4)
	# Stitched scar across the brow.
	draw_line(c + Vector2(-11.0, -5.0), c + Vector2(11.0, -5.0), Color("1E1A16"), 1.4)
	for k in range(6):
		var x: float = -10.0 + 4.0 * float(k)
		draw_line(c + Vector2(x, -7.0), c + Vector2(x, -3.0), Color("1E1A16"), 1.2)
	# Heavy brow, glowing eyes, grim mouth.
	draw_rect(Rect2(c + Vector2(-12.0, -1.0), Vector2(24.0, 2.6)), Color("2E4A2A"))
	for side in [-1.0, 1.0]:
		var eye: Vector2 = c + Vector2(side * 6.0, 4.0)
		draw_circle(eye, 4.6, Color("FFF2B0", 0.2 + 0.2 * pulse))
		draw_circle(eye, 2.2, Color("FFF2B0"))
	draw_line(c + Vector2(-6.0, 10.5), c + Vector2(6.0, 10.5), Color("1E2A1C"), 2.0)
	# Electricity crackling over the plate.
	var arc_pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t * 8.0)
	for k in range(7):
		arc_pts.append(center + Vector2(-28.0 + 9.0 * float(k), -26.0 + rng.randf_range(-3.0, 3.0)))
	draw_polyline(arc_pts, Color("7FD8FF", 0.35 + 0.35 * pulse), 3.0)
	draw_polyline(arc_pts, Color(1, 1, 1, 0.5 + 0.4 * pulse), 1.0)


## Demon Lord portrait: a crimson demon face, front-on, with great black
## horns sweeping up past the plate, a gold circlet set with a red gem,
## burning yellow slit eyes and fangs, on an obsidian plate licked by flames.
func _draw_demon_badge(center: Vector2) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(t * 2.2)
	var hexagon := PackedVector2Array()
	for index in range(6):
		hexagon.append(center + Vector2.RIGHT.rotated(PI / 6.0 + PI / 3.0 * float(index)) * BADGE_RADIUS)
	draw_colored_polygon(Palette.offset_points(hexagon, Vector2(4.0, 6.0)), Palette.SHADOW_COLOR)
	draw_colored_polygon(hexagon, Color("1A0F0E"))
	var inner := PackedVector2Array()
	for point in hexagon:
		inner.append(center + (point - center) * 0.84)
	draw_colored_polygon(inner, Color("3A1A16"))
	# Ember glow rising from the bottom of the plate.
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-29.0, 17.0), center + Vector2(29.0, 17.0), center + Vector2(17.0, 34.0), center + Vector2(-17.0, 34.0),
	]), Color("7A2316", 0.8))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-30.0, -10.0), center + Vector2(-10.0, -30.0), center + Vector2(0.0, -27.0), center + Vector2(-26.0, -1.0),
	]), Color("4E2620"))
	# Flames licking up behind the head.
	for k in range(4):
		var x: float = [-25.0, -18.0, 18.0, 25.0][k]
		var h: float = 12.0 + 5.0 * sin(t * 6.0 + float(k) * 1.7)
		var base: Vector2 = center + Vector2(x, 30.0)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-6.0, 0.0), base + Vector2(sin(t * 4.0 + float(k)) * 2.0, -h), base + Vector2(6.0, 0.0)]), Color("E2572A", 0.85))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-3.0, 0.0), base + Vector2(0.0, -h * 0.55), base + Vector2(3.0, 0.0)]), Color("FFD23F", 0.9))
	var c: Vector2 = center + Vector2(0.0, 6.0)
	# Great horns sweeping out and up past the plate.
	for side in [-1.0, 1.0]:
		var outer := PackedVector2Array()
		var inner_edge := PackedVector2Array()
		for k in range(10):
			var u: float = float(k) / 9.0
			var spine: Vector2 = c + Vector2(side * (10.0 + 22.0 * u - 8.0 * u * u * u), -10.0 - 30.0 * u * u)
			var half: float = lerpf(7.0, 0.6, u)
			outer.append(spine + Vector2(side * half, half * 0.4))
			inner_edge.insert(0, spine - Vector2(side * half, half * 0.4))
		outer.append_array(inner_edge)
		draw_colored_polygon(Palette.offset_points(outer, Vector2(2.0, 3.0)), Color(0, 0, 0, 0.35))
		draw_colored_polygon(outer, Color("120D0D"))
		var core := PackedVector2Array()
		for k in range(outer.size()):
			core.append(outer[k].lerp(outer[outer.size() - 1 - k], 0.18))
		draw_colored_polygon(core, Color("4A3A36"))
		var ridge := PackedVector2Array()
		for k in range(9):
			var u: float = float(k) / 9.0
			ridge.append(c + Vector2(side * (10.0 + 22.0 * u - 8.0 * u * u * u), -10.0 - 30.0 * u * u) + Vector2(-side * 1.2, -1.0))
		draw_polyline(ridge, Color("8A746C"), 1.6)
		for u in [0.25, 0.5]:
			var ring: Vector2 = c + Vector2(side * (10.0 + 22.0 * u - 8.0 * u * u * u), -10.0 - 30.0 * u * u)
			draw_line(ring + Vector2(-3.5, -1.5), ring + Vector2(3.5, 1.5).rotated(side * 0.6), Color("3A2A27"), 1.4)
	# Head: crimson, broad brow narrowing to a pointed chin.
	var head := PackedVector2Array([
		c + Vector2(-15.0, -12.0), c + Vector2(-8.0, -17.0), c + Vector2(8.0, -17.0), c + Vector2(15.0, -12.0),
		c + Vector2(16.0, 0.0), c + Vector2(11.0, 13.0), c + Vector2(0.0, 21.0), c + Vector2(-11.0, 13.0), c + Vector2(-16.0, 0.0),
	])
	draw_colored_polygon(head, Color("5E1014"))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-13.0, -11.0), c + Vector2(-7.0, -15.0), c + Vector2(7.0, -15.0), c + Vector2(13.0, -11.0),
		c + Vector2(14.0, 0.0), c + Vector2(9.0, 11.0), c + Vector2(0.0, 17.0), c + Vector2(-9.0, 11.0), c + Vector2(-14.0, 0.0),
	]), Color("A82A26"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-12.0, -10.0), c + Vector2(-6.0, -14.0), c + Vector2(-1.0, -13.0), c + Vector2(-10.0, -3.0)]), Color("D9503E"))
	# Cheekbones.
	for side in [-1.0, 1.0]:
		draw_line(c + Vector2(side * 13.0, 3.0), c + Vector2(side * 6.0, 8.0), Color("5E1014"), 1.6)
	# Gold circlet with a red gem.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-15.0, -12.0), c + Vector2(-8.0, -16.0), c + Vector2(8.0, -16.0), c + Vector2(15.0, -12.0),
		c + Vector2(14.0, -9.0), c + Vector2(8.0, -12.5), c + Vector2(-8.0, -12.5), c + Vector2(-14.0, -9.0),
	]), Color("C99A3A"))
	draw_line(c + Vector2(-8.0, -15.0), c + Vector2(8.0, -15.0), Color("F0D27A"), 1.2)
	var gem: Vector2 = c + Vector2(0.0, -15.0)
	draw_circle(gem, 5.5 + 1.5 * pulse, Color("FF2E3A", 0.25))
	draw_colored_polygon(PackedVector2Array([gem + Vector2(0.0, -4.5), gem + Vector2(3.5, 0.0), gem + Vector2(0.0, 4.0), gem + Vector2(-3.5, 0.0)]), Color("FF2E3A"))
	draw_circle(gem + Vector2(-1.0, -1.2), 1.0, Color("FFD0D4"))
	# Angry brows and burning slit eyes.
	for side in [-1.0, 1.0]:
		var eye: Vector2 = c + Vector2(side * 6.5, -3.0)
		# Brow: low at the nose, sweeping up to the temple (a scowl).
		draw_colored_polygon(PackedVector2Array([
			eye + Vector2(-side * 5.5, -1.0), eye + Vector2(side * 5.5, -6.0), eye + Vector2(side * 5.0, -3.5), eye + Vector2(-side * 5.0, 1.2),
		]), Color("1E0E12"))
		draw_circle(eye + Vector2(0.0, 1.5), 5.5, Color("FFD23F", 0.2 + 0.2 * pulse))
		# Almond eye, inner corner low, outer corner raised.
		draw_colored_polygon(PackedVector2Array([
			eye + Vector2(-side * 4.5, 2.0), eye + Vector2(side * 4.5, -1.5), eye + Vector2(side * 2.0, 3.5), eye + Vector2(-side * 2.0, 3.8),
		]), Color("FFD23F"))
		draw_line(eye + Vector2(0.0, -0.2), eye + Vector2(0.0, 3.6), Color("1E0E12"), 1.4)
	# Snarl: dark mouth with two fangs, small goatee.
	draw_colored_polygon(PackedVector2Array([c + Vector2(-7.0, 8.0), c + Vector2(7.0, 8.0), c + Vector2(4.5, 12.0), c + Vector2(-4.5, 12.0)]), Color("1E0E12"))
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(side * 5.5, 8.0), c + Vector2(side * 2.5, 8.0), c + Vector2(side * 4.0, 13.0)]), Color("F4E9D8"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-2.5, 17.0), c + Vector2(2.5, 17.0), c + Vector2(0.0, 25.0)]), Color("1E1514"))


## Hexagonal stone portrait: a sunken face under a brow, purple eyes, crystal crown.
func _draw_stone_badge(center: Vector2) -> void:
	var hexagon := PackedVector2Array()
	for index in range(6):
		hexagon.append(center + Vector2.RIGHT.rotated(PI / 6.0 + PI / 3.0 * float(index)) * BADGE_RADIUS)
	draw_colored_polygon(Palette.offset_points(hexagon, Vector2(4.0, 6.0)), Palette.SHADOW_COLOR)
	draw_colored_polygon(hexagon, Palette.STONE_DARK)
	var inner := PackedVector2Array()
	for point in hexagon:
		inner.append(center + (point - center) * 0.82)
	draw_colored_polygon(inner, Palette.STONE_MID)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-22.0, -6.0), center + Vector2(6.0, -22.0), center + Vector2(26.0, -10.0), center + Vector2(4.0, 2.0),
	]), Palette.STONE_LIGHT)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-26.0, 4.0), center + Vector2(26.0, 4.0), center + Vector2(22.0, 14.0), center + Vector2(-22.0, 14.0),
	]), Palette.STONE_DEEP)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)
	for eye_x in [-10.0, 10.0]:
		var eye: Vector2 = center + Vector2(eye_x, 9.0)
		draw_circle(eye, 6.0, Color(Palette.ENEMY_EYE, 0.25 + 0.2 * pulse))
		draw_circle(eye, 4.0, Palette.ENEMY_EYE)
		draw_circle(eye - Vector2(1.3, 1.3), 1.4, Palette.ENEMY_EYE_GLOW)
	for spec in [[-14.0, 14.0, -2.2], [0.0, 18.0, -1.57], [14.0, 14.0, -0.94]]:
		var base: Vector2 = center + Vector2(spec[0] * 0.9, -22.0)
		var along := Vector2.RIGHT.rotated(spec[2])
		var side := Vector2(-along.y, along.x) * 4.0
		var tip: Vector2 = base + along * spec[1]
		draw_colored_polygon(PackedVector2Array([base + side, tip, base - side]), Palette.ENEMY_EYE_DEEP)
		draw_colored_polygon(PackedVector2Array([base + side, tip, base]), Palette.ENEMY_EYE)


func _spaced(text: String) -> String:
	return " ".join(text.split(""))


var _style: StyleBoxFlat


func _panel_style() -> StyleBoxFlat:
	if _style == null:
		_style = StyleBoxFlat.new()
		_style.bg_color = Color(Palette.UI_PANEL, 0.55)
		_style.set_corner_radius_all(10)
	return _style

