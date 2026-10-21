extends Control

## First-time base tutorial (presentation + a tiny saved flag).
##
## Steps, each with a bouncing arrow on its target and a caption bar at the
## bottom explaining what to do and what the module is for:
##   1. OPEN THE HANGAR  — arrow on the landing pad (base overview).
##   2. INSTALL A WEAPON — arrow on the Machine Gun card (loadout list).
##   3. INSTALL MINING   — arrow on the Mining card; while the card is
##                         scrolled out of the list, a "SCROLL DOWN" hint.
##   4. POWER            — install another Machine Gun until every point of
##                         Power is used (POWER row highlighted too).
##   5. LAUNCH           — arrow on the Star Map once back in the overview.
## No skip button (user request).
##
## Second part, merged with the Laboratory's old "POWER FIRST" tip (user
## request): it leads to ENERGY MODULE EXPANSION I.
##   1. LAB_OPEN      — the first time back at the base with ore: arrow on
##                      the Laboratory (saved "lab_done" once inside).
##   2. LAB_RESEARCH  — inside the Laboratory, on every visit until that
##                      research is bought: arrow on the ENERGY tab, then on
##                      the project and its RESEARCH button; while the ore is
##                      short the caption says how much is missing. Buying it
##                      finishes the guide for good.
## Progress follows the real loadout (ShipLoadout), so dragging, the "+"
## button or the detail page all count. The tutorial only starts for a fresh
## ship (no weapon and no mining module installed) and is saved as done in
## ProgressionStore section "tutorial". Load with preload(); no class_name.

const SAVE_SECTION: StringName = &"tutorial"
const GUIDE_ARROW := preload("res://Scripts/UI/GuideArrow.gd")

enum Step { OPEN_HANGAR, INSTALL_WEAPON, INSTALL_MINING, POWER, LAUNCH, LAB_OPEN, LAB_RESEARCH, DONE }
const STEP_COUNT: int = 5
const LAB_STEP_COUNT: int = 2
## The Laboratory goal (was LaboratoryPanel's "POWER FIRST" tip).
const ENERGY_RESEARCH: StringName = &"energy_install_slot_unlock"

const TEXT := {
	Step.OPEN_HANGAR: ["OPEN THE HANGAR", "Click your ship on the landing pad to start building it."],
	Step.INSTALL_WEAPON: ["INSTALL A WEAPON", "Weapons fire at enemies that approach the ship. Drag the MACHINE GUN onto an empty slot, or select a slot and press +."],
	Step.INSTALL_MINING: ["INSTALL A MINING MODULE", "Mining modules drill ore during expeditions. Ore pays for research, chips and locating new planets. Scroll down the module list and drag MINING onto an empty slot."],
	Step.POWER: ["USE ALL YOUR POWER", "Every module uses Power (the bolt number on its card); the bar shows used / total. Install one more MACHINE GUN to use all of your Power. Research ENERGY in the Laboratory for more."],
	Step.LAUNCH: ["READY FOR LAUNCH", "Go back to the base (ESC) and open the STAR MAP to choose a planet. Protect the ship, mine ore, then evacuate to bank it."],
	Step.LAB_OPEN: ["UPGRADE IN THE LABORATORY", "Welcome back! The ore you bring home pays for upgrades. Click the LABORATORY to spend it."],
	Step.LAB_RESEARCH: ["POWER FIRST", "Open the ENERGY tab: a second battery means more Power for more turrets, and it leads to farther planets."],
}

var base: Node = null
var step: Step = Step.DONE

var _time: float = 0.0
var _caption: PanelContainer
var _title: Label
var _body: Label
var _counter: Label
## Arrow target in this control's coordinates; NaN-free flag via _has_target.
var _target := Vector2.ZERO
var _target_radius: float = 0.0
var _has_target: bool = false
## Which way the arrow points at the target (unit vector from arrow to target).
var _arrow_dir := Vector2.DOWN


## Starts the guide when this is a fresh game; otherwise frees itself.
static func should_run() -> bool:
	if bool(ProgressionStore.get_section(SAVE_SECTION).get("done", false)):
		return should_run_lab()
	return not _has_weapon() and not _has_mining()


## Lab part: base tutorial done, ENERGY MODULE EXPANSION not researched yet,
## and either back with ore for the first time or already shown once.
static func should_run_lab() -> bool:
	var data := ProgressionStore.get_section(SAVE_SECTION)
	if not bool(data.get("done", false)) or _energy_researched():
		return false
	return bool(data.get("lab_done", false)) or ResourceManager.stored_ore > 0.0


static func _energy_researched() -> bool:
	return ResearchManager.get_definition(ENERGY_RESEARCH) == null or ResearchManager.is_research_completed(ENERGY_RESEARCH)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_caption()
	var data := ProgressionStore.get_section(SAVE_SECTION)
	var lab := bool(data.get("done", false))
	step = Step.OPEN_HANGAR
	if lab:
		step = Step.LAB_RESEARCH if bool(data.get("lab_done", false)) else Step.LAB_OPEN
	ResearchManager.research_level_changed.connect(_on_research_level_changed)
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


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh_text() -> void:
	_lab_text = ""
	if not TEXT.has(step):
		return
	_title.text = TEXT[step][0]
	_body.text = TEXT[step][1]
	if _is_lab_step():
		_counter.text = "%d/%d" % [int(step) - int(Step.LAB_OPEN) + 1, LAB_STEP_COUNT]
	else:
		_counter.text = "%d/%d" % [int(step) + 1, STEP_COUNT]


func _is_lab_step() -> bool:
	return step == Step.LAB_OPEN or step == Step.LAB_RESEARCH


## Researching ENERGY MODULE EXPANSION finishes the lab part for good.
func _on_research_level_changed(research_id: StringName, _level: int) -> void:
	if _is_lab_step() and research_id == ENERGY_RESEARCH and _energy_researched():
		finish()


## Marks the tutorial as finished and removes it.
func finish() -> void:
	var lab := _is_lab_step()
	step = Step.DONE
	var data := ProgressionStore.get_section(SAVE_SECTION)
	data["done"] = true
	if lab:
		data["lab_done"] = true
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
			if _power_full():
				step = Step.LAUNCH
		Step.LAB_OPEN:
			if _view_state() == &"LABORATORY":
				step = Step.LAB_RESEARCH
				var lab_data := ProgressionStore.get_section(SAVE_SECTION)
				lab_data["lab_done"] = true
				ProgressionStore.set_section(SAVE_SECTION, lab_data)
	# Skip ahead if the player installs modules out of order.
	if step == Step.INSTALL_WEAPON and _has_weapon():
		step = Step.INSTALL_MINING if not _has_mining() else Step.POWER
	if step == Step.POWER and _power_full():
		step = Step.LAUNCH
	if step == Step.LAUNCH and not bool(ProgressionStore.get_section(SAVE_SECTION).get("done", false)):
		var done_data := ProgressionStore.get_section(SAVE_SECTION)
		done_data["done"] = true
		ProgressionStore.set_section(SAVE_SECTION, done_data)
	if step != previous:
		_refresh_text()


func _update_target() -> void:
	_has_target = false
	_scroll_hint = false
	_extra_rect = Rect2()
	var state: StringName = _view_state()
	_caption.visible = state != &"WAREHOUSE" and state != &"MAGIC_STALL" and (state != &"LABORATORY" or _is_lab_step()) and (step != Step.LAB_RESEARCH or state == &"LABORATORY")
	# Keep the caption clear of the loadout panel on the right while assembling.
	var shift := -(LoadoutPanel.PANEL_WIDTH + 16.0) * 0.5 if state == &"ASSEMBLY" else 0.0
	_caption.offset_left = -280.0 + shift
	_caption.offset_right = 280.0 + shift
	# In the Laboratory the caption sits at the top, clear of the RESEARCH strip.
	var at_top := state == &"LABORATORY"
	if at_top != _caption_at_top:
		_caption_at_top = at_top
		_caption.set_anchors_preset(Control.PRESET_CENTER_TOP if at_top else Control.PRESET_CENTER_BOTTOM, true)
		_caption.grow_vertical = Control.GROW_DIRECTION_END if at_top else Control.GROW_DIRECTION_BEGIN
		_caption.offset_top = 14.0 if at_top else 0.0
		_caption.offset_bottom = 14.0 if at_top else -22.0
	if _is_lab_step():
		_keep_above_laboratory()
	match step:
		Step.OPEN_HANGAR:
			if state == &"OVERVIEW":
				_point_at_world(base.hangar.get_hotspot_center(AsteroidHangar.HOTSPOT_HANGAR), 120.0, Vector2.DOWN)
		Step.INSTALL_WEAPON:
			_point_at_card(&"machine_gun")
		Step.INSTALL_MINING:
			_point_at_card(&"mining_module")
		Step.POWER:
			if state == &"OVERVIEW":
				_point_at_world(base.hangar.get_hotspot_center(AsteroidHangar.HOTSPOT_HANGAR), 120.0, Vector2.DOWN)
			else:
				_point_at_card(&"machine_gun")
				_extra_rect = _power_row_rect()
		Step.LAUNCH:
			if state == &"OVERVIEW":
				_point_at_world(base.hangar.get_hotspot_center(AsteroidHangar.HOTSPOT_STAR_MAP), 95.0, Vector2.RIGHT)
			elif state == &"ASSEMBLY":
				var back := base.get("back_button") as Control
				if back != null and back.is_visible_in_tree():
					_point_at_rect(back.get_global_rect(), Vector2.UP)
		Step.LAB_OPEN:
			if state == &"OVERVIEW":
				_point_at_world(base.hangar.get_hotspot_center(AsteroidHangar.HOTSPOT_LAB), 110.0, Vector2.DOWN)
		Step.LAB_RESEARCH:
			if state == &"LABORATORY":
				_guide_energy()


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
		# Out of view: tell the player which way to scroll the list.
		var view := scroll.get_global_rect()
		var below := card.get_global_rect().get_center().y > view.get_center().y
		var edge := Vector2(view.get_center().x, view.end.y - 96.0 if below else view.position.y + 40.0)
		_scroll_hint = true
		_scroll_down = below
		_scroll_at = _screen_to_local(edge)
		return
	_point_at_rect(card.get_global_rect(), Vector2.RIGHT)


## The loadout's POWER row (label, bar, count) in local coordinates.
func _power_row_rect() -> Rect2:
	var panel := base.get("loadout_panel") as Control
	if panel == null or not panel.is_visible_in_tree():
		return Rect2()
	var bar := panel.get("_power_bar") as Control
	if bar == null or not bar.is_visible_in_tree():
		return Rect2()
	var row := bar.get_parent() as Control
	var r := (row if row != null else bar).get_global_rect()
	var top_left := _screen_to_local(r.position)
	return Rect2(top_left, _screen_to_local(r.end) - top_left)


func _point_at_rect(global_rect: Rect2, direction: Vector2) -> void:
	var top_left := _screen_to_local(global_rect.position)
	var bottom_right := _screen_to_local(global_rect.end)
	var rect := Rect2(top_left, bottom_right - top_left)
	# Aim at the near edge so the arrow sits outside the rect.
	var point := rect.get_center() - direction * Vector2(rect.size.x * 0.5, rect.size.y * 0.5)
	_set_target(point, 0.0, direction)
	_highlight_rect = rect


var _highlight_rect := Rect2()
var _caption_at_top: bool = false
## Secondary pulsing outline (the POWER row on the Power step).
var _extra_rect := Rect2()
var _scroll_hint: bool = false
var _scroll_down: bool = true
var _scroll_at := Vector2.ZERO


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
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	if _extra_rect.size != Vector2.ZERO:
		var outline := Palette.rounded_rect_points(_extra_rect.grow(4.0 + 3.0 * pulse), 10.0)
		outline.append(outline[0])
		draw_polyline(outline, Color(Palette.ACCENT, 0.4 + 0.4 * pulse), 2.5)
	if _scroll_hint:
		GUIDE_ARROW.draw_scroll_hint(self, _scroll_at, tr("SCROLL DOWN") if _scroll_down else tr("SCROLL UP"), _time, _scroll_down)
	if not _has_target:
		return
	var bob := sin(_time * 5.0) * 7.0
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
	GUIDE_ARROW.draw(self, tip, direction, 0.5 + 0.5 * sin(_time * 4.0))


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


## Every point of Power in use: no room left for another Machine Gun (or
## no empty slot left to put one in).
func _power_full() -> bool:
	var ship := base.get("ship") as Node
	if ship == null:
		return false
	var free := int(ship.get("total_power_capacity")) - int(ship.get("total_power_consumption"))
	var gun_cost := int(ModuleCatalog.get_stats(&"machine_gun").get("power_cost", 1))
	return free < maxi(gun_cost, 1) or ShipLoadout.installed_modules.size() >= 9


## The lab part has to draw over the Laboratory modal.
func _keep_above_laboratory() -> void:
	var lab_panel := base.get("laboratory_panel") as Control
	if lab_panel == null or lab_panel.get_parent() != get_parent():
		return
	if get_index() < lab_panel.get_index():
		get_parent().move_child(self, lab_panel.get_index())


var _lab_text: String = ""
var _energy_selected: bool = false


## Inside the Laboratory: ENERGY tab -> the project -> RESEARCH, with the
## caption saying what to do (or how much ore is still missing).
func _guide_energy() -> void:
	var lab_panel := base.get("laboratory_panel") as Control
	if lab_panel == null:
		return
	var cost := ResearchManager.get_upgrade_cost(ENERGY_RESEARCH)
	var ore := int(ResourceManager.stored_ore)
	if lab_panel.get("_selected_category_id") != &"energy":
		_energy_selected = false
		_set_lab_text("POWER FIRST", tr("Open the ENERGY tab: a second battery means more Power for more turrets, and it leads to farther planets."))
		var rail := lab_panel.get("category_buttons") as Control
		if rail != null:
			for button in rail.get_children():
				if button.get("category_id") == &"energy" and (button as Control).is_visible_in_tree():
					_point_at_rect((button as Control).get_global_rect(), Vector2.RIGHT)
		return
	var tree_view := lab_panel.get("_research_tree_view") as Control
	if not is_instance_valid(tree_view):
		return
	# Select the project once on arrival in the tab (the player may click on).
	if not _energy_selected:
		_energy_selected = true
		tree_view.call("select_node", ENERGY_RESEARCH)
	if ore < cost:
		_set_lab_text("POWER FIRST", tr("ENERGY MODULE EXPANSION costs %d ore - you have %d. Bring more ore home from your next expedition, then research it here.") % [cost, ore])
	else:
		_set_lab_text("RESEARCH ENERGY MODULE EXPANSION", tr("Press RESEARCH: a second battery means more Power for more turrets, and it leads to farther planets."))
	if tree_view.get("selected_id") == ENERGY_RESEARCH:
		var button := tree_view.get("research_button") as Control
		if button != null and button.is_visible_in_tree():
			_point_at_rect(button.get_global_rect(), Vector2.RIGHT)
	else:
		# The player picked another project: point back at ours on the tree.
		var canvas := tree_view.get("_canvas") as Control
		if canvas != null and canvas.is_visible_in_tree():
			var center: Vector2 = canvas.get_global_transform_with_canvas() * (tree_view.call("get_node_center", ENERGY_RESEARCH) as Vector2)
			_set_target(_screen_to_local(center), 36.0, Vector2.RIGHT)


func _set_lab_text(title: String, body: String) -> void:
	var text := title + "|" + body
	if text == _lab_text:
		return
	_lab_text = text
	_title.text = tr(title)
	_body.text = body
