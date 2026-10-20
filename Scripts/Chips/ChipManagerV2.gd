extends Node

## Owns unlimited chip instances, per-instance quality, crafting, scrapping,
## and per-module-instance socket assignments (keyed by ship cell).

signal chip_inventory_changed(chip_id: StringName, owned_count: int)
signal chip_instance_changed(instance_id: StringName)
signal chip_equipment_changed(slot_id: StringName, chip_id: StringName)
signal chip_operation_failed(reason: String)

const DEFAULT_CONFIGURATION: ChipConfiguration = preload("res://Resources/Chips/ChipConfiguration.tres")
const SAVE_SECTION: StringName = &"chips"
const SAVE_VERSION: int = 5
const LEGACY_FLAT_DAMAGE_ID: StringName = &"damage_chip"
const MIGRATED_FLAT_DAMAGE_ID: StringName = &"attack_chip"
const TURRET_KEY_PREFIX: String = "turret."
const MODULE_KEY_PREFIX: String = "module."
## Share of the Ore invested in a chip that scrapping it returns.
const SCRAP_REFUND_RATIO: float = 0.5

var configuration: ChipConfiguration = DEFAULT_CONFIGURATION
## Compatibility count cache. Authoritative ownership lives in chip_instances.
var owned_chips: Dictionary = {}
## instance_id -> {"chip_type_id": String, "quality": int}
var chip_instances: Dictionary = {}
var loadout: ChipLoadout = ChipLoadout.new()
var _next_instance_sequence: int = 1
var equipment_changes_enabled: bool = true


func _ready() -> void:
	reload_progress()
	ShipLoadout.cell_changed.connect(_on_ship_cell_changed)
	ShipLoadout.cells_swapped.connect(_on_ship_cells_swapped)


func reload_progress() -> void:
	var data := ProgressionStore.get_section(SAVE_SECTION)
	chip_instances.clear()
	loadout = ChipLoadout.new()
	_next_instance_sequence = maxi(int(data.get("next_instance_sequence", 1)), 1)
	var migrated := false
	var raw_instances: Variant = data.get("instances", null)
	if raw_instances is Dictionary:
		for raw_id in (raw_instances as Dictionary).keys():
			var raw_record: Variant = (raw_instances as Dictionary)[raw_id]
			if not raw_record is Dictionary:
				continue
			var type_id := StringName(String((raw_record as Dictionary).get("chip_type_id", "")))
			if type_id.is_empty():
				continue
			chip_instances[String(raw_id)] = {
				"chip_type_id": String(type_id),
				"quality": maxi(int((raw_record as Dictionary).get("quality", 0)), 0),
			}
	else:
		var legacy_owned: Variant = data.get("owned", {})
		if legacy_owned is Dictionary:
			for raw_type in (legacy_owned as Dictionary).keys():
				var type_id := _migrate_legacy_type(StringName(String(raw_type)))
				var count := maxi(int((legacy_owned as Dictionary)[raw_type]), 0)
				for _index in range(count):
					_create_instance(type_id, 0)
				migrated = migrated or count > 0

	var raw_equipped: Variant = data.get("equipped", {})
	if raw_equipped is Dictionary:
		loadout.import_data((raw_equipped as Dictionary).duplicate(true))
	if _migrate_and_validate_assignments(int(data.get("version", 1))):
		migrated = true
	_rebuild_owned_counts()
	if migrated:
		save_progress()


func save_progress() -> bool:
	return ProgressionStore.set_section(SAVE_SECTION, {
		"version": SAVE_VERSION,
		"next_instance_sequence": _next_instance_sequence,
		"instances": chip_instances.duplicate(true),
		"equipped": loadout.export_data(),
		"owned": owned_chips.duplicate(true),
	})


func is_chip_laboratory_unlocked() -> bool:
	return ResearchManager.is_chip_laboratory_unlocked()


func set_equipment_changes_enabled(enabled: bool) -> void:
	equipment_changes_enabled = enabled


func get_owned_count(chip_id: StringName) -> int:
	return maxi(int(owned_chips.get(String(chip_id), 0)), 0)


func get_owned_instances(chip_id: StringName = &"") -> Array[StringName]:
	var result: Array[StringName] = []
	for instance_key in chip_instances.keys():
		var record := chip_instances[instance_key] as Dictionary
		if chip_id.is_empty() or StringName(record.get("chip_type_id", "")) == chip_id:
			result.append(StringName(String(instance_key)))
	result.sort()
	return result


func get_chip_instance(instance_id: StringName) -> Dictionary:
	var record: Variant = chip_instances.get(String(instance_id), {})
	return (record as Dictionary).duplicate(true) if record is Dictionary else {}


func get_instance_chip_type(instance_id: StringName) -> StringName:
	return StringName(String(get_chip_instance(instance_id).get("chip_type_id", "")))


func get_instance_quality_index(instance_id: StringName) -> int:
	return maxi(int(get_chip_instance(instance_id).get("quality", 0)), 0)


func get_instance_quality(instance_id: StringName) -> ChipQualityTier:
	var definition := configuration.get_chip(get_instance_chip_type(instance_id))
	return definition.get_quality(get_instance_quality_index(instance_id)) if definition != null else null


## Debug/test ownership helper. Player purchases must use craft_chip().
func add_owned_chip(chip_id: StringName, amount: int = 1) -> bool:
	var definition := configuration.get_chip(chip_id)
	if definition == null or not definition.enabled or amount <= 0:
		return _fail("Unknown, disabled, or invalid chip ownership request.")
	if amount > 9223372036854775807 - chip_instances.size():
		return _fail("Chip ownership amount is too large.")
	var previous_instances := chip_instances.duplicate(true)
	var previous_sequence := _next_instance_sequence
	for _index in range(amount):
		_create_instance(chip_id, 0)
	_rebuild_owned_counts()
	if not save_progress():
		chip_instances = previous_instances
		_next_instance_sequence = previous_sequence
		_rebuild_owned_counts()
		return _fail("Could not save chip instances.")
	chip_inventory_changed.emit(chip_id, get_owned_count(chip_id))
	return true


## Atomically spends Ore and creates one independently persisted chip.
func craft_chip(chip_id: StringName) -> StringName:
	if not is_chip_laboratory_unlocked():
		_fail("Chip Laboratory unlocks when a weapon reaches Level 10.")
		return &""
	var definition := configuration.get_chip(chip_id)
	if definition == null or not definition.enabled:
		_fail("Unknown or disabled chip recipe.")
		return &""
	var cost := configuration.get_crafting_cost(chip_id)
	if cost < 0 or not ResourceManager.try_spend_stored_ore(cost):
		_fail("Insufficient stored ore.")
		return &""
	var instance_id := _create_instance(chip_id, 0)
	_rebuild_owned_counts()
	if not save_progress():
		chip_instances.erase(String(instance_id))
		_rebuild_owned_counts()
		ResourceManager.add_stored_ore(float(cost))
		_fail("Could not save the crafted chip.")
		return &""
	chip_inventory_changed.emit(chip_id, get_owned_count(chip_id))
	chip_instance_changed.emit(instance_id)
	return instance_id


func get_quality_upgrade_cost(instance_id: StringName) -> int:
	var definition := configuration.get_chip(get_instance_chip_type(instance_id))
	if definition == null:
		return -1
	var next_quality := definition.get_quality(get_instance_quality_index(instance_id) + 1)
	return next_quality.upgrade_cost if next_quality != null else -1


func can_upgrade_quality(instance_id: StringName) -> bool:
	return get_quality_upgrade_cost(instance_id) >= 0


func upgrade_chip_quality(instance_id: StringName) -> bool:
	var key := String(instance_id)
	if not chip_instances.has(key):
		return _fail("Owned chip instance was not found.")
	var cost := get_quality_upgrade_cost(instance_id)
	if cost < 0:
		return _fail("This chip quality upgrade is not configured.")
	if not ResourceManager.try_spend_stored_ore(cost):
		return _fail("Insufficient stored ore.")
	var record := chip_instances[key] as Dictionary
	var previous_quality := maxi(int(record.get("quality", 0)), 0)
	record["quality"] = previous_quality + 1
	chip_instances[key] = record
	if not save_progress():
		record["quality"] = previous_quality
		chip_instances[key] = record
		ResourceManager.add_stored_ore(float(cost))
		return _fail("Could not save the chip quality upgrade.")
	chip_instance_changed.emit(instance_id)
	return true


func get_weapon_slot_id(weapon_type_id: StringName, slot_index: int) -> StringName:
	var template := configuration.get_weapon_slot(weapon_type_id)
	if template == null:
		return &""
	return StringName("%s.%d" % [String(template.slot_id), slot_index])


func get_unlocked_weapon_slot_count(weapon_type_id: StringName) -> int:
	if configuration.get_weapon_slot(weapon_type_id) == null:
		return 0
	return mini(ResearchManager.get_weapon_chip_slot_count(weapon_type_id), configuration.max_weapon_chip_slots)


## Research level that opens socket `slot_index` of a weapon type (0 = unknown).
func get_weapon_slot_unlock_level(weapon_type_id: StringName, slot_index: int) -> int:
	var definition := ResearchManager.get_weapon_research_definition(weapon_type_id)
	if definition == null:
		return 0
	var levels: Array[int] = []
	for milestone in definition.milestones:
		if milestone != null:
			for _index in range(maxi(milestone.weapon_chip_slots_unlocked, 0)):
				levels.append(milestone.target_level)
	levels.sort()
	return levels[slot_index] if slot_index >= 0 and slot_index < levels.size() else 0


func is_weapon_chip_slot_unlocked(weapon_type_id: StringName) -> bool:
	return get_unlocked_weapon_slot_count(weapon_type_id) > 0


func is_chip_compatible_with_weapon(weapon_type_id: StringName, chip_id: StringName) -> bool:
	var slot := configuration.get_weapon_slot(weapon_type_id)
	var chip := configuration.get_chip(chip_id)
	if slot == null or chip == null or not slot.accepts(chip) or not _chip_unlock_requirements_met(chip):
		return false
	if chip_id != &"skill_chip":
		return true
	var scene := ModuleCatalog.get_scene(weapon_type_id)
	var module := scene.instantiate() as ShipModule if scene != null else null
	var supported := module != null and module.supports_active_skill()
	if module != null:
		module.free()
	return supported


## Stable module ID and adaptation kind for any installed chip-capable module.
func get_module_id(cell: Vector2i) -> StringName:
	var entry := ModuleCatalog.find_by_scene(ShipLoadout.get_module(cell.x, cell.y))
	return StringName(entry.get("id", &"")) if not entry.is_empty() else &""


func get_module_kind(cell: Vector2i) -> StringName:
	var id := get_module_id(cell)
	if ModuleCatalog.is_weapon(id):
		return &"weapon"
	if id == &"knockback_module":
		return &"knockback"
	if id == &"regeneration_module":
		return &"regeneration"
	return &""


func _instantiate_module(cell: Vector2i) -> ShipModule:
	var scene := ModuleCatalog.get_scene(get_module_id(cell))
	return scene.instantiate() as ShipModule if scene != null else null


func module_supports_active_skill(cell: Vector2i) -> bool:
	var module := _instantiate_module(cell)
	var supported := module != null and module.supports_active_skill()
	if module != null:
		module.free()
	return supported


func is_chip_compatible_with_module(cell: Vector2i, chip_id: StringName) -> bool:
	var kind := get_module_kind(cell)
	var chip := configuration.get_chip(chip_id)
	if kind.is_empty() or chip == null or not chip.enabled or not _chip_unlock_requirements_met(chip):
		return false
	if kind == &"weapon":
		return is_chip_compatible_with_weapon(get_turret_weapon_type(cell), chip_id)
	if chip_id == &"skill_chip":
		return module_supports_active_skill(cell)
	var candidate_stats: Array[StringName] = [&"healing_amount", &"healing_frequency", &"healing_radius"]
	if kind == &"knockback":
		candidate_stats = [&"shockwave_damage", &"knockback_frequency", &"trigger_range", &"splash_radius"]
	for quality in chip.qualities:
		if quality == null:
			continue
		for effect in quality.effects:
			if effect is ChipStatEffect:
				for stat_id in candidate_stats:
					if (effect as ChipStatEffect).supports_context({"stat_id": stat_id, "module_kind": kind}):
						return true
	return false


func get_module_slot_key(cell: Vector2i, slot_index: int) -> String:
	if get_module_kind(cell) == &"weapon":
		return "%s%d.%d.%d" % [TURRET_KEY_PREFIX, cell.x, cell.y, slot_index]
	return "%s%d.%d.%d" % [MODULE_KEY_PREFIX, cell.x, cell.y, slot_index]


func get_module_slot_count(cell: Vector2i) -> int:
	var kind := get_module_kind(cell)
	if kind == &"weapon":
		return get_turret_slot_count(cell)
	if kind not in [&"knockback", &"regeneration"] or not is_chip_laboratory_unlocked():
		return 0
	var stats := ModuleCatalog.get_stats(get_module_id(cell))
	var maximum_slots := maxi(int(stats.get("max_chip_slots", 3)), 0)
	return mini(
		ResearchManager.get_shield_bonus_chip_slot_count(get_module_id(cell)),
		maximum_slots
	)


func get_module_chip(cell: Vector2i, slot_index: int) -> StringName:
	return StringName(String(loadout.assignments.get(get_module_slot_key(cell, slot_index), "")))


func get_module_chips(cell: Vector2i) -> Array[StringName]:
	var result: Array[StringName] = []
	for index in range(get_module_slot_count(cell)):
		var instance_id := get_module_chip(cell, index)
		if not instance_id.is_empty():
			result.append(instance_id)
	return result


func equip_module_chip(cell: Vector2i, slot_index: int, instance_id: StringName) -> bool:
	if not equipment_changes_enabled:
		return _fail("Chips can only be changed at the base.")
	if get_module_kind(cell).is_empty():
		return _fail("This module does not support chips.")
	if slot_index < 0 or slot_index >= get_module_slot_count(cell):
		return _fail("Module chip slot is locked.")
	var chip_id := get_instance_chip_type(instance_id)
	if chip_id.is_empty() or not is_chip_compatible_with_module(cell, chip_id):
		return _fail("Chip is missing or incompatible with this module.")
	var slot_key := get_module_slot_key(cell, slot_index)
	var current := String(loadout.assignments.get(slot_key, ""))
	if current == String(instance_id):
		return true
	var previous := loadout.assignments.duplicate()
	var old_key := _find_assignment_key(instance_id)
	if not old_key.is_empty():
		loadout.assignments.erase(old_key)
	loadout.assignments[slot_key] = String(instance_id)
	if not save_progress():
		loadout.assignments = previous
		return _fail("Could not save chip equipment.")
	if not old_key.is_empty():
		chip_equipment_changed.emit(StringName(old_key), &"")
	chip_equipment_changed.emit(StringName(slot_key), chip_id)
	return true


func unequip_module_chip(cell: Vector2i, slot_index: int) -> bool:
	if not equipment_changes_enabled:
		return _fail("Chips can only be changed at the base.")
	var slot_key := get_module_slot_key(cell, slot_index)
	if not loadout.assignments.has(slot_key):
		return false
	var old_instance := String(loadout.assignments[slot_key])
	loadout.assignments.erase(slot_key)
	if not save_progress():
		loadout.assignments[slot_key] = old_instance
		return _fail("Could not save chip equipment.")
	chip_equipment_changed.emit(StringName(slot_key), &"")
	return true


# ==========================================
# Per-weapon-instance sockets
# ==========================================
# Research unlocks the socket count by weapon type, while each installed turret
# owns its own independently persisted assignments.

## Assignment key for socket `slot_index` of the turret in `cell`.
func get_turret_slot_key(cell: Vector2i, slot_index: int) -> String:
	return "%s%d.%d.%d" % [TURRET_KEY_PREFIX, cell.x, cell.y, slot_index]


## Weapon type installed in a ship cell, or &"" for empty / non-weapon cells.
func get_turret_weapon_type(cell: Vector2i) -> StringName:
	var scene_path := ShipLoadout.get_module(cell.x, cell.y)
	if scene_path.is_empty():
		return &""
	var entry := ModuleCatalog.find_by_scene(scene_path)
	if entry.is_empty() or entry.get("group", &"") != &"weapon":
		return &""
	return StringName(entry["id"])


func get_turret_slot_count(cell: Vector2i) -> int:
	var weapon_type := get_turret_weapon_type(cell)
	return 0 if weapon_type.is_empty() else get_unlocked_weapon_slot_count(weapon_type)


func get_turret_chip(cell: Vector2i, slot_index: int) -> StringName:
	return get_module_chip(cell, slot_index)


## Instances that currently affect the turret (only open sockets count).
func get_turret_chips(cell: Vector2i) -> Array[StringName]:
	return get_module_chips(cell)


## Installs a chip into a turret socket. A chip installed elsewhere moves here.
func equip_turret_chip(cell: Vector2i, slot_index: int, instance_id: StringName) -> bool:
	# Retained public API for existing UI/tests; all new validation is shared.
	if get_module_kind(cell) == &"weapon":
		return equip_module_chip(cell, slot_index, instance_id)
	return _fail("Chips can only be installed in weapon modules.")


func _legacy_equip_turret_chip(cell: Vector2i, slot_index: int, instance_id: StringName) -> bool:
	var weapon_type := get_turret_weapon_type(cell)
	if weapon_type.is_empty():
		return _fail("Chips can only be installed in weapon modules.")
	if slot_index < 0 or slot_index >= get_unlocked_weapon_slot_count(weapon_type):
		return _fail("Weapon chip slot is locked.")
	var chip_id := get_instance_chip_type(instance_id)
	if chip_id.is_empty() or not is_chip_compatible_with_weapon(weapon_type, chip_id):
		return _fail("Chip is missing or incompatible with this weapon.")
	var slot_key := get_turret_slot_key(cell, slot_index)
	var current_instance := String(loadout.assignments.get(slot_key, ""))
	if current_instance == String(instance_id):
		return true
	if not configuration.allow_duplicate_chip_types_per_weapon:
		for index in range(get_unlocked_weapon_slot_count(weapon_type)):
			var other := get_turret_chip(cell, index)
			if index != slot_index and other != instance_id and not other.is_empty() and get_instance_chip_type(other) == chip_id:
				return _fail("Duplicate chip types are disabled for this weapon.")
	var previous := loadout.assignments.duplicate()
	var old_key := _find_assignment_key(instance_id)
	if not old_key.is_empty():
		loadout.assignments.erase(old_key)
	loadout.assignments[slot_key] = String(instance_id)
	if not save_progress():
		loadout.assignments = previous
		return _fail("Could not save chip equipment.")
	if not old_key.is_empty():
		chip_equipment_changed.emit(StringName(old_key), &"")
	chip_equipment_changed.emit(StringName(slot_key), chip_id)
	return true


func unequip_turret_chip(cell: Vector2i, slot_index: int) -> bool:
	return unequip_module_chip(cell, slot_index)


func is_instance_equipped(instance_id: StringName) -> bool:
	return loadout.assignments.values().has(String(instance_id))


## Installed module cell for UI, or (-1, -1) when idle.
func get_instance_location(instance_id: StringName) -> Vector2i:
	var key := _find_assignment_key(instance_id)
	var parsed := _parse_module_key(key)
	return Vector2i(parsed.x, parsed.y) if parsed.x >= 0 else Vector2i(-1, -1)


## Socket index holding the chip, or -1 when idle.
func get_instance_slot_index(instance_id: StringName) -> int:
	var key := _find_assignment_key(instance_id)
	var parsed := _parse_module_key(key)
	return parsed.z


## Total Ore spent on this instance: recipe plus every quality upgrade.
func get_instance_ore_invested(instance_id: StringName) -> int:
	var chip_id := get_instance_chip_type(instance_id)
	var definition := configuration.get_chip(chip_id)
	if definition == null:
		return 0
	var total := maxi(configuration.get_crafting_cost(chip_id), 0)
	for index in range(1, get_instance_quality_index(instance_id) + 1):
		var tier := definition.get_quality(index)
		if tier != null:
			total += maxi(tier.upgrade_cost, 0)
	return total


func get_scrap_refund(instance_id: StringName) -> int:
	return int(floor(float(get_instance_ore_invested(instance_id)) * SCRAP_REFUND_RATIO))


## Destroys an idle chip and refunds part of the Ore spent on it.
func scrap_chip(instance_id: StringName) -> int:
	var key := String(instance_id)
	if not chip_instances.has(key):
		_fail("Owned chip instance was not found.")
		return -1
	if is_instance_equipped(instance_id):
		_fail("Uninstall the chip before scrapping it.")
		return -1
	var refund := get_scrap_refund(instance_id)
	var chip_id := get_instance_chip_type(instance_id)
	var record: Dictionary = chip_instances[key]
	chip_instances.erase(key)
	_rebuild_owned_counts()
	if not save_progress():
		chip_instances[key] = record
		_rebuild_owned_counts()
		_fail("Could not save the scrapped chip.")
		return -1
	if refund > 0:
		ResourceManager.add_stored_ore(float(refund))
	chip_inventory_changed.emit(chip_id, get_owned_count(chip_id))
	return refund


## Accepts a weapon/module instance or a cell preview. Modules outside a ship
## get no chips; the same physical chip can never affect two modules.
func get_stat_modifiers(context: Dictionary) -> Array[StatModifier]:
	var modifiers: Array[StatModifier] = []
	var cell := _resolve_context_cell(context)
	if cell.x < 0:
		return modifiers
	var adapted_context := context.duplicate()
	if StringName(adapted_context.get("module_kind", &"")).is_empty():
		adapted_context["module_kind"] = get_module_kind(cell)
	if not adapted_context.has("supports_active_skill"):
		adapted_context["supports_active_skill"] = module_supports_active_skill(cell)
	for instance_id in get_module_chips(cell):
		var definition := configuration.get_chip(get_instance_chip_type(instance_id))
		if definition == null:
			continue
		for effect in definition.get_effects_for_quality(get_instance_quality_index(instance_id)):
			if effect != null:
				modifiers.append_array(effect.get_stat_modifiers(instance_id, adapted_context))
	return _apply_percentage_stacking_policy(modifiers)


func _resolve_context_cell(context: Dictionary) -> Vector2i:
	var raw_cell: Variant = context.get("cell", null)
	if raw_cell is Vector2i:
		return raw_cell
	var module: Variant = context.get("module_instance", context.get("weapon_instance", null))
	if not is_instance_valid(module) or not module is Node:
		return Vector2i(-1, -1)
	var node := (module as Node).get_parent()
	while node != null:
		if node.has_method("get_module_cell"):
			return node.call("get_module_cell", module)
		node = node.get_parent()
	return Vector2i(-1, -1)


func _on_ship_cell_changed(cell: Vector2i, old_path: String, new_path: String) -> void:
	if old_path == new_path:
		return
	var changed := false
	for key in loadout.assignments.keys():
		var parsed := _parse_module_key(String(key))
		if parsed.x == cell.x and parsed.y == cell.y:
			loadout.assignments.erase(key)
			changed = true
	if changed:
		save_progress()
		chip_equipment_changed.emit(&"", &"")


func _on_ship_cells_swapped(cell_a: Vector2i, cell_b: Vector2i) -> void:
	var moved: Dictionary = {}
	var changed := false
	for key in loadout.assignments.keys():
		var parsed := _parse_module_key(String(key))
		if parsed.x < 0:
			moved[key] = loadout.assignments[key]
			continue
		var cell := Vector2i(parsed.x, parsed.y)
		if cell == cell_a:
			cell = cell_b
		elif cell == cell_b:
			cell = cell_a
		else:
			moved[key] = loadout.assignments[key]
			continue
		var prefix := TURRET_KEY_PREFIX if String(key).begins_with(TURRET_KEY_PREFIX) else MODULE_KEY_PREFIX
		moved["%s%d.%d.%d" % [prefix, cell.x, cell.y, parsed.z]] = loadout.assignments[key]
		changed = true
	if changed:
		loadout.assignments = moved
		save_progress()
		chip_equipment_changed.emit(&"", &"")


func _find_assignment_key(instance_id: StringName) -> String:
	for key in loadout.assignments.keys():
		if String(loadout.assignments[key]) == String(instance_id):
			return String(key)
	return ""


## "turret.R.C.I" -> Vector3i(R, C, I); anything else -> (-1, -1, -1).
func _parse_turret_key(key: String) -> Vector3i:
	if not key.begins_with(TURRET_KEY_PREFIX):
		return Vector3i(-1, -1, -1)
	var parts := key.substr(TURRET_KEY_PREFIX.length()).split(".")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return Vector3i(-1, -1, -1)
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))


func _parse_module_key(key: String) -> Vector3i:
	if key.begins_with(TURRET_KEY_PREFIX):
		return _parse_turret_key(key)
	if not key.begins_with(MODULE_KEY_PREFIX):
		return Vector3i(-1, -1, -1)
	var parts := key.substr(MODULE_KEY_PREFIX.length()).split(".")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return Vector3i(-1, -1, -1)
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))


func _weapon_type_from_key(key: String) -> StringName:
	var dot := key.rfind(".")
	if dot <= 0 or not key.substr(dot + 1).is_valid_int():
		return &""
	var slot := configuration.get_slot(StringName(key.substr(0, dot)))
	return slot.target_id if slot != null and StringName(slot.scope_id) == ChipSlotDefinition.SCOPE_WEAPON_TYPE else &""


func _apply_percentage_stacking_policy(modifiers: Array[StatModifier]) -> Array[StatModifier]:
	if configuration.percentage_stacking_mode != 0:
		return modifiers
	var result: Array[StatModifier] = []
	var ratios: Dictionary = {}
	for modifier in modifiers:
		if modifier != null and not is_equal_approx(modifier.final_multiplier, 1.0):
			ratios[String(modifier.stat_id)] = float(ratios.get(String(modifier.stat_id), 0.0)) + modifier.final_multiplier - 1.0
			var copy := modifier.duplicate() as StatModifier
			copy.final_multiplier = 1.0
			result.append(copy)
		else:
			result.append(modifier)
	for stat_key in ratios:
		var aggregate := StatModifier.new()
		aggregate.source_id = StringName("chip.percentage_stack.%s" % stat_key)
		aggregate.stat_id = StringName(stat_key)
		aggregate.final_multiplier = maxf(1.0 + float(ratios[stat_key]), 0.0)
		result.append(aggregate)
	return result


func _create_instance(chip_id: StringName, quality: int) -> StringName:
	var instance_id := StringName("%s-%d-%d" % [String(chip_id), Time.get_ticks_usec(), _next_instance_sequence])
	_next_instance_sequence += 1
	while chip_instances.has(String(instance_id)):
		instance_id = StringName("%s-%d-%d" % [String(chip_id), Time.get_ticks_usec(), _next_instance_sequence])
		_next_instance_sequence += 1
	chip_instances[String(instance_id)] = {"chip_type_id": String(chip_id), "quality": maxi(quality, 0)}
	return instance_id


func _rebuild_owned_counts() -> void:
	owned_chips.clear()
	for record_value in chip_instances.values():
		if record_value is Dictionary:
			var type_key := String((record_value as Dictionary).get("chip_type_id", ""))
			if not type_key.is_empty():
				owned_chips[type_key] = int(owned_chips.get(type_key, 0)) + 1


func _migrate_and_validate_assignments(saved_version: int) -> bool:
	var normalized: Dictionary = {}
	var migrated := false
	for raw_slot in loadout.assignments.keys():
		var slot_key := String(raw_slot)
		var raw_value := StringName(String(loadout.assignments[raw_slot]))
		var instance_id := raw_value
		if not chip_instances.has(String(raw_value)):
			# V1 stored chip type ids instead of instances.
			var chip_type := _migrate_legacy_type(raw_value) if saved_version < 2 else raw_value
			instance_id = _find_unequipped_instance_in(chip_type, normalized)
			if instance_id.is_empty() and configuration.get_chip(chip_type) != null:
				instance_id = _create_instance(chip_type, 0)
			if instance_id.is_empty():
				migrated = true
				continue
		if normalized.values().has(String(instance_id)):
			migrated = true
			continue
		if _parse_module_key(slot_key).x < 0:
			# Shared/V1 weapon-type sockets move to the first installed instance.
			slot_key = _migrate_weapon_slot_key(slot_key, normalized)
			migrated = true
			if slot_key.is_empty():
				continue
		if slot_key.is_empty() or normalized.has(slot_key):
			migrated = true
			continue
		var chip_type := get_instance_chip_type(instance_id)
		var module_cell := _parse_module_key(slot_key)
		if module_cell.x >= 0 and module_cell.z >= get_module_slot_count(Vector2i(module_cell.x, module_cell.y)):
			# Return chips in newly locked slots to inventory without deleting them.
			migrated = true
			continue
		if module_cell.x >= 0 and not is_chip_compatible_with_module(Vector2i(module_cell.x, module_cell.y), chip_type):
			migrated = true
			continue
		normalized[slot_key] = String(instance_id)
	if normalized != loadout.assignments:
		migrated = true
	loadout.assignments = normalized
	return migrated


## A shared/V1 weapon slot moves to the first installed turret of that type.
func _migrate_weapon_slot_key(slot_key: String, taken: Dictionary) -> String:
	var slot_index := 0
	var template := configuration.get_slot(StringName(slot_key))
	if template == null:
		var dot := slot_key.rfind(".")
		if dot > 0 and slot_key.substr(dot + 1).is_valid_int():
			slot_index = int(slot_key.substr(dot + 1))
			template = configuration.get_slot(StringName(slot_key.substr(0, dot)))
	if template == null or StringName(template.scope_id) != ChipSlotDefinition.SCOPE_WEAPON_TYPE:
		return ""
	for row in range(ShipLoadout.GRID_SIZE):
		for column in range(ShipLoadout.GRID_SIZE):
			var cell := Vector2i(row, column)
			if get_turret_weapon_type(cell) != template.target_id:
				continue
			var key := get_turret_slot_key(cell, slot_index)
			if not taken.has(key):
				return key
	return ""


func _find_unequipped_instance(chip_id: StringName) -> StringName:
	return _find_unequipped_instance_in(chip_id, loadout.assignments)


func _find_unequipped_instance_in(chip_id: StringName, assignments: Dictionary) -> StringName:
	for instance_id in get_owned_instances(chip_id):
		if not assignments.values().has(String(instance_id)):
			return instance_id
	return &""


func _migrate_legacy_type(chip_id: StringName) -> StringName:
	return MIGRATED_FLAT_DAMAGE_ID if chip_id == LEGACY_FLAT_DAMAGE_ID else chip_id


func _chip_unlock_requirements_met(chip: ChipDefinition) -> bool:
	for requirement in chip.unlock_requirements:
		if not ResearchManager.is_unlocked(requirement):
			return false
	return true


func _fail(reason: String) -> bool:
	chip_operation_failed.emit(reason)
	return false
