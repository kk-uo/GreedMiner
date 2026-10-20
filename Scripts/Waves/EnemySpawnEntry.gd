class_name EnemySpawnEntry
extends Resource

## Inspector-editable fixed-count entry for one enemy type in a wave.

## Stable ID used as a fallback when Enemy Scene is not assigned.
@export var enemy_id: StringName = &"little_rock"

## Scene spawned for this entry. It must inherit BasicEnemy.
@export var enemy_scene: PackedScene

## Exact number of enemies scheduled from this entry.
@export_range(0, 10000, 1) var spawn_count: int = 1

## Budget consumed by one scheduled enemy. Fixed quotas remain authoritative.
@export_range(1, 1000, 1) var spawn_cost: int = 1

## Reserved for future randomized generators; fixed waves do not use weights.
@export_range(0.0, 1000.0, 0.01) var spawn_weight: float = 1.0

## Entries marked Spawn First are placed before ordinary entries.
@export var spawn_first: bool = false

## Marks this entry as the boss tracked by WaveManager's boss signals.
@export var is_boss: bool = false


## Resolves the assigned scene, falling back to the stable enemy catalog ID.
func resolve_scene() -> PackedScene:
	if enemy_scene != null:
		return enemy_scene
	return EnemyCatalog.get_enemy_scene(enemy_id)
