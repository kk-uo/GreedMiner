class_name StoneHeartEffect
extends MagicArtifactEffect

## Stone Heart battle runtime. Armor is a separate pool and never changes the
## hull's maximum health. A break produces one exact-damage radial shockwave,
## then begins one non-resetting regeneration countdown.

signal armor_changed(current_armor: float, maximum_armor: float)
signal armor_shattered
signal armor_restored
signal shockwave_triggered(center: Vector2, radius: float, damage: float, knockback: float)

var maximum_armor: float = 30.0
var shockwave_radius: float = 100.0
var shockwave_damage: float = 25.0
var knockback_distance: float = 100.0
var regeneration_delay: float = 30.0

const ArmorVisual := preload("res://Scripts/VFX/StoneHeartArmorVisual.gd")

var current_armor: float = 0.0
var _regeneration_remaining: float = 0.0
var _break_triggered_for_cycle: bool = false
## Rock chunks drawn on the hull (a child of the ship, so it moves with it).
var _visual: Node2D


func configure(artifact_definition: MagicArtifactDefinition, target_ship: Ship) -> void:
	super(artifact_definition, target_ship)
	var parameters := artifact_definition.effect_parameters
	maximum_armor = maxf(float(parameters.get("armor_hp", maximum_armor)), 0.0)
	shockwave_radius = maxf(float(parameters.get("shockwave_radius", shockwave_radius)), 0.0)
	shockwave_damage = maxf(float(parameters.get("shockwave_damage", shockwave_damage)), 0.0)
	knockback_distance = maxf(float(parameters.get("knockback_distance", knockback_distance)), 0.0)
	regeneration_delay = maxf(float(parameters.get("regeneration_delay", regeneration_delay)), 0.0)
	current_armor = maximum_armor


func _ready() -> void:
	if not is_instance_valid(ship):
		queue_free()
		return
	ship.register_damage_interceptor(Callable(self, "absorb_damage"))
	_visual = ArmorVisual.new()
	_visual.name = "StoneHeartArmor"
	_visual.setup(self)
	ship.add_child(_visual)
	armor_changed.emit(current_armor, maximum_armor)


func _process(delta: float) -> void:
	if current_armor > 0.0 or _regeneration_remaining <= 0.0:
		return
	_regeneration_remaining = maxf(_regeneration_remaining - delta, 0.0)
	if _regeneration_remaining <= 0.0:
		current_armor = maximum_armor
		_break_triggered_for_cycle = false
		armor_changed.emit(current_armor, maximum_armor)
		armor_restored.emit()


## Returns damage that remains for the normal hull pipeline.
func absorb_damage(incoming_damage: float) -> float:
	if incoming_damage <= 0.0 or current_armor <= 0.0:
		return maxf(incoming_damage, 0.0)
	var absorbed := minf(current_armor, incoming_damage)
	current_armor = maxf(current_armor - absorbed, 0.0)
	armor_changed.emit(current_armor, maximum_armor)
	var remaining := maxf(incoming_damage - absorbed, 0.0)
	if current_armor <= 0.0 and not _break_triggered_for_cycle:
		_break_triggered_for_cycle = true
		_regeneration_remaining = regeneration_delay
		armor_shattered.emit()
		_emit_shockwave()
		if regeneration_delay <= 0.0:
			current_armor = maximum_armor
			_break_triggered_for_cycle = false
			armor_changed.emit(current_armor, maximum_armor)
			armor_restored.emit()
	return remaining


## Physics-shape overlap includes enemies whose bodies cross the radius even
## when their centers do not. Instance IDs prevent duplicate damage per break.
func _emit_shockwave() -> void:
	if not is_inside_tree() or not is_instance_valid(ship):
		return
	var center := ship.to_global(Ship.SHIP_SIZE * 0.5)
	var circle := CircleShape2D.new()
	circle.radius = shockwave_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var affected: Dictionary = {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 512):
		var enemy := hit.get("collider") as BasicEnemy
		if enemy != null and not enemy.is_dying():
			affected[enemy.get_instance_id()] = enemy

	var battlefield := ship.get_parent().get_node_or_null("Battlefield") as Battlefield
	var bounds := battlefield.get_world_bounds() if battlefield != null else Rect2()
	for value in affected.values():
		var enemy := value as BasicEnemy
		if not is_instance_valid(enemy) or enemy.is_dying():
			continue
		enemy.take_damage(shockwave_damage, true)
		if (
			is_instance_valid(enemy)
			and not enemy.is_dying()
			and enemy.enemy_tier != BasicEnemy.EnemyTier.BOSS
		):
			enemy.apply_radial_knockback(center, knockback_distance, bounds)
	shockwave_triggered.emit(center, shockwave_radius, shockwave_damage, knockback_distance)


func get_regeneration_remaining() -> float:
	return _regeneration_remaining


func cleanup() -> void:
	if is_instance_valid(ship):
		ship.unregister_damage_interceptor(Callable(self, "absorb_damage"))
	_free_visual()
	current_armor = 0.0
	_regeneration_remaining = 0.0
	queue_free()


func _exit_tree() -> void:
	if is_instance_valid(ship):
		ship.unregister_damage_interceptor(Callable(self, "absorb_damage"))
	_free_visual()


func _free_visual() -> void:
	if is_instance_valid(_visual):
		_visual.queue_free()
	_visual = null

