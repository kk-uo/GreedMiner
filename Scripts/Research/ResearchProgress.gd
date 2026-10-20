class_name ResearchProgress
extends Resource

## Mutable persistent state kept separate from ResearchDefinition balance data.

var levels: Dictionary = {}
var unlocked: Dictionary = {}


func export_data() -> Dictionary:
	return {"levels": levels.duplicate(true), "unlocked": unlocked.duplicate(true)}


func import_data(data: Dictionary) -> void:
	levels = (data.get("levels", {}) as Dictionary).duplicate(true)
	unlocked = (data.get("unlocked", {}) as Dictionary).duplicate(true)
