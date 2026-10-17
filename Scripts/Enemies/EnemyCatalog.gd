class_name EnemyCatalog
extends RefCounted

## Lightweight stable-ID catalog for future planet and wave integration.

const ENEMY_SCENES: Dictionary = {
	&"little_rock": preload("res://Scenes/Enemies/little_rock.tscn"),
	&"rock_golem": preload("res://Scenes/Enemies/rock_golem.tscn"),
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
