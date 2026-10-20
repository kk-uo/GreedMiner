extends Control

## Warehouse (design A): a centred modal opened from the dwarven vault door
## in the asteroid's bottom-right wall (AsteroidHangar.HOTSPOT_WAREHOUSE).
##
## Tabs ALL / RESOURCES / CHIPS. Items sit in a compact grid separated by thin
## divider lines; chips carry an orange tag with the turret they are installed
## on (R·C) or IDLE. The right-hand card shows the selected item; idle chips can
## be scrapped for a partial Ore refund (ChipManager.scrap_chip).
## Presentation only: every number comes from ResourceManager / ChipManager.
## Load with preload(); no class_name on purpose.

signal close_requested

const ChipVisual := preload("res://Scripts/UI/Chips/ChipVisual.gd")
const ScrollKeeper := preload("res://Scripts/UI/ScrollKeeper.gd")

const PANEL_SIZE := Vector2(780.0, 480.0)
const DETAIL_WIDTH: float = 220.0

enum Tab { ALL, RESOURCES, CHIPS }

var current_tab: Tab = Tab.ALL
## Selected item: {"kind": &"resource"|&"chip", "id": StringName}.
var selected: Dictionary = {}
var scrap_button: Button
var grid: ItemGrid

var _frame: PanelContainer
var _tab_buttons: Array[Button] = []
var _detail: VBoxContainer
var _scrap_armed: bool = false
var _open_tween: Tween
## Tab the grid was last built for (scroll is kept while it stays the same).
var _last_built_tab: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	ChipManager.chip_inventory_changed.connect(_on_data_changed.unbind(2))
	ChipManager.chip_equipment_changed.connect(_on_data_changed.unbind(2))
	ChipManager.chip_instance_changed.connect(_on_data_changed.unbind(1))
	ResourceManager.stored_ore_changed.connect(_on_data_changed.unbind(1))
	hide()


func open_panel() -> void:
	show()
	_scrap_armed = false
	refresh()
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	modulate.a = 0.0
	_frame.pivot_offset = _frame.size * 0.5
	_frame.scale = Vector2.ONE * 0.96
	_open_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_open_tween.tween_property(_frame, "scale", Vector2.ONE, 0.2)


func close_panel() -> void:
	hide()


func select_tab(tab: Tab) -> void:
	current_tab = tab
	refresh()


func select_item(kind: StringName, id: StringName) -> void:
	selected = {"kind": kind, "id": id}
	_scrap_armed = false
	grid.selected = selected
	grid.queue_redraw()
	_build_detail()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if not _frame.get_global_rect().has_point((event as InputEventMouseButton).global_position):
			close_requested.emit()
			accept_event()


# ==========================================
# Layout
# ==========================================

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_frame = PanelContainer.new()
	var style := Palette.make_panel_style(Color(Palette.UI_PANEL, 0.98), 14, 18.0, 16.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0.0, 10.0)
	_frame.add_theme_stylebox_override("panel", style)
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.custom_minimum_size = PANEL_SIZE
	_frame.offset_left = -PANEL_SIZE.x * 0.5
	_frame.offset_right = PANEL_SIZE.x * 0.5
	_frame.offset_top = -PANEL_SIZE.y * 0.5
	_frame.offset_bottom = PANEL_SIZE.y * 0.5
	add_child(_frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_frame.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var crate := CrateIcon.new()
	crate.custom_minimum_size = Vector2(30.0, 30.0)
	header.add_child(crate)
	var title := _label("WAREHOUSE", 20, Palette.UI_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_font_size_override("font_size", 18)
	close.add_theme_color_override("font_color", Palette.UI_MUTED)
	close.add_theme_color_override("font_hover_color", Palette.UI_TEXT)
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	for tab in [Tab.ALL, Tab.RESOURCES, Tab.CHIPS]:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0.0, 30.0)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(select_tab.bind(tab))
		tabs.add_child(button)
		_tab_buttons.append(button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	grid = ItemGrid.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.item_pressed.connect(select_item)
	scroll.add_child(grid)
	var note := _label("Orange tag = installed on that turret (R·C). Install / remove chips in the Hangar; idle chips can be scrapped.", 10, Palette.UI_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(note)

	var detail_card := PanelContainer.new()
	detail_card.custom_minimum_size = Vector2(DETAIL_WIDTH, 0.0)
	detail_card.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.UI_PANEL_RAISED, 10, 14.0, 14.0))
	body.add_child(detail_card)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	detail_card.add_child(_detail)


func refresh() -> void:
	if grid == null:
		return
	var kept: Array = ScrollKeeper.capture(self) if int(current_tab) == _last_built_tab else []
	_last_built_tab = int(current_tab)
	var chip_count := ChipManager.get_owned_instances().size()
	var names := ["ALL", "RESOURCES", "CHIPS  %d" % chip_count]
	for index in range(_tab_buttons.size()):
		var button := _tab_buttons[index]
		button.text = names[index]
		var active := index == int(current_tab)
		for state in ["normal", "hover", "pressed"]:
			var color := Palette.ACCENT if active else Palette.UI_PANEL_RAISED
			if state == "hover" and not active:
				color = Palette.MECH
			button.add_theme_stylebox_override(state, Palette.make_panel_style(color, 7, 14.0, 4.0))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(color_name, Palette.UI_PANEL if active else Palette.UI_MUTED)

	var sections: Array[Dictionary] = []
	if current_tab != Tab.CHIPS:
		sections.append({"title": "RESOURCES", "items": [
			{"kind": &"resource", "id": &"ore"},
		]})
	if current_tab != Tab.RESOURCES:
		var items: Array = []
		for instance_id in _sorted_chip_instances():
			items.append({"kind": &"chip", "id": instance_id})
		sections.append({"title": "CHIPS", "items": items})
	grid.set_sections(sections)

	if not _item_exists(selected):
		selected = {}
		for section in sections:
			if not (section["items"] as Array).is_empty():
				selected = (section["items"] as Array)[0]
				break
	grid.selected = selected
	grid.queue_redraw()
	_build_detail()
	ScrollKeeper.restore(self, kept)


func _sorted_chip_instances() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition in ChipManager.configuration.chips:
		if definition == null:
			continue
		for instance_id in ChipManager.get_owned_instances(definition.chip_id):
			result.append(instance_id)
	return result


func _item_exists(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if item["kind"] == &"chip":
		return current_tab != Tab.RESOURCES and not ChipManager.get_chip_instance(item["id"]).is_empty()
	return current_tab != Tab.CHIPS


# ==========================================
# Detail card
# ==========================================

func _build_detail() -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	scrap_button = null
	if selected.is_empty():
		var empty := _label("No chips yet.\nCraft them in the Laboratory (Chip Lab).", 12, Palette.UI_MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_detail.add_child(empty)
		return
	if selected["kind"] == &"resource":
		_build_resource_detail(selected["id"])
	else:
		_build_chip_detail(selected["id"])


func _build_resource_detail(id: StringName) -> void:
	var icon := ResourceIcon.new()
	icon.resource_id = id
	icon.custom_minimum_size = Vector2(0.0, 76.0)
	_detail.add_child(icon)
	_detail.add_child(_centered(_label("ORE", 16, Palette.UI_TEXT)))
	_detail.add_child(_centered(_label(_thousands(floori(ResourceManager.stored_ore)), 26, Palette.GOLD)))
	var text := "Banked from expeditions. Spent on research, chip crafting and locating new planets."
	var description := _centered(_label(text, 11, Palette.UI_MUTED))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(description)


func _build_chip_detail(instance_id: StringName) -> void:
	var chip_id := ChipManager.get_instance_chip_type(instance_id)
	var icon := ChipVisual.ChipIcon.new(chip_id, 76.0, true)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail.add_child(icon)
	_detail.add_child(_centered(_label(ChipVisual.get_display_name(chip_id), 14, Palette.UI_TEXT)))
	var quality := ChipManager.get_instance_quality(instance_id)
	_detail.add_child(_centered(_label("%s  ·  %s" % [
		ChipVisual.get_effect_text(chip_id),
		(quality.display_name if quality != null else "Basic").to_upper(),
	], 11, ChipVisual.get_color(chip_id))))
	var location := ChipManager.get_instance_location(instance_id)
	var installed := location.x >= 0
	var where := "Idle  ·  not installed"
	if installed:
		var weapon := ModuleCatalog.get_entry(ChipManager.get_turret_weapon_type(location))
		where = "Installed on %s\n%s  ·  socket %d" % [
			String(weapon.get("name", "turret")).to_upper(),
			ChipVisual.cell_label(location),
			ChipManager.get_instance_slot_index(instance_id) + 1,
		]
	var where_label := _centered(_label(where, 11, Palette.ACCENT if installed else Palette.UI_MUTED))
	where_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(where_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(spacer)

	scrap_button = Button.new()
	scrap_button.custom_minimum_size = Vector2(0.0, 38.0)
	scrap_button.focus_mode = Control.FOCUS_NONE
	scrap_button.add_theme_font_size_override("font_size", 12)
	var refund := ChipManager.get_scrap_refund(instance_id)
	if installed:
		scrap_button.text = "INSTALLED  ·  CAN'T SCRAP"
		scrap_button.disabled = true
		_style_scrap(Color("352D27"), Palette.UI_MUTED)
	else:
		scrap_button.text = ("CONFIRM?  + ◆ %s" if _scrap_armed else "SCRAP  ·  + ◆ %s") % _thousands(refund)
		scrap_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_scrap(Color("8A2E22") if _scrap_armed else Color("5A2A22"), Color("FFB3A6"))
		scrap_button.pressed.connect(_on_scrap_pressed.bind(instance_id))
	_detail.add_child(scrap_button)
	var hint := _centered(_label(
		"Remove it in the Hangar first." if installed else "Refunds 50% of the ore spent on it.",
		9, Palette.UI_MUTED
	))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(hint)


func _style_scrap(color: Color, text_color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		scrap_button.add_theme_stylebox_override(state, Palette.make_panel_style(color.lightened(0.08) if state == "hover" else color, 8, 10.0, 4.0))
	scrap_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		scrap_button.add_theme_color_override(color_name, text_color)


## Two-step scrap: the first click arms the button, the second confirms.
func _on_scrap_pressed(instance_id: StringName) -> void:
	if not _scrap_armed:
		_scrap_armed = true
		_build_detail()
		return
	_scrap_armed = false
	if ChipManager.scrap_chip(instance_id) >= 0:
		selected = {}
		refresh()


func _on_data_changed() -> void:
	if visible:
		refresh()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


# ==========================================
# Widgets
# ==========================================

## Compact item grid: sections of small tiles separated by thin divider lines.
class ItemGrid:
	extends Control

	const ChipVisual := preload("res://Scripts/UI/Chips/ChipVisual.gd")
	const CELL := Vector2(70.0, 76.0)
	const TITLE_HEIGHT: float = 22.0
	const SECTION_GAP: float = 12.0

	signal item_pressed(kind: StringName, id: StringName)

	var selected: Dictionary = {}
	var _sections: Array[Dictionary] = []
	## [{"rect": Rect2, "item": Dictionary}] rebuilt on layout.
	var _hit: Array[Dictionary] = []
	var _hover := -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(_layout)

	func set_sections(sections: Array[Dictionary]) -> void:
		_sections = sections
		_layout()

	func columns() -> int:
		return maxi(int(floor((size.x - 2.0) / CELL.x)), 1)

	## Tile rect of the item with this id (tests click through it).
	func get_item_rect(id: StringName) -> Rect2:
		for entry in _hit:
			if (entry["item"] as Dictionary)["id"] == id:
				return entry["rect"]
		return Rect2()

	func _layout() -> void:
		_hit.clear()
		var y := 0.0
		var cols := columns()
		for section in _sections:
			var items: Array = section["items"]
			y += TITLE_HEIGHT
			var rows := maxi(int(ceil(float(items.size()) / float(cols))), 1)
			for index in range(items.size()):
				var cell := Vector2(float(index % cols) * CELL.x, y + float(index / cols) * CELL.y)
				_hit.append({"rect": Rect2(cell, CELL), "item": items[index]})
			y += float(rows) * CELL.y + SECTION_GAP
		custom_minimum_size = Vector2(0.0, y)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var hovered := _index_at((event as InputEventMouseMotion).position)
			if hovered != _hover:
				_hover = hovered
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered >= 0 else Control.CURSOR_ARROW
				queue_redraw()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var index := _index_at((event as InputEventMouseButton).position)
			if index >= 0:
				var item: Dictionary = _hit[index]["item"]
				item_pressed.emit(item["kind"], item["id"])
				accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and _hover >= 0:
			_hover = -1
			queue_redraw()

	func _index_at(point: Vector2) -> int:
		for index in range(_hit.size()):
			if (_hit[index]["rect"] as Rect2).has_point(point):
				return index
		return -1

	func _draw() -> void:
		var font := get_theme_default_font()
		var cols := columns()
		var y := 0.0
		var hit_index := 0
		for section in _sections:
			var items: Array = section["items"]
			draw_string(font, Vector2(0.0, y + 14.0), "%s  ·  %d" % [section["title"], items.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.UI_MUTED)
			y += TITLE_HEIGHT
			var rows := maxi(int(ceil(float(items.size()) / float(cols))), 1)
			var box := Rect2(0.0, y, float(cols) * CELL.x, float(rows) * CELL.y)
			Palette.draw_rounded_rect(self, box, 8.0, Color("1A1512"))
			if items.is_empty():
				draw_string(font, Vector2(14.0, y + CELL.y * 0.5 + 4.0), "Nothing here yet  ·  craft chips in the Laboratory", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.UI_MUTED)
			for index in range(items.size()):
				var entry: Dictionary = _hit[hit_index]
				var rect: Rect2 = entry["rect"]
				var item: Dictionary = entry["item"]
				var is_selected: bool = not selected.is_empty() and selected["id"] == item["id"]
				if is_selected or hit_index == _hover:
					Palette.draw_rounded_rect(self, rect.grow(-3.0), 6.0, Palette.MECH if is_selected else Palette.UI_PANEL_RAISED)
				_draw_item(item, rect, font)
				if is_selected:
					var outline := Palette.rounded_rect_points(rect.grow(-3.0), 6.0)
					outline.append(outline[0])
					draw_polyline(outline, Palette.ACCENT, 2.0)
				hit_index += 1
			# Divider lines between cells.
			var line := Color(Palette.MECH, 0.9)
			for r in range(rows):
				# Vertical dividers only up to the last filled cell of each row.
				var in_row := mini(cols, items.size() - r * cols)
				for c in range(1, mini(in_row + 1, cols)):
					draw_line(Vector2(float(c) * CELL.x, y + float(r) * CELL.y + 6.0), Vector2(float(c) * CELL.x, y + float(r + 1) * CELL.y - 6.0), line, 1.0)
			for r in range(1, rows):
				draw_line(Vector2(6.0, y + float(r) * CELL.y), Vector2(box.size.x - 6.0, y + float(r) * CELL.y), line, 1.0)
			var border := Palette.rounded_rect_points(box, 8.0)
			border.append(border[0])
			draw_polyline(border, Palette.MECH, 1.0)
			y += box.size.y + SECTION_GAP

	func _draw_item(item: Dictionary, rect: Rect2, font: Font) -> void:
		var icon_center := rect.position + Vector2(rect.size.x * 0.5, 28.0)
		var tag_rect := Rect2(rect.position + Vector2(7.0, rect.size.y - 22.0), Vector2(rect.size.x - 14.0, 14.0))
		if item["kind"] == &"chip":
			var instance_id: StringName = item["id"]
			ChipVisual.draw_chip(self, ChipManager.get_instance_chip_type(instance_id), icon_center, 30.0)
			var location := ChipManager.get_instance_location(instance_id)
			if location.x >= 0:
				Palette.draw_rounded_rect(self, tag_rect, 4.0, Color("3B2A1A"))
				draw_string(font, tag_rect.position + Vector2(0.0, 11.0), ChipVisual.cell_label(location), HORIZONTAL_ALIGNMENT_CENTER, tag_rect.size.x, 9, Palette.ACCENT)
			else:
				draw_string(font, tag_rect.position + Vector2(0.0, 11.0), "IDLE", HORIZONTAL_ALIGNMENT_CENTER, tag_rect.size.x, 9, Palette.UI_MUTED)
		else:
			ChipVisual.draw_ore(self, icon_center, 28.0)
			var amount := WarehouseText.short_number(floori(ResourceManager.stored_ore))
			draw_string(font, tag_rect.position + Vector2(0.0, 11.0), amount, HORIZONTAL_ALIGNMENT_CENTER, tag_rect.size.x, 11, Palette.GOLD)


class WarehouseText:
	static func short_number(value: int) -> String:
		if value >= 1000000:
			return "%.1fM" % (float(value) / 1000000.0)
		if value >= 10000:
			return "%.1fK" % (float(value) / 1000.0)
		return str(value)


class ResourceIcon:
	extends Control

	const ChipVisual := preload("res://Scripts/UI/Chips/ChipVisual.gd")

	var resource_id: StringName = &"ore"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 32.0, Color(Palette.GOLD if resource_id == &"ore" else Palette.ACCENT, 0.16))
		if resource_id == &"ore":
			ChipVisual.draw_ore(self, center, 52.0)
		else:
			ChipVisual.draw_bolt(self, center, 52.0)


class CrateIcon:
	extends Control

	const ChipVisual := preload("res://Scripts/UI/Chips/ChipVisual.gd")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		ChipVisual.draw_crate(self, size * 0.5, minf(size.x, size.y))
