class_name Demon
extends BasicEnemy

## Common Volcanic Planet melee enemy: pulls its pitchfork back, then thrusts.


func _draw() -> void:
	var windup := DemonVisual.windup_amount(_is_attacking, _attack_pose_time, attack_timer, DemonVisual.WINDUP_TIME)
	DemonVisual.draw_demon(self, _facing, _walk_step(), windup,
			DemonVisual.attack_amount(_attack_pose_time), _is_flashing())


func _get_visual_radius() -> float:
	return 14.0


# ==========================================
# Presentation only (DemonVisual)
# ==========================================

var _anim_time: float = 0.0
var _attack_pose_time: float = 0.0

const WALK_CYCLES_PER_SECOND: float = 1.3


func _ready() -> void:
	super()
	_anim_time = randf() * 10.0


func _process(delta: float) -> void:
	_anim_time += delta
	_attack_pose_time = maxf(_attack_pose_time - delta, 0.0)
	super(delta)


func _on_attack_timer_timeout() -> void:
	super()
	if _is_attacking:
		_attack_pose_time = DemonVisual.ATTACK_POSE_TIME


func _walk_step() -> float:
	return 0.0 if _is_attacking else sin(_anim_time * TAU * WALK_CYCLES_PER_SECOND)


## Presentation: the demon burns away to ash.
const ASH_DEATH := preload("res://Scripts/VFX/AshDeath.gd")

func _spawn_death_visual(death_position: Vector2) -> void:
	ASH_DEATH.spawn(get_parent(), death_position, 1.3)
