extends Control

## One-time battle tip: the first time the ship's hull drops to
## CRITICAL_RATIO, the battle slows to bullet time, the big red EVACUATE
## button gets an arrow and a pulsing ring, and a caption explains the
## strategy: slam it 10 times to leave right away and keep this run's ore,
## because a destroyed ship loses all of it.
##
## Bullet time ends when the player evacuates, presses KEEP FIGHTING, the ship
## is destroyed or the battle ends otherwise; Engine.time_scale is always put
## back to 1 (also when the scene is left). Saved once in ProgressionStore
## section "battle_hints", key "evacuate_tip_shown".
## Load with preload(); no class_name on purpose.

const SAVE_SECTION: StringName = &"battle_hints"
const SAVE_KEY: String = "evacuate_tip_shown"
## Hull fraction that counts as "about to be destroyed".
const CRITICAL_RATIO: float = 0.3
## Battle speed during the tip, and how long (real seconds) easing in/out takes.
const SLOW_SCALE: float = 0.15
const EASE_TIME: float = 0.35

var ship: Ship
var evacuation_panel: EvacuationPanel

var _active: bool = false
var _ending: bool = false
var _time: float = 0.0
var _ease: float = 0.0
var _last_ticks: int = 0
var _caption: PanelContainer


## True when this save has not seen the tip yet.
static func should_watch() -> bool:
	return not bool(ProgressionStore.get_section(SAVE_SECTION).get(SAVE_KEY, false))


func setup(target_ship: Ship, panel: EvacuationPanel) -> void:
	ship = target_ship
	evacuation_panel = panel
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ship != null and not ship.health_changed.is_connected(_on_health_changed):
		ship.health_changed.connect(_on_health_changed)
	if evacuation_panel != null and not evacuation_panel.evacuation_completed.is_connected(finish):
		evacuation_panel.evacuation_completed.connect(finish)
	visible = false


func is_active() -> bool:
	return _active


func _on_health_changed(current_health: float, maximum_health: float) -> void:
	if _active:
		if current_health <= 0.0:
			finish()
		return
	if _ending or current_health <= 0.0 or maximum_health <= 0.0:
		return
	if current_health / maximum_health > CRITICAL_RATIO:
		return
	if not should_watch() or evacuation_panel == null or evacuation_panel.is_completed():
		return
	start()


## Shows the tip and slows the battle down.
func start() -> void:
	if _active:
		return
	var data := ProgressionStore.get_section(SAVE_SECTION)
	data[SAVE_KEY] = true
	ProgressionStore.set_section(SAVE_SECTION, data)
	_active = true
	_ending = false
	_ease = 0.0
	_last_ticks = Time.get_ticks_usec()
	visible = true
	_build_caption()


## Ends bullet time (evacuated, KEEP FIGHTING, destroyed or battle over).
func finish() -> void:
	if not _active:
		return
	_active = false
	_ending = true
	if _caption != null:
		_caption.queue_free()
		_caption = null


func _process(_delta: float) -> void:
	if not _active and not _ending:
		return
	# Real time, so easing is not slowed down by the bullet time itself.
	var now := Time.get_ticks_usec()
	var real_delta := float(now - _last_ticks) / 1000000.0
	_last_ticks = now
	_time += real_delta
	if _active and evacuation_panel != null and not evacuation_panel._is_pressable():
		finish()
	_ease = move_toward(_ease, 1.0 if _active else 0.0, real_delta / EASE_TIME)
	Engine.time_scale = lerpf(1.0, SLOW_SCALE, _ease * _ease * (3.0 - 2.0 * _ease))
	if _ending and _ease <= 0.0:
		_ending = false
		Engine.time_scale = 1.0
		visible = false
	queue_redraw()


func _exit_tree() -> void:
	if _active or _ending:
		Engine.time_scale = 1.0


# ==========================================
# Caption
# ==========================================

func _build_caption() -> void:
	_caption = PanelContainer.new()
	var style := Palette.make_panel_style(Color(Palette.UI_PANEL, 0.97), 12, 18.0, 14.0)
	style.border_width_top = 3
	style.border_color = Palette.THREAT
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 12
	_caption.add_theme_stylebox_override("panel", style)
	_caption.mouse_filter = Control.MOUSE_FILTER_STOP
	# Bottom-right, left of the big red button (the arrow sits in between).
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption.custom_minimum_size = Vector2(430.0, 0.0)
	_caption.offset_right = -260.0
	_caption.offset_bottom = -30.0
	add_child(_caption)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_caption.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", Palette.make_panel_style(Palette.THREAT, 8, 9.0, 4.0))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(_label("!", 14, Palette.UI_PANEL))
	header.add_child(badge)
	header.add_child(_label("HULL CRITICAL", 18, Palette.UI_TEXT))

	var body := _label(
		"Slam the BIG RED BUTTON 10 times to evacuate right now and keep the ore from this run.",
		13, Palette.UI_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	var warning := _label("If the ship is destroyed, ALL ore from this run is lost.", 13, Palette.THREAT)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(warning)
	var strategy := _label("Early on, when a planet is too tough, evacuating is the smart move.", 12, Palette.UI_MUTED)
	strategy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(strategy)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	var keep := Button.new()
	keep.text = "KEEP FIGHTING"
	keep.flat = true
	keep.focus_mode = Control.FOCUS_NONE
	keep.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	keep.add_theme_font_size_override("font_size", 11)
	keep.add_theme_color_override("font_color", Palette.UI_MUTED)
	keep.add_theme_color_override("font_hover_color", Palette.UI_TEXT)
	keep.pressed.connect(finish)
	footer.add_child(keep)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# ==========================================
# Drawing: red edge vignette, ring + arrow on the button
# ==========================================

func _draw() -> void:
	var strength: float = _ease
	if strength <= 0.0:
		return
	# Pulsing red edges ("about to break").
	var pulse: float = 0.6 + 0.4 * sin(_time * 5.0)
	var rect := Rect2(Vector2.ZERO, size)
	for index in range(8):
		var inset: float = float(index) * 10.0
		var alpha: float = 0.3 * strength * pulse * (1.0 - float(index) / 8.0)
		_draw_frame(rect.grow(-inset), 10.0, Color(Palette.THREAT, alpha))
	if not _active or evacuation_panel == null or not evacuation_panel.is_visible_in_tree():
		return
	# Ring around the button and an arrow pointing at it from the left.
	var global_rect := evacuation_panel.get_global_rect()
	var inverse := get_global_transform().affine_inverse()
	var center: Vector2 = inverse * global_rect.get_center()
	var scale_k: float = (inverse * global_rect.end - inverse * global_rect.position).x / maxf(global_rect.size.x, 1.0)
	var radius: float = (EvacuationPanel.RING_RADIUS + EvacuationPanel.RING_WIDTH + 18.0) * scale_k
	var ring_pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
	draw_arc(center, radius + 6.0 * ring_pulse, 0.0, TAU, 64, Color(Palette.ACCENT, 0.55 + 0.45 * ring_pulse), 4.0)
	var bob: float = sin(_time * 7.0) * 7.0
	var tip := center + Vector2(-(radius + 12.0 + bob), 0.0)
	_draw_arrow(tip, Vector2.RIGHT)


func _draw_frame(rect: Rect2, width: float, color: Color) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color)
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - width), Vector2(rect.size.x, width)), color)
	draw_rect(Rect2(rect.position + Vector2(0.0, width), Vector2(width, rect.size.y - width * 2.0)), color)
	draw_rect(Rect2(Vector2(rect.end.x - width, rect.position.y + width), Vector2(width, rect.size.y - width * 2.0)), color)


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
