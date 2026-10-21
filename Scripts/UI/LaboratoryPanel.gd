class_name LaboratoryPanel
extends Control

## Laboratory screen, design A "workbench cards".
##
## A dimmed full-screen layer with one centered panel:
## - header: title, stored ore, ESC;
## - left rail (category_buttons): every enabled research category; unfinished
##   ones show a lock and "COMING SOON";
## - right: one card per research project with the target's icon, current ->
##   next bonus, a level bar and an upgrade button priced in stored ore
##   (states: upgrade / need more ore / locked / max level). A purchase plays a
##   short "+1 LV" flash on the card.
## All rules and numbers come from ResearchManager / ResearchDefinition; this
## script only presents them and calls ResearchManager.purchase_research().

signal close_requested

const PANEL_SIZE := Vector2(1040.0, 610.0)
const RAIL_WIDTH: float = 200.0
const CARD_SIZE := Vector2(380.0, 270.0)

## Kept for compatibility: the category rail container (one button per category).
var category_buttons: VBoxContainer
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
var _selected_chip_id: StringName
## CRAFT button of the selected blueprint (null outside the chip category).
var craft_button: Button
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

const ChipVisual := preload("res://Scripts/UI/Chips/ChipVisual.gd")
const ScrollKeeper := preload("res://Scripts/UI/ScrollKeeper.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_frame()
	ResearchManager.research_level_changed.connect(_on_research_level_changed)
	ResearchManager.purchase_failed.connect(_on_purchase_failed)
	ResourceManager.stored_ore_changed.connect(_on_stored_ore_changed)
	ChipManager.chip_inventory_changed.connect(_on_chip_inventory_changed)
	ChipManager.chip_instance_changed.connect(_on_chip_instance_changed)
	ChipManager.chip_equipment_changed.connect(_on_chip_equipment_changed)
	ChipManager.chip_operation_failed.connect(_on_chip_operation_failed)
	_build_categories()
	_on_stored_ore_changed(ResourceManager.stored_ore)


func _process(delta: float) -> void:
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
	var cost := ResearchManager.get_upgrade_cost(ENERGY_TIP_RESEARCH)
	var body := _label(tr("Save up %d ore and research ENERGY MODULE EXPANSION in Energy. A second battery means more Power for more turrets, and it leads to farther planets.") % cost, 12, Palette.UI_MUTED)
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
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_frame = PanelContainer.new()
	var style := Palette.make_panel_style(Color(Palette.UI_PANEL, 0.97), 14, 24.0, 20.0)
	style.shadow_color = Palette.SHADOW_COLOR
	style.shadow_size = 10
	style.shadow_offset = Vector2(6.0, 10.0)
	_frame.add_theme_stylebox_override("panel", style)
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
	header.add_child(_label("LABORATORY", 22, Palette.UI_TEXT))
	_subtitle = _label("", 13, Palette.UI_MUTED)
	_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_subtitle)
	var ore_pill := PanelContainer.new()
	ore_pill.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.UI_PANEL_RAISED, 16, 14.0, 4.0))
	header.add_child(ore_pill)
	var ore_row := HBoxContainer.new()
	ore_row.add_theme_constant_override("separation", 8)
	ore_pill.add_child(ore_row)
	var gem := OreGem.new()
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ore_row.add_child(gem)
	_ore_label = _label("0", 16, Palette.GOLD)
	ore_row.add_child(_ore_label)
	ore_row.add_child(_label("ORE", 10, Palette.UI_MUTED))
	var close := Button.new()
	close.text = "ESC"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(56.0, 32.0)
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_font_size_override("font_size", 12)
	close.add_theme_color_override("font_color", Palette.UI_MUTED)
	for state in ["normal", "hover", "pressed"]:
		var button_style := Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8)
		if state == "hover":
			button_style.set_border_width_all(2)
			button_style.border_color = Palette.UI_MUTED
		close.add_theme_stylebox_override(state, button_style)
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)

	# Body: category rail + project area.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	category_buttons = VBoxContainer.new()
	category_buttons.custom_minimum_size = Vector2(RAIL_WIDTH, 0.0)
	category_buttons.add_theme_constant_override("separation", 10)
	body.add_child(category_buttons)
	_content = MarginContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		if category == null or not category.enabled:
			continue
		if first_enabled.is_empty():
			first_enabled = category.category_id
		var button := CategoryButton.new()
		var project_count := (
			ChipManager.configuration.chips.size()
			if category.category_id == &"chips"
			else ResearchManager.get_definitions_for_category(category.category_id).size()
		)
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
	if _selected_category_id == &"chips":
		_build_chip_laboratory()
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
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(grid)
	for definition in definitions:
		var card := ResearchCard.new()
		card.custom_minimum_size = CARD_SIZE
		grid.add_child(card)
		card.setup(definition)
		card.upgrade_pressed.connect(_on_upgrade_pressed)
		_cards[definition.research_id] = card
		if upgrade_button == null:
			upgrade_button = card.button


# ==========================================
# Chip Laboratory (manufacture only)
# ==========================================
# Blueprint list on the left, the selected blueprint on the right. Installing
# chips lives in the Hangar (Loadout panel); owned chips live in the Warehouse.

func _build_chip_laboratory() -> void:
	if not ChipManager.is_chip_laboratory_unlocked():
		_show_placeholder(
			"CHIP LABORATORY LOCKED",
			"Raise any weapon research to Level %d to unlock chip crafting."
				% ResearchManager.configuration.chip_laboratory_unlock_level
		)
		return
	_subtitle.text = "·  CHIP LAB  ·  MANUFACTURE ONLY"
	var blueprints: Array[ChipDefinition] = []
	for definition in ChipManager.configuration.chips:
		if definition != null and definition.enabled:
			blueprints.append(definition)
	if blueprints.is_empty():
		_show_placeholder("NO BLUEPRINTS", "No chip recipes are configured.")
		return
	if ChipManager.configuration.get_chip(_selected_chip_id) == null:
		_selected_chip_id = blueprints[0].chip_id

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	_content.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330.0, 0.0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	left.add_child(_label("BLUEPRINTS", 11, Palette.UI_MUTED))
	for definition in blueprints:
		var row := BlueprintRow.new()
		row.setup(definition.chip_id, ChipManager.get_owned_count(definition.chip_id), definition.chip_id == _selected_chip_id)
		row.pressed.connect(_select_chip_blueprint.bind(definition.chip_id))
		left.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var note := _label("Turret chip sockets unlock at weapon Lv 10 / 20 / 30.", 10, Palette.UI_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(note)

	body.add_child(_build_blueprint_detail(ChipManager.configuration.get_chip(_selected_chip_id)))


func _build_blueprint_detail(definition: ChipDefinition) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.UI_PANEL_RAISED, 12, 18.0, 16.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	column.add_child(_label("BLUEPRINT", 10, Palette.UI_MUTED))
	var icon := ChipVisual.ChipIcon.new(definition.chip_id, 116.0, true)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var title := _label(ChipVisual.get_display_name(definition.chip_id), 19, Palette.UI_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var effect := _label(ChipVisual.get_effect_text(definition.chip_id), 13, ChipVisual.get_color(definition.chip_id))
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(effect)
	var description := _label(definition.description, 11, Palette.UI_MUTED)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	var quality := definition.get_quality(0)
	var info := _label(tr("Quality: %s  ·  works on every weapon  ·  owned ×%d") % [
		(quality.display_name if quality != null else "Basic").to_upper(),
		ChipManager.get_owned_count(definition.chip_id),
	], 11, Palette.UI_MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(info)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gap)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	var cost := ChipManager.configuration.get_crafting_cost(definition.chip_id)
	var affordable := ResourceManager.stored_ore >= float(cost)
	craft_button = Button.new()
	craft_button.text = tr("CRAFT  ·  ◆ %s" if affordable else "NEED ORE  ·  ◆ %s") % _thousands(cost)
	craft_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_button.custom_minimum_size = Vector2(0.0, 46.0)
	craft_button.focus_mode = Control.FOCUS_NONE
	craft_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	craft_button.disabled = not affordable
	ResearchCard.style_button(craft_button, &"primary" if affordable else &"poor")
	craft_button.pressed.connect(_craft_chip.bind(definition.chip_id))
	buttons.add_child(craft_button)

	var upgrade_target := _find_upgradable_instance(definition.chip_id)
	var upgrade := Button.new()
	upgrade.custom_minimum_size = Vector2(150.0, 46.0)
	upgrade.focus_mode = Control.FOCUS_NONE
	if upgrade_target.is_empty():
		upgrade.text = "QUALITY MAX"
		upgrade.disabled = true
		upgrade.tooltip_text = "No higher chip quality is available yet."
		ResearchCard.style_button(upgrade, &"locked")
	else:
		var upgrade_cost := ChipManager.get_quality_upgrade_cost(upgrade_target)
		upgrade.text = tr("UPGRADE QUALITY  ◆ %s") % _thousands(upgrade_cost)
		upgrade.disabled = ResourceManager.stored_ore < float(upgrade_cost)
		ResearchCard.style_button(upgrade, &"locked" if upgrade.disabled else &"primary")
		upgrade.pressed.connect(_upgrade_chip.bind(upgrade_target))
	upgrade.add_theme_font_size_override("font_size", 11)
	buttons.add_child(upgrade)

	var hint := HintBox.new()
	hint.custom_minimum_size = Vector2(0.0, 54.0)
	column.add_child(hint)
	return card


func _select_chip_blueprint(chip_id: StringName) -> void:
	_selected_chip_id = chip_id
	_refresh_category()


## Lowest-quality copy of a chip type that still has a configured upgrade.
func _find_upgradable_instance(chip_id: StringName) -> StringName:
	var best: StringName = &""
	for instance_id in ChipManager.get_owned_instances(chip_id):
		if not ChipManager.can_upgrade_quality(instance_id):
			continue
		if best.is_empty() or ChipManager.get_instance_quality_index(instance_id) < ChipManager.get_instance_quality_index(best):
			best = instance_id
	return best


func _craft_chip(chip_id: StringName) -> void:
	if not ChipManager.craft_chip(chip_id).is_empty():
		_message.text = "CHIP CRAFTED  ·  SENT TO THE WAREHOUSE"
		_message.add_theme_color_override("font_color", Palette.GOLD)
		_message_time = 2.2
		_message.visible = true


func _upgrade_chip(instance_id: StringName) -> void:
	ChipManager.upgrade_chip_quality(instance_id)


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
			card.play_upgrade_flash()


func _on_research_level_changed(research_id: StringName, _level: int) -> void:
	ModuleCatalog.clear_stats_cache()
	if is_instance_valid(_research_tree_view):
		_research_tree_view.refresh.call_deferred()
	var card := _cards.get(research_id) as ResearchCard
	if card != null:
		card.refresh()
	if _selected_category_id == &"chips":
		_refresh_category()


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
	if _selected_category_id == &"chips" and is_inside_tree():
		_refresh_category()


func _on_chip_inventory_changed(_chip_id: StringName, _count: int) -> void:
	if _selected_category_id == &"chips":
		_refresh_category()


func _on_chip_instance_changed(_instance_id: StringName) -> void:
	if _selected_category_id == &"chips":
		_refresh_category()


func _on_chip_equipment_changed(_slot_id: StringName, _chip_id: StringName) -> void:
	ModuleCatalog.clear_stats_cache()


func _on_chip_operation_failed(reason: String) -> void:
	_message.add_theme_color_override("font_color", Palette.THREAT)
	_message.text = reason.to_upper()
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

## Left-rail category button: hex badge with a glyph (or a lock), name, status.
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
		custom_minimum_size = Vector2(LaboratoryPanel.RAIL_WIDTH, 48.0)
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		flat = true
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		tooltip_text = category.description
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func set_selected(selected: bool) -> void:
		_selected = selected
		queue_redraw()

	func _draw() -> void:
		var hovered := is_hovered()
		if _selected or hovered:
			Palette.draw_rounded_rect(self, Rect2(Vector2.ZERO, size), 8.0, Palette.UI_PANEL_RAISED if _selected else Color(Palette.UI_PANEL_RAISED, 0.5))
		if _selected:
			Palette.draw_rounded_rect(self, Rect2(Vector2(0.0, 8.0), Vector2(4.0, size.y - 16.0)), 2.0, Palette.ACCENT)
		var center := Vector2(32.0, size.y * 0.5)
		var badge := Palette.offset_points(Palette.regular_polygon(6, 16.0, PI / 6.0), center)
		var badge_color: Color = Palette.ACCENT if _selected else (Palette.MECH_LIGHT if _implemented else Palette.MECH)
		draw_colored_polygon(badge, badge_color)
		var glyph_color: Color = Palette.UI_PANEL if _selected else Palette.UI_MUTED
		if _implemented:
			LaboratoryPanel.draw_category_glyph(self, category_id, center, glyph_color)
		else:
			LaboratoryPanel.draw_lock(self, center + Vector2(0.0, 1.0), 0.7, glyph_color)
		var font := get_theme_default_font()
		draw_string(font, Vector2(60.0, size.y * 0.5 - 1.0), _name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Palette.UI_TEXT if _implemented else Palette.UI_MUTED)
		draw_string(font, Vector2(60.0, size.y * 0.5 + 14.0), _status, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				Palette.ACCENT if _selected else Palette.UI_MUTED)


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

	func setup(definition: ResearchDefinition) -> void:
		_definition = definition
		add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.UI_PANEL_RAISED, 10, 18.0, 16.0))
		tooltip_text = definition.description
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		add_child(column)

		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 16)
		column.add_child(top)
		var icon_box := PanelContainer.new()
		icon_box.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.UI_PANEL, 10, 4.0, 4.0))
		top.add_child(icon_box)
		var icon := ModuleIcon.new()
		icon.setup(definition.target_id, 76.0, 0.95)
		icon_box.add_child(icon)

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		top.add_child(text)
		var title_row := HBoxContainer.new()
		text.add_child(title_row)
		var title := _make_label(_title_text(), 17, Palette.UI_TEXT)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		_level_label = _make_label("", 13, Palette.ACCENT)
		title_row.add_child(_level_label)
		text.add_child(_make_label(_stat_text(), 10, Palette.UI_MUTED))
		var values := HBoxContainer.new()
		values.add_theme_constant_override("separation", 10)
		text.add_child(values)
		_now_label = _make_label("", 24, Palette.UI_TEXT)
		values.add_child(_now_label)
		_arrow_label = _make_label("→", 18, Palette.UI_MUTED)
		_arrow_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		values.add_child(_arrow_label)
		_next_label = _make_label("", 24, Palette.ACCENT)
		values.add_child(_next_label)

		_pips = LevelPips.new()
		_pips.custom_minimum_size = Vector2(0.0, 30.0)
		column.add_child(_pips)
		_slot_label = _make_label("", 10, Palette.UI_MUTED)
		column.add_child(_slot_label)
		_milestone_label = _make_label("", 10, Palette.GOLD)
		_milestone_label.visible = false
		column.add_child(_milestone_label)

		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(spacer)
		button = Button.new()
		button.custom_minimum_size = Vector2(0.0, 50.0)
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
		_level_label.add_theme_color_override("font_color", Palette.GOLD if maxed else Palette.ACCENT)
		var now: float = _damage_for(level)
		_now_label.text = ModuleCatalog.format_number(now)
		_now_label.add_theme_color_override("font_color", Palette.GOLD if maxed else Palette.UI_TEXT)
		_arrow_label.visible = not maxed
		_next_label.visible = not maxed
		if not maxed:
			_next_label.text = ModuleCatalog.format_number(_damage_for(level + 1))
		_pips.set_values(level, max_level, maxed, _chip_milestone_levels())
		var is_shield_research := _definition.effect is ModuleStatResearchEffect
		var module_unlocked := WeaponUnlockManager.is_weapon_unlocked(_definition.target_id)
		var unlocked_slots := (
			ResearchManager.get_shield_bonus_chip_slot_count(_definition.target_id)
			if is_shield_research and ChipManager.is_chip_laboratory_unlocked()
			else (0 if is_shield_research else ResearchManager.get_weapon_chip_slot_count(_definition.target_id))
		)
		var maximum_slots := int(ModuleCatalog.get_stats(_definition.target_id).get("max_chip_slots", 3)) if is_shield_research else ChipManager.configuration.max_weapon_chip_slots
		if not module_unlocked:
			_slot_label.text = tr("REQUIRES: %s") % tr(WeaponUnlockManager.get_unlock_requirement(_definition.target_id).to_upper())
			_slot_label.add_theme_color_override("font_color", Palette.UI_MUTED)
		else:
			_slot_label.text = tr("%d / %d CHIP SLOTS") % [unlocked_slots, maximum_slots]
			_slot_label.add_theme_color_override("font_color", Palette.GOLD if unlocked_slots > 0 else Palette.UI_MUTED)
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

	func _refresh_module_limit(
		effect: ModuleInstallationLimitResearchEffect,
		level: int,
		max_level: int,
		maxed: bool
	) -> void:
		_level_label.text = "COMPLETE" if maxed else "LOCKED"
		_level_label.add_theme_color_override(
			"font_color",
			Palette.GOLD if maxed else Palette.ACCENT
		)
		var current_limit := effect.get_installation_limit(level)
		_now_label.text = "%d / %d" % [
			current_limit,
			effect.unlocked_installation_limit,
		]
		_now_label.add_theme_color_override(
			"font_color",
			Palette.GOLD if maxed else Palette.UI_TEXT
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
			Palette.GOLD if maxed else Palette.UI_MUTED
		)

		var cost := ResearchManager.get_upgrade_cost(_definition.research_id)
		var cost_text := LaboratoryPanel._thousands(cost)
		_milestone_label.visible = not maxed
		_milestone_label.text = tr("UNLOCK COST: %s ORE") % cost_text
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
			button.text = "%s — ◆ %s ORE" % [
				effect.purchase_button_text.to_upper(),
				cost_text,
			]
			button.disabled = not affordable

	func play_upgrade_flash() -> void:
		_flash = 0.5
		_sparks.clear()
		var origin := Vector2(size.x * 0.55, size.y * 0.62)
		for index in range(10):
			var angle := randf_range(-PI * 0.9, -PI * 0.1)
			_sparks.append({"pos": origin, "vel": Vector2.RIGHT.rotated(angle) * randf_range(80.0, 180.0), "size": randf_range(3.0, 5.5)})
		set_process(true)

	func _ready() -> void:
		set_process(false)

	func _process(delta: float) -> void:
		_flash = maxf(_flash - delta, 0.0)
		for spark in _sparks:
			spark["pos"] += spark["vel"] * delta
			spark["vel"] += Vector2(0.0, 320.0) * delta
		if _flash <= 0.0:
			_sparks.clear()
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		if _flash <= 0.0:
			return
		var alpha: float = clampf(_flash / 0.5, 0.0, 1.0)
		var border := Palette.rounded_rect_points(Rect2(Vector2.ZERO, size).grow(-1.5), 10.0)
		border.append(border[0])
		draw_polyline(border, Color(Palette.ACCENT, alpha), 3.0)
		for spark in _sparks:
			var s: float = spark["size"]
			var p: Vector2 = spark["pos"]
			draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, -s * 1.6), p + Vector2(s, 0.0), p + Vector2(0.0, s * 1.6), p + Vector2(-s, 0.0)]), Color(Palette.GOLD, alpha))
		var font := get_theme_default_font()
		draw_string(font, Vector2(size.x - 120.0, size.y * 0.5 - 6.0 - (1.0 - alpha) * 16.0), "+1 LV",
				HORIZONTAL_ALIGNMENT_RIGHT, 100, 22, Color(Palette.ACCENT, alpha))

	## Research levels whose milestone grants a chip slot (Lv 10 / 20 / 30).
	func _chip_milestone_levels() -> Array[int]:
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
			return _definition.display_name.to_upper()
		for entry in ModuleCatalog.ENTRIES:
			if entry["id"] == _definition.target_id:
				return String(entry["name"]).to_upper()
		return _definition.display_name.to_upper()

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
		var base_color: Color = Palette.ACCENT
		var text_color: Color = Palette.UI_PANEL
		var border := Color(0, 0, 0, 0)
		match kind:
			&"poor", &"locked":
				base_color = Color("352D27")
				text_color = Palette.THREAT if kind == &"poor" else Palette.UI_MUTED
			&"max":
				base_color = Color(0, 0, 0, 0)
				text_color = Palette.GOLD
				border = Palette.GOLD
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := Palette.make_panel_style(base_color, 8)
			if kind == &"primary":
				style.shadow_color = Color("B8641A")
				style.shadow_size = 0
				style.shadow_offset = Vector2(0.0, 3.0)
				if state == "hover":
					style.bg_color = Palette.ACCENT.lightened(0.12)
				elif state == "pressed":
					style.bg_color = Palette.ACCENT.darkened(0.1)
			if border.a > 0.0:
				style.set_border_width_all(2)
				style.border_color = border
			target.add_theme_stylebox_override(state, style)
		target.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			target.add_theme_color_override(color_name, text_color)
		target.add_theme_font_size_override("font_size", 14)


## Slanted level segments (gold when maxed).
class LevelPips:
	extends Control

	## Long research tracks are shown one 10-level tier at a time. The tier's
	## last segment ends in a chip icon when that level unlocks a chip slot,
	## so the next reward is always in view.
	const TIER_SIZE: int = 10
	const CHIP_SPACE: float = 34.0

	var _level: int = 0
	var _max_level: int = 10
	var _maxed: bool = false
	var _chip_levels: Array[int] = []

	func set_values(level: int, max_level: int, maxed: bool, chip_levels: Array[int] = []) -> void:
		_level = level
		_max_level = maxi(max_level, 1)
		_maxed = maxed
		_chip_levels = chip_levels
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
		var chip_at := last if _chip_levels.has(last) else -1
		var bar_width := size.x - (CHIP_SPACE if chip_at > 0 else 0.0)
		var bar_height := 12.0
		var bar_y := 0.0

		var gap: float = 4.0
		var width: float = (bar_width - gap * float(segments - 1)) / float(maxi(segments, 1))
		for index in range(segments):
			var x: float = float(index) * (width + gap)
			var color: Color = (Palette.GOLD if _maxed else Palette.ACCENT) if index < filled else Palette.MECH
			draw_colored_polygon(PackedVector2Array([
				Vector2(x + 3.0, bar_y), Vector2(x + width, bar_y), Vector2(x + width - 3.0, bar_y + bar_height), Vector2(x, bar_y + bar_height),
			]), color)

		if tiered:
			var caption := "LV %d – %d" % [first + 1, last]
			draw_string(font, Vector2(0.0, bar_y + bar_height + 15.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.UI_MUTED)
			# Small tier dots: done / current / ahead.
			for index in range(tier_count):
				var dot := Vector2(bar_width - float(tier_count - index) * 12.0 + 4.0, bar_y + bar_height + 11.0)
				var done := index < tier or (_maxed and index == tier)
				draw_circle(dot, 3.2, Palette.GOLD if done else (Palette.ACCENT if index == tier else Palette.MECH))

		if chip_at > 0:
			var earned := _level >= chip_at
			_draw_chip_reward(Vector2(size.x - CHIP_SPACE * 0.5 + 2.0, bar_y + bar_height * 0.5 + 1.0), earned)
			draw_string(font, Vector2(size.x - CHIP_SPACE, bar_y + bar_height + 15.0), "LV %d" % chip_at, HORIZONTAL_ALIGNMENT_CENTER, CHIP_SPACE + 4.0, 9, Palette.GOLD if not earned else Palette.UI_MUTED)

	## Gold chip at the end of the tier: glowing while still ahead, solid once won.
	func _draw_chip_reward(center: Vector2, earned: bool) -> void:
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.004)
		if not earned:
			draw_circle(center, 13.0 + 2.0 * pulse, Color(Palette.GOLD, 0.12 + 0.12 * pulse))
		var pin := Color("8D857C")
		for offset in [-4.0, 0.0, 4.0]:
			draw_rect(Rect2(center + Vector2(offset - 1.0, -12.0), Vector2(2.0, 3.0)), pin)
			draw_rect(Rect2(center + Vector2(offset - 1.0, 9.0), Vector2(2.0, 3.0)), pin)
			draw_rect(Rect2(center + Vector2(-12.0, offset - 1.0), Vector2(3.0, 2.0)), pin)
			draw_rect(Rect2(center + Vector2(9.0, offset - 1.0), Vector2(3.0, 2.0)), pin)
		Palette.draw_rounded_rect(self, Rect2(center - Vector2(9.0, 9.0), Vector2(18.0, 18.0)), 3.0, Palette.MECH)
		Palette.draw_rounded_rect(self, Rect2(center - Vector2(6.5, 6.5), Vector2(13.0, 13.0)), 2.0, Palette.GOLD if earned or pulse > 0.0 else Palette.GOLD_SHADOW)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-6.0, -6.0), center + Vector2(6.0, -6.0), center + Vector2(6.0, -2.0), center + Vector2(-6.0, 1.5)]), Color(1.0, 1.0, 1.0, 0.3))
		if earned:
			draw_polyline(PackedVector2Array([center + Vector2(-3.5, 0.0), center + Vector2(-1.0, 2.8), center + Vector2(3.8, -2.8)]), Palette.UI_PANEL, 2.0)

	func _process(_delta: float) -> void:
		if not _chip_levels.is_empty() and is_visible_in_tree():
			queue_redraw()


## Blueprint list row: chip icon, name, effect, owned count.
class BlueprintRow:
	extends Button

	const ChipVisual := preload("res://Scripts/UI/Chips/ChipVisual.gd")

	var chip_id: StringName
	var _owned: int = 0
	var _selected: bool = false

	func setup(id: StringName, owned: int, selected: bool) -> void:
		chip_id = id
		_owned = owned
		_selected = selected
		custom_minimum_size = Vector2(0.0, 56.0)
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		flat = true
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var fill := Palette.MECH if _selected else (Palette.UI_PANEL_RAISED.lightened(0.04) if is_hovered() else Palette.UI_PANEL_RAISED)
		Palette.draw_rounded_rect(self, rect, 9.0, fill)
		if _selected:
			var border := Palette.rounded_rect_points(rect.grow(-1.0), 9.0)
			border.append(border[0])
			draw_polyline(border, Palette.ACCENT, 2.0)
		ChipVisual.draw_chip(self, chip_id, Vector2(30.0, size.y * 0.5), 38.0)
		var font := get_theme_default_font()
		draw_string(font, Vector2(58.0, size.y * 0.5 - 3.0), ChipVisual.get_display_name(chip_id), HORIZONTAL_ALIGNMENT_LEFT, size.x - 150.0, 13, Palette.UI_TEXT)
		draw_string(font, Vector2(58.0, size.y * 0.5 + 14.0), ChipVisual.get_effect_text(chip_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ChipVisual.get_color(chip_id))
		draw_string(font, Vector2(size.x - 92.0, size.y * 0.5 + 4.0), "OWNED ×%d" % _owned, HORIZONTAL_ALIGNMENT_RIGHT, 80.0, 11, Palette.UI_MUTED if _owned == 0 else Palette.UI_TEXT)


## Dashed note: crafted chips go to the Warehouse, install in the Hangar.
class HintBox:
	extends Control

	const ChipVisual := preload("res://Scripts/UI/Chips/ChipVisual.gd")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var points := Palette.rounded_rect_points(Rect2(Vector2.ZERO, size).grow(-1.0), 9.0)
		points.append(points[0])
		for index in range(points.size() - 1):
			var a := points[index]
			var b := points[index + 1]
			var length := a.distance_to(b)
			var t := 0.0
			while t < length:
				draw_line(a.lerp(b, t / length), a.lerp(b, minf(t + 5.0, length) / length), Palette.MECH_LIGHT, 1.0)
				t += 9.0
		ChipVisual.draw_crate(self, Vector2(26.0, size.y * 0.5), 22.0)
		var font := get_theme_default_font()
		var lines := [
			[["Crafted chips go to the ", Palette.UI_MUTED], ["WAREHOUSE", Palette.UI_TEXT], [".", Palette.UI_MUTED]],
			[["Install them in the ", Palette.UI_MUTED], ["HANGAR", Palette.UI_TEXT], [": select a turret on the ship.", Palette.UI_MUTED]],
		]
		for line_index in range(lines.size()):
			var x := 46.0
			var y := size.y * 0.5 - 4.0 + 16.0 * float(line_index)
			for part in lines[line_index]:
				draw_string(font, Vector2(x, y), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, part[1])
				x += font.get_string_size(part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x


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
		&"energy":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(2.0, -9.0), center + Vector2(-5.0, 1.0), center + Vector2(0.0, 1.0),
				center + Vector2(-2.0, 9.0), center + Vector2(5.0, -1.0), center + Vector2(0.0, -1.0),
			]), color)
		_:
			canvas.draw_circle(center, 4.0, color)
