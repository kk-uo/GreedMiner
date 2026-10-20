class_name FrozenEnemy
extends RangedEnemy

## Frozen units share weather behaviour and the snow-monster art (SnowVisual)
## while retaining their individual, Inspector-editable combat statistics in
## their scenes.
const SnowVisual := preload("res://Scripts/Enemies/SnowVisual.gd")
@export var receives_blizzard_bonus: bool = true
@export var summon_blizzard_after: float = -1.0
@export var blizzard_linger: float = 2.0
@export var entrance_duration: float = 0.0
@export var freeze_windup: float = 5.0
## Ship freeze from the boss snowball; the player clicks to break out early
## (WeatherManager.FREEZE_CLICK_REDUCTION per click).
@export var freeze_duration: float = 10.0
@export var cry_duration: float = 3.0
## The boss gains no speed after crying (only damage reduction).
@export var enrage_speed_bonus: float = 0.0
@export var enrage_damage_reduction_bonus: float = 0.4
## Sled: attempt its first normal attack as soon as it reaches attack range.
@export var attack_immediately_on_contact: bool = false
@export var split_scene: PackedScene
@export var split_distance: float = 30.0
var _weather: WeatherManager
var _battle: Node
var _initial_speed: float
var _elapsed: float = 0.0
var _has_weather: bool = false
var _snowball_started: bool = false
var _snowball_time: float = -1.0
var _cry_time: float = -1.0
var _enraged: bool = false
var _entrance_left: float = 0.0
const SnowImpact := preload("res://Scripts/VFX/SnowImpact.gd")
## Presentation only: animation clock and the attack pose timer.
var _anim_time: float = 0.0
var _attack_pose_time: float = 0.0
var _throw_pose_time: float = 0.0
var _rage_age: float = -1.0
const WALK_CYCLES_PER_SECOND: float = 1.4
const THROW_POSE_TIME: float = 0.5
## Distance (px) from the boss at which the snowball aim line starts.
const AIM_LINE_START: float = 70.0

func _ready() -> void:
	super()
	_initial_speed = move_speed
	_battle = get_tree().current_scene
	if _battle != null:
		_weather = _battle.get_node_or_null("WeatherManager") as WeatherManager
	if _weather != null:
		_weather.weather_changed.connect(_on_weather_changed)
		_on_weather_changed(_weather.current_weather)
	if enemy_tier == EnemyTier.BOSS and entrance_duration > 0.0:
		_entrance_left = entrance_duration
		if _weather != null:
			_weather.add_source(get_instance_id(), WeatherManager.Weather.BLIZZARD_BOSS)
			_weather.start_entrance_shake(entrance_duration)
		health_changed.connect(_on_boss_health_changed)

func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	queue_redraw()
	_anim_time += delta
	_attack_pose_time = maxf(_attack_pose_time - delta, 0.0)
	_throw_pose_time = maxf(_throw_pose_time - delta, 0.0)
	if _enraged:
		_rage_age = 0.0 if _rage_age < 0.0 else _rage_age + delta
	_elapsed += delta
	if _entrance_left > 0.0:
		# Presentation: face the ship while bursting out of the snow.
		var aim := _ship_center()
		if aim != global_position:
			_facing = (aim - global_position).angle()
		_entrance_left = maxf(0.0, _entrance_left - delta)
		_stop_attacking()
		return
	if summon_blizzard_after >= 0.0 and not _has_weather and _elapsed >= summon_blizzard_after:
		_has_weather = true
		if _weather != null:
			_weather.add_source(get_instance_id(), WeatherManager.Weather.BLIZZARD_NORMAL)
	# After summoning, the wizard keeps advancing and attacking like any
	# ranged enemy (it no longer stands where it cast).
	if _snowball_time >= 0.0:
		_snowball_time -= delta
		if _snowball_time <= 0.0:
			_snowball_time = -1.0
			_launch_freezing_snowball()
			_throw_pose_time = THROW_POSE_TIME
	if enemy_tier == EnemyTier.BOSS and not _enraged:
		if _cry_time >= 0.0:
			_stop_attacking()
			_cry_time -= delta
			if _cry_time <= 0.0:
				_enraged = true
				damage_reduction = clampf(damage_reduction + enrage_damage_reduction_bonus, 0.0, 1.0)
				_apply_speed()
			return
	super(delta)

## Called once by WaveManager after final-wave spawn and death-split tracking.
func begin_final_enrage() -> void:
	if not _enraged and _cry_time < 0.0 and not _is_dying:
		_cry_time = cry_duration

## The special snowball uses the existing hostile projectile collision path.
func _launch_freezing_snowball() -> void:
	if not is_instance_valid(target_ship) or projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as HostileProjectile
	if projectile == null:
		return
	projectile.set("freeze_duration", freeze_duration)
	projectile.target_ship = target_ship as Ship
	# The special attack applies the specified freeze, not an extra damage hit.
	projectile.damage = 0.0
	projectile.speed = projectile_speed
	projectile.direction = global_position.direction_to(target_ship.to_global(Ship.SHIP_SIZE * 0.5))
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position

func _on_weather_changed(_value: int) -> void:
	_apply_speed()

func _apply_speed() -> void:
	move_speed = _initial_speed + (enrage_speed_bonus if _enraged else 0.0)
	if receives_blizzard_bonus and _weather != null:
		move_speed += _weather.speed_bonus()

func _on_boss_health_changed(current: float, maximum: float) -> void:
	if not _snowball_started and current > 0.0 and current <= maximum * 0.5:
		_snowball_started = true
		_snowball_time = freeze_windup

func _perform_attack(ship: Ship) -> void:
	if attack_type == AttackType.RANGED:
		super(ship)
	else:
		ship.take_damage(attack_damage)

## The sled attacks immediately on entering range, then uses its normal timer.
func _start_attacking() -> void:
	var starting := not _is_attacking
	super()
	if starting and attack_immediately_on_contact and _is_attacking:
		_on_attack_timer_timeout()

func _perform_death_effect() -> void:
	if split_scene == null or get_parent() == null:
		return
	var center := global_position
	# A visual-only snow and wood burst; it never applies damage.
	var impact := SnowImpact.new()
	impact.wood = true
	impact.position = get_parent().to_local(center) if get_parent() is Node2D else center
	get_parent().call_deferred("add_child", impact)
	var battlefield := _battle.get_node_or_null("Battlefield") as Battlefield if is_instance_valid(_battle) else null
	if battlefield != null:
		# Move the entire formation inward as a block so its members do not
		# collapse onto one another when a sled dies at a map edge.
		var bounds := battlefield.get_world_bounds().grow(-(split_distance + 12.0))
		center.x = clampf(center.x, bounds.position.x, bounds.end.x)
		center.y = clampf(center.y, bounds.position.y, bounds.end.y)
	for offset in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var child := split_scene.instantiate() as BasicEnemy
		if child != null:
			child.target_ship = target_ship
			child.position = get_parent().to_local(center + offset * split_distance)
			get_parent().call_deferred("add_child", child)

func _die() -> void:
	if not _is_dying and _weather != null:
		if _has_weather:
			_weather.remove_source_after(get_instance_id(), blizzard_linger)
		elif enemy_tier == EnemyTier.BOSS:
			_weather.remove_source(get_instance_id())
	super()

func _exit_tree() -> void:
	# Normal death owns its delayed wizard cleanup; non-death removal does not.
	if not _is_dying and is_instance_valid(_weather):
		_weather.remove_source(get_instance_id())

func _on_attack_timer_timeout() -> void:
	super()
	if _is_attacking:
		_attack_pose_time = DemonVisual.ATTACK_POSE_TIME


func _walk_step() -> float:
	return 0.0 if _is_attacking else sin(_anim_time * TAU * WALK_CYCLES_PER_SECOND)


## Which SnowVisual body this unit uses.
func _visual_kind() -> StringName:
	match enemy_id:
		&"big_snow_monster":
			return &"big"
		&"sled_car_snow_monster":
			return &"sled"
		&"snow_monster_wizard":
			return &"wizard"
		&"mega_monster":
			return &"mega"
	return &"snow"


func _get_visual_radius() -> float:
	match _visual_kind():
		&"sled":
			return 34.0
		&"mega":
			return 52.0
		&"big":
			return 27.0
	return get_collision_radius() + 2.0


func _draw() -> void:
	var cast := DemonVisual.attack_amount(_attack_pose_time)
	var fx := {}
	if _entrance_left > 0.0 and entrance_duration > 0.0:
		fx["emerge"] = 1.0 - _entrance_left / entrance_duration
	var roll := -1.0
	if _snowball_time >= 0.0:
		roll = 1.0 - clampf(_snowball_time / maxf(freeze_windup, 0.01), 0.0, 1.0)
		fx["roll"] = roll
	if _throw_pose_time > 0.0:
		fx["throw"] = sin(PI * (1.0 - _throw_pose_time / THROW_POSE_TIME))
	if _cry_time >= 0.0:
		fx["sit"] = 1.0 - clampf(_cry_time / maxf(cry_duration, 0.01), 0.0, 1.0)
	if _rage_age >= 0.0:
		fx["rage_age"] = _rage_age
	SnowVisual.draw(self, _visual_kind(), _facing, _walk_step(), cast, _anim_time, _is_flashing(),
			_enraged, _cry_time >= 0.0, fx)
	if roll > 0.55:
		_draw_snowball_aim(smoothstep(0.55, 0.75, roll))


## Telegraph for the freezing snowball: a dashed line to the ship and a
## spinning frost reticle on it.
func _draw_snowball_aim(strength: float) -> void:
	var target := _ship_center()
	if target == global_position:
		return
	var local_target := to_local(target)
	var dir := local_target.normalized()
	var blink := 0.65 + 0.35 * sin(_anim_time * 10.0)
	var color := Color(SnowVisual.CRYSTAL[1], 0.9 * strength * blink)
	draw_dashed_line(dir * AIM_LINE_START, local_target - dir * 30.0, color, 4.0, 14.0)
	var spin := _anim_time * 2.0
	draw_arc(local_target, 26.0, 0.0, TAU, 40, color, 2.5)
	for index in range(4):
		var a := spin + TAU * float(index) / 4.0
		draw_line(local_target + Vector2(cos(a), sin(a)) * 18.0, local_target + Vector2(cos(a), sin(a)) * 34.0, color, 3.0)


func _ship_center() -> Vector2:
	if is_instance_valid(target_ship):
		return (target_ship as Node2D).to_global(Ship.SHIP_SIZE * 0.5)
	return global_position


## Presentation: snow monsters burst with green blood, fur and ice bits.
const YETI_GORE := preload("res://Scripts/VFX/GoblinGore.gd")
const DROPPED_GEAR := preload("res://Scripts/VFX/DroppedShield.gd")

func _spawn_death_visual(death_position: Vector2) -> void:
	# The sled keeps its own snow-and-wood burst (spawned with the riders in
	# _perform_death_effect); no gore for it.
	if _visual_kind() == &"sled":
		return
	var size := clampf(_get_visual_radius() / 12.0, 1.0, 3.0)
	YETI_GORE.spawn(get_parent(), death_position, size, &"yeti")
	# The Big Snow Monster drops its ice club.
	if _visual_kind() == &"big":
		DROPPED_GEAR.spawn(get_parent(), death_position, _facing, &"ice_club")
