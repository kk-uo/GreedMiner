class_name AncientDragon
extends DragonEnemy

signal boss_state_changed(state_name: String)
signal segment_broken(segments_broken: int)
signal dive_resolved(succeeded: bool, damage: float)
signal fire_breath_resolved(interrupted: bool, damage: float)
signal reinforcements_spawned(count: int)
signal entrance_finished
## Phase two ("Raging Throne", Claude sync 90): emitted once at half health.
signal phase_two_started
signal smoke_breath_resolved
signal fire_wyrms_summoned(count: int)

enum BossState {
	GROUND_COMBAT,
	TAKEOFF,
	AIRBORNE_DIVE_QTE,
	DIVE_RESOLUTION,
	LANDING,
	FIRE_BREATH_CHARGE,
	WINGSTORM_TELEGRAPH,
	RECOVERY,
	DEAD,
	## Lair presentation (only after configure_lair): a shadow sweeps over the
	## hall, then the dragon descends into a tunnel. Damage is locked meanwhile.
	ENTRANCE,
	## Lair: after a reinforcement break it flies over to the other tunnel.
	RELOCATE,
	## Phase two begins: roar, eyes ignite, the lair changes (no damage).
	PHASE_TRANSITION,
	## After every tunnel change (and in phase two every FIRE_WYRM_COOLDOWN):
	## a smoke cloud that blinds the ship's turrets (no target lock).
	SMOKE_BREATH,
	## Phase two: blazing eyes, then three slow fire wyrms crawl at the ship.
	FIRE_EYES,
}

enum DivePart { LEFT_WING, RIGHT_WING, HEAD }

const SEGMENT_COUNT: int = 10
const SEGMENT_HP: float = 15000.0
const TOTAL_HP: float = SEGMENT_COUNT * SEGMENT_HP
const DIVE_PARTS: Array[DivePart] = [DivePart.LEFT_WING, DivePart.RIGHT_WING, DivePart.HEAD]
const SUMMON_BREAKS: Array[int] = [3, 6, 9]
## Shared QTE look (white target + shrinking hint rings + click ripple), the
## same as mining and the Demon Lord (Claude sync 89).
const QteStyleScript := preload("res://Scripts/UI/QteStyle.gd")
const FIRE_WYRM_SCENE := preload("res://Scenes/Enemies/DragonNest/fire_wyrm.tscn")

## Phase two starts once this many segments are broken (half the bar).
const PHASE_TWO_BREAKS: int = 5
const PHASE_TRANSITION_TIME: float = 3.0
const PHASE_TWO_FIRE_BREATH_COOLDOWN: float = 18.0
## Smoke breath: rear up and exhale, the cloud rolls over the ship, then the
## ship's turrets are blinded for SMOKE_BLIND seconds: they keep firing but
## cannot hold a target lock (nearest enemy re-picked every scan), so they turn
## onto the reinforcements / fire wyrms that arrive with the smoke.
const SMOKE_WINDUP: float = 0.9
const SMOKE_TRAVEL: float = 0.6
const SMOKE_BLIND: float = 3.0
## Most wyrms alive at once; a smoke breath only tops the pack up to this.
const FIRE_WYRM_MAX_ALIVE: int = 6
const FIRE_EYES_TELEGRAPH: float = 1.4
const FIRE_WYRM_COOLDOWN: float = 35.0
const FIRE_WYRM_FIRST_DELAY: float = 6.0
const FIRE_WYRM_COUNT: int = 3
const FIRE_WYRM_SPREAD: float = 0.42

@export_group("Dive")
@export_range(0.1, 10.0, 0.1) var takeoff_duration: float = 0.6
@export_range(0.1, 10.0, 0.1) var dive_qte_duration: float = 4.0
@export_range(0.0, 1000.0, 1.0) var dive_success_damage: float = 5.0
@export_range(0.0, 1000.0, 1.0) var dive_failure_damage: float = 30.0
@export_range(1, 20, 1) var clicks_per_part: int = 2
@export_range(0.1, 5.0, 0.1) var dive_resolution_duration: float = 0.35
@export_range(0.1, 5.0, 0.1) var landing_duration: float = 0.65
@export_range(10.0, 200.0, 1.0) var qte_zone_radius: float = 58.0

@export_group("Fire Breath")
@export_range(1.0, 120.0, 0.5) var fire_breath_cooldown: float = 25.0
@export_range(0.1, 20.0, 0.1) var fire_breath_charge_duration: float = 4.0
@export_range(1.0, 100000.0, 1.0) var fire_breath_interrupt_damage: float = 3000.0
@export_range(1, 50, 1) var fire_breath_interrupt_clicks: int = 8
@export_range(0.0, 1000.0, 1.0) var fire_breath_damage: float = 40.0
@export_range(0.1, 10.0, 0.1) var interrupted_recovery_duration: float = 2.0

@export_group("Wingstorm")
@export_range(1.0, 120.0, 0.5) var wingstorm_cooldown: float = 35.0
@export_range(0.0, 1000.0, 1.0) var wingstorm_damage: float = 20.0
@export_range(0.0, 10.0, 0.1) var wingstorm_disruption_duration: float = 1.0
@export_range(0.1, 5.0, 0.1) var wingstorm_telegraph_duration: float = 1.0

@export_group("Summons")
@export var young_dragon_scene: PackedScene

var boss_state: BossState = BossState.GROUND_COMBAT
var current_segment: int = SEGMENT_COUNT
var segments_broken: int = 0
var greed: int = 0
var dive_clicks: Dictionary = {}
var fire_breath_clicks: int = 0
var fire_breath_damage_progress: float = 0.0

var dives_succeeded: int = 0
var dives_failed: int = 0
var total_dive_damage_taken: float = 0.0
var fire_breaths_interrupted: int = 0
var fire_breath_damage_taken: float = 0.0
var young_dragons_summoned: int = 0
var young_dragons_defeated: int = 0
var total_healing_received: float = 0.0

var _state_left: float = 0.0
var _fire_cooldown_left: float = 0.0
var _wingstorm_cooldown_left: float = 0.0
var _weapon_disruption_left: float = 0.0
var _ability_resolved: bool = false
var _dive_succeeded: bool = false
var _summon_after_landing: bool = false
var _ground_anchor: Vector2
var _dive_direction: float = 1.0
var _encounter_elapsed: float = 0.0
var _segment_elapsed: float = 0.0
var _segment_clear_times: Array[float] = []
var _actual_weapon_damage: float = 0.0
var _summons: Array[DragonEnemy] = []
## QTE presentation: when each dive part / the breath was last clicked
## (_animation_time), and whether this QTE shows the first-time CLICK label.
var _qte_pop_at: Dictionary = {}
var _breath_pop_at: float = -100.0
var _qte_click_label: bool = false
## Phase two state and presentation.
var phase_two: bool = false
var smoke_breaths: int = 0
var fire_wyrms_summoned_total: int = 0
var _wyrm_cooldown_left: float = 0.0
var _rage_glow: float = 0.0
var _smoke_cover_left: float = 0.0
var _smoke_target: Vector2
var _smoke_jam_applied: bool = false
var _blind_left: float = 0.0
var _blinded_weapons: Array = []

## Painted size: the boss shows only its front half, about a third of the view.
const ART_R: float = 260.0
## Wings swing forward so they spread across the tunnel mouth.
const WING_ROT: float = 62.0
const ENTRANCE_SWEEP: float = 1.5
const ENTRANCE_DESCENT: float = 2.3
const RELOCATE_ASCENT: float = 0.9
const RELOCATE_SWEEP: float = 1.3

## True once DragonNestController put the boss in a tunnel: it never walks,
## it attacks from there with fireballs and Fire Breath.
var lair_mode: bool = false
var _gates: Array[Vector2] = []
var _gate_index: int = 1
var _lair_ship_center: Vector2
var _anim_left: float = 0.0
var _descent: float = 1.0
var _lunge: float = 0.0
var _raise: float = 0.0
var _breath_fx: float = 0.0
var _breath_target: Vector2
var _mouth_flash: float = 0.0
var _sweep_from: Vector2
var _sweep_to: Vector2
var _sweep_t: float = -1.0
## Landing / take-off effects (local coordinates): dust, rock chips, flung
## coins and embers, plus an expanding shockwave when it touches down.
var _fx: Array[Dictionary] = []
var _shock: float = -1.0
var _was_landed: bool = true
var _shake_tween: Tween


func _ready() -> void:
	max_health = TOTAL_HP
	_base_attack_interval = attack_interval
	for part in DIVE_PARTS:
		dive_clicks[part] = 0
	super()
	add_to_group("boss_qte_targets")
	_ground_anchor = global_position
	_reset_special_cooldowns()
	boss_state_changed.emit(get_boss_state_name())


func _physics_process(delta: float) -> void:
	if _is_dying or boss_state == BossState.DEAD:
		return
	_encounter_elapsed += delta
	_segment_elapsed += delta
	_animation_time += delta
	_update_weapon_disruption(delta)
	_update_smoke_blind(delta)
	_update_pose(delta)
	_update_fx(delta)
	match boss_state:
		BossState.ENTRANCE:
			_hold_for_ability()
			_update_entrance(delta)
		BossState.RELOCATE:
			_hold_for_ability()
			_update_relocation(delta)
		BossState.GROUND_COMBAT:
			_fire_cooldown_left -= delta
			_wingstorm_cooldown_left -= delta
			if phase_two:
				_wyrm_cooldown_left -= delta
			if _fire_cooldown_left <= 0.0:
				start_fire_breath()
			elif phase_two and _wyrm_cooldown_left <= 0.0:
				begin_smoke_breath()
			elif current_segment <= 7 and _wingstorm_cooldown_left <= 0.0:
				_start_wingstorm()
			elif lair_mode:
				_stationary_combat()
			else:
				super(delta)
		BossState.TAKEOFF:
			_hold_for_ability()
			_state_left -= delta
			if _state_left <= 0.0:
				_begin_dive_qte()
		BossState.AIRBORNE_DIVE_QTE:
			_hold_for_ability()
			_state_left -= delta
			_update_airborne_position()
			if _state_left <= 0.0:
				_resolve_dive(false)
		BossState.DIVE_RESOLUTION:
			_hold_for_ability()
			_state_left -= delta
			if _state_left <= 0.0:
				_begin_landing()
		BossState.LANDING:
			_hold_for_ability()
			_state_left -= delta
			global_position = global_position.lerp(_ground_anchor, clampf(delta * 8.0, 0.0, 1.0))
			if _state_left <= 0.0:
				_finish_landing()
		BossState.FIRE_BREATH_CHARGE:
			_hold_for_ability()
			_state_left -= delta
			if _state_left <= 0.0:
				_resolve_fire_breath(false)
		BossState.WINGSTORM_TELEGRAPH:
			_hold_for_ability()
			_state_left -= delta
			if _state_left <= 0.0:
				_resolve_wingstorm()
		BossState.RECOVERY:
			_hold_for_ability()
			_state_left -= delta
			if _state_left <= 0.0:
				_enter_ground_combat()
		BossState.PHASE_TRANSITION:
			_hold_for_ability()
			_state_left -= delta
			if _state_left <= 0.0:
				_enter_ground_combat()
		BossState.SMOKE_BREATH:
			_hold_for_ability()
			_state_left -= delta
			if _state_left <= 0.0:
				_resolve_smoke_breath()
		BossState.FIRE_EYES:
			_hold_for_ability()
			_state_left -= delta
			if _state_left <= 0.0:
				_resolve_fire_eyes()
	_smoke_cover_left = maxf(_smoke_cover_left - delta, 0.0)
	_rage_glow = move_toward(_rage_glow, 1.0 if phase_two else 0.0, delta * 0.8)
	queue_redraw()


func take_damage(damage: float, ignore_damage_reduction: bool = false, count_for_artifact: bool = true, source_weapon: WeaponModule = null) -> void:
	if damage <= 0.0 or _is_dying or not is_damage_unlocked():
		return
	var before := get_current_health()
	var segment_floor := float(current_segment - 1) * SEGMENT_HP
	var available := maxf(before - segment_floor, 0.0)
	var accepted := minf(damage, available)
	if accepted <= 0.0:
		return
	super(accepted, ignore_damage_reduction, count_for_artifact, source_weapon)
	var applied := maxf(before - get_current_health(), 0.0)
	if is_instance_valid(source_weapon):
		_actual_weapon_damage += applied
	if boss_state == BossState.FIRE_BREATH_CHARGE:
		fire_breath_damage_progress += applied
		if fire_breath_damage_progress >= fire_breath_interrupt_damage and not _ability_resolved:
			_resolve_fire_breath(true)
	if not _is_dying and get_current_health() <= segment_floor + 0.001:
		_on_segment_depleted()


func is_damage_unlocked() -> bool:
	return boss_state in [BossState.GROUND_COMBAT, BossState.FIRE_BREATH_CHARGE, BossState.WINGSTORM_TELEGRAPH, BossState.RECOVERY, BossState.SMOKE_BREATH, BossState.FIRE_EYES]


func get_weapon_damage_phase() -> int:
	return segments_broken


func _on_segment_depleted() -> void:
	_segment_clear_times.append(_segment_elapsed)
	_segment_elapsed = 0.0
	if current_segment <= 1:
		return
	segments_broken += 1
	current_segment -= 1
	segment_broken.emit(segments_broken)
	_summon_after_landing = segments_broken in SUMMON_BREAKS
	_begin_takeoff()


func _begin_takeoff() -> void:
	_ability_resolved = true
	_ground_anchor = global_position
	_state_left = takeoff_duration
	_enter_state(BossState.TAKEOFF)


func _begin_dive_qte() -> void:
	for part in DIVE_PARTS:
		dive_clicks[part] = 0
	_qte_pop_at.clear()
	_qte_click_label = QteStyleScript.claim_click_hint()
	_dive_direction = -1.0 if current_segment <= 7 and segments_broken % 2 == 0 else 1.0
	_state_left = dive_qte_duration
	_ability_resolved = false
	_dive_succeeded = false
	_enter_state(BossState.AIRBORNE_DIVE_QTE)


## The "dive" is now an in-place pounce: the dragon rears back with its wings
## raised (QTE window) and strikes from where it stands; it never flies around.
func _update_airborne_position() -> void:
	pass


func _resolve_dive(succeeded: bool) -> void:
	if boss_state != BossState.AIRBORNE_DIVE_QTE or _ability_resolved:
		return
	_ability_resolved = true
	_dive_succeeded = succeeded
	if succeeded:
		dives_succeeded += 1
	else:
		dives_failed += 1
	_state_left = dive_resolution_duration
	_enter_state(BossState.DIVE_RESOLUTION)


func _begin_landing() -> void:
	var damage := dive_success_damage if _dive_succeeded else dive_failure_damage
	total_dive_damage_taken += _apply_ship_damage(damage)
	dive_resolved.emit(_dive_succeeded, damage)
	_state_left = landing_duration
	_enter_state(BossState.LANDING)


func _finish_landing() -> void:
	global_position = _ground_anchor
	if not phase_two and segments_broken >= PHASE_TWO_BREAKS:
		_begin_phase_two()
		return
	if _summon_after_landing:
		_summon_after_landing = false
		if lair_mode and _gates.size() == 2:
			_begin_relocation()
			return
		spawn_reinforcements()
	_enter_ground_combat()


func start_fire_breath() -> bool:
	if boss_state != BossState.GROUND_COMBAT or _is_dying:
		return false
	fire_breath_clicks = 0
	fire_breath_damage_progress = 0.0
	_breath_pop_at = -100.0
	_qte_click_label = QteStyleScript.claim_click_hint()
	_ability_resolved = false
	_state_left = fire_breath_charge_duration
	_enter_state(BossState.FIRE_BREATH_CHARGE)
	return true


func _resolve_fire_breath(interrupted: bool) -> void:
	if boss_state != BossState.FIRE_BREATH_CHARGE or _ability_resolved:
		return
	_ability_resolved = true
	var damage := 0.0
	if interrupted:
		fire_breaths_interrupted += 1
	else:
		_breath_fx = 1.0
		if is_instance_valid(target_ship):
			_breath_target = (target_ship as Ship).to_global(Ship.SHIP_SIZE * 0.5)
		damage = fire_breath_damage
		fire_breath_damage_taken += _apply_ship_damage(damage)
	fire_breath_resolved.emit(interrupted, damage)
	_state_left = interrupted_recovery_duration
	_enter_state(BossState.RECOVERY)


func _start_wingstorm() -> bool:
	if boss_state != BossState.GROUND_COMBAT or current_segment > 7:
		return false
	_state_left = wingstorm_telegraph_duration
	_ability_resolved = false
	_enter_state(BossState.WINGSTORM_TELEGRAPH)
	return true


func _resolve_wingstorm() -> void:
	if boss_state != BossState.WINGSTORM_TELEGRAPH or _ability_resolved:
		return
	_ability_resolved = true
	_apply_ship_damage(wingstorm_damage)
	if is_instance_valid(target_ship):
		(target_ship as Ship).set_weapon_attacks_enabled(false)
		_weapon_disruption_left = maxf(_weapon_disruption_left, wingstorm_disruption_duration)
	_wingstorm_cooldown_left = _scaled_cooldown(wingstorm_cooldown)
	_state_left = 0.5
	_enter_state(BossState.RECOVERY)


func _update_weapon_disruption(delta: float) -> void:
	if _weapon_disruption_left <= 0.0:
		return
	_weapon_disruption_left = maxf(_weapon_disruption_left - delta, 0.0)
	if _weapon_disruption_left <= 0.0 and is_instance_valid(target_ship):
		(target_ship as Ship).set_weapon_attacks_enabled(true)


func route_qte_click(world_position: Vector2) -> bool:
	if boss_state == BossState.AIRBORNE_DIVE_QTE:
		var local := to_local(world_position)
		for part in DIVE_PARTS:
			if local.distance_to(get_qte_part_local_position(part)) <= qte_zone_radius:
				if int(dive_clicks.get(part, 0)) < clicks_per_part:
					dive_clicks[part] = int(dive_clicks.get(part, 0)) + 1
					_qte_pop_at[part] = _animation_time
					if get_dive_click_total() >= clicks_per_part * DIVE_PARTS.size():
						_resolve_dive(true)
				return true
		return false
	if boss_state == BossState.FIRE_BREATH_CHARGE:
		if world_position.distance_to(to_global(get_qte_part_local_position(DivePart.HEAD))) > qte_zone_radius:
			return false
		fire_breath_clicks += 1
		_breath_pop_at = _animation_time
		if fire_breath_clicks >= fire_breath_interrupt_clicks:
			_resolve_fire_breath(true)
		return true
	return false


# ------------------------------------------------------------ phase two

## Half health: a 3 s roar (no damage) while the crown and eyes ignite and the
## lair turns (DragonNestController hatches unstolen eggs, map rages).
func _begin_phase_two() -> void:
	phase_two = true
	_summon_after_landing = false
	_state_left = PHASE_TRANSITION_TIME
	_wyrm_cooldown_left = FIRE_WYRM_FIRST_DELAY
	_mouth_flash = 1.0
	_enter_state(BossState.PHASE_TRANSITION)
	_shake_camera(16.0, 1.4)
	phase_two_started.emit()


## Developer/test helper: ends the phase-two roar immediately.
func skip_phase_transition() -> void:
	if boss_state == BossState.PHASE_TRANSITION:
		_enter_ground_combat()


func force_phase_two() -> bool:
	if phase_two or boss_state != BossState.GROUND_COMBAT:
		return false
	_begin_phase_two()
	return true


## Rear up and exhale a smoke cloud that rolls over the ship; when it lands
## the turrets are blinded for SMOKE_BLIND seconds. In phase two the eyes
## blaze during the exhale and three fire wyrms come out with the smoke.
func begin_smoke_breath() -> bool:
	if _is_dying:
		return false
	_ability_resolved = false
	_smoke_jam_applied = false
	if is_instance_valid(target_ship):
		_smoke_target = (target_ship as Ship).to_global(Ship.SHIP_SIZE * 0.5)
	_state_left = SMOKE_WINDUP + SMOKE_TRAVEL
	_enter_state(BossState.SMOKE_BREATH)
	return true


func _resolve_smoke_breath() -> void:
	if boss_state != BossState.SMOKE_BREATH or _ability_resolved:
		return
	_ability_resolved = true
	_smoke_jam_applied = true
	smoke_breaths += 1
	_smoke_cover_left = SMOKE_BLIND
	_apply_smoke_blind(SMOKE_BLIND)
	if phase_two:
		var count := spawn_fire_wyrms()
		fire_wyrms_summoned.emit(count)
		_wyrm_cooldown_left = _scaled_cooldown(FIRE_WYRM_COOLDOWN)
	smoke_breath_resolved.emit()
	_enter_ground_combat()


## Blinds every turret on the ship (WeaponModule.target_lock_suppressed).
func _apply_smoke_blind(duration: float) -> void:
	if not is_instance_valid(target_ship):
		return
	_blind_left = maxf(_blind_left, duration)
	var stack: Array[Node] = [target_ship]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is WeaponModule:
			(node as WeaponModule).target_lock_suppressed = true
			if not _blinded_weapons.has(node):
				_blinded_weapons.append(node)
		stack.append_array(node.get_children())


func _update_smoke_blind(delta: float) -> void:
	if _blind_left <= 0.0:
		return
	_blind_left = maxf(_blind_left - delta, 0.0)
	if _blind_left <= 0.0:
		_release_smoke_blind()


func _release_smoke_blind() -> void:
	for weapon in _blinded_weapons:
		if is_instance_valid(weapon):
			(weapon as WeaponModule).target_lock_suppressed = false
	_blinded_weapons.clear()
	_blind_left = 0.0


func is_ship_blinded() -> bool:
	return _blind_left > 0.0


## Smoke breath progress for drawing: 0..1 exhale, then 0..1 cloud travel.
func _smoke_phase() -> Vector2:
	var elapsed := SMOKE_WINDUP + SMOKE_TRAVEL - _state_left
	return Vector2(clampf(elapsed / SMOKE_WINDUP, 0.0, 1.0), clampf((elapsed - SMOKE_WINDUP) / SMOKE_TRAVEL, 0.0, 1.0))


## Phase two wyrm summon: since sync 93 it is the smoke breath itself
## (eyes blaze while exhaling, wyrms arrive with the smoke).
func start_fire_eyes() -> bool:
	if boss_state != BossState.GROUND_COMBAT or _is_dying or not phase_two:
		return false
	return begin_smoke_breath()


func _resolve_fire_eyes() -> void:
	if boss_state != BossState.FIRE_EYES or _ability_resolved:
		return
	_ability_resolved = true
	var count := spawn_fire_wyrms()
	fire_wyrms_summoned.emit(count)
	_wyrm_cooldown_left = _scaled_cooldown(FIRE_WYRM_COOLDOWN)
	_state_left = 0.4
	_enter_state(BossState.RECOVERY)


## Three fire wyrms fan out from the head and crawl at the ship.
func spawn_fire_wyrms() -> int:
	if get_parent() == null or not is_instance_valid(target_ship):
		return 0
	var head := to_global(get_qte_part_local_position(DivePart.HEAD))
	var ship_center := (target_ship as Ship).to_global(Ship.SHIP_SIZE * 0.5)
	var forward := head.direction_to(ship_center)
	var alive := 0
	for node in get_parent().get_children():
		if node is BasicEnemy and (node as BasicEnemy).enemy_id == &"fire_wyrm" and not (node as BasicEnemy).is_dying():
			alive += 1
	var wanted := mini(FIRE_WYRM_COUNT, FIRE_WYRM_MAX_ALIVE - alive)
	var count := 0
	for index in range(FIRE_WYRM_COUNT):
		if count >= wanted:
			break
		var lane := (float(index) - float(FIRE_WYRM_COUNT - 1) * 0.5) * FIRE_WYRM_SPREAD
		var wyrm := FIRE_WYRM_SCENE.instantiate() as BasicEnemy
		if wyrm == null:
			continue
		wyrm.target_ship = target_ship
		wyrm.set_meta("dragon_nest_boss_summon", true)
		wyrm.set_meta("spawn_origin", &"dragon_nest_boss_summon")
		get_parent().add_child(wyrm)
		wyrm.global_position = head + forward.rotated(lane) * 150.0 + forward.orthogonal() * lane * 120.0
		count += 1
	fire_wyrms_summoned_total += count
	return count


## World positions of the two eyes (phase two flames pour from them).
func _eye_local_positions() -> Array[Vector2]:
	var hr := 0.2 * ART_R * float(DragonNestArt.HEAD_K[&"ancient"])
	var head := DragonNestArt.head_centre(ART_R, &"ancient", _lunge)
	return [
		(head + Vector2(hr * 0.4, hr * 0.48)).rotated(_facing),
		(head + Vector2(hr * 0.4, -hr * 0.48)).rotated(_facing),
	]


func get_qte_part_local_position(part: DivePart) -> Vector2:
	# Matches the painted wing wrists and head (DragonNestArt), in this frame.
	match part:
		DivePart.LEFT_WING: return DragonNestArt.wing_wrist(ART_R, &"ancient", -1.0, WING_ROT + _raise).rotated(_facing)
		DivePart.RIGHT_WING: return DragonNestArt.wing_wrist(ART_R, &"ancient", 1.0, WING_ROT + _raise).rotated(_facing)
		_: return (DragonNestArt.head_centre(ART_R, &"ancient", _lunge) + Vector2(ART_R * 0.12, 0.0)).rotated(_facing)


func get_dive_click_total() -> int:
	var total := 0
	for part in DIVE_PARTS:
		total += int(dive_clicks.get(part, 0))
	return total


func spawn_reinforcements() -> int:
	_cleanup_summons()
	if young_dragon_scene == null or get_parent() == null:
		return 0
	var profile := DragonNestRules.summon_profile(greed)
	var slots := maxi(int(profile["cap"]) - _summons.size(), 0)
	var count := mini(int(profile["requested"]), slots)
	for index in range(count):
		var summon := young_dragon_scene.instantiate() as DragonEnemy
		if summon == null:
			continue
		summon.target_ship = target_ship
		summon.set_meta("dragon_nest_boss_summon", true)
		summon.set_meta("spawn_origin", &"dragon_nest_boss_summon")
		summon.add_to_group("dragon_nest_boss_summons")
		get_parent().add_child(summon)
		var origin := to_global(get_qte_part_local_position(DivePart.HEAD)) if lair_mode else global_position
		summon.global_position = origin + Vector2(90.0, 0.0).rotated(TAU * float(index) / float(maxi(count, 1)))
		summon.died.connect(_on_summon_died, CONNECT_ONE_SHOT)
		_summons.append(summon)
		young_dragons_summoned += 1
	if count < int(profile["requested"]):
		print("AncientDragon: reinforcement cap reached; skipped %d summon(s)." % (int(profile["requested"]) - count))
	reinforcements_spawned.emit(count)
	return count


func _on_summon_died(_enemy_id: StringName, _position: Vector2) -> void:
	young_dragons_defeated += 1


func _cleanup_summons() -> void:
	for index in range(_summons.size() - 1, -1, -1):
		if not is_instance_valid(_summons[index]) or _summons[index].is_dying():
			_summons.remove_at(index)


func get_active_summon_count() -> int:
	_cleanup_summons()
	return _summons.size()


func apply_greed(value: int) -> void:
	var previous_multiplier := DragonNestRules.attack_interval_multiplier(greed)
	greed = clampi(value, 0, DragonNestRules.MAX_GREED)
	var current_multiplier := DragonNestRules.attack_interval_multiplier(greed)
	attack_interval = _base_attack_interval * current_multiplier
	if is_instance_valid(attack_timer):
		attack_timer.wait_time = attack_interval
	if previous_multiplier > 0.0 and boss_state == BossState.GROUND_COMBAT:
		var ratio := current_multiplier / previous_multiplier
		_fire_cooldown_left = maxf(_fire_cooldown_left * ratio, 0.0)
		_wingstorm_cooldown_left = maxf(_wingstorm_cooldown_left * ratio, 0.0)


func _scaled_cooldown(base: float) -> float:
	return base * DragonNestRules.attack_interval_multiplier(greed)


func _reset_special_cooldowns() -> void:
	_fire_cooldown_left = _scaled_cooldown(PHASE_TWO_FIRE_BREATH_COOLDOWN if phase_two else fire_breath_cooldown)
	_wingstorm_cooldown_left = _scaled_cooldown(wingstorm_cooldown)


func _enter_ground_combat() -> void:
	_ability_resolved = false
	_reset_special_cooldowns()
	_enter_state(BossState.GROUND_COMBAT)


func _enter_state(next_state: BossState) -> void:
	boss_state = next_state
	boss_state_changed.emit(get_boss_state_name())
	queue_redraw()


func _hold_for_ability() -> void:
	_stop_attacking()


func _apply_ship_damage(amount: float) -> float:
	if amount <= 0.0 or not is_instance_valid(target_ship):
		return 0.0
	var before := (target_ship as Ship).current_hp
	(target_ship as Ship).take_damage(amount)
	return maxf(before - (target_ship as Ship).current_hp, 0.0)


func get_segment_remaining_hp() -> float:
	if _is_dying:
		return 0.0
	return clampf(get_current_health() - float(current_segment - 1) * SEGMENT_HP, 0.0, SEGMENT_HP)


func get_boss_state_name() -> String:
	return BossState.keys()[boss_state]


func get_qte_status() -> String:
	if boss_state == BossState.AIRBORNE_DIVE_QTE:
		return "DIVE %d/%d  %.1fs" % [get_dive_click_total(), clicks_per_part * 3, maxf(_state_left, 0.0)]
	if boss_state == BossState.FIRE_BREATH_CHARGE:
		return "BREATH clicks %d/%d dmg %.0f/%.0f  %.1fs" % [fire_breath_clicks, fire_breath_interrupt_clicks, fire_breath_damage_progress, fire_breath_interrupt_damage, maxf(_state_left, 0.0)]
	return "-"


func get_next_special_cooldown() -> float:
	return maxf(minf(_fire_cooldown_left, _wingstorm_cooldown_left if current_segment <= 7 else INF), 0.0)


func record_healing(amount: float) -> void:
	total_healing_received += maxf(amount, 0.0)


func get_balance_metrics() -> Dictionary:
	return {
		"actual_dps": _actual_weapon_damage / maxf(_encounter_elapsed, 0.001),
		"segment_times": _segment_clear_times.duplicate(),
		"encounter_duration": _encounter_elapsed,
		"dive_successes": dives_succeeded,
		"dive_failures": dives_failed,
		"dive_damage": total_dive_damage_taken,
		"breaths_interrupted": fire_breaths_interrupted,
		"breath_damage": fire_breath_damage_taken,
		"healing": total_healing_received,
		"summoned": young_dragons_summoned,
		"summons_defeated": young_dragons_defeated,
		"final_ship_hp": (target_ship as Ship).current_hp if is_instance_valid(target_ship) else 0.0,
	}


## Developer/test helpers keep the same state transitions and damage gates.
func force_nearly_empty_segment() -> void:
	if is_damage_unlocked() and not _is_dying:
		_current_health = float(current_segment - 1) * SEGMENT_HP + 1.0
		health_changed.emit(_current_health, max_health)


func force_dive_qte() -> bool:
	if boss_state != BossState.GROUND_COMBAT or current_segment <= 1:
		return false
	_begin_dive_qte()
	return true


func force_resolve_dive_for_testing(succeeded: bool) -> void:
	if boss_state == BossState.AIRBORNE_DIVE_QTE:
		_resolve_dive(succeeded)
	if boss_state == BossState.DIVE_RESOLUTION:
		_state_left = 0.0
		_begin_landing()
	if boss_state == BossState.LANDING:
		_state_left = 0.0
		_finish_landing()


func _get_visual_radius() -> float:
	return ART_R * 0.8


## Weapons aim at (and measure range to) the head or chest, whichever is
## closer - the body centre is half inside the tunnel.
func get_target_point(from_world: Vector2) -> Vector2:
	var head := to_global(get_qte_part_local_position(DivePart.HEAD))
	var chest := to_global(Vector2(ART_R * 0.55, 0.0).rotated(_facing))
	return head if head.distance_squared_to(from_world) < chest.distance_squared_to(from_world) else chest


# ------------------------------------------------------------------ lair mode

## Called by DragonNestController: anchor in a side tunnel facing the ship,
## move the hit area onto the visible neck/chest, then play the entrance.
func configure_lair(gates: Array[Vector2], ship_center: Vector2, gate_index: int) -> void:
	lair_mode = true
	_gates = gates.duplicate()
	_lair_ship_center = ship_center
	_place_at_gate(clampi(gate_index, 0, _gates.size() - 1))
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		collision.shape = collision.shape.duplicate()
		(collision.shape as CircleShape2D).radius = ART_R * 0.5
	_update_collision_offset()
	begin_entrance()


func _place_at_gate(index: int) -> void:
	_fx.clear()
	_gate_index = index
	global_position = _gates[index]
	_ground_anchor = global_position
	_facing = (_lair_ship_center - global_position).angle()
	_update_collision_offset()


func _update_collision_offset() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and lair_mode:
		collision.position = Vector2(ART_R * 0.85, 0.0).rotated(_facing)


## Developer/test helper: land immediately and start fighting.
func skip_entrance() -> void:
	if boss_state != BossState.ENTRANCE:
		return
	_anim_left = 0.0
	_update_entrance(0.0)


func begin_entrance() -> void:
	_stop_attacking()
	_descent = 0.0
	_anim_left = ENTRANCE_SWEEP + ENTRANCE_DESCENT
	var side := signf((global_position - _lair_ship_center).x)
	# The shadow comes in over the far wall, crosses the hall, and leaves over
	# the tunnel the dragon will land in.
	_start_sweep(_lair_ship_center + Vector2(-side * 1500.0, -380.0), global_position + Vector2(side * 500.0, 260.0))
	_enter_state(BossState.ENTRANCE)


func _start_sweep(from: Vector2, to: Vector2) -> void:
	_sweep_from = from
	_sweep_to = to
	_sweep_t = 0.0


func _update_entrance(delta: float) -> void:
	_anim_left -= delta
	var elapsed := ENTRANCE_SWEEP + ENTRANCE_DESCENT - _anim_left
	_sweep_t = clampf(elapsed / ENTRANCE_SWEEP, 0.0, 1.0) if elapsed < ENTRANCE_SWEEP + 0.2 else -1.0
	_descent = clampf((elapsed - ENTRANCE_SWEEP) / ENTRANCE_DESCENT, 0.0, 1.0)
	if _anim_left <= 0.0:
		_descent = 1.0
		_sweep_t = -1.0
		_enter_ground_combat()
		entrance_finished.emit()


func _begin_relocation() -> void:
	_stop_attacking()
	_anim_left = RELOCATE_ASCENT + RELOCATE_SWEEP + ENTRANCE_DESCENT
	_enter_state(BossState.RELOCATE)


func _update_relocation(delta: float) -> void:
	var total := RELOCATE_ASCENT + RELOCATE_SWEEP + ENTRANCE_DESCENT
	_anim_left -= delta
	var elapsed := total - _anim_left
	if elapsed < RELOCATE_ASCENT:
		_descent = 1.0 - elapsed / RELOCATE_ASCENT
	elif elapsed < RELOCATE_ASCENT + RELOCATE_SWEEP:
		if _sweep_t < 0.0:
			var from := global_position
			_place_at_gate(1 - _gate_index)
			_start_sweep(from, global_position + Vector2(signf((global_position - _lair_ship_center).x) * 400.0, -200.0))
		_descent = 0.0
		_sweep_t = (elapsed - RELOCATE_ASCENT) / RELOCATE_SWEEP
	else:
		_sweep_t = -1.0
		_descent = clampf((elapsed - RELOCATE_ASCENT - RELOCATE_SWEEP) / ENTRANCE_DESCENT, 0.0, 1.0)
	if _anim_left <= 0.0:
		_descent = 1.0
		_sweep_t = -1.0
		spawn_reinforcements()
		# Every tunnel change ends with a smoke breath over the ship.
		begin_smoke_breath()


## Never walks: faces the ship and keeps lobbing fireballs from the tunnel.
func _stationary_combat() -> void:
	if not is_instance_valid(target_ship) or (target_ship as Ship).current_hp <= 0.0:
		_stop_attacking()
		return
	_start_attacking()


func _perform_attack(ship: Ship) -> void:
	if not lair_mode:
		super(ship)
		return
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as HostileProjectile
	if projectile == null:
		return
	var mouth := to_global((DragonNestArt.head_centre(ART_R, &"ancient", _lunge) + Vector2(ART_R * 0.45, 0.0)).rotated(_facing))
	var direction := mouth.direction_to(ship.to_global(Ship.SHIP_SIZE * 0.5))
	projectile.direction = direction
	projectile.speed = projectile_speed
	projectile.damage = attack_damage
	projectile.target_ship = ship
	projectile.set("visual_scale", 2.4)
	var spawn_parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	spawn_parent.add_child(projectile)
	projectile.global_position = mouth
	_mouth_flash = 1.0


func _update_pose(delta: float) -> void:
	var lunge_target := 0.0
	var raise_target := 0.0
	match boss_state:
		BossState.TAKEOFF:
			lunge_target = -0.25
			raise_target = 14.0
		BossState.AIRBORNE_DIVE_QTE:
			lunge_target = -0.3 + sin(_animation_time * 30.0) * 0.015
			raise_target = 18.0
		BossState.DIVE_RESOLUTION:
			lunge_target = 0.6
			raise_target = -6.0
		BossState.FIRE_BREATH_CHARGE:
			lunge_target = -0.12 + sin(_animation_time * 24.0) * 0.01
			raise_target = 6.0
		BossState.PHASE_TRANSITION:
			# Rears up and roars.
			lunge_target = -0.28 + sin(_animation_time * 40.0) * 0.02
			raise_target = 22.0
		BossState.SMOKE_BREATH:
			var sp := _smoke_phase()
			lunge_target = -0.2 * (1.0 - sp.x) + 0.25 * sp.x * (1.0 - sp.y)
			raise_target = 10.0 * (1.0 - sp.x)
		BossState.FIRE_EYES:
			lunge_target = -0.1
			raise_target = 8.0
	var rate := 14.0 if boss_state == BossState.DIVE_RESOLUTION else 5.0
	_lunge = lerpf(_lunge, lunge_target, clampf(delta * rate, 0.0, 1.0))
	_raise = lerpf(_raise, raise_target, clampf(delta * 5.0, 0.0, 1.0))
	_breath_fx = maxf(_breath_fx - delta * 1.3, 0.0)
	_mouth_flash = maxf(_mouth_flash - delta * 3.0, 0.0)


func _update_fx(delta: float) -> void:
	var airborne := boss_state in [BossState.ENTRANCE, BossState.RELOCATE]
	if airborne and _descent > 0.05 and _descent < 1.0:
		# Downdraft: the closer it gets, the more dust and gold it blows away.
		var strength := _descent * _descent
		for i in range(int(strength * 5.0) + 1):
			if randf() < 0.6:
				_spawn_ground_fx(0, ART_R * randf_range(0.6, 1.6), 260.0 * strength + 60.0)
		if randf() < strength * 0.9:
			_spawn_ground_fx(2, ART_R * randf_range(0.4, 1.2), 340.0 * strength + 80.0)
		if randf() < 0.5:
			var p := Vector2(randf_range(-0.4, 0.9) * ART_R, randf_range(-0.4, 0.4) * ART_R).rotated(_facing)
			_fx.append({"p": p, "v": Vector2(randf_range(-30, 30), randf_range(-90, -40)), "life": 0.9, "max": 0.9, "r": randf_range(3.0, 6.0), "kind": 3})
	if _descent >= 1.0 and not _was_landed:
		_touchdown()
	if airborne and _descent < 0.98 and _descent > 0.0 and boss_state == BossState.RELOCATE and _was_landed:
		# lifting off: one big gust
		for i in range(26):
			_spawn_ground_fx(0, ART_R * randf_range(0.5, 1.4), 320.0)
	_was_landed = _descent >= 1.0
	if _shock >= 0.0:
		_shock += delta / 0.8
		if _shock >= 1.0:
			_shock = -1.0
	for i in range(_fx.size() - 1, -1, -1):
		var f := _fx[i]
		f["life"] = float(f["life"]) - delta
		if float(f["life"]) <= 0.0:
			_fx.remove_at(i)
			continue
		var damping := 2.6 if int(f["kind"]) == 0 else 1.4
		f["v"] = (f["v"] as Vector2) * maxf(1.0 - damping * delta, 0.0)
		f["p"] = (f["p"] as Vector2) + (f["v"] as Vector2) * delta


## kind 0 dust puff, 1 rock chip, 2 coin, 3 ember. Spawned on a ring around
## the landing spot, moving outward.
func _spawn_ground_fx(kind: int, distance: float, speed: float) -> void:
	if _fx.size() > 260:
		return
	var a := randf() * TAU
	var dir := Vector2.from_angle(a)
	var centre := Vector2(ART_R * 0.3, 0.0).rotated(_facing)
	var size := randf_range(14.0, 30.0) if kind == 0 else (randf_range(4.0, 9.0) if kind == 1 else randf_range(2.5, 4.0))
	var life := randf_range(0.6, 1.2) if kind == 0 else randf_range(0.5, 0.9)
	_fx.append({"p": centre + dir * distance, "v": dir * speed * randf_range(0.6, 1.2), "life": life, "max": life, "r": size, "kind": kind, "spin": randf() * TAU})


## Touching down: shockwave, a ring of dust, rock chips, coins, a roar of
## flame and a camera shake.
func _touchdown() -> void:
	_shock = 0.0
	for i in range(44):
		_spawn_ground_fx(0, ART_R * randf_range(0.5, 1.1), randf_range(380.0, 620.0))
	for i in range(26):
		_spawn_ground_fx(1, ART_R * randf_range(0.4, 0.9), randf_range(300.0, 560.0))
	for i in range(40):
		_spawn_ground_fx(2, ART_R * randf_range(0.3, 1.0), randf_range(260.0, 520.0))
	_mouth_flash = 1.6
	_shake_camera(16.0, 0.7)


func _shake_camera(amount: float, duration: float) -> void:
	if not is_instance_valid(target_ship) or not target_ship is Ship:
		return
	var camera: Camera2D = (target_ship as Ship).world_camera
	if camera == null:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	var base := Vector2.ZERO
	_shake_tween = camera.create_tween()
	var steps: int = maxi(int(duration / 0.03), 2)
	for step in range(steps):
		var strength := amount * (1.0 - float(step) / float(steps))
		_shake_tween.tween_property(camera, "offset", base + Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.03)
	_shake_tween.tween_property(camera, "offset", base, 0.03)


func _draw_fx_ground() -> void:
	if _shock >= 0.0:
		var centre := Vector2(ART_R * 0.3, 0.0).rotated(_facing)
		var e := ease(_shock, 0.4)
		draw_arc(centre, ART_R * (0.6 + e * 2.6), 0.0, TAU, 72, Color(1.0, 0.55, 0.2, 0.7 * (1.0 - _shock)), 18.0 * (1.0 - _shock) + 2.0)
		draw_arc(centre, ART_R * (0.45 + e * 2.0), 0.0, TAU, 72, Color(0.85, 0.78, 0.66, 0.5 * (1.0 - _shock)), 30.0 * (1.0 - _shock) + 2.0)
		draw_circle(centre, ART_R * 1.3 * (1.0 - _shock * 0.5), Color(1.0, 0.6, 0.25, 0.18 * (1.0 - _shock)))
	for f in _fx:
		var k := float(f["life"]) / float(f["max"])
		var p: Vector2 = f["p"]
		match int(f["kind"]):
			0:
				var r := float(f["r"]) * (1.6 - k * 0.6)
				draw_circle(p, r, Color(0.62, 0.55, 0.47, 0.42 * k))
				draw_circle(p - Vector2(r * 0.25, r * 0.3), r * 0.6, Color(0.78, 0.71, 0.62, 0.35 * k))
			1:
				var r := float(f["r"])
				draw_colored_polygon(DragonNestArt.ellipse(p, r, r * 0.8, 5, float(f["spin"]) + (1.0 - k) * 6.0), Color(0.35, 0.33, 0.29, minf(k * 2.0, 1.0)))
			2:
				var r := float(f["r"])
				draw_circle(p, r, Color(0.95, 0.76, 0.29, minf(k * 2.0, 1.0)))
				draw_circle(p - Vector2.ONE * r * 0.3, r * 0.4, Color(1.0, 0.92, 0.63, minf(k * 2.0, 1.0)))


func _draw_fx_air() -> void:
	for f in _fx:
		if int(f["kind"]) != 3:
			continue
		var k := float(f["life"]) / float(f["max"])
		draw_circle(f["p"], float(f["r"]) * (0.5 + k * 0.5), Color(1.0, 0.55 + 0.3 * k, 0.2, 0.9 * k))


func _draw() -> void:
	var t := _animation_time
	_draw_fx_ground()
	# 1. the flying shadow that sweeps over the hall (entrance / relocation)
	if _sweep_t >= 0.0 and _sweep_t <= 1.0:
		var p := to_local(_sweep_from.lerp(_sweep_to, _sweep_t))
		var heading := (_sweep_to - _sweep_from).angle()
		var fade := sin(_sweep_t * PI)
		DragonNestArt.mono = Color(0.0, 0.0, 0.0, 0.5 * fade)
		DragonNestArt.begin(_pen, Transform2D(heading, Vector2.ONE * 1.25, 0.0, p))
		DragonNestArt.dragon(_pen, ART_R, &"great", t, {"shadow": false, "flap": 14.0, "flap_speed": 5.0})
		DragonNestArt.mono = Color(0, 0, 0, 0)
		_pen.flush_to(self)
	# 2. the dragon itself (descending: bigger and see-through, high above)
	if _descent > 0.0:
		var e := ease(_descent, -2.0)
		var k := lerpf(1.45, 1.0, e)
		var height := (1.0 - e) * 160.0
		var start := _pen._colors.size()
		var mouth := 0.0
		if boss_state == BossState.FIRE_BREATH_CHARGE:
			mouth = 1.0 - _state_left / maxf(fire_breath_charge_duration, 0.001)
		mouth = maxf(mouth, maxf(_mouth_flash, _breath_fx))
		if boss_state == BossState.PHASE_TRANSITION:
			mouth = 1.0
		var flap := 4.0
		if boss_state == BossState.WINGSTORM_TELEGRAPH:
			flap = 22.0
		DragonNestArt.begin(_pen, Transform2D(_facing, Vector2.ONE * k, 0.0, Vector2.ZERO))
		DragonNestArt.dragon(_pen, ART_R, &"ancient", t, {
			"wing_rot": WING_ROT + _raise, "flap": flap, "flap_speed": 9.0 if flap > 10.0 else 1.6,
			"lunge": _lunge, "mouth": mouth,
			"eye": DragonNestArt.EYE.lerp(Color("FFF4C8"), _rage_glow),
			"shadow_offset": Vector2(-0.2 * ART_R, 0.12 * ART_R) + Vector2(height, height * 1.4).rotated(-_facing) / k})
		if _descent < 1.0:
			var alpha_k := clampf(_descent * 1.4, 0.0, 1.0)
			for index in range(start, _pen._colors.size()):
				var c: Color = _pen._colors[index]
				c.a *= alpha_k
				_pen._colors[index] = c
		_pen.flush_to(self)
		_draw_phase_two_fx(t)
	_draw_smoke(t)
	_draw_fx_air()
	# 3. Fire Breath: a cone of flame from the mouth to the ship
	if _breath_fx > 0.0:
		var mouth_local := (DragonNestArt.head_centre(ART_R, &"ancient", _lunge) + Vector2(ART_R * 0.45, 0.0)).rotated(_facing)
		var target := to_local(_breath_target)
		var axis := target - mouth_local
		var side := axis.orthogonal().normalized()
		for layer in [[1.0, Color(1.0, 0.35, 0.1, 0.45)], [0.62, Color(1.0, 0.6, 0.15, 0.6)], [0.3, Color(1.0, 0.88, 0.45, 0.75)]]:
			var w: float = axis.length() * 0.32 * float(layer[0])
			var flicker := 1.0 + sin(t * 40.0) * 0.06
			draw_colored_polygon(PackedVector2Array([mouth_local + side * w * 0.12, mouth_local + axis * 1.08 + side * w * flicker, mouth_local + axis * 1.15, mouth_local + axis * 1.08 - side * w * flicker, mouth_local - side * w * 0.12]),
				Color(layer[1], (layer[1] as Color).a * _breath_fx))
	# 4. QTE / telegraph overlays
	# Shared QTE look: a translucent white target with shrinking hint rings on
	# each wing wrist and the head; every click ripples, a finished part pops
	# away. No numbers (QteStyle: progress is never shown).
	var qte_r := qte_zone_radius * 0.82
	if boss_state == BossState.AIRBORNE_DIVE_QTE:
		for part in DIVE_PARTS:
			var at := get_qte_part_local_position(part)
			var done := int(dive_clicks.get(part, 0)) >= clicks_per_part
			var pop_age := t - float(_qte_pop_at.get(part, -100.0))
			if not done:
				QteStyleScript.draw_target(self, at, qte_r, t + float(part) * 0.23)
			QteStyleScript.draw_pop(self, at, qte_r, pop_age / QteStyleScript.POP_TIME)
		if _qte_click_label:
			QteStyleScript.draw_click_label(self, get_qte_part_local_position(DivePart.HEAD), qte_r, t)
	elif boss_state == BossState.FIRE_BREATH_CHARGE:
		var head := get_qte_part_local_position(DivePart.HEAD)
		# Hint rings tighten as the breath is about to fire.
		QteStyleScript.draw_target(self, head, qte_r, t * (1.0 + 1.5 * (1.0 - clampf(_state_left / maxf(fire_breath_charge_duration, 0.01), 0.0, 1.0))))
		QteStyleScript.draw_pop(self, head, qte_r, (t - _breath_pop_at) / QteStyleScript.POP_TIME)
		if _qte_click_label:
			QteStyleScript.draw_click_label(self, head, qte_r, t)
	elif boss_state == BossState.WINGSTORM_TELEGRAPH:
		var fwd := Vector2.from_angle(_facing)
		for i in range(3):
			var phase := fmod(t * 2.0 + float(i) / 3.0, 1.0)
			draw_arc(fwd * (ART_R * 0.6 + phase * ART_R * 1.6), ART_R * (0.9 + phase * 0.6), _facing - 0.7, _facing + 0.7, 24, Color(0.55, 0.85, 1.0, 0.8 * (1.0 - phase)), 6.0)


## Phase two look: a red aura round the head and flames streaming back from
## both eyes (bigger while summoning wyrms); roar shockwaves on the switch.
func _draw_phase_two_fx(t: float) -> void:
	if _rage_glow <= 0.01:
		return
	var head := DragonNestArt.head_centre(ART_R, &"ancient", _lunge).rotated(_facing)
	var back := Vector2.from_angle(_facing + PI)
	var side := back.orthogonal()
	draw_circle(head, ART_R * 0.55, Color(1.0, 0.25, 0.08, 0.08 * _rage_glow))
	draw_circle(head, ART_R * 0.38, Color(1.0, 0.35, 0.1, 0.08 * _rage_glow))
	var blaze := 1.0
	var summoning := boss_state == BossState.SMOKE_BREATH and phase_two
	var summon_k := 0.0
	if summoning:
		summon_k = clampf(_smoke_phase().x, 0.0, 1.0)
		blaze = 1.0 + 1.4 * summon_k
	for eye in _eye_local_positions():
		draw_circle(eye, 16.0 * blaze, Color(1.0, 0.55, 0.15, 0.35 * _rage_glow))
		for k in range(4):
			var phase := fposmod(t * 2.6 + float(k) * 0.25 + eye.x * 0.01, 1.0)
			var length := (36.0 + 34.0 * blaze) * (0.5 + phase)
			var sway := sin(t * 9.0 + float(k) * 1.7) * 7.0
			var base := eye + back * 4.0
			var tip := eye + back * length + side * sway
			var w := (7.0 + 3.0 * blaze) * (1.0 - phase * 0.6)
			var flame := PackedVector2Array([base + side * w, tip, base - side * w])
			draw_colored_polygon(flame, Color(1.0, 0.38, 0.1, 0.75 * (1.0 - phase) * _rage_glow))
			draw_colored_polygon(PackedVector2Array([base + side * w * 0.45, eye + back * length * 0.6 + side * sway * 0.6, base - side * w * 0.45]), Color(1.0, 0.85, 0.4, 0.8 * (1.0 - phase) * _rage_glow))
		draw_circle(eye, 7.0, Color(1.0, 0.97, 0.85, _rage_glow))
	if boss_state == BossState.PHASE_TRANSITION:
		var elapsed := PHASE_TRANSITION_TIME - _state_left
		for k in range(3):
			var ring := fposmod(elapsed * 0.9 - float(k) * 0.33, 1.0)
			draw_arc(head, ART_R * (0.4 + ring * 2.6), 0.0, TAU, 64, Color(1.0, 0.45, 0.15, 0.55 * (1.0 - ring)), 10.0 * (1.0 - ring) + 2.0)
	if summoning:
		var k2 := summon_k
		var forward := Vector2.from_angle(_facing)
		for index in range(FIRE_WYRM_COUNT):
			var lane := (float(index) - float(FIRE_WYRM_COUNT - 1) * 0.5) * FIRE_WYRM_SPREAD
			var dir := forward.rotated(lane)
			draw_line(head + dir * 90.0, head + dir * (90.0 + 260.0 * k2), Color(1.0, 0.45, 0.12, 0.35 * k2), 14.0)


## Smoke breath: dark puffs pour from the mouth (exhale), roll to the ship
## (travel), then smother it while its weapons are jammed.
func _draw_smoke(t: float) -> void:
	var mouth := (DragonNestArt.head_centre(ART_R, &"ancient", _lunge) + Vector2(ART_R * 0.45, 0.0)).rotated(_facing)
	var target := to_local(_smoke_target)
	if boss_state == BossState.SMOKE_BREATH:
		var sp := _smoke_phase()
		var axis := target - mouth
		for k in range(26):
			var seed := float(k) * 7.31
			var along := fposmod(float(k) * 0.618034 + 0.07, 1.0)
			# Exhale grows the plume; travel pushes every puff toward the ship.
			var reach := clampf(sp.x * 0.35 + sp.y, 0.0, 1.0)
			var u := along * reach
			if u <= 0.0:
				continue
			var spread := axis.orthogonal().normalized() * sin(seed) * (20.0 + 140.0 * u)
			var p := mouth + axis * u + spread
			var r := 26.0 + 60.0 * u + 8.0 * sin(t * 3.0 + seed)
			var a := clampf(sp.x * 2.0, 0.0, 1.0)
			draw_circle(p, r * 1.08, Color(0.08, 0.07, 0.08, 0.45 * a))
			draw_circle(p, r, Color(0.36, 0.34, 0.35, 0.72 * a))
			draw_circle(p + Vector2(-r * 0.25, -r * 0.25), r * 0.6, Color(0.55, 0.53, 0.52, 0.45 * a))
	if _smoke_cover_left > 0.0:
		var fade := clampf(_smoke_cover_left / 0.6, 0.0, 1.0)
		for k in range(22):
			var seed := float(k) * 3.77
			var orbit := Vector2.from_angle(seed + t * (0.35 + 0.1 * sin(seed))) * (40.0 + fposmod(seed * 37.0, 150.0))
			var r := 46.0 + fposmod(seed * 53.0, 42.0)
			draw_circle(target + orbit, r, Color(0.1, 0.09, 0.1, 0.42 * fade))
			draw_circle(target + orbit + Vector2(-r * 0.3, -r * 0.3), r * 0.55, Color(0.22, 0.2, 0.21, 0.4 * fade))


func _die() -> void:
	if _is_dying:
		return
	_enter_state(BossState.DEAD)
	if _weapon_disruption_left > 0.0 and is_instance_valid(target_ship):
		(target_ship as Ship).set_weapon_attacks_enabled(true)
	_weapon_disruption_left = 0.0
	_release_smoke_blind()
	if _encounter_elapsed > 0.1:
		print("ANCIENT_DRAGON_METRICS: ", get_balance_metrics())
	super()


func _exit_tree() -> void:
	_release_smoke_blind()
	remove_from_group("boss_qte_targets")
