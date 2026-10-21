class_name Zombie
extends BasicEnemy

const UNDEAD_DEATH := preload("res://Scripts/VFX/UndeadDeath.gd")

## Leave an interactive grave only for genuine combat deaths.
func _perform_death_effect() -> void:
	var scene := get_tree().current_scene
	var battlefield := scene.get_node_or_null("Battlefield") if scene != null else null
	if battlefield != null and battlefield.has_method("add_zombie_grave"):
		battlefield.add_zombie_grave(global_position)

## Death: sinks into its grave (UndeadDeath); the grave rises after it.
func _spawn_death_visual(death_position: Vector2) -> void:
	UNDEAD_DEATH.spawn(get_parent(), death_position, &"zombie", _get_visual_radius() / 12.0, _facing)

## Movement, attacks, and rewards use BasicEnemy. Art: UndeadVisual (style C).
func _draw() -> void:
	UndeadVisual.draw_zombie(self, _facing, _walk_step(0.8), UndeadVisual.attack_amount(_attack_pose_time), _is_flashing(), _anim_time)


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
	super()
	if _is_attacking:
		_attack_pose_time = UndeadVisual.ATTACK_POSE_TIME


func _walk_step(cycles_per_second: float) -> float:
	return 0.0 if _is_attacking else sin(_anim_time * TAU * cycles_per_second)
