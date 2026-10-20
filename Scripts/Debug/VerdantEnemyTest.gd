extends Node2D

## Isolated manual sandbox for the three Verdant Planet enemies.
## This scene intentionally does not use EnemySpawner or WaveManager.

const GOBLIN_SCENE: PackedScene = preload("res://Scenes/Enemies/goblin.tscn")
const HUNTER_SCENE: PackedScene = preload("res://Scenes/Enemies/goblin_hunter.tscn")
const ELITE_SCENE: PackedScene = preload("res://Scenes/Enemies/elite_goblin.tscn")

@onready var ship: Ship = $Ship
@onready var enemies: Node2D = $Enemies
@onready var debug_label: Label = $DebugUI/Panel/Margin/VBox/DebugLabel


func _ready() -> void:
	$DebugUI/Panel/Margin/VBox/GoblinButton.pressed.connect(
		_spawn_enemy.bind(GOBLIN_SCENE, Vector2(-260.0, 0.0))
	)
	$DebugUI/Panel/Margin/VBox/HunterButton.pressed.connect(
		_spawn_enemy.bind(HUNTER_SCENE, Vector2(360.0, 0.0))
	)
	$DebugUI/Panel/Margin/VBox/EliteButton.pressed.connect(
		_spawn_enemy.bind(ELITE_SCENE, Vector2(0.0, 260.0))
	)
	$DebugUI/Panel/Margin/VBox/AllButton.pressed.connect(_spawn_all)
	$DebugUI/Panel/Margin/VBox/ClearButton.pressed.connect(_clear_enemies)
	_update_debug_text()


func _process(_delta: float) -> void:
	_update_debug_text()


func _spawn_enemy(enemy_scene: PackedScene, offset: Vector2) -> void:
	var enemy := enemy_scene.instantiate() as BasicEnemy
	if enemy == null:
		push_error("VerdantEnemyTest: scene must inherit BasicEnemy.gd.")
		return
	enemy.target_ship = ship
	enemies.add_child(enemy)
	enemy.global_position = ship.to_global(Ship.SHIP_SIZE * 0.5) + offset
	print("Manual test spawned %s." % enemy.enemy_name)


func _spawn_all() -> void:
	_spawn_enemy(GOBLIN_SCENE, Vector2(-260.0, -80.0))
	_spawn_enemy(HUNTER_SCENE, Vector2(360.0, 0.0))
	_spawn_enemy(ELITE_SCENE, Vector2(0.0, 280.0))


func _clear_enemies() -> void:
	for child in enemies.get_children():
		child.queue_free()


func _update_debug_text() -> void:
	if not is_instance_valid(ship) or debug_label == null:
		return
	var lines: Array[String] = [
		"SHIP HP: %.1f / %.1f" % [ship.current_hp, ship.max_hp],
		"ENEMIES: %d" % enemies.get_child_count(),
	]
	for child in enemies.get_children():
		if child is BasicEnemy:
			var enemy := child as BasicEnemy
			lines.append("%s  HP %.1f / %.1f" % [
				enemy.enemy_name,
				enemy.get_current_health(),
				enemy.max_health,
			])
	debug_label.text = "\n".join(lines)
