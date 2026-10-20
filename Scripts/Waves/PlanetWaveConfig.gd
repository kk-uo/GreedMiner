class_name PlanetWaveConfig
extends Resource

## Reusable list of Inspector-editable waves for one planet.

@export var planet_id: StringName = &"rocky_planet"
@export var display_name: String = "Rocky Planet"
@export var waves: Array[WaveDefinition] = []
@export var special_spawn_rules: Array[SpecialSpawnEventRule] = []


func get_total_waves() -> int:
	return waves.size()


## Reports configuration problems without changing the editable resource.
func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if waves.is_empty():
		errors.append("Planet wave configuration contains no waves.")
	for index in range(waves.size()):
		var wave := waves[index]
		if wave == null:
			errors.append("Wave slot %d is empty." % (index + 1))
			continue
		if wave.configuration_pending:
			if not wave.boss_wave:
				errors.append("Pending Wave %d must be explicitly marked as a boss wave." % wave.wave_number)
			if wave.configuration_message.strip_edges().is_empty():
				errors.append("Pending Wave %d needs a development message." % wave.wave_number)
			continue
		if wave.reserved_boss_count > 0:
			if not wave.boss_wave:
				errors.append("Wave %d reserves a boss but is not marked as a boss wave." % wave.wave_number)
			if wave.reserved_boss_enemy_id.is_empty():
				errors.append("Wave %d reserved boss needs a stable future enemy ID." % wave.wave_number)
			if wave.missing_boss_message.strip_edges().is_empty():
				errors.append("Wave %d reserved boss needs a development message." % wave.wave_number)
		if wave.enemy_entries.is_empty():
			errors.append("Wave %d has no enemy entries." % wave.wave_number)
		if (
			wave.spawn_direction_mode != WaveDefinition.SpawnDirectionMode.RANDOM_EDGES
			and wave.get_allowed_direction_vectors().is_empty()
		):
			errors.append("Wave %d requires at least one allowed spawn direction." % wave.wave_number)
		for entry in wave.enemy_entries:
			if entry == null:
				errors.append("Wave %d contains an empty enemy entry." % wave.wave_number)
			elif entry.spawn_count > 0 and entry.resolve_scene() == null:
				errors.append("Wave %d cannot resolve enemy '%s'." % [wave.wave_number, entry.enemy_id])
			elif entry.spawn_cost <= 0:
				errors.append("Wave %d enemy '%s' has a non-positive spawn cost." % [wave.wave_number, entry.enemy_id])
	return errors
