class_name ChipConfiguration
extends Resource

## Inspector database for chips and independently configured equipment slots.

@export var chips: Array[ChipDefinition] = []
@export var slots: Array[ChipSlotDefinition] = []
@export_range(0, 1000000, 1) var default_crafting_cost: int = 500
@export_range(1, 16, 1) var max_weapon_chip_slots: int = 3
@export var allow_duplicate_chip_types_per_weapon: bool = true
@export_enum("Additive", "Multiplicative") var percentage_stacking_mode: int = 0


func get_chip(chip_id: StringName) -> ChipDefinition:
	for chip in chips:
		if chip != null and chip.chip_id == chip_id:
			return chip
	return null


func get_slot(slot_id: StringName) -> ChipSlotDefinition:
	for slot in slots:
		if slot != null and slot.slot_id == slot_id:
			return slot
	return null


func get_weapon_slot(weapon_type_id: StringName) -> ChipSlotDefinition:
	for slot in slots:
		if (
			slot != null
			and StringName(slot.scope_id) == ChipSlotDefinition.SCOPE_WEAPON_TYPE
			and slot.target_id == weapon_type_id
		):
			return slot
	return null


func get_crafting_cost(chip_id: StringName) -> int:
	var chip := get_chip(chip_id)
	if chip == null:
		return 0
	return (
		chip.crafting_cost_override
		if chip.crafting_cost_override >= 0
		else default_crafting_cost
	)
