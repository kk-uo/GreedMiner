extends Node

## Owns permanent weapon availability and first-time planet completions.
## Research levels and ship module instances remain owned by their managers.

signal weapon_unlocked(weapon_id: StringName, display_name: String)
signal planet_completion_recorded(planet_id: StringName)
## Emitted after ore is spent to pinpoint (unlock) a destination planet.
signal planet_located(planet_id: StringName)

const SAVE_SECTION: StringName = &"weapon_unlocks"
const DEFAULT_CONFIGURATION: WeaponUnlockConfiguration = preload(
	"res://Resources/Progression/WeaponUnlockConfiguration.tres"
)

var configuration: WeaponUnlockConfiguration = DEFAULT_CONFIGURATION
var unlocked_weapon_ids: Dictionary = {}
var completed_planet_ids: Dictionary = {}
## Planets whose coordinates the player bought with ore ("precise locate").
var located_planet_ids: Dictionary = {}


func _ready() -> void:
	for message in configuration.get_validation_errors():
		push_error("WeaponUnlockManager: " + message)
	reload_progress()


## Loads old and new saves safely, then reapplies data-defined starting and
## completed-planet unlocks. This also supports unlock definitions added later.
func reload_progress() -> void:
	var data := ProgressionStore.get_section(SAVE_SECTION)
	unlocked_weapon_ids = _normalized_true_dictionary(data.get("unlocked_weapons", {}))
	completed_planet_ids = _normalized_true_dictionary(data.get("completed_planets", {}))
	located_planet_ids = _normalized_true_dictionary(data.get("located_planets", {}))
	var migrated := false
	for definition in configuration.definitions:
		if definition == null:
			continue
		if definition.is_starting_unlocked():
			migrated = _set_unlocked_without_signal(definition.weapon_id) or migrated
		elif (
			definition.unlock_condition == WeaponUnlockDefinition.UnlockCondition.PLANET_COMPLETION
			and has_completed_planet(definition.required_planet_id)
		):
			migrated = _set_unlocked_without_signal(definition.weapon_id) or migrated
	if migrated:
		save_progress()


func save_progress() -> bool:
	# Store an explicit state for every configured weapon. Keeping locked entries
	# as false makes the save self-contained and lets newly launched processes
	# restore the exact per-weapon state without relying on UI defaults.
	var weapon_states: Dictionary = {}
	for definition in configuration.definitions:
		if definition != null and not definition.weapon_id.is_empty():
			weapon_states[String(definition.weapon_id)] = is_weapon_unlocked(definition.weapon_id)
	# Preserve unknown legacy/future IDs instead of discarding player progress.
	for weapon_id in unlocked_weapon_ids.keys():
		if bool(unlocked_weapon_ids[weapon_id]):
			weapon_states[String(weapon_id)] = true
	return ProgressionStore.set_section(SAVE_SECTION, {
		"unlocked_weapons": weapon_states,
		"completed_planets": completed_planet_ids.duplicate(true),
		"located_planets": located_planet_ids.duplicate(true),
	})


func is_weapon_unlocked(weapon_id: StringName) -> bool:
	return bool(unlocked_weapon_ids.get(String(weapon_id), false))


func has_completed_planet(planet_id: StringName) -> bool:
	return bool(completed_planet_ids.get(String(planet_id), false))


## A planet is reachable once located. Free destinations (cost <= 0) and
## planets already cleared in older saves count as located.
func is_planet_located(planet_id: StringName, locate_cost: int = 0) -> bool:
	return (
		locate_cost <= 0
		or bool(located_planet_ids.get(String(planet_id), false))
		or has_completed_planet(planet_id)
	)


## Spends stored ore to permanently pinpoint a planet. Atomic: ore is refunded
## if the save fails. Returns true when the planet is (now) located.
func locate_planet(planet_id: StringName, locate_cost: int) -> bool:
	if planet_id.is_empty():
		return false
	if is_planet_located(planet_id, locate_cost):
		return true
	if not ResourceManager.try_spend_stored_ore(locate_cost):
		return false
	located_planet_ids[String(planet_id)] = true
	if not save_progress():
		located_planet_ids.erase(String(planet_id))
		ResourceManager.add_stored_ore(float(locate_cost))
		return false
	planet_located.emit(planet_id)
	return true


## Locates a destination for playtesting without spending Ore. The manager
## remains responsible for saving, rollback, and the normal location signal.
func locate_planet_for_development(planet_id: StringName) -> bool:
	if not DeveloperCommands.is_available() or planet_id.is_empty():
		return false
	if is_planet_located(planet_id, 1):
		return true
	located_planet_ids[String(planet_id)] = true
	if not save_progress():
		located_planet_ids.erase(String(planet_id))
		return false
	planet_located.emit(planet_id)
	return true


func get_definition(weapon_id: StringName) -> WeaponUnlockDefinition:
	return configuration.get_definition(weapon_id)


func get_unlock_requirement(weapon_id: StringName) -> String:
	var definition := get_definition(weapon_id)
	if definition == null:
		return "Weapon unlock is not configured."
	if not definition.requirement_text.strip_edges().is_empty():
		return definition.requirement_text
	match definition.unlock_condition:
		WeaponUnlockDefinition.UnlockCondition.STARTING:
			return "Available from the start."
		WeaponUnlockDefinition.UnlockCondition.PLANET_COMPLETION:
			return "Complete %s." % String(definition.required_planet_id)
		_:
			return "Unlock condition not yet decided."


## Permanently unlocks every weapon registered in the data configuration.
## DeveloperCommands provides the build guard; this manager remains the sole
## owner of persistence, rollback, and weapon_unlocked notifications.
func unlock_all_configured_weapons() -> Array[StringName]:
	var previous_unlocked := unlocked_weapon_ids.duplicate(true)
	var newly_unlocked: Array[StringName] = []
	for definition in configuration.definitions:
		if definition != null and _set_unlocked_without_signal(definition.weapon_id):
			newly_unlocked.append(definition.weapon_id)

	if newly_unlocked.is_empty():
		return newly_unlocked
	if not save_progress():
		unlocked_weapon_ids = previous_unlocked
		return []

	for weapon_id in newly_unlocked:
		var definition := get_definition(weapon_id)
		weapon_unlocked.emit(
			weapon_id,
			definition.display_name if definition != null else String(weapon_id)
		)
	return newly_unlocked


## Records only the first successful clear and returns newly unlocked IDs.
## Repeated clears are harmless and never emit duplicate reward signals.
func record_planet_completion(planet_id: StringName) -> Array[StringName]:
	var newly_unlocked: Array[StringName] = []
	if planet_id.is_empty() or has_completed_planet(planet_id):
		return newly_unlocked

	var previous_completed := completed_planet_ids.duplicate(true)
	var previous_unlocked := unlocked_weapon_ids.duplicate(true)
	completed_planet_ids[String(planet_id)] = true
	for definition in configuration.definitions:
		if definition != null and definition.is_unlocked_by_planet(planet_id):
			if _set_unlocked_without_signal(definition.weapon_id):
				newly_unlocked.append(definition.weapon_id)

	if not save_progress():
		completed_planet_ids = previous_completed
		unlocked_weapon_ids = previous_unlocked
		return []

	planet_completion_recorded.emit(planet_id)
	for weapon_id in newly_unlocked:
		var definition := get_definition(weapon_id)
		weapon_unlocked.emit(
			weapon_id,
			definition.display_name if definition != null else String(weapon_id)
		)
	return newly_unlocked


func _set_unlocked_without_signal(weapon_id: StringName) -> bool:
	if weapon_id.is_empty() or is_weapon_unlocked(weapon_id):
		return false
	unlocked_weapon_ids[String(weapon_id)] = true
	return true


func _normalized_true_dictionary(value: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if bool((value as Dictionary)[key]):
				normalized[String(key)] = true
	elif value is Array:
		# Early prototype saves may store IDs as an array.
		for entry in value as Array:
			normalized[String(entry)] = true
	return normalized
