extends Node

## Volcanic Planet: every wave, a pack of ordinary Demons climbs out of the
## lava rifts at once (user request). Gameplay: PACK_SIZE demons, EMERGE_DELAY
## seconds after each wave starts, at the widest spots of one rift that is at
## least MIN_SHIP_DISTANCE from the hull. They are extras on top of the wave
## budget (like graveyard lightning skeletons) and are tracked by WaveManager
## through the Enemies container. Presentation: each demon rises out of the
## lava over EMERGE_TIME (glowing hot, growing, then cooling) with
## LavaEmergeFx; it only starts moving once it is out.
## BattleMain adds this node on volcanic maps that have rifts.

const EMERGE_FX := preload("res://Scripts/VFX/LavaEmergeFx.gd")
const PACK_SIZE := Vector2i(5, 6)
const EMERGE_DELAY: float = 4.0
const MIN_SHIP_DISTANCE: float = 220.0
const EMERGE_TIME: float = 1.2
const STAGGER: float = 0.15
const ENEMY_ID: StringName = &"demon"

var battle: Node2D
var field: Battlefield
var waves: WaveManager
var ship: Ship
var enemies: Node2D
var _rng := RandomNumberGenerator.new()

signal pack_emerged(count: int, at: Vector2)


func _ready() -> void:
	_rng.randomize()
	if waves != null:
		waves.wave_started.connect(_on_wave_started)


func _on_wave_started(_wave_number: int, _total: int, _boss: bool) -> void:
	get_tree().create_timer(EMERGE_DELAY, false).timeout.connect(emerge_pack)


func _active() -> bool:
	return is_instance_valid(battle) and not bool(battle.get("_battle_ended")) and is_instance_valid(waves) and waves.is_running()


## Spawns one pack now. Returns how many demons climbed out.
func emerge_pack() -> int:
	if not _active() or not is_instance_valid(field) or not is_instance_valid(enemies):
		return 0
	var points := field.get_lava_emerge_points()
	var candidates: Array[Vector2] = []
	for point in points:
		if not is_instance_valid(ship) or ship.get_distance_to_hull(point) >= MIN_SHIP_DISTANCE:
			candidates.append(point)
	if candidates.is_empty():
		return 0
	var center: Vector2 = candidates[_rng.randi() % candidates.size()]
	# The widest spots near the chosen one, nearest first.
	var spots: Array[Vector2] = []
	for point in candidates:
		if point.distance_to(center) <= 260.0:
			spots.append(point)
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(center) < b.distance_to(center))
	var count := _rng.randi_range(PACK_SIZE.x, PACK_SIZE.y)
	for index in range(count):
		var base: Vector2 = spots[index % spots.size()]
		var at := base + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(0.0, 14.0)
		_emerge_one(at, float(index) * STAGGER)
	pack_emerged.emit(count, center)
	return count


func _emerge_one(at: Vector2, delay: float) -> void:
	var enemy := EnemyCatalog.instantiate_enemy(ENEMY_ID)
	if enemy == null:
		return
	enemy.target_ship = ship
	enemy.set_meta("spawn_origin", &"lava_fissure")
	enemy.visible = delay <= 0.0
	enemy.set_physics_process(false)
	enemies.add_child(enemy)
	enemy.global_position = at
	enemy.scale = Vector2.ONE * 0.45
	enemy.modulate = Color(2.6, 1.5, 0.6)
	var tween := enemy.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void:
			enemy.visible = true)
	tween.tween_callback(func() -> void:
		EMERGE_FX.spawn(enemy.get_parent(), at, 14.0))
	tween.tween_interval(0.3)
	tween.set_parallel(true)
	tween.tween_property(enemy, "scale", Vector2.ONE, EMERGE_TIME * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy, "modulate", Color.WHITE, EMERGE_TIME)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		if is_instance_valid(enemy) and not enemy.is_dying():
			enemy.set_physics_process(true))
