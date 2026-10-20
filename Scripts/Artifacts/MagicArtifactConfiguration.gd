class_name MagicArtifactConfiguration
extends Resource

## Registry for every discoverable artifact. Adding an artifact requires a
## definition resource here, not another branch in ArtifactManager.

@export var definitions: Array[MagicArtifactDefinition] = []


func get_definition(artifact_id: StringName) -> MagicArtifactDefinition:
	for definition in definitions:
		if definition != null and definition.artifact_id == artifact_id:
			return definition
	return null


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for definition in definitions:
		if definition == null:
			errors.append("Artifact configuration contains an empty definition.")
			continue
		if definition.artifact_id.is_empty():
			errors.append("Artifact definition has an empty ID.")
		elif seen.has(String(definition.artifact_id)):
			errors.append("Duplicate artifact ID: %s" % definition.artifact_id)
		else:
			seen[String(definition.artifact_id)] = true
		if definition.effect_script == null:
			errors.append("Artifact %s has no effect script." % definition.artifact_id)
	return errors

