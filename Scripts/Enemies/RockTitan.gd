class_name RockTitan
extends BasicEnemy

## Boss of the Rocky Planet family: a slow walking mountain that splits into
## four Rock Golems when killed. Visuals live in StoneVisual.draw_titan().

## Scene created by this enemy's death effect.
@export var split_enemy_scene: PackedScene

## Number of golems released on death.
@export_range(1, 8, 1) var split_count: int = 4

## Distance from the titan's center at which the golems appear.
@export var split_radius: float = 70.0

## Permanent first-kill reward. ArtifactManager enforces global uniqueness.
@export var first_kill_artifact_id: StringName = &"stone_heart"

## Walk-cycle clock, slam timer and step tracking (presentation only).
var _anim_time: float = 0.0
var _slam_left: float = 0.0
var _last_step_sign: float = 0.0
var _shake_tween: Tween
var _shake_base_offset: Vector2 = Vector2.ZERO
var _trail_timer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO

const WALK_CYCLES_PER_SECOND: float = 0.26
const STEP_SHAKE: float = 1.6
const SLAM_SHAKE: float = 7.0
## Seconds between the light dust trails left behind while walking.
const TRAIL_INTERVAL: float = 0.22


func _ready() -> void:
	super()
	_anim_time = randf() * 10.0
	_last_position = global_position


func _process(delta: float) -> void:
	_anim_time += delta
	_slam_left = maxf(_slam_left - delta, 0.0)
	var moved: float = global_position.distance_to(_last_position)
	_last_position = global_position
	# A camera bump and a dust cloud under the planted fist on every footfall,
	# plus a light dust trail behind the body while it is moving.
	if not _is_attacking and not _is_dying:
		# A fist is planted the moment the heavy swing reaches either end.
		var swing: float = StoneVisual.heavy_swing(_anim_time, WALK_CYCLES_PER_SECOND)
		var planted_sign: float = signf(swing) if absf(swing) > 0.999 else 0.0
		if planted_sign != 0.0 and planted_sign != _last_step_sign:
			_shake_camera(STEP_SHAKE, 0.12)
			_footstep_dust(planted_sign)
		_last_step_sign = planted_sign if planted_sign != 0.0 else _last_step_sign
		if moved > 0.001:
			_trail_timer -= delta
			if _trail_timer <= 0.0:
				_trail_timer = TRAIL_INTERVAL
				_trail_dust()
	super(delta)


## Plays the two-fist slam pose and a heavy camera shake when an attack lands.
func _on_attack_timer_timeout() -> void:
	super()
	if _is_attacking:
		_slam_left = StoneVisual.TITAN_SLAM_TIME
		_shake_camera(SLAM_SHAKE, 0.3)
		var forward := Vector2.RIGHT.rotated(_facing)
		StoneDust.spawn(get_parent(), _titan_point(Vector2(128.0, 0.0)), 16, 22.0, 120.0, 1.5, forward, 1.3)


func _get_visual_radius() -> float:
	return StoneVisual.TITAN_VISUAL_RADIUS


func _draw() -> void:
	var swing: float = 0.0 if _is_attacking else StoneVisual.heavy_swing(_anim_time, WALK_CYCLES_PER_SECOND)
	StoneVisual.draw_titan(self, _facing, swing, StoneVisual.titan_slam_amount(_slam_left),
			_is_flashing(), _anim_time)


## Releases split_count Rock Golems in a ring around the death position.
func _perform_death_effect() -> void:
	if not first_kill_artifact_id.is_empty():
		ArtifactManager.grant_artifact(first_kill_artifact_id)
	_shake_camera(SLAM_SHAKE * 1.4, 0.45)
	TitanCollapse.spawn(get_parent(), global_position, StoneVisual.TITAN_VISUAL_RADIUS)
	if split_enemy_scene == null:
		push_warning("Rock Titan: Rock Golem split scene is missing.")
		return

	var spawn_parent := get_parent()
	if spawn_parent == null:
		return

	var death_position := global_position
	for index in range(split_count):
		var golem := split_enemy_scene.instantiate() as BasicEnemy
		if golem == null:
			push_error("Rock Titan: Split scene must inherit BasicEnemy.gd.")
			continue

		var angle: float = _facing + PI * 0.25 + TAU * float(index) / float(split_count)
		golem.target_ship = target_ship
		golem.position = spawn_parent.to_local(death_position + Vector2.RIGHT.rotated(angle) * split_radius)
		# Deferred insertion is safe even when death occurs inside a physics query.
		spawn_parent.call_deferred("add_child", golem)


## Shakes the battle camera around its resting offset (presentation only).
func _shake_camera(amount: float, duration: float) -> void:
	if not is_instance_valid(target_ship) or not target_ship is Ship:
		return
	var camera: Camera2D = (target_ship as Ship).world_camera
	if camera == null:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		camera.offset = _shake_base_offset
	_shake_base_offset = camera.offset
	# Bound to the camera so the restore still runs if the titan is freed mid-shake.
	_shake_tween = camera.create_tween()
	var steps: int = maxi(int(duration / 0.03), 2)
	var base := _shake_base_offset
	for step in range(steps):
		var strength: float = amount * (1.0 - float(step) / float(steps))
		_shake_tween.tween_property(camera, "offset",
				base + Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.03)
	_shake_tween.tween_property(camera, "offset", base, 0.03)


## Converts a point in titan design units (before TITAN_DRAW_SCALE) to world space.
func _titan_point(local_point: Vector2) -> Vector2:
	return global_position + (local_point * StoneVisual.TITAN_DRAW_SCALE).rotated(_facing)


## Dust rolling out from under the fist that just landed.
func _footstep_dust(step_sign: float) -> void:
	var fist := _titan_point(Vector2(80.0, -112.0 * step_sign))
	StoneDust.spawn(get_parent(), fist, 14, 22.0, 95.0, 1.4)


## Small puffs drifting off the back of the body while it walks.
func _trail_dust() -> void:
	var side: float = randf_range(-80.0, 80.0)
	var back := _titan_point(Vector2(-100.0, side))
	StoneDust.spawn(get_parent(), back, 3, 15.0, 40.0, 1.4, -Vector2.RIGHT.rotated(_facing), 0.7)
