class_name ModuleCatalog
extends RefCounted

## Every module the player can install, in panel order.
##
## Stats are never duplicated here: they are read from each module scene
## (exported values and getters), so tuning a .tscn updates the UI too.

const ENTRIES: Array[Dictionary] = [
	{"id": &"machine_gun", "name": "Machine Gun", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn"},
	{"id": &"dwarf_cannon", "name": "Dwarf Cannon", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn"},
	{"id": &"laser", "name": "Laser", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Laser/laser.tscn"},
	{"id": &"chainsaw", "name": "Chainsaw", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Chainsaw/chainsaw.tscn"},
	{"id": &"flamethrower", "name": "Flamethrower", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Flamethrower/flamethrower.tscn"},
	{"id": &"scatter_machine_gun", "name": "Scatter Machine Gun", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/scatter_machine_gun.tscn", "fusion_only": true,
		"research_source_id": &"scatter_machine_gun", "artifact_compatibility_ids": [&"machine_gun"]},
	{"id": &"knockback_machine_gun", "name": "Knockback Machine Gun", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/knockback_machine_gun.tscn", "fusion_only": true,
		"research_source_id": &"knockback_machine_gun", "artifact_compatibility_ids": [&"machine_gun", &"knockback_module"]},
	{"id": &"laser_machine_gun", "name": "Laser Machine Gun", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/laser_machine_gun.tscn", "fusion_only": true,
		"research_source_id": &"laser_machine_gun", "artifact_compatibility_ids": [&"machine_gun", &"laser"]},
	{"id": &"sawblade_machine_gun", "name": "Sawblade Machine Gun", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/sawblade_machine_gun.tscn", "fusion_only": true,
		"research_source_id": &"sawblade_machine_gun", "artifact_compatibility_ids": [&"machine_gun", &"chainsaw"]},
	{"id": &"flame_machine_gun", "name": "Flame Machine Gun", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/flame_machine_gun.tscn", "fusion_only": true,
		"research_source_id": &"flame_machine_gun", "artifact_compatibility_ids": [&"machine_gun", &"flamethrower"]},
	{"id": &"laser_chainsaw", "name": "Laser Chainsaw", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/laser_chainsaw.tscn", "fusion_only": true,
		"research_source_id": &"laser_chainsaw", "artifact_compatibility_ids": [&"chainsaw", &"laser"]},
	{"id": &"heavy_laser", "name": "Heavy Laser", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/heavy_laser.tscn", "fusion_only": true,
		"research_source_id": &"heavy_laser", "artifact_compatibility_ids": [&"laser", &"dwarf_cannon"],
		"artifact_incompatible_ids": [&"angry_stone", &"ghost_bullet", &"red_crystal", &"true_ice"]},
	{"id": &"automatic_cannon", "name": "Automatic Cannon", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/automatic_cannon.tscn", "fusion_only": true,
		"research_source_id": &"automatic_cannon", "artifact_compatibility_ids": [&"dwarf_cannon", &"machine_gun"]},
	{"id": &"siege_cannon", "name": "Siege Cannon", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/siege_cannon.tscn", "fusion_only": true,
		"research_source_id": &"siege_cannon", "artifact_compatibility_ids": [&"dwarf_cannon"]},
	{"id": &"knockback_cannon", "name": "Long-Range Knockback Cannon", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/knockback_cannon.tscn", "fusion_only": true,
		"research_source_id": &"knockback_cannon", "artifact_compatibility_ids": [&"dwarf_cannon", &"knockback_module"]},
	{"id": &"flame_cannon", "name": "Flame Cannon", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/flame_cannon.tscn", "fusion_only": true,
		"research_source_id": &"flame_cannon", "artifact_compatibility_ids": [&"dwarf_cannon", &"flamethrower"]},
	{"id": &"knockback_laser", "name": "Knockback Laser", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/knockback_laser.tscn", "fusion_only": true,
		"research_source_id": &"knockback_laser", "artifact_compatibility_ids": [&"laser", &"knockback_module"],
		"artifact_incompatible_ids": [&"ghost_bullet", &"red_crystal"]},
	{"id": &"flame_laser", "name": "Flame Laser", "group": &"weapon",
		"scene": "res://Scenes/Modules/Weapons/Fusion/flame_laser.tscn", "fusion_only": true,
		"research_source_id": &"flame_laser", "artifact_compatibility_ids": [&"laser", &"flamethrower"],
		"artifact_incompatible_ids": [&"angry_stone", &"ghost_bullet", &"red_crystal", &"true_ice"]},
	{"id": &"energy_module", "name": "Energy", "group": &"system",
		"scene": "res://Scenes/Modules/Energy/energy_module.tscn"},
	{"id": &"mining_module", "name": "Mining", "group": &"system",
		"scene": "res://Scenes/Modules/Mining/mining_module.tscn"},
	{"id": &"knockback_module", "name": "Knockback", "group": &"shield",
		"scene": "res://Scenes/Modules/Shield/knockback_module.tscn"},
	{"id": &"regeneration_module", "name": "Regeneration", "group": &"shield",
		"scene": "res://Scenes/Modules/Shield/regeneration_module.tscn"},
]

static var _stats_cache: Dictionary = {}


static func clear_stats_cache() -> void:
	_stats_cache.clear()


static func get_entry(id: StringName) -> Dictionary:
	for entry in ENTRIES:
		if entry["id"] == id:
			return entry
	return {}


## Finds the catalog entry whose scene matches an installed module's path.
static func find_by_scene(scene_path: String) -> Dictionary:
	for entry in ENTRIES:
		if entry["scene"] == scene_path:
			return entry
	return {}


static func get_scene(id: StringName) -> PackedScene:
	var entry := get_entry(id)
	if entry.is_empty():
		return null
	return load(entry["scene"]) as PackedScene


## Ship.ModuleType matching the module's category.
static func get_module_type(id: StringName) -> int:
	match String(get_stats(id).get("category", "")):
		"weapon":
			return Ship.ModuleType.Weapon
		"mining":
			return Ship.ModuleType.Mining
		"energy":
			return Ship.ModuleType.Energy
		"shield":
			return Ship.ModuleType.Shield
	return Ship.ModuleType.Empty


static func is_weapon(id: StringName) -> bool:
	return get_entry(id).get("group", &"") == &"weapon"


## Non-weapon systems are not part of weapon progression.
## Weapons and any module with an unlock definition (e.g. shields) are gated by
## WeaponUnlockManager; other systems are always available.
static func is_module_unlocked(id: StringName) -> bool:
	if WeaponFusionRegistry.is_fused_module(id):
		return WeaponFusionRegistry.is_unlocked()
	if is_weapon(id) or WeaponUnlockManager.get_definition(id) != null:
		return WeaponUnlockManager.is_weapon_unlocked(id)
	return true


static func get_unlock_requirement(id: StringName) -> String:
	if WeaponFusionRegistry.is_fused_module(id):
		return WeaponFusionRegistry.get_unlock_requirement()
	if is_weapon(id) or WeaponUnlockManager.get_definition(id) != null:
		return WeaponUnlockManager.get_unlock_requirement(id)
	return ""


## Reads gameplay values from a temporary instance of the module scene.
static func get_stats(id: StringName) -> Dictionary:
	# Energy capacity and hull bonus depend on current research. Re-read this
	# module so a cached +1 Power cannot survive a research reset.
	var has_dynamic_research_stats := id == &"energy_module"
	if not has_dynamic_research_stats and _stats_cache.has(id):
		return _stats_cache[id]

	var stats: Dictionary = {}
	var scene := get_scene(id)
	var module := scene.instantiate() if scene != null else null
	if module is ShipModule:
		var ship_module := module as ShipModule
		stats["category"] = String(ship_module.get_module_category())
		stats["power_cost"] = ship_module.get_power_consumption()
		stats["power_capacity"] = ship_module.get_power_capacity()
		if ship_module is WeaponModule:
			var weapon := ship_module as WeaponModule
			if "basic_damage" in weapon:
				stats["base_damage"] = float(weapon.get("basic_damage"))
			stats["damage"] = weapon.get_damage()
			stats["fire_rate"] = weapon.get_fire_rate()
			for key in ["attack_range", "projectile_range", "attack_radius", "aoe_radius"]:
				if key in weapon:
					stats[key] = float(weapon.get(key))
		if "mining_rate" in ship_module:
			stats["mining_rate"] = float(ship_module.get("mining_rate"))
		stats["max_hp_bonus"] = ship_module.get_max_hp_bonus()
		stats["regeneration_per_second"] = ship_module.get_regeneration_per_second()
		for key in ["knockback_damage", "trigger_range", "splash_radius", "cooldown", "healing_amount", "healing_interval", "healing_radius"]:
			if key in ship_module:
				stats[key] = ship_module.get(key)
	if module != null:
		module.free()

	if not has_dynamic_research_stats:
		_stats_cache[id] = stats
	return stats


## Untouched damage used by research previews and additive modifier math.
static func get_base_weapon_damage(id: StringName) -> float:
	return float(get_stats(id).get("base_damage", 0.0))


## Largest value of a stat across the catalog, used to scale stat bars.
static func get_stat_max(key: String) -> float:
	var best := 0.0
	for entry in ENTRIES:
		if bool(entry.get("fusion_only", false)):
			continue
		var stats := get_stats(entry["id"])
		var value := float(stats.get(key, 0.0))
		if key == "dps":
			value = float(stats.get("damage", 0.0)) * float(stats.get("fire_rate", 0.0))
		best = maxf(best, value)
	return maxf(best, 0.001)


## One-line summary shown on list cards.
static func get_summary(id: StringName) -> String:
	var stats := get_stats(id)
	match String(stats.get("category", "")):
		"weapon":
			var parts := ["DMG %s" % format_number(stats.get("damage", 0.0)), "%s/s" % format_number(stats.get("fire_rate", 0.0))]
			if stats.has("aoe_radius"):
				parts.append("AOE %s" % format_number(stats["aoe_radius"]))
			elif stats.has("attack_radius"):
				parts.append("RADIUS %s" % format_number(stats["attack_radius"]))
			elif stats.has("attack_range"):
				parts.append("RNG %s" % format_number(stats["attack_range"]))
			return " · ".join(parts)
		"energy":
			return "+%d POWER" % int(stats.get("power_capacity", 0))
		"mining":
			return "%s ORE / s" % format_number(stats.get("mining_rate", 0.0))
		"shield":
			return "+%s HULL" % format_number(stats.get("max_hp_bonus", 0.0))
	return ""


## Formats numbers without trailing ".0" noise.
static func format_number(value: Variant) -> String:
	var number := float(value)
	if is_equal_approx(number, roundf(number)):
		return str(int(roundf(number)))
	return "%.1f" % number
