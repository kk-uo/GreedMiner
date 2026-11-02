class_name DragonNestController
extends Node2D

const HOARD_SCRIPT := preload("res://Scripts/Battle/DragonNest/DragonHoard.gd")
const HUD_SCRIPT := preload("res://Scripts/Battle/DragonNest/DragonNestHud.gd")
const FIXED_MAP_SCENE := preload("res://Scenes/Battle/DragonNest/dragon_nest_map.tscn")

var battle: Node2D
var battlefield: Battlefield
var ship: Ship
var wave_manager: WaveManager
var enemies: Node2D

var greed: int = 0
var hoards: Array[DragonHoard] = []
var guardians: Array[DragonEnemy] = []
var boss: AncientDragon
var _active_hoard: DragonHoard
var _last_ship_hp: float = 0.0
var _hud: DragonNestHud
var _entrance_position: Vector2
## Boss anchors in the left [0] and right [1] tunnels (body centre).
var _gate_positions: Array[Vector2] = []
var _ship_center: Vector2
var _boss_view_applied: bool = false
var _fixed_map: DragonNestFixedMap
## Hoard egg positions wander a little each battle (Claude sync 90).
const HOARD_JITTER := Vector2(60.0, 45.0)
const HOARD_MAX_REACH: float = 540.0


func configure(owner_battle: Node2D, field: Battlefield, player_ship: Ship, waves: WaveManager, enemy_container: Node2D) -> void:
	battle = owner_battle
	battlefield = field
	ship = player_ship
	wave_manager = waves
	enemies = enemy_container


func _ready() -> void:
	if battlefield == null or ship == null or wave_manager == null or enemies == null:
		push_error("DragonNestController requires battle, battlefield, ship, waves, and enemies.")
		set_process(false)
		return
	_last_ship_hp = ship.current_hp
	_build_fixed_layout()
	enemies.child_entered_tree.connect(_on_enemy_entered)
	for child in enemies.get_children():
		_on_enemy_entered(child)
	_hud = HUD_SCRIPT.new() as DragonNestHud
	_hud.controller = self
	battle.add_child(_hud)
	queue_redraw()


func _process(_delta: float) -> void:
	if is_instance_valid(boss) and ship.current_hp > _last_ship_hp:
		boss.record_healing(ship.current_hp - _last_ship_hp)
	_last_ship_hp = ship.current_hp


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if battle != null and battle.has_method("is_ship_input_frozen") and battle.call("is_ship_input_frozen"):
		return
	var world_position := get_global_mouse_position()
	if is_instance_valid(_active_hoard):
		if _active_hoard.route_click(world_position):
			get_viewport().set_input_as_handled()
		return
	for hoard in hoards:
		if hoard.route_click(world_position):
			get_viewport().set_input_as_handled()
			return


func _build_fixed_layout() -> void:
	var bounds := battlefield.get_world_bounds()
	var safe_bounds := bounds.grow(-90.0)
	var ship_center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	_ship_center = ship_center
	_gate_positions = [
		(ship_center + Vector2(-DragonNestRules.BOSS_ANCHOR_X, 0.0)).clamp(safe_bounds.position, safe_bounds.end),
		(ship_center + Vector2(DragonNestRules.BOSS_ANCHOR_X, 0.0)).clamp(safe_bounds.position, safe_bounds.end),
	]
	# The Ancient Dragon first appears in the right-hand tunnel.
	_entrance_position = _gate_positions[1]
	# One random seed per battle drives the hoard jitter and every scattered
	# prop in the lair. (Battlefield's own seed is pinned to the fixed hall by
	# BattleMain; a test can still pin the lair through Battlefield.map_seed.)
	var lair_seed := battlefield.map_seed if battlefield.map_seed != 0 else randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = lair_seed
	var fixed_positions: Array[Vector2] = []
	for data in DragonNestRules.HOARDS:
		var jitter := Vector2(rng.randf_range(-HOARD_JITTER.x, HOARD_JITTER.x), rng.randf_range(-HOARD_JITTER.y, HOARD_JITTER.y))
		# Stay within HOARD_MAX_REACH so the parked ship can still steal.
		var offset := ((data["offset"] as Vector2) + jitter).limit_length(HOARD_MAX_REACH)
		fixed_positions.append((ship_center + offset).clamp(safe_bounds.position, safe_bounds.end))
	var fixed_map := FIXED_MAP_SCENE.instantiate() as DragonNestFixedMap
	add_child(fixed_map)
	fixed_map.configure(ship_center, fixed_positions, _entrance_position, lair_seed)
	_fixed_map = fixed_map
	for index in range(DragonNestRules.HOARDS.size()):
		var data := DragonNestRules.HOARDS[index]
		var hoard := HOARD_SCRIPT.new() as DragonHoard
		hoard.hoard_id = StringName(data["id"])
		hoard.display_name = String(data["label"])
		hoard.reward_per_success = int(data["reward"])
		hoard.maximum_successes = int(data["steals"])
		hoard.pile_radius = float(data.get("pile", 90.0))
		# The whole treasure mountain is clickable, not just its middle.
		hoard.interaction_radius = maxf(hoard.interaction_radius, hoard.pile_radius * 0.75)
		hoard.z_index = -15
		add_child(hoard)
		hoard.global_position = fixed_positions[index]
		hoard.attempt_started.connect(_on_hoard_attempt_started)
		hoard.steal_succeeded.connect(_on_hoard_steal_succeeded)
		hoard.steal_failed.connect(_on_hoard_attempt_failed)
		hoards.append(hoard)

		var guardian := EnemyCatalog.instantiate_enemy(StringName(data["guardian"])) as DragonEnemy
		if guardian == null:
			push_error("Dragon Nest guardian scene missing: %s" % data["guardian"])
			continue
		guardian.guardian_mode = true
		guardian.target_ship = ship
		guardian.set_meta("dragon_nest_guardian", true)
		add_child(guardian)
		# Asleep, curled up on the throne behind its hoard.
		var away := ship_center.direction_to(hoard.global_position)
		guardian.global_position = hoard.global_position + away * DragonNestRules.throne_offset(hoard.pile_radius)
		guardian._facing = (-away).angle() + PI * 0.5
		guardian.apply_greed(greed)
		guardians.append(guardian)


func _on_hoard_attempt_started(hoard: DragonHoard) -> void:
	if is_instance_valid(_active_hoard) and _active_hoard != hoard:
		return
	_active_hoard = hoard
	var guardian := get_guardian_for_hoard(hoard)
	if is_instance_valid(guardian):
		guardian.wake_guardian()


func _on_hoard_steal_succeeded(hoard: DragonHoard, reward: int) -> void:
	ResourceManager.add_mission_ore(float(reward), &"treasure")
	set_greed(greed + 1)
	var guardian := get_guardian_for_hoard(hoard)
	if hoard.successful_steals >= 3 and is_instance_valid(guardian):
		guardian.enrage_guardian()
	_active_hoard = null


func _on_hoard_attempt_failed(_hoard: DragonHoard) -> void:
	_active_hoard = null


func get_guardian_for_hoard(hoard: DragonHoard) -> DragonEnemy:
	var index := hoards.find(hoard)
	return guardians[index] if index >= 0 and index < guardians.size() and is_instance_valid(guardians[index]) else null


func set_greed(value: int) -> void:
	greed = clampi(value, 0, DragonNestRules.MAX_GREED)
	for guardian in guardians:
		if is_instance_valid(guardian):
			guardian.apply_greed(greed)
	if is_instance_valid(boss):
		boss.apply_greed(greed)


func _on_enemy_entered(node: Node) -> void:
	var ancient := node as AncientDragon
	if ancient == null:
		return
	boss = ancient
	if boss.is_node_ready():
		boss.apply_greed(greed)
	else:
		boss.ready.connect(_on_boss_ready.bind(boss), CONNECT_ONE_SHOT)
	boss.set_deferred("global_position", _entrance_position)
	_setup_boss.call_deferred(boss)
	boss.tree_exiting.connect(_on_boss_exiting, CONNECT_ONE_SHOT)


## Puts the boss in its tunnel (half of it stays inside), plays the entrance
## (a shadow sweeps over the hall, then it descends) and widens the view.
func _setup_boss(ancient: AncientDragon) -> void:
	if not is_instance_valid(ancient) or ancient != boss:
		return
	ancient.configure_lair(_gate_positions, _ship_center, 1)
	if not ancient.phase_two_started.is_connected(_on_boss_phase_two):
		ancient.phase_two_started.connect(_on_boss_phase_two)
	_widen_view_for_boss()


## Phase two: the lair rages and every egg the player left on a hoard hatches
## into a young dragon (the more you stole, the fewer hatch).
func _on_boss_phase_two() -> void:
	if is_instance_valid(_fixed_map):
		_fixed_map.set_raging(true)
	hatch_remaining_eggs()


func hatch_remaining_eggs() -> int:
	var hatched := 0
	for hoard in hoards:
		if not is_instance_valid(hoard) or not hoard.hatch_egg():
			continue
		var hatchling := EnemyCatalog.instantiate_enemy(&"young_dragon") as DragonEnemy
		if hatchling == null:
			continue
		hatchling.target_ship = ship
		hatchling.set_meta("dragon_nest_boss_summon", true)
		hatchling.set_meta("spawn_origin", &"dragon_nest_boss_summon")
		hatchling.set_meta("dragon_nest_hatchling", true)
		enemies.add_child(hatchling)
		hatchling.global_position = hoard.global_position + Vector2(0.0, -6.0)
		hatchling.apply_greed(greed)
		hatched += 1
	return hatched


func _widen_view_for_boss() -> void:
	if _boss_view_applied or ship == null or ship.world_camera == null:
		return
	_boss_view_applied = true
	var camera := ship.world_camera
	var view_width := get_viewport_rect().size.x / maxf(camera.zoom.x, 0.001)
	var target := camera.zoom * view_width / (view_width + DragonNestRules.BOSS_VIEW_EXTRA)
	var tween := create_tween()
	tween.tween_property(camera, "zoom", target, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_boss_ready(ancient: AncientDragon) -> void:
	if is_instance_valid(ancient) and ancient == boss:
		ancient.apply_greed(greed)


func _on_boss_exiting() -> void:
	boss = null


func get_live_guardian_count() -> int:
	var count := 0
	for guardian in guardians:
		if is_instance_valid(guardian) and not guardian.is_dying():
			count += 1
	return count


func get_pending_scheduled_count() -> int:
	var accounting := wave_manager.get_spawn_accounting()
	return int(accounting.get("scheduled_remaining", 0)) + wave_manager.get_pending_external_spawn_count()


func get_entrance_position() -> Vector2:
	return _entrance_position


func _draw() -> void:
	pass


func developer_jump_to_wave(wave_number: int) -> void:
	if not DeveloperCommands.is_available():
		return
	battle.set_meta("suppress_planet_completion_progress", developer_jump_suppresses_progress(wave_number))
	wave_manager.stop_wave_system(&"dragon_nest_developer_jump")
	ship.set_weapon_attacks_enabled(true)
	for child in enemies.get_children():
		var enemy := child as BasicEnemy
		if enemy != null:
			enemy.set_death_effects_enabled(false)
		child.queue_free()
	await get_tree().process_frame
	wave_manager.start_wave_system(clampi(wave_number, 1, 11))


func developer_jump_suppresses_progress(wave_number: int) -> bool:
	return wave_number > 1


func developer_spawn_enemy(enemy_id: StringName) -> BasicEnemy:
	if not DeveloperCommands.is_available():
		return null
	var enemy := EnemyCatalog.instantiate_enemy(enemy_id)
	if enemy == null:
		return null
	if enemy is AncientDragon:
		(enemy as AncientDragon).young_dragon_scene = EnemyCatalog.get_enemy_scene(&"young_dragon")
	enemy.target_ship = ship
	enemy.set_meta("spawn_origin", &"developer")
	enemies.add_child(enemy)
	enemy.global_position = _entrance_position
	return enemy


func get_gate_positions() -> Array[Vector2]:
	return _gate_positions


func developer_nearly_empty_segment() -> void:
	if DeveloperCommands.is_available() and is_instance_valid(boss):
		boss.force_nearly_empty_segment()


func developer_trigger_dive() -> void:
	if DeveloperCommands.is_available() and is_instance_valid(boss):
		boss.force_dive_qte()


func developer_trigger_breath() -> void:
	if DeveloperCommands.is_available() and is_instance_valid(boss):
		boss.start_fire_breath()


func developer_spawn_reinforcements() -> void:
	if DeveloperCommands.is_available() and is_instance_valid(boss):
		boss.spawn_reinforcements()


func developer_set_ship_hp(value: float) -> void:
	if not DeveloperCommands.is_available() or not is_instance_valid(ship):
		return
	ship.current_hp = clampf(value, 1.0, ship.max_hp)
	ship.health_changed.emit(ship.current_hp, ship.max_hp)


func developer_reset_session() -> void:
	if not DeveloperCommands.is_available():
		return
	ResourceManager.start_new_mission()
	ResourceManager.set_current_expedition_planet(DragonNestRules.PLANET_ID)
	get_tree().reload_current_scene()


func _exit_tree() -> void:
	if is_instance_valid(_active_hoard):
		_active_hoard.cancel_attempt()
