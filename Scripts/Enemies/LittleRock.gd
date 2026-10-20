class_name LittleRock
extends BasicEnemy

## Small common melee enemy used by the Rocky Planet enemy family.


## Visual body variant (StoneVisual.Variant); -1 picks one at random on spawn.
@export_enum("Random:-1", "Boulder:0", "Crystal:1") var visual_variant: int = -1

## Waddle clock and remaining lunge time (presentation only).
var _anim_time: float = 0.0
var _attack_pose_time: float = 0.0

const WALK_CYCLES_PER_SECOND: float = 2.6


func _ready() -> void:
	super()
	if visual_variant < 0:
		visual_variant = StoneVisual.random_variant()
	_anim_time = randf() * 10.0


func _process(delta: float) -> void:
	_anim_time += delta
	_attack_pose_time = maxf(_attack_pose_time - delta, 0.0)
	super(delta)


## Plays a short head-butt lunge whenever an attack lands.
func _on_attack_timer_timeout() -> void:
	super()
	if _is_attacking:
		_attack_pose_time = StoneVisual.ATTACK_POSE_TIME


## Grey stone pebble (variant chosen per enemy), purple eyes; see StoneVisual.
func _draw() -> void:
	var step: float = 0.0 if _is_attacking else sin(_anim_time * TAU * WALK_CYCLES_PER_SECOND)
	StoneVisual.draw_little_rock(self, visual_variant, _facing, step,
			StoneVisual.attack_amount(_attack_pose_time), _is_flashing())


## Presentation: the rock shatters into shards and dust.
const STONE_SHATTER := preload("res://Scripts/VFX/StoneShatter.gd")

func _spawn_death_visual(death_position: Vector2) -> void:
	STONE_SHATTER.spawn(get_parent(), death_position, 1.0, false)
