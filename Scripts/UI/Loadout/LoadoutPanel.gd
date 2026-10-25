class_name LoadoutPanel
extends Control

## Right-hand loadout panel shown while assembling the ship.
##
## List view: power budget plus every installable module, each with a quick
## "+" install button. Detail view shows module statistics and, for an
## installed module, its three magic-artifact sockets: installed / empty "+" /
## locked "RESEARCH LV xx". Clicking a socket opens the artifact collection.
## Every weapon and Shield module instance owns the sockets attached to its cell.
## BaseMain owns install/remove while this panel only presents and emits.

## A module card in the list was clicked (BaseMain shows why a locked or
## over-limit module cannot be installed).
signal module_card_pressed(module_id: StringName)
signal install_requested(module_id: StringName)
signal remove_requested
## A module card was dragged; BaseMain follows the mouse and drops it on a slot.
signal drag_started(module_id: StringName)

const PANEL_WIDTH: float = 340.0
## Mouse travel (px) before a press on a card turns into a drag.
const DRAG_THRESHOLD: float = 8.0

enum View { LIST, DETAIL, STYLE }

var _view: View = View.LIST
var _detail_id: StringName = &""
var _detail_installed: bool = false

var _slot_row: int = -1
var _slot_column: int = -1
## Catalog id of the module in the selected slot, or empty.
var _slot_module_id: StringName = &""

var _power_used: int = 0
var _power_capacity: int = 0

var _slot_pill_label: Label
var _slot_pill: PanelContainer
var _power_bar: PowerBar
var _power_label: Label
var _body: VBoxContainer
var _footer: HBoxContainer
var _message: Label
var _scroll: ScrollContainer
## View the body was last built for (scroll is kept when it stays the same).
var _last_built_view: String = ""

const ArtifactVisual := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")
const ScrollKeeper := preload("res://Scripts/UI/ScrollKeeper.gd")
const StoragePicker := preload("res://Scripts/UI/Loadout/StoragePicker.gd")
## Ship artifact slot whose picker is open in the list view (-1 = none).
var _artifact_picker_slot: int = -1
## Module artifact socket whose picker is open in detail view, or -1.
var _module_artifact_picker_slot: int = -1
## Left-of-screen grid used by ship and module artifact pickers.
var _storage: PanelContainer

var _press_id: StringName = &""
var _press_position: Vector2 = Vector2.ZERO
var _drag_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	LanguageManager.language_changed.connect(func(_locale: StringName) -> void: _rebuild())
	if not WeaponUnlockManager.weapon_unlocked.is_connected(_on_weapon_unlocked):
		WeaponUnlockManager.weapon_unlocked.connect(_on_weapon_unlocked)
	_build_frame()
	_build_storage()
	ArtifactManager.equipment_changed.connect(_on_artifact_data_changed.unbind(2))
	ArtifactManager.collection_changed.connect(_on_artifact_data_changed.unbind(2))
	ArtifactManager.artifact_operation_failed.connect(show_message)
	# Research can unlock SHIP STYLE or artifact slots shown in the list.
	ResearchManager.research_level_changed.connect(func(_id: StringName, _level: int) -> void:
		if _view == View.LIST:
			_rebuild()
	)
	_rebuild()


func _on_weapon_unlocked(_weapon_id: StringName, _display_name: String) -> void:
	_rebuild()


# ==========================================
# Public API (called by BaseMain)
# ==========================================

## Sets the selected ship cell. row < 0 means no slot is selected.
func set_slot(row: int, column: int, installed_id: StringName) -> void:
	_close_picker()
	_slot_row = row
	_slot_column = column
	_slot_module_id = installed_id
	show_message("")
	if row >= 0 and installed_id != &"":
		show_detail(installed_id, true)
	else:
		show_list()


func set_power(used: int, capacity: int) -> void:
	_power_used = used
	_power_capacity = capacity
	if _power_bar != null:
		_power_bar.set_values(used, capacity)
		_power_label.text = "%d / %d" % [used, capacity]
		_rebuild()


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = not text.is_empty()


func show_list() -> void:
	_close_picker()
	_view = View.LIST
	_rebuild()


## Hull color scheme picker (Hangar > SHIP STYLE).
func show_style() -> void:
	_view = View.STYLE
	_rebuild()


func show_detail(module_id: StringName, installed: bool) -> void:
	_module_artifact_picker_slot = -1
	_view = View.DETAIL
	_detail_id = module_id
	_detail_installed = installed
	_rebuild()


func has_slot() -> bool:
	return _slot_row >= 0


## Whether installing module_id into the selected slot fits the power budget.
func can_install(module_id: StringName) -> bool:
	if not has_slot() or not ModuleCatalog.is_module_unlocked(module_id):
		return false
	var new_stats := ModuleCatalog.get_stats(module_id)
	var old_stats := ModuleCatalog.get_stats(_slot_module_id) if _slot_module_id != &"" else {}
	var used := _power_used + int(new_stats.get("power_cost", 0)) - int(old_stats.get("power_cost", 0))
	var capacity := _power_capacity + int(new_stats.get("power_capacity", 0)) - int(old_stats.get("power_capacity", 0))
	return used <= capacity


# ==========================================
# Frame (built once)
# ==========================================

func _build_frame() -> void:
	var frame := PanelContainer.new()
	var frame_style := Palette.make_panel_style(Color(Palette.UI_PANEL, 0.96), 12, 16.0, 16.0)
	frame_style.shadow_color = Palette.SHADOW_COLOR
	frame_style.shadow_size = 0
	frame_style.shadow_offset = Palette.SHADOW_OFFSET
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	frame.add_child(column)

	# Header: title + selected slot pill.
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("LOADOUT", 22, Palette.UI_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_slot_pill = PanelContainer.new()
	_slot_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_slot_pill)
	_slot_pill_label = _label("", 11, Palette.UI_PANEL)
	_slot_pill.add_child(_slot_pill_label)

	# Power budget.
	var power_row := HBoxContainer.new()
	power_row.add_theme_constant_override("separation", 10)
	column.add_child(power_row)
	power_row.add_child(_label("POWER", 11, Palette.UI_MUTED))
	_power_bar = PowerBar.new()
	_power_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_row.add_child(_power_bar)
	_power_label = _label("0 / 0", 14, Palette.UI_TEXT)
	power_row.add_child(_power_label)
	_power_bar.set_values(_power_used, _power_capacity)

	column.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)

	_message = _label("", 12, Color("FF6B7D"))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	column.add_child(_message)

	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 10)
	column.add_child(_footer)


func _rebuild() -> void:
	if _body == null:
		return
	# Picking something rebuilds the same view: keep the scroll position so the
	# panel does not jump back to the top. A different view (or another
	# module's details) starts at the top.
	var view_key := "%d:%s" % [_view, _detail_id if _view == View.DETAIL else &""]
	var kept: Array = ScrollKeeper.capture(self) if view_key == _last_built_view else []
	_last_built_view = view_key
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	for child in _footer.get_children():
		child.queue_free()

	# Slot pill: orange when a slot is selected, muted otherwise.
	var pill_style := Palette.make_panel_style(Palette.ACCENT if has_slot() else Palette.UI_PANEL_RAISED, 11, 10.0, 3.0)
	_slot_pill.add_theme_stylebox_override("panel", pill_style)
	_slot_pill_label.text = (tr("SLOT R%d · C%d") % [_slot_row + 1, _slot_column + 1]) if has_slot() else "NO SLOT"
	_slot_pill_label.add_theme_color_override("font_color", Palette.UI_PANEL if has_slot() else Palette.UI_MUTED)

	if _view == View.LIST:
		_build_list()
	elif _view == View.STYLE:
		_build_style()
	else:
		_build_detail()
	_refresh_storage()
	if kept.is_empty():
		_scroll.scroll_vertical = 0
	else:
		ScrollKeeper.restore(self, kept)


# ==========================================
# List view
# ==========================================

func _build_list() -> void:
	if ArtifactManager.is_stall_unlocked():
		_build_artifact_slots()
	_body.add_child(_label("WEAPONS", 11, Palette.UI_MUTED))
	for entry in ModuleCatalog.ENTRIES:
		if entry["group"] == &"weapon" and not bool(entry.get("fusion_only", false)):
			_body.add_child(_make_card(entry))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	_body.add_child(spacer)
	_body.add_child(_label("SYSTEMS", 11, Palette.UI_MUTED))
	for entry in ModuleCatalog.ENTRIES:
		if entry["group"] == &"system":
			_body.add_child(_make_card(entry))
	var shield_spacer := Control.new()
	shield_spacer.custom_minimum_size = Vector2(0.0, 6.0)
	_body.add_child(shield_spacer)
	_body.add_child(_label("SHIELDS", 11, Palette.UI_MUTED))
	for entry in ModuleCatalog.ENTRIES:
		if entry["group"] == &"shield":
			_body.add_child(_make_card(entry))

	var hint := _label(
		"Click a module for details, or drag it onto any slot." if has_slot() else "Drag a module onto a ship slot, or select a slot first.",
		12, Palette.UI_MUTED
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var footer_column := VBoxContainer.new()
	footer_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_column.add_theme_constant_override("separation", 10)
	_footer.add_child(footer_column)
	footer_column.add_child(hint)
	footer_column.add_child(_make_style_button())


# ==========================================
# Ship artifacts (equipped here; collected at the Magic Stall)
# ==========================================

func _build_artifact_slots() -> void:
	_body.add_child(_label("ARTIFACTS", 11, Palette.UI_MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)
	for slot_index in range(ArtifactManager.SHIP_SLOT_COUNT):
		var slot := ArtifactSlot.new()
		var artifact_id := ArtifactManager.get_ship_artifact(slot_index)
		var definition := ArtifactManager.get_definition(artifact_id)
		slot.setup(definition, ArtifactManager.is_ship_slot_unlocked(slot_index), slot_index == _artifact_picker_slot)
		slot.set_meta("artifact_slot", slot_index)
		slot.pressed.connect(func() -> void:
			var reopen := _artifact_picker_slot != slot_index
			_reset_pickers()
			if reopen:
				_artifact_picker_slot = slot_index
			_rebuild()
		)
		row.add_child(slot)
	if _artifact_picker_slot >= 0 and not ArtifactManager.is_ship_slot_unlocked(_artifact_picker_slot):
		_artifact_picker_slot = -1
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	_body.add_child(spacer)


## Three research-gated artifact sockets occupy the former chip-socket area in
## the module detail panel. The collection picker may still open beside the
## panel, but the persistent socket UI belongs here with the module statistics.
func _build_module_artifact_sockets(cell: Vector2i) -> void:
	_body.add_child(HSeparator.new())
	var heading := _label(tr("ARTIFACTS"), 11, Palette.UI_MUTED)
	_body.add_child(heading)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	center.add_child(row)

	var next_locked_level := 0
	for slot_index in range(ArtifactManager.MODULE_SLOT_COUNT):
		var current := ArtifactManager.get_module_artifact(cell, slot_index)
		var unlocked := ArtifactManager.is_module_artifact_slot_unlocked(cell, slot_index)
		var unlock_level := ArtifactManager.get_module_artifact_slot_unlock_level(cell, slot_index)
		var slot := ArtifactSlot.new()
		slot.setup(ArtifactManager.get_definition(current), unlocked, slot_index == _module_artifact_picker_slot)
		slot.tooltip_text = (
			tr("Artifact Slot %d") % (slot_index + 1)
			if unlocked
			else tr("Research this module to Level %d") % unlock_level
		)
		if unlocked:
			slot.pressed.connect(func() -> void:
				var reopen := _module_artifact_picker_slot != slot_index
				_reset_pickers()
				if reopen:
					_module_artifact_picker_slot = slot_index
				_rebuild()
			)
		elif next_locked_level == 0:
			next_locked_level = unlock_level
		row.add_child(slot)

	if next_locked_level > 0:
		var hint := _label(
			tr("Research this module to Level %d to unlock the next artifact slot.") % next_locked_level,
			11,
			Palette.UI_MUTED
		)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(hint)



func _make_card(entry: Dictionary) -> Control:
	var id: StringName = entry["id"]
	var unlocked := ModuleCatalog.is_module_unlocked(id)
	var card := Button.new()
	card.set_meta("module_id", id)
	card.custom_minimum_size = Vector2(0.0, 64.0)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8)
	var hover := Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8)
	hover.set_border_width_all(2)
	hover.border_color = Palette.ACCENT
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if id == _slot_module_id and has_slot():
		var current := Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8)
		current.set_border_width_all(2)
		current.border_color = Palette.UI_MUTED
		card.add_theme_stylebox_override("normal", current)
	card.pressed.connect(func() -> void:
		# A drag that ends back on its own card is not a click.
		if _drag_active:
			_drag_active = false
			return
		show_detail(id, false)
		module_card_pressed.emit(id)
	)
	card.gui_input.connect(_on_card_gui_input.bind(id))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_right = -8.0
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var icon := ModuleIcon.new()
	icon.setup(id, 48.0, 0.62)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name_text: String = tr(String(entry["name"]))
	if id == _slot_module_id and has_slot():
		name_text += tr("  ·  IN SLOT")
	# Cards stay minimal: just the name. Stats live in the detail view.
	# Locked modules are dimmed and show a padlock instead of the "+" button.
	text.add_child(_label(name_text, 16, Palette.UI_TEXT if unlocked else Palette.UI_MUTED))
	if not unlocked:
		icon.modulate = Color(1.0, 1.0, 1.0, 0.45)
		card.tooltip_text = "Locked · %s" % ModuleCatalog.get_unlock_requirement(id)

	var pill := PowerPill.new()
	pill.setup(ModuleCatalog.get_stats(id))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pill)

	if not unlocked:
		var lock := LockIcon.new()
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lock)
		return card

	var add := Button.new()
	add.text = "+"
	add.custom_minimum_size = Vector2(32.0, 32.0)
	add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add.focus_mode = Control.FOCUS_NONE
	add.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_primary(add, 6)
	add.add_theme_font_size_override("font_size", 20)
	var allowed := can_install(id) and id != _slot_module_id
	add.disabled = not allowed
	add.tooltip_text = _install_block_reason(id) if not allowed else "Install into the selected slot"
	add.pressed.connect(func() -> void: install_requested.emit(id))
	row.add_child(add)
	return card


## Turns a press-and-move on a card into a drag (see drag_started).
func _on_card_gui_input(event: InputEvent, id: StringName) -> void:
	if not ModuleCatalog.is_module_unlocked(id):
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_press_id = id
			_press_position = (event as InputEventMouseButton).global_position
			_drag_active = false
		else:
			_press_id = &""
	elif event is InputEventMouseMotion and _press_id == id and not _drag_active:
		if (event as InputEventMouseMotion).global_position.distance_to(_press_position) > DRAG_THRESHOLD:
			_drag_active = true
			drag_started.emit(id)


func _install_block_reason(id: StringName) -> String:
	if not ModuleCatalog.is_module_unlocked(id):
		return ModuleCatalog.get_unlock_requirement(id)
	if not has_slot():
		return "Select a slot on the ship first"
	if id == _slot_module_id:
		return "Already in this slot"
	if not can_install(id):
		return "Not enough power — add an Energy Module"
	return ""


# ==========================================
# Ship style view
# ==========================================

func _make_style_button() -> Button:
	var button := Button.new()
	button.text = "SHIP STYLE"
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "Change the ship's colors"
	for state in ["normal", "hover", "pressed"]:
		var style := Palette.make_panel_style(Color(Palette.ACCENT, 0.12) if state != "normal" else Color(0, 0, 0, 0), 8, 12.0, 6.0)
		style.set_border_width_all(2)
		style.border_color = Palette.ACCENT
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, Palette.ACCENT)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(show_style)
	# Locked until the Laboratory's Ship Style research is done.
	if not ResearchManager.is_ship_style_unlocked():
		button.text = "SHIP STYLE  ·  LOCKED"
		button.disabled = true
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		button.tooltip_text = "Research SHIP STYLE in the Laboratory (Ship)"
		var locked := Palette.make_panel_style(Color(0, 0, 0, 0), 8, 12.0, 6.0)
		locked.set_border_width_all(2)
		locked.border_color = Palette.MECH
		button.add_theme_stylebox_override("disabled", locked)
		button.add_theme_color_override("font_disabled_color", Palette.UI_MUTED)
	return button


func _build_style() -> void:
	var back := Button.new()
	back.text = "‹  LOADOUT"
	back.flat = true
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.focus_mode = Control.FOCUS_NONE
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.add_theme_color_override("font_color", Palette.UI_MUTED)
	back.add_theme_color_override("font_hover_color", Palette.UI_TEXT)
	back.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	back.pressed.connect(show_list)
	_body.add_child(back)
	_body.add_child(_label("SHIP STYLE", 20, Palette.UI_TEXT))
	_body.add_child(_label("COLOR", 11, Palette.UI_MUTED))
	for style_id in ShipHullVisual.STYLE_ORDER:
		_body.add_child(_make_style_card(style_id))
	var hull_spacer := Control.new()
	hull_spacer.custom_minimum_size = Vector2(0.0, 6.0)
	_body.add_child(hull_spacer)
	_body.add_child(_label("HULL", 11, Palette.UI_MUTED))
	for hull_id in ShipHullVisual.HULL_ORDER:
		_body.add_child(_make_hull_card(hull_id))
	var thruster_spacer := Control.new()
	thruster_spacer.custom_minimum_size = Vector2(0.0, 6.0)
	_body.add_child(thruster_spacer)
	_body.add_child(_label("THRUSTERS", 11, Palette.UI_MUTED))
	for thruster_id in ShipHullVisual.THRUSTER_ORDER:
		_body.add_child(_make_thruster_card(thruster_id))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	_body.add_child(spacer)
	_body.add_child(_label("ROTATION", 11, Palette.UI_MUTED))
	var rotation_row := HBoxContainer.new()
	rotation_row.add_theme_constant_override("separation", 8)
	_body.add_child(rotation_row)
	for degrees in ShipLoadout.ROTATIONS:
		rotation_row.add_child(_make_rotation_button(degrees))
	var hint := _label("Color, hull and thrusters mix freely; modules keep their own colors. Rotation also turns the ship's edges in battle. Saved automatically.", 12, Palette.UI_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(hint)


func _make_rotation_button(degrees: float) -> Button:
	var selected := is_equal_approx(ShipLoadout.layout_rotation, degrees)
	var button := Button.new()
	button.text = "%d°" % roundi(degrees)
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if selected:
		_style_primary(button, 8)
	else:
		for state in ["normal", "hover", "pressed"]:
			var style := Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8)
			if state == "hover":
				style.set_border_width_all(2)
				style.border_color = Palette.UI_MUTED
			button.add_theme_stylebox_override(state, style)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", Palette.UI_TEXT)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(func() -> void:
		ShipLoadout.set_layout_rotation(degrees)
		ShipLoadout.save()
		_rebuild()
	)
	return button


func _make_style_card(style_id: StringName) -> Control:
	var colors := ShipHullVisual.style_colors(style_id)
	var selected := style_id == ShipLoadout.style_id
	var card := Button.new()
	card.custom_minimum_size = Vector2(0.0, 52.0)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8)
	var hover := Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8)
	hover.set_border_width_all(2)
	hover.border_color = Palette.UI_MUTED
	if selected:
		normal.set_border_width_all(2)
		normal.border_color = Palette.ACCENT
		hover.border_color = Palette.ACCENT
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.pressed.connect(func() -> void:
		ShipLoadout.set_style(style_id)
		ShipLoadout.save()
		_rebuild()
	)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14.0
	row.offset_right = -14.0
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var swatches := StyleSwatches.new()
	swatches.colors = [colors["tile"], colors["rim"], colors["iron"], colors["accent"]]
	swatches.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatches)
	var name_label := _label(String(colors["name"]).to_upper(), 14, Palette.UI_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	if selected:
		var tag := _label("IN USE", 10, Palette.ACCENT)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
	return card


func _make_hull_card(hull_id: StringName) -> Control:
	var design := ShipHullVisual.hull_design(hull_id)
	var selected := hull_id == ShipLoadout.hull_id
	var card := Button.new()
	card.custom_minimum_size = Vector2(0.0, 64.0)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8)
	var hover := Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8)
	hover.set_border_width_all(2)
	hover.border_color = Palette.UI_MUTED
	if selected:
		normal.set_border_width_all(2)
		normal.border_color = Palette.ACCENT
		hover.border_color = Palette.ACCENT
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.pressed.connect(func() -> void:
		ShipLoadout.set_hull(hull_id)
		ShipLoadout.save()
		_rebuild()
	)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10.0
	row.offset_right = -14.0
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var preview := HullPreview.new()
	preview.hull_id = hull_id
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(preview)
	var name_label := _label(String(design["name"]).to_upper(), 14, Palette.UI_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	if selected:
		var tag := _label("IN USE", 10, Palette.ACCENT)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
	return card


func _make_thruster_card(thruster_id: StringName) -> Control:
	var selected := thruster_id == ShipLoadout.thruster_id
	var card := Button.new()
	card.custom_minimum_size = Vector2(0.0, 72.0)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8)
	var hover := Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8)
	hover.set_border_width_all(2)
	hover.border_color = Palette.UI_MUTED
	if selected:
		normal.set_border_width_all(2)
		normal.border_color = Palette.ACCENT
		hover.border_color = Palette.ACCENT
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.pressed.connect(func() -> void:
		ShipLoadout.set_thruster(thruster_id)
		ShipLoadout.save()
		_rebuild()
	)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_right = -14.0
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	# Unfolded preview on the current hull; hovering the card fires it.
	var preview := HullPreview.new()
	preview.hull_id = ShipLoadout.hull_id
	preview.thruster_id = thruster_id
	preview.deploy = 1.0
	preview.span = 330.0
	preview.hover_source = card
	preview.custom_minimum_size = Vector2(64.0, 64.0)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(preview)
	var name_label := _label(String(ShipHullVisual.THRUSTERS[thruster_id]["name"]).to_upper(), 14, Palette.UI_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	if selected:
		var tag := _label("IN USE", 10, Palette.ACCENT)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
	return card


## Tiny 3x3 hull in the current color scheme for a hull design card.
class HullPreview:
	extends Control

	const CELL: float = 64.0
	var hull_id: StringName = &"classic"
	## Thruster style to draw (&"" = the saved one), how far it is unfolded,
	## and the card whose hover makes it fire.
	var thruster_id: StringName = &""
	var deploy: float = 0.0
	var span: float = 260.0
	var hover_source: Control = null
	var _thrust: float = 0.0
	var _geometry: Dictionary = {}
	var _cells: Array[Vector2i] = []

	func _init() -> void:
		custom_minimum_size = Vector2(56.0, 56.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for row in range(3):
			for column in range(3):
				_cells.append(Vector2i(column, row))

	func _process(_delta: float) -> void:
		if not _geometry.is_empty() and ShipHullVisual.is_animated(_geometry):
			queue_redraw()
		if hover_source != null:
			var hovered := hover_source.get_global_rect().has_point(hover_source.get_global_mouse_position())
			_thrust = move_toward(_thrust, 0.85 if hovered else 0.0, _delta * 3.0)
			if _thrust > 0.0 or hovered:
				queue_redraw()

	func _draw() -> void:
		if _geometry.is_empty():
			_geometry = ShipHullVisual.build(_cells, CELL, hull_id)
		var scale: float = size.x / span
		var center := Vector2(CELL * 1.5, CELL * 1.5)
		draw_set_transform(size * 0.5 - center * scale, 0.0, Vector2.ONE * scale)
		ShipHullVisual.draw_pods(self, _geometry, _thrust, thruster_id, deploy)
		ShipHullVisual.draw_hull(self, _geometry, _cells, CELL)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Four small color chips: tile, frame, frame shade, accent.
class StyleSwatches:
	extends Control

	var colors: Array = []

	func _init() -> void:
		custom_minimum_size = Vector2(74.0, 14.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for index in range(colors.size()):
			var rect := Rect2(Vector2(float(index) * 19.0, 0.0), Vector2(14.0, 14.0))
			Palette.draw_rounded_rect(self, rect, 3.0, colors[index])


# ==========================================
# Detail view
# ==========================================

func _build_detail() -> void:
	var id := _detail_id
	var entry := ModuleCatalog.get_entry(id)
	var stats := ModuleCatalog.get_stats(id)
	var category := String(stats.get("category", ""))
	var module_unlocked := ModuleCatalog.is_module_unlocked(id)

	var back := Button.new()
	back.text = "‹  ALL MODULES"
	back.flat = true
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.focus_mode = Control.FOCUS_NONE
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.add_theme_color_override("font_color", Palette.UI_MUTED)
	back.add_theme_color_override("font_hover_color", Palette.UI_TEXT)
	back.add_theme_font_size_override("font_size", 13)
	back.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	back.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	back.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	back.pressed.connect(show_list)
	_body.add_child(back)

	# Big icon + identity.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	_body.add_child(top)
	var icon := ModuleIcon.new()
	icon.setup(id, 96.0, 1.45)
	top.add_child(icon)
	var identity := VBoxContainer.new()
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 6)
	top.add_child(identity)
	var title := _label(tr(String(entry.get("name", ""))).to_upper(), 20, Palette.UI_TEXT)
	identity.add_child(title)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 6)
	identity.add_child(tags)
	var category_pill := PanelContainer.new()
	category_pill.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.UI_PANEL_RAISED, 11, 10.0, 2.0))
	category_pill.add_child(_label(category.to_upper(), 10, Palette.UI_MUTED))
	tags.add_child(category_pill)
	var pill := PowerPill.new()
	pill.setup(stats)
	tags.add_child(pill)
	identity.add_child(_label(
		"INSTALLED" if _detail_installed else ("IN SLOT" if id == _slot_module_id and has_slot() else "NOT INSTALLED"),
		11, Palette.ACCENT if _detail_installed else Palette.UI_MUTED
	))

	_body.add_child(HSeparator.new())
	if not module_unlocked:
		var requirement := _label(
			"LOCKED  //  %s" % ModuleCatalog.get_unlock_requirement(id).to_upper(),
			12,
			Palette.UI_MUTED
		)
		requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(requirement)
	var turret_cell := _detail_turret_cell(category)
	var stats_header := HBoxContainer.new()
	_body.add_child(stats_header)
	var stats_label := _label("STATS", 11, Palette.UI_MUTED)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_header.add_child(stats_label)
	for row in _stat_rows(id, stats, category, turret_cell):
		_body.add_child(row)
	if turret_cell.x >= 0:
		_build_module_artifact_sockets(turret_cell)

	# Footer actions.
	if _detail_installed:
		var remove := Button.new()
		remove.text = "REMOVE"
		remove.custom_minimum_size = Vector2(110.0, 44.0)
		remove.focus_mode = Control.FOCUS_NONE
		remove.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		remove.pressed.connect(func() -> void: remove_requested.emit())
		_footer.add_child(remove)
		var change := Button.new()
		change.text = "CHANGE MODULE"
		change.custom_minimum_size = Vector2(0.0, 44.0)
		change.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		change.focus_mode = Control.FOCUS_NONE
		change.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_primary(change, 8)
		change.pressed.connect(show_list)
		_footer.add_child(change)
	else:
		var install := Button.new()
		install.text = "INSTALL TO SLOT" if has_slot() else "SELECT A SLOT FIRST"
		install.custom_minimum_size = Vector2(0.0, 44.0)
		install.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		install.focus_mode = Control.FOCUS_NONE
		install.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_primary(install, 8)
		var allowed := module_unlocked and can_install(id) and id != _slot_module_id
		install.disabled = not allowed
		if not module_unlocked:
			install.text = "WEAPON LOCKED"
		elif not allowed and has_slot():
			install.text = "ALREADY IN SLOT" if id == _slot_module_id else "NOT ENOUGH POWER"
		install.pressed.connect(func() -> void: install_requested.emit(id))
		_footer.add_child(install)


func _stat_rows(id: StringName, stats: Dictionary, category: String, turret_cell: Vector2i = Vector2i(-1, -1)) -> Array[Control]:
	var rows: Array[Control] = []
	match category:
		"weapon":
			var damage := float(stats.get("damage", 0.0))
			var rate := float(stats.get("fire_rate", 0.0))
			var damage_max := ModuleCatalog.get_stat_max("damage")
			var rate_max := ModuleCatalog.get_stat_max("fire_rate")
			var dps_max := ModuleCatalog.get_stat_max("dps")
			rows.append(StatRow.make("DAMAGE", ModuleCatalog.format_number(damage), damage / damage_max))
			rows.append(StatRow.make("FIRE RATE", "%s / s" % ModuleCatalog.format_number(rate), rate / rate_max))
			if stats.has("attack_radius"):
				var radius := float(stats["attack_radius"])
				rows.append(StatRow.make("RADIUS", ModuleCatalog.format_number(radius), radius / ModuleCatalog.get_stat_max("attack_range")))
			elif stats.has("attack_range"):
				var reach := float(stats["attack_range"])
				rows.append(StatRow.make("RANGE", ModuleCatalog.format_number(reach), reach / ModuleCatalog.get_stat_max("attack_range")))
			if stats.has("projectile_range"):
				var projectile_reach := float(stats["projectile_range"])
				rows.append(StatRow.make("PROJECTILE RANGE", ModuleCatalog.format_number(projectile_reach), projectile_reach / ModuleCatalog.get_stat_max("projectile_range")))
			if stats.has("aoe_radius"):
				var aoe := float(stats["aoe_radius"])
				rows.append(StatRow.make("BLAST RADIUS", ModuleCatalog.format_number(aoe), aoe / ModuleCatalog.get_stat_max("aoe_radius")))
			rows.append(StatRow.make("DPS", ModuleCatalog.format_number(damage * rate), damage * rate / dps_max))
		"energy":
			rows.append(StatRow.make("POWER", "+%d" % int(stats.get("power_capacity", 0)), 1.0))
		"mining":
			var ore := float(stats.get("mining_rate", 0.0))
			rows.append(StatRow.make("ORE", "%s / s" % ModuleCatalog.format_number(ore), ore / ModuleCatalog.get_stat_max("mining_rate")))
		"shield":
			rows.append(StatRow.make("MAX HULL", "+%s" % ModuleCatalog.format_number(stats.get("max_hp_bonus", 0.0)), 1.0))
			var regeneration := float(stats.get("regeneration_per_second", 0.0))
			if regeneration > 0.0:
				rows.append(StatRow.make("REPAIR", "%s / s" % ModuleCatalog.format_number(regeneration), 1.0))
	rows.append(StatRow.make("POWER USE", str(int(stats.get("power_cost", 0))), -1.0))
	return rows


# ==========================================
# Module artifact sockets
# ==========================================

## Ship cell of the installed weapon shown in the detail view, else (-1, -1).
func _detail_turret_cell(category: String) -> Vector2i:
	if not _detail_installed or not has_slot() or category not in ["weapon", "shield"]:
		return Vector2i(-1, -1)
	var entry := ModuleCatalog.find_by_scene(ShipLoadout.get_module(_slot_row, _slot_column))
	if entry.is_empty() or StringName(entry.get("id", &"")) != _detail_id:
		return Vector2i(-1, -1)
	return Vector2i(_slot_row, _slot_column)


func _build_storage() -> void:
	_storage = StoragePicker.new()
	_storage.visible = false
	_storage.close_requested.connect(_close_picker)
	add_child(_storage)


func _process(_delta: float) -> void:
	if _storage != null and _storage.visible:
		var parent_control := get_parent() as Control
		var height: float = parent_control.size.y if parent_control != null else get_viewport_rect().size.y
		_storage.pin_left(height)


## Forgets which picker is open (without rebuilding).
func _reset_pickers() -> void:
	_artifact_picker_slot = -1
	_module_artifact_picker_slot = -1


func _close_picker() -> void:
	if not is_picker_open() and (_storage == null or not _storage.visible):
		return
	_reset_pickers()
	_rebuild()


func is_picker_open() -> bool:
	return _artifact_picker_slot >= 0 or _module_artifact_picker_slot >= 0


## Cells of the open storage picker (exposed for tests).
func get_picker_rows() -> Array[Node]:
	return _storage.get_cells() if _storage != null and _storage.visible else ([] as Array[Node])


## Fills the left storage grid for whichever picker is open, or hides it.
func _refresh_storage() -> void:
	if _storage == null:
		return
	var was_visible: bool = _storage.visible
	var shown := false
	if _artifact_picker_slot >= 0 and _view == View.LIST:
		shown = _fill_ship_artifact_storage(_artifact_picker_slot)
	elif _module_artifact_picker_slot >= 0 and _view == View.DETAIL and _detail_installed:
		shown = _fill_module_artifact_storage(_module_artifact_picker_slot)
	if not shown:
		_reset_pickers()
	_storage.visible = shown
	if shown and not was_visible:
		_storage.modulate.a = 0.0
		_storage.create_tween().tween_property(_storage, "modulate:a", 1.0, 0.14)


func _fill_ship_artifact_storage(slot_index: int) -> bool:
	if not ArtifactManager.is_ship_slot_unlocked(slot_index):
		return false
	var entries: Array = []
	var current := ArtifactManager.get_ship_artifact(slot_index)
	if not current.is_empty():
		entries.append(_artifact_remove_entry(current, func() -> void:
			ArtifactManager.unequip_ship_artifact(slot_index)
			_close_picker()
		))
	for artifact_id in ArtifactManager.get_owned_artifact_ids():
		var definition := ArtifactManager.get_definition(artifact_id)
		if definition == null or definition.equip_target != MagicArtifactDefinition.EquipTarget.SHIP or artifact_id == current:
			continue
		entries.append(_artifact_entry(definition, func() -> void:
			ArtifactManager.equip_ship_artifact(slot_index, artifact_id)
			_close_picker()
		))
	_storage.show_entries("ARTIFACTS", "SHIP SLOT %d" % (slot_index + 1), entries, "Collect artifacts on planets; they are kept at the Magic Stall.")
	return true


func _fill_module_artifact_storage(slot_index: int) -> bool:
	if not ArtifactManager.is_stall_unlocked() or not has_slot():
		return false
	var cell := Vector2i(_slot_row, _slot_column)
	if not ArtifactManager.is_module_artifact_slot_unlocked(cell, slot_index):
		return false
	var entries: Array = []
	var current := ArtifactManager.get_module_artifact(cell, slot_index)
	if not current.is_empty():
		entries.append(_artifact_remove_entry(current, func() -> void:
			ArtifactManager.unequip_module_artifact(cell, slot_index)
			_close_picker()
		))
	for artifact_id in ArtifactManager.get_owned_artifact_ids():
		var definition := ArtifactManager.get_definition(artifact_id)
		# Use the same cell-aware rule as the actual equip command. Fusion
		# weapons inherit compatibility from both of their source modules and
		# therefore cannot be filtered only by their result module id.
		if definition == null or not ArtifactManager.is_module_artifact_compatible(cell, artifact_id) or artifact_id == current:
			continue
		entries.append(_artifact_entry(definition, func() -> void:
			ArtifactManager.equip_module_artifact(cell, artifact_id, slot_index)
			_close_picker()
		))
	_storage.show_entries("ARTIFACTS", "%s · SLOT %d" % [_cell_label(cell), slot_index + 1], entries, "No compatible artifact is currently owned.")
	return true


func _artifact_entry(definition: MagicArtifactDefinition, callback: Callable) -> Dictionary:
	var rarity := ArtifactVisual.rarity_index(definition)
	var in_use := ArtifactManager.is_artifact_equipped(definition.artifact_id)
	var stats: Array[String] = []
	for chip in ArtifactVisual.stat_chips(definition):
		stats.append(String(chip[1]))
	return {
		"kind": &"artifact", "id": definition.artifact_id, "rarity": rarity,
		"tag": "IN USE" if in_use else "",
		"name": definition.display_name.to_upper(),
		"detail": definition.description.strip_edges() if not definition.description.strip_edges().is_empty() else "  ".join(stats),
		"note": ArtifactVisual.rarity_name(rarity) + ("  ·  equipped elsewhere; moves here" if in_use else ""),
		"action": "EQUIP", "callback": callback,
	}


func _artifact_remove_entry(artifact_id: StringName, callback: Callable) -> Dictionary:
	var definition := ArtifactManager.get_definition(artifact_id)
	return {
		"kind": &"remove", "id": artifact_id, "tag": "REMOVE",
		"name": "REMOVE " + (definition.display_name.to_upper() if definition != null else ""),
		"detail": "", "note": "Back to the Magic Stall collection.", "action": "REMOVE",
		"callback": callback,
	}


func _on_artifact_data_changed() -> void:
	if _view == View.DETAIL:
		_rebuild()


func _cell_label(cell: Vector2i) -> String:
	return "R%d · C%d" % [cell.x + 1, cell.y + 1]


# ==========================================
# Helpers
# ==========================================

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _style_primary(button: Button, radius: int) -> void:
	var normal := Palette.make_panel_style(Palette.ACCENT, radius, 10.0, 6.0)
	var hover := Palette.make_panel_style(Color("FFA04A"), radius, 10.0, 6.0)
	var disabled := Palette.make_panel_style(Palette.UI_PANEL_RAISED, radius, 10.0, 6.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Palette.UI_PANEL)
	button.add_theme_color_override("font_disabled_color", Color(Palette.UI_MUTED, 0.7))


# ==========================================
# Small drawn widgets
# ==========================================

## Small padlock shown on locked module cards.
## Ship artifact slot: equipped icon, empty "+", or a lock (needs research).
class ArtifactSlot extends Button:
	const Visual := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")
	var _definition: MagicArtifactDefinition
	var _unlocked: bool = false
	var _open: bool = false

	func setup(definition: MagicArtifactDefinition, unlocked: bool, open: bool) -> void:
		_definition = definition
		_unlocked = unlocked
		_open = open
		custom_minimum_size = Vector2(62.0, 62.0)
		focus_mode = Control.FOCUS_NONE
		disabled = not unlocked
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
		var empty := definition == null
		var color: Color = Visual.rarity_color(Visual.rarity_index(definition)) if not empty else Palette.MECH
		var normal := Palette.make_panel_style(Color("17120F") if empty else Palette.UI_PANEL_RAISED, 12)
		normal.set_border_width_all(2)
		normal.border_color = Palette.ACCENT if open else color
		var hover := normal.duplicate() as StyleBoxFlat
		hover.border_color = Palette.ACCENT
		for state in ["normal", "disabled"]:
			add_theme_stylebox_override(state, normal)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", hover)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if not empty:
			var icon := Visual.IconView.new(46.0)
			icon.artifact_id = definition.artifact_id
			icon.rarity = Visual.rarity_index(definition)
			icon.custom_minimum_size = Vector2.ZERO
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 7.0
			icon.offset_top = 7.0
			icon.offset_right = -7.0
			icon.offset_bottom = -7.0
			add_child(icon)

	func _draw() -> void:
		if _definition != null:
			return
		var c := size * 0.5
		if not _unlocked:
			draw_rect(Rect2(c + Vector2(-7.0, -2.0), Vector2(14.0, 11.0)), Palette.MECH_LIGHT)
			draw_arc(c + Vector2(0.0, -2.0), 5.0, PI, TAU, 12, Palette.MECH_LIGHT, 2.4)
			return
		var color := Palette.ACCENT if _open else Palette.MECH_LIGHT
		draw_line(c + Vector2(-8.0, 0.0), c + Vector2(8.0, 0.0), color, 2.4)
		draw_line(c + Vector2(0.0, -8.0), c + Vector2(0.0, 8.0), color, 2.4)


class LockIcon extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(32.0, 32.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0.0, 2.0)
		draw_arc(c + Vector2(0.0, -4.0), 5.5, PI, TAU, 16, Palette.UI_MUTED, 2.4)
		draw_line(c + Vector2(-5.5, -4.0), c + Vector2(-5.5, -1.0), Palette.UI_MUTED, 2.4)
		draw_line(c + Vector2(5.5, -4.0), c + Vector2(5.5, -1.0), Palette.UI_MUTED, 2.4)
		Palette.draw_rounded_rect(self, Rect2(c + Vector2(-8.0, -2.0), Vector2(16.0, 12.0)), 2.5, Palette.UI_MUTED)
		draw_circle(c + Vector2(0.0, 3.5), 1.8, Palette.UI_PANEL_RAISED)


## Segmented power budget bar.
class PowerBar extends Control:
	var used: int = 0
	var capacity: int = 0

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, 12.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_values(new_used: int, new_capacity: int) -> void:
		used = new_used
		capacity = new_capacity
		queue_redraw()

	func _draw() -> void:
		var segments := maxi(capacity, 1)
		var gap := 4.0
		var width := (size.x - gap * float(segments - 1)) / float(segments)
		for index in range(segments):
			var color := Palette.MECH
			if index < used:
				color = Palette.UI_TEXT
			if used > capacity:
				color = Palette.THREAT
			Palette.draw_rounded_rect(self, Rect2(float(index) * (width + gap), 0.0, width, size.y), 3.0, color)


## Pill showing a module's power use (or "+N" for energy producers).
class PowerPill extends Control:
	var text: String = ""

	func setup(stats: Dictionary) -> void:
		var capacity := int(stats.get("power_capacity", 0))
		text = ("+%d" % capacity) if capacity > 0 else str(int(stats.get("power_cost", 0)))
		custom_minimum_size = Vector2(44.0, 22.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		tooltip_text = "Power"
		queue_redraw()

	func _draw() -> void:
		Palette.draw_rounded_rect(self, Rect2(Vector2.ZERO, size), size.y * 0.5, Palette.UI_PANEL)
		var c := Vector2(13.0, size.y * 0.5)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(1.5, -6.0), c + Vector2(-4.0, 1.0), c + Vector2(0.0, 1.0),
			c + Vector2(-1.5, 6.0), c + Vector2(4.0, -1.0), c + Vector2(0.0, -1.0),
		]), Palette.ACCENT)
		var font := get_theme_default_font()
		draw_string(font, Vector2(20.0, size.y * 0.5 + 5.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 24.0, 13, Palette.UI_TEXT)


## Label, value and a thin bar. fraction < 0 hides the bar. A chip bonus adds
## a gold "+N" after the value and a gold segment after the white bar.
class StatRow extends Control:
	var label_text: String = ""
	var value_text: String = ""
	var fraction: float = 0.0
	var bonus_text: String = ""
	var bonus_fraction: float = 0.0

	static func make(label: String, value: String, frac: float, bonus: String = "", bonus_frac: float = 0.0) -> StatRow:
		var row := StatRow.new()
		row.label_text = label
		row.value_text = value
		row.fraction = frac
		row.bonus_text = bonus
		row.bonus_fraction = maxf(bonus_frac, 0.0) if not bonus.is_empty() else 0.0
		row.custom_minimum_size = Vector2(0.0, 22.0 if frac < 0.0 else 32.0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return row

	func _draw() -> void:
		var font := get_theme_default_font()
		draw_string(font, Vector2(0.0, 15.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Palette.UI_TEXT)
		var bonus_width := 0.0
		if not bonus_text.is_empty():
			bonus_width = font.get_string_size(" " + bonus_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(size.x - bonus_width, 15.0), " " + bonus_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Palette.GOLD)
		draw_string(font, Vector2(0.0, 15.0), value_text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - bonus_width, 14, Palette.UI_TEXT)
		if fraction >= 0.0:
			var track := Rect2(0.0, 23.0, size.x, 6.0)
			Palette.draw_rounded_rect(self, track, 3.0, Palette.MECH)
			# When base + bonus overflow the bar, shrink both so the gold part stays visible.
			var base_part := clampf(fraction, 0.0, 1.0)
			var bonus_part := bonus_fraction
			if base_part + bonus_part > 1.0:
				var total := base_part + bonus_part
				base_part /= total
				bonus_part /= total
			var base_width := maxf(track.size.x * base_part, 6.0)
			if bonus_part > 0.0:
				var end_x := minf(base_width + maxf(track.size.x * bonus_part, 4.0), track.size.x)
				Palette.draw_rounded_rect(self, Rect2(track.position, Vector2(end_x, 6.0)), 3.0, Palette.GOLD)
			Palette.draw_rounded_rect(self, Rect2(track.position, Vector2(base_width, 6.0)), 3.0, Palette.UI_TEXT)
