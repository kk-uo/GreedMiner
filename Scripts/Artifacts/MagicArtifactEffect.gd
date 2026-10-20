class_name MagicArtifactEffect
extends Node2D

## Runtime extension point for an equipped artifact's battle behavior.

var definition: MagicArtifactDefinition
var ship: Ship


func configure(artifact_definition: MagicArtifactDefinition, target_ship: Ship) -> void:
	definition = artifact_definition
	ship = target_ship


func cleanup() -> void:
	queue_free()

