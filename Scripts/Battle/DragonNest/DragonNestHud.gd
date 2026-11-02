class_name DragonNestHud
extends CanvasLayer

var controller: DragonNestController
var _title: Label
var _summary: Label
var _segment_row: HBoxContainer
var _segments: Array[ColorRect] = []
var _developer_panel: PanelContainer
var _wave_spin: SpinBox
var _debug_visible: bool = false


func _ready() -> void:
	layer = 30
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := VBoxContainer.new()
	top.position = Vector2(260.0, 14.0)
	top.custom_minimum_size = Vector2(640.0, 0.0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_title = Label.new()
	_title.text = tr("DRAGON NEST")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.hide()
	top.add_child(_title)
	_segment_row = HBoxContainer.new()
	_segment_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_segment_row.hide()
	top.add_child(_segment_row)
	for index in range(AncientDragon.SEGMENT_COUNT):
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(48.0, 8.0)
		segment.color = Color("3b3028")
		segment.tooltip_text = tr("Boss segment %d") % (index + 1)
		_segment_row.add_child(segment)
		_segments.append(segment)
	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.hide()
	top.add_child(_summary)

	if DeveloperCommands.is_available():
		_build_developer_panel(root)
		_developer_panel.hide()


func _process(_delta: float) -> void:
	if controller == null or not is_instance_valid(controller):
		return
	var boss := controller.boss
	var boss_text := tr("Boss: not spawned")
	if is_instance_valid(boss):
		boss_text = tr("Boss S%d  %.0f/%.0f  total %.0f/%.0f  %s  next %.1fs  summons %d  QTE %s") % [
			boss.current_segment,
			boss.get_segment_remaining_hp(),
			AncientDragon.SEGMENT_HP,
			boss.get_current_health(),
			AncientDragon.TOTAL_HP,
			tr(boss.get_boss_state_name()),
			boss.get_next_special_cooldown(),
			boss.get_active_summon_count(),
			tr(boss.get_qte_status()),
		]
	_summary.text = tr("Wave %d/%d  enemies %d  pending %d  ship %.0f/%.0f  expedition ore %.0f  greed %d/15 %s\n%s") % [
		controller.wave_manager.get_current_wave_number(),
		controller.wave_manager.get_total_waves(),
		controller.wave_manager.get_alive_enemy_count() + controller.get_live_guardian_count(),
		controller.get_pending_scheduled_count(),
		controller.ship.current_hp,
		controller.ship.max_hp,
		ResourceManager.mission_ore,
		controller.greed,
		tr(DragonNestRules.greed_tier_name(controller.greed)),
		boss_text,
	]
	_update_segments(boss)
	_segment_row.visible = _debug_visible or is_instance_valid(boss)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F11:
		return
	if not DeveloperCommands.is_available():
		return
	set_debug_tools_visible(not _debug_visible)
	get_viewport().set_input_as_handled()


## Detailed text and Dragon Nest-only controls stay out of the ordinary battle
## view. Developers can still toggle them with F11 when Developer Mode is on.
func set_debug_tools_visible(value: bool) -> void:
	_debug_visible = value and DeveloperCommands.is_available()
	_title.visible = _debug_visible
	_summary.visible = _debug_visible
	if is_instance_valid(_developer_panel):
		_developer_panel.visible = _debug_visible
	_segment_row.visible = _debug_visible or is_instance_valid(controller.boss if controller != null else null)


func _update_segments(boss: AncientDragon) -> void:
	for index in range(_segments.size()):
		if not is_instance_valid(boss):
			_segments[index].color = Color("3b3028")
			continue
		if index < boss.segments_broken:
			_segments[index].color = Color("642d2d")
		elif index == boss.segments_broken:
			var ratio := boss.get_segment_remaining_hp() / AncientDragon.SEGMENT_HP
			_segments[index].color = Color("ef6a3a").lerp(Color("642d2d"), 1.0 - ratio)
		else:
			_segments[index].color = Color("d9a33e")


func _build_developer_panel(root: Control) -> void:
	_developer_panel = PanelContainer.new()
	_developer_panel.position = Vector2(12.0, 170.0)
	_developer_panel.custom_minimum_size = Vector2(218.0, 0.0)
	_developer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_developer_panel)
	var column := VBoxContainer.new()
	_developer_panel.add_child(column)
	var heading := Label.new()
	heading.text = tr("DRAGON NEST DEV")
	column.add_child(heading)
	_wave_spin = SpinBox.new()
	_wave_spin.min_value = 1
	_wave_spin.max_value = 11
	_wave_spin.value = 11
	column.add_child(_wave_spin)
	_add_button(column, "Start / jump selected wave", func() -> void: controller.developer_jump_to_wave(int(_wave_spin.value)))
	_add_button(column, "Start Wave 1", func() -> void: controller.developer_jump_to_wave(1))
	_add_button(column, "Jump Boss Wave 11", func() -> void: controller.developer_jump_to_wave(11))
	_add_button(column, "Spawn Young Dragon", func() -> void: controller.developer_spawn_enemy(&"young_dragon"))
	_add_button(column, "Spawn Greater Dragon", func() -> void: controller.developer_spawn_enemy(&"greater_dragon"))
	_add_button(column, "Boss segment -> 1 HP", func() -> void: controller.developer_nearly_empty_segment())
	_add_button(column, "Trigger Dive QTE", func() -> void: controller.developer_trigger_dive())
	_add_button(column, "Trigger Fire Breath", func() -> void: controller.developer_trigger_breath())
	var greed_row := HBoxContainer.new()
	column.add_child(greed_row)
	for value in [0, 5, 10, 15]:
		_add_button(greed_row, "G%d" % value, func() -> void: controller.set_greed(value))
	_add_button(column, "Spawn Reinforcements", func() -> void: controller.developer_spawn_reinforcements())
	_add_button(column, "Ship HP = 10", func() -> void: controller.developer_set_ship_hp(10.0))
	_add_button(column, "Heal Ship Full", func() -> void: controller.ship.heal(controller.ship.max_hp))
	_add_button(column, "Reset Dragon Nest", func() -> void: controller.developer_reset_session())


func _add_button(parent: Control, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = tr(text_value)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
