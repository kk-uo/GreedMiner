class_name ChipSlotDefinition
extends Resource

## Configurable slot contract. No default slot count or ship-grid assumption.

const SCOPE_GLOBAL: StringName = &"global"
const SCOPE_WEAPON_TYPE: StringName = &"weapon_type"

@export var slot_id: StringName
@export var display_name: String
@export_enum("global", "weapon_type") var scope_id: String = "global"
@export var target_id: StringName
@export var accepted_chip_categories: Array[StringName] = []
@export var enabled: bool = true


func accepts(chip: ChipDefinition) -> bool:
	return (
		enabled
		and chip != null
		and chip.enabled
		and (
			accepted_chip_categories.is_empty()
			or accepted_chip_categories.has(chip.category_id)
		)
	)


func matches_context(context: Dictionary) -> bool:
	if StringName(scope_id) == SCOPE_WEAPON_TYPE:
		return StringName(context.get("weapon_type_id", &"")) == target_id
	return true
