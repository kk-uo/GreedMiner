class_name ArtifactTutorialHint
extends Control

## First-artifact prompt shown at the base (presentation): a caption card in
## the tutorial style - the new artifact's icon glowing in a rune badge, a
## friendly line about the Magic Stall waking up, a TAKE ME THERE button -
## and the guide arrow bobbing over the Magic Stall (whose rune circle the
## hangar already highlights). Non-modal. `skip_requested` is kept for
## compatibility but there is no skip button any more (user request).

signal open_requested
signal skip_requested

const ARTIFACT_VISUAL := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")
const GUIDE_ARROW := preload("res://Scripts/UI/GuideArrow.gd")
const RUNE := Color("7FE0E6")

## BaseMain, for the arrow over the Magic Stall (optional).
var base: Node = null

var _time: float = 0.0
var _panel: PanelContainer
var _badge: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := Palette.make_panel_style(Color(Palette.UI_PANEL, 0.96), 12, 18.0, 12.0)
	style.border_width_top = 3
	style.border_color = RUNE
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = 24.0
	_panel.offset_right = 24.0 + 470.0
	_panel.offset_bottom = -24.0
	_panel.offset_top = -24.0
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_panel.add_child(row)
	_badge = Control.new()
	_badge.custom_minimum_size = Vector2(64.0, 64.0)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.draw.connect(_draw_badge)
	row.add_child(_badge)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	row.add_child(column)
	column.add_child(_label(tr("THE MAGIC STALL HAS WOKEN UP"), 16, RUNE.lightened(0.3)))
	var body := _label(tr("Something you brought back is humming with old magic. Take it to the Magic Stall and see what it can do."), 12, Palette.UI_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(280.0, 0.0)
	column.add_child(body)
	var go := Button.new()
	go.text = "TAKE ME THERE"
	go.focus_mode = Control.FOCUS_NONE
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size = Vector2(0.0, 34.0)
	go.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	go.add_theme_font_size_override("font_size", 12)
	for state in ["normal", "hover", "pressed"]:
		go.add_theme_stylebox_override(state, Palette.make_panel_style(RUNE.lightened(0.15) if state == "hover" else RUNE, 8, 12.0, 4.0))
	go.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		go.add_theme_color_override(color_name, Palette.UI_PANEL)
	go.pressed.connect(func() -> void: open_requested.emit())
	row.add_child(go)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _process(delta: float) -> void:
	_time += delta
	_badge.queue_redraw()
	queue_redraw()


## The first artifact's icon in a slowly turning rune circle.
func _draw_badge() -> void:
	var c := _badge.size * 0.5
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	_badge.draw_circle(c, 30.0, Color(RUNE, 0.1 + 0.08 * pulse))
	_badge.draw_arc(c, 29.0, 0.0, TAU, 40, Color(RUNE, 0.55), 1.6)
	for k in range(6):
		var a := _time * 0.5 + TAU * float(k) / 6.0
		var p := c + Vector2.RIGHT.rotated(a) * 29.0
		_badge.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3), p + Vector2(3, 0), p + Vector2(0, 3), p + Vector2(-3, 0)]), RUNE)
	var id: StringName = ArtifactManager.first_artifact_id
	var definition: MagicArtifactDefinition = ArtifactManager.get_definition(id) if not id.is_empty() else null
	ARTIFACT_VISUAL.draw_icon(_badge, c + Vector2(0, sin(_time * 2.0) * 1.5), 40.0, id, ARTIFACT_VISUAL.rarity_index(definition))


## Bobbing arrow over the Magic Stall while the base overview is shown.
func _draw() -> void:
	if base == null or not is_instance_valid(base) or not _panel.visible:
		return
	if base.has_method("get_view_state_name") and base.call("get_view_state_name") != &"OVERVIEW":
		return
	var hangar := base.get("hangar") as Node
	if hangar == null:
		return
	var world: Vector2 = hangar.call("get_hotspot_center", AsteroidHangar.HOTSPOT_MAGIC_STALL)
	var canvas := get_viewport().get_canvas_transform()
	var screen := canvas * world
	var radius := 110.0 * canvas.get_scale().x
	var local := get_global_transform_with_canvas().affine_inverse() * (screen - Vector2(0, radius))
	var bob := sin(_time * 5.0) * 7.0
	GUIDE_ARROW.draw(self, local - Vector2(0, 8.0 + bob), Vector2.DOWN, 0.5 + 0.5 * sin(_time * 4.0))
