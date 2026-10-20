class_name ChipDefinition
extends Resource

## Inspector-editable chip metadata and effect references.

@export var chip_id: StringName
@export var chip_name: String
@export_multiline var description: String
@export var category_id: StringName
@export var rarity_id: StringName
@export var icon: Texture2D
## -1 uses ChipConfiguration.default_crafting_cost.
@export_range(-1, 1000000, 1) var crafting_cost_override: int = -1
@export var qualities: Array[ChipQualityTier] = []
## Legacy fallback for configurations created before per-quality effects.
@export var effects: Array[ChipEffect] = []
@export var unlock_requirements: Array[StringName] = []
@export var enabled: bool = true


func get_quality(index: int) -> ChipQualityTier:
	return qualities[index] if index >= 0 and index < qualities.size() else null


func get_effects_for_quality(index: int) -> Array[ChipEffect]:
	var quality := get_quality(index)
	return quality.effects if quality != null else effects
