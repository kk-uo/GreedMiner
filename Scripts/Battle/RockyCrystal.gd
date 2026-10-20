extends Node2D

## An individual crystal; the battlefield owns placement and battle owns rewards.
signal broken(world_position: Vector2, is_red: bool)

const REQUIRED_CLICKS := 10
var is_red := false
var _gold := false
var _size := 1.0
var _base_rotation := 0.0
var _clicks := 0
var _broken := false
var _shake: Tween


func configure(crystal_size: float, angle: float, gold: bool, red: bool) -> void:
	_size = crystal_size
	_base_rotation = angle
	rotation = angle
	_gold = gold
	is_red = red


func contains_world_point(point: Vector2) -> bool:
	var local := to_local(point) / _size
	return not _broken and Rect2(-10.0, -23.0, 20.0, 38.0).has_point(local)


func register_click() -> void:
	if _broken:
		return
	_clicks += 1
	if _clicks >= REQUIRED_CLICKS:
		_broken = true
		broken.emit(global_position, is_red)
		queue_free()
		return
	if _shake != null and _shake.is_valid():
		_shake.kill()
	rotation = _base_rotation
	_shake = create_tween()
	_shake.tween_property(self, "rotation", _base_rotation + 0.10, 0.04)
	_shake.tween_property(self, "rotation", _base_rotation - 0.07, 0.05)
	_shake.tween_property(self, "rotation", _base_rotation, 0.05)


func _draw() -> void:
	var light := Palette.GOLD if _gold else Palette.COBALT
	var dark := Palette.GOLD_SHADOW if _gold else Palette.COBALT_SHADOW
	var shine := Palette.GOLD_LIGHT if _gold else Palette.COBALT_LIGHT
	if is_red:
		light = Color("e04b42")
		dark = Color("87292b")
		shine = Color("ffb2a2")
	var glow := light
	glow.a = 0.10
	draw_circle(Vector2.ZERO, 30.0 * _size, glow)
	draw_circle(Vector2(2.0, 14.0 * _size), 9.0 * _size, Palette.SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _size)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -22), Vector2(8, -12), Vector2(8, 6), Vector2(0, 14)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -22), Vector2(-8, -12), Vector2(-8, 6), Vector2(0, 14)]), light)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -22), Vector2(-8, -12), Vector2(0, -9)]), shine)
