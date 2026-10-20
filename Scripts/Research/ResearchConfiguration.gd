class_name ResearchConfiguration
extends Resource

## Inspector database for categories and research definitions.

@export var categories: Array[ResearchCategory] = []
@export var definitions: Array[ResearchDefinition] = []
@export var trees: Array[ResearchTreeDefinition] = []
@export_range(1, 100, 1) var chip_laboratory_unlock_level: int = 10


func get_category(category_id: StringName) -> ResearchCategory:
	for category in categories:
		if category != null and category.category_id == category_id:
			return category
	return null


func get_definition(research_id: StringName) -> ResearchDefinition:
	for definition in definitions:
		if definition != null and definition.research_id == research_id:
			return definition
	for tree in trees:
		if tree == null:
			continue
		for node in tree.nodes:
			if node != null and node.definition != null and node.research_id == research_id:
				return node.definition
	return null


func get_all_definitions() -> Array[ResearchDefinition]:
	var result: Array[ResearchDefinition] = definitions.duplicate()
	for tree in trees:
		if tree == null:
			continue
		for node in tree.nodes:
			if node != null and node.definition != null and not result.has(node.definition):
				result.append(node.definition)
	return result


func get_tree(category_id: StringName) -> ResearchTreeDefinition:
	for tree in trees:
		if tree != null and tree.tree_id == category_id:
			return tree
	return null


func get_tree_node(research_id: StringName) -> ResearchTreeNode:
	for tree in trees:
		if tree != null:
			var node := tree.get_node(research_id)
			if node != null:
				return node
	return null


func get_definitions_for_category(category_id: StringName) -> Array[ResearchDefinition]:
	var matches: Array[ResearchDefinition] = []
	for definition in definitions:
		if definition != null and definition.category_id == category_id and definition.enabled:
			matches.append(definition)
	return matches


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var category_ids: Dictionary = {}
	for category in categories:
		if category == null or category.category_id.is_empty():
			errors.append("Research category has no stable ID.")
		elif category_ids.has(category.category_id):
			errors.append("Duplicate category ID: %s" % category.category_id)
		else:
			category_ids[category.category_id] = true
	var research_ids: Dictionary = {}
	for definition in definitions:
		if definition == null or definition.research_id.is_empty():
			errors.append("Research definition has no stable ID.")
		elif research_ids.has(definition.research_id):
			errors.append("Duplicate research ID: %s" % definition.research_id)
		else:
			research_ids[definition.research_id] = true
			if not category_ids.has(definition.category_id):
				errors.append("Research '%s' references an unknown category." % definition.research_id)
			var milestone_levels: Dictionary = {}
			for milestone in definition.milestones:
				if milestone == null:
					continue
				if milestone.target_level <= definition.starting_level or milestone.target_level > definition.max_level:
					errors.append("Research '%s' has an out-of-range milestone." % definition.research_id)
				elif milestone_levels.has(milestone.target_level):
					errors.append("Research '%s' has duplicate milestone level %d." % [definition.research_id, milestone.target_level])
				else:
					milestone_levels[milestone.target_level] = true
	var seen_tree_ids: Dictionary = {}
	var seen_nodes: Dictionary = {}
	for tree in trees:
		if tree == null or tree.tree_id.is_empty() or tree.nodes.is_empty():
			errors.append("Research tree is empty or has no ID.")
			continue
		if seen_tree_ids.has(tree.tree_id):
			errors.append("Duplicate research tree: %s" % tree.tree_id)
		seen_tree_ids[tree.tree_id] = true
		for node in tree.nodes:
			if node == null or node.research_id.is_empty():
				errors.append("Tree %s contains an empty node." % tree.tree_id)
				continue
			if seen_nodes.has(node.research_id):
				errors.append("Duplicate tree research ID: %s" % node.research_id)
			seen_nodes[node.research_id] = true
			var definition := get_definition(node.research_id)
			if definition == null or (node.definition != null and node.definition.research_id != node.research_id):
				errors.append("Tree node %s has a missing or mismatched definition." % node.research_id)
			elif definition.category_id != tree.tree_id or node.tree_category != tree.tree_id:
				errors.append("Tree node %s has an invalid category." % node.research_id)
			elif definition.cost_configuration == null or definition.cost_configuration.get_upgrade_cost(definition.starting_level) < 0:
				errors.append("Tree node %s has an invalid cost." % node.research_id)
			elif definition.max_level != definition.starting_level + 1:
				errors.append("Tree node %s must be a one-time research definition." % node.research_id)
			if node.definition != null and definitions.any(func(d): return d != null and d.research_id == node.research_id and d != node.definition):
				errors.append("Duplicate definition for tree node %s." % node.research_id)
			for prerequisite in node.prerequisite_ids:
				if tree.get_node(prerequisite) == null:
					errors.append("Tree node %s has missing prerequisite %s." % [node.research_id, prerequisite])
			if _tree_has_cycle(tree, node.research_id, {}, {}):
				errors.append("Cycle detected at tree node %s." % node.research_id)
	return errors


func _tree_has_cycle(tree: ResearchTreeDefinition, id: StringName, visiting: Dictionary, done: Dictionary) -> bool:
	if visiting.has(id):
		return true
	if done.has(id):
		return false
	var node := tree.get_node(id)
	if node == null:
		return false
	visiting[id] = true
	for prerequisite in node.prerequisite_ids:
		if _tree_has_cycle(tree, prerequisite, visiting, done):
			return true
	visiting.erase(id)
	done[id] = true
	return false
