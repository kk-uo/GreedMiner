class_name Hellhunter
extends BasicEnemy

## Fast Volcanic Planet melee chaser: gallops in with speed streaks and bites.


func _draw() -> void:
	DemonVisual.draw_hellhunter(self, _facing, _anim_time, not _is_attacking,
			DemonVisual.attack_amount(_attack_pose_time), _is_flashing())


func _get_visual_radius() -> float:
	return 12.0


# ==========================================
# Presentation only (DemonVisual)
# ==========================================

var _anim_time: float = 0.0
var _attack_pose_time: float = 0.0


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


## Presentation: the demon burns away to ash.
const ASH_DEATH := preload("res://Scripts/VFX/AshDeath.gd")

func _spawn_death_visual(death_position: Vector2) -> void:
	ASH_DEATH.spawn(get_parent(), death_position, 1.2)
