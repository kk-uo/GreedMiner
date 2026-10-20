class_name DemonLord
extends BasicEnemy

## Volcanic Planet boss. Gameplay remains live during both click challenges;
## BattleMain only gives this boss priority inside the currently reserved
## world-space QTE region.

signal boss_state_changed(state: BossState)
signal boss_qte_started(special: bool, duration: float)
signal boss_qte_progress(current_clicks: int, required_clicks: int)
signal boss_qte_finished(succeeded: bool, special: bool)
signal summons_spawned(summons: Array[BasicEnemy])
signal laser_fired(damage: float)

enum BossState {
	NORMAL,
	SUMMONING,
	NORMAL_CHARGING,
	TELEPORTING,
	SPECIAL_CHARGING,
	FIRING_LASER,
	RECOVERY,
	DEAD,
}

enum BodyPart {
	HEAD,
	LEFT_HAND,
	RIGHT_HAND,
	LEFT_FOOT,
	RIGHT_FOOT,
}

const BODY_PARTS: Array[BodyPart] = [
	BodyPart.HEAD,
	BodyPart.LEFT_HAND,
	BodyPart.RIGHT_HAND,
	BodyPart.LEFT_FOOT,
	BodyPart.RIGHT_FOOT,
]
const DemonLordVisualScript := preload("res://Scripts/Enemies/DemonLordVisual.gd")
const QteStyleScript := preload("res://Scripts/UI/QteStyle.gd")

## Clickable weak points (pixels, facing +X), matching DemonLordVisual's
## head, hands and hooves.
const BODY_PART_OFFSETS: Dictionary = {
	BodyPart.HEAD: DemonLordVisualScript.HEAD * DemonLordVisualScript.MODEL_SCALE,
	BodyPart.LEFT_HAND: Vector2(DemonLordVisualScript.HAND.x, -DemonLordVisualScript.HAND.y) * DemonLordVisualScript.MODEL_SCALE,
	BodyPart.RIGHT_HAND: DemonLordVisualScript.HAND * DemonLordVisualScript.MODEL_SCALE,
	BodyPart.LEFT_FOOT: Vector2(DemonLordVisualScript.HOOF_AT.x, -DemonLordVisualScript.HOOF_AT.y) * DemonLordVisualScript.MODEL_SCALE,
	BodyPart.RIGHT_FOOT: DemonLordVisualScript.HOOF_AT * DemonLordVisualScript.MODEL_SCALE,
}
## Pentagon drawing order of the weak points.
const PENTAGON_ORDER: Array[BodyPart] = [
	BodyPart.HEAD, BodyPart.RIGHT_HAND, BodyPart.RIGHT_FOOT, BodyPart.LEFT_FOOT, BodyPart.LEFT_HAND,
]

## Drawn radius of the white target during the normal charge (the click area
## stays normal_qte_radius, a little more forgiving than what is shown).
const NORMAL_TARGET_RADIUS: float = 60.0
const TELEPORT_PILLAR_TIME: float = 0.8
const SUMMON_FADE_TIME: float = 0.6

@export_group("Summoning")
@export var hellhunter_scene: PackedScene
@export_range(0.1, 120.0, 0.1) var summoning_cooldown: float = 12.0
@export_range(0.0, 20.0, 0.1) var summoning_circle_delay: float = 1.5
@export_range(0, 100, 1) var maximum_active_summons: int = 0
@export_range(1, 20, 1) var summon_count: int = 6
@export_range(1.0, 200.0, 1.0) var summoning_circle_distance: float = 50.0
@export_range(20.0, 100.0, 1.0) var summon_formation_spacing: float = 32.0

@export_group("Normal Laser QTE")
@export_range(0.1, 120.0, 0.1) var normal_laser_interval: float = 30.0
@export_range(0.1, 20.0, 0.1) var normal_charge_duration: float = 4.0
@export_range(1, 100, 1) var normal_required_clicks: int = 10
## 1.0: the Demon Lord is invulnerable while charging a laser (take_damage
## also ignores armour-piercing damage then).
@export_range(0.0, 1.0, 0.01) var charging_damage_reduction: float = 1.0
@export_range(0.0, 1000.0, 1.0) var laser_damage: float = 50.0
@export_range(0.0, 20.0, 0.1) var recovery_duration: float = 2.0
@export_range(0.0, 1.0, 0.01) var minimum_valid_click_interval: float = 0.1
@export_range(20.0, 200.0, 1.0) var normal_qte_radius: float = 87.0

@export_group("Special QTE")
@export_range(0.1, 20.0, 0.1) var special_charge_duration: float = 5.0
@export_range(1, 20, 1) var special_clicks_per_part: int = 3
@export_range(4.0, 50.0, 1.0) var body_part_hit_radius: float = 22.0
@export_range(20.0, 200.0, 1.0) var special_reserved_radius: float = 108.0

@export_group("Enrage")
## Move speed multiplier once the half-health teleport has happened.
@export_range(1.0, 5.0, 0.05) var enrage_speed_multiplier: float = 1.5

@export_group("Laser Presentation")
@export_range(0.01, 2.0, 0.01) var laser_visual_duration: float = 0.6

var boss_state: BossState = BossState.NORMAL
var normal_click_count: int = 0
var special_part_clicks: Dictionary = {}
var special_phase_triggered: bool = false
var teleport_count: int = 0
var lasers_fired_count: int = 0
var summons_created_count: int = 0

var _state_time_left: float = 0.0
var _state_elapsed: float = 0.0
var _normal_laser_cooldown_left: float = 0.0
var _summoning_cooldown_left: float = 0.0
var _base_damage_reduction: float = 0.0
var _last_valid_click_time: float = -INF
var _summoning_circle_world: Vector2 = Vector2.ZERO
var _summons: Array[BasicEnemy] = []
var _laser_end_local: Vector2 = Vector2.ZERO
var _laser_visual_left: float = 0.0
## Presentation: seconds since a hit rippled the invulnerability ward.
var _ward_hit_age: float = 1.0
var _anim_time: float = 0.0
var enraged: bool = false

# Presentation only.
var _show_click_label: bool = false
var _qte_pop_age: float = -1.0
var _part_pop_age: Dictionary = {}
var _recovery_from_break: bool = false
var _teleport_from_world: Vector2 = Vector2.ZERO
var _teleport_age: float = -1.0
var _summon_fade_age: float = -1.0


func _ready() -> void:
	super()
	_base_damage_reduction = damage_reduction
	_normal_laser_cooldown_left = normal_laser_interval
	_summoning_cooldown_left = summoning_cooldown
	add_to_group("boss_qte_targets")
	for part in BODY_PARTS:
		special_part_clicks[part] = 0


func _physics_process(delta: float) -> void:
	if _is_dying or boss_state == BossState.DEAD:
		return
	_state_elapsed += delta
	_laser_visual_left = maxf(_laser_visual_left - delta, 0.0)
	_cleanup_summons()
	match boss_state:
		BossState.NORMAL:
			_normal_laser_cooldown_left -= delta
			_summoning_cooldown_left -= delta
			if _normal_laser_cooldown_left <= 0.0:
				start_normal_charge()
			elif _summoning_cooldown_left <= 0.0 and _can_start_summoning():
				_start_summoning()
			else:
				super(delta)
		BossState.SUMMONING:
			_normal_laser_cooldown_left -= delta
			_hold_for_ability()
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				_spawn_hellhunters()
				_summon_fade_age = 0.0
				_summoning_cooldown_left = summoning_cooldown
				_enter_state(BossState.NORMAL)
				if _normal_laser_cooldown_left <= 0.0:
					start_normal_charge()
		BossState.NORMAL_CHARGING:
			_hold_for_ability()
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				_fail_qte(false)
		BossState.TELEPORTING:
			_hold_for_ability()
			_start_special_charge()
		BossState.SPECIAL_CHARGING:
			_hold_for_ability()
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				_fail_qte(true)
		BossState.FIRING_LASER:
			_hold_for_ability()
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				_enter_recovery()
		BossState.RECOVERY:
			_hold_for_ability()
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				_normal_laser_cooldown_left = normal_laser_interval
				_enter_state(BossState.NORMAL)


func _process(delta: float) -> void:
	_anim_time += delta
	_ward_hit_age += delta
	if _qte_pop_age >= 0.0:
		_qte_pop_age += delta
	for part in _part_pop_age.keys():
		_part_pop_age[part] = float(_part_pop_age[part]) + delta
	if _teleport_age >= 0.0:
		_teleport_age += delta
		if _teleport_age > TELEPORT_PILLAR_TIME:
			_teleport_age = -1.0
	if _summon_fade_age >= 0.0:
		_summon_fade_age += delta
		if _summon_fade_age > SUMMON_FADE_TIME:
			_summon_fade_age = -1.0
	super(delta)


func take_damage(amount: float, ignore_damage_reduction: bool = false, count_for_artifact: bool = true, source_weapon: WeaponModule = null) -> void:
	if amount <= 0.0 or _is_dying:
		return
	# Invulnerable while charging either laser: hits just ripple the ward.
	if is_invulnerable():
		_ward_hit_age = 0.0
		return
	super(amount, ignore_damage_reduction, count_for_artifact, source_weapon)
	if (
		not _is_dying
		and not special_phase_triggered
		and get_current_health() <= max_health * 0.5
	):
		special_phase_triggered = true
		_begin_half_health_phase()


## True while the Demon Lord charges a laser (normal or special): no damage.
func is_invulnerable() -> bool:
	return boss_state == BossState.NORMAL_CHARGING or boss_state == BossState.SPECIAL_CHARGING


## Begins the repeatable ten-click normal laser charge.
func start_normal_charge() -> bool:
	if boss_state != BossState.NORMAL or _is_dying:
		return false
	_stop_attacking()
	normal_click_count = 0
	_last_valid_click_time = -INF
	_show_click_label = QteStyleScript.claim_click_hint()
	damage_reduction = charging_damage_reduction
	_state_time_left = normal_charge_duration
	_enter_state(BossState.NORMAL_CHARGING)
	boss_qte_started.emit(false, normal_charge_duration)
	boss_qte_progress.emit(0, normal_required_clicks)
	return true


## Begins the one-time five-part challenge. Tests may disable teleport when they
## only need to inspect counters; gameplay always enters through half health.
func start_special_charge(perform_teleport: bool = true) -> bool:
	if _is_dying or boss_state == BossState.DEAD or special_phase_triggered:
		return false
	if perform_teleport:
		_teleport_opposite_ship()
		_enter_enrage()
	special_phase_triggered = true
	_start_special_charge()
	return true


func _start_special_charge() -> void:
	_stop_attacking()
	for part in BODY_PARTS:
		special_part_clicks[part] = 0
	_part_pop_age.clear()
	_last_valid_click_time = -INF
	_show_click_label = QteStyleScript.claim_click_hint()
	damage_reduction = charging_damage_reduction
	_state_time_left = special_charge_duration
	_enter_state(BossState.SPECIAL_CHARGING)
	boss_qte_started.emit(true, special_charge_duration)
	boss_qte_progress.emit(0, BODY_PARTS.size() * special_clicks_per_part)


func _begin_half_health_phase() -> void:
	_cancel_active_ability()
	_enter_state(BossState.TELEPORTING)
	_teleport_opposite_ship()
	_enter_enrage()


## Half-health enrage: faster movement (and a burning aura, see _draw).
func _enter_enrage() -> void:
	if enraged:
		return
	enraged = true
	move_speed *= enrage_speed_multiplier


func _start_summoning() -> void:
	_stop_attacking()
	var direction := Vector2.RIGHT
	if is_instance_valid(target_ship) and target_ship is Ship:
		var ship_center := (target_ship as Ship).to_global(Ship.SHIP_SIZE * 0.5)
		direction = global_position.direction_to(ship_center)
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
	_summoning_circle_world = global_position + direction.rotated(PI * 0.5) * summoning_circle_distance
	_state_time_left = summoning_circle_delay
	_enter_state(BossState.SUMMONING)


func force_start_summoning() -> bool:
	if boss_state != BossState.NORMAL or not _can_start_summoning():
		return false
	_start_summoning()
	return true


func _can_start_summoning() -> bool:
	if hellhunter_scene == null:
		return false
	if maximum_active_summons <= 0:
		return true
	return get_active_summon_count() + summon_count <= maximum_active_summons


func _spawn_hellhunters() -> void:
	if hellhunter_scene == null or not is_instance_valid(target_ship):
		return
	var parent := get_parent()
	if parent == null:
		return
	var spawned: Array[BasicEnemy] = []
	var used_positions: Array[Vector2] = []
	for index in range(summon_count):
		var angle := TAU * float(index) / float(maxi(summon_count, 1))
		var desired := _summoning_circle_world + Vector2.RIGHT.rotated(angle) * summon_formation_spacing
		var position := _find_valid_nearby_position(desired, 12.0, used_positions)
		var summon := hellhunter_scene.instantiate() as BasicEnemy
		if summon == null:
			continue
		summon.target_ship = target_ship
		summon.set_meta("demon_lord_summon", true)
		summon.set_meta("demon_lord_owner_id", get_instance_id())
		summon.add_to_group("boss_summons")
		parent.add_child(summon)
		summon.global_position = position
		used_positions.append(position)
		_summons.append(summon)
		spawned.append(summon)
	summons_created_count += spawned.size()
	summons_spawned.emit(spawned)
	if spawned.size() != summon_count:
		push_error("DemonLord: spawned %d of %d Hellhunters." % [spawned.size(), summon_count])


func _find_valid_nearby_position(desired: Vector2, radius: float, used: Array[Vector2]) -> Vector2:
	var battlefield := _get_battlefield()
	var bounds := battlefield.get_world_bounds().grow(-radius - 4.0) if battlefield != null else Rect2(desired - Vector2(500.0, 500.0), Vector2(1000.0, 1000.0))
	for attempt in range(128):
		var ring := float(attempt / 12) * summon_formation_spacing * 0.55
		var candidate := desired + Vector2.RIGHT.rotated(float(attempt) * 2.399963) * ring
		candidate.x = clampf(candidate.x, bounds.position.x, bounds.end.x)
		candidate.y = clampf(candidate.y, bounds.position.y, bounds.end.y)
		if _is_valid_world_position(candidate, radius, used):
			return candidate
	push_warning("DemonLord: no ideal summon position found; using bounded fallback.")
	return Vector2(clampf(desired.x, bounds.position.x, bounds.end.x), clampf(desired.y, bounds.position.y, bounds.end.y))


func _is_valid_world_position(candidate: Vector2, radius: float, used: Array[Vector2] = []) -> bool:
	var battlefield := _get_battlefield()
	if battlefield != null:
		var bounds := battlefield.get_world_bounds().grow(-radius - 4.0)
		if not bounds.has_point(candidate) or not battlefield.is_area_free(candidate, radius):
			return false
	if is_instance_valid(target_ship) and target_ship is Ship:
		if (target_ship as Ship).get_distance_to_hull(candidate, radius) < 8.0:
			return false
	for occupied in used:
		if candidate.distance_to(occupied) < radius * 2.0 + 2.0:
			return false
	if not is_inside_tree():
		return true
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _teleport_opposite_ship() -> void:
	if not is_instance_valid(target_ship) or not target_ship is Ship:
		return
	var ship := target_ship as Ship
	var ship_center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	var original_offset := global_position - ship_center
	if original_offset.length_squared() <= 0.001:
		original_offset = Vector2.RIGHT * 300.0
	var intended_direction := -original_offset.normalized()
	var distance := original_offset.length()
	var desired := ship_center + intended_direction * distance
	var radius := get_collision_radius()
	var candidates: Array[Vector2] = [desired]
	for step in range(1, 17):
		var adjusted_distance := maxf(distance - float(step) * 24.0, radius + 120.0)
		var base := ship_center + intended_direction * adjusted_distance
		var tangent := Vector2(-intended_direction.y, intended_direction.x)
		candidates.append(base)
		candidates.append(base + tangent * float(step) * 12.0)
		candidates.append(base - tangent * float(step) * 12.0)
	for candidate in candidates:
		if _is_valid_world_position(candidate, radius):
			_teleport_from_world = global_position
			_teleport_age = 0.0
			global_position = candidate
			_facing = global_position.direction_to(ship_center).angle()
			teleport_count += 1
			return
	push_warning("DemonLord: could not find a valid opposite-side teleport destination.")


## Called from BattleMain._input before normal world/QTE unhandled input.
## Returns true for every click in the reserved region, including invalid or
## too-fast clicks, so an overlapping interaction can never double-activate.
func route_qte_click(world_position: Vector2) -> bool:
	if not is_boss_qte_active():
		return false
	var local := to_local(world_position)
	if boss_state == BossState.NORMAL_CHARGING:
		if local.length() > normal_qte_radius:
			return false
		_register_normal_click()
		return true
	if boss_state == BossState.SPECIAL_CHARGING:
		if local.length() > special_reserved_radius:
			return false
		var part := _find_body_part(local)
		if part >= 0:
			_register_special_click(part)
		return true
	return false


func _register_normal_click() -> bool:
	if _state_elapsed - _last_valid_click_time < minimum_valid_click_interval:
		return false
	_last_valid_click_time = _state_elapsed
	_qte_pop_age = 0.0
	normal_click_count += 1
	boss_qte_progress.emit(normal_click_count, normal_required_clicks)
	if normal_click_count >= normal_required_clicks:
		_succeed_qte(false)
	return true


func _register_special_click(part: BodyPart) -> bool:
	if _state_elapsed - _last_valid_click_time < minimum_valid_click_interval:
		return false
	if int(special_part_clicks.get(part, 0)) >= special_clicks_per_part:
		return false
	_last_valid_click_time = _state_elapsed
	special_part_clicks[part] = int(special_part_clicks.get(part, 0)) + 1
	if int(special_part_clicks[part]) >= special_clicks_per_part:
		_part_pop_age[part] = 0.0
	var total := get_special_total_clicks()
	boss_qte_progress.emit(total, BODY_PARTS.size() * special_clicks_per_part)
	if is_special_qte_complete():
		_succeed_qte(true)
	return true


func _find_body_part(local_position: Vector2) -> int:
	var best_part := -1
	var best_distance := INF
	for part in BODY_PARTS:
		var position := get_body_part_local_position(part)
		var distance := local_position.distance_to(position)
		if distance <= body_part_hit_radius and distance < best_distance:
			best_part = int(part)
			best_distance = distance
	return best_part


func get_body_part_local_position(part: BodyPart) -> Vector2:
	return (BODY_PART_OFFSETS.get(part, Vector2.ZERO) as Vector2).rotated(_facing)


func get_body_part_world_position(part: BodyPart) -> Vector2:
	return to_global(get_body_part_local_position(part))


func get_special_total_clicks() -> int:
	var total := 0
	for part in BODY_PARTS:
		total += int(special_part_clicks.get(part, 0))
	return total


func is_special_qte_complete() -> bool:
	for part in BODY_PARTS:
		if int(special_part_clicks.get(part, 0)) < special_clicks_per_part:
			return false
	return true


func is_boss_qte_active() -> bool:
	return boss_state in [BossState.NORMAL_CHARGING, BossState.SPECIAL_CHARGING]


func get_qte_time_left() -> float:
	return maxf(_state_time_left, 0.0) if is_boss_qte_active() else 0.0


func _succeed_qte(special: bool) -> void:
	damage_reduction = _base_damage_reduction
	_recovery_from_break = true
	boss_qte_finished.emit(true, special)
	_enter_recovery()


func _fail_qte(special: bool) -> void:
	damage_reduction = _base_damage_reduction
	boss_qte_finished.emit(false, special)
	_fire_laser()


func _fire_laser() -> void:
	_stop_attacking()
	_recovery_from_break = false
	lasers_fired_count += 1
	if is_instance_valid(target_ship) and target_ship is Ship:
		var ship := target_ship as Ship
		_laser_end_local = to_local(_get_nearest_ship_boundary_world(ship, global_position))
		_laser_visual_left = laser_visual_duration
		var receiver := ship.get_node_or_null("DamageArea") as ShipDamageArea
		if receiver != null:
			receiver.apply_damage(laser_damage)
		else:
			ship.take_damage(laser_damage)
	laser_fired.emit(laser_damage)
	_state_time_left = laser_visual_duration
	_enter_state(BossState.FIRING_LASER)


func _enter_recovery() -> void:
	_stop_attacking()
	damage_reduction = _base_damage_reduction
	_state_time_left = recovery_duration
	_enter_state(BossState.RECOVERY)


func _cancel_active_ability() -> void:
	if is_boss_qte_active():
		damage_reduction = _base_damage_reduction
	_stop_attacking()
	_state_time_left = 0.0


func _hold_for_ability() -> void:
	_stop_attacking()


func _enter_state(next_state: BossState) -> void:
	boss_state = next_state
	_state_elapsed = 0.0
	boss_state_changed.emit(boss_state)
	queue_redraw()


func _cleanup_summons() -> void:
	for index in range(_summons.size() - 1, -1, -1):
		if not is_instance_valid(_summons[index]) or _summons[index].is_dying():
			_summons.remove_at(index)


func get_active_summon_count() -> int:
	_cleanup_summons()
	return _summons.size()


func _get_battlefield() -> Battlefield:
	var parent := get_parent()
	return parent.get_parent().get_node_or_null("Battlefield") as Battlefield if parent != null and parent.get_parent() != null else null


func _perform_death_effect() -> void:
	_cleanup_qte_state()


func _cleanup_qte_state() -> void:
	damage_reduction = _base_damage_reduction
	boss_state = BossState.DEAD
	_state_time_left = 0.0
	remove_from_group("boss_qte_targets")
	queue_redraw()


func _exit_tree() -> void:
	_cleanup_qte_state()


func _get_visual_radius() -> float:
	return 66.0


func _draw() -> void:
	var flashing := _is_flashing()
	var gem := DemonLordVisualScript.gem_position(_facing)
	var charging := boss_state in [BossState.NORMAL_CHARGING, BossState.SPECIAL_CHARGING]
	var charge: float = 0.0
	if charging:
		var duration: float = normal_charge_duration if boss_state == BossState.NORMAL_CHARGING else special_charge_duration
		charge = clampf(1.0 - _state_time_left / maxf(duration, 0.01), 0.0, 1.0)
	elif boss_state == BossState.FIRING_LASER:
		charge = 1.0
	var step: float = 0.0
	if boss_state == BossState.NORMAL and not _is_attacking:
		step = sin(_anim_time * TAU * 0.6)
	var recoil: float = 0.0
	var recovery_k: float = 0.0
	if boss_state == BossState.RECOVERY:
		recovery_k = clampf(1.0 - _state_time_left / maxf(recovery_duration, 0.01), 0.0, 1.0)
		if _recovery_from_break:
			recoil = 10.0 * sin(PI * minf(recovery_k * 4.0, 1.0)) * (1.0 - recovery_k)

	if boss_state == BossState.SUMMONING:
		var k: float = clampf(1.0 - _state_time_left / maxf(summoning_circle_delay, 0.01), 0.0, 1.0)
		DemonLordVisualScript.draw_summoning_circle(self, to_local(_summoning_circle_world), summon_formation_spacing + 12.0, k, 1.0, _anim_time)
	elif _summon_fade_age >= 0.0:
		DemonLordVisualScript.draw_summoning_circle(self, to_local(_summoning_circle_world), summon_formation_spacing + 12.0, 1.0, 1.0 - _summon_fade_age / SUMMON_FADE_TIME, _anim_time)
	if _teleport_age >= 0.0:
		DemonLordVisualScript.draw_fire_pillar(self, to_local(_teleport_from_world), _teleport_age / TELEPORT_PILLAR_TIME, _anim_time)

	if charging:
		_draw_ward_glow()
	if charging and is_instance_valid(target_ship) and target_ship is Ship:
		var aim := to_local(_get_nearest_ship_boundary_world(target_ship as Ship, global_position))
		DemonLordVisualScript.draw_sight_line(self, gem, aim, charge, _state_time_left, _anim_time)

	DemonLordVisualScript.draw_body(self, _facing, _anim_time, step, charge, 1.0 if enraged else 0.0, recoil, flashing)

	if _teleport_age >= 0.0:
		DemonLordVisualScript.draw_fire_pillar(self, Vector2.ZERO, _teleport_age / TELEPORT_PILLAR_TIME, _anim_time)
	if charging:
		DemonLordVisualScript.draw_charge_particles(self, gem, _anim_time, charge)
	if boss_state == BossState.FIRING_LASER:
		var k: float = clampf(1.0 - _state_time_left / maxf(laser_visual_duration, 0.01), 0.0, 1.0)
		DemonLordVisualScript.draw_laser(self, gem, _laser_end_local, k, _anim_time)
	if boss_state == BossState.RECOVERY:
		var head := (DemonLordVisualScript.HEAD * DemonLordVisualScript.MODEL_SCALE).rotated(_facing)
		if _recovery_from_break:
			DemonLordVisualScript.draw_backfire(self, gem, head, recovery_k, _anim_time, recovery_duration)
		else:
			DemonLordVisualScript.draw_cooling(self, gem, recovery_k, _anim_time)

	if charging:
		_draw_ward_edge()

	# White QTE targets (no progress shown).
	if boss_state == BossState.NORMAL_CHARGING:
		QteStyleScript.draw_target(self, Vector2.ZERO, NORMAL_TARGET_RADIUS, _anim_time)
		if _qte_pop_age >= 0.0:
			QteStyleScript.draw_pop(self, Vector2.ZERO, NORMAL_TARGET_RADIUS, _qte_pop_age / QteStyleScript.POP_TIME)
		if _show_click_label:
			QteStyleScript.draw_click_label(self, Vector2.ZERO, NORMAL_TARGET_RADIUS, _anim_time)
	if boss_state == BossState.SPECIAL_CHARGING:
		var corners := PackedVector2Array()
		for part in PENTAGON_ORDER:
			corners.append(get_body_part_local_position(part))
		corners.append(corners[0])
		for index in range(corners.size() - 1):
			_dashed_line(corners[index], corners[index + 1], Color(1, 1, 1, 0.6), 2.2)
		for part in BODY_PARTS:
			var position := get_body_part_local_position(part)
			if int(special_part_clicks.get(part, 0)) >= special_clicks_per_part:
				var pop: float = float(_part_pop_age.get(part, 1.0)) / QteStyleScript.POP_TIME
				QteStyleScript.draw_pop(self, position, body_part_hit_radius, pop)
				continue
			QteStyleScript.draw_target(self, position, body_part_hit_radius, _anim_time + float(part) * 0.23)
		if _show_click_label:
			QteStyleScript.draw_click_label(self, Vector2.ZERO, special_reserved_radius, _anim_time)


func _dashed_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var length := from.distance_to(to)
	var direction := (to - from) / maxf(length, 0.001)
	var offset: float = fposmod(_anim_time * 20.0, 11.0)
	var at: float = offset - 11.0
	while at < length:
		var a := maxf(at, 0.0)
		var b := minf(at + 6.0, length)
		if b > a:
			draw_line(from + direction * a, from + direction * b, color, width)
		at += 11.0


## Invulnerability ward while charging: a dark-flame glow under the body and
## a slowly turning hexagonal rune barrier over it that flares where hits
## glance off (see _ward_hit_age).
func _ward_radius() -> float:
	return _get_visual_radius() + 46.0


func _draw_ward_glow() -> void:
	var hit := 1.0 - clampf(_ward_hit_age / 0.25, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_anim_time * 5.0)
	draw_circle(Vector2.ZERO, _ward_radius(), Color(Color("C2410C"), 0.10 + 0.06 * pulse + 0.15 * hit))


func _draw_ward_edge() -> void:
	var radius := _ward_radius()
	var hit := 1.0 - clampf(_ward_hit_age / 0.25, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_anim_time * 5.0)
	var flame := Color("FF8A2A")
	var hexagon := PackedVector2Array()
	for index in range(7):
		hexagon.append(Vector2.RIGHT.rotated(TAU * float(index) / 6.0 + _anim_time * 0.4) * radius)
	draw_polyline(hexagon, Color(Color("7A1A1C"), 0.6), 7.0 + 3.0 * hit)
	draw_polyline(hexagon, Color(flame, 0.75 + 0.25 * pulse), 3.0 + 2.5 * hit)
	draw_polyline(hexagon, Color(Color("FFE08A"), 0.35 + 0.6 * hit), 1.2)
	for index in range(6):
		var p := Vector2.RIGHT.rotated(TAU * float(index) / 6.0 + _anim_time * 0.4) * radius
		draw_circle(p, 7.0 + 3.0 * hit, Color("4A0F12"))
		draw_circle(p, 4.5 + 2.0 * hit, Color(Color("FFE08A"), 0.75 + 0.25 * pulse))
