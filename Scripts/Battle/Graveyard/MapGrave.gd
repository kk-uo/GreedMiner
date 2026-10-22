extends Node2D

## Mining target for one tombstone in the terrain's baked artwork.
var dig_site: Node = null
var dig_progress: float = 0.0
var stone: Dictionary


func crumble() -> void:
	var terrain := get_parent()
	if is_instance_valid(terrain) and terrain.has_method("remove_stone"):
		terrain.call("remove_stone", stone)
	queue_free()
