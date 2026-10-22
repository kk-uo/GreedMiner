class_name ResearchTreeView
extends Control

## Laboratory research tree (design C "horizontal tree + bottom strip").
## The tree grows left to right: every node is one hexagon icon, with no text.
## Clicking a node selects it and the strip along the bottom shows its name,
## what it gives, its cost and the RESEARCH button, so the tree is never
## covered. Presentation only: state and purchases stay in ResearchManager.
##
## Columns come from the prerequisite depth; rows are laid out like a tidy
## tree (a parent sits in the middle of its children). Siblings keep the order
## of their visual_position.x in the tree resource.

signal message_requested(message: String)

const COLUMN_GAP: float = 210.0
const ROW_GAP: float = 104.0
const HEX_RADIUS: float = 30.0
const MARGIN := Vector2(64.0, 52.0)
const STRIP_HEIGHT: float = 84.0
const STRIP_GAP: float = 14.0
const LINK_WIDTH: float = 4.0
const PULSE_SPEED: float = 3.4
const FLASH_TIME: float = 0.55

const COLOR_DONE := Color("F08A24")
const COLOR_DONE_EDGE := Color("FFB25E")
const COLOR_AVAILABLE := Color("2A231E")
const COLOR_LOCKED := Color("221C18")
const COLOR_LOCKED_EDGE := Color("5A524B")
const COLOR_LINK_SOFT := Color("8A5A30")
const COLOR_LINK_OFF := Color("3B3530")
const COLOR_DARK := Color("1D1714")
const COLOR_SELECT := Color("FFD23F")

var tree: ResearchTreeDefinition
## research_id -> {"node": ResearchTreeNode, "at": Vector2 (canvas position)}.
var _nodes: Dictionary = {}
var selected_id: StringName = &""

var _scroll: ScrollContainer
var _canvas: TreeCanvas
var _strip: PanelContainer
var _strip_icon: NodeIcon
var _strip_name: Label
var _strip_note: Label
var _strip_stat: PanelContainer
var _strip_stat_icon: StatIcon
var _strip_stat_label: Label
var _strip_cost: HBoxContainer
var _strip_cost_label: Label
## RESEARCH / DONE / LOCKED button of the selected node (exposed for tests).
var research_button: Button


func setup(definition: ResearchTreeDefinition) -> void:
	tree = definition
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0.0, 360.0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_layout_nodes()
	_build_children()
	selected_id = _default_selection()
	refresh()


func refresh() -> void:
	if tree == null or _canvas == null:
		return
	if not _nodes.has(selected_id):
		selected_id = _default_selection()
	_refresh_strip()
	_canvas.queue_redraw()


## Selects a node (as if clicked) and shows it in the bottom strip.
func select_node(research_id: StringName) -> void:
	if not _nodes.has(research_id):
		return
	selected_id = research_id
	refresh()


## Canvas position of a node's centre (exposed for tests).
func get_node_center(research_id: StringName) -> Vector2:
	return (_nodes[research_id]["at"] as Vector2) if _nodes.has(research_id) else Vector2.ZERO


# ==========================================
# Layout
# ==========================================

func _layout_nodes() -> void:
	_nodes.clear()
	var enabled: Array[ResearchTreeNode] = []
	for node in tree.nodes:
		if node != null and node.enabled:
			enabled.append(node)
	# Depth = longest prerequisite chain; the first enabled prerequisite is the
	# parent used for the row layout (links are drawn to every prerequisite).
	var depth: Dictionary = {}
	var children: Dictionary = {}
	var roots: Array[ResearchTreeNode] = []
	for node in enabled:
		depth[node.research_id] = _depth_of(node, {})
		var parent := _layout_parent(node)
		if parent == null:
			roots.append(node)
		else:
			if not children.has(parent.research_id):
				children[parent.research_id] = []
			(children[parent.research_id] as Array).append(node)
	var by_order := func(a: ResearchTreeNode, b: ResearchTreeNode) -> bool:
		return a.visual_position.x < b.visual_position.x if a.visual_position.x != b.visual_position.x else a.visual_position.y < b.visual_position.y
	roots.sort_custom(by_order)
	for key in children:
		(children[key] as Array).sort_custom(by_order)
	var rows: Dictionary = {}
	var next_row: Array[float] = [0.0]
	for root in roots:
		_place_rows(root, children, rows, next_row)
	for node in enabled:
		var at := MARGIN + Vector2(float(depth[node.research_id]) * COLUMN_GAP, float(rows.get(node.research_id, 0.0)) * ROW_GAP)
		_nodes[node.research_id] = {"node": node, "at": at}


func _depth_of(node: ResearchTreeNode, visiting: Dictionary) -> int:
	if visiting.has(node.research_id):
		return 0
	visiting[node.research_id] = true
	var best := 0
	for id in node.prerequisite_ids:
		var parent := tree.get_node(id)
		if parent != null and parent.enabled:
			best = maxi(best, _depth_of(parent, visiting) + 1)
	visiting.erase(node.research_id)
	return best


func _layout_parent(node: ResearchTreeNode) -> ResearchTreeNode:
	for id in node.prerequisite_ids:
		var parent := tree.get_node(id)
		if parent != null and parent.enabled and parent != node:
			return parent
	return null


## Leaves take the next free row; a parent sits halfway between its first and
## last child. Returns the row of `node`.
func _place_rows(node: ResearchTreeNode, children: Dictionary, rows: Dictionary, next_row: Array[float]) -> float:
	if rows.has(node.research_id):
		return rows[node.research_id]
	var kids: Array = children.get(node.research_id, [])
	if kids.is_empty():
		rows[node.research_id] = next_row[0]
		next_row[0] += 1.0
	else:
		var first: float = _place_rows(kids[0], children, rows, next_row)
		var last: float = first
		for index in range(1, kids.size()):
			last = _place_rows(kids[index], children, rows, next_row)
		rows[node.research_id] = (first + last) * 0.5
	return rows[node.research_id]


func _canvas_size() -> Vector2:
	var extent := Vector2.ZERO
	for item in _nodes.values():
		extent = extent.max(item["at"])
	return extent + MARGIN


func _default_selection() -> StringName:
	var first: StringName = &""
	for node in tree.nodes:
		if node == null or not _nodes.has(node.research_id):
			continue
		if first.is_empty():
			first = node.research_id
		if ResearchManager.get_tree_node_state(node.research_id) == &"AVAILABLE":
			return node.research_id
	return first


# ==========================================
# Children: scrolling tree canvas + bottom strip
# ==========================================

func _build_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_bottom = -(STRIP_HEIGHT + STRIP_GAP)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	_canvas = TreeCanvas.new()
	_canvas.view = self
	_canvas.custom_minimum_size = _canvas_size()
	center.add_child(_canvas)
	_build_strip()


func _build_strip() -> void:
	_strip = PanelContainer.new()
	_strip.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.UI_PANEL_RAISED, 14, 20.0, 12.0))
	_strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_strip.offset_top = -STRIP_HEIGHT
	_strip.offset_bottom = 0.0
	add_child(_strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_strip.add_child(row)

	_strip_icon = NodeIcon.new()
	_strip_icon.custom_minimum_size = Vector2(56.0, 56.0)
	_strip_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_strip_icon)

	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 2)
	names.custom_minimum_size = Vector2(200.0, 0.0)
	row.add_child(names)
	_strip_name = _label("", 17, Palette.UI_TEXT)
	names.add_child(_strip_name)
	_strip_note = _label("", 11, Palette.UI_MUTED)
	names.add_child(_strip_note)

	_strip_stat = PanelContainer.new()
	_strip_stat.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.UI_PANEL, 9, 12.0, 6.0))
	_strip_stat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_strip_stat)
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 8)
	_strip_stat.add_child(stat_row)
	_strip_stat_icon = StatIcon.new()
	_strip_stat_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stat_row.add_child(_strip_stat_icon)
	_strip_stat_label = _label("", 17, Palette.UI_TEXT)
	stat_row.add_child(_strip_stat_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_strip_cost = HBoxContainer.new()
	_strip_cost.add_theme_constant_override("separation", 6)
	row.add_child(_strip_cost)
	var gem := OreDiamond.new()
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_strip_cost.add_child(gem)
	_strip_cost_label = _label("", 16, Palette.GOLD)
	_strip_cost_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_strip_cost.add_child(_strip_cost_label)

	research_button = Button.new()
	research_button.custom_minimum_size = Vector2(150.0, 44.0)
	research_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	research_button.focus_mode = Control.FOCUS_NONE
	research_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	research_button.pressed.connect(_on_research_pressed)
	row.add_child(research_button)


func _refresh_strip() -> void:
	if _strip == null:
		return
	var has_node := _nodes.has(selected_id)
	_strip.visible = has_node
	if not has_node:
		return
	var node: ResearchTreeNode = _nodes[selected_id]["node"]
	var state := ResearchManager.get_tree_node_state(selected_id)
	var info := node_info(node)
	_strip_icon.glyph = info["glyph"]
	_strip_icon.tier = info["tier"]
	_strip_icon.state = state
	_strip_icon.queue_redraw()
	_strip_name.text = tr(node.display_name)
	_strip_stat_icon.kind = info["stat_icon"]
	_strip_stat_icon.queue_redraw()
	_strip_stat_label.text = info["stat"]
	_strip_stat.visible = not String(info["stat"]).is_empty()

	var missing := _missing_prerequisites(node)
	_strip_note.text = (tr("Requires %s") % ", ".join(missing)) if state == &"LOCKED" and not missing.is_empty() else tr(node.description)
	_strip_note.visible = not _strip_note.text.is_empty()

	var cost := ResearchManager.get_upgrade_cost(selected_id)
	var affordable := ResourceManager.stored_ore >= cost
	_strip_cost.visible = state != &"COMPLETED"
	_strip_cost.get_child(0).visible = cost > 0
	_strip_cost_label.text = tr("FREE") if cost == 0 else str(cost)
	_strip_cost_label.add_theme_color_override("font_color", Palette.GOLD if affordable or state == &"LOCKED" else Palette.THREAT)
	match state:
		&"COMPLETED":
			research_button.text = "DONE"
			research_button.disabled = true
			LaboratoryPanel.ResearchCard.style_button(research_button, &"locked")
		&"AVAILABLE":
			research_button.text = "RESEARCH"
			research_button.disabled = not affordable
			LaboratoryPanel.ResearchCard.style_button(research_button, &"primary" if affordable else &"poor")
		_:
			research_button.text = "LOCKED"
			research_button.disabled = true
			LaboratoryPanel.ResearchCard.style_button(research_button, &"locked")
	research_button.mouse_default_cursor_shape = Control.CURSOR_ARROW if research_button.disabled else Control.CURSOR_POINTING_HAND


func _missing_prerequisites(node: ResearchTreeNode) -> Array[String]:
	var missing: Array[String] = []
	for id in node.prerequisite_ids:
		if not ResearchManager.is_research_completed(id):
			var parent := tree.get_node(id)
			missing.append(tr(parent.display_name) if parent != null else String(id))
	return missing


func _on_research_pressed() -> void:
	if selected_id.is_empty():
		return
	_on_node_pressed(selected_id)


## Buys the node if it can be bought, or explains why not.
func _on_node_pressed(research_id: StringName) -> void:
	var state := ResearchManager.get_tree_node_state(research_id)
	if state == &"LOCKED":
		var node := tree.get_node(research_id)
		var names := _missing_prerequisites(node) if node != null else ([] as Array[String])
		message_requested.emit(tr("Requires: %s") % ", ".join(names) if not names.is_empty() else tr("Research configuration is invalid."))
	elif state == &"AVAILABLE":
		if ResearchManager.purchase_research(research_id):
			_canvas.flash(research_id)
	refresh.call_deferred()


# ==========================================
# What a node gives (icon, tier, stat chip)
# ==========================================

## Mining tree research id (without the tier suffix) -> glyph.
const MINING_GLYPHS := {
	"mining_value": &"crystal_value",
	"mining_respawn": &"regrow",
	"mining_qte": &"qte",
	"mining_passive": &"ore_flow",
	"mining_hp": &"dwarf_hp",
	"mining_time": &"dig_speed",
	"mining_worker": &"dwarf_pair",
	"mining_detection": &"dwarf_stealth",
	"mining_move_speed": &"dwarf_run",
}


## {"glyph", "tier", "stat_icon", "stat"} for a node, read from its research
## effect so new nodes get a sensible icon without extra data.
static func node_info(node: ResearchTreeNode) -> Dictionary:
	var info := {"glyph": &"generic", "tier": 1, "stat_icon": &"plus", "stat": ""}
	var id := String(node.research_id)
	var tail := id.get_slice("_", id.get_slice_count("_") - 1)
	if tail.is_valid_int():
		info["tier"] = maxi(int(tail), 1)
	var definition := ResearchManager.get_definition(node.research_id) if Engine.get_main_loop() != null else null
	var effect: ResearchEffect = definition.effect if definition != null else null
	if effect is ShipResearchEffect:
		var ship_effect := effect as ShipResearchEffect
		if not ship_effect.unlocked_planet_ids.is_empty():
			info["glyph"] = &"planet"
			info["stat_icon"] = &"planet"
			var names: Array[String] = []
			for planet_id in ship_effect.unlocked_planet_ids:
				var index := PlanetSelect.get_planet_index(planet_id)
				var planet_name := String(PlanetSelect.PLANETS[index].get("name", planet_id)) if PlanetSelect.PLANETS[index].get("id") == planet_id else String(planet_id)
				names.append(planet_name.get_slice(" ", 0))
			info["stat"] = " · ".join(names)
		elif ship_effect.base_power_bonus > 0:
			info["glyph"] = &"energy"
			info["stat_icon"] = &"energy"
			info["stat"] = TranslationServer.translate("+%d POWER") % ship_effect.base_power_bonus
		elif ship_effect.unlocks_ship_style:
			info["glyph"] = &"style"
			info["stat_icon"] = &"style"
			info["stat"] = "SHIP STYLE"
		elif ship_effect.power_bonus > 0:
			info["glyph"] = &"energy"
			info["stat_icon"] = &"energy"
			info["stat"] = TranslationServer.translate("+%d POWER") % ship_effect.power_bonus
		elif ship_effect.artifact_slots > 0:
			info["glyph"] = &"magic"
			info["stat_icon"] = &"gem"
			info["stat"] = TranslationServer.translate("+%d slot") % ship_effect.artifact_slots
		elif ship_effect.regeneration_amount > 0.0:
			info["glyph"] = &"regen"
			info["stat_icon"] = &"clock"
			info["stat"] = "+%s HP / %ss" % [_number(ship_effect.regeneration_amount), _number(ship_effect.regeneration_interval)]
		elif ship_effect.expansion_capacity_bonus > 0:
			info["glyph"] = &"expand"
			info["stat_icon"] = &"energy"
			info["stat"] = "SLOT EXPANSION READY"
		elif ship_effect.energy_module_hp_bonus > 0.0:
			info["glyph"] = &"shielded"
			info["stat_icon"] = &"shield"
			info["stat"] = "+%s HP / BATTERY" % _number(ship_effect.energy_module_hp_bonus)
		elif ship_effect.max_hp_bonus > 0.0:
			info["glyph"] = &"hp"
			info["stat_icon"] = &"shield"
			info["stat"] = "+%s HP" % _number(ship_effect.max_hp_bonus)
	elif MINING_GLYPHS.has(id.trim_suffix("_" + tail) if tail.is_valid_int() else id):
		# Mining tree projects have no effect resource yet: icon by id.
		info["glyph"] = MINING_GLYPHS[id.trim_suffix("_" + tail) if tail.is_valid_int() else id]
		info["stat_icon"] = &"mining"
	elif effect is ModuleInstallationLimitResearchEffect:
		var limit_effect := effect as ModuleInstallationLimitResearchEffect
		var target := String(definition.target_id)
		# Node shows an extra module slot; the stat chip names which module.
		info["glyph"] = &"slot"
		info["stat_icon"] = &"mining" if target.contains("mining") else (&"energy" if target.contains("energy") else &"plus")
		info["stat"] = TranslationServer.translate("+%d slot") % maxi(limit_effect.unlocked_installation_limit - limit_effect.initial_installation_limit, 1)
	return info


static func _number(value: float) -> String:
	return str(int(round(value))) if absf(value - round(value)) < 0.05 else "%.1f" % value


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# ==========================================
# Drawing helpers (shared by the canvas and the strip icon)
# ==========================================

static func hexagon(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle: float = PI / 6.0 + TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func draw_hex_outline(canvas: CanvasItem, center: Vector2, radius: float, color: Color, width: float) -> void:
	var points := hexagon(center, radius)
	points.append(points[0])
	canvas.draw_polyline(points, color, width, true)


## One research node: hexagon in its state colors with the glyph inside.
static func draw_node(canvas: CanvasItem, center: Vector2, radius: float, glyph: StringName, tier: int, state: StringName) -> void:
	var fill := COLOR_AVAILABLE
	var edge := COLOR_DONE
	var glyph_color := Palette.UI_TEXT
	if state == &"COMPLETED":
		fill = COLOR_DONE
		edge = COLOR_DONE_EDGE
		glyph_color = COLOR_DARK
	elif state == &"LOCKED":
		fill = COLOR_LOCKED
		edge = COLOR_LOCKED_EDGE
		glyph_color = COLOR_LOCKED_EDGE
	canvas.draw_colored_polygon(hexagon(center + Vector2(3.0, 4.0), radius), Color(0, 0, 0, 0.3))
	canvas.draw_colored_polygon(hexagon(center, radius), fill)
	draw_hex_outline(canvas, center, radius, edge, 2.5)
	draw_glyph(canvas, center, radius / 20.0, glyph, glyph_color)
	if tier >= 2:
		draw_tier(canvas, center + Vector2(7.5, 9.0) * radius / 20.0, radius / 20.0, tier, glyph_color)
	var badge := center + Vector2(radius * 0.68, -radius * 0.68)
	if state == &"COMPLETED":
		canvas.draw_circle(badge, 7.0, COLOR_DARK)
		canvas.draw_polyline(PackedVector2Array([badge + Vector2(-3, 0), badge + Vector2(-1, 2.5), badge + Vector2(3, -2.5)]), COLOR_SELECT, 1.8, true)
	elif state == &"LOCKED":
		canvas.draw_circle(badge, 8.0, COLOR_DARK)
		canvas.draw_rect(Rect2(badge + Vector2(-4, -1), Vector2(8, 6)), Palette.UI_MUTED)
		canvas.draw_arc(badge + Vector2(0, -1.5), 2.5, PI, TAU, 8, Palette.UI_MUTED, 1.5)


## Roman tier mark ("II", "III"...) drawn as small bars.
static func draw_tier(canvas: CanvasItem, at: Vector2, scale: float, tier: int, color: Color) -> void:
	var count := clampi(tier, 2, 4)
	for index in range(count):
		var x := at.x + float(index) * 2.6 * scale
		canvas.draw_line(Vector2(x, at.y - 3.2 * scale), Vector2(x, at.y + 3.2 * scale), color, maxf(1.2 * scale, 1.0))


## Node glyph in a 20-unit box around `center` (scaled by `scale`).
static func draw_glyph(canvas: CanvasItem, center: Vector2, scale: float, glyph: StringName, color: Color) -> void:
	var p := func(x: float, y: float) -> Vector2: return center + Vector2(x, y) * scale
	match glyph:
		&"hp":
			var heart := PackedVector2Array()
			for index in range(28):
				var t: float = TAU * float(index) / 28.0
				heart.append(p.call(7.6 * pow(sin(t), 3.0), -(6.2 * cos(t) - 2.4 * cos(2.0 * t) - 0.9 * cos(3.0 * t) - 0.45 * cos(4.0 * t)) + 0.6))
			canvas.draw_colored_polygon(heart, color)
			var cut := Color(COLOR_DARK, 0.45)
			canvas.draw_rect(Rect2(p.call(-1.0, -4.0), Vector2(2.0, 7.0) * scale), cut)
			canvas.draw_rect(Rect2(p.call(-3.5, -1.5), Vector2(7.0, 2.0) * scale), cut)
		&"regen":
			canvas.draw_arc(center, 6.0 * scale, PI * 0.55, PI * 2.25, 18, color, 2.2 * scale)
			canvas.draw_colored_polygon(PackedVector2Array([p.call(-9.0, -3.0), p.call(-3.0, -3.0), p.call(-6.0, 2.0)]), color)
			canvas.draw_rect(Rect2(p.call(-1.0, -3.0), Vector2(2.0, 6.0) * scale), color)
			canvas.draw_rect(Rect2(p.call(-3.0, -1.0), Vector2(6.0, 2.0) * scale), color)
		&"magic":
			canvas.draw_colored_polygon(PackedVector2Array([p.call(0, -8), p.call(6, -2), p.call(4, 7), p.call(-4, 7), p.call(-6, -2)]), color)
			canvas.draw_colored_polygon(PackedVector2Array([p.call(0, -8), p.call(6, -2), p.call(0, 0), p.call(-6, -2)]), Color(COLOR_DARK, 0.25))
		&"mining":
			canvas.draw_line(p.call(-5.0, 7.0), p.call(4.0, -3.0), color, 2.4 * scale)
			canvas.draw_colored_polygon(PackedVector2Array([p.call(-6, -6), p.call(1, -8), p.call(8, -3), p.call(7, 0), p.call(1, -5), p.call(-5, -3)]), color)
		&"energy":
			canvas.draw_colored_polygon(PackedVector2Array([p.call(2, -9), p.call(-5, 1), p.call(0, 1), p.call(-2, 9), p.call(5, -2), p.call(0, -2)]), color)
		&"style":
			# Three overlapping paint swatches.
			canvas.draw_circle(p.call(-3.5, 2.5), 4.6 * scale, color)
			canvas.draw_circle(p.call(3.5, 2.5), 4.6 * scale, Color(color, 0.75))
			canvas.draw_circle(p.call(0.0, -3.5), 4.6 * scale, Color(color, 0.5))
		&"planet":
			# A planet with a ring and a small dotted route toward it.
			canvas.draw_circle(p.call(2.5, -1.5), 5.5 * scale, color)
			canvas.draw_arc(p.call(2.5, -1.5), 8.5 * scale, -0.35, PI - 0.35, 16, color, 1.6 * scale)
			for dot in range(3):
				canvas.draw_circle(p.call(-8.0 + float(dot) * 2.6, 7.5 - float(dot) * 2.2), 1.1 * scale, color)
		&"shielded":
			# A shield with a battery bolt cut through it.
			canvas.draw_colored_polygon(PackedVector2Array([p.call(-7, -7), p.call(0, -9), p.call(7, -7), p.call(7, 0), p.call(0, 9), p.call(-7, 0)]), color)
			canvas.draw_colored_polygon(PackedVector2Array([p.call(1.5, -6), p.call(-3.5, 1), p.call(-0.5, 1), p.call(-1.5, 6), p.call(3.5, -1), p.call(0.5, -1)]), Color(COLOR_DARK, 0.55))
		&"expand":
			# A battery whose frame opens outward: corner brackets pushing out.
			canvas.draw_rect(Rect2(p.call(-4.0, -5.5), Vector2(8.0, 11.0) * scale), color)
			canvas.draw_rect(Rect2(p.call(-1.8, -7.2), Vector2(3.6, 1.8) * scale), color)
			canvas.draw_colored_polygon(PackedVector2Array([p.call(1.2, -3.5), p.call(-1.8, 0.6), p.call(0.0, 0.6), p.call(-1.0, 3.8), p.call(2.0, -0.4), p.call(0.2, -0.4)]), Color(COLOR_DARK, 0.55))
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var c: Vector2 = p.call(corner.x * 9.0, corner.y * 8.5)
				canvas.draw_line(c, c - Vector2(corner.x * 3.6, 0.0) * scale, color, 1.6 * scale)
				canvas.draw_line(c, c - Vector2(0.0, corner.y * 3.6) * scale, color, 1.6 * scale)
		&"slot":
			# A second module slot: one filled cell and a "+" cell.
			canvas.draw_rect(Rect2(p.call(-9.0, -4.5), Vector2(8.0, 9.0) * scale), color)
			canvas.draw_rect(Rect2(p.call(1.0, -4.5), Vector2(8.0, 9.0) * scale), color, false, 1.6 * scale)
			canvas.draw_rect(Rect2(p.call(4.2, -2.6), Vector2(1.6, 5.2) * scale), color)
			canvas.draw_rect(Rect2(p.call(2.4, -0.8), Vector2(5.2, 1.6) * scale), color)
		&"crystal_value":
			# A crystal with a rising arrow: more ore per crystal.
			_draw_crystal(canvas, p.call(-3.5, 0.0), scale, color)
			canvas.draw_colored_polygon(PackedVector2Array([p.call(6, -9), p.call(10, -3.5), p.call(2, -3.5)]), color)
			canvas.draw_rect(Rect2(p.call(5.0, -3.6), Vector2(2.0, 8.0) * scale), color)
		&"regrow":
			# A crystal inside a circling arrow: it grows back.
			canvas.draw_arc(center, 8.0 * scale, -PI * 0.35, PI * 1.35, 20, color, 1.8 * scale)
			var end: Vector2 = p.call(cos(-PI * 0.35) * 8.0, sin(-PI * 0.35) * 8.0)
			canvas.draw_colored_polygon(PackedVector2Array([end + Vector2(-3.6, -1.8) * scale, end + Vector2(2.6, -2.6) * scale, end + Vector2(1.0, 3.4) * scale]), color)
			_draw_crystal(canvas, center, scale * 0.6, color)
		&"qte":
			# A cursor tapping, with a burst: quick-time mining reward.
			for k in range(5):
				var a := -PI * 0.95 + float(k) * PI * 0.22
				var at: Vector2 = p.call(-3.0, -3.0)
				canvas.draw_line(at + Vector2(cos(a), sin(a)) * 3.8 * scale, at + Vector2(cos(a), sin(a)) * 7.0 * scale, color, 1.6 * scale)
			canvas.draw_colored_polygon(PackedVector2Array([p.call(-2, -2), p.call(-2, 9), p.call(1, 6.5), p.call(3, 10), p.call(5, 9), p.call(3, 5.5), p.call(7, 5)]), color)
		&"ore_flow":
			# Ore drops pouring steadily out of a small chute: ore per second.
			canvas.draw_colored_polygon(PackedVector2Array([p.call(-9, -8), p.call(1, -8), p.call(-1, -3), p.call(-7, -3)]), color)
			for k in range(3):
				var d: Vector2 = p.call(-4.0 + float(k) * 4.2, -0.5 + float(k) * 3.8)
				var r := (2.2 + 0.5 * float(k)) * scale
				canvas.draw_colored_polygon(PackedVector2Array([d + Vector2(0, -r), d + Vector2(r, 0), d + Vector2(0, r), d + Vector2(-r, 0)]), color)
			canvas.draw_arc(p.call(6.0, -4.5), 3.6 * scale, 0.0, TAU, 14, color, 1.4 * scale)
			canvas.draw_line(p.call(6.0, -4.5), p.call(6.0, -6.6), color, 1.2 * scale)
			canvas.draw_line(p.call(6.0, -4.5), p.call(7.6, -4.5), color, 1.2 * scale)
		&"dwarf_hp":
			# A dwarf's helmet with its lamp, and a heart: tougher dwarves.
			_draw_helmet(canvas, p.call(-1.5, 2.0), scale, color)
			var heart := PackedVector2Array()
			for index in range(20):
				var t: float = TAU * float(index) / 20.0
				heart.append(p.call(6.0 + 3.6 * pow(sin(t), 3.0), -5.5 - (3.0 * cos(t) - 1.2 * cos(2.0 * t) - 0.45 * cos(3.0 * t) - 0.2 * cos(4.0 * t))))
			canvas.draw_colored_polygon(heart, color)
		&"dig_speed":
			# A pickaxe with speed lines: faster digging.
			canvas.draw_line(p.call(-2.0, 8.0), p.call(5.0, -1.0), color, 2.4 * scale)
			canvas.draw_colored_polygon(PackedVector2Array([p.call(-2, -5), p.call(4, -8), p.call(10, -4), p.call(9, -1), p.call(4, -5), p.call(-1, -2.5)]), color)
			for k in range(3):
				var y := -3.0 + float(k) * 4.0
				canvas.draw_line(p.call(-10.0 + float(k) * 1.5, y), p.call(-5.0 + float(k) * 1.5, y), color, 1.5 * scale)
		&"dwarf_stealth":
			# An enemy's eye struck through: dwarves are spotted from less far.
			var eye := PackedVector2Array()
			for index in range(24):
				var t: float = TAU * float(index) / 24.0
				eye.append(p.call(cos(t) * 9.0, sin(t) * 5.2 * absf(sin(t)) * (1.0 if sin(t) >= 0.0 else 1.0)))
			canvas.draw_colored_polygon(eye, color)
			canvas.draw_circle(center, 3.4 * scale, Color(COLOR_DARK, 0.6))
			canvas.draw_circle(p.call(-1.0, -1.0), 1.1 * scale, color)
			canvas.draw_line(p.call(-8.0, 8.0), p.call(8.0, -8.0), Color(COLOR_DARK, 0.85), 3.6 * scale)
			canvas.draw_line(p.call(-8.0, 8.0), p.call(8.0, -8.0), color, 1.8 * scale)
		&"dwarf_run":
			# A dwarf's helmet dashing forward, speed lines streaming behind.
			_draw_helmet(canvas, p.call(3.0, 2.0), scale * 0.95, color)
			for k in range(3):
				var y := -3.0 + float(k) * 3.4
				canvas.draw_line(p.call(-10.0 + float(k) * 1.2, y), p.call(-5.0 + float(k) * 1.2, y), color, 1.5 * scale)
		&"dwarf_pair":
			# Two dwarf helmets: a second dwarf per module.
			_draw_helmet(canvas, p.call(4.0, -1.5), scale * 0.85, Color(color, 0.55))
			_draw_helmet(canvas, p.call(-3.0, 3.0), scale, color)
		_:
			canvas.draw_rect(Rect2(p.call(-1.3, -6.0), Vector2(2.6, 12.0) * scale), color)
			canvas.draw_rect(Rect2(p.call(-6.0, -1.3), Vector2(12.0, 2.6) * scale), color)


## A standing hexagonal crystal with its left face shaded.
static func _draw_crystal(canvas: CanvasItem, at: Vector2, scale: float, color: Color) -> void:
	var q := func(x: float, y: float) -> Vector2: return at + Vector2(x, y) * scale
	canvas.draw_colored_polygon(PackedVector2Array([q.call(0, -10), q.call(4.5, -5.5), q.call(4.5, 6), q.call(0, 9.5), q.call(-4.5, 6), q.call(-4.5, -5.5)]), color)
	canvas.draw_colored_polygon(PackedVector2Array([q.call(0, -10), q.call(0, 9.5), q.call(-4.5, 6), q.call(-4.5, -5.5)]), Color(COLOR_DARK, 0.28))


## A dwarf's round mining helmet with a brim and a lamp (cut out).
static func _draw_helmet(canvas: CanvasItem, at: Vector2, scale: float, color: Color) -> void:
	var dome := PackedVector2Array()
	for index in range(13):
		var a := PI + PI * float(index) / 12.0
		dome.append(at + Vector2(cos(a) * 7.0, sin(a) * 6.5) * scale)
	canvas.draw_colored_polygon(dome, color)
	canvas.draw_rect(Rect2(at + Vector2(-8.5, -0.2) * scale, Vector2(17.0, 2.6) * scale), color)
	canvas.draw_circle(at + Vector2(0, -3.0) * scale, 2.0 * scale, Color(COLOR_DARK, 0.55))


# ==========================================
# Inner controls
# ==========================================

## The tree itself: links and hexagon nodes, click to select.
class TreeCanvas:
	extends Control

	var view: ResearchTreeView
	var _hover: StringName = &""
	var _time: float = 0.0
	var _flash: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_time += delta
		for id in _flash.keys():
			_flash[id] = float(_flash[id]) + delta
			if float(_flash[id]) > FLASH_TIME:
				_flash.erase(id)
		queue_redraw()

	func flash(research_id: StringName) -> void:
		_flash[research_id] = 0.0

	func _node_at(point: Vector2) -> StringName:
		for id in view._nodes:
			if point.distance_to(view._nodes[id]["at"]) <= HEX_RADIUS + 4.0:
				return id
		return &""

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var hover := _node_at(event.position)
			if hover != _hover:
				_hover = hover
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hover.is_empty() else Control.CURSOR_ARROW
				queue_redraw()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var id := _node_at(event.position)
			if not id.is_empty():
				view.select_node(id)
				accept_event()

	func _draw() -> void:
		if view == null or view.tree == null:
			return
		# Links first: parent -> half way -> down/up -> child (right angles).
		for id in view._nodes:
			var node: ResearchTreeNode = view._nodes[id]["node"]
			var state := ResearchManager.get_tree_node_state(id)
			for parent_id in node.prerequisite_ids:
				if not view._nodes.has(parent_id):
					continue
				var from: Vector2 = view._nodes[parent_id]["at"]
				var to: Vector2 = view._nodes[id]["at"]
				var color := COLOR_LINK_OFF
				if state == &"COMPLETED":
					color = COLOR_DONE
				elif ResearchManager.is_research_completed(parent_id):
					color = COLOR_DONE if state == &"AVAILABLE" else COLOR_LINK_SOFT
				var mid_x: float = (from.x + to.x) * 0.5
				draw_polyline(PackedVector2Array([from, Vector2(mid_x, from.y), Vector2(mid_x, to.y), to]), color, LINK_WIDTH, true)
		for id in view._nodes:
			var node: ResearchTreeNode = view._nodes[id]["node"]
			var at: Vector2 = view._nodes[id]["at"]
			var state := ResearchManager.get_tree_node_state(id)
			var info := ResearchTreeView.node_info(node)
			if state == &"AVAILABLE":
				var pulse: float = 0.1 + 0.22 * (0.5 + 0.5 * sin(_time * PULSE_SPEED))
				draw_colored_polygon(ResearchTreeView.hexagon(at, HEX_RADIUS + 6.0), Color(COLOR_DONE, pulse))
			var radius: float = HEX_RADIUS * (1.06 if id == _hover else 1.0)
			ResearchTreeView.draw_node(self, at, radius, info["glyph"], info["tier"], state)
			if id == view.selected_id:
				ResearchTreeView.draw_hex_outline(self, at, HEX_RADIUS + 9.0, COLOR_SELECT, 2.5)
			if _flash.has(id):
				var k: float = float(_flash[id]) / FLASH_TIME
				ResearchTreeView.draw_hex_outline(self, at, HEX_RADIUS * lerpf(1.0, 2.0, k), Color(COLOR_SELECT, 1.0 - k), 3.0 * (1.0 - k) + 0.5)


## Big hexagon icon of the selected node in the strip.
class NodeIcon:
	extends Control

	var glyph: StringName = &"generic"
	var tier: int = 1
	var state: StringName = &"LOCKED"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		ResearchTreeView.draw_node(self, size * 0.5, minf(size.x, size.y) * 0.46, glyph, tier, state)


## Small muted icon in front of the stat value.
class StatIcon:
	extends Control

	var kind: StringName = &"plus"

	func _init() -> void:
		custom_minimum_size = Vector2(16.0, 16.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var color := Palette.UI_MUTED
		match kind:
			&"shield":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -6), c + Vector2(6, -6), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)]), color)
			&"clock":
				draw_arc(c, 6.0, 0.0, TAU, 20, color, 2.0)
				draw_line(c, c + Vector2(0, -4), color, 2.0)
				draw_line(c, c + Vector2(3, 0), color, 2.0)
			&"gem":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, -2), c + Vector2(4, 6), c + Vector2(-4, 6), c + Vector2(-6, -2)]), color)
			&"mining", &"energy", &"planet", &"style":
				ResearchTreeView.draw_glyph(self, c, 0.8, kind, color)
			_:
				ResearchTreeView.draw_glyph(self, c, 0.8, &"generic", color)


## Gold ore diamond in front of the cost.
class OreDiamond:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(12.0, 14.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)]), Palette.GOLD)
