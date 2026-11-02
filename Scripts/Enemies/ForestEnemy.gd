class_name ForestEnemy
extends RangedEnemy

## The fairy heals ONE nearby wounded treant each pulse while moving. Once it
## reaches the ship's attack range, it commits to attacking for the rest of its life.
@export_range(0.0, 500.0, 1.0) var heal_amount: float = 50.0
@export_range(0.0, 500.0, 1.0) var heal_radius: float = 120.0
@export_range(0.1, 30.0, 0.1) var heal_interval: float = 1.0
var committed_to_attack: bool = false
var _heal_time: float = 0.0
@export_range(0.0, 5.0, 0.1) var emerge_duration: float = 1.1
var _emerge_left: float = 0.0
## Presentation: walk cycle clock and a throttled redraw (forest packs are big).
const REDRAW_INTERVAL: float = 1.0 / 12.0
var _anim_time: float = 0.0
var _redraw_wait: float = 0.0
## Far-away melee trees need not recalculate ship and dwarf steering 60 times/s.
## Timers still run in the engine, and accumulated delta preserves movement.
@export_range(0.02, 0.5, 0.01) var distant_ai_interval: float = 0.1
@export_range(100.0, 1200.0, 10.0) var full_rate_distance: float = 360.0
var _ai_accumulator: float = 0.0
var _batch_crown_visible: bool = false
var _batch_local_until_ms: int = 0
var _scheduler_far: bool = false

func _ready() -> void:
	super()
	if enemy_id == &"fairy":
		# Keep the one-second healing rate while avoiding synchronized scans.
		_heal_time = -_dwarf_search_schedule.phase_delay(0.2)
	if enemy_id in [&"treant", &"big_treant"]:
		_emerge_left = emerge_duration
		# Spawners set the position right after add_child, so wait a frame.
		_play_emerge_sound.call_deferred()
		# Every treant is drawn by the forest's MultiMesh batch when there is one.
		var batch := get_tree().get_first_node_in_group(&"forest_treant_batch")
		if batch != null:
			batch.call("register", self)
	_anim_time = randf() * 10.0
	_ai_accumulator = randf() * distant_ai_interval


func _play_emerge_sound() -> void:
	if is_inside_tree() and emerge_duration > 0.0:
		EnemySfx.play(self, SFX_RISE, -10.0, 0.1, 0.75 if enemy_id == &"big_treant" else 1.0)

func _process(delta: float) -> void:
	# Hit flash and emergence redraw every frame; the walk cycle / facing only
	# about 12 times a second so big forest packs stay cheap.
	_anim_time += delta
	var reacting := _hit_flash_time > 0.0 or _hit_jiggle > 0.0
	_update_hit_feedback(delta)
	if _batch_crown_visible:
		# The batch draws this tree from our rotation / scale / self_modulate;
		# only the hit feedback needs ticking, then processing stops again.
		if not reacting:
			set_process(false)
		return
	if reacting:
		queue_redraw()
		return
	if _batch_crown_visible:
		return
	_redraw_wait -= delta
	if _redraw_wait <= 0.0:
		_redraw_wait = REDRAW_INTERVAL
		queue_redraw()

func _physics_process(delta: float) -> void:
	var battle := get_tree().current_scene
	if battle != null and battle.get("_battle_ended") == true:
		_stop_attacking()
		return
	if _emerge_left > 0.0:
		_emerge_left = maxf(0.0, _emerge_left - delta)
		return
	if enemy_id != &"fairy":
		if enemy_id in [&"treant", &"big_treant"] and is_instance_valid(target_ship) and not _is_dying:
			if is_far_from_ship():
				_ai_accumulator += delta
				if _ai_accumulator < distant_ai_interval:
					return
				delta = _ai_accumulator
				_ai_accumulator = 0.0
			else:
				delta += _ai_accumulator
				_ai_accumulator = 0.0
		super(delta)
		return
	if _is_dying or not is_instance_valid(target_ship) or not target_ship is Ship:
		_stop_attacking()
		return
	var ship := target_ship as Ship
	if ship.current_hp <= 0.0:
		_stop_attacking()
		return
	var closest := _get_nearest_ship_boundary_world(ship, global_position)
	var to_ship := closest - global_position
	var distance := to_ship.length()
	if distance > 0.01:
		_facing = to_ship.angle()
	if distance <= attack_range + ATTACK_RANGE_TOLERANCE:
		committed_to_attack = true
	if committed_to_attack:
		if distance <= attack_range + ATTACK_RANGE_TOLERANCE:
			_start_attacking()
			# Keep walking tangentially instead of stopping while shooting.
			global_position += to_ship.normalized().orthogonal() * get_effective_move_speed() * delta
		else:
			_stop_attacking()
			global_position = global_position.move_toward(closest, get_effective_move_speed() * delta)
	else:
		_stop_attacking()
		global_position = global_position.move_toward(closest, get_effective_move_speed() * delta)
		_heal_time += delta
		if _heal_time >= heal_interval:
			_heal_time = 0.0
			_heal_nearest_treant()

func _heal_nearest_treant() -> void:
	var selected: ForestEnemy
	var shortest := heal_radius
	for node in get_tree().get_nodes_in_group("enemies"):
		var tree_enemy := node as ForestEnemy
		if tree_enemy == null or tree_enemy == self or tree_enemy.is_dying():
			continue
		if tree_enemy.enemy_id not in [&"treant", &"big_treant"] or tree_enemy.get_current_health() >= tree_enemy.max_health:
			continue
		var distance := global_position.distance_to(tree_enemy.global_position)
		if distance <= shortest:
			selected = tree_enemy
			shortest = distance
	if selected != null:
		selected.heal(heal_amount)
		EnemySfx.play(selected, SFX_FAIRY_HEAL, -6.0, 0.06)

func heal(amount: float) -> float:
	if _is_dying or amount <= 0.0:
		return 0.0
	var previous := _current_health
	_current_health = minf(max_health, _current_health + amount)
	if _current_health > previous:
		health_changed.emit(_current_health, max_health)
	return _current_health - previous

func _perform_attack(ship: Ship) -> void:
	if enemy_id == &"fairy":
		super(ship)
		EnemySfx.play(self, SFX_FAIRY_ATTACK, -5.0)
	else:
		ship.take_damage(attack_damage)
		if enemy_id in [&"treant", &"big_treant"]:
			EnemySfx.play(self, SFX_TREANT_ATTACK, -11.0, 0.08, 0.8 if enemy_id == &"big_treant" else 1.0)

func _on_attack_timer_timeout() -> void:
	if enemy_id == &"fairy" and is_instance_valid(target_ship):
		var closest := _get_nearest_ship_boundary_world(target_ship as Ship, global_position)
		if global_position.distance_to(closest) > attack_range + ATTACK_RANGE_TOLERANCE:
			_stop_attacking()
			return
	super()

func _get_visual_radius() -> float:
	return 10.0 if enemy_id == &"fairy" else (30.0 if enemy_id == &"big_treant" else 17.0)


func is_far_from_ship() -> bool:
	if not is_instance_valid(target_ship) or not target_ship is Ship:
		return false
	var ship_center := (target_ship as Ship).global_position + Ship.SHIP_SIZE * 0.5
	return global_position.distance_squared_to(ship_center) > full_rate_distance * full_rate_distance

func _draw() -> void:
	if enemy_id == &"fairy":
		ForestVisual.draw_fairy(self, _facing, _is_flashing(), _anim_time)
		return
	if _batch_crown_visible:
		return
	var rise := 1.0 - _emerge_left / maxf(emerge_duration, 0.001)
	var step := 0.0 if (_is_attacking or _emerge_left > 0.0) else sin(_anim_time * TAU * 1.4)
	# Far ordinary trees share a low-detail mesh during emergence. Close trees
	# retain the exact source-tree crown and the original hit/step animation.
	var draw_crown: Dictionary
	var distant_scale := 1.0
	var far := enemy_id in [&"treant", &"big_treant"] and is_far_from_ship()
	if far:
		var info: Dictionary = get_meta("forest_crown", {})
		var giant := enemy_id == &"big_treant" and bool(info.get("giant", false))
		draw_crown = ForestVisual.shared_distant_crown(int(info.get("seed", get_instance_id())), giant)
		distant_scale = float(info.get("radius", 46.0 if giant else 40.0)) / (46.0 if giant else 40.0)
	else:
		if _crown.is_empty():
			_crown = _build_crown()
		draw_crown = _crown
	var big := enemy_id == &"big_treant"
	var swell := 1.0 + (BIG_CROWN_SCALE - 1.0) * clampf((rise - 0.45) / 0.55, 0.0, 1.0) if big else 1.0
	ForestVisual.draw_walking_tree(self, draw_crown, _facing, step, _is_flashing(), rise, _anim_time, swell * distant_scale, true, not far)


func set_batch_crown_visible(value: bool) -> void:
	if _batch_crown_visible == value:
		return
	_batch_crown_visible = value
	# Batched trees are drawn by ForestTreantBatch; they only process while a
	# hit reaction is running (see take_damage / register_click).
	set_process(not value or _hit_flash_time > 0.0 or _hit_jiggle > 0.0)
	queue_redraw()


func can_batch_visual() -> bool:
	return true


## Hits no longer pull a tree out of the batch (that turned every laser sweep
## into hundreds of individual redraws); they only wake the hit feedback.
func take_damage(damage: float, ignore_damage_reduction: bool = false, count_for_artifact: bool = true, source_weapon: WeaponModule = null) -> void:
	var previous := get_current_health()
	super(damage, ignore_damage_reduction, count_for_artifact, source_weapon)
	if get_current_health() < previous and _batch_crown_visible and not _is_dying:
		set_process(true)


func register_click() -> bool:
	var registered := super()
	if registered and _batch_crown_visible:
		set_process(true)
	return registered


## Presentation: the walking-tree crown (ForestVisual.build_tree_crown),
## taken from the tree this treant rose from (meta "forest_crown", set by
## ForestRingRaise); a stand-in crown when spawned some other way.
const BIG_CROWN_SCALE: float = 1.4
var _crown: Dictionary = {}


func _build_crown() -> Dictionary:
	var info: Dictionary = get_meta("forest_crown", {})
	var radius := float(info.get("radius", 40.0 if enemy_id == &"treant" else 46.0))
	var seed_value := int(info.get("seed", get_instance_id() % 100000))
	return ForestVisual.build_tree_crown(radius, seed_value, bool(info.get("giant", false)))


## Presentation: forest sounds (rise, attacks, fairy heal, deaths).
const SFX_RISE := preload("res://Assets/Audio/Enemies/Forest/treant_rise.wav")
const SFX_TREANT_ATTACK := preload("res://Assets/Audio/Enemies/Forest/treant_attack.wav")
const SFX_TREANT_DEATH := preload("res://Assets/Audio/Enemies/Forest/treant_death.wav")
const SFX_FAIRY_ATTACK := preload("res://Assets/Audio/Enemies/Forest/fairy_attack.wav")
const SFX_FAIRY_HEAL := preload("res://Assets/Audio/Enemies/Forest/fairy_heal.wav")
const SFX_FAIRY_DEATH := preload("res://Assets/Audio/Enemies/Forest/fairy_death.wav")
const SFX_BOSS_DEATH := preload("res://Assets/Audio/Enemies/Forest/boss_death.wav")


func _spawn_death_visual(death_position: Vector2) -> void:
	super(death_position)
	match enemy_id:
		&"fairy":
			EnemySfx.play(death_position, SFX_FAIRY_DEATH, -6.0)
		&"chainsaw_spaceship_treant":
			EnemySfx.play(death_position, SFX_BOSS_DEATH, -1.0, 0.0)
		_:
			EnemySfx.play(death_position, SFX_TREANT_DEATH, -9.0, 0.08, 0.75 if enemy_id == &"big_treant" else 1.0)
