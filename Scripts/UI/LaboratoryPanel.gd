class_name LaboratoryPanel
extends Control

## Laboratory screen, soft "Thronefall-like" style (user pick): no big dark
## panel - a warm veil over the base, and on it:
## - header: title, stored ore, a round ESC;
## - a row of round category icons (category_buttons) on top; unfinished
##   ones are faded with a lock; the selected one shows its name;
## - cream cards, one per research project: level badge, the module's real
##   art, its name and the one number that matters (now -> next), and the
##   price button at the bottom (upgrade / need more ore / locked / max).
##   Level bar, artifact slots and milestones fade in on hover. Only the button
##   upgrades.
## Motion: cards pop in one after another on a tab change, lift a little on
## hover, buttons squash when pressed; a purchase flies gold from the ore
## counter into the card, bumps the card and the new value ("+1 LV").
## All rules and numbers come from ResearchManager / ResearchDefinition; this
## script only presents them and calls ResearchManager.purchase_research().

signal close_requested

const PANEL_SIZE := Vector2(1100.0, 640.0)
const RAIL_WIDTH: float = 200.0
const CARD_SIZE := Vector2(214.0, 292.0)
## Soft palette (cards and controls on the warm veil).
const CREAM := Color("FBF3E4")
const CREAM_DARK := Color("E6D7BF")
const CREAM_LOCKED := Color("E4DACA")
const INK := Color("4A3B30")
const INK_SOFT := Color("8C7A6A")
const VEIL := Color("1E1510", 0.74)
const POOR := Color("C9614B")

## Kept for compatibility: the category row (one button per category).
var category_buttons: BoxContainer
## The upgrade button of the first card, or a disabled placeholder for
## categories that are not implemented yet.
var upgrade_button: Button

var _selected_category_id: StringName
var _frame: PanelContainer
var _subtitle: Label
var _ore_label: Label
var _content: Control
var _message: Label
var _message_time: float = 0.0
var _cards: Dictionary = {}
var _open_tween: Tween
var _research_tree_view: ResearchTreeView
## Every visit until it is researched: a tip recommending the Energy tree
## root (ProgressionStore "lab_hints"."energy_tip_shown" only records that it
## has been seen at least once).
const HINT_SECTION: StringName = &"lab_hints"
const ENERGY_TIP_RESEARCH: StringName = &"energy_install_slot_unlock"
## The tip below is now shown by TutorialGuide instead (kept for reference).
const ENERGY_TIP_MERGED_INTO_GUIDE: bool = true
var energy_tip: PanelContainer
## Category the content was last built for (scroll is kept while unchanged).
var _last_built_category: StringName = &""

const ScrollKeeper := preload("res://Scripts/UI/ScrollKeeper.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	LanguageManager.language_changed.connect(func(_locale: StringName) -> void:
		_build_categories()
		_refresh_category()
	)
	_build_frame()
	ResearchManager.research_level_changed.connect(_on_research_level_changed)
	ResearchManager.purchase_failed.connect(_on_purchase_failed)
	ResourceManager.stored_ore_changed.connect(_on_stored_ore_changed)
	_build_categories()
	_on_stored_ore_changed(ResourceManager.stored_ore)


func _process(delta: float) -> void:
	_update_coins(delta)
	if _message_time > 0.0:
		_message_time -= delta
		_message.modulate.a = clampf(_message_time / 0.4, 0.0, 1.0)
		_message.visible = _message_time > 0.0


func open_panel() -> void:
	show()
	_refresh_category()
	_maybe_show_energy_tip()
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	modulate.a = 0.0
	_frame.pivot_offset = _frame.size * 0.5
	_frame.scale = Vector2.ONE * 0.96
	_open_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_open_tween.tween_property(_frame, "scale", Vector2.ONE, 0.22)


func close_panel() -> void:
	hide()


# ==========================================
# First-visit tip: buy Energy Core first
# ==========================================

func _maybe_show_energy_tip() -> void:
	if energy_tip != null and is_instance_valid(energy_tip):
		return
	# Merged into the base TutorialGuide (Laboratory part) by user request:
	# the guide now leads to ENERGY MODULE EXPANSION on every visit.
	if ENERGY_TIP_MERGED_INTO_GUIDE:
		return
	if ResearchManager.get_definition(ENERGY_TIP_RESEARCH) == null or ResearchManager.is_research_completed(ENERGY_TIP_RESEARCH):
		return
	var section := ProgressionStore.get_section(HINT_SECTION)
	section["energy_tip_shown"] = true
	ProgressionStore.set_section(HINT_SECTION, section)
	_build_energy_tip()


func _build_energy_tip() -> void:
	energy_tip = PanelContainer.new()
	var style := Palette.make_panel_style(Color(Palette.UI_PANEL, 0.98), 12, 18.0, 14.0)
	style.border_width_top = 3
	style.border_color = Palette.ACCENT
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 12
	energy_tip.add_theme_stylebox_override("panel", style)
	energy_tip.mouse_filter = Control.MOUSE_FILTER_STOP
	# Over the top of the project area (right of the category rail).
	energy_tip.set_anchors_preset(Control.PRESET_CENTER)
	energy_tip.offset_left = -PANEL_SIZE.x * 0.5 + 24.0 + RAIL_WIDTH + 44.0
	energy_tip.offset_right = PANEL_SIZE.x * 0.5 - 48.0
	energy_tip.offset_top = -PANEL_SIZE.y * 0.5 + 84.0
	energy_tip.offset_bottom = energy_tip.offset_top
	add_child(energy_tip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	energy_tip.add_child(row)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.ACCENT, 8, 9.0, 5.0))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(_label("TIP", 13, Palette.UI_PANEL))
	row.add_child(badge)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	row.add_child(column)
	column.add_child(_label("POWER FIRST", 16, Palette.UI_TEXT))
	var body := _label(tr("Research ENERGY MODULE EXPANSION for free in Energy. A second battery means more Power for more turrets, and it leads to farther planets."), 12, Palette.UI_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(300.0, 0.0)
	column.add_child(body)
	var show_me := Button.new()
	show_me.text = "SHOW ME"
	show_me.focus_mode = Control.FOCUS_NONE
	show_me.custom_minimum_size = Vector2(104.0, 36.0)
	show_me.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	show_me.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ResearchCard.style_button(show_me, &"primary")
	show_me.add_theme_font_size_override("font_size", 12)
	show_me.pressed.connect(show_energy_tip_target)
	row.add_child(show_me)
	var later := Button.new()
	later.text = "LATER"
	later.flat = true
	later.focus_mode = Control.FOCUS_NONE
	later.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	later.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	later.add_theme_font_size_override("font_size", 11)
	later.add_theme_color_override("font_color", Palette.UI_MUTED)
	later.add_theme_color_override("font_hover_color", Palette.UI_TEXT)
	later.pressed.connect(dismiss_energy_tip)
	row.add_child(later)


## SHOW ME: open the Energy category with the tip's research selected.
func show_energy_tip_target() -> void:
	dismiss_energy_tip()
	_select_category(&"energy")
	if is_instance_valid(_research_tree_view):
		_research_tree_view.select_node(ENERGY_TIP_RESEARCH)


func dismiss_energy_tip() -> void:
	if energy_tip != null and is_instance_valid(energy_tip):
		energy_tip.queue_free()
	energy_tip = null


## Clicking the dimmed area around the panel closes the laboratory.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if not _frame.get_global_rect().has_point((event as InputEventMouseButton).global_position):
			close_requested.emit()
			accept_event()


# ==========================================
# Frame (built once)
# ==========================================

func _build_frame() -> void:
	var dim := ColorRect.new()
	dim.color = VEIL
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_frame = PanelContainer.new()
	# No panel: everything sits directly on the warm veil.
	_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.custom_minimum_size = PANEL_SIZE
	_frame.offset_left = -PANEL_SIZE.x * 0.5
	_frame.offset_right = PANEL_SIZE.x * 0.5
	_frame.offset_top = -PANEL_SIZE.y * 0.5
	_frame.offset_bottom = PANEL_SIZE.y * 0.5
	add_child(_frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_frame.add_child(column)

	# Header.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	header.add_child(_label("LABORATORY", 26, CREAM))
	_subtitle = _label("", 14, Color(CREAM, 0.55))
	_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_subtitle)
	var ore_pill := PanelContainer.new()
	ore_pill.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	header.add_child(ore_pill)
	var ore_row := HBoxContainer.new()
	ore_row.add_theme_constant_override("separation", 8)
	ore_pill.add_child(ore_row)
	var gem := OreGem.new()
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ore_row.add_child(gem)
	_ore_label = _label("0", 20, Palette.GOLD)
	ore_row.add_child(_ore_label)
	ore_row.add_child(_label("ORE", 12, Color(CREAM, 0.55)))
	var close := Button.new()
	close.text = "ESC"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(60.0, 38.0)
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_font_size_override("font_size", 13)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		close.add_theme_color_override(color_name, INK)
	for state in ["normal", "hover", "pressed"]:
		var button_style := Palette.make_panel_style(CREAM if state != "normal" else Color(CREAM, 0.85), 19)
		button_style.border_width_bottom = 3
		button_style.border_color = CREAM_DARK
		close.add_theme_stylebox_override(state, button_style)
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)

	# Body: the row of round category icons, then the project area.
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	category_buttons = HBoxContainer.new()
	category_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	category_buttons.add_theme_constant_override("separation", 12)
	body.add_child(category_buttons)
	_content = MarginContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)

	_message = _label("", 13, Palette.THREAT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.visible = false
	column.add_child(_message)


# ==========================================
# Categories
# ==========================================

func _build_categories() -> void:
	for child in category_buttons.get_children():
		category_buttons.remove_child(child)
		child.queue_free()
	var first_enabled: StringName
	for category in ResearchManager.get_categories():
		if category == null or not category.enabled or category.category_id == &"chips":
			continue
		if first_enabled.is_empty():
			first_enabled = category.category_id
		var button := CategoryButton.new()
		var project_count := ResearchManager.get_definitions_for_category(category.category_id).size()
		button.setup(category, project_count)
		button.pressed.connect(_select_category.bind(category.category_id))
		category_buttons.add_child(button)
	if _selected_category_id.is_empty():
		_selected_category_id = first_enabled
	_update_category_button_states()


func _select_category(category_id: StringName) -> void:
	_selected_category_id = category_id
	_update_category_button_states()
	_refresh_category()
	_fit_frame.call_deferred()


func _update_category_button_states() -> void:
	for child in category_buttons.get_children():
		var button := child as CategoryButton
		if button != null:
			button.set_selected(button.category_id == _selected_category_id)


# ==========================================
# Project cards
# ==========================================

func _refresh_category() -> void:
	# Rebuilding the same category (crafting, upgrading...) keeps the scroll
	# position; switching category starts at the top.
	var kept: Array = ScrollKeeper.capture(_content) if _selected_category_id == _last_built_category else []
	_last_built_category = _selected_category_id
	_build_category_content()
	ScrollKeeper.restore(_content, kept)


func _build_category_content() -> void:
	_research_tree_view = null
	# Remove right away so the old cards never count toward the panel's size.
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_cards.clear()
	upgrade_button = null
	var category := ResearchManager.configuration.get_category(_selected_category_id)
	if category == null:
		_show_placeholder("NO CATEGORY", "")
		return
	_subtitle.text = tr("·  %s RESEARCH") % tr(category.display_name.to_upper())
	if not category.implemented:
		_show_placeholder("COMING SOON", category.description)
		return
	var tree := ResearchManager.configuration.get_tree(_selected_category_id)
	if tree != null:
		# The tree view scrolls itself and keeps its detail strip pinned below.
		_research_tree_view = ResearchTreeView.new()
		_content.add_child(_research_tree_view)
		_research_tree_view.setup(tree)
		_research_tree_view.message_requested.connect(_on_tree_message)
		return
	var definitions := ResearchManager.get_definitions_for_category(_selected_category_id)
	if definitions.is_empty():
		_show_placeholder("NO PROJECTS YET", "No research projects are configured for this category.")
		return

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	center.add_child(grid)
	for definition in definitions:
		var card := ResearchCard.new()
		card.custom_minimum_size = CARD_SIZE
		grid.add_child(card)
		card.setup(definition)
		card.upgrade_pressed.connect(_on_upgrade_pressed)
		card.appear(0.05 * float(_cards.size()))
		_cards[definition.research_id] = card
		if upgrade_button == null:
			upgrade_button = card.button


## Keeps the frame at PANEL_SIZE, centered, whatever the content was before.
func _fit_frame() -> void:
	_frame.size = PANEL_SIZE
	_frame.offset_left = -PANEL_SIZE.x * 0.5
	_frame.offset_right = PANEL_SIZE.x * 0.5
	_frame.offset_top = -PANEL_SIZE.y * 0.5
	_frame.offset_bottom = PANEL_SIZE.y * 0.5


func _show_placeholder(title: String, description: String) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_content.add_child(box)
	var icon := LockGlyph.new()
	icon.custom_minimum_size = Vector2(64.0, 64.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var heading := _label(title, 22, Palette.UI_TEXT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	if description != "":
		var text := _label(description, 14, Palette.UI_MUTED)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(420.0, 0.0)
		text.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(text)
	upgrade_button = Button.new()
	upgrade_button.text = "LOCKED"
	upgrade_button.disabled = true
	upgrade_button.focus_mode = Control.FOCUS_NONE
	upgrade_button.custom_minimum_size = Vector2(240.0, 48.0)
	upgrade_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ResearchCard.style_button(upgrade_button, &"locked")
	box.add_child(upgrade_button)


func _on_upgrade_pressed(research_id: StringName) -> void:
	if ResearchManager.purchase_research(research_id):
		var card := _cards.get(research_id) as ResearchCard
		if card != null:
			_fly_coins(card)
			card.play_upgrade_flash.call_deferred()


# ==========================================
# Motion: ore flying into a card on purchase
# ==========================================

var _fx: Control
var _coins: Array = []
var _ore_punch: float = 0.0


func _fly_coins(card: Control) -> void:
	if _fx == null:
		_fx = Control.new()
		_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fx.draw.connect(_draw_coins)
		add_child(_fx)
	var to_local := _fx.get_global_transform().affine_inverse()
	var from := to_local * _ore_label.get_global_rect().get_center()
	var to := to_local * (card.get_global_rect().get_center() + Vector2(0.0, -20.0))
	for k in range(9):
		_coins.append({"from": from, "to": to, "t": -0.04 * float(k), "bend": randf_range(-90.0, 90.0), "spin": randf() * TAU})
	_ore_punch = 1.0


func _update_coins(delta: float) -> void:
	if _ore_punch > 0.0:
		_ore_punch = maxf(_ore_punch - delta * 4.0, 0.0)
		_ore_label.pivot_offset = _ore_label.size * 0.5
		_ore_label.scale = Vector2.ONE * (1.0 + 0.25 * sin(PI * _ore_punch))
	if _coins.is_empty():
		return
	for coin in _coins:
		coin["t"] = float(coin["t"]) + delta / 0.45
	_coins = _coins.filter(func(c: Dictionary) -> bool: return float(c["t"]) < 1.0)
	_fx.queue_redraw()


func _draw_coins() -> void:
	for coin in _coins:
		var t := float(coin["t"])
		if t < 0.0:
			continue
		var k := t * t * (3.0 - 2.0 * t)
		var from: Vector2 = coin["from"]
		var to: Vector2 = coin["to"]
		var side := (to - from).orthogonal().normalized() * float(coin["bend"])
		var p := from.lerp(to, k) + side * sin(PI * k)
		var r := lerpf(7.0, 4.0, k)
		var spin := float(coin["spin"]) + t * 9.0
		var w := absf(cos(spin)) * r * 0.7 + r * 0.3
		_fx.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(w, 0), p + Vector2(0, r), p + Vector2(-w, 0)]), Palette.GOLD)
		_fx.draw_circle(p, r * 1.8, Color(Palette.GOLD, 0.15))


func _on_research_level_changed(research_id: StringName, _level: int) -> void:
	ModuleCatalog.clear_stats_cache()
	if is_instance_valid(_research_tree_view):
		_research_tree_view.refresh.call_deferred()
	var card := _cards.get(research_id) as ResearchCard
	if card != null:
		card.refresh()


func _on_purchase_failed(_research_id: StringName, reason: String) -> void:
	_message.add_theme_color_override("font_color", Palette.THREAT)
	_message.text = reason.to_upper()
	_message_time = 2.2
	_message.visible = true


func _on_stored_ore_changed(amount: float) -> void:
	_ore_label.text = _thousands(floori(amount))
	if is_instance_valid(_research_tree_view):
		_research_tree_view.refresh.call_deferred()
	for card in _cards.values():
		(card as ResearchCard).refresh()


func _on_tree_message(message: String) -> void:
	_message.text = message
	_message_time = 2.2
	_message.visible = true


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

## Category button: a round cream icon; the selected one gets an orange ring
## and its name underneath (hover shows the name too).
class CategoryButton:
	extends Button

	var category_id: StringName
	var _implemented: bool = false
	var _selected: bool = false
	var _name: String = ""
	var _status: String = ""

	func setup(category: ResearchCategory, project_count: int) -> void:
		category_id = category.category_id
		_implemented = category.implemented
		_name = tr(category.display_name)
		_status = (tr("%d PROJECTS") % project_count) if _implemented else tr("COMING SOON")
		custom_minimum_size = Vector2(84.0, 84.0)
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		flat = true
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		tooltip_text = "%s\n%s" % [_name, category.description]
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	var _hover: float = 0.0
	var _ring: float = 0.0

	func set_selected(selected: bool) -> void:
		if selected and not _selected:
			_ring = 0.0
		_selected = selected
		queue_redraw()

	func _process(delta: float) -> void:
		var target := 1.0 if is_hovered() and _implemented else 0.0
		var ring_target := 1.0 if _selected else 0.0
		if is_equal_approx(_hover, target) and is_equal_approx(_ring, ring_target):
			return
		_hover = move_toward(_hover, target, delta / 0.12)
		_ring = move_toward(_ring, ring_target, delta / 0.25)
		queue_redraw()

	func _draw() -> void:
		var hovered := is_hovered()
		var lift := 3.0 * _hover
		var center := Vector2(size.x * 0.5, 30.0 - lift)
		var radius := 25.0 + 2.0 * _hover
		var alpha := 1.0 if _selected else (0.55 + 0.3 * _hover if _implemented else 0.25)
		draw_circle(center + Vector2(0.0, 3.0 + lift), radius, Color(0, 0, 0, 0.2))
		draw_circle(center, radius, Color(LaboratoryPanel.CREAM, alpha))
		if _ring > 0.0:
			# The selection ring sweeps round when a tab is picked.
			var sweep := 1.0 - pow(1.0 - _ring, 3.0)
			draw_arc(center, radius + 4.5, -PI * 0.5, -PI * 0.5 + TAU * sweep, 48, Palette.ACCENT, 3.0, true)
		var glyph_color: Color = LaboratoryPanel.INK if _selected or hovered else LaboratoryPanel.INK_SOFT
		if _implemented:
			LaboratoryPanel.draw_category_glyph(self, category_id, center, glyph_color)
		else:
			LaboratoryPanel.draw_lock(self, center + Vector2(0.0, 1.0), 0.7, glyph_color)
		if _selected or hovered:
			var font := get_theme_default_font()
			draw_string(font, Vector2(-20.0, 78.0), _name, HORIZONTAL_ALIGNMENT_CENTER, size.x + 40.0, 13,
					Color(LaboratoryPanel.CREAM, 1.0 if _selected else 0.7))


## One research project: icon, values, level bar, upgrade button.
class ResearchCard:
	extends PanelContainer

	signal upgrade_pressed(research_id: StringName)

	var button: Button
	var _definition: ResearchDefinition
	var _level_label: Label
	var _now_label: Label
	var _arrow_label: Label
	var _next_label: Label
	var _pips: LevelPips
	var _slot_label: Label
	var _milestone_label: Label
	var _flash: float = 0.0
	var _sparks: Array[Dictionary] = []
	var _details: VBoxContainer
	var _hover: float = 0.0
	var _style_hovered: bool = false
	## 0 -> 1 pop-in (tweened by appear()); _bump: purchase squash 1 -> 0.
	var _appear: float = 1.0
	var _bump: float = 0.0
	var _button_scale: float = 1.0

	## Pop in after `delay` seconds (fade + grow with a little overshoot).
	func appear(delay: float) -> void:
		_appear = 0.0
		modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(self, "_appear", 1.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## Cream card with a soft drop shadow and a darker lip at the bottom;
	## hovered: orange outline. Locked / maxed cards are a little greyer.
	func _apply_card_style(hovered: bool) -> void:
		_style_hovered = hovered
		var locked := button != null and button.disabled and button.text == "LOCKED"
		var style := Palette.make_panel_style(LaboratoryPanel.CREAM_LOCKED if locked else LaboratoryPanel.CREAM, 22, 16.0, 14.0)
		style.border_width_bottom = 5
		style.border_color = LaboratoryPanel.CREAM_DARK
		if hovered:
			style.set_border_width_all(3)
			style.border_width_bottom = 5
			style.border_color = Palette.ACCENT
		style.shadow_color = Color(0, 0, 0, 0.24)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0.0, 6.0)
		add_theme_stylebox_override("panel", style)


	func setup(definition: ResearchDefinition) -> void:
		_definition = definition
		_apply_card_style(false)
		tooltip_text = tr(definition.description)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		add_child(column)

		# Level badge, top right.
		var top := HBoxContainer.new()
		top.alignment = BoxContainer.ALIGNMENT_END
		column.add_child(top)
		var badge := PanelContainer.new()
		var badge_style := Palette.make_panel_style(LaboratoryPanel.INK, 14, 10.0, 3.0)
		badge.add_theme_stylebox_override("panel", badge_style)
		top.add_child(badge)
		_level_label = _make_label("", 13, LaboratoryPanel.CREAM)
		_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(_level_label)

		# The module's real art, big and centred.
		var icon := ModuleIcon.new()
		icon.show_backdrop = false
		icon.setup(definition.target_id, 96.0, 1.2)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)

		var title := _make_label(_title_text(), 17, LaboratoryPanel.INK)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.clip_text = true
		column.add_child(title)
		var values := HBoxContainer.new()
		values.alignment = BoxContainer.ALIGNMENT_CENTER
		values.add_theme_constant_override("separation", 8)
		column.add_child(values)
		_now_label = _make_label("", 24, LaboratoryPanel.INK)
		values.add_child(_now_label)
		_arrow_label = _make_label("→", 18, LaboratoryPanel.INK_SOFT)
		_arrow_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		values.add_child(_arrow_label)
		_next_label = _make_label("", 24, Palette.ACCENT)
		values.add_child(_next_label)
		var stat := _make_label(_stat_text(), 11, LaboratoryPanel.INK_SOFT)
		stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(stat)

		# Details fade in on hover (level track, artifact slots, next milestone).
		_details = VBoxContainer.new()
		_details.add_theme_constant_override("separation", 2)
		_details.modulate.a = 0.0
		column.add_child(_details)
		_pips = LevelPips.new()
		_pips.custom_minimum_size = Vector2(0.0, 30.0)
		_details.add_child(_pips)
		_slot_label = _make_label("", 10, LaboratoryPanel.INK_SOFT)
		_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_slot_label.custom_minimum_size = Vector2(LaboratoryPanel.CARD_SIZE.x - 36.0, 0.0)
		_details.add_child(_slot_label)
		_milestone_label = _make_label("", 10, Color("B9801E"))
		_milestone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_milestone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_milestone_label.custom_minimum_size = Vector2(LaboratoryPanel.CARD_SIZE.x - 36.0, 0.0)
		_milestone_label.visible = false
		_details.add_child(_milestone_label)

		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(spacer)
		button = Button.new()
		button.custom_minimum_size = Vector2(0.0, 42.0)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func() -> void: upgrade_pressed.emit(_definition.research_id))
		column.add_child(button)
		refresh()

	func refresh() -> void:
		if _definition == null:
			return
		var level: int = ResearchManager.get_level(_definition.research_id)
		var max_level: int = _definition.max_level
		var maxed := level >= max_level
		var module_limit_effect := (
			_definition.effect as ModuleInstallationLimitResearchEffect
		)
		if module_limit_effect != null:
			_refresh_module_limit(
				module_limit_effect,
				level,
				max_level,
				maxed
			)
			return

		_level_label.text = "LV %d" % level
		_level_label.add_theme_color_override("font_color", Color("F2D27A") if maxed else LaboratoryPanel.CREAM)
		var now: float = _damage_for(level)
		_now_label.text = ModuleCatalog.format_number(now)
		_now_label.add_theme_color_override("font_color", Color("B9801E") if maxed else LaboratoryPanel.INK)
		_arrow_label.visible = not maxed
		_next_label.visible = not maxed
		if not maxed:
			_next_label.text = ModuleCatalog.format_number(_damage_for(level + 1))
		_pips.set_values(level, max_level, maxed, _artifact_milestone_levels())
		var is_shield_research := _definition.effect is ModuleStatResearchEffect
		var module_unlocked := ModuleCatalog.is_module_unlocked(_definition.target_id)
		var unlocked_slots := (
			ResearchManager.get_shield_artifact_slot_count(_definition.target_id)
			if is_shield_research
			else ResearchManager.get_weapon_artifact_slot_count(_definition.target_id)
		)
		var maximum_slots := ArtifactManager.MODULE_SLOT_COUNT
		if not module_unlocked:
			_slot_label.text = tr("REQUIRES: %s") % tr(ModuleCatalog.get_unlock_requirement(_definition.target_id).to_upper())
			_slot_label.add_theme_color_override("font_color", LaboratoryPanel.INK_SOFT)
		else:
			_slot_label.text = tr("%d / %d ARTIFACT SLOTS") % [unlocked_slots, maximum_slots]
			_slot_label.add_theme_color_override("font_color", Color("B9801E") if unlocked_slots > 0 else LaboratoryPanel.INK_SOFT)
		var next_milestone: ResearchMilestone = (
			_definition.get_milestone(level + 1) if not maxed else null
		)
		_milestone_label.visible = next_milestone != null and not next_milestone.display_text.is_empty()
		if _milestone_label.visible:
			_milestone_label.text = tr(next_milestone.display_text.to_upper())

		var cost: int = ResearchManager.get_upgrade_cost(_definition.research_id)
		var cost_text := LaboratoryPanel._thousands(cost)
		if maxed:
			ResearchCard.style_button(button, &"max")
			button.text = "MAX LEVEL"
			button.disabled = true
		elif not ResearchManager.is_unlocked(_definition.research_id) or not _requirements_met():
			ResearchCard.style_button(button, &"locked")
			button.text = "LOCKED"
			button.disabled = true
		elif next_milestone != null:
			ResearchCard.style_button(button, &"primary" if ResourceManager.stored_ore >= float(cost) else &"poor")
			button.text = tr("UPGRADE TO LEVEL %d — ◆ %s ORE") % [level + 1, cost_text]
			button.disabled = ResourceManager.stored_ore < float(cost)
		elif ResourceManager.stored_ore < float(cost):
			ResearchCard.style_button(button, &"poor")
			button.text = tr("NEED MORE ORE     ◆ %s") % cost_text
			button.disabled = true
		else:
			ResearchCard.style_button(button, &"primary")
			button.text = tr("UPGRADE     ◆ %s") % cost_text
			button.disabled = false
		_apply_card_style(_style_hovered)

	func _refresh_module_limit(
		effect: ModuleInstallationLimitResearchEffect,
		level: int,
		max_level: int,
		maxed: bool
	) -> void:
		_level_label.text = "COMPLETE" if maxed else "LOCKED"
		_level_label.add_theme_color_override(
			"font_color",
			Color("F2D27A") if maxed else LaboratoryPanel.CREAM
		)
		var current_limit := effect.get_installation_limit(level)
		_now_label.text = "%d / %d" % [
			current_limit,
			effect.unlocked_installation_limit,
		]
		_now_label.add_theme_color_override(
			"font_color",
			Color("B9801E") if maxed else LaboratoryPanel.INK
		)
		_arrow_label.visible = not maxed
		_next_label.visible = not maxed
		if not maxed:
			_next_label.text = "%d / %d" % [
				effect.unlocked_installation_limit,
				effect.unlocked_installation_limit,
			]
		_pips.set_values(level, max_level, maxed)
		_slot_label.text = "STATUS: UNLOCKED" if maxed else "ONE-TIME INSTALLATION UNLOCK"
		_slot_label.add_theme_color_override(
			"font_color",
			Color("B9801E") if maxed else LaboratoryPanel.INK_SOFT
		)

		var cost := ResearchManager.get_upgrade_cost(_definition.research_id)
		var cost_text := LaboratoryPanel._thousands(cost)
		_milestone_label.visible = not maxed
		_milestone_label.text = tr("UNLOCK COST: FREE") if cost == 0 else tr("UNLOCK COST: %s ORE") % cost_text
		if maxed:
			ResearchCard.style_button(button, &"max")
			button.text = "UNLOCKED"
			button.disabled = true
		elif not ResearchManager.is_unlocked(_definition.research_id) or not _requirements_met():
			ResearchCard.style_button(button, &"locked")
			button.text = "LOCKED"
			button.disabled = true
		else:
			var affordable := ResourceManager.stored_ore >= float(cost)
			ResearchCard.style_button(button, &"primary" if affordable else &"poor")
			button.text = tr("%s — FREE") % tr(effect.purchase_button_text.to_upper()) if cost == 0 else "%s — ◆ %s ORE" % [
				effect.purchase_button_text.to_upper(),
				cost_text,
			]
			button.disabled = not affordable
		_apply_card_style(_style_hovered)

	func play_upgrade_flash() -> void:
		_bump = 1.0
		_flash = 0.5
		_sparks.clear()
		var origin := Vector2(size.x * 0.55, size.y * 0.62)
		for index in range(10):
			var angle := randf_range(-PI * 0.9, -PI * 0.1)
			_sparks.append({"pos": origin, "vel": Vector2.RIGHT.rotated(angle) * randf_range(80.0, 180.0), "size": randf_range(3.0, 5.5)})

	func _process(delta: float) -> void:
		# Hover: details fade in, outline on, the card lifts a little.
		var hovered := is_visible_in_tree() and get_global_rect().has_point(get_global_mouse_position())
		_hover = move_toward(_hover, 1.0 if hovered else 0.0, delta / 0.15)
		if _details != null:
			_details.modulate.a = _hover
		if hovered != _style_hovered:
			_apply_card_style(hovered)
		_bump = maxf(_bump - delta * 3.0, 0.0)
		var ease_hover := _hover * _hover * (3.0 - 2.0 * _hover)
		pivot_offset = size * 0.5
		scale = Vector2.ONE * (lerpf(0.86, 1.0, _appear) * (1.0 + 0.03 * ease_hover) + 0.07 * sin(PI * _bump))
		modulate.a = clampf(_appear * 1.4, 0.0, 1.0)
		# Button: grows on hover, squashes while pressed.
		if button != null:
			var target := 1.0
			if not button.disabled:
				if button.is_pressed():
					target = 0.94
				elif button.is_hovered():
					target = 1.04
			_button_scale = lerpf(_button_scale, target, minf(delta * 18.0, 1.0))
			button.pivot_offset = button.size * 0.5
			button.scale = Vector2.ONE * _button_scale
		if _next_label != null and _bump > 0.0:
			_next_label.pivot_offset = _next_label.size * 0.5
			_next_label.scale = Vector2.ONE * (1.0 + 0.5 * sin(PI * _bump))
		if _flash <= 0.0 and _sparks.is_empty():
			return
		_flash = maxf(_flash - delta, 0.0)
		for spark in _sparks:
			spark["pos"] += spark["vel"] * delta
			spark["vel"] += Vector2(0.0, 320.0) * delta
		if _flash <= 0.0:
			_sparks.clear()
		queue_redraw()

	func _draw() -> void:
		if _flash <= 0.0:
			return
		var alpha: float = clampf(_flash / 0.5, 0.0, 1.0)
		var border := Palette.rounded_rect_points(Rect2(Vector2.ZERO, size).grow(-1.5), 22.0)
		border.append(border[0])
		draw_polyline(border, Color(Palette.ACCENT, alpha), 3.0)
		for spark in _sparks:
			var s: float = spark["size"]
			var p: Vector2 = spark["pos"]
			draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, -s * 1.6), p + Vector2(s, 0.0), p + Vector2(0.0, s * 1.6), p + Vector2(-s, 0.0)]), Color(Palette.GOLD, alpha))
		var font := get_theme_default_font()
		draw_string(font, Vector2(0.0, size.y * 0.42 - (1.0 - alpha) * 22.0), "+1 LV",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(Palette.ACCENT, alpha))

	## Research levels whose milestone grants an artifact slot (Lv 10 / 20 / 30).
	func _artifact_milestone_levels() -> Array[int]:
		var levels: Array[int] = []
		for milestone in _definition.milestones:
			if milestone != null and (milestone.weapon_chip_slots_unlocked > 0 or milestone.module_chip_slots_unlocked > 0):
				levels.append(milestone.target_level)
		levels.sort()
		return levels

	func _requirements_met() -> bool:
		for requirement in _definition.unlock_requirements:
			if not ResearchManager.is_unlocked(requirement):
				return false
		return true

	## Preview from the untouched base stat; runtime uses the same additive ratio.
	func _damage_for(level: int) -> float:
		var effect := _definition.effect as WeaponDamageResearchEffect
		if effect != null:
			var base_damage := ModuleCatalog.get_base_weapon_damage(_definition.target_id)
			return effect.get_damage_for_level(base_damage, level)
		var module_effect := _definition.effect as ModuleStatResearchEffect
		if module_effect != null:
			var stats := ModuleCatalog.get_stats(_definition.target_id)
			var property_name := "knockback_damage" if module_effect.stat_id == &"shockwave_damage" else String(module_effect.stat_id)
			return module_effect.get_value_for_level(float(stats.get(property_name, 0.0)), level)
		return 0.0

	func _title_text() -> String:
		if _definition.effect is ModuleInstallationLimitResearchEffect:
			return tr(_definition.display_name).to_upper()
		for entry in ModuleCatalog.ENTRIES:
			if entry["id"] == _definition.target_id:
				return tr(String(entry["name"]))
		return tr(_definition.display_name)

	func _stat_text() -> String:
		if _definition.effect is WeaponDamageResearchEffect:
			return "DAMAGE"
		if _definition.effect is ModuleStatResearchEffect:
			return "SHOCKWAVE DAMAGE" if (_definition.effect as ModuleStatResearchEffect).stat_id == &"shockwave_damage" else "HEALING PER PULSE"
		if _definition.effect is ModuleInstallationLimitResearchEffect:
			return "CURRENT LIMIT"
		return _definition.display_name.to_upper()

	func _make_label(text: String, font_size: int, color: Color) -> Label:
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", color)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return label

	static func style_button(target: Button, kind: StringName) -> void:
		# primary: orange pill with a lip; poor / locked / max: quiet text.
		var base_color: Color = Palette.ACCENT
		var text_color: Color = Color("3A2410")
		match kind:
			&"poor":
				base_color = Color(0, 0, 0, 0)
				text_color = LaboratoryPanel.POOR
			&"locked":
				base_color = Color(0, 0, 0, 0)
				text_color = LaboratoryPanel.INK_SOFT
			&"max":
				base_color = Color(0, 0, 0, 0)
				text_color = Color("B9801E")
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := Palette.make_panel_style(base_color, 21)
			if kind == &"primary":
				style.border_width_bottom = 4
				style.border_color = Color("B8641A")
				if state == "hover":
					style.bg_color = Palette.ACCENT.lightened(0.12)
				elif state == "pressed":
					style.bg_color = Palette.ACCENT.darkened(0.1)
			target.add_theme_stylebox_override(state, style)
		target.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			target.add_theme_color_override(color_name, text_color)
		target.add_theme_font_size_override("font_size", 13)


## Slanted level segments (gold when maxed).
class LevelPips:
	extends Control

	## Long research tracks are shown one 10-level tier at a time. The tier's
	## last segment ends in an artifact gem when that level unlocks a slot,
	## so the next reward is always in view.
	const TIER_SIZE: int = 10
	const ARTIFACT_SPACE: float = 34.0

	var _level: int = 0
	var _max_level: int = 10
	var _maxed: bool = false
	var _artifact_levels: Array[int] = []

	func set_values(level: int, max_level: int, maxed: bool, artifact_levels: Array[int] = []) -> void:
		_level = level
		_max_level = maxi(max_level, 1)
		_maxed = maxed
		_artifact_levels = artifact_levels
		queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		var tiered := _max_level > TIER_SIZE
		var tier_count := ceili(float(_max_level) / float(TIER_SIZE)) if tiered else 1
		var tier := mini(_level / TIER_SIZE, tier_count - 1) if tiered else 0
		if _maxed:
			tier = tier_count - 1
		var first := tier * TIER_SIZE if tiered else 0
		var last := mini(first + TIER_SIZE, _max_level) if tiered else _max_level
		var segments := last - first
		var filled := clampi(_level - first, 0, segments)
		var artifact_at := last if _artifact_levels.has(last) else -1
		var bar_width := size.x - (ARTIFACT_SPACE if artifact_at > 0 else 0.0)
		var bar_height := 12.0
		var bar_y := 0.0

		var gap: float = 4.0
		var width: float = (bar_width - gap * float(segments - 1)) / float(maxi(segments, 1))
		for index in range(segments):
			var x: float = float(index) * (width + gap)
			var color: Color = (Palette.GOLD if _maxed else Palette.ACCENT) if index < filled else LaboratoryPanel.CREAM_DARK
			draw_colored_polygon(PackedVector2Array([
				Vector2(x + 3.0, bar_y), Vector2(x + width, bar_y), Vector2(x + width - 3.0, bar_y + bar_height), Vector2(x, bar_y + bar_height),
			]), color)

		if tiered:
			var caption := "LV %d – %d" % [first + 1, last]
			draw_string(font, Vector2(0.0, bar_y + bar_height + 15.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LaboratoryPanel.INK_SOFT)
			# Small tier dots: done / current / ahead.
			for index in range(tier_count):
				var dot := Vector2(bar_width - float(tier_count - index) * 12.0 + 4.0, bar_y + bar_height + 11.0)
				var done := index < tier or (_maxed and index == tier)
				draw_circle(dot, 3.2, Palette.GOLD if done else (Palette.ACCENT if index == tier else LaboratoryPanel.CREAM_DARK))

		if artifact_at > 0:
			var earned := _level >= artifact_at
			_draw_artifact_reward(Vector2(size.x - ARTIFACT_SPACE * 0.5 + 2.0, bar_y + bar_height * 0.5 + 1.0), earned)
			draw_string(font, Vector2(size.x - ARTIFACT_SPACE, bar_y + bar_height + 15.0), "LV %d" % artifact_at, HORIZONTAL_ALIGNMENT_CENTER, ARTIFACT_SPACE + 4.0, 9, Palette.GOLD if not earned else Palette.UI_MUTED)

	## Gold artifact gem at the end of the tier.
	func _draw_artifact_reward(center: Vector2, earned: bool) -> void:
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.004)
		if not earned:
			draw_circle(center, 13.0 + 2.0 * pulse, Color(Palette.GOLD, 0.12 + 0.12 * pulse))
		var gem_color := Palette.GOLD if earned else Palette.GOLD_SHADOW
		var gem := PackedVector2Array([
			center + Vector2(0.0, -10.0), center + Vector2(8.0, -2.0),
			center + Vector2(5.0, 8.0), center + Vector2(-5.0, 8.0),
			center + Vector2(-8.0, -2.0),
		])
		draw_colored_polygon(gem, gem_color)
		draw_polyline(PackedVector2Array([gem[0], gem[1], gem[2], gem[3], gem[4], gem[0]]), Palette.MECH, 1.5)
		draw_colored_polygon(PackedVector2Array([gem[0], gem[1], center, gem[4]]), Color(1.0, 1.0, 1.0, 0.28))
		if earned:
			draw_polyline(PackedVector2Array([center + Vector2(-3.5, 0.0), center + Vector2(-1.0, 2.8), center + Vector2(3.8, -2.8)]), Palette.UI_PANEL, 2.0)

	func _process(_delta: float) -> void:
		if not _artifact_levels.is_empty() and is_visible_in_tree():
			queue_redraw()


class OreGem:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(14.0, 20.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var top := c + Vector2(0.0, -9.0)
		var right := c + Vector2(6.5, 0.0)
		var bottom := c + Vector2(0.0, 9.0)
		var left := c + Vector2(-6.5, 0.0)
		draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), Palette.GOLD_SHADOW)
		draw_colored_polygon(PackedVector2Array([top, right, c, left]), Palette.GOLD)


class LockGlyph:
	extends Control

	func _draw() -> void:
		var center := size * 0.5
		draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(6, size.x * 0.5, PI / 6.0), center), Palette.MECH)
		LaboratoryPanel.draw_lock(self, center + Vector2(0.0, 2.0), 1.4, Palette.UI_MUTED)


## Padlock glyph centered on center.
static func draw_lock(canvas: CanvasItem, center: Vector2, glyph_scale: float, color: Color) -> void:
	var s := glyph_scale
	canvas.draw_arc(center + Vector2(0.0, -4.0 * s), 5.0 * s, PI, TAU, 10, color, 2.2 * s)
	canvas.draw_line(center + Vector2(-5.0 * s, -4.0 * s), center + Vector2(-5.0 * s, -1.0 * s), color, 2.2 * s)
	canvas.draw_line(center + Vector2(5.0 * s, -4.0 * s), center + Vector2(5.0 * s, -1.0 * s), color, 2.2 * s)
	Palette.draw_rounded_rect(canvas, Rect2(center + Vector2(-7.0, -2.0) * s, Vector2(14.0, 11.0) * s), 2.0 * s, color)


## Simple glyph per category inside the rail badge.
static func draw_category_glyph(canvas: CanvasItem, category_id: StringName, center: Vector2, color: Color) -> void:
	match category_id:
		&"weapon":
			canvas.draw_arc(center, 7.0, 0.0, TAU, 16, color, 2.0)
			for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				canvas.draw_line(center + direction * 4.0, center + direction * 10.0, color, 2.0)
		&"fusion_weapon":
			# Two linked weapon cores communicate fusion without adding new art.
			canvas.draw_arc(center + Vector2(-4.5, 0.0), 6.0, 0.0, TAU, 16, color, 2.0)
			canvas.draw_arc(center + Vector2(4.5, 0.0), 6.0, 0.0, TAU, 16, color, 2.0)
			canvas.draw_line(center + Vector2(-1.5, -7.0), center + Vector2(1.5, 7.0), color, 2.0)
		&"energy":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(2.0, -9.0), center + Vector2(-5.0, 1.0), center + Vector2(0.0, 1.0),
				center + Vector2(-2.0, 9.0), center + Vector2(5.0, -1.0), center + Vector2(0.0, -1.0),
			]), color)
		&"mining":
			ResearchTreeView.draw_glyph(canvas, center, 0.9, &"mining", color)
		&"shield":
			ResearchTreeView.draw_glyph(canvas, center, 0.9, &"shielded", color)
		&"ship":
			for row in range(3):
				for column in range(3):
					canvas.draw_rect(Rect2(center + Vector2(-8.5 + 6.0 * column, -8.5 + 6.0 * row), Vector2(5.0, 5.0)), color)
		_:
			canvas.draw_circle(center, 4.0, color)
