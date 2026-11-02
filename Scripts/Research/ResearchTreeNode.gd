class_name ResearchTreeNode
extends Resource

## Presentation and dependencies only. Purchase state belongs to ResearchManager.
@export var research_id: StringName
@export var definition: ResearchDefinition
@export var display_name: String
@export_multiline var description: String
@export var tree_category: StringName
@export var prerequisite_ids: Array[StringName] = []
## Requirements in another research tree (not drawn as local connectors).
@export var required_external_research_ids: Array[StringName] = []
## Planet victories required in addition to research prerequisites.
@export var required_planet_clear_ids: Array[StringName] = []
## Optional one-time threshold for every base weapon's research level.
@export_range(0, 30, 1) var required_base_weapon_level: int = 0
@export var visual_position: Vector2 = Vector2.ZERO
@export var icon: Texture2D
@export_multiline var tooltip: String
@export var enabled: bool = true
