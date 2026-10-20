class_name RockGolem
extends BasicEnemy

## Large melee enemy that splits into two Little Rocks when killed.

## Scene created by this enemy's death effect.
@export var split_enemy_scene: PackedScene

## Local offsets keep the two spawned enemies from overlapping completely.
@export var split_offset: float = 18.0


## Spawns exactly two fully initialized Little Rocks at the death position.
func _perform_death_effect() -> void:
	if split_enemy_scene == null:
		push_warning("Rock Golem: Little Rock split scene is missing.")
		return

	var spawn_parent := get_parent()
	if spawn_parent == null:
		return

	var death_position := global_position
	var offsets := [
		Vector2(-split_offset, 0.0),
		Vector2(split_offset, 0.0),
	]

	for offset in offsets:
		var little_rock := split_enemy_scene.instantiate() as LittleRock
		if little_rock == null:
			push_error("Rock Golem: Split scene must use LittleRock.gd.")
			continue

		little_rock.target_ship = target_ship
		# Visual only: the fragments keep the golem's look.
		little_rock.visual_variant = visual_variant
		little_rock.position = spawn_parent.to_local(death_position + offset)
		# Deferred insertion is safe even when death occurs inside a physics query.
		spawn_parent.call_deferred("add_child", little_rock)


## Visual body variant (StoneVisual.Variant); -1 picks one at random on spawn.
@export_enum("Random:-1", "Boulder:0", "Crystal:1") var visual_variant: int = -1

## Walk-cycle clock and remaining attack-pose time (presentation only).
var _anim_time: float = 0.0
var _attack_pose_time: float = 0.0

## Slow, heavy fist swing (full left-right cycles per second).
const WALK_CYCLES_PER_SECOND: float = 0.45


func _ready() -> void:
	super()
	if visual_variant < 0:
		visual_variant = StoneVisual.random_variant()
	_anim_time = randf() * 10.0


func _process(delta: float) -> void:
	_anim_time += delta
	_attack_pose_time = maxf(_attack_pose_time - delta, 0.0)
	super(delta)


## Plays the two-fist slam pose whenever an attack lands.
func _on_attack_timer_timeout() -> void:
	super()
	if _is_attacking:
		_attack_pose_time = StoneVisual.ATTACK_POSE_TIME


func _get_visual_radius() -> float:
	return 28.0


## Grey stone golem (variant chosen per enemy), purple eyes; see StoneVisual.
func _draw() -> void:
	var swing: float = 0.0 if _is_attacking else StoneVisual.heavy_swing(_anim_time, WALK_CYCLES_PER_SECOND)
	StoneVisual.draw_golem(self, visual_variant, _facing, swing,
			StoneVisual.attack_amount(_attack_pose_time), _is_flashing())


## Presentation: the rock shatters into shards and dust.
const STONE_SHATTER := preload("res://Scripts/VFX/StoneShatter.gd")

func _spawn_death_visual(death_position: Vector2) -> void:
	STONE_SHATTER.spawn(get_parent(), death_position, 2.0, false)
