class_name SettingsMenu
extends Control

## Top-left gear button with a small settings dropdown (style A).
##
## Items:
## - VOLUME          -> controls the Master audio bus and saves the preference
## - MAIN MENU       -> emits main_menu_requested (not implemented yet: "SOON")
## - DEVELOPER MODE  -> emits developer_mode_requested when enabled by project settings
## - QUIT GAME       -> asks once more, then quits. On web builds a browser tab
##                      cannot be closed by the game, so it shows a hint instead.
## The owner scene decides when the gear is available via set_available().
## Clicking outside the dropdown or pressing Esc closes it.

signal main_menu_requested
signal developer_mode_requested
signal quit_requested

const GEAR_SIZE: float = 44.0
const MARGIN: float = 16.0
const DROPDOWN_WIDTH: float = 240.0
## Whether the Main Menu / Developer Mode items work yet.
@export var main_menu_enabled: bool = false
@export var developer_mode_enabled: bool = false
## Only battle opts in; the base menu leaves simulation running.
@export var pause_game_when_open: bool = false
## Battle has no developer panel, so do not offer a nonfunctional action there.
@export var allow_developer_mode: bool = true
## Language changes are offered in the base, not during combat.
@export var allow_language_change: bool = true
## The base places settings in the top-right; battle retains its existing layout.
@export var align_right: bool = false

var _gear: GearButton
var _catcher: Control
var _dropdown: PanelContainer
var _quit_button: Button
var _quit_hint: Label
var _quit_armed_time: float = 0.0
var _available: bool = true
var _owns_pause: bool = false


func _ready() -> void:
	# Presentation mirrors the centralized guard; command methods enforce it too.
	developer_mode_enabled = allow_developer_mode and DeveloperCommands.is_available()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Full-screen click catcher behind the dropdown: a click outside closes it.
	_catcher = Control.new()
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.visible = false
	_catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			close_menu()
			_catcher.accept_event()
	)
	add_child(_catcher)

	_gear = GearButton.new()
	if align_right:
		_gear.anchor_left = 1.0
		_gear.anchor_right = 1.0
		_gear.offset_left = -MARGIN - GEAR_SIZE
		_gear.offset_right = -MARGIN
		_gear.offset_top = MARGIN
		_gear.offset_bottom = MARGIN + GEAR_SIZE
	else:
		_gear.position = Vector2(MARGIN, MARGIN)
	_gear.size = Vector2.ONE * GEAR_SIZE
	_gear.tooltip_text = "Settings"
	_gear.pressed.connect(toggle_menu)
	add_child(_gear)

	_build_dropdown()


func _process(delta: float) -> void:
	if _quit_armed_time > 0.0:
		_quit_armed_time -= delta
		if _quit_armed_time <= 0.0:
			_set_quit_armed(false)


func _unhandled_input(event: InputEvent) -> void:
	if _available and event.is_action_pressed("ui_cancel"):
		toggle_menu()
		get_viewport().set_input_as_handled()


## Shows or hides the gear (e.g. only in the base overview). Hiding closes the menu.
func set_available(available: bool) -> void:
	if available == _available:
		return
	_available = available
	_gear.visible = available
	if not available:
		close_menu()


func is_open() -> bool:
	return _dropdown.visible


func toggle_menu() -> void:
	if is_open():
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	if not _available or is_open():
		return
	_set_quit_armed(false)
	_dropdown.visible = true
	_catcher.visible = true
	_gear.set_active(true)
	_dropdown.modulate.a = 0.0
	_dropdown.position.y = MARGIN + GEAR_SIZE + 2.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dropdown, "modulate:a", 1.0, 0.14)
	tween.tween_property(_dropdown, "position:y", MARGIN + GEAR_SIZE + 8.0, 0.16)
	if pause_game_when_open and not get_tree().paused:
		_owns_pause = true
		get_tree().paused = true


func close_menu() -> void:
	_dropdown.visible = false
	_catcher.visible = false
	_gear.set_active(false)
	_set_quit_armed(false)
	_release_owned_pause()


## Never clear a pause that was already active before this menu opened.
func _release_owned_pause() -> void:
	if _owns_pause and is_inside_tree():
		get_tree().paused = false
	_owns_pause = false


func _exit_tree() -> void:
	_release_owned_pause()


# ==========================================
# Dropdown
# ==========================================

func _build_dropdown() -> void:
	_dropdown = PanelContainer.new()
	var style := Palette.make_panel_style(Color(Palette.UI_PANEL, 0.97), 10, 10.0, 10.0)
	style.shadow_color = Palette.SHADOW_COLOR
	style.shadow_size = 8
	style.shadow_offset = Vector2(4.0, 6.0)
	_dropdown.add_theme_stylebox_override("panel", style)
	_dropdown.position = Vector2(MARGIN, MARGIN + GEAR_SIZE + 8.0)
	if align_right:
		_dropdown.anchor_left = 1.0
		_dropdown.anchor_right = 1.0
		_dropdown.offset_left = -MARGIN - DROPDOWN_WIDTH
		_dropdown.offset_right = -MARGIN
	_dropdown.custom_minimum_size = Vector2(DROPDOWN_WIDTH, 0.0)
	_dropdown.visible = false
	add_child(_dropdown)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_dropdown.add_child(column)
	var title := _label("SETTINGS", 11, Palette.UI_MUTED)
	title.custom_minimum_size = Vector2(0.0, 22.0)
	column.add_child(title)
	if allow_language_change:
		var language_row := HBoxContainer.new()
		language_row.add_child(_label("LANGUAGE", 11, Palette.UI_MUTED))
		var language := OptionButton.new()
		language.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		language.add_item("English")
		language.add_item("简体中文")
		language.select(1 if TranslationServer.get_locale().begins_with("zh") else 0)
		language.item_selected.connect(func(index: int) -> void:
			if not LanguageManager.request_language(&"zh_CN" if index == 1 else &"en"):
				language.select(1 if TranslationServer.get_locale().begins_with("zh") else 0)
		)
		language_row.add_child(language)
		column.add_child(language_row)
	var volume_row := HBoxContainer.new()
	volume_row.custom_minimum_size.y = 32.0
	volume_row.add_child(_label("VOLUME", 11, Palette.UI_MUTED))
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = AudioSettings.master_volume_percent
	volume_slider.custom_minimum_size.x = 88.0
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	volume_row.add_child(volume_slider)
	var volume_value := _label("%d%%" % AudioSettings.master_volume_percent, 11, Palette.UI_TEXT)
	volume_value.custom_minimum_size.x = 38.0
	volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_row.add_child(volume_value)
	volume_slider.value_changed.connect(func(value: float) -> void:
		var percent := roundi(value)
		AudioSettings.set_master_volume(percent)
		volume_value.text = "%d%%" % percent
	)
	column.add_child(volume_row)

	column.add_child(_item("MAIN MENU", main_menu_enabled, func() -> void:
		close_menu()
		main_menu_requested.emit()
	))
	column.add_child(_item("DEVELOPER MODE", developer_mode_enabled, func() -> void:
		close_menu()
		developer_mode_requested.emit()
	))
	var separator := ColorRect.new()
	separator.color = Palette.UI_PANEL_RAISED
	separator.custom_minimum_size = Vector2(0.0, 2.0)
	column.add_child(separator)

	_quit_button = Button.new()
	_quit_button.text = "QUIT GAME"
	_quit_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_quit_button.custom_minimum_size = Vector2(0.0, 40.0)
	_quit_button.focus_mode = Control.FOCUS_NONE
	_quit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_item(_quit_button, Palette.THREAT, false)
	_quit_button.pressed.connect(_on_quit_pressed)
	column.add_child(_quit_button)
	_quit_hint = _label("", 11, Palette.UI_MUTED)
	_quit_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quit_hint.visible = false
	column.add_child(_quit_hint)


func _item(text: String, enabled: bool, action: Callable) -> Control:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 40.0)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not enabled
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_FORBIDDEN
	button.tooltip_text = "" if enabled else "Coming soon"
	_style_item(button, Palette.UI_TEXT, not enabled)
	button.pressed.connect(action)
	if enabled:
		return button
	# "SOON" tag on the right of unfinished items.
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.UI_PANEL_RAISED, 8, 7.0, 1.0))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	tag.anchor_top = 0.5
	tag.anchor_bottom = 0.5
	tag.offset_left = -56.0
	tag.offset_right = -12.0
	tag.offset_top = -9.0
	tag.offset_bottom = 9.0
	var tag_label := _label("SOON", 9, Palette.ACCENT)
	tag.add_child(tag_label)
	button.add_child(tag)
	return button


func _style_item(button: Button, color: Color, muted: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := Palette.make_panel_style(Color(0, 0, 0, 0), 8, 12.0, 4.0)
		if state == "hover" or state == "pressed":
			style.bg_color = Palette.UI_PANEL_RAISED
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var text_color: Color = Palette.UI_MUTED if muted else color
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(color_name, text_color)
	button.add_theme_font_size_override("font_size", 14)


## First click arms the button ("CONFIRM QUIT?"), a second click within 3 s quits.
func _on_quit_pressed() -> void:
	if _quit_armed_time <= 0.0:
		_set_quit_armed(true)
		return
	quit_requested.emit()
	AudioSettings.flush()
	if OS.has_feature("web"):
		_quit_hint.text = "Close the browser tab to quit."
		_quit_hint.visible = true
		_quit_armed_time = 0.0
		_quit_button.text = "QUIT GAME"
		return
	# Unlocks are normally written as soon as they change. Save once more before
	# an explicit quit so every configured weapon state is guaranteed on disk.
	if not WeaponUnlockManager.save_progress():
		push_warning("SettingsMenu: Weapon unlock progress could not be saved before quitting.")
	get_tree().quit()


func _set_quit_armed(armed: bool) -> void:
	if _quit_button == null:
		return
	_quit_armed_time = 3.0 if armed else 0.0
	_quit_button.text = "CONFIRM QUIT?" if armed else "QUIT GAME"
	var style := _quit_button.get_theme_stylebox("normal") as StyleBoxFlat
	if style != null:
		style.bg_color = Color(Palette.THREAT, 0.18) if armed else Color(0, 0, 0, 0)
	if not armed:
		_quit_hint.visible = false


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Dark rounded square with a code-drawn gear.
class GearButton:
	extends Button

	var _active: bool = false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		flat = true
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func set_active(active: bool) -> void:
		_active = active
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		Palette.draw_rounded_rect(self, rect, 10.0, Palette.UI_PANEL)
		if _active or is_hovered():
			var border := Palette.rounded_rect_points(rect.grow(-1.0), 10.0)
			border.append(border[0])
			draw_polyline(border, Palette.ACCENT if _active else Palette.UI_MUTED, 2.0)
		var center := size * 0.5
		var color: Color = Palette.ACCENT if _active else Palette.UI_TEXT
		var teeth := PackedVector2Array()
		for index in range(16):
			var angle := TAU * float(index) / 16.0 + PI / 16.0
			var radius := 13.0 if index % 2 == 0 else 10.0
			teeth.append(center + Vector2.RIGHT.rotated(angle) * radius)
		draw_colored_polygon(teeth, color)
		draw_circle(center, 4.5, Palette.UI_PANEL)
