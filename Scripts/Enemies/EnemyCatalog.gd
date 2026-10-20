class_name EnemyCatalog
extends RefCounted

## Lightweight stable-ID catalog for future planet and wave integration.

const ENEMY_SCENES: Dictionary = {
	&"little_rock": preload("res://Scenes/Enemies/little_rock.tscn"),
	&"rock_golem": preload("res://Scenes/Enemies/rock_golem.tscn"),
	&"rock_titan": preload("res://Scenes/Enemies/rock_titan.tscn"),
	&"goblin": preload("res://Scenes/Enemies/goblin.tscn"),
	&"goblin_hunter": preload("res://Scenes/Enemies/goblin_hunter.tscn"),
	&"elite_goblin": preload("res://Scenes/Enemies/elite_goblin.tscn"),
	&"goblin_giant_chariot": preload("res://Scenes/Enemies/goblin_giant_chariot.tscn"),
	&"red_rock": preload("res://Scenes/Enemies/red_rock.tscn"),
	&"goblin_engineer": preload("res://Scenes/Enemies/goblin_engineer.tscn"),
	&"demon": preload("res://Scenes/Enemies/demon.tscn"),
	&"hellhunter": preload("res://Scenes/Enemies/hellhunter.tscn"),
	&"big_demon": preload("res://Scenes/Enemies/big_demon.tscn"),
	&"imp": preload("res://Scenes/Enemies/imp.tscn"),
	&"demon_lord": preload("res://Scenes/Enemies/demon_lord.tscn"),
	&"snow_monster": preload("res://Scenes/Enemies/snow_monster.tscn"),
	&"big_snow_monster": preload("res://Scenes/Enemies/big_snow_monster.tscn"),
	&"sled_car_snow_monster": preload("res://Scenes/Enemies/sled_car_snow_monster.tscn"),
	&"snow_monster_wizard": preload("res://Scenes/Enemies/snow_monster_wizard.tscn"),
	&"mega_monster": preload("res://Scenes/Enemies/mega_monster.tscn"),
}


## Returns the scene registered for an enemy ID.
static func get_enemy_scene(enemy_id: StringName) -> PackedScene:
	return ENEMY_SCENES.get(enemy_id) as PackedScene


## Creates an enemy by stable ID, or returns null for an unknown ID.
static func instantiate_enemy(enemy_id: StringName) -> BasicEnemy:
	var enemy_scene := get_enemy_scene(enemy_id)
	if enemy_scene == null:
		push_warning("EnemyCatalog: Unknown enemy ID: %s" % enemy_id)
		return null

	return enemy_scene.instantiate() as BasicEnemy
