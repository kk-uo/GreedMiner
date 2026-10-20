extends Node

## Stores the ship's module configuration between scenes.
##
## Each cell is identified by its row and column.
## The same loadout is used by BaseMain and BattleMain.
## It is saved in ProgressionStore (section "loadout") by save() and restored
## on startup, so the player's last configuration survives restarts.

const GRID_SIZE: int = 3
const SAVE_SECTION: StringName = &"loadout"

## Emitted when the hull color scheme changes (Ship redraws itself).
signal style_changed(style_id: StringName)

## Hull color scheme id (see ShipHullVisual.STYLES). Saved with the loadout.
var style_id: StringName = &"bone_iron"

## Emitted when the hull design changes (Ship rebuilds its outline).
signal hull_changed(hull_id: StringName)

## Hull design id (see ShipHullVisual.HULLS). Saved with the loadout.
var hull_id: StringName = &"classic"

## Emitted when the ship's layout rotation changes (Ship re-orients itself).
signal rotation_changed(degrees: float)

## Allowed ship orientations in degrees.
const ROTATIONS: Array[float] = [0.0, 45.0]

## Ship orientation in degrees (0 or 45). Gameplay follows it: the hull, its
## edges for enemy contact and every module rotate together. Saved with the loadout.
var layout_rotation: float = 0.0

## Emitted whenever the module scene in one cell changes (install / remove /
## replace). Chip sockets of that turret are released when the module changes.
signal cell_changed(cell: Vector2i, old_path: String, new_path: String)

## Emitted when two cells exchange their modules (chips travel with them).
signal cells_swapped(cell_a: Vector2i, cell_b: Vector2i)

## Stores module scene paths by cell coordinates.
## Example: Vector2i(0, 1) -> machine_gun.tscn
var installed_modules: Dictionary = {}


func _ready() -> void:
	load_saved()


# ==========================================
# Persistence
# ==========================================

## Restores the last saved loadout. Unknown cells or missing scenes are skipped;
## with no save at all the loadout stays empty (Ship adds the default Energy Module).
func load_saved() -> void:
	# Always restore true new-game defaults before importing a saved section.
	# This also makes an in-session developer reset clear the previous loadout.
	installed_modules.clear()
	style_id = &"bone_iron"
	hull_id = &"classic"
	layout_rotation = 0.0
	var data := ProgressionStore.get_section(SAVE_SECTION)
	var saved_style := StringName(String(data.get("style", "")))
	if ShipHullVisual.STYLES.has(saved_style):
		style_id = saved_style
	var saved_hull := StringName(String(data.get("hull", "")))
	if ShipHullVisual.HULLS.has(saved_hull):
		hull_id = saved_hull
	var saved_rotation := float(data.get("rotation", 0.0))
	if ROTATIONS.has(saved_rotation):
		layout_rotation = saved_rotation
	var cells: Variant = data.get("cells", null)
	if not cells is Dictionary:
		return
	for key in (cells as Dictionary).keys():
		var parts := String(key).split(",")
		if parts.size() != 2:
			continue
		var row := int(parts[0])
		var column := int(parts[1])
		var scene_path := String((cells as Dictionary)[key])
		if is_valid_cell(row, column) and ResourceLoader.exists(scene_path):
			installed_modules[Vector2i(row, column)] = scene_path


## Saves the current loadout so the next session starts with it.
func save() -> bool:
	var cells := {}
	for cell in installed_modules.keys():
		cells["%d,%d" % [cell.x, cell.y]] = installed_modules[cell]
	return ProgressionStore.set_section(SAVE_SECTION, {"cells": cells, "style": String(style_id), "hull": String(hull_id), "rotation": layout_rotation})


## Switches the hull color scheme (unknown ids are ignored). Call save() to keep it.
func set_style(new_style_id: StringName) -> void:
	if not ShipHullVisual.STYLES.has(new_style_id) or new_style_id == style_id:
		return
	style_id = new_style_id
	style_changed.emit(style_id)


## Switches the hull design (unknown ids are ignored). Call save() to keep it.
func set_hull(new_hull_id: StringName) -> void:
	if not ShipHullVisual.HULLS.has(new_hull_id) or new_hull_id == hull_id:
		return
	hull_id = new_hull_id
	hull_changed.emit(hull_id)


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

	var cell := Vector2i(row, column)
	var old_path := String(installed_modules.get(cell, ""))
	installed_modules[cell] = module_scene_path
	cell_changed.emit(cell, old_path, module_scene_path)


## Removes a module from the specified cell.
func remove_module(row: int, column: int) -> void:
	var cell := Vector2i(row, column)
	if not installed_modules.has(cell):
		return
	var old_path := String(installed_modules[cell])
	installed_modules.erase(cell)
	cell_changed.emit(cell, old_path, "")


## Exchanges the modules of two cells (either may be empty).
func swap_cells(cell_a: Vector2i, cell_b: Vector2i) -> void:
	if cell_a == cell_b or not is_valid_cell(cell_a.x, cell_a.y) or not is_valid_cell(cell_b.x, cell_b.y):
		return
	var path_a := String(installed_modules.get(cell_a, ""))
	var path_b := String(installed_modules.get(cell_b, ""))
	installed_modules.erase(cell_a)
	installed_modules.erase(cell_b)
	if not path_a.is_empty():
		installed_modules[cell_b] = path_a
	if not path_b.is_empty():
		installed_modules[cell_a] = path_b
	cells_swapped.emit(cell_a, cell_b)


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


## Rotates the ship layout to one of ROTATIONS. Call save() to keep it.
func set_layout_rotation(degrees: float) -> void:
	if not ROTATIONS.has(degrees) or is_equal_approx(degrees, layout_rotation):
		return
	layout_rotation = degrees
	rotation_changed.emit(layout_rotation)
