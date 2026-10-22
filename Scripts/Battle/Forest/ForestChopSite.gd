class_name ForestChopSite
extends "res://Scripts/Battle/Graveyard/GraveDigSite.gd"

## Uses exactly the grave-clearing radius and duration. One dwarf chops every
## unclaimed tree inside the dispatch ring, without creating an ore reward.
func setup(claimed: Array[Node2D]) -> void:
	graves = claimed
	for tree in graves:
		tree.chop_site = self

func advance_mining(seconds: float) -> float:
	if not can_be_mined() or seconds <= 0.0:
		return 0.0
	mining_progress += seconds
	var progress := clampf(mining_progress / dig_duration(), 0.0, 1.0)
	for tree in _live_graves():
		tree.dig_progress = progress
		tree.queue_redraw()
	if progress >= 1.0:
		_done = true
		for tree in _live_graves():
			tree.chop()
		queue_free()
	return 0.0

func release() -> void:
	for tree in _live_graves():
		if not tree.chopped:
			tree.chop_site = null
			tree.dig_progress = 0.0
			tree.queue_redraw()
	queue_free()

func get_chip_color() -> Color:
	return Color("76B56A")
