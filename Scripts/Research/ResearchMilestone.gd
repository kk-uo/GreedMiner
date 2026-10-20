class_name ResearchMilestone
extends Resource

## Inspector-editable reward and optional price override for a target level.
## Milestones belong to ResearchDefinition data so managers and UI can share
## the same rule without hardcoding a special case for Level 10.

@export_range(2, 100, 1) var target_level: int = 10
@export_range(-1, 1000000, 1) var upgrade_cost_override: int = -1
@export_range(0, 16, 1) var weapon_chip_slots_unlocked: int = 0
@export_range(0, 16, 1) var module_chip_slots_unlocked: int = 0
@export_multiline var display_text: String


func has_cost_override() -> bool:
	return upgrade_cost_override >= 0
