class_name Ship
extends Node2D

## Represents a modular spaceship with a 3x3 grid.
##
## The ship supports module installation, removal,
## cell selection, and shared loadout configuration.

## Emitted when the player selects a grid cell.
signal cell_selected(row: int, column: int)

## Emitted when the player clicks outside the ship grid.
signal cell_deselected


# ==========================================
# Module Types
# ==========================================

enum ModuleType {
	Empty,
	Weapon,
	Cargo,
	Shield,
	Energy,
	Mining,
	Support,
}


# ==========================================
# Ship Grid Configuration
# ==========================================

## Number of rows and columns.
const GRID_SIZE: int = 3

## Size of each cell in pixels.
const CELL_SIZE: float = 64.0

## Total size of the ship grid.
const SHIP_SIZE: Vector2 = Vector2(
	GRID_SIZE * CELL_SIZE,
	GRID_SIZE * CELL_SIZE
)

## Default cell background color.
const CELL_COLOR: Color = Color("3A3F46")

## Color used to highlight the selected cell.
const SELECTION_COLOR: Color = Color.YELLOW


# ==========================================
# Ship Mode
# ==========================================

## Enables ship assembly mode.
## Weapons will not attack while this is enabled.
@export var assembly_mode: bool = false


# ==========================================
# Node References
# ==========================================

## Container holding all installed modules.
@onready var installed_modules: Node2D = $InstalledModules


# ==========================================
# Ship Cell Data
# ==========================================

## Stores all cells in the 3x3 grid.
var _cells: Array = []

## Currently selected cell.
var _selected_cell: ShipCell = null

## Stores installed module instances by grid position.
var _module_instances: Dictionary = {}


# ==========================================
# Initialization
# ==========================================

func _ready() -> void:
	# Initialize all nine ship cells.
	_initialize_cells()

	# Center the ship inside the viewport.
	position = (get_viewport_rect().size - SHIP_SIZE) * 0.5

	# Recreate modules saved in the shared loadout.
	load_installed_modules()

	# Draw the ship grid.
	queue_redraw()


# ==========================================
# Ship Rendering
# ==========================================

func _draw() -> void:
	# Draw every cell in the ship grid.
	for row in range(GRID_SIZE):
		for column in range(GRID_SIZE):

			# Calculate the current cell rectangle.
			var cell_rect: Rect2 = Rect2(
				column * CELL_SIZE,
				row * CELL_SIZE,
				CELL_SIZE,
				CELL_SIZE
			)

			# Draw the cell background.
			draw_rect(
				cell_rect,
				CELL_COLOR,
				true
			)

			# Draw the white cell border.
			draw_rect(
				cell_rect,
				Color.WHITE,
				false,
				2.0
			)

			# Highlight the currently selected cell.
			if _cells[row][column] == _selected_cell:
				draw_rect(
					cell_rect.grow(-3.0),
					SELECTION_COLOR,
					false,
					4.0
				)


# ==========================================
# Mouse Input
# ==========================================

func _unhandled_input(event: InputEvent) -> void:
	# Only handle mouse button events.
	if not event is InputEventMouseButton:
		return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton

	# Only respond to left mouse button presses.
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return

	if not mouse_button.pressed:
		return

	# Convert mouse coordinates into ship-local coordinates.
	var local_mouse_position: Vector2 = to_local(
		get_global_mouse_position()
	)

	# Find the clicked cell.
	var cell: ShipCell = _get_cell_at(local_mouse_position)

	if cell != null:
		# Save the selected cell.
		_selected_cell = cell
		cell_selected.emit(cell.row, cell.column)

		# Print the selected cell information.
		print(
			"Selected cell: row=%s, column=%s, module=%s" % [
				cell.row,
				cell.column,
				ModuleType.find_key(cell.module_type)
			]
		)
	else:
		# Clear the selection outside the ship.
		_selected_cell = null
		cell_deselected.emit()

	# Refresh the selection border.
	queue_redraw()


# ==========================================
# Selected Cell Utilities
# ==========================================

## Returns the currently selected cell.
func get_selected_cell() -> ShipCell:
	return _selected_cell


## Returns the selected cell's row.
func get_selected_row() -> int:
	if _selected_cell == null:
		return -1

	return _selected_cell.row


## Returns the selected cell's column.
func get_selected_column() -> int:
	if _selected_cell == null:
		return -1

	return _selected_cell.column


# ==========================================
# Grid Position Utilities
# ==========================================

## Returns the center of a cell in ship-local coordinates.
func get_cell_center(row: int, column: int) -> Vector2:
	var x: float = column * CELL_SIZE + CELL_SIZE / 2.0
	var y: float = row * CELL_SIZE + CELL_SIZE / 2.0

	return Vector2(x, y)


# ==========================================
# Module Installation
# ==========================================

## Creates and installs a module in the specified cell.
func install_module(
	module_scene: PackedScene,
	module_type: int,
	row: int,
	column: int
) -> bool:

	# Validate the requested cell position.
	if not ShipLoadout.is_valid_cell(row, column):
		push_warning("Ship: Invalid cell position.")
		return false

	# Ensure that the module scene exists.
	if module_scene == null:
		push_warning("Ship: Module scene is missing.")
		return false

	# Prevent installing an empty module type.
	if module_type == ModuleType.Empty:
		push_warning("Ship: Cannot install an empty module.")
		return false

	# Find the target cell.
	var cell: ShipCell = _cells[row][column]

	# Prevent installing into an occupied cell.
	if cell.module_type != ModuleType.Empty:
		push_warning("Ship: Cell is already occupied.")
		return false

	# Create a new module instance.
	var module: Node2D = module_scene.instantiate() as Node2D

	if module == null:
		push_error("Ship: Module scene must use a Node2D root.")
		return false

	# Add the module to the ship.
	installed_modules.add_child(module)

	# Position the module at the cell center.
	module.position = get_cell_center(row, column)

	# Keep weapon visuals active while preventing combat behavior in the base.
	if module is MachineGun:
		(module as MachineGun).assembly_mode = assembly_mode

	# Store the module instance.
	var key: Vector2i = Vector2i(row, column)
	_module_instances[key] = module

	# Update the cell's module type.
	cell.module_type = module_type

	# Save the installation to the shared loadout.
	if not module_scene.resource_path.is_empty():
		ShipLoadout.install_module(
			row,
			column,
			module_scene.resource_path
		)

	# Print installation information.
	print(
		"Installed %s at row=%s, column=%s" % [
			module.name,
			row,
			column
		]
	)

	queue_redraw()
	return true


# ==========================================
# Module Removal
# ==========================================

## Removes the module installed in a specified cell.
func remove_module(row: int, column: int) -> bool:

	# Validate the requested cell.
	if not ShipLoadout.is_valid_cell(row, column):
		return false

	var key: Vector2i = Vector2i(row, column)

	# Ensure that the cell contains a module instance.
	if not _module_instances.has(key):
		return false

	# Retrieve the installed module.
	var module: Node2D = _module_instances[key]

	# Remove the instance from the dictionary.
	_module_instances.erase(key)

	# Remove the module from the scene.
	if is_instance_valid(module):
		module.queue_free()

	# Mark the cell as empty.
	_cells[row][column].module_type = ModuleType.Empty

	# Update the shared loadout.
	ShipLoadout.remove_module(row, column)

	print(
		"Removed module at row=%s, column=%s" % [
			row,
			column
		]
	)

	queue_redraw()
	return true


# ==========================================
# Load Saved Modules
# ==========================================

## Recreates installed modules from ShipLoadout.
func load_installed_modules() -> void:

	for row in range(GRID_SIZE):
		for column in range(GRID_SIZE):

			# Get the saved scene path for this cell.
			var scene_path: String = ShipLoadout.get_module(
				row,
				column
			)

			# Skip empty cells.
			if scene_path.is_empty():
				continue

			# Load the module scene.
			var module_scene: PackedScene = load(
				scene_path
			) as PackedScene

			if module_scene == null:
				push_warning(
					"Ship: Cannot load module: " + scene_path
				)
				continue

			# Install the saved module.
			# MachineGun is currently the only supported type.
			install_module(
				module_scene,
				ModuleType.Weapon,
				row,
				column
			)


# ==========================================
# Grid Initialization
# ==========================================

## Creates all nine ship cells.
func _initialize_cells() -> void:

	_cells.clear()

	for row in range(GRID_SIZE):

		var cell_row: Array[ShipCell] = []

		for column in range(GRID_SIZE):

			# Initialize every cell as empty.
			var cell: ShipCell = ShipCell.new(
				row,
				column,
				ModuleType.Empty
			)

			cell_row.append(cell)

		_cells.append(cell_row)


# ==========================================
# Cell Detection
# ==========================================

## Finds the cell at a ship-local position.
func _get_cell_at(local_position: Vector2) -> ShipCell:

	# Check whether the position is inside the grid.
	var ship_rect: Rect2 = Rect2(
		Vector2.ZERO,
		SHIP_SIZE
	)

	if not ship_rect.has_point(local_position):
		return null

	# Convert the position into grid coordinates.
	var column: int = floori(
		local_position.x / CELL_SIZE
	)

	var row: int = floori(
		local_position.y / CELL_SIZE
	)

	# Validate the calculated coordinates.
	if not ShipLoadout.is_valid_cell(row, column):
		return null

	return _cells[row][column]


# ==========================================
# Ship Cell Class
# ==========================================

## Represents one cell in the ship grid.
class ShipCell:

	var row: int
	var column: int
	var module_type: int

	func _init(
		cell_row: int,
		cell_column: int,
		initial_module_type: int
	) -> void:

		row = cell_row
		column = cell_column
		module_type = initial_module_type
