class_name Flamethrower
extends WeaponModule

## Short-range flamethrower. Once a target is in range and the nozzle is on
## it, it sprays a burst of burst_count fire puffs, one every attack_interval
## (10 puffs over 2 s by default), turning to follow the target, then rests
## for burst_pause seconds before the next burst. Every puff flies out to the
## attack range, pierces everything in its way and deals basic_damage once to
## each enemy (and tree) it touches (FlamethrowerProjectile). Each shot is a
## gush of visible hexagon puffs, and every visible puff can hit.

## Damage dealt by each fire puff to each thing it touches.
@export var basic_damage: float = 5.0

## Seconds between puffs inside a burst (0.2 = 5 puffs per second).
@export var attack_interval: float = 0.2

## Puffs per burst (projectile_count).
@export var burst_count: int = 10

## Rest between bursts, in seconds.
@export var burst_pause: float = 1.0

## Maximum targeting distance in pixels.
@export var attack_range: float = 200.0

## Nominal maximum puff radius in pixels; collision and visuals scale together.
@export var projectile_range: float = 15.0

## Puff speed in pixels per second.
@export var projectile_speed: float = 300.0

## Maximum rotation speed in degrees per second.
@export var rotation_speed: float = 120.0

## Maximum aiming error allowed before a burst starts.
@export var aim_tolerance: float = 10.0

@export var projectile_scene: PackedScene

@onready var _turret: Node2D = $Turret
@onready var _muzzle: Marker2D = $Turret/Muzzle
@onready var _sound: WeaponSound = $Sound

var current_target: BasicEnemy = null
## Puffs still to fire in the current burst (0 = not bursting).
var _burst_left: int = 0
var _puff_timer: float = 0.0
var _pause_left: float = 0.0
const BASE_PUFF_RADIUS: float = 15.0
func get_damage() -> float:
	return get_modified_damage(basic_damage)


## Puffs per second while spraying (chips and artifacts scale this).
func get_fire_rate() -> float:
	if attack_interval <= 0.0:
		return 0.0
	return get_modified_fire_rate(1.0 / attack_interval)


## Projectile-range bonuses stretch the reach and fatten every flame puff.
func get_flame_size_scale() -> float:
	return maxf(get_modified_projectile_range(projectile_range) / BASE_PUFF_RADIUS, 0.1)


## True while a burst is spraying (the turret visual shows the pilot flare).
func is_spraying() -> bool:
	return _burst_left > 0


func _process(delta: float) -> void:
	if assembly_mode:
		_sound.stop_sound()
		current_target = null
		_burst_left = 0
		_puff_timer = 0.0
		_pause_left = 0.0
		return
	_pause_left = maxf(_pause_left - delta, 0.0)
	var has_aim := false
	var aim_position := Vector2.ZERO
	if is_manual_control_active():
		current_target = null
		has_aim = has_valid_manual_aim(_turret.global_position)
		aim_position = get_manual_aim_world_position()
	else:
		current_target = keep_or_find_target(current_target, global_position, get_modified_attack_range(attack_range), delta)
		has_aim = is_instance_valid(current_target)
		if has_aim:
			aim_position = current_target.get_target_point(global_position)
	if has_aim:
		rotate_turret_toward(_turret, aim_position, rotation_speed, delta)
	var rate := get_fire_rate()
	if rate <= 0.0:
		return
	if _burst_left > 0:
		# A started burst keeps spraying (sweeping after the target).
		_puff_timer -= delta
		while _puff_timer <= 0.0 and _burst_left > 0:
			fire()
			_burst_left -= 1
			_puff_timer += 1.0 / rate
		if _burst_left == 0:
			_pause_left = burst_pause
		return
	if _pause_left > 0.0 or not has_aim:
		return
	if get_aim_error(_turret, aim_position) > deg_to_rad(aim_tolerance):
		return
	_burst_left = maxi(burst_count, 1)
	_puff_timer = 0.0


## Emits one fire puff from the nozzle.
func fire() -> void:
	if projectile_scene == null:
		push_error("Flamethrower: projectile scene is missing!")
		return
	var puff := projectile_scene.instantiate() as FlamethrowerProjectile
	if puff == null:
		return
	get_tree().current_scene.add_child(puff)
	puff.global_position = _muzzle.global_position
	# A little spread so the stream reads as a cone of flame.
	puff.direction = Vector2.RIGHT.rotated(_muzzle.global_rotation + randf_range(-0.12, 0.12))
	puff.damage = damage
	puff.speed = projectile_speed
	puff.max_distance = get_modified_attack_range(attack_range)
	puff.size_scale = get_flame_size_scale()
	puff.source_weapon = self
	# The shot keeps pouring visible (and damaging) puffs until the next one.
	puff.muzzle = _muzzle
	var rate := get_fire_rate()
	puff.emit_window = 1.0 / rate if rate > 0.0 else 0.0
	_sound.sustain_for(0.28)
