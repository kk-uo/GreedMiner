extends Node2D

## Controls the base: the asteroid-hold overview and the ship assembly view.
##
## Overview: the whole dwarven hold is visible. Clicking the hangar pad zooms
## the camera onto the ship and slides in the loadout panel on the right;
## clicking the star map opens destination selection. In assembly, the Back
## button, Esc or a click on empty ground zooms back out.

const PLANET_SELECT_SCENE_PATH: String = "res://Scenes/PlanetSelection/planet_select.tscn"

## Gap between the loadout panel and the window edge, in UI units.
const PANEL_MARGIN: float = 16.0

enum ViewState { OVERVIEW, ZOOMING, ASSEMBLY, LABORATORY, WAREHOUSE, MAGIC_STALL }

const WarehousePanelScript := preload("res://Scripts/UI/WarehousePanel.gd")
const HANGAR_TURRET_IDLE := preload("res://Scripts/Base/HangarTurretIdle.gd")
const TutorialGuideScript := preload("res://Scripts/UI/TutorialGuide.gd")
const MagicStallPanelScript := preload("res://Scripts/UI/MagicStallPanel.gd")
const ArtifactTutorialHintScript := preload("res://Scripts/UI/ArtifactTutorialHint.gd")

## Camera zoom while assembling the ship.
@export_range(0.5, 4.0, 0.05) var assembly_zoom: float = 1.8
## Seconds for the zoom between overview and assembly.
@export_range(0.1, 2.0, 0.05) var zoom_duration: float = 0.7


@onready var ship: Ship = $Ship
@onready var ui_root: ScaledUIRoot = $BaseUI/UIRoot
@onready var loadout_panel: LoadoutPanel = $BaseUI/UIRoot/LoadoutPanel
@onready var hangar: AsteroidHangar = $Battlefield
@onready var back_button: Button = $BaseUI/UIRoot/BackButton
@onready var fade_overlay: ColorRect = $BaseUI/FadeOverlay
@onready var laboratory_panel: LaboratoryPanel = $BaseUI/UIRoot/LaboratoryPanel
@onready var settings_menu: SettingsMenu = $BaseUI/UIRoot/SettingsMenu
@onready var ore_panel: Control = $BaseUI/UIRoot/OrePanel
@onready var developer_panel: DeveloperPanel = $BaseUI/UIRoot/DeveloperPanel


var _selected_row: int = -1
var _selected_column: int = -1

var _view_state: ViewState = ViewState.OVERVIEW
## Frame on which a cell selection was last cleared. The ship handles a click
## before BaseMain does, so this tells us the same click already deselected.
var _popup_closed_frame: int = -1
var _camera_tween: Tween
var _panel_tween: Tween
var _drag_id: StringName = &""
var _drag_ghost: Control
var _drop_marker: DropMarker
## Rearranging installed modules by dragging them on the ship.
const SHIP_DRAG_THRESHOLD: float = 8.0
var _press_cell := Vector2i(-1, -1)
var _press_position := Vector2.ZERO
var _ship_drag_cell := Vector2i(-1, -1)
## Warehouse modal (built in code, see _build_warehouse). It opens from the
## vault door hotspot in the asteroid's bottom-right wall.
var warehouse_panel: Control
var magic_stall_panel: MagicStallPanel
var artifact_tutorial_hint: ArtifactTutorialHint


func _ready() -> void:
	ChipManager.set_equipment_changes_enabled(true)
	ArtifactManager.set_equipment_changes_enabled(true)
	_connect_once(ship.cell_selected, _on_ship_cell_selected)
	_connect_once(ship.cell_deselected, _on_ship_cell_deselected)
	_connect_once(ship.energy_changed, _on_ship_energy_changed)
	_connect_once(ship.module_operation_failed, _on_module_operation_failed)
	_connect_once(loadout_panel.install_requested, _on_install_requested)
	_connect_once(loadout_panel.remove_requested, _on_remove_requested)
	_connect_once(loadout_panel.drag_started, _on_drag_started)
	_connect_once(back_button.pressed, _exit_assembly)
	_connect_once(laboratory_panel.close_requested, _close_laboratory)
	_connect_once(settings_menu.main_menu_requested, _show_toast.bind("MAIN MENU  ·  COMING SOON"))
	_connect_once(settings_menu.developer_mode_requested, developer_panel.open_panel)
	_connect_once(get_viewport().size_changed, _on_viewport_size_changed)
	_connect_once(ArtifactManager.tutorial_state_changed, _on_artifact_tutorial_state_changed)
	_connect_once(ArtifactManager.artifact_granted, _on_artifact_granted_at_base)

	_build_warehouse()
	_build_magic_stall()
	_build_tutorial()
	_build_artifact_tutorial_hint()
	loadout_panel.set_power(ship.total_power_consumption, ship.total_power_capacity)
	loadout_panel.set_slot(-1, -1, &"")
	_drop_marker = DropMarker.new()
	ship.add_child(_drop_marker)
	# Docked weapons look around now and then (presentation only).
	var turret_idle: Node = HANGAR_TURRET_IDLE.new()
	turret_idle.name = "HangarTurretIdle"
	turret_idle.set("ship", ship)
	add_child(turret_idle)

	# Start every visit in the overview; assembly is entered by clicking the pad.
	ship.cell_input_enabled = false
	back_button.hide()
	loadout_panel.hide()
	laboratory_panel.hide()
	fade_overlay.color.a = 0.0
	ship.world_camera.zoom = Vector2.ONE * _get_overview_zoom()

	# Coming back from an evacuation: the ship lands on the pad.
	if ShipLaunchController.landing_pending_at_base:
		ShipLaunchController.landing_pending_at_base = false
		var launcher := get_node_or_null("ShipLaunchController") as ShipLaunchController
		if launcher != null:
			ship.visual_altitude = 1.0
			ship.modulate.a = 0.0
			launcher.play_landing.call_deferred()


## The settings gear is only offered in the overview (assembly has BACK there).
func _process(_delta: float) -> void:
	settings_menu.set_available(_view_state == ViewState.OVERVIEW)
	ore_panel.visible = _view_state == ViewState.OVERVIEW


## Connects a signal only if it is not already connected.
func _connect_once(source_signal: Signal, callback: Callable) -> void:
	if not source_signal.is_connected(callback):
		source_signal.connect(callback)


# ==========================================
# Slot selection and loadout panel
# ==========================================

func _on_ship_cell_selected(row: int, column: int) -> void:
	_selected_row = row
	_selected_column = column
	loadout_panel.set_slot(row, column, _get_installed_id(row, column))


func _on_ship_cell_deselected() -> void:
	if _selected_row >= 0:
		_popup_closed_frame = Engine.get_process_frames()
	_selected_row = -1
	_selected_column = -1
	loadout_panel.set_slot(-1, -1, &"")


## Catalog id of the module currently installed in a cell, or empty.
func _get_installed_id(row: int, column: int) -> StringName:
	var scene_path := ShipLoadout.get_module(row, column)
	if scene_path.is_empty():
		return &""
	var entry := ModuleCatalog.find_by_scene(scene_path)
	return entry.get("id", &"") as StringName


## Installs (or replaces) the module in the selected cell. Ship validates power.
func _on_install_requested(module_id: StringName) -> void:
	if not ShipLoadout.is_valid_cell(_selected_row, _selected_column):
		return
	if not ModuleCatalog.is_module_unlocked(module_id):
		loadout_panel.show_message(ModuleCatalog.get_unlock_requirement(module_id))
		return
	var scene := ModuleCatalog.get_scene(module_id)
	if scene == null:
		return
	if ship.replace_module(scene, ModuleCatalog.get_module_type(module_id), _selected_row, _selected_column):
		loadout_panel.set_slot(_selected_row, _selected_column, module_id)
		ShipLoadout.save()


func _on_remove_requested() -> void:
	if not ShipLoadout.is_valid_cell(_selected_row, _selected_column):
		return
	if ship.remove_module(_selected_row, _selected_column):
		loadout_panel.set_slot(_selected_row, _selected_column, &"")
		ShipLoadout.save()


# ==========================================
# Drag-and-drop install (list card -> ship slot)
# ==========================================

func _on_drag_started(module_id: StringName) -> void:
	if _view_state != ViewState.ASSEMBLY:
		return
	_cancel_drag()
	_drag_id = module_id
	_drag_ghost = _make_drag_ghost(module_id)
	ui_root.add_child(_drag_ghost)
	_update_drag()


## Runs before the GUI so the drag keeps following the mouse over the panel.
func _input(event: InputEvent) -> void:
	if _drag_id == &"":
		if _handle_ship_remove_input(event):
			return
		_handle_ship_drag_input(event)
		return
	if event is InputEventMouseMotion:
		_update_drag()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
		_finish_drag()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_drag()
		get_viewport().set_input_as_handled()


## Right-clicking an occupied ship cell removes its module through the same
## validated path as the loadout panel's Remove button.
func _handle_ship_remove_input(event: InputEvent) -> bool:
	if _view_state != ViewState.ASSEMBLY:
		return false
	var button := event as InputEventMouseButton
	if (
		button == null
		or not button.pressed
		or button.button_index != MOUSE_BUTTON_RIGHT
	):
		return false
	# UI clicks must never affect a world-space slot behind the panel.
	if get_viewport().gui_get_hovered_control() != null:
		return false
	var cell := ship.get_cell_at_global(_event_world_position(button))
	if not ShipLoadout.is_valid_cell(cell.x, cell.y):
		return false
	if not ShipLoadout.has_module(cell.x, cell.y):
		return false

	_cancel_ship_drag()
	ship.select_cell(cell.x, cell.y)
	_on_remove_requested()
	get_viewport().set_input_as_handled()
	return true


func _update_drag() -> void:
	if _drag_ghost != null:
		var mouse := ui_root.screen_to_ui(get_viewport().get_mouse_position())
		_drag_ghost.position = mouse - Vector2(32.0, 32.0)
	var cell := ship.get_cell_at_global(get_global_mouse_position())
	_drop_marker.show_cell(cell, _drop_allowed(_drag_id, cell))


func _finish_drag() -> void:
	var module_id := _drag_id
	var cell := ship.get_cell_at_global(get_global_mouse_position())
	_cancel_drag()
	drop_module_on_cell(module_id, cell)


## Installs module_id into a ship cell as if it had been dropped there.
## Returns false when the cell is invalid or the install was rejected.
func drop_module_on_cell(module_id: StringName, cell: Vector2i) -> bool:
	if not ShipLoadout.is_valid_cell(cell.x, cell.y):
		return false
	# Select the slot, then install exactly like the "+" button does.
	ship.select_cell(cell.x, cell.y)
	if _get_installed_id(cell.x, cell.y) != module_id:
		_on_install_requested(module_id)
	# Dragging is for quick building, so the panel stays on the module list
	# (the slot stays highlighted) instead of jumping to the module's details.
	loadout_panel.show_list()
	return _get_installed_id(cell.x, cell.y) == module_id


func _cancel_drag() -> void:
	_drag_id = &""
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	if _drop_marker != null:
		_drop_marker.show_cell(Vector2i(-1, -1), false)


# ==========================================
# Drag-and-drop rearrange (ship slot -> ship slot)
# ==========================================

## Press on an installed module, move a few pixels: it is picked up. Drop it
## on another slot to move it there (swapping with whatever is there). A plain
## click still just selects the slot (Ship handles that).
func _handle_ship_drag_input(event: InputEvent) -> void:
	if _view_state != ViewState.ASSEMBLY:
		_cancel_ship_drag()
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press_cell = Vector2i(-1, -1)
			if get_viewport().gui_get_hovered_control() != null:
				return
			var cell := ship.get_cell_at_global(_event_world_position(button))
			if cell.x >= 0 and ShipLoadout.has_module(cell.x, cell.y):
				_press_cell = cell
				_press_position = button.position
		else:
			if _ship_drag_cell.x >= 0:
				_finish_ship_drag(_event_world_position(button))
				get_viewport().set_input_as_handled()
			_press_cell = Vector2i(-1, -1)
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		if _ship_drag_cell.x < 0 and _press_cell.x >= 0 and motion.position.distance_to(_press_position) > SHIP_DRAG_THRESHOLD:
			_begin_ship_drag(_press_cell)
		if _ship_drag_cell.x >= 0:
			_update_ship_drag(_event_world_position(motion), motion.position)
		return
	if _ship_drag_cell.x >= 0 and event.is_action_pressed("ui_cancel"):
		_cancel_ship_drag()
		get_viewport().set_input_as_handled()


func _begin_ship_drag(cell: Vector2i) -> void:
	var module_id := _get_installed_id(cell.x, cell.y)
	if module_id == &"":
		return
	_ship_drag_cell = cell
	_press_cell = Vector2i(-1, -1)
	_drag_ghost = _make_drag_ghost(module_id)
	ui_root.add_child(_drag_ghost)
	var module := ship.get_module_at(cell.x, cell.y)
	if module != null:
		module.modulate.a = 0.35


func _update_ship_drag(world_position: Vector2, screen_position: Vector2) -> void:
	if _drag_ghost != null:
		_drag_ghost.position = ui_root.screen_to_ui(screen_position) - Vector2(32.0, 32.0)
	var cell := ship.get_cell_at_global(world_position)
	_drop_marker.show_cell(cell if cell != _ship_drag_cell else Vector2i(-1, -1), cell.x >= 0)


## World position of a mouse event (independent of the OS cursor).
func _event_world_position(event: InputEventMouse) -> Vector2:
	return to_global((make_input_local(event) as InputEventMouse).position)


func _finish_ship_drag(world_position: Vector2) -> void:
	var source := _ship_drag_cell
	var target := ship.get_cell_at_global(world_position)
	_cancel_ship_drag()
	move_module_to_cell(source, target)


## Moves the module in source to target (swapping if target is occupied) as if
## it had been dragged there. Returns false when nothing changed.
func move_module_to_cell(source: Vector2i, target: Vector2i) -> bool:
	if not ShipLoadout.is_valid_cell(target.x, target.y) or source == target:
		return false
	if not ship.swap_modules(source.x, source.y, target.x, target.y):
		return false
	ShipLoadout.save()
	ship.select_cell(target.x, target.y)
	return true


func _cancel_ship_drag() -> void:
	if _ship_drag_cell.x >= 0:
		var module := ship.get_module_at(_ship_drag_cell.x, _ship_drag_cell.y)
		if module != null:
			module.modulate.a = 1.0
	_ship_drag_cell = Vector2i(-1, -1)
	_press_cell = Vector2i(-1, -1)
	if _drag_ghost != null and _drag_id == &"":
		_drag_ghost.queue_free()
		_drag_ghost = null
	if _drop_marker != null and _drag_id == &"":
		_drop_marker.show_cell(Vector2i(-1, -1), false)


## Whether dropping module_id on cell fits the power budget (Ship still validates).
func _drop_allowed(module_id: StringName, cell: Vector2i) -> bool:
	if cell.x < 0 or not ModuleCatalog.is_module_unlocked(module_id):
		return false
	var old_id := _get_installed_id(cell.x, cell.y)
	if old_id == module_id:
		return false
	var new_stats := ModuleCatalog.get_stats(module_id)
	var old_stats := ModuleCatalog.get_stats(old_id) if old_id != &"" else {}
	var used: int = ship.total_power_consumption + int(new_stats.get("power_cost", 0)) - int(old_stats.get("power_cost", 0))
	var capacity: int = ship.total_power_capacity + int(new_stats.get("power_capacity", 0)) - int(old_stats.get("power_capacity", 0))
	return used <= capacity


func _make_drag_ghost(module_id: StringName) -> Control:
	var ghost := PanelContainer.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := Palette.make_panel_style(Color(Palette.UI_PANEL, 0.9), 10, 6.0, 6.0)
	style.set_border_width_all(2)
	style.border_color = Palette.ACCENT
	ghost.add_theme_stylebox_override("panel", style)
	var icon := ModuleIcon.new()
	icon.setup(module_id, 52.0, 0.66)
	ghost.add_child(icon)
	ghost.modulate.a = 0.92
	return ghost


## Ship-local highlight of the slot under a dragged module.
class DropMarker:
	extends Node2D

	var _cell := Vector2i(-1, -1)
	var _allowed := false

	func _init() -> void:
		z_index = 10

	func show_cell(cell: Vector2i, allowed: bool) -> void:
		if cell == _cell and allowed == _allowed:
			return
		_cell = cell
		_allowed = allowed
		queue_redraw()

	func _draw() -> void:
		if _cell.x < 0:
			return
		var size: float = Ship.CELL_SIZE
		var rect := Rect2(Vector2(_cell.y, _cell.x) * size, Vector2.ONE * size).grow(-2.0)
		var color: Color = Palette.ACCENT if _allowed else Palette.THREAT
		Palette.draw_rounded_rect(self, rect, 8.0, Color(color, 0.22))
		var points := Palette.rounded_rect_points(rect, 8.0)
		points.append(points[0])
		draw_polyline(points, color, 4.0)


func _on_ship_energy_changed(
	power_capacity: int,
	power_consumption: int,
	_available_power: int,
	_expansion_capacity: int
) -> void:
	loadout_panel.set_power(power_consumption, power_capacity)


func _on_module_operation_failed(reason: String) -> void:
	loadout_panel.show_message(reason)


func _on_viewport_size_changed() -> void:
	match _view_state:
		ViewState.OVERVIEW:
			ship.world_camera.zoom = Vector2.ONE * _get_overview_zoom()
		ViewState.ASSEMBLY:
			ship.world_camera.offset = _get_assembly_camera_offset()


## Shifts the camera so the ship stays centered in the space left of the panel.
func _get_assembly_camera_offset() -> Vector2:
	var panel_screen_width := (LoadoutPanel.PANEL_WIDTH + PANEL_MARGIN) * ui_root.ui_visual_scale
	return Vector2(panel_screen_width * 0.5 / assembly_zoom, 0.0)


func _slide_panel(show_panel: bool) -> void:
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var shown_left := -(LoadoutPanel.PANEL_WIDTH + PANEL_MARGIN)
	var hidden_left := 24.0
	if show_panel:
		loadout_panel.show()
		loadout_panel.offset_left = hidden_left
		loadout_panel.offset_right = hidden_left + LoadoutPanel.PANEL_WIDTH
		loadout_panel.modulate.a = 0.0
		_panel_tween.set_parallel(true)
		_panel_tween.tween_property(loadout_panel, "offset_left", shown_left, 0.3)
		_panel_tween.tween_property(loadout_panel, "offset_right", -PANEL_MARGIN, 0.3)
		_panel_tween.tween_property(loadout_panel, "modulate:a", 1.0, 0.2)
	else:
		_panel_tween.set_parallel(true)
		_panel_tween.tween_property(loadout_panel, "offset_left", hidden_left, 0.2)
		_panel_tween.tween_property(loadout_panel, "offset_right", hidden_left + LoadoutPanel.PANEL_WIDTH, 0.2)
		_panel_tween.tween_property(loadout_panel, "modulate:a", 0.0, 0.2)
		_panel_tween.chain().tween_callback(loadout_panel.hide)


# ==========================================
# Overview <-> assembly
# ==========================================

func _unhandled_input(event: InputEvent) -> void:
	match _view_state:
		ViewState.OVERVIEW:
			if event is InputEventMouseMotion:
				_update_hover()
			elif (
				event is InputEventMouseButton
				and (event as InputEventMouseButton).pressed
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			):
				_update_hover()
				match hangar.hovered:
					AsteroidHangar.HOTSPOT_HANGAR:
						_enter_assembly()
						get_viewport().set_input_as_handled()
					AsteroidHangar.HOTSPOT_STAR_MAP:
						_open_star_map()
						get_viewport().set_input_as_handled()
					AsteroidHangar.HOTSPOT_LAB:
						_open_laboratory()
						get_viewport().set_input_as_handled()
					AsteroidHangar.HOTSPOT_WAREHOUSE:
						open_warehouse()
						get_viewport().set_input_as_handled()
					AsteroidHangar.HOTSPOT_MAGIC_STALL:
						open_magic_stall()
						get_viewport().set_input_as_handled()
		ViewState.ASSEMBLY:
			if (
				event is InputEventMouseButton
				and (event as InputEventMouseButton).pressed
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			):
				# Clicking empty ground off the pad zooms back out. If that same
				# click just cleared a slot selection, it only clears it.
				var on_pad := hangar.get_hotspot_at(_event_world_position(event as InputEventMouse)) == AsteroidHangar.HOTSPOT_HANGAR
				if not on_pad and _popup_closed_frame != Engine.get_process_frames():
					_exit_assembly()
					get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_cancel"):
				# First Esc clears the selected slot, the next one leaves assembly.
				if _selected_row >= 0:
					ship.clear_selection()
					_on_ship_cell_deselected()
				else:
					_exit_assembly()
				get_viewport().set_input_as_handled()
		ViewState.LABORATORY:
			if event.is_action_pressed("ui_cancel"):
				_close_laboratory()
				get_viewport().set_input_as_handled()
		ViewState.WAREHOUSE:
			if event.is_action_pressed("ui_cancel"):
				close_warehouse()
				get_viewport().set_input_as_handled()
		ViewState.MAGIC_STALL:
			if event.is_action_pressed("ui_cancel"):
				close_magic_stall()
				get_viewport().set_input_as_handled()


func _open_laboratory() -> void:
	if _view_state != ViewState.OVERVIEW:
		return
	_view_state = ViewState.LABORATORY
	_clear_hover()
	hangar.show_tags = false
	laboratory_panel.open_panel()


func _close_laboratory() -> void:
	if _view_state != ViewState.LABORATORY:
		return
	laboratory_panel.close_panel()
	_view_state = ViewState.OVERVIEW
	hangar.show_tags = true
	_update_hover()


# ==========================================
# Warehouse
# ==========================================

## Current view as a name (OVERVIEW, ZOOMING, ASSEMBLY, ...), for the tutorial.
func get_view_state_name() -> StringName:
	return StringName(ViewState.keys()[_view_state])


## First-time guide: arrows to the hangar, weapon and mining cards, star map.
func _build_tutorial() -> void:
	if not TutorialGuideScript.should_run():
		return
	var guide: Control = TutorialGuideScript.new()
	guide.name = "TutorialGuide"
	guide.base = self
	ui_root.add_child(guide)
	# Below settings / developer panels, above the base HUD.
	ui_root.move_child(guide, laboratory_panel.get_index())


## Builds the centred Warehouse modal below the settings and developer panels.
func _build_warehouse() -> void:
	if warehouse_panel != null:
		return
	var insert_index := laboratory_panel.get_index() + 1
	warehouse_panel = WarehousePanelScript.new()
	warehouse_panel.name = "WarehousePanel"
	ui_root.add_child(warehouse_panel)
	ui_root.move_child(warehouse_panel, insert_index)
	warehouse_panel.close_requested.connect(close_warehouse)


func open_warehouse() -> void:
	if _view_state != ViewState.OVERVIEW:
		return
	_view_state = ViewState.WAREHOUSE
	_clear_hover()
	hangar.show_tags = false
	hangar.vault_held_open = true
	warehouse_panel.open_panel()


func close_warehouse() -> void:
	if _view_state != ViewState.WAREHOUSE:
		return
	warehouse_panel.close_panel()
	_view_state = ViewState.OVERVIEW
	hangar.show_tags = true
	hangar.vault_held_open = false
	_update_hover()


# ==========================================
# Magic Artifact Stall
# ==========================================

func _build_magic_stall() -> void:
	if magic_stall_panel != null:
		return
	magic_stall_panel = MagicStallPanelScript.new()
	magic_stall_panel.name = "MagicStallPanel"
	ui_root.add_child(magic_stall_panel)
	ui_root.move_child(magic_stall_panel, laboratory_panel.get_index() + 1)
	magic_stall_panel.close_requested.connect(close_magic_stall)


func open_magic_stall() -> void:
	if _view_state != ViewState.OVERVIEW:
		return
	if not ArtifactManager.is_stall_unlocked():
		_show_toast("MAGIC STALL  ·  LOCKED UNTIL YOUR FIRST ARTIFACT")
		return
	_view_state = ViewState.MAGIC_STALL
	_clear_hover()
	hangar.show_tags = false
	hangar.artifact_guide_active = false
	if artifact_tutorial_hint != null:
		artifact_tutorial_hint.hide()
	magic_stall_panel.open_panel(ArtifactManager.first_artifact_id, ArtifactManager.tutorial_pending)


func close_magic_stall() -> void:
	if _view_state != ViewState.MAGIC_STALL:
		return
	magic_stall_panel.close_panel()
	_view_state = ViewState.OVERVIEW
	hangar.show_tags = true
	if ArtifactManager.tutorial_pending and artifact_tutorial_hint != null:
		artifact_tutorial_hint.show()
		hangar.artifact_guide_active = true
	_update_hover()


func _build_artifact_tutorial_hint() -> void:
	if not ArtifactManager.tutorial_pending or ArtifactManager.tutorial_completed:
		return
	if artifact_tutorial_hint != null:
		return
	artifact_tutorial_hint = ArtifactTutorialHintScript.new()
	artifact_tutorial_hint.name = "ArtifactTutorialHint"
	ui_root.add_child(artifact_tutorial_hint)
	artifact_tutorial_hint.open_requested.connect(open_magic_stall)
	artifact_tutorial_hint.skip_requested.connect(ArtifactManager.complete_tutorial)
	hangar.artifact_guide_active = true


func _on_artifact_tutorial_state_changed(pending: bool, completed: bool) -> void:
	if completed or not pending:
		hangar.artifact_guide_active = false
		if artifact_tutorial_hint != null:
			artifact_tutorial_hint.queue_free()
			artifact_tutorial_hint = null
		return
	_build_artifact_tutorial_hint()


func _on_artifact_granted_at_base(definition: MagicArtifactDefinition, _first: bool) -> void:
	_show_toast("ARTIFACT ACQUIRED  ·  %s" % definition.display_name.to_upper())
	_build_artifact_tutorial_hint()


## Zoom that fits the whole asteroid hold in the window.
func _get_overview_zoom() -> float:
	var viewport_size := get_viewport_rect().size
	var world := hangar.world_size
	return minf(viewport_size.x / world.x, viewport_size.y / world.y)


func _update_hover() -> void:
	hangar.hovered = hangar.get_hotspot_at(get_global_mouse_position())
	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND
		if hangar.hovered != AsteroidHangar.HOTSPOT_NONE
		else Input.CURSOR_ARROW
	)


func _clear_hover() -> void:
	hangar.hovered = AsteroidHangar.HOTSPOT_NONE
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _start_camera_tween() -> Tween:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return _camera_tween


## Clicking the hangar pad: zoom onto the ship, then allow assembly.
func _enter_assembly() -> void:
	if _view_state != ViewState.OVERVIEW:
		return
	_view_state = ViewState.ZOOMING
	_clear_hover()
	hangar.show_tags = false

	var tween := _start_camera_tween()
	tween.set_parallel(true)
	tween.tween_property(ship.world_camera, "zoom", Vector2.ONE * assembly_zoom, zoom_duration)
	tween.tween_property(ship.world_camera, "offset", _get_assembly_camera_offset(), zoom_duration)
	tween.chain().tween_callback(func() -> void:
		_view_state = ViewState.ASSEMBLY
		_slide_panel(true)
		ship.cell_input_enabled = true
		back_button.modulate.a = 0.0
		back_button.show()
		create_tween().tween_property(back_button, "modulate:a", 1.0, 0.15)
	)


## Back button / Esc: close any menu and zoom back out to the overview.
func _exit_assembly() -> void:
	if _view_state != ViewState.ASSEMBLY:
		return
	_view_state = ViewState.ZOOMING
	ship.cell_input_enabled = false
	ship.clear_selection()
	_on_ship_cell_deselected()
	back_button.hide()
	_slide_panel(false)

	var tween := _start_camera_tween()
	tween.set_parallel(true)
	tween.tween_property(ship.world_camera, "zoom", Vector2.ONE * _get_overview_zoom(), zoom_duration)
	tween.tween_property(ship.world_camera, "offset", Vector2.ZERO, zoom_duration)
	tween.chain().tween_callback(func() -> void:
		_view_state = ViewState.OVERVIEW
		hangar.show_tags = true
		_update_hover()
	)


## Clicking the star map: glide toward it, fade out, open destination select.
func _open_star_map() -> void:
	if _view_state != ViewState.OVERVIEW:
		return
	_view_state = ViewState.ZOOMING
	_clear_hover()

	var tween := _start_camera_tween()
	tween.set_parallel(true)
	tween.tween_property(ship.world_camera, "global_position", hangar.get_hotspot_center(AsteroidHangar.HOTSPOT_STAR_MAP), 0.55)
	tween.tween_property(ship.world_camera, "zoom", Vector2.ONE * _get_overview_zoom() * 2.2, 0.55)
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.4).set_delay(0.15)
	tween.chain().tween_callback(func() -> void:
		# Mission resources reset only after an unlocked planet is deployed.
		get_tree().change_scene_to_file(PLANET_SELECT_SCENE_PATH)
	)


var _toast: PanelContainer
var _toast_tween: Tween


## Small transient message at the top of the screen.
func _show_toast(text: String) -> void:
	if _toast == null:
		_toast = PanelContainer.new()
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.add_theme_stylebox_override("panel", Palette.make_panel_style(Color(Palette.UI_PANEL, 0.94), 8, 18.0, 10.0))
		var label := Label.new()
		label.name = "Text"
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Palette.UI_TEXT)
		_toast.add_child(label)
		ui_root.add_child(_toast)
	(_toast.get_node("Text") as Label).text = text
	_toast.reset_size()
	_toast.position = Vector2((ui_root.size.x - _toast.size.x) * 0.5, 24.0)
	_toast.modulate.a = 0.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
