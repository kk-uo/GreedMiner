class_name MagicStallPanel
extends Control

## Magic Stall: two tabs, almost no text.
## - COLLECTION: every owned artifact as a big card (rarity diamond, equipped
##   badge), sortable by rarity or by acquisition order, plus a detail card
##   (big icon, rarity, ship/module, three icon+number stats, source).
## - COMPENDIUM: all artifacts grouped by planet; undiscovered ones are dark
##   silhouettes that already show their rarity.
## Equipping happens in the hangar (LoadoutPanel > ARTIFACTS); this panel only
## shows and collects. All state lives in ArtifactManager.

signal close_requested

const PANEL_SIZE := Vector2(1000.0, 560.0)
const ArtifactVisual := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")
const ScrollKeeper := preload("res://Scripts/UI/ScrollKeeper.gd")

enum Tab { COLLECTION, COMPENDIUM }
enum Sort { RARITY, NEWEST }

## Planet rows of the Compendium: id -> [label, ground theme].
const PLANET_ROWS := [
	[&"rocky_planet", "ROCKY", &"rocky"],
	[&"goblin_planet", "VERDANT", &"jungle"],
	[&"frozen_planet", "FROZEN", &"frozen"],
	[&"volcanic_planet", "VOLCANIC", &"volcanic"],
]

var selected_artifact_id: StringName = &""
## Kept for compatibility; ship slots are chosen in the hangar now.
var selected_ship_slot: int = 0
var tab: Tab = Tab.COLLECTION
var sort_mode: Sort = Sort.RARITY

var _frame: PanelContainer
var _tab_buttons: Array[Button] = []
var _sort_buttons: Array[Button] = []
var _progress: HBoxContainer
var _progress_bar: ProgressStrip
var _progress_label: Label
var _collection_page: HBoxContainer
var _compendium_page: ScrollContainer
var _grid: GridContainer
var _count_label: Label
var _detail_icon: Control
var _detail_name: Label
var _detail_tags: HBoxContainer
var _detail_stats: HBoxContainer
var _detail_description: Label
var _detail_status: Label
var _detail_source: Label
var _compendium_rows: VBoxContainer
## Tab + sort the pages were last built for (scroll is kept while unchanged).
var _last_built_view: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	ArtifactManager.collection_changed.connect(_on_artifact_data_changed.unbind(2))
	ArtifactManager.equipment_changed.connect(_on_artifact_data_changed.unbind(2))
	hide()


func open_panel(preselect_id: StringName = &"", show_tutorial: bool = false) -> void:
	tab = Tab.COLLECTION
	if ArtifactManager.owns_artifact(preselect_id):
		selected_artifact_id = preselect_id
	elif not ArtifactManager.owns_artifact(selected_artifact_id):
		var sorted := _sorted_owned()
		selected_artifact_id = sorted[0] if not sorted.is_empty() else &""
	# Visiting the stall is the whole first-artifact guide now; equipping
	# happens in the hangar.
	if show_tutorial and ArtifactManager.tutorial_pending:
		ArtifactManager.complete_tutorial()
	refresh()
	show()


func close_panel() -> void:
	hide()


func select_artifact(artifact_id: StringName) -> void:
	if ArtifactManager.get_definition(artifact_id) == null:
		return
	selected_artifact_id = artifact_id
	refresh()


func select_ship_slot(slot_index: int) -> void:
	selected_ship_slot = clampi(slot_index, 0, ArtifactManager.SHIP_SLOT_COUNT - 1)


func set_tab(next: Tab) -> void:
	tab = next
	refresh()


func set_sort(next: Sort) -> void:
	sort_mode = next
	refresh()


func refresh() -> void:
	if _frame == null:
		return
	var view_key := "%d:%d" % [int(tab), int(sort_mode)]
	var kept: Array = ScrollKeeper.capture(self) if view_key == _last_built_view else []
	_last_built_view = view_key
	for index in range(_tab_buttons.size()):
		_style_tab(_tab_buttons[index], index == int(tab))
	_collection_page.visible = tab == Tab.COLLECTION
	_compendium_page.visible = tab == Tab.COMPENDIUM
	_progress.visible = tab == Tab.COMPENDIUM
	var total: int = ArtifactManager.get_all_definitions().size()
	var owned: int = ArtifactManager.get_owned_artifact_ids().size()
	_progress_bar.ratio = float(owned) / float(maxi(total, 1))
	_progress_bar.queue_redraw()
	_progress_label.text = "%d / %d" % [owned, total]
	if tab == Tab.COLLECTION:
		_refresh_collection(owned, total)
	else:
		_refresh_compendium()
	ScrollKeeper.restore(self, kept)


# ==========================================
# Build
# ==========================================

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_frame = PanelContainer.new()
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	_frame.custom_minimum_size = PANEL_SIZE
	_frame.offset_left = -PANEL_SIZE.x * 0.5
	_frame.offset_right = PANEL_SIZE.x * 0.5
	_frame.offset_top = -PANEL_SIZE.y * 0.5
	_frame.offset_bottom = PANEL_SIZE.y * 0.5
	var frame_style := Palette.make_panel_style(Color(Palette.UI_PANEL, 0.99), 16, 20.0, 16.0)
	frame_style.set_border_width_all(1)
	frame_style.border_color = Palette.MECH
	_frame.add_theme_stylebox_override("panel", frame_style)
	add_child(_frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	_frame.add_child(root)

	# Header: rune badge, tabs, progress (compendium), close.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	header.add_child(RuneBadge.new())
	var tabs_box := PanelContainer.new()
	tabs_box.add_theme_stylebox_override("panel", Palette.make_panel_style(Color("14100D"), 12, 4.0, 4.0))
	header.add_child(tabs_box)
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 4)
	tabs_box.add_child(tabs_row)
	for entry in [[Tab.COLLECTION, "COLLECTION"], [Tab.COMPENDIUM, "COMPENDIUM"]]:
		var button := Button.new()
		button.text = entry[1]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size = Vector2(0.0, 34.0)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(set_tab.bind(entry[0]))
		tabs_row.add_child(button)
		_tab_buttons.append(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_progress = HBoxContainer.new()
	_progress.add_theme_constant_override("separation", 10)
	header.add_child(_progress)
	_progress_bar = ProgressStrip.new()
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress.add_child(_progress_bar)
	_progress_label = _label("", 14, Palette.UI_TEXT)
	_progress.add_child(_progress_label)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.custom_minimum_size = Vector2(34.0, 34.0)
	close.add_theme_font_size_override("font_size", 20)
	close.add_theme_color_override("font_color", Palette.UI_MUTED)
	close.add_theme_color_override("font_hover_color", Palette.UI_TEXT)
	for state in ["normal", "hover", "pressed"]:
		close.add_theme_stylebox_override(state, Palette.make_panel_style(Palette.UI_PANEL_RAISED, 9))
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)

	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pages)
	_build_collection(pages)
	_build_compendium(pages)


func _build_collection(parent: Control) -> void:
	_collection_page = HBoxContainer.new()
	_collection_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_collection_page.add_theme_constant_override("separation", 16)
	parent.add_child(_collection_page)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	_collection_page.add_child(left)
	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 6)
	left.add_child(sort_row)
	for entry in [[Sort.RARITY, "◆  RARITY"], [Sort.NEWEST, "⟲  NEWEST"]]:
		var button := Button.new()
		button.text = entry[1]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size = Vector2(0.0, 30.0)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(set_sort.bind(entry[0]))
		sort_row.add_child(button)
		_sort_buttons.append(button)
	var sort_spacer := Control.new()
	sort_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_row.add_child(sort_spacer)
	_count_label = _label("", 12, Palette.UI_MUTED)
	sort_row.add_child(_count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	var detail := PanelContainer.new()
	detail.custom_minimum_size = Vector2(300.0, 0.0)
	detail.add_theme_stylebox_override("panel", Palette.make_panel_style(Color("14100D"), 14, 18.0, 18.0))
	_collection_page.add_child(detail)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	detail.add_child(column)
	_detail_icon = ArtifactVisual.IconView.new(150.0)
	_detail_icon.glow = true
	_detail_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_detail_icon)
	_detail_name = _label("", 21, Palette.UI_TEXT)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_name)
	_detail_tags = HBoxContainer.new()
	_detail_tags.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail_tags.add_theme_constant_override("separation", 6)
	column.add_child(_detail_tags)
	_detail_stats = HBoxContainer.new()
	_detail_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail_stats.add_theme_constant_override("separation", 6)
	column.add_child(_detail_stats)
	_detail_description = _label("", 13, Palette.UI_TEXT)
	_detail_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_description)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)
	_detail_status = _label("", 12, Palette.UI_MUTED)
	_detail_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_detail_status)
	_detail_source = _label("", 12, Palette.UI_MUTED)
	_detail_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_detail_source)


func _build_compendium(parent: Control) -> void:
	_compendium_page = ScrollContainer.new()
	_compendium_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_compendium_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(_compendium_page)
	_compendium_rows = VBoxContainer.new()
	_compendium_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compendium_rows.add_theme_constant_override("separation", 12)
	_compendium_page.add_child(_compendium_rows)


# ==========================================
# Refresh
# ==========================================

func _refresh_collection(owned: int, total: int) -> void:
	for index in range(_sort_buttons.size()):
		_style_toggle(_sort_buttons[index], index == int(sort_mode))
	_count_label.text = "%d / %d" % [owned, total]
	_clear_children(_grid)
	for artifact_id in _sorted_owned():
		var definition := ArtifactManager.get_definition(artifact_id)
		var card := ArtifactCard.new()
		card.setup(definition, artifact_id == selected_artifact_id, ArtifactManager.is_artifact_equipped(artifact_id), false)
		card.pressed.connect(select_artifact.bind(artifact_id))
		_grid.add_child(card)
	_refresh_detail()


func _refresh_detail() -> void:
	var definition := ArtifactManager.get_definition(selected_artifact_id)
	var has_artifact := definition != null and ArtifactManager.owns_artifact(selected_artifact_id)
	_detail_icon.visible = has_artifact
	_clear_children(_detail_tags)
	_clear_children(_detail_stats)
	if not has_artifact:
		_detail_name.text = ""
		_detail_description.text = ""
		_detail_status.text = ""
		_detail_source.text = ""
		return
	_detail_icon.artifact_id = definition.artifact_id
	_detail_icon.rarity = ArtifactVisual.rarity_index(definition)
	_detail_icon.queue_redraw()
	_detail_name.text = definition.display_name
	_detail_description.text = definition.description
	var rarity_index: int = ArtifactVisual.rarity_index(definition)
	var rarity_color: Color = ArtifactVisual.rarity_color(rarity_index)
	_detail_tags.add_child(_chip("◆ " + ArtifactVisual.rarity_name(rarity_index), rarity_color))
	var module_target := definition.equip_target == MagicArtifactDefinition.EquipTarget.MODULE
	_detail_tags.add_child(_chip("MODULE" if module_target else "SHIP", Palette.UI_TEXT))
	for stat in ArtifactVisual.stat_chips(definition):
		var chip := StatChip.new()
		chip.kind = stat[0]
		chip.text = stat[1]
		_detail_stats.add_child(chip)
	if ArtifactManager.is_artifact_equipped(definition.artifact_id):
		_detail_status.text = "● EQUIPPED"
		_detail_status.add_theme_color_override("font_color", Palette.ACCENT)
	else:
		_detail_status.text = "EQUIP IN HANGAR"
		_detail_status.add_theme_color_override("font_color", Palette.UI_MUTED)
	_detail_source.text = definition.source_name if not definition.source_name.is_empty() else ""


func _refresh_compendium() -> void:
	_clear_children(_compendium_rows)
	var rows: Array = PLANET_ROWS.duplicate()
	rows.append([&"", "UNKNOWN", &"rocky"])
	for row in rows:
		var definitions: Array[MagicArtifactDefinition] = []
		for definition in ArtifactManager.get_all_definitions():
			if definition == null:
				continue
			var planet: StringName = definition.source_planet_id
			var known := false
			for entry in PLANET_ROWS:
				if entry[0] == planet:
					known = true
			if (row[0] == &"" and not known) or (row[0] != &"" and planet == row[0]):
				definitions.append(definition)
		if definitions.is_empty():
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		_compendium_rows.add_child(line)
		var badge := PlanetBadge.new()
		badge.label = row[1]
		badge.theme_id = row[2]
		line.add_child(badge)
		var found: int = 0
		for definition in definitions:
			var owned := ArtifactManager.owns_artifact(definition.artifact_id)
			if owned:
				found += 1
			var card := ArtifactCard.new()
			card.setup(definition, false, false, not owned, true)
			if owned:
				card.pressed.connect(func() -> void:
					selected_artifact_id = definition.artifact_id
					set_tab(Tab.COLLECTION)
				)
			line.add_child(card)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(spacer)
		var count := _label("%d/%d" % [found, definitions.size()], 13, Palette.UI_MUTED)
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(count)


## Owned ids in the current sort: rarity (highest first, then oldest) or newest first.
func _sorted_owned() -> Array[StringName]:
	var ids := ArtifactManager.get_owned_artifact_ids()
	if sort_mode == Sort.NEWEST:
		ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return ArtifactManager.get_acquisition_index(a) > ArtifactManager.get_acquisition_index(b))
	else:
		ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			var ra: int = ArtifactVisual.rarity_index(ArtifactManager.get_definition(a))
			var rb: int = ArtifactVisual.rarity_index(ArtifactManager.get_definition(b))
			if ra != rb:
				return ra > rb
			return ArtifactManager.get_acquisition_index(a) < ArtifactManager.get_acquisition_index(b))
	return ids


func _on_artifact_data_changed() -> void:
	if visible:
		refresh()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if not _frame.get_global_rect().has_point(click.global_position):
			close_requested.emit()
			accept_event()


# ==========================================
# Small helpers
# ==========================================

func _style_tab(button: Button, active: bool) -> void:
	var style := Palette.make_panel_style(Palette.ACCENT if active else Color(0, 0, 0, 0), 9, 18.0, 6.0)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Palette.UI_PANEL if active else Palette.UI_MUTED)
	button.add_theme_color_override("font_hover_color", Palette.UI_PANEL if active else Palette.UI_TEXT)
	button.add_theme_color_override("font_pressed_color", Palette.UI_PANEL if active else Palette.UI_TEXT)


func _style_toggle(button: Button, active: bool) -> void:
	var style := Palette.make_panel_style(Palette.MECH if active else Color(0, 0, 0, 0), 8, 12.0, 4.0)
	style.set_border_width_all(1)
	style.border_color = Palette.MECH_LIGHT if active else Palette.MECH
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Palette.UI_TEXT if active else Palette.UI_MUTED)
	button.add_theme_color_override("font_hover_color", Palette.UI_TEXT)


func _chip(text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.UI_PANEL_RAISED, 11, 10.0, 3.0))
	var label := _label(text, 11, color)
	chip.add_child(label)
	return chip


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# ==========================================
# Inner controls
# ==========================================

## One artifact card: rarity diamond, equipped badge, icon, name.
## compact: Compendium cell (icon only).
class ArtifactCard:
	extends Button

	const Visual := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")
	var rarity: int = 0
	var equipped: bool = false
	var unknown: bool = false
	var compact: bool = false

	func setup(definition: MagicArtifactDefinition, selected: bool, is_equipped: bool, is_unknown: bool, is_compact: bool = false) -> void:
		rarity = Visual.rarity_index(definition)
		equipped = is_equipped
		unknown = is_unknown
		compact = is_compact
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_ARROW if unknown else Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(96.0, 96.0) if compact else Vector2(118.0, 148.0)
		var color: Color = Visual.rarity_color(rarity)
		var normal := Palette.make_panel_style(Color("17120F") if unknown else Palette.UI_PANEL_RAISED, 12)
		normal.set_border_width_all(2)
		normal.border_color = Palette.ACCENT if selected else (Palette.MECH if unknown else Color(color, 0.4))
		var hover := normal.duplicate() as StyleBoxFlat
		if not unknown:
			hover.border_color = Palette.ACCENT if selected else color
		add_theme_stylebox_override("normal", normal)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", hover)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var column := VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 4)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(column)
		var icon := Visual.IconView.new(66.0 if compact else 84.0)
		icon.artifact_id = definition.artifact_id
		icon.rarity = rarity
		icon.silhouette = unknown
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		if not compact:
			var name_label := Label.new()
			name_label.text = definition.display_name
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_label.custom_minimum_size = Vector2(104.0, 0.0)
			name_label.add_theme_font_size_override("font_size", 12)
			name_label.add_theme_color_override("font_color", Palette.UI_TEXT)
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(name_label)

	func _draw() -> void:
		var color: Color = Visual.rarity_color(rarity)
		# Rarity diamond (top-left; bottom-centre on compact cells).
		var at := Vector2(size.x * 0.5, size.y - 10.0) if compact else Vector2(13.0, 13.0)
		var diamond := PackedVector2Array([at + Vector2(0, -5), at + Vector2(5, 0), at + Vector2(0, 5), at + Vector2(-5, 0)])
		draw_colored_polygon(diamond, Color(color, 0.5 if unknown else 1.0))
		if equipped:
			var badge := Rect2(Vector2(size.x - 28.0, 6.0), Vector2(22.0, 22.0))
			draw_style_box(Palette.make_panel_style(Palette.ACCENT, 6), badge)
			Visual.draw_target_icon(self, badge.get_center(), 12.0, false, Palette.UI_PANEL)


## Icon + number chip for one effect stat.
class StatChip:
	extends PanelContainer

	const Visual := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")
	var kind: StringName = &""
	var text: String = ""

	func _ready() -> void:
		add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8, 10.0, 6.0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		add_child(row)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(16.0, 16.0)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.draw.connect(func() -> void: Visual.draw_stat_icon(icon, icon.size * 0.5, 15.0, kind, Palette.UI_MUTED))
		row.add_child(icon)
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Palette.UI_TEXT)
		row.add_child(label)


## Planet name with a little planet disc (Compendium rows).
class PlanetBadge:
	extends Control

	var label: String = ""
	var theme_id: StringName = &"rocky"

	func _init() -> void:
		custom_minimum_size = Vector2(118.0, 96.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var colors := Palette.planet(theme_id)
		var center := Vector2(14.0, size.y * 0.5)
		draw_circle(center, 13.0, colors["ground"])
		draw_circle(center + Vector2(3.0, 3.0), 9.0, Color(0, 0, 0, 0.18))
		draw_circle(center + Vector2(-4.0, -4.0), 4.0, colors["ground_light"])
		var font := get_theme_default_font()
		draw_string(font, Vector2(34.0, size.y * 0.5 + 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.UI_MUTED)


## Thin cyan progress strip (Compendium completion).
class ProgressStrip:
	extends Control

	var ratio: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(180.0, 8.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_style_box(Palette.make_panel_style(Palette.UI_PANEL_RAISED, 4), Rect2(Vector2.ZERO, size))
		if ratio > 0.0:
			draw_style_box(Palette.make_panel_style(Color("5FE6EE"), 4), Rect2(Vector2.ZERO, Vector2(size.x * clampf(ratio, 0.0, 1.0), size.y)))


## Small round stone with a glowing rune (panel title badge).
class RuneBadge:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(30.0, 30.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 13.0, Color("3E3128"))
		draw_circle(c, 10.0, Color("6E5D4F"))
		draw_polyline(PackedVector2Array([c + Vector2(-4, -6), c + Vector2(0, 6), c + Vector2(4, -6)]), Color("5FE6EE"), 2.2)
