class_name ResearchDefinition
extends Resource

## Data-only definition for one research project.

@export var research_id: StringName
@export var category_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export_range(0, 100, 1) var starting_level: int = 1
@export_range(1, 100, 1) var max_level: int = 1
@export var cost_configuration: ResearchCostConfig
@export var target_id: StringName
@export var unlock_requirements: Array[StringName] = []
@export var effect: ResearchEffect
@export var milestones: Array[ResearchMilestone] = []
@export var unlocked_by_default: bool = true
@export var enabled: bool = true
@export var implemented: bool = false


func get_milestone(target_level: int) -> ResearchMilestone:
	for milestone in milestones:
		if milestone != null and milestone.target_level == target_level:
			return milestone
	return null
