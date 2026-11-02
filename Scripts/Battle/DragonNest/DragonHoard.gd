class_name DragonHoard
extends Node2D

signal attempt_started(hoard: DragonHoard)
signal steal_succeeded(hoard: DragonHoard, reward: int)
signal steal_failed(hoard: DragonHoard)
signal depleted(hoard: DragonHoard)

@export var hoard_id: StringName = &"small"
@export var display_name: String = "SMALL HOARD"
@export_range(1, 20, 1) var maximum_successes: int = 5
@export_range(0, 10000, 1) var reward_per_success: int = 100
@export_range(0.1, 10.0, 0.1) var attempt_duration: float = 2.5
@export_range(1, 10, 1) var required_clicks: int = 3
@export_range(10.0, 200.0, 1.0) var interaction_radius: float = 42.0
@export_range(10.0, 100.0, 1.0) var target_radius: float = 22.0
## Radius of the treasure mountain (x; y is 0.77 of it). Set by the controller.
@export_range(20.0, 300.0, 1.0) var pile_radius: float = 90.0

var _pile_mesh: ArrayMesh
var _egg_pen := MeshBatch2D.new()
var _egg_time: float = 0.0
var _egg_wait: float = 0.0

## Ancient Dragon phase two hatches the egg of every hoard not emptied.
var egg_hatched: bool = false
var _hatch_age: float = -1.0
var successful_steals: int = 0
var attempt_active: bool = false
var attempt_clicks: int = 0
var attempt_time_left: float = 0.0
var _target_index: int = 0

const TARGET_OFFSETS: Array[Vector2] = [
	Vector2(-30.0, -18.0),
	Vector2(32.0, -12.0),
	Vector2(0.0, 28.0),
]


func _process(delta: float) -> void:
	# The egg glows slowly; repaint it a few times a second.
	_egg_time += delta
	if _hatch_age >= 0.0:
		_hatch_age += delta
		if _hatch_age < 0.8:
			queue_redraw()
	_egg_wait -= delta
	if _egg_wait <= 0.0:
		_egg_wait = 0.1
		queue_redraw()
	if not attempt_active:
		return
	attempt_time_left = maxf(attempt_time_left - delta, 0.0)
	if attempt_time_left <= 0.0:
		_finish_attempt(false)
	queue_redraw()


## Hatches this hoard's egg unless the hoard was emptied. Returns true if a
## dragon should come out of it.
func hatch_egg() -> bool:
	if egg_hatched or is_depleted():
		return false
	egg_hatched = true
	_hatch_age = 0.0
	queue_redraw()
	return true


func begin_attempt() -> bool:
	if attempt_active or is_depleted():
		return false
	attempt_active = true
	attempt_clicks = 0
	attempt_time_left = attempt_duration
	_target_index = successful_steals % TARGET_OFFSETS.size()
	attempt_started.emit(self)
	queue_redraw()
	return true


## Returns true only inside this hoard's active spatial interaction region.
func route_click(world_position: Vector2) -> bool:
	if is_depleted():
		return false
	if not attempt_active:
		if world_position.distance_to(global_position) > interaction_radius:
			return false
		begin_attempt()
		return true
	var target := global_position + TARGET_OFFSETS[_target_index]
	if world_position.distance_to(target) <= target_radius:
		attempt_clicks += 1
		_target_index = (_target_index + 1) % TARGET_OFFSETS.size()
		if attempt_clicks >= required_clicks:
			_finish_attempt(true)
		queue_redraw()
		return true
	# Consume clicks only in the active hoard region. Outside clicks remain
	# available to mining QTEs, weapons, and other world interactions.
	return world_position.distance_to(global_position) <= interaction_radius + 45.0


func cancel_attempt() -> void:
	if attempt_active:
		_finish_attempt(false)


func _finish_attempt(succeeded: bool) -> void:
	if not attempt_active:
		return
	attempt_active = false
	attempt_time_left = 0.0
	if succeeded:
		successful_steals = mini(successful_steals + 1, maximum_successes)
		steal_succeeded.emit(self, reward_per_success)
		if is_depleted():
			depleted.emit(self)
	else:
		steal_failed.emit(self)
	queue_redraw()


func is_depleted() -> bool:
	return successful_steals >= maximum_successes


func _draw() -> void:
	if _pile_mesh == null:
		_pile_mesh = _bake_pile()
	# The mountain shrinks with every successful steal.
	var left := 1.0 - float(successful_steals) / float(maxi(maximum_successes, 1))
	var k := lerpf(0.42, 1.0, left)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)
	draw_mesh(_pile_mesh, null, Transform2D.IDENTITY, Color(0.55, 0.5, 0.45) if is_depleted() else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	# The dragon egg the guardian is brooding sits on top of the heap.
	var egg_r := 15.0 + pile_radius * 0.08
	if not egg_hatched:
		_egg_pen.clear()
		DragonNestArt.egg(_egg_pen, Vector2(0.0, -4.0), egg_r, _egg_time)
		_egg_pen.flush_to(self)
	else:
		_draw_hatched_shell(Vector2(0.0, -4.0), egg_r)
	if attempt_active:
		var target := TARGET_OFFSETS[_target_index]
		draw_arc(target, target_radius, 0.0, TAU, 24, Color("66e0c2"), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-35.0, pile_radius * 0.77 + 22.0), tr("STEAL %d/%d  %.1fs") % [attempt_clicks, required_clicks, attempt_time_left], HORIZONTAL_ALIGNMENT_CENTER, 70.0, 12, Color("ffd35a"))


## Two broken shell halves where the egg was; a burst of shell bits and a
## flash while it hatches.
func _draw_hatched_shell(at: Vector2, r: float) -> void:
	var shell := Color("A82A1E")
	var inner := Color("1a1210")
	draw_colored_polygon(PackedVector2Array([at + Vector2(-r, 2), at + Vector2(-r * 0.7, -r * 0.6), at + Vector2(-r * 0.3, -r * 0.2), at + Vector2(0, -r * 0.7), at + Vector2(0, r * 0.5), at + Vector2(-r * 0.6, r * 0.6)]), shell)
	draw_colored_polygon(PackedVector2Array([at + Vector2(r * 0.15, r * 0.5), at + Vector2(r * 0.3, -r * 0.5), at + Vector2(r * 0.6, -r * 0.1), at + Vector2(r * 0.95, -r * 0.55), at + Vector2(r, r * 0.3)]), shell.darkened(0.15))
	draw_circle(at + Vector2(0, r * 0.15), r * 0.4, inner)
	if _hatch_age >= 0.0 and _hatch_age < 0.8:
		var k := _hatch_age / 0.8
		draw_circle(at, r * (1.2 + 2.5 * k), Color(1.0, 0.7, 0.3, 0.5 * (1.0 - k)))
		for i in range(10):
			var dir := Vector2.from_angle(TAU * float(i) / 10.0 + 0.3)
			var p := at + dir * r * (0.6 + 3.2 * k) + Vector2(0, 40.0 * k * k)
			draw_circle(p, 3.0 * (1.0 - k) + 1.0, Color(shell, 1.0 - k))


## A treasure mountain: one big irregular heap plus smaller heaps around it
## (no clean oval), gems and treasure poking out.
func _bake_pile() -> ArrayMesh:
	var pen := MeshBatch2D.new()
	var seed_value := int(hash(hoard_id)) & 0xffff
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(4):
		var a := rng.randf() * TAU
		var p := Vector2(cos(a) * pile_radius * 0.85, sin(a) * pile_radius * 0.62)
		DragonNestArt.gold_mound(pen, p, pile_radius * rng.randf_range(0.32, 0.45), seed_value + 10 + i, 1)
	DragonNestArt.gold_mound(pen, Vector2.ZERO, pile_radius * 0.8, seed_value, 3)
	return pen.build()
