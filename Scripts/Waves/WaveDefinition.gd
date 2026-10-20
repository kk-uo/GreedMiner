class_name WaveDefinition
extends Resource

## Inspector-editable definition of one ordered enemy wave.

enum SpawnPattern {
	RANDOM,
	ALTERNATING_SIDES,
	CARDINAL_CYCLE,
	CLUSTER,
	FORMATION,
}

## Controls whether each request chooses its own edge, the whole wave shares
## one edge, or requests are limited to an Inspector-configured edge list.
enum SpawnDirectionMode {
	RANDOM_EDGES,
	SINGLE_DIRECTION,
	RESTRICTED_DIRECTIONS,
}

enum SpawnDirection {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
}

@export_range(1, 999, 1) var wave_number: int = 1
@export_range(0.0, 600.0, 0.1) var preparation_duration: float = 0.0
@export_range(0.05, 60.0, 0.05) var spawn_interval: float = 2.0
@export_range(0.0, 60.0, 0.1) var initial_spawn_delay: float = 0.0
@export_range(0, 500, 1) var maximum_simultaneous_enemies: int = 0
@export var spawn_pattern: SpawnPattern = SpawnPattern.RANDOM
@export var spawn_direction_mode: SpawnDirectionMode = SpawnDirectionMode.RANDOM_EDGES
@export var allowed_directions: Array[SpawnDirection] = [
	SpawnDirection.TOP,
	SpawnDirection.BOTTOM,
	SpawnDirection.LEFT,
	SpawnDirection.RIGHT,
]
@export var boss_wave: bool = false
## Boss interface for a wave whose boss content is not authored yet. Reserved
## bosses are counted for design totals but are never substituted or spawned.
@export_range(0, 10, 1) var reserved_boss_count: int = 0
@export var reserved_boss_enemy_id: StringName = &""
## Whether a future boss implementation must reserve summons from fixed wave
## entries. False explicitly allows separately tracked extra summons.
@export var boss_summons_consume_wave_quota: bool = true
@export_multiline var missing_boss_message: String = ""

## Optional fixed duration for a batch-spawn phase. Zero preserves the legacy
## one-enemy-per-interval scheduler used by Rocky Planet.
@export_range(0.0, 600.0, 0.1) var spawn_phase_duration: float = 0.0
@export var batch_spawning_enabled: bool = false
@export var interleave_enemy_types: bool = false
## Optional full-duration spawn phases; disabled for existing planets.
@export var wait_for_spawn_phase_end: bool = false

## A pending wave is a deliberate development stop, not an empty completed wave.
@export var configuration_pending: bool = false
@export_multiline var configuration_message: String = ""

## Fixed-count enemy entries. Each sub-resource is unique to this wave.
@export var enemy_entries: Array[EnemySpawnEntry] = []


func get_total_spawn_count() -> int:
	var total: int = 0
	for entry in enemy_entries:
		if entry != null:
			total += maxi(entry.spawn_count, 0)
	return total


func get_total_count_including_reserved_boss() -> int:
	return get_total_spawn_count() + maxi(reserved_boss_count, 0)


func has_missing_reserved_boss() -> bool:
	return boss_wave and reserved_boss_count > 0


## Total shared spawn budget represented by this wave's exact quotas.
func get_total_spawn_budget() -> int:
	var total: int = 0
	for entry in enemy_entries:
		if entry != null:
			total += maxi(entry.spawn_count, 0) * maxi(entry.spawn_cost, 0)
	return total


## Legacy waves derive their phase length from count × interval without changing
## runtime behavior. Verdant waves store this value explicitly for batching.
func get_effective_spawn_phase_duration() -> float:
	if spawn_phase_duration > 0.0:
		return spawn_phase_duration
	return float(get_total_spawn_count()) * maxf(spawn_interval, 0.05)


## Number of ordinary enemies emitted per scheduler tick for a fixed phase.
func get_spawn_batch_size() -> int:
	if not batch_spawning_enabled or spawn_phase_duration <= 0.0:
		return 1
	var tick_count := maxi(ceili(spawn_phase_duration / maxf(spawn_interval, 0.05)), 1)
	return maxi(ceili(float(get_total_spawn_count()) / float(tick_count)), 1)


## Converts the Inspector enum values into world-space edge directions.
func get_allowed_direction_vectors() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for configured_direction in allowed_directions:
		var direction := direction_to_vector(configured_direction)
		if direction != Vector2.ZERO and direction not in result:
			result.append(direction)
	return result


static func direction_to_vector(direction: SpawnDirection) -> Vector2:
	match direction:
		SpawnDirection.TOP:
			return Vector2.UP
		SpawnDirection.BOTTOM:
			return Vector2.DOWN
		SpawnDirection.LEFT:
			return Vector2.LEFT
		SpawnDirection.RIGHT:
			return Vector2.RIGHT
		_:
			return Vector2.ZERO
