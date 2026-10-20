class_name ResearchTreeDefinition
extends Resource

@export var tree_id: StringName
@export var display_name: String
@export var nodes: Array[ResearchTreeNode] = []


func get_node(research_id: StringName) -> ResearchTreeNode:
	for node in nodes:
		if node != null and node.research_id == research_id:
			return node
	return null
