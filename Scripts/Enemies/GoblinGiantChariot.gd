class_name GoblinGiantChariot
extends BasicEnemy

## Verdant Planet boss: two war boars pulling a goblin catapult wagon.
## The rig is long, so contact, throw landing and the berserk trigger are all
## measured from its FRONT (the boars' snouts, FRONT_REACH ahead of the centre),
## not from the node origin.
##
## Stage A — ADVANCE: rolls slowly toward the ship. Every throw_cooldown
## seconds it stops and throws goblins:
##   THROWING (throw_animation_duration s, stationary): winds up, and at
##     throw_release_fraction of the animation hurls throw_goblin_count goblins
##     plus throw_elite_count Elite Goblins at once. They land throw_distance
##     ahead of its front (shorter when the ship is closer, so they never land
##     on the hull) (goblins in a block, elites leading in front of it)
##     and stay rooted for thrown_goblin_root_duration after landing.
##   PAUSED (post_throw_pause s, stationary), then the cooldown restarts.
## Stage B — BERSERK: once its distance to the ship boundary is within
## berserk_trigger_distance it never throws again and moves at
## move_speed × berserk_speed_multiplier (entered exactly once).
## Death: death_spawn_count goblins burst out in a ring around the wreck.
## Distances use the game's world units (same as attack_range).

signal throw_started
signal goblins_thrown(goblins: Array[Goblin])
signal berserk_started

enum Stage { ADVANCE, THROWING, PAUSED, BERSERK }

@export_group("Throw goblins")
## Scene of the thrown (and death-spawned) goblins.
@export var goblin_scene: PackedScene
## Scene of the Elite Goblins thrown together with the goblins.
@export var elite_goblin_scene: PackedScene
## Elite Goblins thrown per throw (land in front of the goblin block).
@export_range(0, 5, 1) var throw_elite_count: int = 1
@export_range(1, 20, 1) var throw_goblin_count: int = 10
## Landing distance in front of the chariot (measured from the boars' snouts).
@export var throw_distance: float = 250.0
## Seconds the thrown goblins stay in place after landing.
@export var thrown_goblin_root_duration: float = 2.0
## Built-in cooldown between throws (counted after the pause ends).
@export var throw_cooldown: float = 8.0
## Delay before the very first throw after the boss appears.
@export var first_throw_delay: float = 4.0
## Length of the throw animation; the chariot does not move meanwhile.
@export var throw_animation_duration: float = 4.0
## Point in the animation (0..1) where all goblins are released at once.
@export_range(0.05, 1.0, 0.01) var throw_release_fraction: float = 0.75
## Stationary pause after the throw animation before rolling on.
@export var post_throw_pause: float = 2.0
## Seconds a thrown goblin is in the air (part of the throw animation).
@export var throw_flight_time: float = 0.55
## Spacing of the landing block formation.
@export var thrown_formation_spacing: float = 26.0

@export_group("Berserk")
@export var berserk_trigger_distance: float = 200.0
@export var berserk_speed_multiplier: float = 2.0

@export_group("Death")
@export_range(0, 40, 1) var death_spawn_count: int = 10
@export var death_spawn_radius: float = 140.0

## Distance from the node origin to the boars' snouts.
const FRONT_REACH: float = GoblinVisual.CHARIOT_FRONT_REACH
const WRECK_SCRIPT := preload("res://Scripts/VFX/ChariotWreck.gd")
const VISUAL_RADIUS: float = 115.0
## Hit / target body: a capsule along the rig from the wagon's tail to the
## boars' snouts (distances from the node origin along the facing).
## Thrown units keep at least this much room between the landing block's
## centre and the hull (block depth + elites + margin), shrinking the throw
## when the chariot is close; MIN_THROW_DISTANCE is the shortest throw.
const THROW_HULL_CLEARANCE: float = 110.0
const MIN_THROW_DISTANCE: float = 40.0
const BODY_REAR: float = 165.0
const BODY_RADIUS: float = 62.0

var stage: Stage = Stage.ADVANCE
var _stage_time: float = 0.0
var _cooldown_left: float = 0.0
var _released: bool = false
var _base_speed: float = 0.0
var _berserk: bool = false
var throws_done: int = 0
## Elite Goblins of the most recent throw (for tests / effects).
var thrown_elites: Array[EliteGoblin] = []
## Seconds since the last release (drives the wagon kicking up its front).
var _since_release: float = 99.0

## Presentation clocks.
var _anim_time: float = 0.0
var _roll: float = 0.0


func _ready() -> void:
	super()
	_base_speed = move_speed
	_cooldown_left = first_throw_delay


func is_berserk() -> bool:
	return _berserk


## 0..1 progress through the throw animation (0 outside THROWING).
func get_throw_progress() -> float:
	if stage != Stage.THROWING:
		return 0.0
	return clampf(_stage_time / maxf(throw_animation_duration, 0.01), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	_align_body()
	# Entering the 200px zone cancels every non-berserk state immediately,
	# including a throw wind-up or post-throw pause. No further goblins release.
	if not _berserk and _distance_to_ship() <= berserk_trigger_distance:
		_enter_berserk()
	match stage:
		Stage.ADVANCE:
			_cooldown_left -= delta
			if _cooldown_left <= 0.0:
				_start_throw()
				return
		Stage.THROWING:
			_stage_time += delta
			_hold_position()
			if not _released and _stage_time >= throw_animation_duration * throw_release_fraction:
				_release_goblins()
			if _stage_time >= throw_animation_duration:
				if not _released:
					_release_goblins()
				stage = Stage.PAUSED
				_stage_time = 0.0
			return
		Stage.PAUSED:
			_stage_time += delta
			_hold_position()
			if _stage_time >= post_throw_pause:
				stage = Stage.ADVANCE
				_stage_time = 0.0
				_cooldown_left = throw_cooldown
			return
	_advance(delta)


## Like BasicEnemy movement, but the rig stops when its front (not its centre)
## reaches attack_range from the hull.
func _advance(delta: float) -> void:
	if not is_instance_valid(target_ship) or not target_ship is Ship:
		_stop_attacking()
		return
	var ship := target_ship as Ship
	if ship.current_hp <= 0.0:
		_stop_attacking()
		return
	var closest := _get_nearest_ship_boundary_world(ship, global_position)
	var to_ship := closest - global_position
	if to_ship.length_squared() > 0.01:
		_facing = to_ship.angle()
	var gap: float = to_ship.length() - FRONT_REACH
	if gap <= attack_range:
		_start_attacking()
		return
	_stop_attacking()
	var step: float = minf(move_speed * delta, gap - attack_range)
	global_position += to_ship.normalized() * step
	_roll += step


## Distance from the chariot's front (boar snouts) to the ship hull.
func _distance_to_ship() -> float:
	if not is_instance_valid(target_ship) or not target_ship is Ship:
		return INF
	return global_position.distance_to(_get_nearest_ship_boundary_world(target_ship as Ship, global_position)) - FRONT_REACH


func _forward() -> Vector2:
	if is_instance_valid(target_ship) and target_ship is Ship:
		var to_ship := _get_nearest_ship_boundary_world(target_ship as Ship, global_position) - global_position
		if to_ship.length_squared() > 0.01:
			return to_ship.normalized()
	return Vector2.RIGHT.rotated(_facing)


func _hold_position() -> void:
	_stop_attacking()
	_facing = _forward().angle()


func _start_throw() -> void:
	stage = Stage.THROWING
	_stage_time = 0.0
	_released = false
	throw_started.emit()


func _enter_berserk() -> void:
	if _berserk:
		return
	_berserk = true
	stage = Stage.BERSERK
	move_speed = _base_speed * berserk_speed_multiplier
	berserk_started.emit()


## Hurls throw_goblin_count goblins at once into a block ahead of the chariot.
func _release_goblins() -> void:
	thrown_elites.clear()
	_released = true
	_since_release = 0.0
	throws_done += 1
	var thrown: Array[Goblin] = []
	var parent := get_parent()
	if goblin_scene == null or parent == null:
		push_warning("Goblin Giant Chariot: goblin scene is missing.")
		goblins_thrown.emit(thrown)
		return
	var forward := _forward()
	# Never land on (or past) the ship: keep the whole block, elites included,
	# outside the hull when the chariot throws from close range.
	var ahead: float = clampf(_distance_to_ship() - THROW_HULL_CLEARANCE, MIN_THROW_DISTANCE, throw_distance)
	var landing_center := global_position + forward * (FRONT_REACH + ahead)
	var launch := global_position - forward * 72.0
	var slots := SpawnFormation.place(landing_center, forward, throw_goblin_count, thrown_formation_spacing, false)
	var front_edge: float = 0.0
	for slot in slots:
		front_edge = maxf(front_edge, ((slot["position"] as Vector2) - landing_center).dot(forward))
		var goblin := goblin_scene.instantiate() as Goblin
		if goblin == null:
			push_error("Goblin Giant Chariot: goblin_scene must use Goblin.gd.")
			continue
		goblin.target_ship = target_ship
		parent.add_child(goblin)
		goblin.global_position = slot["position"]
		goblin.throw_to(launch, throw_flight_time, thrown_goblin_root_duration)
		thrown.append(goblin)
	# Elites lead the block: one row in front of it, spread sideways.
	if elite_goblin_scene != null:
		var side := Vector2(-forward.y, forward.x)
		for index in range(throw_elite_count):
			var elite := elite_goblin_scene.instantiate() as EliteGoblin
			if elite == null:
				push_error("Goblin Giant Chariot: elite_goblin_scene must use EliteGoblin.gd.")
				continue
			elite.target_ship = target_ship
			parent.add_child(elite)
			var lateral: float = (float(index) - float(throw_elite_count - 1) * 0.5) * 46.0
			elite.global_position = landing_center + forward * (front_edge + 32.0) + side * lateral
			elite.throw_to(launch, throw_flight_time, thrown_goblin_root_duration)
			thrown_elites.append(elite)
	goblins_thrown.emit(thrown)


## Ten goblins burst out of the wreck, evenly spread, using normal AI at once.
func _perform_death_effect() -> void:
	if not ArtifactManager.owns_artifact(&"goblin_horn"):
		ArtifactManager.grant_artifact(&"goblin_horn")
	var parent := get_parent()
	if parent == null:
		return
	var death_position := global_position
	# Defeat animation: wagon breaks, crew + boars flee, a white flag rises.
	var wreck: Node2D = WRECK_SCRIPT.new()
	wreck.setup(_facing)
	wreck.position = parent.to_local(death_position)
	parent.call_deferred("add_child", wreck)
	if goblin_scene == null or death_spawn_count <= 0:
		return
	for index in range(death_spawn_count):
		var goblin := goblin_scene.instantiate() as BasicEnemy
		if goblin == null:
			continue
		var angle: float = _facing + TAU * float(index) / float(death_spawn_count)
		goblin.target_ship = target_ship
		goblin.position = parent.to_local(death_position + Vector2.RIGHT.rotated(angle) * death_spawn_radius)
		# Deferred: death can happen inside a physics callback.
		parent.call_deferred("add_child", goblin)


## Nearest point on the rig's centre line (tail → snouts) to from_world, so
## turrets lock on as soon as the boars' heads come into range and aim there.
func get_target_point(from_world: Vector2) -> Vector2:
	var forward := Vector2.RIGHT.rotated(_facing)
	var tail := global_position - forward * (BODY_REAR - BODY_RADIUS)
	var snout := global_position + forward * (FRONT_REACH - 15.0)
	var along: float = clampf((from_world - tail).dot(forward), 0.0, tail.distance_to(snout))
	return tail + forward * along


## Keeps the capsule hitbox lined up with the drawn rig.
func _align_body() -> void:
	var body := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body == null:
		return
	body.rotation = _facing - PI * 0.5
	body.position = Vector2.RIGHT.rotated(_facing) * ((FRONT_REACH - BODY_REAR) * 0.5)


func _get_visual_radius() -> float:
	return VISUAL_RADIUS


func _process(delta: float) -> void:
	_anim_time += delta
	_since_release += delta
	super(delta)


## Front of the wagon kicks up when the arm fires, then rocks back down.
func get_tilt() -> float:
	var t: float = _since_release
	if t < 0.12:
		return t / 0.12
	var settle: float = exp(-(t - 0.12) * 3.0) * cos((t - 0.12) * 8.0)
	return clampf(settle, -0.3, 1.0) if t < 2.0 else 0.0


func _draw() -> void:
	var release := 0.0
	if stage == Stage.THROWING and _released:
		release = clampf((_stage_time - throw_animation_duration * throw_release_fraction) / 0.35, 0.0, 1.0)
	elif stage == Stage.PAUSED:
		release = 1.0
	GoblinVisual.draw_chariot(self, _facing, _roll, get_throw_progress(), release, _berserk, _anim_time, _is_flashing(), get_tilt())
