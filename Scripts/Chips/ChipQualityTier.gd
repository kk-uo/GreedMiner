class_name ChipQualityTier
extends Resource

## One Inspector-editable quality tier. upgrade_cost is the Ore cost required
## to enter this tier from the previous tier; -1 keeps that upgrade unavailable.

@export var quality_id: StringName = &"basic"
@export var display_name: String = "Basic"
@export_range(-1, 1000000, 1) var upgrade_cost: int = -1
@export var effects: Array[ChipEffect] = []
