class_name WaveSpawnRequest
extends RefCounted

## One executable spawn instruction. Ordinary requests contain one enemy;
## special cluster requests contain the entire quota-preserving group.

var entry: EnemySpawnEntry
var spawn_count: int = 1
var pattern: WaveDefinition.SpawnPattern = WaveDefinition.SpawnPattern.RANDOM
var direction: Vector2 = Vector2.ZERO
var cluster_radius: float = 0.0
var formation_spacing: float = 30.0
var special_event_id: StringName = &""
## Negative means ordinary queue scheduling; otherwise active-phase timing.
var trigger_phase_fraction: float = -1.0
var with_flag_bearer: bool = true


func get_budget_cost() -> int:
	return spawn_count * maxi(entry.spawn_cost, 0) if entry != null else 0


func is_cluster() -> bool:
	return pattern == WaveDefinition.SpawnPattern.CLUSTER and spawn_count > 1


## Organized block (Goblin Pack) — see SpawnFormation.
func is_formation() -> bool:
	return pattern == WaveDefinition.SpawnPattern.FORMATION and spawn_count > 1
