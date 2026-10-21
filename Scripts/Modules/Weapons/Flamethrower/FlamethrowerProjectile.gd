class_name FlamethrowerProjectile
extends Area2D

## One shot of the Flamethrower: a short gush of hexagonal fire puffs, which
## are BOTH what you see and what hits, so any enemy touching a visible flame
## hexagon is burnt. Each shot is fired once per attack interval; for
## `emit_window` seconds it keeps pouring EMIT_RATE puffs per second out of
## the nozzle (following the turret as it sweeps). Every puff flies out to
## the attack range, swelling and cooling from white-hot to red, then hangs
## in place for about LINGER_TIME seconds and fades into smoke.
## Damage: each enemy (or tree) that touches ANY puff of this shot takes
## `damage` once per shot, whether the puff is flying or hanging there.

var direction: Vector2 = Vector2.RIGHT
var damage: float = 2.0
var speed: float = 300.0
var max_distance: float = 150.0
## Puff size multiplier (range bonuses make every puff bigger, see Flamethrower).
var size_scale: float = 1.0
var source_weapon: WeaponModule
## Nozzle the puffs pour from while the shot is emitting (optional; without
## it they come from where the shot was placed, along `direction`).
var muzzle: Node2D
## How long this shot keeps pouring puffs (Flamethrower sets one interval).
var emit_window: float = 0.0

const EMIT_RATE: float = 45.0
const LINGER_TIME: float = 0.5
const SPREAD: float = 0.16
## Share of the colour ramp used while flying; the rest is the linger fade.
const FLY_SHARE: float = 0.72
## Hit circle relative to the drawn hexagon (between its in- and out-radius).
const HIT_RADIUS_RATIO: float = 0.93
const SMOKE := Color("2B2420")
const STAGES: Array = [
	[0.10, Color("FFF2C2")],
	[0.26, Color("FFD23F")],
	[0.48, Color("F08A24")],
	[0.66, Color("E2572A")],
	[0.80, Color("B8321F")],
]

var _puffs: Array = []
var _hit_ids: Dictionary = {}
var _emit_left: float = 0.0
var _debt: float = 0.0
var _origin: Vector2
var _time: float = 0.0
var _started: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	area_entered.connect(_on_area_entered)


## Starts pouring (on the first physics frame, after the weapon has filled
## in direction, range, size and nozzle).
func _start() -> void:
	_started = true
	_origin = global_position
	_emit_left = maxf(emit_window, 0.0)
	_spawn_puff()


## True once the shot has stopped pouring and every puff hangs in place.
func is_lingering() -> bool:
	if not _started or _emit_left > 0.0 or _puffs.is_empty():
		return false
	for puff in _puffs:
		if float(puff["age"]) < float(puff["fly"]):
			return false
	return true


func get_puff_count() -> int:
	return _puffs.size()


## World positions of the live puffs (tests / debugging).
func get_puff_positions() -> PackedVector2Array:
	var points := PackedVector2Array()
	for puff in _puffs:
		points.append(puff["pos"])
	return points


func _spawn_puff() -> void:
	var from := _origin
	var angle := direction.angle()
	if is_instance_valid(muzzle):
		from = muzzle.global_position
		angle = muzzle.global_rotation
	var dir := Vector2.RIGHT.rotated(angle + randf_range(-SPREAD, SPREAD))
	var v := speed * randf_range(0.85, 1.1)
	var shape := CircleShape2D.new()
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	var puff := {
		"pos": from + dir * randf_range(0.0, 6.0), "vel": dir * v, "age": 0.0,
		"fly": maxf(max_distance, 1.0) / maxf(v, 1.0) * randf_range(0.9, 1.15),
		"linger": LINGER_TIME * randf_range(0.85, 1.1),
		"rot": randf() * TAU, "spin": randf_range(-4.0, 4.0),
		"size": randf_range(0.8, 1.2) * size_scale,
		"shape": shape, "collision": collision,
	}
	_puffs.append(puff)
	_update_shape(puff)


func _physics_process(delta: float) -> void:
	if not _started:
		_start()
		return
	_time += delta
	if _emit_left > 0.0:
		_emit_left -= delta
		_debt += EMIT_RATE * delta
		while _debt >= 1.0:
			_debt -= 1.0
			_spawn_puff()
	for index in range(_puffs.size() - 1, -1, -1):
		var puff: Dictionary = _puffs[index]
		puff["age"] += delta
		if puff["age"] >= float(puff["fly"]) + float(puff["linger"]):
			(puff["collision"] as Node).queue_free()
			_puffs.remove_at(index)
			continue
		if puff["age"] < puff["fly"]:
			puff["pos"] += puff["vel"] * delta
			puff["rot"] += puff["spin"] * delta
		else:
			puff["rot"] += puff["spin"] * delta * 0.3
		_update_shape(puff)
	if _emit_left <= 0.0 and _puffs.is_empty():
		queue_free()
		return
	queue_redraw()


func _update_shape(puff: Dictionary) -> void:
	(puff["collision"] as Node2D).position = to_local(puff["pos"])
	(puff["shape"] as CircleShape2D).radius = _radius(puff) * HIT_RADIUS_RATIO


## Drawn hexagon radius of a puff (flying: swells; hanging: flickers, grows).
func _radius(puff: Dictionary) -> float:
	var age: float = puff["age"]
	var fly: float = puff["fly"]
	var radius: float
	if age < fly:
		radius = lerpf(3.0, 15.0, sqrt(age / fly))
	else:
		var k: float = (age - fly) / float(puff["linger"])
		radius = (15.0 + 3.0 * k) * (1.0 + 0.08 * sin(age * 30.0 + float(puff["spin"]) * 5.0))
	return radius * float(puff["size"])


func _ramp(puff: Dictionary) -> float:
	var age: float = puff["age"]
	var fly: float = puff["fly"]
	if age < fly:
		return age / fly * FLY_SHARE
	var k: float = (age - fly) / float(puff["linger"])
	return FLY_SHARE + (1.0 - FLY_SHARE) * k * k


func _on_area_entered(area: Area2D) -> void:
	var id := area.get_instance_id()
	if _hit_ids.has(id):
		return
	if area.is_in_group(&"destructible_props"):
		_hit_ids[id] = true
		area.call("take_damage", damage)
		return
	if not area is BasicEnemy:
		return
	var enemy := area as BasicEnemy
	if enemy.is_dying() or not enemy.is_in_group("enemies"):
		return
	_hit_ids[id] = true
	var weapon: WeaponModule = source_weapon if is_instance_valid(source_weapon) else null
	var before := enemy.get_current_health()
	enemy.take_damage(damage, false, true, weapon)
	if weapon != null and is_instance_valid(enemy):
		weapon.projectile_hit.emit(enemy, maxf(before - enemy.get_current_health(), 0.0))


## Oldest puffs (smoke) first so the hot ones near the nozzle sit on top;
## later shots are later in the tree, so they draw over earlier ones.
func _draw() -> void:
	for puff in _puffs:
		var at := to_local(puff["pos"])
		draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(6, _radius(puff), puff["rot"]), at), _color_at(_ramp(puff)))


func _color_at(t: float) -> Color:
	for stage in STAGES:
		if t < stage[0]:
			return stage[1]
	var last: float = STAGES[STAGES.size() - 1][0]
	return Color(SMOKE, 0.7 * (1.0 - (t - last) / (1.0 - last)))
