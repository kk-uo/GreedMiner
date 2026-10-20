class_name Goblin
extends BasicEnemy

## Common Verdant Planet melee enemy.
##
## Extras used by the Goblin family's special spawns:
## - is_flag_bearer: the one banner carrier in a Goblin Pack formation. Same
##   gameplay stats as any goblin; only the visual differs (V1).
## - root_for() / throw_to(): goblins hurled by the Goblin Giant Chariot fly in
##   an arc, land, stay rooted (no movement, no attacks) for a while, then use
##   normal goblin AI.

## Visual marker only: draws a banner on this goblin.
@export var is_flag_bearer: bool = false

## Seconds left before this goblin may move / attack again.
var _root_time: float = 0.0
## Thrown-flight presentation: start offset (relative to the landing spot),
## total and elapsed flight time.
var _flight_from := Vector2.ZERO
var _flight_time: float = 0.0
var _flight_age: float = 0.0


## Keeps the goblin in place for seconds (stacks to the longest request).
func root_for(seconds: float) -> void:
	_root_time = maxf(_root_time, seconds)
	_stop_attacking()


func is_rooted() -> bool:
	return _root_time > 0.0


func get_root_time_left() -> float:
	return _root_time


## Called right after this goblin is placed on its landing spot: it is drawn
## flying in from from_global for flight_time, then stays rooted for
## root_duration after landing.
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
			var ship := target_ship as Ship
			var to_ship := _get_nearest_ship_boundary_world(ship, global_position) - global_position
			if to_ship.length_squared() > 0.01:
				_facing = to_ship.angle()
		return
	super(delta)


func _draw() -> void:
	var origin := Vector2.ZERO
	var lift: float = 1.0
	if _flight_age < _flight_time:
		var k: float = _flight_age / _flight_time
		origin = _flight_from * (1.0 - k) + Vector2(0.0, -sin(k * PI) * 46.0)
		lift = 1.0 + 0.35 * sin(k * PI)
	GoblinVisual.draw_goblin(self, _facing, _walk_step(),
			GoblinVisual.attack_amount(_attack_pose_time), _is_flashing(), is_flag_bearer, origin, lift)


func _get_visual_radius() -> float:
	return 10.0


# ==========================================
# Presentation only (GoblinVisual)
# ==========================================

## Walk-cycle clock and remaining attack-pose time.
var _anim_time: float = 0.0
var _attack_pose_time: float = 0.0

## Quick, scurrying step (full cycles per second).
const WALK_CYCLES_PER_SECOND: float = 1.6


func _ready() -> void:
	super()
	_anim_time = randf() * 10.0
	# The banner is drawn over neighbouring goblins in the formation.
	if is_flag_bearer:
		z_index = 1


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


## Presentation: goblins burst into gore instead of the generic flash.
const GOBLIN_GORE := preload("res://Scripts/VFX/GoblinGore.gd")

func _spawn_death_visual(death_position: Vector2) -> void:
	GOBLIN_GORE.spawn(get_parent(), death_position, 1.0)
