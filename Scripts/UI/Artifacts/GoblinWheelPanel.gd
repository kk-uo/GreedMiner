class_name GoblinWheelPanel
extends Control

## Goblin Wheel battle HUD, now a small goblin slot machine (user pick B,
## goblin style, Claude sync 84): a plank-and-iron cabinet with a goblin head
## on top and three bone reels. The reels spin in and stop one by one on the
## three offered buffs (icons only; hovering a reel shows one line of text).
## Clicking a reel picks it: it flashes gold, coins burst from the goblin's
## grin, the other reels fold away, then the machine slides back down.
## Non-blocking: the battle keeps running throughout.
## API kept from the wheel: start_spin / choose_option / finish_immediately /
## is_presenting, signals spin_finished(buff_id) and presentation_finished.

signal spin_finished(buff_id: StringName)
signal presentation_finished

const PANEL_SIZE := Vector2(200.0, 132.0)
const REEL_SIZE := Vector2(48.0, 60.0)
const REEL_GAP: float = 10.0
const REEL_TOP: float = 46.0
const SLIDE_TIME: float = 0.25
const REEL_STOPS: Array[float] = [0.45, 0.7, 0.95]
## Time from the click to the buff being granted (spin_finished).
const SPIN_DURATION: float = 0.6
const RESULT_HOLD: float = 0.9
const EXIT_TIME: float = 0.3

const WOOD_DARK := Palette.GOBLIN_WOOD_DARK
const WOOD := Palette.GOBLIN_WOOD
const WOOD_LIGHT := Palette.GOBLIN_WOOD_LIGHT
const IRON_DARK := Palette.GOBLIN_IRON_DARK
const IRON := Palette.GOBLIN_IRON
const IRON_LIGHT := Palette.GOBLIN_IRON_LIGHT
const BONE := Palette.GOBLIN_BONE
const SKIN := Palette.GOBLIN_SKIN
const SKIN_DARK := Palette.GOBLIN_SKIN_DARK
const EYE := Palette.GOBLIN_EYE
const GOLD := Color("F2C14A")
const GOLD_DARK := Color("A8741E")
const INK := Color("2A1E14")

## buff id -> icon kind drawn on the reel.
const ICON_FOR := {
	&"ship_health": &"heart",
	&"flat_damage": &"sword_plus",
	&"damage_percent": &"sword_percent",
	&"weapon_range": &"scope",
	&"fire_rate": &"bolt",
	&"mining_rate": &"pick",
}
const STRIP: Array[StringName] = [&"heart", &"sword_plus", &"scope", &"bolt", &"pick", &"sword_percent"]

var options: Array[Dictionary] = []
var selected_index: int = -1
var _time: float = 0.0
var _chosen_at: float = -1.0
var _spinning: bool = false
var _awaiting_choice: bool = false
var _result_left: float = 0.0
var _exit_left: float = 0.0
var _granted: bool = false
var _hover: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -PANEL_SIZE.x - 20.0
	offset_top = -PANEL_SIZE.y - 164.0
	offset_right = -20.0
	offset_bottom = -164.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	hide()
	set_process(false)


func start_spin(offered_options: Array[Dictionary], result_index: int = -1) -> void:
	if offered_options.size() != 3:
		push_error("GoblinWheelPanel requires exactly three offered buffs.")
		return
	options = offered_options.duplicate(true)
	selected_index = -1
	_time = 0.0
	_chosen_at = -1.0
	_result_left = 0.0
	_exit_left = 0.0
	_granted = false
	_spinning = false
	_hover = -1
	_awaiting_choice = true
	show()
	set_process(true)
	if result_index >= 0:
		choose_option(result_index)
	queue_redraw()


## Picks one reel. Reels still spinning snap to their buff first.
func choose_option(option_index: int) -> bool:
	if options.size() != 3 or not _awaiting_choice:
		return false
	selected_index = clampi(option_index, 0, options.size() - 1)
	_time = maxf(_time, REEL_STOPS[REEL_STOPS.size() - 1])
	_awaiting_choice = false
	_spinning = true
	_chosen_at = _time
	queue_redraw()
	return true


func is_presenting() -> bool:
	return visible and (_awaiting_choice or _spinning or _result_left > 0.0 or _exit_left > 0.0)


## Grants the chosen buff now (skips the jackpot flourish).
func finish_immediately() -> void:
	if not _spinning:
		return
	_finish_spin()


func _process(delta: float) -> void:
	_time += delta
	modulate.a = _exit_left / EXIT_TIME if _exit_left > 0.0 else 1.0
	if _spinning and _time - _chosen_at >= SPIN_DURATION:
		_finish_spin()
	elif _result_left > 0.0:
		_result_left = maxf(_result_left - delta, 0.0)
		if _result_left <= 0.0:
			_exit_left = EXIT_TIME
	elif _exit_left > 0.0:
		_exit_left = maxf(_exit_left - delta, 0.0)
		if _exit_left <= 0.0:
			hide()
			set_process(false)
			presentation_finished.emit()
	queue_redraw()


func _finish_spin() -> void:
	if not _spinning or _granted:
		return
	_spinning = false
	_granted = true
	_result_left = RESULT_HOLD
	queue_redraw()
	spin_finished.emit(StringName(options[selected_index].get("id", &"")))


func _gui_input(event: InputEvent) -> void:
	if not _awaiting_choice:
		return
	if event is InputEventMouseMotion:
		var over := _reel_at((event as InputEventMouseMotion).position)
		if over != _hover:
			_hover = over
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var index := _reel_at(click.position)
	if index >= 0:
		choose_option(index)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()


func _reel_at(point: Vector2) -> int:
	for index in range(3):
		if _reel_rect(index).grow(3.0).has_point(point - _slide_offset()):
			return index
	return -1


func _reel_rect(index: int) -> Rect2:
	var total := REEL_SIZE.x * 3.0 + REEL_GAP * 2.0
	var x0 := (PANEL_SIZE.x - total) * 0.5
	return Rect2(Vector2(x0 + index * (REEL_SIZE.x + REEL_GAP), REEL_TOP), REEL_SIZE)


func _slide_offset() -> Vector2:
	var into := clampf(_time / SLIDE_TIME, 0.0, 1.0)
	into = 1.0 - pow(1.0 - into, 3.0)
	var out := 1.0 - _exit_left / EXIT_TIME if _exit_left > 0.0 else 0.0
	return Vector2(0.0, (1.0 - into) * 140.0 + out * out * 160.0)


# ------------------------------------------------------------ drawing

func _draw() -> void:
	if options.is_empty():
		return
	var off := _slide_offset()
	draw_set_transform(off, 0.0, Vector2.ONE)
	var since_pick := _time - _chosen_at if _chosen_at >= 0.0 else -1.0
	var cabinet := Rect2(8.0, 30.0, PANEL_SIZE.x - 16.0, PANEL_SIZE.y - 34.0)
	_draw_cabinet(cabinet)
	_draw_goblin(Vector2(PANEL_SIZE.x * 0.5, 22.0), since_pick)
	var fold := clampf((since_pick - 0.15) / 0.3, 0.0, 1.0) if since_pick >= 0.0 else 0.0
	for index in range(3):
		var chosen := index == selected_index and since_pick >= 0.0
		if not chosen and fold >= 1.0:
			continue
		var rect := _reel_rect(index)
		var scale_k := 1.0
		if chosen:
			# Slide the winner to the middle and give it a little jackpot pulse.
			var to_mid := _reel_rect(1).position.x - rect.position.x
			rect.position.x += to_mid * fold
			scale_k = 1.0 + 0.12 * sin(clampf(since_pick / 0.35, 0.0, 1.0) * PI)
		elif since_pick >= 0.0:
			scale_k = 1.0 - fold
		_draw_reel(index, rect, scale_k, chosen, since_pick)
	if since_pick >= 0.0:
		_draw_coins(Vector2(PANEL_SIZE.x * 0.5, 30.0), since_pick)
	_draw_tooltip()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cabinet(r: Rect2) -> void:
	Palette.draw_rounded_rect(self, Rect2(r.position + Vector2(3, 5), r.size), 9.0, Color(0, 0, 0, 0.35))
	Palette.draw_rounded_rect(self, r, 9.0, WOOD_DARK)
	# Planks.
	var inner := r.grow(-4.0)
	Palette.draw_rounded_rect(self, inner, 6.0, WOOD)
	for k in range(1, 4):
		var y := inner.position.y + inner.size.y * k / 4.0
		draw_line(Vector2(inner.position.x + 2, y), Vector2(inner.end.x - 2, y), WOOD_DARK, 1.5)
	draw_line(inner.position + Vector2(6, 6), Vector2(inner.end.x - 30, inner.position.y + 6), Color(WOOD_LIGHT, 0.6), 1.5)
	# Iron straps with rivets.
	for y in [r.position.y + 7.0, r.end.y - 9.0]:
		draw_rect(Rect2(r.position.x + 2, y - 3.5, r.size.x - 4, 7), IRON_DARK)
		draw_rect(Rect2(r.position.x + 2, y - 3.5, r.size.x - 4, 2.5), IRON)
		for x in range(int(r.position.x) + 10, int(r.end.x) - 4, 22):
			draw_circle(Vector2(x, y), 2.2, IRON_LIGHT)
			draw_circle(Vector2(x + 0.6, y + 0.6), 1.0, IRON_DARK)
	# Bone spikes on the top corners.
	for side in [-1.0, 1.0]:
		var base := Vector2(r.position.x + 10.0 if side < 0.0 else r.end.x - 10.0, r.position.y + 2.0)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-5, 0), base + Vector2(5, 0), base + Vector2(side * 7.0, -13)]), BONE)
		draw_line(base + Vector2(-3, -3), base + Vector2(side * 4.0, -9), Color(INK, 0.25), 1.0)


func _draw_goblin(at: Vector2, since_pick: float) -> void:
	var cheer := since_pick >= 0.0 and since_pick < SPIN_DURATION + RESULT_HOLD
	var bob := sin(_time * 3.0) * 1.2 if not cheer else -2.0 * absf(sin(since_pick * 14.0))
	at.y += bob
	# Ears.
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([at + Vector2(side * 10, -4), at + Vector2(side * 28, -12), at + Vector2(side * 12, 6)]), SKIN_DARK)
		draw_colored_polygon(PackedVector2Array([at + Vector2(side * 12, -2), at + Vector2(side * 23, -8), at + Vector2(side * 13, 3)]), SKIN)
	draw_circle(at + Vector2(1.5, 2.5), 15.0, Color(0, 0, 0, 0.3))
	draw_circle(at, 15.0, SKIN_DARK)
	draw_circle(at + Vector2(-1.5, -1.5), 13.0, SKIN)
	# Eyes: blink now and then; wide and glinting on a jackpot.
	var blink := fposmod(_time, 3.2) < 0.12 and not cheer
	for side in [-1.0, 1.0]:
		var eye := at + Vector2(side * 5.5, -3.0)
		if blink:
			draw_line(eye + Vector2(-2.5, 0), eye + Vector2(2.5, 0), INK, 1.5)
		else:
			draw_circle(eye, 3.4 if cheer else 2.8, INK)
			draw_circle(eye, 2.0 if cheer else 1.7, EYE)
			draw_circle(eye + Vector2(-0.7, -0.7), 0.7, Color.WHITE)
	# Grin with teeth (wider when cheering).
	var mouth_w := 9.0 if cheer else 7.0
	var mouth := PackedVector2Array([at + Vector2(-mouth_w, 4), at + Vector2(mouth_w, 4), at + Vector2(mouth_w * 0.6, 9.5 if cheer else 8.0), at + Vector2(-mouth_w * 0.6, 9.5 if cheer else 8.0)])
	draw_colored_polygon(mouth, INK)
	for k in range(-2, 3):
		var tx := at.x + k * mouth_w * 0.36
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 1.4, at.y + 4), Vector2(tx + 1.4, at.y + 4), Vector2(tx, at.y + 6.5)]), BONE)


func _draw_reel(index: int, rect: Rect2, scale_k: float, chosen: bool, since_pick: float) -> void:
	if scale_k <= 0.02:
		return
	var center := rect.get_center()
	var size := rect.size * scale_k
	var r := Rect2(center - size * 0.5, size)
	var hovered := _awaiting_choice and index == _hover
	if chosen or hovered:
		var glow := 0.55 + 0.45 * sin(_time * 10.0) if chosen else 0.6
		Palette.draw_rounded_rect(self, r.grow(4.0), 8.0, Color(GOLD, 0.35 * glow))
	Palette.draw_rounded_rect(self, r.grow(2.0), 7.0, INK)
	Palette.draw_rounded_rect(self, r, 6.0, BONE)
	# Inner shading: darker top and bottom, like a drum.
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.16)), Color(INK, 0.12))
	draw_rect(Rect2(Vector2(r.position.x + 2, r.end.y - 2 - r.size.y * 0.16), Vector2(r.size.x - 4, r.size.y * 0.16)), Color(INK, 0.12))
	var stop_at: float = REEL_STOPS[index]
	var icon_size := 15.0 * scale_k
	if _time < stop_at and selected_index < 0:
		# Spinning: the icon strip scrolls down, faded at the drum edges.
		var phase := _time * 9.0 + float(index) * 0.37
		var step := r.size.y * 0.6
		for j in range(-1, 2):
			var y := center.y + (float(j) + fposmod(phase, 1.0)) * step
			if absf(y - center.y) > r.size.y * 0.42:
				continue
			var kind: StringName = STRIP[posmod(floori(phase) - j + index * 2, STRIP.size())]
			_draw_icon(kind, Vector2(center.x, y), icon_size * 0.9, 0.45)
	else:
		var bounce := maxf(0.0, 1.0 - (_time - stop_at) / 0.18) if selected_index < 0 else 0.0
		var kind: StringName = ICON_FOR.get(StringName(options[index].get("id", &"")), &"coin")
		_draw_icon(kind, center - Vector2(0, 5.0 * bounce), icon_size, 1.0)
	var border := GOLD if (chosen or hovered) else Color(WOOD_DARK, 0.9)
	var outline := Palette.rounded_rect_points(r.grow(1.0), 7.0, 3)
	outline.append(outline[0])
	draw_polyline(outline, border, 2.5 if (chosen or hovered) else 1.5)
	if chosen and since_pick < 0.12:
		Palette.draw_rounded_rect(self, r, 6.0, Color(1, 1, 0.85, 0.8 * (1.0 - since_pick / 0.12)))


func _draw_coins(from: Vector2, t: float) -> void:
	if t > 0.9:
		return
	for k in range(12):
		var a := -PI * (0.12 + 0.76 * float(k) / 11.0)
		var v := 70.0 + float((k * 37) % 50)
		var p := from + Vector2(cos(a), sin(a)) * v * t + Vector2(0, 170.0 * t * t)
		var fade := 1.0 - t / 0.9
		var squash := absf(cos(t * 18.0 + float(k)))
		draw_set_transform(_slide_offset() + p, 0.0, Vector2(maxf(squash, 0.25), 1.0))
		draw_circle(Vector2.ZERO, 4.0, Color(GOLD_DARK, fade))
		draw_circle(Vector2(-0.5, -0.5), 3.0, Color(GOLD, fade))
	draw_set_transform(_slide_offset(), 0.0, Vector2.ONE)


## One small line under the reels, only while hovering (icons stay wordless).
func _draw_tooltip() -> void:
	var index := _hover if _awaiting_choice else -1
	if index < 0 or index >= options.size():
		return
	var text := tr(String(options[index].get("label", "BUFF")))
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16.0
	var box := Rect2(Vector2((PANEL_SIZE.x - width) * 0.5, PANEL_SIZE.y - 18.0), Vector2(width, 18.0))
	Palette.draw_rounded_rect(self, box, 6.0, Color(INK, 0.92))
	draw_string(font, box.position + Vector2(8.0, 13.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BONE)


func _draw_icon(kind: StringName, c: Vector2, s: float, alpha: float) -> void:
	var k := s / 15.0
	var col := func(color: Color) -> Color: return Color(color, color.a * alpha)
	match kind:
		&"heart":
			draw_circle(c + Vector2(-4, -3) * k, 5.2 * k, col.call(Color("D9465A")))
			draw_circle(c + Vector2(4, -3) * k, 5.2 * k, col.call(Color("D9465A")))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -1) * k, c + Vector2(9, -1) * k, c + Vector2(0, 10) * k]), col.call(Color("D9465A")))
			draw_circle(c + Vector2(-5, -5) * k, 1.8 * k, col.call(Color("FFC2CC")))
		&"sword_plus", &"sword_percent":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-1.6, 7) * k, c + Vector2(-1.6, -9) * k, c + Vector2(0, -12) * k, c + Vector2(1.6, -9) * k, c + Vector2(1.6, 7) * k]), col.call(IRON_LIGHT))
			draw_rect(Rect2(c + Vector2(-6, 6) * k, Vector2(12, 2.6) * k), col.call(GOLD))
			draw_rect(Rect2(c + Vector2(-1.2, 8.6) * k, Vector2(2.4, 4.4) * k), col.call(WOOD))
			var green: Color = col.call(Color("7BE36E"))
			if kind == &"sword_plus":
				draw_rect(Rect2(c + Vector2(4, -10.2) * k, Vector2(8, 2.4) * k), green)
				draw_rect(Rect2(c + Vector2(6.8, -13) * k, Vector2(2.4, 8) * k), green)
			else:
				draw_circle(c + Vector2(6, -10) * k, 1.9 * k, green)
				draw_circle(c + Vector2(11, -4) * k, 1.9 * k, green)
				draw_line(c + Vector2(11.5, -11) * k, c + Vector2(5.5, -3) * k, green, 1.6 * k)
		&"scope":
			var blue: Color = col.call(Color("8CD2FF"))
			draw_arc(c, 9.5 * k, 0.0, TAU, 24, blue, 2.0 * k)
			draw_arc(c, 4.5 * k, 0.0, TAU, 16, blue, 1.6 * k)
			for a in range(4):
				var v := Vector2.RIGHT.rotated(a * PI * 0.5)
				draw_line(c + v * 6.5 * k, c + v * 12.5 * k, blue, 2.0 * k)
			draw_circle(c, 1.5 * k, col.call(EYE))
		&"bolt":
			draw_colored_polygon(PackedVector2Array([c + Vector2(2, -12) * k, c + Vector2(-7, 1.5) * k, c + Vector2(-1, 1.5) * k, c + Vector2(-3, 12) * k, c + Vector2(7, -2.5) * k, c + Vector2(1, -2.5) * k]), col.call(Color("FFD65A")))
		&"pick":
			draw_line(c + Vector2(-7, 9) * k, c + Vector2(6, -6) * k, col.call(WOOD), 2.8 * k)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-2, -11) * k, c + Vector2(10, -2) * k, c + Vector2(12, -5) * k, c + Vector2(3, -12) * k]), col.call(IRON_LIGHT))
		_:
			draw_circle(c, 8.0 * k, col.call(GOLD_DARK))
			draw_circle(c, 6.0 * k, col.call(GOLD))
