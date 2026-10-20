class_name RewardPopup
extends Node2D

## Floating "+N" ore pickup shown where a rewarding enemy dies (style A).
## Pops in, rises, then fades; a few gold sparks burst out. Frees itself.

const LIFE: float = 1.8
const RISE: float = 70.0

var amount: float = 0.0

var _age: float = 0.0
var _label: Label
var _sparks: Array[Dictionary] = []


## Adds a popup to parent at a global position. Safe during physics callbacks.
static func spawn(parent: Node, world_position: Vector2, ore_amount: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var popup := RewardPopup.new()
	popup.amount = ore_amount
	popup.z_as_relative = false
	popup.z_index = 40
	parent.call_deferred("add_child", popup)
	popup.set_deferred("global_position", world_position)


func _ready() -> void:
	_label = Label.new()
	_label.text = "+%d" % int(round(amount))
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Palette.GOLD)
	_label.add_theme_color_override("font_outline_color", Palette.UI_PANEL)
	_label.add_theme_constant_override("outline_size", 10)
	_label.position = Vector2(8.0, -24.0)
	add_child(_label)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in range(10):
		var angle: float = rng.randf_range(0.0, TAU)
		_sparks.append({
			"vel": Vector2.RIGHT.rotated(angle) * rng.randf_range(90.0, 200.0),
			"pos": Vector2.ZERO,
			"size": rng.randf_range(4.0, 7.0),
			"rot": angle,
		})


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	var drag: float = exp(-4.0 * delta)
	for spark in _sparks:
		spark["pos"] += spark["vel"] * delta
		spark["vel"] *= drag
	queue_redraw()


func _draw() -> void:
	var t: float = _age / LIFE
	var rise: float = RISE * (1.0 - pow(1.0 - t, 3.0))
	var pop: float = 1.0 + 0.35 * maxf(0.0, 1.0 - _age / 0.18)
	var alpha: float = clampf((LIFE - _age) / 0.5, 0.0, 1.0)
	_label.position = Vector2(8.0, -24.0 - rise)
	_label.scale = Vector2.ONE * pop
	_label.modulate.a = alpha

	# Gold ore gem next to the number.
	var gem_center := Vector2(-10.0, -6.0 - rise)
	var gem := PackedVector2Array([
		gem_center + Vector2(0.0, -14.0) * pop, gem_center + Vector2(10.0, 0.0) * pop,
		gem_center + Vector2(0.0, 14.0) * pop, gem_center + Vector2(-10.0, 0.0) * pop,
	])
	draw_colored_polygon(Palette.offset_points(gem, Vector2(3.0, 4.0)), Color(Palette.UI_PANEL, 0.6 * alpha))
	draw_colored_polygon(gem, Color(Palette.GOLD_SHADOW, alpha))
	draw_colored_polygon(PackedVector2Array([gem[0], gem[1], gem_center, gem[3]]), Color(Palette.GOLD, alpha))

	# Sparks burst from the death point and fade quickly.
	var spark_alpha: float = clampf(1.0 - _age / 0.7, 0.0, 1.0)
	if spark_alpha > 0.0:
		for spark in _sparks:
			var diamond := Palette.regular_polygon(4, spark["size"] * spark_alpha, spark["rot"])
			draw_colored_polygon(Palette.offset_points(diamond, spark["pos"]), Color(Palette.GOLD, spark_alpha))
