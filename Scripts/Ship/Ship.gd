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

## Emitted whenever aggregate module energy statistics change.
signal energy_changed(
	total_power_capacity: int,
	total_power_consumption: int,
	available_power: int,
	total_expansion_capacity: int
)

## Emitted when an install, replacement, or removal is rejected.
signal module_operation_failed(reason: String)

## Emitted after the installed module set changes successfully.
signal module_configuration_changed

## Emitted when combat systems enable or disable installed weapon attacks.
signal weapon_attacks_enabled_changed(enabled: bool)


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

## Default module required by every starting ship.
const BASIC_ENERGY_MODULE_SCENE: PackedScene = preload(
	"res://Scenes/Modules/Energy/energy_module.tscn"
)
const DEFAULT_ENERGY_CELL: Vector2i = Vector2i(1, 1)
const ENERGY_MODULE_TYPE_ID: StringName = &"energy_module"
const MINING_MODULE_TYPE_ID: StringName = &"mining_module"
const SHIELD_MODULE_TYPE_ID: StringName = &"shield_module"


# ==========================================
# Ship Mode
# ==========================================

## Enables ship assembly mode.
## Weapons will not attack while this is enabled.
@export var assembly_mode: bool = false

## When false, clicks never select grid cells (the base overview uses this).
var cell_input_enabled: bool = true

## Shared visual zoom used by BaseMain and BattleMain.
@export_range(0.1, 4.0, 0.05) var world_visual_scale: float = 1.0


# ==========================================
# Ship Health
# ==========================================

## Maximum health available to the ship during combat.
@export var max_hp: float = 50.0

## Emitted whenever ship health changes.
signal health_changed(current_health: float, maximum_health: float)

## Emitted when combat damage actually lands on the hull (after interceptors
## such as shields). The battle HUD flashes a red screen edge (DamageVignette).
signal damaged(amount: float)

## Current ship health used by enemy attacks.
var current_hp: float = 0.0

## Inspector-authored hull health before installed-module bonuses.
var _base_max_hp: float = 50.0
var _research_regeneration_elapsed: Dictionary = {}


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
# Presentation-only flight state (no gameplay effect)
# ==========================================

## 0 = landed, 1 = high in the air. Driven by ShipLaunchController; scales the
## hull and modules toward the camera and pushes the shadow away.
var visual_altitude: float = 0.0:
	set(value):
		visual_altitude = clampf(value, 0.0, 1.5)
		_apply_visual_altitude()

## 0..1 nozzle glow on the thruster pods. Read by ThrusterFX for the fire.
var thruster_power: float = 0.0:
	set(value):
		thruster_power = clampf(value, 0.0, 1.0)
		queue_redraw()

## 0..1 how far the thrusters are unfolded (style dependent; see
## ShipHullVisual.THRUSTERS). 0 on the ground, 1 in flight. Animated by
## ShipLaunchController.
var thruster_deploy: float = 0.0:
	set(value):
		thruster_deploy = clampf(value, 0.0, 1.0)
		queue_redraw()

## Maximum extra scale at visual_altitude = 1.
const ALTITUDE_SCALE: float = 0.45
## Shadow travel at visual_altitude = 1, in world pixels.
const ALTITUDE_SHADOW := Vector2(60.0, 78.0)

var _hull_cells: Array[Vector2i] = []
var _hull_geometry: Dictionary = {}

## Runtime combat gate independent from BaseMain's assembly mode.
var _weapon_attacks_enabled: bool = true
var _all_modules_active: bool = true
var _freeze_module_states: Dictionary = {}
var _freeze_all_modules_active: bool = false
var _combat_frozen: bool = false

## Ordered, synchronous damage middleware used by temporary battle effects.
## Each callable receives incoming damage and returns the amount still owed to
## the hull. With no interceptors the original damage behavior is unchanged.
var _damage_interceptors: Array[Callable] = []

## Reusable calculator owned by this ship instance.
var energy_system: ShipEnergySystem = ShipEnergySystem.new()

## Human-readable result from the most recent rejected module operation.
var last_module_error: String = ""

var total_power_capacity: int:
	get:
		return energy_system.total_power_capacity

var total_power_consumption: int:
	get:
		return energy_system.total_power_consumption

var available_power: int:
	get:
		return energy_system.available_power

var total_expansion_capacity: int:
	get:
		return energy_system.total_expansion_capacity


# ==========================================
# Initialization
# ==========================================

func _ready() -> void:
	add_to_group("friendly_healing_targets")
	_base_max_hp = max_hp
	ResearchManager.research_level_changed.connect(_on_ship_research_changed)
	energy_system.totals_changed.connect(_on_energy_totals_changed)
	ShipLoadout.style_changed.connect(_on_style_changed)
	ShipLoadout.hull_changed.connect(_on_hull_changed)
	ShipLoadout.thruster_changed.connect(_on_thruster_changed)
	ShipLoadout.rotation_changed.connect(apply_layout_rotation)

	# Keep world rendering centered and consistently scaled in every scene.
	world_camera.position = SHIP_SIZE * 0.5
	world_camera.zoom = Vector2.ONE * world_visual_scale
	world_camera.enabled = true

	# Initialize all nine ship cells.
	_initialize_cells()
	_rebuild_hull()
	_ensure_required_energy_loadout()

	# Place the stationary ship at the center of the world-space battlefield.
	var battlefield := get_parent().get_node_or_null("Battlefield") as Battlefield
	if battlefield != null:
		global_position = battlefield.to_global(
			(battlefield.world_size - SHIP_SIZE) * 0.5
		)
	else:
		# Retain a safe fallback when Ship is previewed by itself.
		position = (get_viewport_rect().size - SHIP_SIZE) * 0.5

	# Orientation from the loadout (0 or 45 degrees), around the hull center.
	apply_layout_rotation(ShipLoadout.layout_rotation)

	# Recreate modules saved in the shared loadout.
	load_installed_modules()

	# A newly entered scene begins with the fully assembled hull at full health.
	# Later installs can raise max HP without healing existing damage.
	_recalculate_health_stats(true)

	# Draw the ship grid.
	queue_redraw()


## Rotates the whole ship (hull, modules, contact edges) around the hull
## center so it stays in the same spot. The camera ignores rotation.
func apply_layout_rotation(degrees: float) -> void:
	var center_before := to_global(SHIP_SIZE * 0.5)
	rotation_degrees = degrees
	global_position += center_before - to_global(SHIP_SIZE * 0.5)
	queue_redraw()
	# Module plates draw screen-space shadows, so they redraw too.
	if installed_modules != null:
		for module in installed_modules.get_children():
			(module as CanvasItem).queue_redraw()


## Redraws the hull when the player picks another color scheme.
func _on_style_changed(_style_id: StringName) -> void:
	queue_redraw()


func _on_thruster_changed(_thruster_id: StringName) -> void:
	queue_redraw()


## Rebuilds the outline when the player picks another hull design.
func _on_hull_changed(_hull_id: StringName) -> void:
	_rebuild_hull()


## Animated hull patterns (runway lights) need a redraw every frame.
func _process(_delta: float) -> void:
	if ShipHullVisual.is_animated(_hull_geometry) or ShipHullVisual.thruster_needs_redraw(thruster_power, thruster_deploy):
		queue_redraw()
	if assembly_mode or not _all_modules_active or current_hp <= 0.0:
		return
	for effect in ResearchManager.get_ship_research_effects():
		if effect.regeneration_amount <= 0.0 or effect.regeneration_interval <= 0.0:
			continue
		var elapsed := float(_research_regeneration_elapsed.get(effect, 0.0)) + _delta
		var pulses := floori(elapsed / effect.regeneration_interval)
		_research_regeneration_elapsed[effect] = fmod(elapsed, effect.regeneration_interval)
		if pulses > 0:
			heal(effect.regeneration_amount * pulses)


func _on_ship_research_changed(_research_id: StringName, _level: int) -> void:
	_recalculate_health_stats()
	# Energy Core research raises every Energy Module's power.
	_recalculate_energy()


## Applies combat damage without allowing health to fall below zero.
func take_damage(damage: float) -> void:
	if damage <= 0.0 or current_hp <= 0.0:
		return

	var remaining_damage := damage
	for interceptor in _damage_interceptors.duplicate():
		if not interceptor.is_valid():
			_damage_interceptors.erase(interceptor)
			continue
		remaining_damage = clampf(float(interceptor.call(remaining_damage)), 0.0, remaining_damage)
		if remaining_damage <= 0.0:
			return

	current_hp = maxf(current_hp - remaining_damage, 0.0)
	health_changed.emit(current_hp, max_hp)
	damaged.emit(remaining_damage)
	print("Ship HP: %s" % current_hp)

	if current_hp <= 0.0:
		print("Ship destroyed!")


func register_damage_interceptor(interceptor: Callable) -> void:
	if interceptor.is_valid() and not _damage_interceptors.has(interceptor):
		_damage_interceptors.append(interceptor)


func unregister_damage_interceptor(interceptor: Callable) -> void:
	_damage_interceptors.erase(interceptor)


## Restores hull health without exceeding the current module-adjusted maximum.
func heal(amount: float, source_weapon: WeaponModule = null) -> void:
	if amount <= 0.0 or current_hp <= 0.0 or current_hp >= max_hp:
		return
	var previous_health := current_hp
	current_hp = minf(current_hp + amount, max_hp)
	ArtifactManager.record_battle_activity(source_weapon, current_hp - previous_health)
	health_changed.emit(current_hp, max_hp)


func can_receive_healing() -> bool:
	return current_hp > 0.0 and current_hp < max_hp


func get_healing_position() -> Vector2:
	return to_global(SHIP_SIZE * 0.5)


## Distance from an enemy collision boundary to the transformed 3x3 hull.
## A result of zero means the queried shape overlaps the ship rectangle.
func get_distance_to_hull(world_position: Vector2, object_radius: float = 0.0) -> float:
	var local := to_local(world_position)
	var rect := Rect2(Vector2.ZERO, SHIP_SIZE)
	var dx := maxf(maxf(rect.position.x - local.x, 0.0), local.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - local.y, 0.0), local.y - rect.end.y)
	return maxf(Vector2(dx, dy).length() - maxf(object_radius, 0.0), 0.0)


## Gives installed defensive modules one pre-damage opportunity to cancel an
## actual pending attack. Proximity alone never calls this method.
func try_interrupt_enemy_attack(enemy: BasicEnemy) -> bool:
	if assembly_mode or not _all_modules_active or enemy == null:
		return false
	for module in _get_installed_ship_modules():
		var knockback := module as KnockbackModule
		if knockback != null and knockback.try_interrupt_attack(enemy, self):
			return true
	return false


# ==========================================
# Ship Rendering
# ==========================================

func _draw() -> void:
	var center := SHIP_SIZE * 0.5
	var lift := get_visual_scale()

	# Ground shadow: drifts away and fades as the ship climbs.
	# The offset is converted to local space so the shadow always falls down-right.
	var shadow_offset := get_shadow_offset().rotated(-global_rotation)
	draw_set_transform(center + shadow_offset - center * minf(lift, 1.1), 0.0, Vector2.ONE * minf(lift, 1.1))
	ShipHullVisual.draw_shadow(self, _hull_geometry, Vector2.ZERO, 1.0 - 0.75 * clampf(visual_altitude, 0.0, 1.0))

	# Hull, pods and grid overlays scale around the hull center when airborne.
	draw_set_transform(center - center * lift, 0.0, Vector2.ONE * lift)
	ShipHullVisual.draw_pods(self, _hull_geometry, thruster_power, ShipLoadout.thruster_id, thruster_deploy)
	ShipHullVisual.draw_hull(self, _hull_geometry, _hull_cells, CELL_SIZE)

	for cell_position in _hull_cells:
		var cell: ShipCell = _cells[cell_position.y][cell_position.x]
		var cell_rect := Rect2(Vector2(cell_position) * CELL_SIZE, Vector2.ONE * CELL_SIZE)

		# Empty cells show a mounting socket so the grid stays readable.
		if cell.module_type == ModuleType.Empty:
			var socket_colors := ShipHullVisual.socket_colors()
			var socket := Rect2(cell_rect.get_center() - Vector2(13.0, 13.0), Vector2(26.0, 26.0))
			Palette.draw_rounded_rect(self, socket, 5.0, socket_colors[0])
			for bolt in [Vector2(-8.0, -8.0), Vector2(8.0, -8.0), Vector2(-8.0, 8.0), Vector2(8.0, 8.0)]:
				draw_circle(cell_rect.get_center() + bolt, 1.8, socket_colors[1])

		# Selected cell: safety-orange frame.
		if cell == _selected_cell:
			var frame := Palette.rounded_rect_points(cell_rect.grow(-4.0), 6.0)
			frame.append(frame[0])
			draw_polyline(frame, Palette.ACCENT, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Every grid cell that is part of the hull, as Vector2i(column, row).
## When the grid grows irregularly, only this list needs to change.
func get_hull_cells() -> Array[Vector2i]:
	return _hull_cells.duplicate()


## Recomputes hull outline, thruster pods and rune studs from the cell set.
func _rebuild_hull() -> void:
	_hull_cells.clear()
	for row in range(_cells.size()):
		for column in range((_cells[row] as Array).size()):
			_hull_cells.append(Vector2i(column, row))
	_hull_geometry = ShipHullVisual.build(_hull_cells, CELL_SIZE)
	queue_redraw()


## Current visual scale from altitude (1.0 on the ground).
func get_visual_scale() -> float:
	return 1.0 + ALTITUDE_SCALE * visual_altitude


## Ground-shadow offset for the current altitude, in ship-local pixels.
func get_shadow_offset() -> Vector2:
	return Palette.SHADOW_OFFSET + ALTITUDE_SHADOW * visual_altitude


func _nozzles() -> PackedVector2Array:
	if not _hull_geometry.has("pods"):
		return PackedVector2Array()
	return ShipHullVisual.nozzle_points(_hull_geometry, ShipLoadout.thruster_id, thruster_deploy)


## Global positions of the thruster nozzles as currently drawn.
func get_thruster_global_positions() -> PackedVector2Array:
	var result := PackedVector2Array()
	var center := SHIP_SIZE * 0.5
	var lift := get_visual_scale()
	for pod in _nozzles():
		result.append(to_global(center + (pod - center) * lift))
	return result


## Global positions on the ground directly below each nozzle.
func get_thruster_ground_positions() -> PackedVector2Array:
	var result := PackedVector2Array()
	var center := SHIP_SIZE * 0.5
	# The exhaust stays put on the ground under the hull; it does not follow
	# the perspective drift of the shadow, so it reads as a rising launch.
	var ground_scale := minf(get_visual_scale(), 1.1)
	for pod in _nozzles():
		result.append(to_global(center + (pod - center) * ground_scale))
	return result


func _apply_visual_altitude() -> void:
	if installed_modules == null:
		return
	var lift := get_visual_scale()
	var center := SHIP_SIZE * 0.5
	installed_modules.scale = Vector2.ONE * lift
	installed_modules.position = center - center * lift
	queue_redraw()


# ==========================================
# Mouse Input
# ==========================================

func _unhandled_input(event: InputEvent) -> void:
	if not cell_input_enabled:
		return

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

## Clears the selected cell without emitting signals.
func clear_selection() -> void:
	_selected_cell = null
	queue_redraw()


## Selects a cell from code (e.g. a drag-and-drop install) and emits cell_selected.
func select_cell(row: int, column: int) -> void:
	if not ShipLoadout.is_valid_cell(row, column):
		return
	_selected_cell = _cells[row][column]
	cell_selected.emit(row, column)
	queue_redraw()


## Cell under a global point as Vector2i(row, column), or Vector2i(-1, -1).
func get_cell_at_global(global_point: Vector2) -> Vector2i:
	var cell: ShipCell = _get_cell_at(to_local(global_point))
	if cell == null:
		return Vector2i(-1, -1)
	return Vector2i(cell.row, cell.column)


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
	last_module_error = ""

	if not ShipLoadout.is_valid_cell(row, column):
		return _reject_module_operation("Invalid cell position.")

	if module_type == ModuleType.Empty:
		return _reject_module_operation("Cannot install an empty module.")

	var cell: ShipCell = _cells[row][column]
	if cell.module_type != ModuleType.Empty:
		return _reject_module_operation("Cell is already occupied.")

	var module := _instantiate_ship_module(module_scene)
	if module == null:
		return false

	var detected_type := _detect_module_type(module)
	if detected_type != module_type:
		module.free()
		return _reject_module_operation("Module category does not match the requested slot type.")
	if not _validate_weapon_unlock(module):
		module.free()
		return false

	var proposed_modules := _get_installed_ship_modules()
	proposed_modules.append(module)
	if not _validate_module_installation_limit(
		module,
		_get_installed_ship_modules(),
		proposed_modules
	):
		module.free()
		return false
	if not _validate_energy_profile(proposed_modules):
		module.free()
		return false

	_commit_module(module, module_scene, module_type, row, column, true)
	return true


## Atomically replaces one cell without discarding the old module on failure.
func replace_module(
	module_scene: PackedScene,
	module_type: int,
	row: int,
	column: int
) -> bool:
	last_module_error = ""
	if not ShipLoadout.is_valid_cell(row, column):
		return _reject_module_operation("Invalid cell position.")

	var key := Vector2i(row, column)
	if not _module_instances.has(key):
		return install_module(module_scene, module_type, row, column)

	var replacement := _instantiate_ship_module(module_scene)
	if replacement == null:
		return false

	var detected_type := _detect_module_type(replacement)
	if detected_type != module_type:
		replacement.free()
		return _reject_module_operation("Module category does not match the requested slot type.")
	if not _validate_weapon_unlock(replacement):
		replacement.free()
		return false

	var current_modules := _get_installed_ship_modules()
	var proposed_modules := _get_installed_ship_modules(key)
	proposed_modules.append(replacement)
	if not _validate_module_installation_limit(
		replacement,
		current_modules,
		proposed_modules
	):
		replacement.free()
		return false
	if not _validate_energy_profile(proposed_modules):
		replacement.free()
		return false

	var old_module: ShipModule = _module_instances[key]
	_module_instances.erase(key)
	if is_instance_valid(old_module):
		old_module.queue_free()

	_cells[row][column].module_type = ModuleType.Empty
	_commit_module(replacement, module_scene, module_type, row, column, true)
	return true


## Completes an already validated module installation.
func _commit_module(
	module: ShipModule,
	module_scene: PackedScene,
	module_type: int,
	row: int,
	column: int,
	persist_loadout: bool
) -> void:
	installed_modules.add_child(module)
	module.position = get_cell_center(row, column)

	if module is MiningModule:
		(module as MiningModule).set_mining_enabled(not assembly_mode)
	if module is WeaponModule:
		(module as WeaponModule).assembly_mode = (
			assembly_mode or not _weapon_attacks_enabled
		)
	if module is ShieldModule:
		(module as ShieldModule).set_module_active(
			not assembly_mode and _all_modules_active
		)

	var key := Vector2i(row, column)
	_module_instances[key] = module
	_cells[row][column].module_type = module_type

	if persist_loadout and not module_scene.resource_path.is_empty():
		ShipLoadout.install_module(row, column, module_scene.resource_path)

	last_module_error = ""
	_recalculate_energy()
	_recalculate_health_stats(false)
	module_configuration_changed.emit()
	print("Installed %s at row=%s, column=%s" % [module.name, row, column])
	queue_redraw()


# ==========================================
# Module Rearranging
# ==========================================

## Moves the module in cell A to cell B. If B holds a module, the two swap.
## The installed set does not change, so no power / limit validation is needed.
## Modules slide to their new cells; the shared loadout is updated (call
## ShipLoadout.save() to persist).
func swap_modules(row_a: int, column_a: int, row_b: int, column_b: int) -> bool:
	last_module_error = ""
	if not ShipLoadout.is_valid_cell(row_a, column_a) or not ShipLoadout.is_valid_cell(row_b, column_b):
		return _reject_module_operation("Invalid cell position.")
	var key_a := Vector2i(row_a, column_a)
	var key_b := Vector2i(row_b, column_b)
	if key_a == key_b:
		return false
	if not _module_instances.has(key_a):
		return _reject_module_operation("Nothing to move in this slot.")

	var module_a: ShipModule = _module_instances[key_a]
	var module_b: ShipModule = _module_instances.get(key_b, null)
	var type_a: int = _cells[row_a][column_a].module_type
	var type_b: int = _cells[row_b][column_b].module_type

	_module_instances.erase(key_a)
	_module_instances.erase(key_b)
	_module_instances[key_b] = module_a
	_cells[row_b][column_b].module_type = type_a
	_slide_module(module_a, get_cell_center(row_b, column_b))
	if module_b != null:
		_module_instances[key_a] = module_b
		_cells[row_a][column_a].module_type = type_b
		_slide_module(module_b, get_cell_center(row_a, column_a))
	else:
		_cells[row_a][column_a].module_type = ModuleType.Empty

	ShipLoadout.swap_cells(key_a, key_b)

	module_configuration_changed.emit()
	queue_redraw()
	return true


## Atomically consumes two occupied cells and installs a fusion weapon in the
## target cell. Power is validated against the complete proposed loadout.
func fuse_modules(source: Vector2i, target: Vector2i, result_scene: PackedScene) -> bool:
	last_module_error = ""
	if (
		source == target
		or not ShipLoadout.is_valid_cell(source.x, source.y)
		or not ShipLoadout.is_valid_cell(target.x, target.y)
		or not _module_instances.has(source)
		or not _module_instances.has(target)
	):
		return _reject_module_operation("Weapon Fusion requires two occupied ship cells.")
	var result := _instantiate_ship_module(result_scene)
	if result == null or not result is WeaponModule:
		if result != null:
			result.free()
		return _reject_module_operation("Fusion result must be a weapon module.")
	var proposed := _get_installed_ship_modules(source)
	for index in range(proposed.size() - 1, -1, -1):
		if proposed[index] == _module_instances[target]:
			proposed.remove_at(index)
	proposed.append(result)
	if not _validate_energy_profile(proposed):
		result.free()
		return false

	var source_module: ShipModule = _module_instances[source]
	var target_module: ShipModule = _module_instances[target]
	_module_instances.erase(source)
	_module_instances.erase(target)
	if is_instance_valid(source_module):
		source_module.queue_free()
	if is_instance_valid(target_module):
		target_module.queue_free()
	_cells[source.x][source.y].module_type = ModuleType.Empty
	_cells[target.x][target.y].module_type = ModuleType.Empty
	_commit_module(result, result_scene, ModuleType.Weapon, target.x, target.y, false)
	ShipLoadout.fuse_cells(source, target, result_scene.resource_path)
	_recalculate_energy()
	_recalculate_health_stats(false)
	module_configuration_changed.emit()
	queue_redraw()
	return true


## Installed module currently in a cell, or null.
func get_module_at(row: int, column: int) -> ShipModule:
	return _module_instances.get(Vector2i(row, column), null)


## Cell holding an installed module instance, or Vector2i(-1, -1).
## Used by ChipManager to find which turret's chip sockets apply.
func get_module_cell(module: Node) -> Vector2i:
	for key in _module_instances:
		if _module_instances[key] == module:
			return key
	return Vector2i(-1, -1)


func _slide_module(module: ShipModule, target: Vector2) -> void:
	if not is_instance_valid(module):
		return
	if not is_inside_tree():
		module.position = target
		return
	var tween := module.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(module, "position", target, 0.18)


# ==========================================
# Module Removal
# ==========================================

## Removes the module installed in a specified cell.
func remove_module(row: int, column: int) -> bool:
	last_module_error = ""
	if not ShipLoadout.is_valid_cell(row, column):
		return _reject_module_operation("Invalid cell position.")

	var key: Vector2i = Vector2i(row, column)
	if not _module_instances.has(key):
		return _reject_module_operation("Selected cell is already empty.")

	var proposed_modules := _get_installed_ship_modules(key)
	if not _validate_removal_energy_profile(proposed_modules):
		return false

	var module: ShipModule = _module_instances[key]
	_module_instances.erase(key)
	if is_instance_valid(module):
		module.queue_free()

	_cells[row][column].module_type = ModuleType.Empty
	ShipLoadout.remove_module(row, column)
	_recalculate_energy()
	_recalculate_health_stats(false)
	module_configuration_changed.emit()
	print("Removed module at row=%s, column=%s" % [row, column])
	queue_redraw()
	return true


# ==========================================
# Load Saved Modules
# ==========================================
## Recreates installed modules from ShipLoadout.
func load_installed_modules() -> void:
	var prepared_modules: Array[Dictionary] = []
	for row in range(GRID_SIZE):
		for column in range(GRID_SIZE):
			var scene_path: String = ShipLoadout.get_module(row, column)
			if scene_path.is_empty():
				continue

			var module_scene := load(scene_path) as PackedScene
			if module_scene == null:
				push_warning("Ship: Cannot load module: " + scene_path)
				continue

			var module := _instantiate_ship_module(module_scene)
			if module == null:
				continue

			var detected_type := _detect_module_type(module)
			if detected_type == ModuleType.Empty:
				module.free()
				push_warning("Ship: Unsupported module type: " + scene_path)
				continue

			prepared_modules.append({
				"module": module,
				"scene": module_scene,
				"type": detected_type,
				"row": row,
				"column": column,
				"priority": 0 if module.get_module_category() == ShipModule.CATEGORY_ENERGY else 1,
			})

	# Energy providers load first. Existing loadouts are restored without silently
	# deleting legacy modules; an invalid legacy profile is reported afterward.
	prepared_modules.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.priority) < int(b.priority)
	)
	for entry in prepared_modules:
		_commit_module(
			entry.module,
			entry.scene,
			entry.type,
			entry.row,
			entry.column,
			false
		)

	var restored_modules := _get_installed_ship_modules()
	_report_legacy_installation_limits(restored_modules)
	var restored_profile := energy_system.calculate_profile(restored_modules)
	if int(restored_profile.energy_module_count) < 1:
		_reject_module_operation("Existing loadout has no Energy Module; loadout preserved.")
	elif int(restored_profile.total_power_consumption) > int(restored_profile.total_power_capacity):
		_reject_module_operation(
			"Existing loadout exceeds power capacity; loadout preserved."
		)


## Ensures a new ship starts with one Basic Energy Module without overwriting.
func _ensure_required_energy_loadout() -> void:
	for row in range(GRID_SIZE):
		for column in range(GRID_SIZE):
			var scene_path := ShipLoadout.get_module(row, column)
			if scene_path.is_empty():
				continue
			if _scene_path_is_energy_module(scene_path):
				return

	var target := DEFAULT_ENERGY_CELL
	if ShipLoadout.has_module(target.x, target.y):
		target = Vector2i(-1, -1)
		for row in range(GRID_SIZE):
			for column in range(GRID_SIZE):
				if not ShipLoadout.has_module(row, column):
					target = Vector2i(row, column)
					break
			if target.x >= 0:
				break

	if target.x < 0:
		_reject_module_operation(
			"Starting loadout has no Energy Module and no empty cell; loadout preserved."
		)
		return

	ShipLoadout.install_module(
		target.x,
		target.y,
		BASIC_ENERGY_MODULE_SCENE.resource_path
	)


func _scene_path_is_energy_module(scene_path: String) -> bool:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return false
	var module := scene.instantiate() as ShipModule
	if module == null:
		return false
	var is_energy := module.get_module_category() == ShipModule.CATEGORY_ENERGY
	module.free()
	return is_energy


func _instantiate_ship_module(module_scene: PackedScene) -> ShipModule:
	if module_scene == null:
		_reject_module_operation("Module scene is missing.")
		return null

	var module := module_scene.instantiate() as ShipModule
	if module == null:
		_reject_module_operation("Module scene root must inherit ShipModule.")
		return null
	return module


func _detect_module_type(module: ShipModule) -> int:
	match module.get_module_category():
		ShipModule.CATEGORY_WEAPON:
			return ModuleType.Weapon
		ShipModule.CATEGORY_MINING:
			return ModuleType.Mining
		ShipModule.CATEGORY_ENERGY:
			return ModuleType.Energy
		ShipModule.CATEGORY_SHIELD:
			return ModuleType.Shield
		_:
			return ModuleType.Empty


func _get_installed_ship_modules(
	excluded_cell: Vector2i = Vector2i(-1, -1)
) -> Array[ShipModule]:
	var modules: Array[ShipModule] = []
	for key: Vector2i in _module_instances:
		if key == excluded_cell:
			continue
		var module := _module_instances[key] as ShipModule
		if module != null and is_instance_valid(module):
			modules.append(module)
	return modules


func _validate_energy_profile(modules: Array[ShipModule]) -> bool:
	var profile := energy_system.calculate_profile(modules)
	if int(profile.energy_module_count) < 1:
		return _reject_module_operation("At least one Energy Module is required.")
	if int(profile.total_power_consumption) > int(profile.total_power_capacity):
		return _reject_module_operation(
			"Insufficient Power: required %d, capacity %d." % [
				profile.total_power_consumption,
				profile.total_power_capacity,
			]
		)
	return true


## Let an overloaded saved loadout shed modules until it is valid again.
## Removing a power source is still rejected if it would worsen the deficit.
func _validate_removal_energy_profile(modules: Array[ShipModule]) -> bool:
	var profile := energy_system.calculate_profile(modules)
	if int(profile.energy_module_count) < 1:
		return _reject_module_operation("At least one Energy Module is required.")
	var current_profile := energy_system.calculate_profile(_get_installed_ship_modules())
	var current_deficit: int = maxi(
		0,
		int(current_profile.total_power_consumption) - int(current_profile.total_power_capacity)
	)
	var proposed_deficit: int = maxi(
		0,
		int(profile.total_power_consumption) - int(profile.total_power_capacity)
	)
	if proposed_deficit > 0 and (current_deficit == 0 or proposed_deficit > current_deficit):
		return _reject_module_operation(
			"Insufficient Power: required %d, capacity %d." % [
				profile.total_power_consumption,
				profile.total_power_capacity,
			]
		)
	return true


## Authoritative new-install guard. Saved legacy weapons are restored by
## load_installed_modules() without passing through this check, so old loadouts
## remain intact while every install and replacement path is protected.
func _validate_weapon_unlock(module: ShipModule) -> bool:
	var unlock_id: StringName = &""
	if module is WeaponModule:
		unlock_id = (module as WeaponModule).weapon_type_id
	elif module is ShieldModule:
		# Shield modules opt in by having an unlock definition.
		unlock_id = (module as ShieldModule).get_research_target_id()
		if WeaponUnlockManager.get_definition(unlock_id) == null:
			return true
	else:
		return true
	if WeaponUnlockManager.is_weapon_unlocked(unlock_id):
		return true
	return _reject_module_operation(
		"%s is locked. %s" % [
			_weapon_display_name(unlock_id),
			WeaponUnlockManager.get_unlock_requirement(unlock_id),
		]
	)


func _weapon_display_name(weapon_id: StringName) -> String:
	var definition := WeaponUnlockManager.get_definition(weapon_id)
	return definition.display_name if definition != null else String(weapon_id)


## Enforces one-time Laboratory permissions in the authoritative Ship path.
## A preserved legacy loadout may already exceed a new limit; operations that
## do not increase that category remain allowed, but no extra module can be
## added until the proposed count is within the unlocked maximum.
func _validate_module_installation_limit(
	new_module: ShipModule,
	current_modules: Array[ShipModule],
	proposed_modules: Array[ShipModule]
) -> bool:
	var module_type_id := _module_type_id_for_category(
		new_module.get_module_category()
	)
	if module_type_id.is_empty():
		return true
	var current_count := _count_module_category(
		current_modules,
		new_module.get_module_category()
	)
	var proposed_count := _count_module_category(
		proposed_modules,
		new_module.get_module_category()
	)
	var maximum := ResearchManager.get_module_installation_limit(module_type_id)
	if proposed_count > maximum and proposed_count > current_count:
		return _reject_module_operation(
			"%s installation limit reached (%d/%d)." % [
				_module_display_name(module_type_id),
				current_count,
				maximum,
			]
		)
	return true


func _report_legacy_installation_limits(modules: Array[ShipModule]) -> void:
	for module_type_id in [ENERGY_MODULE_TYPE_ID, MINING_MODULE_TYPE_ID]:
		var category := _category_for_module_type_id(module_type_id)
		var installed_count := _count_module_category(modules, category)
		var maximum := ResearchManager.get_module_installation_limit(module_type_id)
		if installed_count > maximum:
			push_warning(
				"Ship: Existing loadout has %d %s installations above the current limit of %d; loadout preserved, additional installations blocked." % [
					installed_count,
					_module_display_name(module_type_id),
					maximum,
				]
			)


func _count_module_category(
	modules: Array[ShipModule],
	category: StringName
) -> int:
	var count := 0
	for module in modules:
		if module != null and is_instance_valid(module) and module.get_module_category() == category:
			count += 1
	return count


func _module_type_id_for_category(category: StringName) -> StringName:
	match category:
		ShipModule.CATEGORY_ENERGY:
			return ENERGY_MODULE_TYPE_ID
		ShipModule.CATEGORY_MINING:
			return MINING_MODULE_TYPE_ID
	return &""


func _category_for_module_type_id(module_type_id: StringName) -> StringName:
	match module_type_id:
		ENERGY_MODULE_TYPE_ID:
			return ShipModule.CATEGORY_ENERGY
		MINING_MODULE_TYPE_ID:
			return ShipModule.CATEGORY_MINING
	return ShipModule.CATEGORY_GENERIC


func _module_display_name(module_type_id: StringName) -> String:
	return "Energy Module" if module_type_id == ENERGY_MODULE_TYPE_ID else "Mining Module"


## Public count for assembly UI and automated validation.
func get_installed_module_count(module_type_id: StringName) -> int:
	return _count_module_category(
		_get_installed_ship_modules(),
		_category_for_module_type_id(module_type_id)
	)


func _recalculate_energy() -> void:
	energy_system.recalculate(_get_installed_ship_modules())


## Rebuilds health bonuses from the installed set so replacements and removal
## cannot duplicate bonuses. Increasing max HP never heals unless this is the
## initial scene setup; decreasing it only clamps health to the new maximum.
func _recalculate_health_stats(fill_to_maximum: bool = false) -> void:
	var maximum_bonus := 0.0
	for module in _get_installed_ship_modules():
		maximum_bonus += maxf(module.get_max_hp_bonus(), 0.0)
	for effect in ResearchManager.get_ship_research_effects():
		maximum_bonus += maxf(effect.max_hp_bonus, 0.0)
	max_hp = maxf(_base_max_hp + maximum_bonus, 1.0)
	current_hp = max_hp if fill_to_maximum else minf(current_hp, max_hp)
	health_changed.emit(current_hp, max_hp)


func _on_energy_totals_changed(
	power_capacity: int,
	power_consumption: int,
	remaining_power: int,
	expansion_capacity: int
) -> void:
	energy_changed.emit(
		power_capacity,
		power_consumption,
		remaining_power,
		expansion_capacity
	)


## Returns aggregate energy data for UI, debugging, and future travel systems.
func get_energy_snapshot() -> Dictionary:
	return energy_system.get_snapshot()


## Enables or disables every installed weapon without changing its loadout.
##
## BattleMain disables attacks when the ship is destroyed. BaseMain continues
## to use assembly_mode so weapons remain visible but inactive while assembling.
func set_weapon_attacks_enabled(enabled: bool) -> void:
	if _weapon_attacks_enabled == enabled:
		return

	_weapon_attacks_enabled = enabled
	for module in _get_installed_ship_modules():
		if module is WeaponModule:
			(module as WeaponModule).assembly_mode = (
				assembly_mode or not enabled
			)

	weapon_attacks_enabled_changed.emit(enabled)


## Pauses or resumes every installed module at once: weapons stop firing and
## mining drills stop producing ore. BattleMain pauses everything when the
## battle ends (victory, defeat or evacuation).
func set_all_modules_active(active: bool) -> void:
	if _combat_frozen and not active:
		# Battle shutdown must never restore pre-freeze module state afterward.
		set_combat_frozen(false)
	_all_modules_active = active
	set_weapon_attacks_enabled(active)
	for module in _get_installed_ship_modules():
		if module is MiningModule:
			(module as MiningModule).set_mining_enabled(active and not assembly_mode)
		elif module is ShieldModule:
			(module as ShieldModule).set_module_active(active and not assembly_mode)

## Temporarily suspend module processing without resetting timers or loadout.
## Passive hull capacity remains intact, but active shield reactions are gated.
func set_combat_frozen(frozen: bool) -> void:
	if frozen == _combat_frozen:
		return
	_combat_frozen = frozen
	if frozen:
		_freeze_all_modules_active = _all_modules_active
		_all_modules_active = false
		_freeze_module_states.clear()
		for module in _get_installed_ship_modules():
			var state := {"mode": module.process_mode}
			if module is WeaponModule:
				state["assembly"] = (module as WeaponModule).assembly_mode
				(module as WeaponModule).assembly_mode = true
			if module is ShieldModule:
				state["shield_active"] = (module as ShieldModule).module_active
				(module as ShieldModule).module_active = false
			_freeze_module_states[module] = state
			module.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		_all_modules_active = _freeze_all_modules_active
		for module in _freeze_module_states:
			if not is_instance_valid(module):
				continue
			var state: Dictionary = _freeze_module_states[module]
			module.process_mode = state["mode"]
			if module is WeaponModule:
				(module as WeaponModule).assembly_mode = state["assembly"]
			if module is ShieldModule:
				(module as ShieldModule).module_active = state["shield_active"]
		_freeze_module_states.clear()


## Returns whether installed weapons are currently allowed to attack.
func are_weapon_attacks_enabled() -> bool:
	return _weapon_attacks_enabled


func _reject_module_operation(reason: String) -> bool:
	last_module_error = reason
	push_warning("Ship: " + reason)
	module_operation_failed.emit(reason)
	return false



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
