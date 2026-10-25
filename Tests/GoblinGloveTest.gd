extends Node

## Regression guard: manual aiming is research, not a collectible artifact.

const CONFIG := preload("res://Resources/Artifacts/ArtifactConfiguration.tres")
const TestSave := preload("res://Tests/TestSave.gd")


func _ready() -> void:
	TestSave.isolate("goblin_glove_retirement")
	if CONFIG.get_definition(&"goblin_glove") != null:
		push_error("Retired Goblin Glove is still registered.")
		get_tree().quit(1)
		return
	ProgressionStore.set_section(&"magic_artifacts", {
		"owned": {"goblin_glove": true},
		"ship_slots": ["goblin_glove", "", ""],
		"first_artifact_id": "goblin_glove",
		"tutorial_pending": true,
	})
	ArtifactManager.reload_progress()
	if ArtifactManager.owns_artifact(&"goblin_glove") or not ArtifactManager.ship_slots[0].is_empty() or not ArtifactManager.first_artifact_id.is_empty() or ArtifactManager.tutorial_pending:
		push_error("Retired Goblin Glove remained in a legacy save.")
		get_tree().quit(1)
		return
	ProgressionStore.set_section(&"magic_artifacts", {
		"owned": {"goblin_glove": true, "stone_heart": true},
		"ship_slots": ["goblin_glove", "stone_heart", ""],
		"first_artifact_id": "goblin_glove",
		"tutorial_pending": true,
	})
	ArtifactManager.reload_progress()
	if not ArtifactManager.owns_artifact(&"stone_heart") or ArtifactManager.ship_slots[1] != &"stone_heart" or ArtifactManager.first_artifact_id != &"stone_heart":
		push_error("Retiring Goblin Glove damaged other collected artifacts.")
		get_tree().quit(1)
		return
	print("GOBLIN_GLOVE_RETIREMENT_TEST: PASS")
	get_tree().quit(0)
