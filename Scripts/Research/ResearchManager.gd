extends Node

## Owns research state, purchasing, persistence, and effect lookup.

signal research_level_changed(research_id: StringName, level: int)
signal research_unlocked(research_id: StringName)
signal research_milestone_reached(research_id: StringName, level: int)
signal purchase_failed(research_id: StringName, reason: String)

const DEFAULT_CONFIGURATION: ResearchConfiguration = preload(
	"res://Resources/Research/ResearchConfiguration.tres"
)
const SAVE_SECTION: StringName = &"research"
const WEAPON_CATEGORY_ID: StringName = &"weapon"
const SHIELD_CATEGORY_ID: StringName = &"shield"

var configuration: ResearchConfiguration = DEFAULT_CONFIGURATION
var progress: ResearchProgress = ResearchProgress.new()
var _purchase_in_progress: bool = false


func _ready() -> void:
	for message in configuration.get_validation_errors():
		push_error("ResearchManager: " + message)
	reload_progress()


func reload_progress() -> void:
	progress = ResearchProgress.new()
	progress.import_data(ProgressionStore.get_section(SAVE_SECTION))
	var migrated_existing_level := false
	for definition in configuration.get_all_definitions():
		if definition == null:
			continue
		var key := String(definition.research_id)
		if not progress.levels.has(key):
			progress.levels[key] = definition.starting_level
		else:
			var saved_level := int(progress.levels[key])
			var normalized_level := clampi(
				saved_level,
				definition.starting_level,
				definition.max_level
			)
			progress.levels[key] = normalized_level
			migrated_existing_level = migrated_existing_level or saved_level != normalized_level
		if not progress.unlocked.has(String(definition.research_id)):
			progress.unlocked[String(definition.research_id)] = definition.unlocked_by_default
	if migrated_existing_level:
		save_progress()


func save_progress() -> bool:
	return ProgressionStore.set_section(SAVE_SECTION, progress.export_data())


func get_categories() -> Array[ResearchCategory]:
	return configuration.categories


func get_definitions_for_category(category_id: StringName) -> Array[ResearchDefinition]:
	return configuration.get_definitions_for_category(category_id)


func get_definition(research_id: StringName) -> ResearchDefinition:
	return configuration.get_definition(research_id)


func get_level(research_id: StringName) -> int:
	var definition := get_definition(research_id)
	if definition == null:
		return 0
	return clampi(
		int(progress.levels.get(String(research_id), definition.starting_level)),
		definition.starting_level,
		definition.max_level
	)


func is_unlocked(research_id: StringName) -> bool:
	var definition := get_definition(research_id)
	if definition == null:
		return false
	# Weapon and shield-module availability are permanent unlock progression, not
	# research flags. This overrides stale `unlocked=true` values written by
	# older save versions so research cannot precede the corresponding module.
	if (
		(
			definition.category_id == WEAPON_CATEGORY_ID
			and definition.effect is WeaponDamageResearchEffect
		)
		or (
			definition.category_id == SHIELD_CATEGORY_ID
			and definition.effect is ModuleStatResearchEffect
		)
	):
		return WeaponUnlockManager.is_weapon_unlocked(definition.target_id)
	return bool(progress.unlocked.get(String(research_id), definition.unlocked_by_default))


func get_upgrade_cost(research_id: StringName) -> int:
	var definition := get_definition(research_id)
	if definition == null or definition.cost_configuration == null:
		return 0
	if get_level(research_id) >= definition.max_level:
		return 0
	var milestone := definition.get_milestone(get_level(research_id) + 1)
	if milestone != null and milestone.has_cost_override():
		return milestone.upgrade_cost_override
	return definition.cost_configuration.get_upgrade_cost(get_level(research_id))


func purchase_research(research_id: StringName) -> bool:
	if _purchase_in_progress:
		purchase_failed.emit(research_id, "Another research purchase is in progress.")
		return false
	var definition := get_definition(research_id)
	var failure := _get_purchase_failure(definition)
	if not failure.is_empty():
		purchase_failed.emit(research_id, failure)
		return false

	var cost := get_upgrade_cost(research_id)
	_purchase_in_progress = true
	if not ResourceManager.try_spend_stored_ore(cost):
		_purchase_in_progress = false
		purchase_failed.emit(research_id, "Insufficient stored ore.")
		return false

	var next_level := get_level(research_id) + 1
	var previous_level := get_level(research_id)
	progress.levels[String(research_id)] = next_level
	if not save_progress():
		progress.levels[String(research_id)] = previous_level
		ResourceManager.add_stored_ore(float(cost))
		_purchase_in_progress = false
		purchase_failed.emit(research_id, "Could not save research progress.")
		return false
	_purchase_in_progress = false
	research_level_changed.emit(research_id, next_level)
	if definition.get_milestone(next_level) != null:
		research_milestone_reached.emit(research_id, next_level)
	return true


func _get_purchase_failure(definition: ResearchDefinition) -> String:
	if definition == null:
		return "Unknown research definition."
	var category := configuration.get_category(definition.category_id)
	if not definition.enabled or not definition.implemented:
		return "Research is not implemented."
	if category == null or not category.enabled or not category.implemented:
		return "Research category is not implemented."
	if not is_unlocked(definition.research_id):
		return "Research is locked."
	for requirement in definition.unlock_requirements:
		if not is_unlocked(requirement):
			return "Unlock requirements are not met."
	if get_level(definition.research_id) >= definition.max_level:
		return "Maximum research level reached."
	if definition.cost_configuration == null:
		return "Research has no cost configuration."
	var tree_node := configuration.get_tree_node(definition.research_id)
	if tree_node != null:
		if not configuration.get_validation_errors().is_empty():
			return "Research tree configuration is invalid."
		if not tree_node.enabled:
			return "Research node is disabled."
		for prerequisite in tree_node.prerequisite_ids:
			if not is_research_completed(prerequisite):
				return "Requires completed research: %s." % prerequisite
	return ""


## One-time tree state remains derived from the existing research save.
func is_research_completed(research_id: StringName) -> bool:
	var definition := get_definition(research_id)
	return definition != null and get_level(research_id) >= definition.max_level


## Gameplay-facing mining research values; all progress remains in the research save.
func get_crystal_value_multiplier() -> float:
	return 1.0 + 0.05 * int(is_research_completed(&"mining_value_1")) + 0.05 * int(is_research_completed(&"mining_value_2"))


func get_crystal_respawn_seconds() -> float:
	if is_research_completed(&"mining_respawn_2"):
		return 140.0
	return 150.0 if is_research_completed(&"mining_respawn_1") else 0.0


func get_dwarf_max_hp() -> float:
	return 50.0 + 10.0 * int(is_research_completed(&"mining_hp_1")) + 10.0 * int(is_research_completed(&"mining_hp_2")) + 10.0 * int(is_research_completed(&"mining_hp_3"))


func get_dwarf_movement_speed_bonus() -> float:
	return 5.0 if is_research_completed(&"mining_move_speed") else 0.0


func get_dwarf_detection_range(base_range: float) -> float:
	return minf(base_range, 175.0) if is_research_completed(&"mining_detection") else base_range


func get_crystal_mining_seconds() -> float:
	return 10.0 - 0.5 * int(is_research_completed(&"mining_time_1")) - 0.5 * int(is_research_completed(&"mining_time_2"))


func get_mining_qte_ore_multiplier() -> float:
	return 1.25 if is_research_completed(&"mining_qte") else 1.0


func get_mining_output_bonus() -> float:
	return 0.5 if is_research_completed(&"mining_passive") else 0.0


func get_tree_node_state(research_id: StringName) -> StringName:
	var node := configuration.get_tree_node(research_id)
	if node == null or not node.enabled or not configuration.get_validation_errors().is_empty():
		return &"LOCKED"
	if is_research_completed(research_id):
		return &"COMPLETED"
	var definition := get_definition(research_id)
	if definition == null or not definition.enabled or not definition.implemented or not is_unlocked(research_id):
		return &"LOCKED"
	for prerequisite in node.prerequisite_ids:
		if not is_research_completed(prerequisite):
			return &"LOCKED"
	return &"AVAILABLE"


func get_ship_research_effects() -> Array[ShipResearchEffect]:
	var result: Array[ShipResearchEffect] = []
	for definition in configuration.get_all_definitions():
		if definition != null and definition.enabled and definition.implemented and definition.effect is ShipResearchEffect and is_research_completed(definition.research_id):
			result.append(definition.effect as ShipResearchEffect)
	return result


## Every research whose ShipResearchEffect lists `planet_id`; all of them must
## be completed before the planet can be reached (e.g. Frozen needs both
## Long-Range Cells and Air Conditioning).
func get_planet_access_researches(planet_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for definition in configuration.get_all_definitions():
		if definition == null or not definition.enabled or not definition.effect is ShipResearchEffect:
			continue
		if (definition.effect as ShipResearchEffect).unlocked_planet_ids.has(planet_id):
			result.append(definition.research_id)
	return result


## The first gating research still missing for `planet_id`, or empty.
func get_planet_access_research(planet_id: StringName) -> StringName:
	for research_id in get_planet_access_researches(planet_id):
		if not is_research_completed(research_id):
			return research_id
	return &""


## True when every research gating the planet is done (or none gates it).
func is_planet_in_range(planet_id: StringName) -> bool:
	return get_planet_access_research(planet_id).is_empty()


## Ship power from research that needs no Energy Module.
func get_ship_base_power_bonus() -> int:
	var bonus := 0
	for effect in get_ship_research_effects():
		bonus += maxi(effect.base_power_bonus, 0)
	return bonus


## True once SHIP STYLE (colors / hull designs) has been researched.
func is_ship_style_unlocked() -> bool:
	for effect in get_ship_research_effects():
		if effect.unlocks_ship_style:
			return true
	return false


## Extra grid-expansion capacity each Energy Module supplies from research.
## Interface only: nothing turns this capacity into slots yet.
func get_energy_module_expansion_bonus() -> int:
	var bonus := 0
	for effect in get_ship_research_effects():
		bonus += maxi(effect.expansion_capacity_bonus, 0)
	return bonus


## True once batteries support slot expansion (the hull research that will
## actually add slots should check this).
func is_energy_slot_expansion_supported() -> bool:
	return get_energy_module_expansion_bonus() > 0


## Extra max hull HP each installed Energy Module gives from research.
func get_energy_module_hp_bonus() -> float:
	var bonus := 0.0
	for effect in get_ship_research_effects():
		bonus += maxf(effect.energy_module_hp_bonus, 0.0)
	return bonus


## Extra power each Energy Module supplies from completed research.
func get_energy_module_power_bonus() -> int:
	var bonus := 0
	for effect in get_ship_research_effects():
		bonus += maxi(effect.power_bonus, 0)
	return bonus


## Returns permanent modifiers for one weapon type and stat.
func get_weapon_stat_modifiers(
	weapon_type_id: StringName,
	stat_id: StringName
) -> Array[StatModifier]:
	var modifiers: Array[StatModifier] = []
	for definition in configuration.definitions:
		if (
			definition == null
			or not definition.enabled
			or not definition.implemented
			or definition.category_id != WEAPON_CATEGORY_ID
			or definition.target_id != weapon_type_id
			or definition.effect == null
		):
			continue
		for modifier in definition.effect.get_stat_modifiers(
			definition.research_id,
			definition.target_id,
			get_level(definition.research_id)
		):
			if modifier != null and modifier.stat_id == stat_id:
				modifiers.append(modifier)
	return modifiers


## Returns permanent stat modifiers for one defensive module type.
func get_shield_stat_modifiers(
	module_type_id: StringName,
	stat_id: StringName
) -> Array[StatModifier]:
	var modifiers: Array[StatModifier] = []
	for definition in configuration.definitions:
		if (
			definition == null
			or not definition.enabled
			or not definition.implemented
			or definition.category_id != SHIELD_CATEGORY_ID
			or definition.target_id != module_type_id
			or definition.effect == null
		):
			continue
		for modifier in definition.effect.get_stat_modifiers(
			definition.research_id,
			definition.target_id,
			get_level(definition.research_id)
		):
			if modifier != null and modifier.stat_id == stat_id:
				modifiers.append(modifier)
	return modifiers


func get_shield_research_definition(module_type_id: StringName) -> ResearchDefinition:
	for definition in configuration.definitions:
		if (
			definition != null
			and definition.enabled
			and definition.implemented
			and definition.category_id == SHIELD_CATEGORY_ID
			and definition.target_id == module_type_id
			and definition.effect is ModuleStatResearchEffect
		):
			return definition
	return null


## Shield sockets are earned through research milestones, after the global
## Chip Laboratory unlock. The configured milestones control all three slots.
func get_shield_bonus_chip_slot_count(module_type_id: StringName) -> int:
	var definition := get_shield_research_definition(module_type_id)
	if definition == null:
		return 0
	var level := get_level(definition.research_id)
	var count := 0
	for milestone in definition.milestones:
		if milestone != null and level >= milestone.target_level:
			count += milestone.module_chip_slots_unlocked
	return count


func get_shield_bonus_slot_unlock_level(module_type_id: StringName, bonus_slot_index: int) -> int:
	var definition := get_shield_research_definition(module_type_id)
	if definition == null:
		return 0
	var levels: Array[int] = []
	for milestone in definition.milestones:
		if milestone == null:
			continue
		for _index in range(maxi(milestone.module_chip_slots_unlocked, 0)):
			levels.append(milestone.target_level)
	levels.sort()
	return levels[bonus_slot_index] if bonus_slot_index >= 0 and bonus_slot_index < levels.size() else 0


## Finds the global damage-research definition shared by one weapon type.
func get_weapon_research_definition(weapon_type_id: StringName) -> ResearchDefinition:
	for definition in configuration.definitions:
		if (
			definition != null
			and definition.enabled
			and definition.implemented
			and definition.category_id == WEAPON_CATEGORY_ID
			and definition.target_id == weapon_type_id
			and definition.effect is WeaponDamageResearchEffect
		):
			return definition
	return null


func get_weapon_research_level(weapon_type_id: StringName) -> int:
	var definition := get_weapon_research_definition(weapon_type_id)
	return get_level(definition.research_id) if definition != null else 0


## Returns type-level chip slots derived from reached research milestones.
## No separate unlock boolean is saved, so existing Level 10 saves migrate
## automatically and cannot disagree with their research progress.
func get_weapon_chip_slot_count(weapon_type_id: StringName) -> int:
	var definition := get_weapon_research_definition(weapon_type_id)
	if definition == null:
		return 0
	var current_level := get_level(definition.research_id)
	var slot_count := 0
	for milestone in definition.milestones:
		if milestone != null and current_level >= milestone.target_level:
			slot_count += milestone.weapon_chip_slots_unlocked
	return slot_count


func is_weapon_chip_slot_unlocked(weapon_type_id: StringName) -> bool:
	return get_weapon_chip_slot_count(weapon_type_id) > 0


## The shared Chip Laboratory unlocks as soon as any weapon reaches the
## Inspector-configured threshold. No separate save flag can become stale.
func is_chip_laboratory_unlocked() -> bool:
	for definition in configuration.definitions:
		if (
			definition != null
			and definition.enabled
			and definition.implemented
			and definition.category_id == WEAPON_CATEGORY_ID
			and definition.effect is WeaponDamageResearchEffect
			and get_level(definition.research_id)
				>= configuration.chip_laboratory_unlock_level
		):
			return true
	return false


func get_next_weapon_chip_slot_milestone(weapon_type_id: StringName) -> int:
	var definition := get_weapon_research_definition(weapon_type_id)
	if definition == null:
		return 0
	var level := get_level(definition.research_id)
	var next_level := 0
	for milestone in definition.milestones:
		if (
			milestone != null
			and milestone.weapon_chip_slots_unlocked > 0
			and milestone.target_level > level
			and (next_level == 0 or milestone.target_level < next_level)
		):
			next_level = milestone.target_level
	return next_level


## Returns the configured permanent installation limit for a module type.
## Missing definitions keep the conservative one-module default.
func get_module_installation_limit(module_type_id: StringName) -> int:
	for definition in configuration.definitions:
		if (
			definition == null
			or not definition.enabled
			or not definition.implemented
			or definition.target_id != module_type_id
			or not definition.effect is ModuleInstallationLimitResearchEffect
		):
			continue
		var effect := definition.effect as ModuleInstallationLimitResearchEffect
		return effect.get_installation_limit(get_level(definition.research_id))
	return 1


func is_module_installation_unlock_completed(module_type_id: StringName) -> bool:
	for definition in configuration.definitions:
		if (
			definition != null
			and definition.enabled
			and definition.implemented
			and definition.target_id == module_type_id
			and definition.effect is ModuleInstallationLimitResearchEffect
		):
			return get_level(definition.research_id) >= definition.max_level
	return false


## Enables future unlock rewards without coupling them to UI code.
func unlock_research(research_id: StringName) -> bool:
	var definition := get_definition(research_id)
	if definition == null or is_unlocked(research_id):
		return false
	# Weapon unlocks must use WeaponUnlockManager planet progression.
	if (
		definition.category_id == WEAPON_CATEGORY_ID
		and definition.effect is WeaponDamageResearchEffect
	):
		return false
	progress.unlocked[String(research_id)] = true
	save_progress()
	research_unlocked.emit(research_id)
	return true


## Completes a non-combat research entry without spending resources. This is
## deliberately limited to Developer Mode callers; normal progression must use
## purchase_research(). Keeping the mutation here preserves the research save
## format and emits the same state notifications used by regular upgrades.
func complete_research_for_development(research_id: StringName) -> bool:
	var definition := get_definition(research_id)
	if not DeveloperCommands.is_available() or definition == null or not definition.enabled or not definition.implemented:
		return false
	if not definition.effect is ShipResearchEffect or (definition.effect as ShipResearchEffect).unlocked_planet_ids.is_empty():
		return false
	if is_research_completed(research_id):
		return true

	var previous_level := get_level(research_id)
	var previous_unlocked := bool(progress.unlocked.get(String(research_id), definition.unlocked_by_default))
	progress.unlocked[String(research_id)] = true
	progress.levels[String(research_id)] = definition.max_level
	if not save_progress():
		progress.unlocked[String(research_id)] = previous_unlocked
		progress.levels[String(research_id)] = previous_level
		return false

	if not previous_unlocked:
		research_unlocked.emit(research_id)
	research_level_changed.emit(research_id, definition.max_level)
	if definition.get_milestone(definition.max_level) != null:
		research_milestone_reached.emit(research_id, definition.max_level)
	return true
