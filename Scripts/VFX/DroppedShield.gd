extends Node2D

## Gear knocked loose when an enemy dies: it is flung a short way spinning,
## lands with a bounce and lies on the ground, then fades and sinks away.
## kind &"shield": an Elite Goblin's round wooden shield.
## kind &"ice_club": a Big Snow Monster's ice club (the ice melts away).
## Presentation only.
## Load with preload(); no class_name on purpose.

const REST: float = 5.0
const FADE: float = 1.0
const GRAVITY: float = 620.0
const RADIUS: float = 12.0

var _age: float = 0.0
var _pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _z: float = 6.0
var _vz: float = 170.0
var _rot: float = 0.0
var _spin: float = 9.0
var _landed: bool = false
var _land_age: float = 0.0
var _bounces: int = 0
var kind: StringName = &"shield"


## Spawns the shield at a global position, tossed away from `facing`.
static func spawn(parent: Node, at: Vector2, facing: float, gear: StringName = &"shield") -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var shield: Node2D = load("res://Scripts/VFX/DroppedShield.gd").new()
	shield.set("kind", gear)
	parent.add_child(shield)
	shield.global_position = at + Vector2.RIGHT.rotated(facing) * 8.0
	shield.call("_toss", facing)
	return shield


func _toss(facing: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_vel = Vector2.RIGHT.rotated(facing + PI + rng.randf_range(-1.0, 1.0)) * rng.randf_range(40.0, 75.0)
	_spin = rng.randf_range(7.0, 12.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	_rot = rng.randf() * TAU


func _ready() -> void:
	z_index = 0


func _process(delta: float) -> void:
	_age += delta
	if not _landed:
		_pos += _vel * delta
		_z += _vz * delta
		_vz -= GRAVITY * delta
		_rot += _spin * delta
		if _z <= 0.0:
			_z = 0.0
			if _bounces < 1 and _vz < -90.0:
				_vz = -_vz * 0.3
				_vel *= 0.4
				_spin *= 0.3
				_bounces += 1
			else:
				_landed = true
	else:
		_land_age += delta
		if _land_age >= REST + FADE:
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	var fade := 1.0
	var sink := 1.0
	if _landed and _land_age > REST:
		var t := (_land_age - REST) / FADE
		fade = 1.0 - t
		sink = 1.0 - 0.25 * t
	if kind == &"ice_club":
		_draw_club(fade, sink)
		return
	var lift := 1.0 + _z / 160.0
	var r := RADIUS * lift * sink
	var at := _pos + Vector2(0.0, -_z)
	draw_circle(_pos + Vector2(3.0, 4.0) * (1.0 + _z / 40.0), RADIUS * sink, Color(0, 0, 0, 0.28 * fade))
	# Round wooden shield lying flat: dark rim, planks, iron band, boss.
	draw_circle(at, r, Color(Palette.GOBLIN_WOOD_DARK, fade))
	draw_circle(at + Vector2(-0.6, -0.6), r * 0.86, Color(Palette.GOBLIN_WOOD_LIGHT, fade))
	var along := Vector2.RIGHT.rotated(_rot)
	var across := Vector2(-along.y, along.x)
	for k in [-0.45, 0.0, 0.45]:
		var offset: Vector2 = across * r * float(k)
		var half := sqrt(maxf(1.0 - float(k) * float(k), 0.0)) * r * 0.84
		draw_line(at + offset - along * half, at + offset + along * half, Color(Palette.GOBLIN_WOOD, fade), 1.2)
	draw_arc(at, r * 0.93, 0.0, TAU, 28, Color(Palette.GOBLIN_IRON, fade), 1.8)
	for k in range(6):
		draw_circle(at + Vector2.RIGHT.rotated(_rot + TAU * float(k) / 6.0) * r * 0.93, 1.1 * lift, Color(Palette.GOBLIN_IRON_LIGHT, fade))
	draw_circle(at, 4.2 * lift * sink, Color(Palette.GOBLIN_IRON_DARK, fade))
	draw_circle(at + Vector2(-0.6, -0.6), 3.0 * lift * sink, Color(Palette.GOBLIN_IRON_LIGHT, fade))
	# A fresh crack and a blood smear from the fight.
	draw_polyline(PackedVector2Array([at + along.rotated(0.9) * r * 0.85, at + along.rotated(1.1) * r * 0.45, at + along.rotated(0.8) * r * 0.2]), Color(Palette.GOBLIN_WOOD_DARK, fade), 1.2)
	draw_circle(at + along.rotated(-2.2) * r * 0.5, r * 0.18, Color(Color("7A1218"), 0.8 * fade))


## Ice club lying on the ground: wooden haft, faceted ice block; as it fades
## the ice melts into a small puddle.
func _draw_club(fade: float, sink: float) -> void:
	var lift := 1.0 + _z / 160.0
	var at := _pos + Vector2(0.0, -_z)
	var along := Vector2.RIGHT.rotated(_rot)
	var across := Vector2(-along.y, along.x)
	var melt := 1.0
	if _landed and _land_age > REST:
		melt = 1.0 - (_land_age - REST) / FADE
	if _landed:
		draw_circle(_pos + along * 14.0, 11.0 * (1.2 - melt * 0.4), Color(Color("9FE7FF"), 0.25 * fade))
	draw_line(_pos - along * 18.0 + Vector2(3, 4), _pos + along * 6.0 + Vector2(3, 4), Color(0, 0, 0, 0.28 * fade), 5.0)
	draw_circle(_pos + along * 15.0 + Vector2(3.0, 4.0) * (1.0 + _z / 40.0), 9.0, Color(0, 0, 0, 0.28 * fade))
	draw_line(at - along * 18.0 * lift, at + along * 6.0 * lift, Color(Palette.GOBLIN_WOOD_DARK, fade), 4.4 * lift)
	draw_line(at - along * 17.0 * lift, at + along * 5.0 * lift, Color(Palette.GOBLIN_WOOD, fade), 2.2 * lift)
	draw_line(at - along * 14.0 * lift - across * 2.5, at - along * 14.0 * lift + across * 2.5, Color(Palette.GOBLIN_LEATHER, fade), 2.0)
	var head := at + along * 15.0 * lift
	var h := 9.0 * lift * clampf(melt, 0.3, 1.0)
	var block := PackedVector2Array([head - along * h - across * h * 0.8, head + along * h * 0.6 - across * h, head + along * h, head + along * h * 0.6 + across * h, head - along * h + across * h * 0.8, head - along * h * 1.2])
	draw_colored_polygon(block, Color(Color("7FB3D6"), fade))
	var inner := PackedVector2Array()
	for point in block:
		inner.append(head + (point - head) * 0.68 + Vector2(-0.8, -0.8))
	draw_colored_polygon(inner, Color(Color("CFEFFF"), fade))
	draw_line(head - along * h * 0.5 - across * h * 0.3, head + along * h * 0.5 - across * h * 0.5, Color(1, 1, 1, 0.8 * fade), 1.2)
