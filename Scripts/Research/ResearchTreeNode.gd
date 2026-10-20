class_name ResearchTreeNode
extends Resource

## Presentation and dependencies only. Purchase state belongs to ResearchManager.
@export var research_id: StringName
@export var definition: ResearchDefinition
@export var display_name: String
@export_multiline var description: String
@export var tree_category: StringName
@export var prerequisite_ids: Array[StringName] = []
@export var visual_position: Vector2 = Vector2.ZERO
@export var icon: Texture2D
@export_multiline var tooltip: String
@export var enabled: bool = true
