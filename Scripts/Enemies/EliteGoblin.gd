class_name EliteGoblin
extends BasicEnemy

## Large Verdant Planet melee enemy with percentage damage reduction.
## Can also be hurled by the Goblin Giant Chariot (throw_to / root_for work the
## same as on Goblin: arc flight, land, stay rooted, then normal AI).

## Seconds left before this elite may move / attack again.
var _root_time: float = 0.0
var _flight_from := Vector2.ZERO
var _flight_time: float = 0.0
var _flight_age: float = 0.0


func root_for(seconds: float) -> void:
	_root_time = maxf(_root_time, seconds)
	_stop_attacking()


func is_rooted() -> bool:
	return _root_time > 0.0


func get_root_time_left() -> float:
	return _root_time


## Placed on its landing spot first, then drawn flying in from from_global.
func throw_to(from_global: Vector2, flight_time: float, root_duration: float) -> void:
	_flight_from = from_global - global_position
	_flight_time = maxf(flight_time, 0.0)
	_flight_age = 0.0
	root_for(_flight_time + root_duration)


func is_in_flight() -> bool:
	return _flight_age < _flight_time


func _physics_process(delta: float) -> void:
	if _root_time > 0.0 and not _is_dying:
		_root_time = maxf(_root_time - delta, 0.0)
		_stop_attacking()
		if is_instance_valid(target_ship) and target_ship is Ship:
			var to_ship := _get_nearest_ship_boundary_world(target_ship as Ship, global_position) - global_position
			if to_ship.length_squared() > 0.01:
				_facing = to_ship.angle()
		return
	super(delta)


func _draw() -> void:
	if _flight_age < _flight_time:
		var k: float = _flight_age / _flight_time
		var origin: Vector2 = _flight_from * (1.0 - k) + Vector2(0.0, -sin(k * PI) * 46.0)
		draw_set_transform(origin, 0.0, Vector2.ONE * (1.0 + 0.3 * sin(k * PI)))
	GoblinVisual.draw_elite(self, _facing, _walk_step(),
			GoblinVisual.attack_amount(_attack_pose_time), _is_flashing())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_visual_radius() -> float:
	return 20.0


# ==========================================
# Presentation only (GoblinVisual)
# ==========================================

## Walk-cycle clock and remaining attack-pose time.
var _anim_time: float = 0.0
var _attack_pose_time: float = 0.0

## Quick, scurrying step (full cycles per second).
const WALK_CYCLES_PER_SECOND: float = 0.8


func _ready() -> void:
	super()
	_anim_time = randf() * 10.0


func _process(delta: float) -> void:
	_anim_time += delta
	if _flight_age < _flight_time:
		_flight_age += delta
	_attack_pose_time = maxf(_attack_pose_time - delta, 0.0)
	super(delta)


## Plays the attack pose whenever an attack goes out.
func _on_attack_timer_timeout() -> void:
	super()
	if _is_attacking:
		_attack_pose_time = GoblinVisual.ATTACK_POSE_TIME


func _walk_step() -> float:
	return 0.0 if (_is_attacking or _root_time > 0.0) else sin(_anim_time * TAU * WALK_CYCLES_PER_SECOND)


## Presentation: a bigger gore burst, and the shield drops to the ground,
## lies there for a while, then fades.
const GOBLIN_GORE := preload("res://Scripts/VFX/GoblinGore.gd")
const DROPPED_SHIELD := preload("res://Scripts/VFX/DroppedShield.gd")

func _spawn_death_visual(death_position: Vector2) -> void:
	GOBLIN_GORE.spawn(get_parent(), death_position, 1.4)
	DROPPED_SHIELD.spawn(get_parent(), death_position, _facing)
