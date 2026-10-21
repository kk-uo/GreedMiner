extends Node

## First Rock Titan defeat cinematic (user pick: finisher B + V1). The moment
## the titan falls: the battle ends (waves stop, other enemies crumble, the
## titan does not split), its rubble stays on the ground, every dwarf runs
## out of the ship and starts mining it, and the camera slowly pulls back
## over the whole Rocky Planet, out into space until the planet hangs in the
## stars - then the GREED MINER title (credit: DESIGNED BY KUOSS) floats in over the slowly turning planet. One click returns to the base
## (banking the ore and recording the planet as cleared); after IDLE_HINT
## seconds a small white hint says so. Seen once (ProgressionStore "story").
## Load with preload(); no class_name on purpose.

const SAVE_SECTION: StringName = &"story"
const SEEN_KEY := "rocky_finale"
const DWARF_COUNT: int = 9
const ZOOM_OUT_TIME: float = 7.0
const SPACE_AT: float = 6.4
const SPACE_FADE: float = 1.4
const TITLE_AT: float = 9.0
const IDLE_HINT: float = 6.0
const ART := preload("res://Scripts/Mining/DwarfMinerArt.gd")
const BASE_SCENE_PATH := "res://Scenes/Base/base_main.tscn"

var battle: Node2D
var at := Vector2.ZERO

var _start_us: int = 0
var _camera: Camera2D
var _zoom_from := Vector2.ONE
var _pos_from := Vector2.ZERO
var _zoom_to := Vector2.ONE
var _pos_to := Vector2.ZERO
var _rubble: Node2D
var _crew: Node2D
var _space: Control
var _bars: Array[ColorRect] = []
var _title: Label
var _subtitle: Label
var _hint: Label
var _title_shown_at: float = -1.0
var _leaving: bool = false


static func has_been_seen() -> bool:
	return bool(ProgressionStore.get_section(SAVE_SECTION).get(SEEN_KEY, false))


## True when killing this titan should play the finale instead of splitting.
static func should_play(titan: Node) -> bool:
	if has_been_seen() or not titan.is_inside_tree():
		return false
	var scene := titan.get_tree().current_scene
	return scene != null and scene.has_method("play_rocky_finale") and not bool(scene.get("_battle_ended"))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_us = Time.get_ticks_usec()
	var ship := battle.get("ship") as Ship
	_camera = ship.world_camera
	_camera.position_smoothing_enabled = false
	_zoom_from = _camera.zoom
	_pos_from = _camera.global_position
	var field := battle.get("battlefield") as Battlefield
	var view := get_viewport().get_visible_rect().size
	var fit := maxf(view.x / field.world_size.x, view.y / field.world_size.y)
	_zoom_to = Vector2.ONE * fit
	_pos_to = field.to_global(field.world_size * 0.5)
	# Rubble that stays, and the dwarves who come out to mine it.
	_rubble = TitanRubble.new()
	_rubble.call("build", 11)
	field.get_interactables_root().add_child(_rubble)
	_rubble.global_position = at
	_crew = FinaleCrew.new()
	_crew.set("from", ship.global_position)
	_crew.set("rubble", _rubble)
	battle.add_child(_crew)
	_build_overlay()


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 58
	add_child(layer)
	_space = SpaceView.new()
	_space.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_space.modulate.a = 0.0
	_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_space)
	for k in range(2):
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(bar)
		_bars.append(bar)
	var font: Font = load("res://Assets/Fonts/ChakraPetch-SemiBold.ttf")
	_title = _make_label("GREED MINER", 132, Color("FFD23F"), 22, font)
	_title.add_theme_color_override("font_outline_color", Color("3B2410"))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_title.add_theme_constant_override("shadow_offset_x", 6)
	_title.add_theme_constant_override("shadow_offset_y", 9)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	layer.add_child(_title)
	_subtitle = _make_label("DESIGNED BY KUOSS", 28, Color("F2EAD9"), 8, null)
	_subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	layer.add_child(_subtitle)
	_hint = _make_label(tr("CLICK ANYWHERE TO RETURN TO BASE"), 18, Color(1, 1, 1), 0, null)
	layer.add_child(_hint)
	for label in [_title, _subtitle, _hint]:
		label.modulate.a = 0.0


func _make_label(text: String, size: int, color: Color, outline: int, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_constant_override("outline_size", outline)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _elapsed() -> float:
	return float(Time.get_ticks_usec() - _start_us) / 1000000.0


func _process(_delta: float) -> void:
	var t := _elapsed()
	var view := get_viewport().get_visible_rect().size
	# Camera: a slow pull-back over the whole planet surface.
	var k := smoothstep(0.0, ZOOM_OUT_TIME, t)
	var eased := 1.0 - pow(1.0 - k, 2.0)
	_camera.zoom = Vector2.ONE * exp(lerpf(log(_zoom_from.x), log(_zoom_to.x), eased))
	_camera.global_position = _pos_from.lerp(_pos_to, eased)
	# Letterbox bars stay for the whole cinematic.
	var bar_h := view.y * 0.12 * smoothstep(0.0, 0.3, t)
	_bars[0].position = Vector2.ZERO
	_bars[0].size = Vector2(view.x, bar_h)
	_bars[1].position = Vector2(0, view.y - bar_h)
	_bars[1].size = Vector2(view.x, bar_h)
	# Out into space: the planet shrinks to hang in the stars.
	var space := smoothstep(SPACE_AT, SPACE_AT + SPACE_FADE, t)
	_space.modulate.a = space
	_space.set("shrink", smoothstep(SPACE_AT, SPACE_AT + 3.2, t))
	_space.set("time", t)
	_space.queue_redraw()
	# Title floats up and in.
	var title_k := smoothstep(TITLE_AT, TITLE_AT + 1.4, t)
	_title.modulate.a = title_k
	_title.position = Vector2(0, view.y * 0.1 + 24.0 * (1.0 - title_k))
	_title.size = Vector2(view.x, 170)
	var sub_k := smoothstep(TITLE_AT + 0.8, TITLE_AT + 2.0, t)
	_subtitle.modulate.a = sub_k
	_subtitle.position = Vector2(0, view.y * 0.1 + 162.0)
	_subtitle.size = Vector2(view.x, 40)
	if title_k > 0.0 and _title_shown_at < 0.0:
		_title_shown_at = t
	# Idle hint at the bottom (inside the lower bar).
	if _title_shown_at >= 0.0 and t - _title_shown_at >= IDLE_HINT:
		_hint.modulate.a = 0.55 + 0.35 * sin(t * 3.0)
	_hint.position = Vector2(0, view.y - view.y * 0.12 * 0.5 - 14.0)
	_hint.size = Vector2(view.x, 28)


func _input(event: InputEvent) -> void:
	if _leaving or _elapsed() < TITLE_AT:
		return
	var pressed := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventKey and (event as InputEventKey).pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	return_to_base()


## Banks the mission, records the planet as cleared, saves the finale as seen
## and goes back to the base (the ship lands there).
func return_to_base() -> void:
	if _leaving:
		return
	_leaving = true
	var data := ProgressionStore.get_section(SAVE_SECTION)
	data[SEEN_KEY] = true
	ProgressionStore.set_section(SAVE_SECTION, data)
	preload("res://Scripts/Base/BaseHomecoming.gd").pending = {"kind": &"haul", "ore": ResourceManager.bank_current_mission_ore()}
	WeaponUnlockManager.record_planet_completion(&"rocky_planet")
	ShipLaunchController.landing_pending_at_base = true
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(BASE_SCENE_PATH)


# ==========================================
# Pieces
# ==========================================

## The titan's rubble: big grey boulders (some with gold), purple heart
## shards and pebbles in a dusty crater. Stays for the rest of the battle.
class TitanRubble extends Node2D:
	var rocks: Array = []
	var _fade: float = 0.0

	func build(seed_value: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in range(48):
			var big := i < 14
			var a := rng.randf() * TAU
			var d := rng.randf_range(10.0, 130.0) if big else rng.randf_range(30.0, 270.0)
			var r := rng.randf_range(26.0, 46.0) if big else rng.randf_range(8.0, 18.0)
			var pts := PackedVector2Array()
			var sides := rng.randi_range(5, 7)
			for k in range(sides):
				var aa := TAU * float(k) / float(sides) + rng.randf() * 0.4
				pts.append(Vector2(cos(aa), sin(aa)) * r * rng.randf_range(0.75, 1.1))
			rocks.append({"at": Vector2(cos(a), sin(a) * 0.8) * d, "pts": pts, "r": r, "crystal": rng.randf() < 0.15, "gold": big and rng.randf() < 0.6})

	## Spots around the big boulders where a dwarf can stand and dig.
	func dig_spots(count: int) -> Array:
		var spots := []
		for i in range(count):
			var rock: Dictionary = rocks[i % 14]
			var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(count) + 0.3)
			spots.append([global_position + rock["at"] + dir * (float(rock["r"]) + 14.0), (-dir).angle()])
		return spots

	func _process(delta: float) -> void:
		if _fade < 1.0:
			_fade = minf(_fade + delta * 1.5, 1.0)
			modulate.a = _fade
			queue_redraw()

	func _draw() -> void:
		var b := MeshBatch2D.new()
		b.draw_circle(Vector2(10, 14), 230.0, Color(0, 0, 0, 0.12))
		b.draw_circle(Vector2.ZERO, 150.0, Color("6A4D3A", 0.5))
		for rock in rocks:
			var at: Vector2 = rock["at"]
			var pts: PackedVector2Array = rock["pts"]
			var r: float = rock["r"]
			var shadow := PackedVector2Array()
			var body := PackedVector2Array()
			var lit := PackedVector2Array()
			for p in pts:
				shadow.append(at + p + Vector2(6, 8))
				body.append(at + p)
				lit.append(at + p * 0.6 + Vector2(-0.25, -0.25) * r)
			b.draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
			if rock["crystal"]:
				b.draw_colored_polygon(body, Color("5E3FA8"))
				b.draw_colored_polygon(lit, Color("B49CFF"))
			else:
				b.draw_colored_polygon(body, Color("5E5650"))
				b.draw_colored_polygon(lit, Color("8E857C"))
				if rock["gold"]:
					b.draw_colored_polygon(PackedVector2Array([at + Vector2(-4, -10), at + Vector2(4, -4), at + Vector2(-2, 6)]), Palette.GOLD)
		b.flush_to(self)


## Dwarves streaming out of the ship to dig in the rubble.
class FinaleCrew extends Node2D:
	var from := Vector2.ZERO
	var rubble: Node2D
	var _dwarves: Array = []
	var _time: float = 0.0

	func _ready() -> void:
		z_index = 2
		var spots: Array = rubble.call("dig_spots", 9)
		for i in range(spots.size()):
			_dwarves.append({"pos": from, "to": spots[i][0], "face": spots[i][1], "delay": 0.4 + 0.22 * float(i), "phase": float(i) * 0.37})

	func _process(delta: float) -> void:
		_time += delta
		for d in _dwarves:
			if _time < float(d["delay"]):
				continue
			var pos: Vector2 = d["pos"]
			var to: Vector2 = d["to"]
			d["pos"] = pos.move_toward(to, 210.0 * delta)
		queue_redraw()

	func _draw() -> void:
		var b := MeshBatch2D.new()
		for d in _dwarves:
			if _time < float(d["delay"]):
				continue
			var pos: Vector2 = d["pos"]
			var to: Vector2 = d["to"]
			var walking := pos.distance_to(to) > 1.0
			var facing: float = (to - pos).angle() if walking else float(d["face"])
			var local := to_local(pos)
			ART.draw(b, {"at": local, "time": _time + float(d["phase"]), "facing": facing, "walking": walking, "working": not walking})
			if not walking:
				ART.draw_chips(b, local + Vector2.RIGHT.rotated(facing) * 20.0, _time + float(d["phase"]), -Vector2.RIGHT.rotated(facing), Color("8E857C"))
		b.flush_to(self)


## Space: stars and the Rocky Planet, shrinking from filling the screen to
## hanging in the sky, with a glint where the ship is.
class SpaceView extends Control:
	const SPIN_SPEED: float = 0.07
	## [longitude, latitude, size (of radius), 0 = light patch / 1 = crater]
	const FEATURES := [
		[-0.3, 0.35, 0.5, 0], [2.4, -0.2, 0.45, 0], [4.3, 0.5, 0.35, 0],
		[-0.6, -0.2, 0.15, 1], [0.5, 0.4, 0.13, 1], [0.25, -0.5, 0.1, 1],
		[-0.15, 0.65, 0.07, 1], [1.4, 0.1, 0.16, 1], [2.1, 0.55, 0.09, 1],
		[2.9, -0.45, 0.12, 1], [3.6, 0.2, 0.14, 1], [4.5, -0.3, 0.1, 1],
		[5.2, 0.45, 0.08, 1], [5.6, -0.05, 0.13, 1],
	]
	var shrink: float = 0.0
	var time: float = 0.0

	## Fills a squashed circle at `at`, clipped to the planet's disc (centre
	## c, radius r) so features never poke past the limb.
	func _fill_on_disc(at: Vector2, radius: float, squash: Vector2, c: Vector2, r: float, color: Color) -> void:
		var pts := PackedVector2Array()
		var disc := PackedVector2Array()
		for k in range(28):
			var a := TAU * float(k) / 28.0
			pts.append(at + Vector2(cos(a), sin(a)) * radius * squash)
		for k in range(64):
			var a := TAU * float(k) / 64.0
			disc.append(c + Vector2(cos(a), sin(a)) * r * 0.99)
		for clipped in Geometry2D.intersect_polygons(pts, disc):
			if clipped.size() >= 3 and not Geometry2D.triangulate_polygon(clipped).is_empty():
				draw_colored_polygon(clipped, color)

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color("0B0B14"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in range(200):
			var tw := 0.6 + 0.4 * sin(time * 2.0 + float(i))
			draw_circle(Vector2(rng.randf() * s.x, rng.randf() * s.y), rng.randf_range(0.6, 1.8), Color(1, 1, 1, rng.randf_range(0.3, 0.9) * tw))
		var r := lerpf(s.x * 0.9, s.y * 0.29, 1.0 - pow(1.0 - shrink, 2.0))
		var c := Vector2(s.x * 0.5, lerpf(s.y * 0.5 + r * 0.2, s.y * 0.75, shrink))
		draw_circle(c, r * 1.06, Color("8A6A4D", 0.12))
		draw_circle(c, r, Color("8A6A4D"))
		# Slow spin: surface features ride across the globe (longitude, latitude,
		# size, colour), foreshortened near the limb; the light stays fixed.
		var spin := time * SPIN_SPEED
		for feature in FEATURES:
			var lon: float = float(feature[0]) - spin
			var lat: float = feature[1]
			var depth := cos(lat) * cos(lon)
			if depth <= 0.06:
				continue
			var p := c + Vector2(cos(lat) * sin(lon), -sin(lat)) * r
			# Shrink and fade towards the limb so nothing pokes past the edge.
			var edge := smoothstep(0.06, 0.45, depth)
			var fr: float = float(feature[2]) * r * lerpf(0.4, 1.0, edge)
			var squash := Vector2(depth, maxf(cos(lat), 0.2))
			if feature[3] == 0:
				_fill_on_disc(p, fr, squash, c, r, Color("967558", edge))
			else:
				_fill_on_disc(p, fr, squash, c, r, Color("6A4D3A", edge))
				_fill_on_disc(p + Vector2(0.15, 0.15) * fr * squash, fr * 0.72, squash, c, r, Color("7D5F45", edge))
		var shade := PackedVector2Array()
		for k in range(40):
			var a := -PI * 0.5 + PI * float(k) / 39.0
			shade.append(c + Vector2(cos(a), sin(a)) * r)
		for k in range(40):
			var a := PI * 0.5 - PI * float(k) / 39.0
			shade.append(c + Vector2(cos(a) * r * 0.35, sin(a) * r))
		draw_colored_polygon(shade, Color(0, 0, 0, 0.35))
		# The ship's landing site glints while it faces us.
		var site_lon := 0.35 - spin
		var site_lat := 0.15
		var site_depth := cos(site_lat) * cos(site_lon)
		if site_depth > 0.1:
			var glint := c + Vector2(cos(site_lat) * sin(site_lon), -sin(site_lat)) * r
			var pulse := (0.7 + 0.3 * sin(time * 4.0)) * minf(site_depth * 2.0, 1.0)
			draw_circle(glint, 10.0 * pulse, Color(1, 0.85, 0.4, 0.35 * pulse))
			draw_circle(glint, 3.0 * pulse, Color(1, 0.95, 0.7, pulse))
