class_name GoblinHunter
extends RangedEnemy

## Common ranged Verdant Planet enemy.

func _draw() -> void:
	var windup: float = 0.0
	if _is_attacking and _attack_pose_time <= 0.0 and attack_timer != null and not attack_timer.is_stopped():
		windup = clampf(1.0 - attack_timer.time_left / GoblinVisual.WINDUP_TIME, 0.0, 1.0)
	GoblinVisual.draw_hunter(self, _facing, _walk_step(), windup,
			GoblinVisual.attack_amount(_attack_pose_time), _is_flashing())


func _get_visual_radius() -> float:
	return 10.0


# ==========================================
# Presentation only (GoblinVisual)
# ==========================================

## Walk-cycle clock and remaining attack-pose time.
var _anim_time: float = 0.0
var _attack_pose_time: float = 0.0

## Quick, scurrying step (full cycles per second).
const WALK_CYCLES_PER_SECOND: float = 1.4


func _ready() -> void:
	super()
	_anim_time = randf() * 10.0


func _process(delta: float) -> void:
	_anim_time += delta
	_attack_pose_time = maxf(_attack_pose_time - delta, 0.0)
	super(delta)


## Plays the attack pose whenever an attack goes out.
func _on_attack_timer_timeout() -> void:
	super()
	if _is_attacking:
		_attack_pose_time = GoblinVisual.ATTACK_POSE_TIME


func _walk_step() -> float:
	return 0.0 if _is_attacking else sin(_anim_time * TAU * WALK_CYCLES_PER_SECOND)


## Presentation: goblins burst into gore instead of the generic flash.
const GOBLIN_GORE := preload("res://Scripts/VFX/GoblinGore.gd")

func _spawn_death_visual(death_position: Vector2) -> void:
	GOBLIN_GORE.spawn(get_parent(), death_position, 1.0)
