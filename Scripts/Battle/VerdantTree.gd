extends Area2D

## A destructible tree on the Verdant Planet battlefield.
##
## Turrets never aim at trees (they are not in the "enemies" group); a tree
## only takes damage when a shot happens to hit it or it stands in a beam's
## or blast's path (weapons check the "destructible_props" group). Small
## clumps have SMALL_HP and pay SMALL_ORE; the big landmark trees have
## LARGE_HP and pay LARGE_ORE. At 0 HP the tree topples away from the ship,
## pays its ore (with a "+N" popup) and leaves a stump.
##
## Battlefield places these (jungle theme, interactive_verdant_trees) and
## fills in the drawing data with configure_small() / configure_large().
## Load with preload(); no class_name on purpose.

signal felled(world_position: Vector2, ore: float)

const SMALL_HP: float = 20.0
const LARGE_HP: float = 100.0
const SMALL_ORE: float = 1.0
const LARGE_ORE: float = 5.0
const GROUP: StringName = &"destructible_props"

const FALL_TIME: float = 0.6
const LIE_TIME: float = 3.0
const FADE_TIME: float = 1.0
const HIT_TIME: float = 0.25
const TRUNK := Color("5A3E28")
const TRUNK_LIGHT := Color("7A5638")
const STUMP_RING := Color("B08A5A")

var large: bool = false
var max_hp: float = SMALL_HP
var hp: float = SMALL_HP
var ore: float = SMALL_ORE
var _colors: Dictionary = {}
## small: [[offset, radius, turn], ...]; large: [[offset, radius], ...] + turn.
var _blobs: Array = []
var _turn: float = 0.0
var _radius: float = 12.0
var _fall_dir := Vector2.RIGHT
var _fall_age: float = -1.0
var _hit_age: float = 1.0
var _hit_dir := Vector2.RIGHT
var _leaves: Array = []
var _rng := RandomNumberGenerator.new()
## An untouched tree draws one cached mesh (hundreds of trees per map);
## _pen is the canvas the canopy is drawn on (self, or a MeshBatch2D).
var _mesh: ArrayMesh
var _pen: Object = self


func configure_small(blobs: Array, radius: float, colors: Dictionary) -> void:
	large = false
	_blobs = blobs
	_radius = radius
	_colors = colors
	max_hp = SMALL_HP
	ore = SMALL_ORE
	hp = max_hp


## A big foliage clump that counts as a large tree (keeps its clump look).
func mark_large() -> void:
	max_hp = LARGE_HP
	ore = LARGE_ORE
	hp = max_hp


func configure_large(lobes: Array, turn: float, colors: Dictionary) -> void:
	large = true
	_blobs = lobes
	_turn = turn
	_radius = 46.0
	_colors = colors
	max_hp = LARGE_HP
	ore = LARGE_ORE
	hp = max_hp


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius * (0.8 if large else 0.75)
	shape.shape = circle
	add_child(shape)
	# Idle trees do no per-frame work; hits and falling switch it on.
	set_process(false)


func is_standing() -> bool:
	return _fall_age < 0.0


## Same signature as BasicEnemy.take_damage so weapons can treat it alike.
func take_damage(amount: float, _ignore_damage_reduction: bool = false, _count_for_artifact: bool = true, _source_weapon: Node = null) -> void:
	if amount <= 0.0 or not is_standing():
		return
	hp = maxf(hp - amount, 0.0)
	_hit_age = 0.0
	_hit_dir = _away_from_ship()
	for k in range(3 if not large else 5):
		var dir := _hit_dir.rotated(_rng.randf_range(-1.2, 1.2))
		_leaves.append({"p": dir * _radius * 0.6, "v": dir * _rng.randf_range(40.0, 110.0), "age": 0.0, "rot": _rng.randf() * TAU})
	if hp <= 0.0:
		_fell()
	set_process(true)
	queue_redraw()


func _fell() -> void:
	_fall_age = 0.0
	_fall_dir = _away_from_ship().rotated(_rng.randf_range(-0.5, 0.5))
	set_deferred("monitorable", false)
	collision_layer = 0
	remove_from_group(GROUP)
	ResourceManager.add_mission_ore(ore)
	RewardPopup.spawn(get_parent(), global_position, ore)
	felled.emit(global_position, ore)


## Shots come from the ship, so trees fall away from it.
func _away_from_ship() -> Vector2:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var ship = scene.get("ship") if scene != null else null
	if ship is Ship and is_instance_valid(ship):
		var away: Vector2 = global_position - (ship as Ship).to_global(Ship.SHIP_SIZE * 0.5)
		if away.length_squared() > 1.0:
			return away.normalized()
	return Vector2.RIGHT.rotated(_rng.randf() * TAU)


func _process(delta: float) -> void:
	var busy := false
	if _hit_age < HIT_TIME:
		_hit_age += delta
		busy = true
	for leaf in _leaves.duplicate():
		leaf["age"] += delta
		leaf["p"] += leaf["v"] * delta
		leaf["v"] *= 0.92
		if leaf["age"] > 0.7:
			_leaves.erase(leaf)
	busy = busy or not _leaves.is_empty()
	if _fall_age >= 0.0 and _fall_age < FALL_TIME + LIE_TIME + FADE_TIME:
		var before := _fall_age
		_fall_age += delta
		if before < FALL_TIME and _fall_age >= FALL_TIME:
			_on_impact()
		busy = true
	queue_redraw()
	if not busy:
		set_process(false)


func _on_impact() -> void:
	# Leaves and dust burst where the crown hits the ground.
	var crown := _fall_dir * _trunk_length()
	for k in range(10 if large else 6):
		var dir := Vector2.RIGHT.rotated(_rng.randf() * TAU)
		_leaves.append({"p": crown + dir * _radius * 0.4, "v": dir * _rng.randf_range(50.0, 140.0), "age": 0.0, "rot": _rng.randf() * TAU})


func _trunk_length() -> float:
	return _radius * (1.7 if large else 1.5)


func _draw() -> void:
	if is_standing() and _hit_age >= HIT_TIME and hp >= max_hp and _leaves.is_empty():
		if _mesh == null:
			var batch := MeshBatch2D.new()
			_pen = batch
			_draw_canopy(Vector2.ZERO, Vector2.ONE, 1.0, true)
			_pen = self
			_mesh = batch.build()
		draw_mesh(_mesh, null)
		return
	if is_standing():
		var shake := Vector2.ZERO
		if _hit_age < HIT_TIME:
			var k := 1.0 - _hit_age / HIT_TIME
			shake = _hit_dir * sin(_hit_age * 70.0) * (3.0 if not large else 2.0) * k
		_draw_canopy(shake, Vector2.ONE, 1.0, true)
		if hp < max_hp:
			_draw_hp_bar()
	else:
		_draw_fallen()
	_draw_leaves()


## The standing crown (same look as the baked foliage / big tree).
func _draw_canopy(offset: Vector2, squash: Vector2, alpha: float, shadow: bool) -> void:
	var xf := Transform2D(_fall_dir.angle(), squash, 0.0, offset) * Transform2D(-_fall_dir.angle(), Vector2.ZERO)
	var rock := Color(_colors.get("rock", Color("2F4A22")), alpha)
	var mid := Color(_colors.get("canopy_mid", Color("4F7339")), alpha)
	var light := Color(_colors.get("rock_light", Color("6E9A47")), alpha)
	var shade := Color(Palette.SHADOW_COLOR, Palette.SHADOW_COLOR.a * alpha)
	if large:
		var sh := Vector2(10.0, 14.0)
		if shadow:
			_pen.draw_colored_polygon(xf * Palette.offset_points(Palette.regular_polygon(12, 34.0, _turn), sh), shade)
			for lobe in _blobs:
				_pen.draw_colored_polygon(xf * Palette.offset_points(Palette.regular_polygon(8, lobe[1], _turn), lobe[0] + sh), shade)
		_pen.draw_colored_polygon(xf * Palette.regular_polygon(12, 36.0, _turn), rock)
		for lobe in _blobs:
			_pen.draw_colored_polygon(xf * Palette.offset_points(Palette.regular_polygon(8, lobe[1], _turn), lobe[0]), rock)
		for lobe in _blobs:
			_pen.draw_colored_polygon(xf * Palette.offset_points(Palette.regular_polygon(8, lobe[1] * 0.74, _turn), lobe[0] * 0.92 + Vector2(-2.0, -3.0)), mid)
		_pen.draw_colored_polygon(xf * Palette.offset_points(Palette.regular_polygon(10, 22.0, _turn), Vector2(-3.0, -4.0)), mid)
		for lobe in _blobs:
			var lobe_offset: Vector2 = lobe[0]
			if lobe_offset.x + lobe_offset.y < 8.0:
				_pen.draw_colored_polygon(xf * Palette.offset_points(Palette.regular_polygon(6, lobe[1] * 0.4, _turn), lobe_offset * 0.85 + Vector2(-6.0, -7.0)), light)
		_pen.draw_colored_polygon(xf * Palette.offset_points(Palette.regular_polygon(7, 12.0, _turn), Vector2(-9.0, -11.0)), light)
		return
	if shadow:
		var sh := Palette.SHADOW_OFFSET * (0.8 + _radius / 40.0)
		for blob in _blobs:
			_pen.draw_colored_polygon(xf * Palette.offset_points(Palette.regular_polygon(8, blob[1], blob[2]), blob[0] + sh), shade)
	for blob in _blobs:
		_pen.draw_colored_polygon(xf * Palette.offset_points(Palette.regular_polygon(8, blob[1], blob[2]), blob[0]), rock)
	for blob in _blobs:
		_pen.draw_colored_polygon(xf * Palette.offset_points(Palette.regular_polygon(8, blob[1] * 0.78, blob[2]), blob[0] + Vector2(-1.5, -2.0)), mid)
	for blob in _blobs:
		var r: float = blob[1]
		_pen.draw_colored_polygon(xf * Palette.offset_points(Palette.regular_polygon(6, r * 0.42, blob[2]), blob[0] + Vector2(-r * 0.3, -r * 0.32)), light)


## Toppling (seen from above): the trunk swings out along the fall direction
## while the crown slides to its tip and flattens; then the tree lies there,
## fades, and a stump stays behind.
func _draw_fallen() -> void:
	var t := clampf(_fall_age / FALL_TIME, 0.0, 1.0)
	var ease_t := t * t
	var fade := 1.0 - clampf((_fall_age - FALL_TIME - LIE_TIME) / FADE_TIME, 0.0, 1.0)
	var length := _trunk_length() * ease_t
	var across := Vector2(-_fall_dir.y, _fall_dir.x)
	var width := _radius * (0.32 if large else 0.26)
	# Stump (stays after the fade).
	draw_circle(Vector2(2.0, 3.0), width * 1.1, Palette.SHADOW_COLOR)
	draw_circle(Vector2.ZERO, width * 1.1, TRUNK)
	draw_circle(Vector2.ZERO, width * 0.75, STUMP_RING)
	draw_arc(Vector2.ZERO, width * 0.45, 0.0, TAU, 12, TRUNK_LIGHT, 1.2)
	if fade <= 0.0:
		return
	# Log.
	if length > 1.0:
		var log := PackedVector2Array([across * width, across * width + _fall_dir * length, -across * width + _fall_dir * length, -across * width])
		draw_colored_polygon(Palette.offset_points(log, Vector2(3.0, 4.0) * ease_t), Color(Palette.SHADOW_COLOR, Palette.SHADOW_COLOR.a * fade))
		draw_colored_polygon(log, Color(TRUNK, fade))
		draw_line(across * width * 0.4, across * width * 0.4 + _fall_dir * length, Color(TRUNK_LIGHT, fade), width * 0.4)
	# Crown sliding to the tip, flattening as it lands.
	var squash := Vector2(lerpf(1.0, 0.8, ease_t), lerpf(1.0, 1.08, ease_t))
	_draw_canopy(_fall_dir * _trunk_length() * ease_t, squash, fade, t < 1.0)


func _draw_hp_bar() -> void:
	var w := _radius * (1.2 if large else 1.4)
	var at := Vector2(-w * 0.5, -_radius - 10.0)
	draw_rect(Rect2(at, Vector2(w, 4.0)), Color(Palette.UI_PANEL, 0.8))
	draw_rect(Rect2(at, Vector2(w * hp / max_hp, 4.0)), Color("8CCB45"))


func _draw_leaves() -> void:
	var leaf_color: Color = _colors.get("canopy_mid", Color("4F7339"))
	for leaf in _leaves:
		var a := 1.0 - float(leaf["age"]) / 0.7
		var p: Vector2 = leaf["p"]
		var d := Vector2.RIGHT.rotated(float(leaf["rot"]) + float(leaf["age"]) * 9.0) * 3.0
		draw_colored_polygon(PackedVector2Array([p - d, p + Vector2(-d.y, d.x) * 0.5, p + d, p - Vector2(-d.y, d.x) * 0.5]), Color(leaf_color.lightened(0.15), a))
