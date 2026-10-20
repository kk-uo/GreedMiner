class_name Imp
extends RangedEnemy

## Small Volcanic Planet ranged enemy: hovers, grows a fireball in its hand and
## throws it at the ship.


func _draw() -> void:
	var charge := DemonVisual.windup_amount(_is_attacking, _attack_pose_time, attack_timer, DemonVisual.CHARGE_TIME)
	DemonVisual.draw_imp(self, _facing, _anim_time, charge,
			DemonVisual.attack_amount(_attack_pose_time), _is_flashing())


func _get_visual_radius() -> float:
	return 10.0


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
	ASH_DEATH.spawn(get_parent(), death_position, 1.0)
