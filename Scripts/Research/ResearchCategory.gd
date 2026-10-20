class_name ResearchCategory
extends Resource

## Inspector-editable laboratory category identified by a stable ID.

@export var category_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var enabled: bool = true
@export var implemented: bool = false
