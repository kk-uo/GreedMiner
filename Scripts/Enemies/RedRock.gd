extends BasicEnemy

## Rocky Planet common kamikaze: a fast red magma pebble.
## When it reaches the ship it stops, glows for fuse_time and blows itself up.
## Every death (shot, clicked, caught in another blast, or self-destruct)
## leaves an EnemyExplosion that hurts EVERYONE in explosion_radius: nearby
## enemies and the ship alike, so popping it inside a crowd is a strategy.
## Self-destructing on the hull grants no ore; any other death pays reward_ore.

const EXPLOSION := preload("res://Scripts/VFX/EnemyExplosion.gd")

@export var explosion_radius: float = 70.0
@export var explosion_damage: float = 20.0
## Seconds it glows at the hull before exploding.
@export var fuse_time: float = 0.35

var _fuse_left: float = -1.0
var _self_destructed: bool = false
var _anim_time: float = 0.0

const WALK_CYCLES_PER_SECOND: float = 3.4


func _ready() -> void:
	super()
	_anim_time = randf() * 10.0


func _process(delta: float) -> void:
	_anim_time += delta
	super(delta)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	if _fuse_left >= 0.0:
		_fuse_left -= delta
		if _fuse_left <= 0.0:
			_self_destructed = true
			_current_health = 0.0
			_die()
		return
	super(delta)


## Reaching the ship lights the fuse instead of attacking.
func _start_attacking() -> void:
	if _fuse_left < 0.0 and not _is_dying:
		_fuse_left = fuse_time


func is_fuse_lit() -> bool:
	return _fuse_left >= 0.0


func _perform_death_effect() -> void:
	EXPLOSION.spawn(get_parent(), global_position, explosion_radius, explosion_damage, target_ship, self)


func _grant_reward(death_position: Vector2) -> void:
	if _self_destructed:
		return
	super(death_position)


func _get_visual_radius() -> float:
	return 12.0


func _draw() -> void:
	var lit: bool = _fuse_left >= 0.0
	var heat: float = 1.0 - clampf(_fuse_left / maxf(fuse_time, 0.01), 0.0, 1.0) if lit else 0.0
	var step: float = 0.0 if lit else sin(_anim_time * TAU * WALK_CYCLES_PER_SECOND)
	if lit:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (1.0 + 0.25 * heat))
	StoneVisual.draw_red_rock(self, _facing, step, heat, _anim_time, _is_flashing() or (lit and fmod(_anim_time, 0.12) < 0.04))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Presentation: the rock shatters into shards and dust.
const STONE_SHATTER := preload("res://Scripts/VFX/StoneShatter.gd")

func _spawn_death_visual(death_position: Vector2) -> void:
	STONE_SHATTER.spawn(get_parent(), death_position, 1.1, true)
