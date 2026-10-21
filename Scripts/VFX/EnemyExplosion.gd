extends Node2D

## Blast left by an exploding enemy (Red Rock, Goblin Engineer) or a dynamite
## stick. After a short fuse delay (so chain reactions ripple outward instead
## of all popping on one frame) it damages every enemy whose body is within
## radius - friend or foe alike - and, when hurt_ship is set, the ship if its
## hull is within radius. Then it plays a flat style-A fireball and frees.
##
## Create it with spawn(); damage_enemies = false makes a ship-only blast.

const LIFE: float = 0.62
const FUSE: float = 0.06

const FIRE_CORE := Color("FFF4C2")
const FIRE_HOT := Color("FFC23A")
const FIRE_MID := Color("F07A24")
const FIRE_DARK := Color("B8432A")
const SMOKE := Color("4A3F38")
const SHOCK := Color("FFF4E0")

var radius: float = 70.0
var damage: float = 20.0
var damage_enemies: bool = true
var hurt_ship: bool = true
var ship: Node2D = null
## Enemy that caused the blast (never damaged by its own explosion).
var source: Node = null

var _age: float = 0.0
var _applied: bool = false
var _debris: Array[Dictionary] = []


## Adds a blast to parent at a world position. Safe inside physics callbacks.
static func spawn(parent: Node, world_position: Vector2, blast_radius: float, blast_damage: float,
		target_ship: Node2D, blast_source: Node = null, enemies_too: bool = true) -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var blast: Node2D = load("res://Scripts/VFX/EnemyExplosion.gd").new()
	blast.radius = blast_radius
	blast.damage = blast_damage
	blast.ship = target_ship
	blast.source = blast_source
	blast.damage_enemies = enemies_too
	blast.z_as_relative = false
	blast.z_index = 20
	blast.position = parent.to_local(world_position) if parent is Node2D else world_position
	parent.call_deferred("add_child", blast)
	return blast


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in range(12):
		var angle: float = TAU * float(index) / 12.0 + rng.randf_range(-0.2, 0.2)
		_debris.append({
			"dir": Vector2.RIGHT.rotated(angle),
			"speed": rng.randf_range(0.7, 1.15),
			"size": rng.randf_range(2.0, 3.6),
			"spin": rng.randf_range(-9.0, 9.0),
			"dark": index % 3 == 0,
		})


func _process(delta: float) -> void:
	_age += delta
	if not _applied and _age >= FUSE:
		_applied = true
		_apply_damage()
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _apply_damage() -> void:
	var center := global_position
	for node in get_tree().get_nodes_in_group("mining_dwarves"):
		if is_instance_valid(node) and node.has_method("is_enemy_targetable") and node.call("is_enemy_targetable") and center.distance_to(node.call("get_enemy_target_position")) <= radius:
			node.call("take_damage", damage)
	if damage_enemies:
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as BasicEnemy
			if enemy == null or enemy == source or enemy.is_dying():
				continue
			var body_point: Vector2 = enemy.get_target_point(center)
			if center.distance_to(body_point) <= radius + enemy._get_visual_radius() * 0.5:
				# Enemy-origin damage does not count as ship damage for artifacts.
				enemy.take_damage(damage, false, false)
	if hurt_ship and is_instance_valid(ship) and ship is Ship:
		var hull := ship as Ship
		if hull.current_hp > 0.0 and _distance_to_hull(hull, center) <= radius:
			hull.take_damage(damage)


## Distance from a world point to the ship grid's outer boundary (0 inside).
static func _distance_to_hull(hull: Ship, world_point: Vector2) -> float:
	var local: Vector2 = hull.to_local(world_point)
	var size: Vector2 = Ship.SHIP_SIZE
	var clamped := Vector2(clampf(local.x, 0.0, size.x), clampf(local.y, 0.0, size.y))
	var scale_factor: float = hull.global_transform.get_scale().x
	return local.distance_to(clamped) * absf(scale_factor)


func _draw() -> void:
	var t: float = clampf(_age / LIFE, 0.0, 1.0)
	var r: float = radius
	# Shock ring marks the real blast radius.
	var ring_k: float = clampf(_age / 0.28, 0.0, 1.0)
	if ring_k < 1.0:
		var ring_r: float = r * (0.35 + 0.65 * (1.0 - pow(1.0 - ring_k, 3.0)))
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, Color(SHOCK, 0.85 * (1.0 - ring_k)), 4.0 * (1.0 - ring_k) + 0.6)
	# Smoke puffs drifting up.
	if t > 0.3:
		var k: float = (t - 0.3) / 0.7
		for index in range(5):
			var angle: float = TAU * float(index) / 5.0 + 0.4
			var pos := Vector2.RIGHT.rotated(angle) * r * 0.42 * (0.7 + 0.5 * k) + Vector2(0.0, -14.0 * k)
			draw_circle(pos, r * 0.16 * (0.7 + 0.6 * k), Color(SMOKE, 0.55 * (1.0 - k)))
	# Fireball: grows fast, then shrinks into smoke.
	var grow: float = clampf(_age / 0.12, 0.0, 1.0)
	var fade: float = clampf((t - 0.25) / 0.75, 0.0, 1.0)
	var fire_r: float = r * 0.62 * (0.4 + 0.6 * grow) * (1.0 - 0.35 * fade)
	if fade < 1.0:
		draw_circle(Vector2(3.0, 4.0), fire_r, Color(0.0, 0.0, 0.0, 0.2 * (1.0 - fade)))
		draw_circle(Vector2.ZERO, fire_r, Color(FIRE_DARK, 1.0 - fade))
		draw_circle(Vector2(-fire_r * 0.08, -fire_r * 0.1), fire_r * 0.78, Color(FIRE_MID, 1.0 - fade))
		draw_circle(Vector2(-fire_r * 0.15, -fire_r * 0.18), fire_r * 0.5, Color(FIRE_HOT, 1.0 - fade))
		if _age < 0.18:
			draw_circle(Vector2(-fire_r * 0.18, -fire_r * 0.2), fire_r * 0.3, Color(FIRE_CORE, 1.0 - _age / 0.18))
	# Debris chips.
	for chip in _debris:
		var d: float = r * float(chip["speed"]) * (1.0 - pow(1.0 - minf(t * 1.6, 1.0), 2.4))
		var pos: Vector2 = chip["dir"] * d
		var s: float = float(chip["size"]) * (1.0 - 0.6 * t)
		var rot: float = float(chip["spin"]) * t
		var tri := PackedVector2Array([Vector2(s, 0.0).rotated(rot) + pos, Vector2(-s * 0.6, s * 0.8).rotated(rot) + pos, Vector2(-s * 0.6, -s * 0.8).rotated(rot) + pos])
		draw_colored_polygon(tri, Color(SMOKE if chip["dark"] else FIRE_HOT, 1.0 - t))
