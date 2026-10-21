extends BasicEnemy

const UNDEAD_DEATH := preload("res://Scripts/VFX/UndeadDeath.gd")

## Skeleton, Vampire and Werewolf share this script; stats live in scenes.
## Art: UndeadVisual (style C "gothic night").
func _draw() -> void:
	var attack := UndeadVisual.attack_amount(_attack_pose_time)
	match enemy_id:
		&"skeleton":
			UndeadVisual.draw_skeleton(self, _facing, _walk_step(2.4), attack, _is_flashing(), _anim_time)
		&"vampire":
			UndeadVisual.draw_vampire(self, _facing, _walk_step(1.0), attack, _is_flashing(), _anim_time)
		&"werewolf":
			UndeadVisual.draw_werewolf(self, _facing, _walk_step(2.8), attack, _is_flashing(), _anim_time)
		_:
			UndeadVisual.draw_zombie(self, _facing, _walk_step(0.8), attack, _is_flashing(), _anim_time)

## Death: bone pile / bat swarm / moon howl (UndeadDeath).
func _spawn_death_visual(death_position: Vector2) -> void:
	if enemy_id in [&"skeleton", &"vampire", &"werewolf"]:
		UNDEAD_DEATH.spawn(get_parent(), death_position, enemy_id, _get_visual_radius() / 12.0, _facing)
	else:
		super(death_position)

func _get_visual_radius() -> float:
	return 12.0 if enemy_tier == EnemyTier.COMMON else 20.0


## Vampire blood moon defense is total reduction, not an additional multiplier.
@export_range(0.0, 1.0, 0.01) var vampire_blood_moon_reduction: float = 0.8


func get_blood_moon_total_damage_reduction() -> float:
	return vampire_blood_moon_reduction if enemy_id == &"vampire" else -1.0


# ==========================================
# Presentation only (UndeadVisual)
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
	if enemy_id == &"vampire" and is_blood_moon_active():
		return
	super()
	if _is_attacking:
		_attack_pose_time = UndeadVisual.ATTACK_POSE_TIME


func _walk_step(cycles_per_second: float) -> float:
	return 0.0 if _is_attacking else sin(_anim_time * TAU * cycles_per_second)
