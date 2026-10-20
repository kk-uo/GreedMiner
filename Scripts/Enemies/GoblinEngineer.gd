extends BasicEnemy

## Verdant Planet common ranged goblin: lobs lit dynamite at the hull from
## attack_range. On death it explodes (EnemyExplosion) and hurts everyone in
## explosion_radius - other goblins and the ship alike - so popping one next
## to a crowd is a strategy.

const DYNAMITE := preload("res://Scripts/Enemies/GoblinDynamite.gd")
const EXPLOSION := preload("res://Scripts/VFX/EnemyExplosion.gd")

@export var explosion_radius: float = 70.0
@export var explosion_damage: float = 20.0
## Seconds a dynamite stick spends in the air.
@export var dynamite_flight_time: float = 0.7


func _perform_attack(ship: Ship) -> void:
	var dynamite: Node2D = DYNAMITE.new()
	var spawn_parent := get_parent()
	if spawn_parent == null:
		return
	dynamite.target_ship = ship
	dynamite.damage = attack_damage
	dynamite.flight_time = dynamite_flight_time
	dynamite.z_as_relative = false
	dynamite.z_index = 15
	spawn_parent.add_child(dynamite)
	var hand := global_position + Vector2.RIGHT.rotated(_facing) * 8.0
	dynamite.launch(hand, _get_nearest_ship_boundary_world(ship, global_position))


func _perform_death_effect() -> void:
	EXPLOSION.spawn(get_parent(), global_position, explosion_radius, explosion_damage, target_ship, self)


func _draw() -> void:
	var windup: float = 0.0
	if _is_attacking and _attack_pose_time <= 0.0 and attack_timer != null and not attack_timer.is_stopped():
		windup = clampf(1.0 - attack_timer.time_left / GoblinVisual.WINDUP_TIME, 0.0, 1.0)
	GoblinVisual.draw_engineer(self, _facing, _walk_step(), windup,
			GoblinVisual.attack_amount(_attack_pose_time), _is_flashing(), _anim_time)


func _get_visual_radius() -> float:
	return 10.0


# ==========================================
# Presentation only (GoblinVisual)
# ==========================================

var _anim_time: float = 0.0
var _attack_pose_time: float = 0.0

const WALK_CYCLES_PER_SECOND: float = 1.4


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
		_attack_pose_time = GoblinVisual.ATTACK_POSE_TIME


func _walk_step() -> float:
	return 0.0 if _is_attacking else sin(_anim_time * TAU * WALK_CYCLES_PER_SECOND)


## Presentation: goblins burst into gore instead of the generic flash.
const GOBLIN_GORE := preload("res://Scripts/VFX/GoblinGore.gd")

func _spawn_death_visual(death_position: Vector2) -> void:
	GOBLIN_GORE.spawn(get_parent(), death_position, 1.0)
