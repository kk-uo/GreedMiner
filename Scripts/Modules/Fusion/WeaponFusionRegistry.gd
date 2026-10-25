class_name WeaponFusionRegistry
extends RefCounted

## Data-driven weapon fusion recipes. Ingredient order never matters.

const REQUIRED_PLANET: StringName = &"graveyard_planet"
const REQUIRED_RESEARCH_LEVEL: int = 30
const FUSION_DURATION_SECONDS: float = 1.0
const SAVE_SECTION: StringName = &"weapon_fusion"
const DEVELOPER_UNLOCK_KEY: StringName = &"developer_unlocked"
const BASE_WEAPONS: Array[StringName] = [
	&"machine_gun",
	&"dwarf_cannon",
	&"laser",
	&"chainsaw",
	&"flamethrower",
]

static var RECIPES: Array[Dictionary] = [
	_recipe(&"machine_gun", &"machine_gun", &"scatter_machine_gun", "Scatter Machine Gun"),
	_recipe(&"knockback_module", &"machine_gun", &"knockback_machine_gun", "Knockback Machine Gun"),
	_recipe(&"laser", &"machine_gun", &"laser_machine_gun", "Laser Machine Gun"),
	_recipe(&"chainsaw", &"machine_gun", &"sawblade_machine_gun", "Sawblade Machine Gun"),
	_recipe(&"flamethrower", &"machine_gun", &"flame_machine_gun", "Flame Machine Gun"),
	_recipe(&"chainsaw", &"laser", &"laser_chainsaw", "Laser Chainsaw"),
	_recipe(&"dwarf_cannon", &"laser", &"heavy_laser", "Heavy Laser"),
	_recipe(&"dwarf_cannon", &"machine_gun", &"automatic_cannon", "Automatic Cannon"),
	_recipe(&"dwarf_cannon", &"dwarf_cannon", &"siege_cannon", "Siege Cannon"),
	_recipe(&"dwarf_cannon", &"knockback_module", &"knockback_cannon", "Long-Range Knockback Cannon"),
	_recipe(&"dwarf_cannon", &"flamethrower", &"flame_cannon", "Flame Cannon"),
	_recipe(&"knockback_module", &"laser", &"knockback_laser", "Knockback Laser"),
	_recipe(&"flamethrower", &"laser", &"flame_laser", "Flame Laser"),
]


static func _recipe(first: StringName, second: StringName, result: StringName, display_name: String) -> Dictionary:
	return {
		"ingredients": [first, second],
		"result_id": result,
		"display_name": display_name,
		"scene": "res://Scenes/Modules/Weapons/Fusion/%s.tscn" % String(result),
		"duration": FUSION_DURATION_SECONDS,
	}


static func find_recipe(first: StringName, second: StringName) -> Dictionary:
	if first.is_empty() or second.is_empty() or is_fused_module(first) or is_fused_module(second):
		return {}
	for recipe in RECIPES:
		var ingredients: Array = recipe["ingredients"]
		if (
			(ingredients[0] == first and ingredients[1] == second)
			or (ingredients[0] == second and ingredients[1] == first)
		):
			return recipe
	return {}


static func get_recipe_for_result(result_id: StringName) -> Dictionary:
	for recipe in RECIPES:
		if recipe["result_id"] == result_id:
			return recipe
	return {}


static func is_fused_module(module_id: StringName) -> bool:
	return not get_recipe_for_result(module_id).is_empty()


static func is_unlocked() -> bool:
	if is_developer_unlocked():
		return true
	if not WeaponUnlockManager.has_completed_planet(REQUIRED_PLANET):
		return false
	for weapon_id in BASE_WEAPONS:
		if ResearchManager.get_weapon_research_level(weapon_id) < REQUIRED_RESEARCH_LEVEL:
			return false
	return true


## Developer Mode can expose fusion for testing without forging a Graveyard
## clear or changing ordinary weapon research. The override is persisted in its
## own progression section and is removed by Reset All Progress.
static func is_developer_unlocked() -> bool:
	return bool(ProgressionStore.get_section(SAVE_SECTION).get(DEVELOPER_UNLOCK_KEY, false))


static func unlock_for_development() -> bool:
	if not DeveloperCommands.is_available():
		return false
	if is_developer_unlocked():
		return true
	var data := ProgressionStore.get_section(SAVE_SECTION)
	data[DEVELOPER_UNLOCK_KEY] = true
	return ProgressionStore.set_section(SAVE_SECTION, data)


static func get_unlock_requirement() -> String:
	if not WeaponUnlockManager.has_completed_planet(REQUIRED_PLANET):
		return "Clear the Graveyard Planet to unlock Weapon Fusion."
	var incomplete: Array[String] = []
	for weapon_id in BASE_WEAPONS:
		if ResearchManager.get_weapon_research_level(weapon_id) < REQUIRED_RESEARCH_LEVEL:
			var entry := ModuleCatalog.get_entry(weapon_id)
			incomplete.append(String(entry.get("name", weapon_id)))
	if not incomplete.is_empty():
		return "Reach Level 30 with every weapon. Missing: %s." % ", ".join(incomplete)
	return ""
