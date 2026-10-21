extends Node2D

## Giant Frank's resurrection cinematic (presentation only).
## When his health first reaches zero the whole screen drops to black so
## only the fallen Frankenstein is visible (HUD and weather hidden too). On
## GiantFrank.lightning_struck a huge forked bolt crashes down from the top
## of the screen onto him with a white flash; on resurrection_completed he
## stands up crackling, and a moment later the light slowly returns.
## GiantFrank adds this when first_death_started fires.
## Load with preload(); no class_name on purpose.

const DARK_IN: float = 0.3
const HOLD_AFTER_REVIVE: float = 0.5
const DARK_OUT: float = 0.8
const STRIKE_TIME: float = 0.75
## Safety: never keep the screen black longer than this.
const MAX_TIME: float = 7.0
const ARC := Color("7FD8FF")
const ARC_GLOW := Color("3FA8FF")

var frank: Node2D

var _age: float = 0.0
var _dark: float = 0.0
var _strike_age: float = -1.0
var _revived_age: float = -1.0
var _bolt: Node2D
var _restore: Dictionary = {}
var _hidden: Array = []
var _rng := RandomNumberGenerator.new()


## Starts the cinematic for `boss` (added under `parent`).
static func play(parent: Node, boss: Node2D) -> Node2D:
	var fx: Node2D = load("res://Scripts/VFX/FrankResurrectionFx.gd").new()
	fx.frank = boss
	parent.add_child(fx)
	return fx


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4000
	_rng.randomize()
	_bolt = Node2D.new()
	_bolt.z_as_relative = false
	_bolt.z_index = 4002
	_bolt.draw.connect(_draw_bolt)
	add_child(_bolt)
	if is_instance_valid(frank):
		# Frank alone is drawn above the black.
		_restore = {"z_index": frank.z_index, "z_as_relative": frank.z_as_relative}
		frank.z_as_relative = false
		frank.z_index = 4001
		if frank.has_signal("lightning_struck"):
			frank.connect("lightning_struck", func(_at: Vector2) -> void: _strike_age = 0.0)
		if frank.has_signal("resurrection_completed"):
			frank.connect("resurrection_completed", func() -> void: _revived_age = 0.0)
	# Hide the HUD and the screen-space weather while it plays.
	var scene := get_tree().current_scene
	if scene != null:
		for path in ["BattleUI", "WeatherManager/GraveyardWeather"]:
			var node := scene.get_node_or_null(path)
			if node is CanvasLayer and (node as CanvasLayer).visible:
				(node as CanvasLayer).visible = false
				_hidden.append(node)


func _process(delta: float) -> void:
	_age += delta
	if _strike_age >= 0.0:
		_strike_age += delta
	if _revived_age >= 0.0:
		_revived_age += delta
	var target := 1.0
	if _revived_age >= HOLD_AFTER_REVIVE or _age >= MAX_TIME or not is_instance_valid(frank):
		target = 0.0
	var speed := 1.0 / (DARK_IN if target > _dark else DARK_OUT)
	_dark = move_toward(_dark, target, delta * speed)
	if target == 0.0 and _dark <= 0.0:
		_finish()
		return
	queue_redraw()
	_bolt.queue_redraw()


func _finish() -> void:
	if is_instance_valid(frank) and not _restore.is_empty():
		frank.z_as_relative = _restore["z_as_relative"]
		frank.z_index = _restore["z_index"]
	for node in _hidden:
		if is_instance_valid(node):
			(node as CanvasLayer).visible = true
	_hidden.clear()
	queue_free()


func _exit_tree() -> void:
	# Never leave the HUD hidden if the battle ends mid-cinematic.
	for node in _hidden:
		if is_instance_valid(node):
			(node as CanvasLayer).visible = true


func _view_rect() -> Rect2:
	var xf := get_viewport().get_canvas_transform()
	return (xf.affine_inverse() * get_viewport().get_visible_rect()).grow(80.0)


## The black curtain over everything except Frank.
func _draw() -> void:
	if _dark <= 0.0:
		return
	draw_rect(_view_rect(), Color(0, 0, 0, _dark))


## The resurrection bolt: a huge forked bolt from the top of the screen
## onto Frank, flickering, with a screen flash and an impact burst.
func _draw_bolt() -> void:
	if _strike_age < 0.0 or _strike_age > STRIKE_TIME or not is_instance_valid(frank):
		return
	var k := _strike_age / STRIKE_TIME
	var view := _view_rect()
	var target := frank.global_position
	# Flicker: three bright pulses that fade out.
	var flicker := 1.0 - k
	if fmod(_strike_age, 0.12) > 0.07:
		flicker *= 0.45
	# Screen flash right at the strike.
	var flash := 1.0 - clampf(_strike_age / 0.22, 0.0, 1.0)
	if flash > 0.0:
		_bolt.draw_rect(view, Color(0.9, 0.95, 1.0, 0.8 * flash))
	var seed_value := int(_strike_age / 0.12)
	var start := Vector2(target.x + 60.0 * sin(float(seed_value) * 1.7), view.position.y)
	var main := _bolt_path(start, target, 16, 48.0, seed_value)
	_stroke(main, flicker, 1.0)
	# Branches forking off the main channel.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	for index in range(5):
		var from: Vector2 = main[rng.randi_range(3, main.size() - 4)]
		var dir := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(0.3, 1.0)).normalized()
		var to := from + dir * rng.randf_range(90.0, 200.0)
		_stroke(_bolt_path(from, to, 6, 22.0, seed_value * 13 + index), flicker * 0.7, 0.45)
	# Impact: a glowing burst on Frank.
	var burst := 160.0 * (0.6 + 0.4 * (1.0 - k))
	_bolt.draw_circle(target, burst, Color(ARC_GLOW, 0.22 * flicker))
	_bolt.draw_circle(target, burst * 0.55, Color(ARC, 0.35 * flicker))
	_bolt.draw_circle(target, burst * 0.25, Color(1, 1, 1, 0.6 * flicker))
	for index in range(10):
		var a := TAU * float(index) / 10.0 + float(seed_value)
		_bolt.draw_line(target + Vector2.RIGHT.rotated(a) * 30.0, target + Vector2.RIGHT.rotated(a) * burst * 1.1, Color(ARC, 0.7 * flicker), 3.0)


func _bolt_path(from: Vector2, to: Vector2, segments: int, jag: float, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var normal := (to - from).orthogonal().normalized()
	var points := PackedVector2Array([from])
	for index in range(1, segments):
		var u := float(index) / float(segments)
		points.append(from.lerp(to, u) + normal * rng.randf_range(-jag, jag) * (1.0 - u * 0.6))
	points.append(to)
	return points


func _stroke(points: PackedVector2Array, alpha: float, width_scale: float) -> void:
	_bolt.draw_polyline(points, Color(ARC_GLOW, 0.25 * alpha), 70.0 * width_scale)
	_bolt.draw_polyline(points, Color(ARC, 0.7 * alpha), 26.0 * width_scale)
	_bolt.draw_polyline(points, Color(1, 1, 1, alpha), 9.0 * width_scale)
