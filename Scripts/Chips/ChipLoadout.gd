class_name ChipLoadout
extends Resource

## Persistent slot-to-chip assignments, separate from the ship's 3x3 grid.

var assignments: Dictionary = {}


func export_data() -> Dictionary:
	return assignments.duplicate(true)


func import_data(data: Dictionary) -> void:
	assignments = data.duplicate(true)
