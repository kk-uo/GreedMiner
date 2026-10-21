extends Control

## First-battle mining tutorial (presentation + a tiny saved flag). Shown the
## first time the player lands on a planet with crystals / ores and has a
## Mining Module installed; the player does it themselves:
##   1. SEND A DWARF  - arrow on the Mining Module, a ghost cursor drags from
##                      it to the nearest crystal. The first wave holds until
##                      the first dwarf is sent (or SKIP / HOLD_LIMIT).
##   2. MINING        - arrow on the crystal being mined.
##   3. BRING IT HOME - arrow follows the dwarf carrying the ore.
##   4. DONE          - GOT IT closes it.
## Same caption + bouncing arrow style as the base TutorialGuide. Saved as done
## in ProgressionStore section "mining_tutorial". Load with preload().

const GUIDE_ARROW := preload("res://Scripts/UI/GuideArrow.gd")
const SAVE_SECTION: StringName = &"mining_tutorial"
## Never hold the first wave longer than this (seconds).
const HOLD_LIMIT: float = 60.0

enum Step { SEND, MINING, CARRY, DONE, CLOSED }
const STEP_COUNT: int = 4

const TEXT := {
	Step.SEND: ["SEND A DWARF MINER", "Drag from your MINING module to a crystal. A dwarf walks out and mines it for you. The first wave waits until you try it."],
	Step.MINING: ["DWARF AT WORK", "The dwarf needs 10 seconds; the bar above the crystal shows progress. Right-click the mining module to call it back early."],
	Step.CARRY: ["BRING IT HOME", "The dwarf carries the ore back to the ship. Protect it: enemies can hit it on the way, and a fallen dwarf needs 15 s to be replaced."],
	Step.DONE: ["ORE DELIVERED!", "Every planet has its own crystals and ores. Keep your dwarves busy between fights to earn more ore."],
}

var battle: Node = null
var controller: Node2D = null
var step: Step = Step.SEND

var _time: float = 0.0
var _hold_time: float = 0.0
var _holding: bool = false
var _worker: Node2D = null
var _caption: PanelContainer
var _title: Label
var _body: Label
var _counter: Label
var _got_it: Button
var _has_target: bool = false
var _target := Vector2.ZERO
var _target_radius: float = 0.0
var _ghost_from := Vector2.ZERO
var _ghost_to := Vector2.ZERO
var _show_ghost: bool = false


## True when the tutorial should run for this battle.
static func should_run(mining_controller: Node) -> bool:
	if mining_controller == null:
		return false
	if bool(ProgressionStore.get_section(SAVE_SECTION).get("done", false)):
		return false
	return _first_module(mining_controller) != null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_caption()
	_refresh_text()
	_set_hold(true)
	# WaveManager starts itself with a deferred call queued before ours; hold
	# again right after it so not even the first enemy spawns.
	_keep_holding.call_deferred()


func _keep_holding() -> void:
	if _holding and battle != null and is_instance_valid(battle):
		var waves := battle.get_node_or_null("WaveManager")
		if waves != null:
			waves.set_process(false)


func _exit_tree() -> void:
	_set_hold(false)


## Holds the wave system before the first wave so the player can try mining
## in peace. Nothing has spawned yet when the tutorial starts.
func _set_hold(hold: bool) -> void:
	if battle == null or not is_instance_valid(battle) or hold == _holding:
		return
	var waves := battle.get_node_or_null("WaveManager")
	if waves == null:
		return
	if hold and waves.has_method("get_current_wave_number") and int(waves.call("get_current_wave_number")) > 1:
		return
	_holding = hold
	waves.set_process(not hold)


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
		_got_it.add_theme_stylebox_override(state, Palette.make_panel_style(Palette.ACCENT.lightened(0.1) if state == "hover" else Palette.ACCENT, 8, 12.0, 4.0))
	_got_it.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		_got_it.add_theme_color_override(color_name, Palette.UI_PANEL)
	_got_it.pressed.connect(finish)
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
	_got_it.visible = step == Step.DONE


## Marks the tutorial as finished (GOT IT / SKIP) and removes it.
func finish() -> void:
	_set_hold(false)
	step = Step.CLOSED
	var data := ProgressionStore.get_section(SAVE_SECTION)
	data["done"] = true
	ProgressionStore.set_section(SAVE_SECTION, data)
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	if controller == null or not is_instance_valid(controller) or bool(battle.get("_battle_ended")):
		queue_free()
		return
	if _holding:
		_hold_time += delta
		if _hold_time >= HOLD_LIMIT:
			_set_hold(false)
		else:
			# WaveManager re-enables itself when it starts (deferred); keep it held.
			var waves := battle.get_node_or_null("WaveManager")
			if waves != null:
				waves.set_process(false)
	# Wait for the landing sequence before showing anything.
	var launcher := battle.get_node_or_null("ShipLaunchController")
	var landing := launcher != null and launcher.has_method("is_busy") and bool(launcher.call("is_busy"))
	_caption.visible = not landing
	if landing:
		_has_target = false
		queue_redraw()
		return
	_advance()
	_update_target()
	queue_redraw()


func _advance() -> void:
	var previous := step
	var workers: Dictionary = controller.get("workers")
	match step:
		Step.SEND:
			for worker in workers.values():
				if is_instance_valid(worker):
					_worker = worker
					step = Step.MINING
					_set_hold(false)
		Step.MINING:
			if not is_instance_valid(_worker):
				step = Step.SEND
			elif _worker.call("is_carrying_ore"):
				step = Step.CARRY
			elif int(_worker.get("state")) == 2:
				# Recalled without ore: let them try again.
				step = Step.SEND
		Step.CARRY:
			if not is_instance_valid(_worker) or _worker.is_queued_for_deletion():
				# Returned (ore banked) or fell on the way.
				step = Step.DONE if float(controller.get("cooldowns").get(_first_module(controller), 0.0)) <= 0.0 else Step.SEND
	if step != previous:
		_refresh_text()


func _update_target() -> void:
	_has_target = false
	_show_ghost = false
	var canvas := get_viewport().get_canvas_transform()
	var zoom := canvas.get_scale().x / _ui_scale()
	match step:
		Step.SEND:
			var module := _first_module(controller)
			if module == null:
				return
			_set_target(_to_local(canvas * module.global_position), 34.0 * zoom)
			var crystal := _nearest_crystal(module.global_position)
			if crystal != null:
				_show_ghost = true
				_ghost_from = _target
				_ghost_to = _to_local(canvas * crystal.global_position)
		Step.MINING:
			if is_instance_valid(_worker) and is_instance_valid(_worker.get("crystal")):
				var crystal: Node2D = _worker.get("crystal")
				_set_target(_to_local(canvas * crystal.global_position), 34.0 * zoom)
		Step.CARRY:
			if is_instance_valid(_worker):
				_set_target(_to_local(canvas * _worker.global_position), 22.0 * zoom)


func _set_target(point: Vector2, radius: float) -> void:
	_has_target = true
	_target = point
	_target_radius = radius


func _draw() -> void:
	if not _has_target:
		return
	var bob := sin(_time * 5.0) * 7.0
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	draw_arc(_target, _target_radius + 6.0 * pulse, 0.0, TAU, 64, Color(Palette.ACCENT, 0.35 + 0.4 * pulse), 3.0)
	var arrow_dir := Vector2.DOWN
	if _show_ghost:
		_draw_ghost_drag()
		# Arrow comes from the side away from the crystal.
		if _ghost_to.distance_to(_ghost_from) > 1.0:
			arrow_dir = (_ghost_from - _ghost_to).normalized() * -1.0
	_draw_arrow(_target - arrow_dir * (_target_radius + 10.0 + bob), arrow_dir)


## A ghost cursor pressing on the module and dragging to the crystal (loops).
func _draw_ghost_drag() -> void:
	const GOLD := Color("F5CE6A")
	var cycle := fposmod(_time, 2.4)
	var k := clampf((cycle - 0.4) / 1.3, 0.0, 1.0)
	var eased := k * k * (3.0 - 2.0 * k)
	var at := _ghost_from.lerp(_ghost_to, eased)
	var pressed := cycle > 0.25 and cycle < 1.9
	if pressed:
		var length := _ghost_from.distance_to(at)
		var dir := (at - _ghost_from) / maxf(length, 0.001)
		var x := 0.0
		while x < length:
			draw_line(_ghost_from + dir * x, _ghost_from + dir * minf(x + 9.0, length), Color(GOLD, 0.85), 3.0)
			x += 15.0
	if k >= 1.0 and pressed:
		draw_arc(_ghost_to, 22.0, 0.0, TAU, 32, GOLD, 2.5)
	var alpha := 1.0 if cycle < 2.1 else 1.0 - (cycle - 2.1) / 0.3
	var s := 0.9 if pressed else 1.0
	var cursor := PackedVector2Array([Vector2(0, 0), Vector2(0, 22), Vector2(6, 17), Vector2(10, 26), Vector2(14, 24), Vector2(10, 15), Vector2(17, 15)])
	var shadow := PackedVector2Array()
	var shape := PackedVector2Array()
	for p in cursor:
		shape.append(at + p * s)
		shadow.append(at + p * s + Vector2(3, 4))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.3 * alpha))
	draw_colored_polygon(shape, Color(1, 1, 1, alpha))
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, Color(Palette.UI_PANEL, alpha), 2.0)
	if pressed:
		draw_arc(at, 9.0, 0.0, TAU, 20, Color(GOLD, 0.7 * alpha), 2.0)


func _draw_arrow(tip: Vector2, direction: Vector2) -> void:
	GUIDE_ARROW.draw(self, tip, direction, 0.5 + 0.5 * sin(_time * 4.0))


# ==========================================
# Helpers
# ==========================================

static func _first_module(mining_controller: Node) -> Node2D:
	var ship_node: Node = mining_controller.get("ship")
	if ship_node == null or not is_instance_valid(ship_node):
		return null
	for child in (ship_node as Ship).installed_modules.get_children():
		if child is MiningModule and (child as MiningModule).mining_enabled:
			return child
	return null


func _nearest_crystal(from: Vector2) -> Node2D:
	var field: Node = controller.get("field")
	if field == null:
		return null
	var container: Node = field.call("get_interactables_root").get_node_or_null("RockyCrystals")
	if container == null:
		return null
	var best: Node2D = null
	for crystal in container.get_children():
		if crystal.call("can_be_mined") and (best == null or crystal.global_position.distance_to(from) < best.global_position.distance_to(from)):
			best = crystal
	return best


func _ui_scale() -> float:
	var root := get_parent()
	return float(root.get("ui_visual_scale")) if root != null and root.get("ui_visual_scale") != null else 1.0


func _to_local(screen: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen
