extends Node

## Stores the ship's module configuration between scenes.
##
## Each cell is identified by its row and column.
## The same loadout is used by BaseMain and BattleMain.

const GRID_SIZE: int = 3

## Stores module scene paths by cell coordinates.
## Example: Vector2i(0, 1) -> machine_gun.tscn
var installed_modules: Dictionary = {}


# ==========================================
# Module Installation
# ==========================================

## Saves a module in the specified ship cell.
func install_module(
	row: int,
	column: int,
	module_scene_path: String
) -> void:
	if not is_valid_cell(row, column):
		push_warning("ShipLoadout: Invalid cell position.")
		return

	installed_modules[Vector2i(row, column)] = module_scene_path


## Removes a module from the specified cell.
func remove_module(row: int, column: int) -> void:
	installed_modules.erase(Vector2i(row, column))


# ==========================================
# Module Queries
# ==========================================

## Returns the module scene path installed in a cell.
func get_module(row: int, column: int) -> String:
	return installed_modules.get(
		Vector2i(row, column),
		""
	)


## Checks whether a cell contains a module.
func has_module(row: int, column: int) -> bool:
	return installed_modules.has(Vector2i(row, column))


## Validates the cell coordinates.
func is_valid_cell(row: int, column: int) -> bool:
	return (
		row >= 0
		and row < GRID_SIZE
		and column >= 0
		and column < GRID_SIZE
	)
