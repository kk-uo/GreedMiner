class_name SiegeCannon
extends FusionWeapon

## Map-wide artillery: each volley marks the densest enemy-centered blast.
## No range or turret aim gate is used. The existing FusionProjectile resolves
## the impact so damage attribution, artifacts and boss hits stay consistent.
const AIRSTRIKE := preload("res://Scripts/Modules/Fusion/SiegeAirstrike.gd")

@export_range(0.0, 3.0, 0.05) var mark_duration: float = 0.6
@export_range(0.05, 3.0, 0.05) var fall_duration: float = 0.4


func _process(delta: float) -> void:
	_visual_rotation = fmod(_visual_rotation + delta * 8.0, TAU)
	queue_redraw()
	if assembly_mode:
		_deactivate()
		return
	var rate := get_fire_rate()
	if rate <= 0.0:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return
	if _fire_at_selected_impact():
		_cooldown = 1.0 / rate


func fire() -> void:
	if assembly_mode:
		return
	_fire_at_selected_impact()


func _fire_at_selected_impact() -> bool:
	var impact: Vector2
	if is_manual_control_active():
		if not has_valid_manual_aim(_turret.global_position):
			return false
		current_target = null
		impact = get_manual_aim_world_position()
	else:
		var target := _densest_target(get_tree().get_nodes_in_group(&"enemies"), aoe_radius)
		if target == null:
			return false
		current_target = target
		impact = target.global_position
	_turret.look_at(impact)
	_spawn_strike(impact)
	return true


func _spawn_strike(impact: Vector2) -> void:
	if projectile_scene == null:
		push_error("SiegeCannon: projectile scene is missing.")
		return
	begin_artifact_attack()
	var strike_count := 1 + get_artifact_projectile_count_bonus()
	for index in range(strike_count):
		var strike := AIRSTRIKE.new()
		strike.source_weapon = self
		strike.projectile_scene = projectile_scene
		strike.damage = get_modified_explosion_damage(get_damage())
		strike.blast_radius = aoe_radius
		strike.shell_radius = get_modified_projectile_range(projectile_range)
		strike.mark_duration = mark_duration
		# Airstrike shells do not travel in a straight line; their fall time is
		# inverse to the same projectile-speed multiplier as other cannon shells.
		strike.fall_duration = fall_duration * projectile_speed / maxf(get_modified_projectile_speed(projectile_speed), 0.001)
		get_tree().current_scene.add_child(strike)
		# Keep twin shells distinct while landing inside the selected enemy pack.
		var lateral := Vector2(12.0 * (float(index) - float(strike_count - 1) * 0.5), 0.0)
		strike.global_position = impact + lateral
	var launch := AIRSTRIKE.LaunchFx.new()
	get_tree().current_scene.add_child(launch)
	launch.global_position = _turret.global_position
	_play_attack_sound()
	end_artifact_attack()


## The target point is always an enemy, never an empty grid cell. A spatial
## hash limits the search to nearby cells; ties retain group order instead of
## reverting to highest-health targeting.
static func _densest_target(entries: Array[Node], radius: float) -> BasicEnemy:
	var valid: Array[BasicEnemy] = []
	var cells: Dictionary = {}
	var cell_size := maxf(radius, 1.0)
	for node in entries:
		var enemy := node as BasicEnemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dying() or not enemy.is_inside_tree():
			continue
		valid.append(enemy)
		var cell := Vector2i(floori(enemy.global_position.x / cell_size), floori(enemy.global_position.y / cell_size))
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(enemy)
	var best: BasicEnemy
	var best_count := 0
	var radius_sq := radius * radius
	for candidate in valid:
		var center := candidate.global_position
		var cell := Vector2i(floori(center.x / cell_size), floori(center.y / cell_size))
		var count := 0
		for y in range(cell.y - 1, cell.y + 2):
			for x in range(cell.x - 1, cell.x + 2):
				for neighbor in cells.get(Vector2i(x, y), []):
					if center.distance_squared_to((neighbor as BasicEnemy).global_position) <= radius_sq:
						count += 1
		if count > best_count:
			best = candidate
			best_count = count
			if count == valid.size():
				break
	return best
