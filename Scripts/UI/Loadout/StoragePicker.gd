extends PanelContainer

## Hangar storage picker: a big square panel on the left of the screen with a
## grid of small cells, one per artifact or chip that can go into the slot the
## player clicked (ship artifact slot, module artifact socket or chip socket).
## Hovering a cell shows its name and effect in the strip at the bottom;
## clicking a cell does its action right away (INSTALL / MOVE / EQUIP /
## REMOVE). Blocked cells stay visible but greyed out so the reason is clear.
##
## LoadoutPanel owns one instance as its child and keeps it pinned to the left
## edge of the screen (see pin_left), so it fades and hides with the panel.
## Load with preload(); no class_name on purpose.

signal close_requested

const ArtifactVisual := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")
const ChipVisual := preload("res://Scripts/UI/Chips/ChipVisual.gd")

const COLUMNS: int = 5
const CELL: float = 74.0
const GAP: float = 8.0
const PADDING: float = 18.0
const PANEL_WIDTH: float = COLUMNS * CELL + (COLUMNS - 1) * GAP + PADDING * 2.0
## Grid rows shown before it scrolls (the panel grows with its content).
const MIN_ROWS: int = 2
const MAX_ROWS: int = 4
const SCREEN_MARGIN: float = 24.0

var _title: Label
var _subtitle: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _info_name: Label
var _info_detail: Label
var _info_note: Label
var _info_icon: CellIcon
var _entries: Array = []


func _init() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := Palette.make_panel_style(Palette.UI_PANEL, 14, PADDING, 16.0)
	style.border_width_top = 3
	style.border_color = Palette.ACCENT
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 14
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	_title = _label("", 18, Palette.UI_TEXT)
	titles.add_child(_title)
	_subtitle = _label("", 11, Palette.UI_MUTED)
	titles.add_child(_subtitle)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_color_override("font_color", Palette.UI_MUTED)
	close.add_theme_color_override("font_hover_color", Palette.UI_TEXT)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_scroll.add_child(_grid)

	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.UI_PANEL_RAISED, 10, 12.0, 10.0))
	info.custom_minimum_size = Vector2(0.0, 76.0)
	column.add_child(info)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	info.add_child(info_row)
	_info_icon = CellIcon.new()
	_info_icon.custom_minimum_size = Vector2(52.0, 52.0)
	_info_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_row.add_child(_info_icon)
	var info_text := VBoxContainer.new()
	info_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_text.alignment = BoxContainer.ALIGNMENT_CENTER
	info_text.add_theme_constant_override("separation", 1)
	info_row.add_child(info_text)
	_info_name = _label("", 14, Palette.UI_TEXT)
	info_text.add_child(_info_name)
	_info_detail = _label("", 12, Palette.ACCENT)
	_info_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Fixed width so wrapped text never makes the panel tall and thin.
	_info_detail.custom_minimum_size = Vector2(PANEL_WIDTH - PADDING * 2.0 - 24.0 - 52.0 - 12.0, 0.0)
	info_text.add_child(_info_detail)
	_info_note = _label("", 10, Palette.UI_MUTED)
	_info_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_note.custom_minimum_size = Vector2(PANEL_WIDTH - PADDING * 2.0 - 24.0 - 52.0 - 12.0, 0.0)
	info_text.add_child(_info_note)


## Keeps the panel on the left edge of the screen, vertically centred, while
## its parent (the Loadout panel on the right) slides in and out.
func pin_left(viewport_height: float) -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var parent_origin: Vector2 = parent_control.position
	position = Vector2(SCREEN_MARGIN - parent_origin.x, (viewport_height - size.y) * 0.5 - parent_origin.y)


## entries: Array of Dictionaries:
##   kind: &"artifact" | &"chip" | &"remove"
##   id: artifact_id / chip_id (for remove: the item being removed, may be empty)
##   rarity: int (artifacts)          badge: String (top-right, e.g. "×2")
##   tag: String (bottom, e.g. "R1·C2", "IN USE")
##   name / detail / note: Strings for the info strip
##   action: String ("INSTALL", "MOVE", "EQUIP", "REMOVE", "BLOCKED")
##   enabled: bool                   callback: Callable
func show_entries(title: String, subtitle: String, entries: Array, empty_text: String) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_entries = entries
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for entry in entries:
		var cell := StorageCell.new()
		cell.setup(entry)
		cell.hovered_entry.connect(_show_info)
		_grid.add_child(cell)
	var rows: int = clampi(ceili(float(entries.size()) / float(COLUMNS)), MIN_ROWS, MAX_ROWS)
	_scroll.custom_minimum_size = Vector2(0.0, rows * CELL + (rows - 1) * GAP)
	if entries.is_empty():
		_show_info({"kind": &"", "name": "NOTHING HERE YET", "detail": "", "note": empty_text})
	else:
		# Prefer the first item that can actually be used.
		var first: Dictionary = entries[0]
		for entry in entries:
			if bool(entry.get("enabled", true)) and entry.get("kind") != &"remove":
				first = entry
				break
		_show_info(first)


## Cells of the open picker (exposed for tests).
func get_cells() -> Array[Node]:
	return _grid.get_children()


func _show_info(entry: Dictionary) -> void:
	_info_icon.entry = entry
	_info_icon.queue_redraw()
	_info_icon.visible = entry.get("kind", &"") != &""
	_info_name.text = String(entry.get("name", ""))
	_info_detail.text = String(entry.get("detail", ""))
	_info_detail.visible = not _info_detail.text.is_empty()
	var note := String(entry.get("note", ""))
	var action := String(entry.get("action", ""))
	if not action.is_empty() and bool(entry.get("enabled", true)):
		note = ("CLICK TO %s" % action) + ("  ·  " + note if not note.is_empty() else "")
	_info_note.text = note
	_info_note.visible = not note.is_empty()
	# Grow or shrink with the content (rows, wrapped info text).
	reset_size.call_deferred()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## One square cell in the grid.
class StorageCell extends Button:
	signal hovered_entry(entry: Dictionary)

	var entry: Dictionary = {}
	## Item id (chip type or artifact id) and the action, for tests.
	var chip_id: StringName = &""
	var item_id: StringName = &""
	var action: String = ""

	func setup(data: Dictionary) -> void:
		entry = data
		item_id = data.get("id", &"")
		chip_id = item_id if data.get("kind", &"") == &"chip" else &""
		action = String(data.get("action", ""))
		custom_minimum_size = Vector2(CELL, CELL)
		focus_mode = Control.FOCUS_NONE
		flat = true
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		disabled = not bool(data.get("enabled", true))
		mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void:
			hovered_entry.emit(entry)
			queue_redraw()
		)
		mouse_exited.connect(queue_redraw)
		pressed.connect(activate)

	## Does the cell's action (same as clicking it).
	func activate() -> void:
		if disabled:
			return
		var callback: Callable = entry.get("callback", Callable())
		if callback.is_valid():
			callback.call()

	func _draw() -> void:
		var rect := Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0))
		var font := get_theme_default_font()
		var kind: StringName = entry.get("kind", &"")
		var accent := Palette.MECH
		if kind == &"artifact":
			accent = ArtifactVisual.rarity_color(int(entry.get("rarity", 0)))
		elif kind == &"chip":
			accent = ChipVisual.get_color(entry.get("id", &""))
		var hovered := is_hovered() and not disabled
		var outline := Palette.rounded_rect_points(rect, 10.0, 3)
		outline.append(outline[0])
		if kind == &"remove":
			Palette.draw_rounded_rect(self, rect, 10.0, Color("17120F"))
			for index in range(outline.size() - 1):
				draw_dashed_line(outline[index], outline[index + 1], Palette.ACCENT if hovered else Palette.MECH_LIGHT, 1.5, 5.0)
		else:
			Palette.draw_rounded_rect(self, rect, 10.0, Palette.UI_PANEL_RAISED.lightened(0.06) if hovered else Palette.UI_PANEL_RAISED)
			draw_polyline(outline, Palette.ACCENT if hovered else Color(accent, 0.55 if not disabled else 0.2), 2.0 if hovered else 1.5)
		var alpha := 0.35 if disabled else 1.0
		StoragePickerDraw.icon(self, entry, Vector2(size.x * 0.5, size.y * 0.44), CELL * 0.62, alpha)
		var badge := String(entry.get("badge", ""))
		if not badge.is_empty():
			draw_string(font, Vector2(0.0, 15.0), badge, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 7.0, 11, Palette.UI_TEXT if not disabled else Palette.UI_MUTED)
		var tag := String(entry.get("tag", ""))
		if not tag.is_empty():
			var tag_color := Palette.UI_MUTED if disabled else (Palette.ACCENT if kind != &"remove" else Palette.UI_MUTED)
			draw_string(font, Vector2(0.0, size.y - 7.0), tag, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, tag_color)


## Big icon in the info strip.
class CellIcon extends Control:
	var entry: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		StoragePickerDraw.icon(self, entry, size * 0.5, minf(size.x, size.y) * 0.9, 1.0)


## Inner classes cannot call the outer script's static functions directly by
## name, so the shared icon drawing lives here.
class StoragePickerDraw:
	const Visual := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")
	const Chips := preload("res://Scripts/UI/Chips/ChipVisual.gd")

	static func icon(canvas: CanvasItem, entry: Dictionary, center: Vector2, side: float, alpha: float) -> void:
		match entry.get("kind", &""):
			&"artifact":
				Visual.draw_icon(canvas, center, side, entry.get("id", &""), int(entry.get("rarity", 0)))
			&"chip":
				Chips.draw_chip(canvas, entry.get("id", &""), center, side * 0.8, alpha, alpha >= 1.0)
			&"remove":
				var r := side * 0.26
				canvas.draw_line(center + Vector2(-r, -r), center + Vector2(r, r), Palette.UI_MUTED, 3.0)
				canvas.draw_line(center + Vector2(-r, r), center + Vector2(r, -r), Palette.UI_MUTED, 3.0)
