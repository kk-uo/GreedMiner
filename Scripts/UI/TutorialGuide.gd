extends Control

## First-time base tutorial (presentation + a tiny saved flag).
##
## Steps, each with a bouncing arrow on its target and a caption bar at the
## bottom explaining what to do and what the module is for:
##   1. OPEN THE HANGAR  — arrow on the landing pad (base overview).
##   2. INSTALL A WEAPON — arrow on the Machine Gun card (loadout list).
##   3. INSTALL MINING   — arrow on the Mining card.
##   4. POWER            — arrow on the loadout's POWER bar; GOT IT moves on.
##   5. LAUNCH           — arrow on the Star Map once back in the overview.
## Progress follows the real loadout (ShipLoadout), so dragging, the "+"
## button or the detail page all count. The tutorial only starts for a fresh
## ship (no weapon and no mining module installed) and is saved as done in
## ProgressionStore section "tutorial". Load with preload(); no class_name.

const SAVE_SECTION: StringName = &"tutorial"

enum Step { OPEN_HANGAR, INSTALL_WEAPON, INSTALL_MINING, POWER, LAUNCH, DONE }
const STEP_COUNT: int = 5

const TEXT := {
	Step.OPEN_HANGAR: ["OPEN THE HANGAR", "Click your ship on the landing pad to start building it."],
	Step.INSTALL_WEAPON: ["INSTALL A WEAPON", "Weapons fire at enemies that approach the ship. Drag the MACHINE GUN onto an empty slot, or select a slot and press +."],
	Step.INSTALL_MINING: ["INSTALL A MINING MODULE", "Mining modules drill ore during expeditions. Ore pays for research, chips and locating new planets. Drag MINING onto an empty slot."],
	Step.POWER: ["POWER", "Every module uses Power (the bolt number on its card); the bar shows used / total. Your Energy Module gives 4. Research ENERGY in the Laboratory for more Power and more turrets."],
	Step.LAUNCH: ["READY FOR LAUNCH", "Go back to the base (ESC) and open the STAR MAP to choose a planet. Protect the ship, mine ore, then evacuate to bank it."],
}

var base: Node = null
var step: Step = Step.DONE

var _time: float = 0.0
var _caption: PanelContainer
var _title: Label
var _body: Label
var _counter: Label
var _got_it: Button
## Arrow target in this control's coordinates; NaN-free flag via _has_target.
var _target := Vector2.ZERO
var _target_radius: float = 0.0
var _has_target: bool = false
## Which way the arrow points at the target (unit vector from arrow to target).
var _arrow_dir := Vector2.DOWN


## Starts the guide when this is a fresh game; otherwise frees itself.
static func should_run() -> bool:
	if bool(ProgressionStore.get_section(SAVE_SECTION).get("done", false)):
		return false
	return not _has_weapon() and not _has_mining()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_caption()
	step = Step.OPEN_HANGAR
	_refresh_text()


func _build_caption() -> void:
	_caption = PanelContainer.new()
	var style := Palette.make_panel_style(Color(Palette.UI_PANEL, 0.96), 12, 18.0, 12.0)
	style.border_width_top = 3
	style.border_color = Palette.ACCENT
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	style.shadow_size = 10
	_caption.add_theme_stylebox_override("panel", style)
	_caption.mouse_filter = Control.MOUSE_FILTER_STOP
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption.custom_minimum_size = Vector2(560.0, 0.0)
	_caption.offset_left = -280.0
	_caption.offset_right = 280.0
	_caption.offset_bottom = -22.0
	add_child(_caption)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_caption.add_child(row)
	_counter = _label("1/4", 13, Palette.UI_PANEL)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.ACCENT, 8, 9.0, 5.0))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(_counter)
	row.add_child(badge)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)
	_title = _label("", 16, Palette.UI_TEXT)
	column.add_child(_title)
	_body = _label("", 12, Palette.UI_MUTED)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(420.0, 0.0)
	column.add_child(_body)
	_got_it = Button.new()
	_got_it.text = "GOT IT"
	_got_it.focus_mode = Control.FOCUS_NONE
	_got_it.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_got_it.custom_minimum_size = Vector2(84.0, 32.0)
	_got_it.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_got_it.add_theme_font_size_override("font_size", 12)
	for state in ["normal", "hover", "pressed"]:
		var got_style := Palette.make_panel_style(Palette.ACCENT.lightened(0.1) if state == "hover" else Palette.ACCENT, 8, 12.0, 4.0)
		_got_it.add_theme_stylebox_override(state, got_style)
	_got_it.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		_got_it.add_theme_color_override(color_name, Palette.UI_PANEL)
	_got_it.pressed.connect(acknowledge_power)
	_got_it.visible = false
	row.add_child(_got_it)
	var skip := Button.new()
	skip.text = "SKIP"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip.add_theme_font_size_override("font_size", 11)
	skip.add_theme_color_override("font_color", Palette.UI_MUTED)
	skip.add_theme_color_override("font_hover_color", Palette.UI_TEXT)
	skip.pressed.connect(finish)
	row.add_child(skip)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh_text() -> void:
	if not TEXT.has(step):
		return
	_title.text = TEXT[step][0]
	_body.text = TEXT[step][1]
	_counter.text = "%d/%d" % [int(step) + 1, STEP_COUNT]
	_got_it.visible = step == Step.POWER


## GOT IT on the Power step: move on to launching.
func acknowledge_power() -> void:
	if step == Step.POWER:
		step = Step.LAUNCH
		_refresh_text()


## Marks the tutorial as finished (also used by SKIP) and removes it.
func finish() -> void:
	step = Step.DONE
	var data := ProgressionStore.get_section(SAVE_SECTION)
	data["done"] = true
	ProgressionStore.set_section(SAVE_SECTION, data)
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	if base == null or not is_instance_valid(base):
		return
	_advance()
	_update_target()
	queue_redraw()


## Moves on when the player has done what the current step asks.
func _advance() -> void:
	var previous := step
	match step:
		Step.OPEN_HANGAR:
			if _in_assembly():
				step = Step.INSTALL_WEAPON
		Step.INSTALL_WEAPON:
			if _has_weapon():
				step = Step.INSTALL_MINING
		Step.INSTALL_MINING:
			if _has_mining():
				step = Step.POWER
				# The essential lesson is learned; a later restart won't repeat it.
				var data := ProgressionStore.get_section(SAVE_SECTION)
				data["done"] = true
				ProgressionStore.set_section(SAVE_SECTION, data)
		Step.POWER:
			# Leaving the hangar counts as having read it.
			if _view_state() == &"OVERVIEW":
				step = Step.LAUNCH
	# Skip ahead if the player installs modules out of order.
	if step == Step.INSTALL_WEAPON and _has_weapon():
		step = Step.INSTALL_MINING if not _has_mining() else Step.POWER
	if step != previous:
		_refresh_text()


func _update_target() -> void:
	_has_target = false
	var state: StringName = _view_state()
	_caption.visible = state != &"LABORATORY" and state != &"WAREHOUSE" and state != &"MAGIC_STALL"
	# Keep the caption clear of the loadout panel on the right while assembling.
	var shift := -(LoadoutPanel.PANEL_WIDTH + 16.0) * 0.5 if state == &"ASSEMBLY" else 0.0
	_caption.offset_left = -280.0 + shift
	_caption.offset_right = 280.0 + shift
	match step:
		Step.OPEN_HANGAR:
			if state == &"OVERVIEW":
				_point_at_world(base.hangar.get_hotspot_center(AsteroidHangar.HOTSPOT_HANGAR), 120.0, Vector2.DOWN)
		Step.INSTALL_WEAPON:
			_point_at_card(&"machine_gun")
		Step.INSTALL_MINING:
			_point_at_card(&"mining_module")
		Step.POWER:
			_point_at_power_bar()
		Step.LAUNCH:
			if state == &"OVERVIEW":
				_point_at_world(base.hangar.get_hotspot_center(AsteroidHangar.HOTSPOT_STAR_MAP), 95.0, Vector2.RIGHT)
			elif state == &"ASSEMBLY":
				var back := base.get("back_button") as Control
				if back != null and back.is_visible_in_tree():
					_point_at_rect(back.get_global_rect(), Vector2.UP)


func _point_at_world(world: Vector2, world_radius: float, direction: Vector2) -> void:
	var screen := get_viewport().get_canvas_transform() * world
	var zoom := get_viewport().get_canvas_transform().get_scale().x
	_set_target(_screen_to_local(screen), world_radius * zoom / _ui_scale(), direction)


func _point_at_card(module_id: StringName) -> void:
	if _view_state() != &"ASSEMBLY":
		return
	var panel := base.get("loadout_panel") as Control
	if panel == null or not panel.is_visible_in_tree():
		return
	var card := _find_card(panel, module_id)
	if card == null or not card.is_visible_in_tree():
		return
	# Only point while the card is inside the panel's scroll view.
	var scroll := panel.get("_scroll") as Control
	if scroll != null and not scroll.get_global_rect().grow(4.0).encloses(card.get_global_rect()):
		return
	_point_at_rect(card.get_global_rect(), Vector2.RIGHT)


func _point_at_power_bar() -> void:
	if _view_state() != &"ASSEMBLY":
		return
	var panel := base.get("loadout_panel") as Control
	if panel == null or not panel.is_visible_in_tree():
		return
	var bar := panel.get("_power_bar") as Control
	if bar == null or not bar.is_visible_in_tree():
		return
	# Highlight the whole POWER row (label, bar, count); the arrow comes in
	# from the left, outside the panel.
	var row := bar.get_parent() as Control
	_point_at_rect((row if row != null else bar).get_global_rect(), Vector2.RIGHT)


func _point_at_rect(global_rect: Rect2, direction: Vector2) -> void:
	var top_left := _screen_to_local(global_rect.position)
	var bottom_right := _screen_to_local(global_rect.end)
	var rect := Rect2(top_left, bottom_right - top_left)
	# Aim at the near edge so the arrow sits outside the rect.
	var point := rect.get_center() - direction * Vector2(rect.size.x * 0.5, rect.size.y * 0.5)
	_set_target(point, 0.0, direction)
	_highlight_rect = rect


var _highlight_rect := Rect2()


func _set_target(point: Vector2, radius: float, direction: Vector2) -> void:
	_has_target = true
	_target = point
	_target_radius = radius
	_arrow_dir = direction.normalized()
	if radius > 0.0:
		_highlight_rect = Rect2()


func _find_card(root: Node, module_id: StringName) -> Control:
	for child in root.get_children():
		if child is Control and child.has_meta("module_id") and child.get_meta("module_id") == module_id:
			return child
		var found := _find_card(child, module_id)
		if found != null:
			return found
	return null


func _draw() -> void:
	if not _has_target:
		return
	var bob := sin(_time * 5.0) * 7.0
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	if _target_radius > 0.0:
		draw_arc(_target, _target_radius + 6.0 * pulse, 0.0, TAU, 64, Color(Palette.ACCENT, 0.35 + 0.4 * pulse), 3.0)
	elif _highlight_rect.size != Vector2.ZERO:
		var outline := Palette.rounded_rect_points(_highlight_rect.grow(4.0 + 3.0 * pulse), 10.0)
		outline.append(outline[0])
		draw_polyline(outline, Color(Palette.ACCENT, 0.5 + 0.4 * pulse), 3.0)
	# Arrow sits just outside the target, pointing along _arrow_dir.
	var tip := _target - _arrow_dir * (_target_radius + 10.0 + bob)
	_draw_arrow(tip, _arrow_dir)


func _draw_arrow(tip: Vector2, direction: Vector2) -> void:
	var side := direction.orthogonal()
	var head := 22.0
	var shaft := 26.0
	var points := PackedVector2Array([
		tip,
		tip - direction * head + side * head * 0.8,
		tip - direction * head + side * 8.0,
		tip - direction * (head + shaft) + side * 8.0,
		tip - direction * (head + shaft) - side * 8.0,
		tip - direction * head - side * 8.0,
		tip - direction * head - side * head * 0.8,
	])
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(3.0, 4.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.3))
	draw_colored_polygon(points, Palette.ACCENT)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Palette.UI_PANEL, 2.5)


# ==========================================
# Helpers
# ==========================================

func _ui_scale() -> float:
	var root := get_parent()
	return float(root.get("ui_visual_scale")) if root != null and root.get("ui_visual_scale") != null else 1.0


func _screen_to_local(screen: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen


## BaseMain view state name: OVERVIEW, ZOOMING, ASSEMBLY, LABORATORY, ...
func _view_state() -> StringName:
	return base.call("get_view_state_name") if base.has_method("get_view_state_name") else &""


func _in_assembly() -> bool:
	return _view_state() == &"ASSEMBLY"


static func _has_weapon() -> bool:
	for path in ShipLoadout.installed_modules.values():
		var entry := ModuleCatalog.find_by_scene(String(path))
		if not entry.is_empty() and ModuleCatalog.is_weapon(entry["id"]):
			return true
	return false


static func _has_mining() -> bool:
	for path in ShipLoadout.installed_modules.values():
		if ModuleCatalog.find_by_scene(String(path)).get("id", &"") == &"mining_module":
			return true
	return false
