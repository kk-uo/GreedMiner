extends Node

## Owns chip inventory and configurable equipment assignments.

signal chip_inventory_changed(chip_id: StringName, owned_count: int)
signal chip_equipment_changed(slot_id: StringName, chip_id: StringName)
signal chip_operation_failed(reason: String)

const DEFAULT_CONFIGURATION: ChipConfiguration = preload(
	"res://Resources/Chips/ChipConfiguration.tres"
)
const SAVE_SECTION: StringName = &"chips"

var configuration: ChipConfiguration = DEFAULT_CONFIGURATION
var owned_chips: Dictionary = {}
var loadout: ChipLoadout = ChipLoadout.new()


func _ready() -> void:
	reload_progress()


func reload_progress() -> void:
	var data := ProgressionStore.get_section(SAVE_SECTION)
	owned_chips = (data.get("owned", {}) as Dictionary).duplicate(true)
	loadout = ChipLoadout.new()
	loadout.import_data(data.get("equipped", {}) as Dictionary)


func save_progress() -> bool:
	return ProgressionStore.set_section(SAVE_SECTION, {
		"owned": owned_chips.duplicate(true),
		"equipped": loadout.export_data(),
	})


func get_owned_count(chip_id: StringName) -> int:
	return maxi(int(owned_chips.get(String(chip_id), 0)), 0)


func add_owned_chip(chip_id: StringName, amount: int = 1) -> bool:
	var definition := configuration.get_chip(chip_id)
	if definition == null or not definition.enabled or amount <= 0:
		return _fail("Unknown, disabled, or invalid chip ownership request.")
	var new_count := get_owned_count(chip_id) + amount
	owned_chips[String(chip_id)] = new_count
	save_progress()
	chip_inventory_changed.emit(chip_id, new_count)
	return true


func equip_chip(slot_id: StringName, chip_id: StringName, context: Dictionary = {}) -> bool:
	var slot := configuration.get_slot(slot_id)
	var chip := configuration.get_chip(chip_id)
	if slot == null:
		return _fail("Chip slot is not configured.")
	if not is_slot_unlocked(slot_id):
		return _fail("Chip slot is locked.")
	if chip == null or not slot.accepts(chip):
		return _fail("Chip is missing or incompatible with this slot.")
	if not _chip_unlock_requirements_met(chip):
		return _fail("Chip unlock requirements are not met.")
	if get_owned_count(chip_id) <= _equipped_count(chip_id):
		return _fail("No unequipped copy of this chip is owned.")

	unequip_chip(slot_id, context, false)
	loadout.assignments[String(slot_id)] = String(chip_id)
	for effect in chip.effects:
		if effect != null:
			effect.apply(context)
	save_progress()
	chip_equipment_changed.emit(slot_id, chip_id)
	return true


func unequip_chip(slot_id: StringName, context: Dictionary = {}, persist: bool = true) -> bool:
	var key := String(slot_id)
	if not loadout.assignments.has(key):
		return false
	var chip_id := StringName(loadout.assignments[key])
	var chip := configuration.get_chip(chip_id)
	if chip != null:
		for effect in chip.effects:
			if effect != null:
				effect.remove(context)
	loadout.assignments.erase(key)
	if persist:
		save_progress()
	chip_equipment_changed.emit(slot_id, &"")
	return true


func get_equipped_chip(slot_id: StringName) -> StringName:
	return StringName(loadout.assignments.get(String(slot_id), ""))


func is_slot_unlocked(slot_id: StringName) -> bool:
	var slot := configuration.get_slot(slot_id)
	if slot == null or not slot.enabled:
		return false
	if StringName(slot.scope_id) == ChipSlotDefinition.SCOPE_WEAPON_TYPE:
		return ResearchManager.is_weapon_chip_slot_unlocked(slot.target_id)
	return true


func get_unlocked_weapon_slot_count(weapon_type_id: StringName) -> int:
	if configuration.get_weapon_slot(weapon_type_id) == null:
		return 0
	return ResearchManager.get_weapon_chip_slot_count(weapon_type_id)


func is_weapon_chip_slot_unlocked(weapon_type_id: StringName) -> bool:
	return get_unlocked_weapon_slot_count(weapon_type_id) > 0


func is_chip_compatible_with_weapon(weapon_type_id: StringName, chip_id: StringName) -> bool:
	var slot := configuration.get_weapon_slot(weapon_type_id)
	var chip := configuration.get_chip(chip_id)
	return (
		slot != null
		and chip != null
		and slot.accepts(chip)
		and _chip_unlock_requirements_met(chip)
	)


func equip_weapon_chip(weapon_type_id: StringName, chip_id: StringName) -> bool:
	var slot := configuration.get_weapon_slot(weapon_type_id)
	if slot == null:
		return _fail("Weapon chip slot is not configured.")
	return equip_chip(slot.slot_id, chip_id, {"weapon_type_id": weapon_type_id})


func unequip_weapon_chip(weapon_type_id: StringName) -> bool:
	var slot := configuration.get_weapon_slot(weapon_type_id)
	if slot == null:
		return false
	return unequip_chip(slot.slot_id, {"weapon_type_id": weapon_type_id})


func get_equipped_chip_for_weapon(weapon_type_id: StringName) -> StringName:
	var slot := configuration.get_weapon_slot(weapon_type_id)
	return get_equipped_chip(slot.slot_id) if slot != null else &""


func get_stat_modifiers(context: Dictionary) -> Array[StatModifier]:
	var modifiers: Array[StatModifier] = []
	for slot_key in loadout.assignments:
		var slot := configuration.get_slot(StringName(slot_key))
		if slot == null or not is_slot_unlocked(slot.slot_id) or not slot.matches_context(context):
			continue
		var chip_value: Variant = loadout.assignments[slot_key]
		var chip_id := StringName(chip_value)
		var chip := configuration.get_chip(chip_id)
		if chip == null:
			continue
		for effect in chip.effects:
			if effect != null:
				modifiers.append_array(effect.get_stat_modifiers(chip_id, context))
	return modifiers


func _chip_unlock_requirements_met(chip: ChipDefinition) -> bool:
	for requirement in chip.unlock_requirements:
		if not ResearchManager.is_unlocked(requirement):
			return false
	return true


func _equipped_count(chip_id: StringName) -> int:
	var count := 0
	for equipped in loadout.assignments.values():
		if StringName(equipped) == chip_id:
			count += 1
	return count


func _fail(reason: String) -> bool:
	chip_operation_failed.emit(reason)
	return false
