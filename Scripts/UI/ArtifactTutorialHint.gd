class_name ArtifactTutorialHint
extends Control

## Non-modal, skippable first-artifact prompt shown only after returning to base.

signal open_requested
signal skip_requested


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 24.0
	panel.offset_top = -150.0
	panel.offset_right = 500.0
	panel.offset_bottom = -24.0
	panel.add_theme_stylebox_override("panel", Palette.make_panel_style(Color(Palette.UI_PANEL, 0.96), 10, 16.0, 12.0))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var title := Label.new()
	title.text = "↓  MAGIC STALL AWAKENED"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Palette.ACCENT_LIGHT)
	column.add_child(title)
	var body := Label.new()
	body.text = "A mysterious power has awakened the Magic Stall in the base. Visit it to see your first artifact."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Palette.UI_TEXT)
	column.add_child(body)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var open := Button.new()
	open.text = "OPEN MAGIC STALL"
	open.pressed.connect(func() -> void: open_requested.emit())
	actions.add_child(open)
	var skip := Button.new()
	skip.text = "SKIP"
	skip.pressed.connect(func() -> void: skip_requested.emit())
	actions.add_child(skip)

