class_name SpecialSpawnEventRule
extends Resource

## Reusable rule that reorganizes part of a fixed quota into a special pattern.
## It never adds enemies or budget to the wave.

enum Pattern { CLUSTER, FORMATION }
enum TriggerMode { RANDOM_CHANCE, FIXED_PHASE_FRACTION }

@export var event_id: StringName = &"goblin_pack"
@export var enemy_id: StringName = &"goblin"
@export var trigger_mode: TriggerMode = TriggerMode.RANDOM_CHANCE
## Zero uses starting_wave; non-zero restricts this event to one exact wave.
@export_range(0, 999, 1) var exact_wave: int = 0
## Percentage of the active spawn phase used by deterministic events.
@export_range(0.0, 1.0, 0.01) var trigger_phase_fraction: float = 0.5
## Zero keeps the existing random range; positive values request an exact size.
@export_range(0, 100, 1) var fixed_group_size: int = 0
@export_range(1, 999, 1) var starting_wave: int = 3
@export_range(0.0, 1.0, 0.01) var trigger_chance: float = 0.25
@export_range(0, 10, 1) var maximum_events_per_wave: int = 1
@export_range(1, 100, 1) var minimum_group_size: int = 6
@export_range(1, 100, 1) var maximum_group_size: int = 10
@export var pattern: Pattern = Pattern.CLUSTER
@export_range(0.0, 1000.0, 1.0) var cluster_radius: float = 80.0
## FORMATION only: distance between neighbouring units in the block
## (layouts live in SpawnFormation.PRESETS; one unit is the flag bearer).
@export_range(8.0, 200.0, 1.0) var formation_spacing: float = 30.0
@export var with_flag_bearer: bool = true


func is_eligible(wave_number: int, available_quota: int) -> bool:
	return (
		(exact_wave == wave_number if exact_wave > 0 else wave_number >= starting_wave)
		and maximum_events_per_wave > 0
		and available_quota >= get_required_minimum()
	)


func roll(rng: RandomNumberGenerator) -> bool:
	if trigger_mode == TriggerMode.FIXED_PHASE_FRACTION:
		return true
	return rng.randf() < clampf(trigger_chance, 0.0, 1.0)


func get_required_minimum() -> int:
	return fixed_group_size if fixed_group_size > 0 else minimum_group_size


func choose_group_size(available_quota: int, rng: RandomNumberGenerator) -> int:
	if fixed_group_size > 0:
		return fixed_group_size if available_quota >= fixed_group_size else 0
	return rng.randi_range(minimum_group_size, mini(maximum_group_size, available_quota))
