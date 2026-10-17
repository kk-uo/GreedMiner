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

## Corner radius of the hull plate.
const HULL_RADIUS: float = 14.0


# ==========================================
# Ship Mode
# ==========================================

## Enables ship assembly mode.
## Weapons will not attack while this is enabled.
@export var assembly_mode: bool = false

## Shared visual zoom used by BaseMain and BattleMain.
@export_range(0.1, 4.0, 0.05) var world_visual_scale: float = 1.0


# ==========================================
# Ship Health
# ==========================================

## Maximum health available to the ship during combat.
@export var max_hp: float = 100.0

## Emitted whenever ship health changes.
signal health_changed(current_health: float, maximum_health: float)

## Current ship health used by enemy attacks.
var current_hp: float = 0.0


# ==========================================
# Node References
# ==========================================

## Container holding all installed modules.
@onready var installed_modules: Node2D = $InstalledModules

## Camera centered on the visual middle of the ship grid.
@onready var world_camera: Camera2D = $WorldCamera


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
	# Keep world rendering centered and consistently scaled in every scene.
	world_camera.position = SHIP_SIZE * 0.5
	world_camera.zoom = Vector2.ONE * world_visual_scale
	world_camera.enabled = true

	# Initialize combat health whenever a ship scene is created.
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)

	# Initialize all nine ship cells.
	_initialize_cells()

	# Place the stationary ship at the center of the world-space battlefield.
	var battlefield := get_parent().get_node_or_null("Battlefield") as Battlefield
	if battlefield != null:
		global_position = battlefield.to_global(
			(battlefield.world_size - SHIP_SIZE) * 0.5
		)
	else:
		# Retain a safe fallback when Ship is previewed by itself.
		position = (get_viewport_rect().size - SHIP_SIZE) * 0.5

	# Recreate modules saved in the shared loadout.
	load_installed_modules()

	# Draw the ship grid.
	queue_redraw()


## Applies combat damage without allowing health to fall below zero.
func take_damage(damage: float) -> void:
	if damage <= 0.0 or current_hp <= 0.0:
		return

	current_hp = maxf(current_hp - damage, 0.0)
	health_changed.emit(current_hp, max_hp)
	print("Ship HP: %s" % current_hp)

	if current_hp <= 0.0:
		print("Ship destroyed!")


# ==========================================
# Ship Rendering
# ==========================================

func _draw() -> void:
	var hull_rect := Rect2(Vector2.ZERO, SHIP_SIZE)

	# Drop shadow uses the hull silhouette (style A: one hard shadow, bottom-right).
	Palette.draw_rounded_rect(
		self, Rect2(Palette.SHADOW_OFFSET + Vector2(1.0, 1.0), SHIP_SIZE), HULL_RADIUS, Palette.SHADOW_COLOR
	)

	# Landing legs reach out diagonally from each corner.
	var corners := [
		[Vector2(6.0, 6.0), Vector2(-1.0, -1.0)],
		[Vector2(SHIP_SIZE.x - 6.0, 6.0), Vector2(1.0, -1.0)],
		[Vector2(6.0, SHIP_SIZE.y - 6.0), Vector2(-1.0, 1.0)],
		[Vector2(SHIP_SIZE.x - 6.0, SHIP_SIZE.y - 6.0), Vector2(1.0, 1.0)],
	]
	for corner in corners:
		var start: Vector2 = corner[0]
		var foot: Vector2 = start + (corner[1] as Vector2).normalized() * 22.0
		draw_line(start, foot, Palette.MECH, 10.0)
		draw_circle(foot, 7.0, Palette.MECH)
		draw_circle(foot + Vector2(-1.5, -1.5), 3.0, Palette.MECH_LIGHT)

	# Hull: shadow tone on the full rect, lit face inset toward the top-left.
	Palette.draw_rounded_rect(self, hull_rect, HULL_RADIUS, Palette.SHIP_SHADOW)
	Palette.draw_rounded_rect(
		self, Rect2(Vector2.ZERO, SHIP_SIZE - Vector2(6.0, 7.0)), HULL_RADIUS - 1.0, Palette.SHIP_BODY
	)

	# Panel seams between grid cells.
	for index in range(1, GRID_SIZE):
		var offset := float(index) * CELL_SIZE
		draw_line(Vector2(offset, 8.0), Vector2(offset, SHIP_SIZE.y - 10.0), Palette.SHIP_SEAM, 2.0)
		draw_line(Vector2(8.0, offset), Vector2(SHIP_SIZE.x - 10.0, offset), Palette.SHIP_SEAM, 2.0)

	for row in range(GRID_SIZE):
		for column in range(GRID_SIZE):
			var cell_rect := Rect2(column * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			var cell: ShipCell = _cells[row][column]

			# Empty cells show a mounting socket so the grid stays readable.
			if cell.module_type == ModuleType.Empty:
				var socket := Rect2(cell_rect.get_center() - Vector2(15.0, 15.0), Vector2(30.0, 30.0))
				Palette.draw_rounded_rect(self, socket, 5.0, Palette.SHIP_SEAM)
				for bolt in [Vector2(-9.0, -9.0), Vector2(9.0, -9.0), Vector2(-9.0, 9.0), Vector2(9.0, 9.0)]:
					draw_circle(cell_rect.get_center() + bolt, 2.0, Palette.SHIP_SHADOW)

			# Selected cell: safety-orange frame.
			if cell == _selected_cell:
				var frame := Palette.rounded_rect_points(cell_rect.grow(-4.0), 6.0)
				frame.append(frame[0])
				draw_polyline(frame, Palette.ACCENT, 3.0)


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
	# Control mining based on the ship's current mode.
	if module is MiningModule:
		module.set_mining_enabled(not assembly_mode)
	# Keep weapon visuals active while preventing combat behavior in the base.
	if module is WeaponModule:
		(module as WeaponModule).assembly_mode = assembly_mode

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

			# Get the saved module scene path.
			var scene_path: String = ShipLoadout.get_module(
				row,
				column
			)

			# Skip empty cells.
			if scene_path.is_empty():
				continue

			# Load the saved module scene.
			var module_scene: PackedScene = load(
				scene_path
			) as PackedScene

			if module_scene == null:
				push_warning(
					"Ship: Cannot load module: " + scene_path
				)
				continue

			# Create a temporary instance to identify its type.
			var preview_module: Node = module_scene.instantiate()

			if preview_module == null:
				push_warning(
					"Ship: Cannot instantiate module: " + scene_path
				)
				continue

			var detected_type: int = ModuleType.Empty

			# Identify the module category.
			if preview_module is WeaponModule:
				detected_type = ModuleType.Weapon

			elif preview_module is MiningModule:
				detected_type = ModuleType.Mining

			# Release the temporary instance.
			preview_module.free()

			# Skip unsupported module types.
			if detected_type == ModuleType.Empty:
				push_warning(
					"Ship: Unsupported module type: " + scene_path
				)
				continue

			# Install the module with its correct type.
			install_module(
				module_scene,
				detected_type,
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
