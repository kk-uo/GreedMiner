class_name ResultBoard
extends Control

## End-of-battle result board (user pick C, "the dwarves' mining report"):
## a wooden board with a plaque, one pinned card per enemy type (live enemy
## art, kill count, a slammed "knocked out" stamp), a big boss card, the ore
## receipt split by source, and a weapon blueprint (new unlock) or the best
## weapon note. Built in code on a 1600x900 stage scaled to the screen.
## Everything animates in; a click skips to the end. Presentation only:
## `return_requested` is handled by BattleMain.

signal return_requested

const STAGE := Vector2(1600, 900)
const CREAM := Color("FBF3E4")
const PAPER := Color("EADCC0")
const PAPER_EDGE := Color("B89A6E")
const INK := Color("3B3530")
const MUTED := Color("8C7E6A")
const BROWN_INK := Color("6B3A22")
const ORANGE := Color("F08A24")
const RED := Color("D9465A")
const WOOD_A := Color("8A5A34")
const WOOD_B := Color("80522F")
const WOOD_FRAME := Color("6E4628")
const PLAQUE := Color("3B2A1E")
const BLUEPRINT := Color("2F5E8C")
const NOTE := Color("F6DE7A")
const STAMP_SOUND := preload("res://Assets/Audio/UI/stamp_thud.wav")
const ARTIFACT_VISUAL := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")
const ARTIFACT_PAPER := Color("3A2B45")

## outcome (&"victory"/&"defeat"), planet_name, stats (BattleStats), ore_total,
## unlocks (Array of module ids), hull, max_hull, waves_done, waves_total.
## New magic artifacts come from stats.artifacts ({id, name, rarity}).
var data: Dictionary = {}
var _stage: Control
var _font: Font
var _tweens: Array[Tween] = []
var _stamps: Array[Control] = []
var _finished: bool = false
var _button: Button
var _sound: AudioStreamPlayer


func setup(result: Dictionary) -> void:
	data = result


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_fit_stage)
	if get_parent() is Control:
		set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		# Under a CanvasLayer: cover the visible viewport ourselves.
		get_viewport().size_changed.connect(_cover_viewport)
		_cover_viewport()
	_font = get_theme_default_font()
	_sound = AudioStreamPlayer.new()
	_sound.stream = STAMP_SOUND
	_sound.volume_db = -8.0
	_sound.max_polyphony = 4
	add_child(_sound)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_stage = Control.new()
	_stage.size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_fit_stage()
	_build()
	dim.modulate.a = 0.0
	_track(create_tween()).tween_property(dim, "modulate:a", 1.0, 0.3)


func _cover_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _fit_stage() -> void:
	if _stage == null:
		return
	var k := minf(size.x / STAGE.x, size.y / STAGE.y)
	if k <= 0.0:
		k = 1.0
	_stage.scale = Vector2.ONE * k
	_stage.position = (size - STAGE * k) * 0.5


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not _finished:
		skip_animation()
		accept_event()


## Jumps every running entrance animation to its end state.
func skip_animation() -> void:
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.custom_step(60.0)
	_finished = true


func is_victory() -> bool:
	return data.get("outcome", &"victory") == &"victory"


func get_return_button() -> Button:
	return _button


# ------------------------------------------------------------ build

func _build() -> void:
	var stats: BattleStats = data.get("stats")
	var planet: String = data.get("planet_name", "")
	var board := _painter(Rect2(100, 64, 1400, 772), _draw_board)
	var plaque_text := (tr("%s · MINING REPORT") if is_victory() else tr("%s · MINING ABORTED")) % planet
	var plaque := _painter(Rect2(540, 40, 520, 76), func(c: Control) -> void:
		Palette.draw_rounded_rect(c, Rect2(Vector2(0, 6), c.size), 10.0, Color(0, 0, 0, 0.3))
		Palette.draw_rounded_rect(c, Rect2(Vector2.ZERO, c.size), 10.0, PLAQUE)
		_text_c(c, plaque_text, c.size.x * 0.5, 50, 32, CREAM))
	_drop_in(board, 0.0)
	_drop_in(plaque, 0.12)

	var rows: Array[Dictionary] = stats.enemy_rows() if stats != null else []
	var boss_row: Dictionary = {}
	if not rows.is_empty() and bool(rows[0]["boss"]):
		boss_row = rows.pop_front()
	var delay := 0.45
	if not boss_row.is_empty():
		_enemy_card(Rect2(160, 150, 330, 500), -0.035, boss_row, true, delay)
		delay += 0.18
	var area := Rect2(520, 150, 460, 560) if not boss_row.is_empty() else Rect2(160, 150, 820, 560)
	delay = _enemy_grid(area, rows, not boss_row.is_empty(), delay)
	if boss_row.is_empty() and rows.is_empty():
		var empty := _painter(Rect2(area.position + Vector2(0, 180), Vector2(area.size.x, 80)), func(c: Control) -> void:
			_text_c(c, tr("No enemies knocked out"), c.size.x * 0.5, 50, 26, CREAM))
		_pop_in(empty, delay)
	_receipt(delay)
	_reward_cards(delay + 0.5)
	_best_weapon_note(delay + 0.3)
	# Stamps slam once every card is pinned.
	var slam_at := delay + 0.25
	for stamp in _stamps:
		_slam(stamp, slam_at)
		slam_at += 0.12
	_button = Button.new()
	_button.text = tr("RETURN TO BASE")
	_button.position = Vector2(650, 760)
	_button.size = Vector2(300, 62)
	_button.add_theme_font_size_override("font_size", 28)
	for state in ["normal", "hover", "pressed", "focus"]:
		if state == "focus":
			_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			continue
		var box := StyleBoxFlat.new()
		box.bg_color = ORANGE.lightened(0.08) if state == "hover" else (ORANGE.darkened(0.1) if state == "pressed" else ORANGE)
		box.set_corner_radius_all(31)
		box.border_width_bottom = 6
		box.border_color = Color("B8661A")
		_button.add_theme_stylebox_override(state, box)
	_button.add_theme_color_override("font_color", Color.WHITE)
	_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.pressed.connect(func() -> void:
		_button.disabled = true
		return_requested.emit())
	_stage.add_child(_button)
	_pop_in(_button, slam_at + 0.1)
	var done := _track(create_tween())
	done.tween_interval(slam_at + 0.4)
	done.tween_callback(func() -> void: _finished = true)


## Lays out up to 8 cards (fewer columns with a boss card); extra enemy
## types fold into one "Others" card. Returns the next free delay.
func _enemy_grid(area: Rect2, rows: Array[Dictionary], has_boss: bool, delay: float) -> float:
	if rows.is_empty():
		return delay
	var max_cols := 3 if has_boss else 5
	var n := rows.size()
	var cols := clampi(ceili(float(n) / 2.0), 1, max_cols)
	var grid_rows := mini(2, ceili(float(n) / float(cols)))
	var capacity := cols * grid_rows
	var shown: Array[Dictionary] = rows.duplicate()
	if n > capacity:
		shown = rows.slice(0, capacity - 1)
		var rest := 0
		for row in rows.slice(capacity - 1):
			rest += int(row["count"])
		shown.append({"id": &"_others", "name": "Others", "scene": "", "boss": false, "count": rest, "types": n - capacity + 1})
	var gap := 26.0
	var card_w := minf(210.0, (area.size.x - gap * float(cols - 1)) / float(cols))
	var card_h := minf(250.0, (area.size.y - gap * float(grid_rows - 1)) / float(grid_rows))
	var used := Vector2(card_w * cols + gap * (cols - 1), card_h * grid_rows + gap * (grid_rows - 1))
	var origin := area.position + (area.size - used) * 0.5
	for i in range(shown.size()):
		var col := i % cols
		var row := i / cols
		var at := origin + Vector2(col * (card_w + gap), row * (card_h + gap))
		var tilts: Array[float] = [-0.05, 0.04, -0.02, 0.05, -0.04]
		var tilt: float = tilts[(i * 3 + 1) % 5]
		_enemy_card(Rect2(at, Vector2(card_w, card_h)), tilt, shown[i], false, delay)
		delay += 0.12
	return delay


func _enemy_card(rect: Rect2, tilt: float, row: Dictionary, boss: bool, delay: float) -> void:
	var card := Control.new()
	card.position = rect.position
	card.size = rect.size
	card.pivot_offset = rect.size * 0.5
	card.rotation = tilt
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(card)
	var count := int(row["count"])
	var shown := {"value": 0}
	var name_text := tr(String(row["name"]))
	if row.get("id") == &"_others":
		name_text = tr("Others") + "  " + tr("+%d types") % int(row.get("types", 0))
	var paper := _painter(Rect2(Vector2.ZERO, rect.size), func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_rect(Rect2(Vector2(6, 8), c.size), Color(0, 0, 0, 0.3))
		c.draw_rect(r, PAPER)
		c.draw_rect(r.grow(-8), PAPER_EDGE, false, 2.0)
		if boss:
			_text_c(c, "BOSS", c.size.x * 0.5, 64, 40, BROWN_INK)
		_text_c(c, name_text, c.size.x * 0.5, c.size.y - (70 if boss else 44), 26 if boss else 18, INK)
		_text_c(c, "×%d" % int(shown["value"]), c.size.x * 0.5, c.size.y - (22 if boss else 14), 36 if boss else 28, BROWN_INK))
	_move_to(paper, card)
	# Live enemy art, clipped to the picture area.
	var pic_rect := Rect2(12, 84, rect.size.x - 24, rect.size.y - 184) if boss else Rect2(10, 14, rect.size.x - 20, rect.size.y - 76)
	var pic := Control.new()
	pic.position = pic_rect.position
	pic.size = pic_rect.size
	pic.clip_contents = true
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pic)
	var scene_path := String(row.get("scene", ""))
	if scene_path != "":
		var portrait := EnemyPortrait.create(scene_path, minf(pic_rect.size.x, pic_rect.size.y) * (0.4 if boss else 0.34))
		if portrait != null:
			portrait.position = pic_rect.size * 0.5
			pic.add_child(portrait)
	# Pin and stamp.
	var _pin_242 := _painter(Rect2(rect.size.x * 0.5 - 10, -2, 20, 20), func(c: Control) -> void:
		c.draw_circle(Vector2(12, 13), 8, Color(0, 0, 0, 0.3))
		c.draw_circle(Vector2(10, 10), 8, RED)
		c.draw_circle(Vector2(8, 8), 3, Color(1, 1, 1, 0.6)))
	_move_to(_pin_242, card)
	_pin_242.z_index = 41
	var stamp_size := Vector2(170, 66) if boss else Vector2(minf(96.0, rect.size.x * 0.5), 38)
	var stamp_at := Vector2(rect.size.x * 0.5 + (70 if boss else rect.size.x * 0.24), (150 if boss else 34))
	var stamp_text := tr("DEFEATED") if boss else tr("KNOCKED OUT")
	var stamp := _painter(Rect2(stamp_at - stamp_size * 0.5, stamp_size), func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_rect(r, Color(RED, 0.14))
		c.draw_rect(r, RED, false, 4.0)
		c.draw_rect(r.grow(-7), RED, false, 1.5)
		var fs := 36 if boss else 18
		_stamp_text(c, stamp_text, fs))
	_move_to(stamp, card)
	stamp.rotation = -0.22
	stamp.visible = false
	# Enemy art may carry its own z_index; stamps always land on top.
	stamp.z_index = 40
	_stamps.append(stamp)
	_pop_in(card, delay)
	var roll := _track(create_tween())
	roll.tween_interval(delay + 0.1)
	roll.tween_method(func(v: float) -> void:
		shown["value"] = roundi(v)
		paper.queue_redraw(), 0.0, float(count), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _receipt(delay: float) -> void:
	var stats: BattleStats = data.get("stats")
	var lines: Array = stats.ore_rows() if stats != null else []
	var total := float(data.get("ore_total", stats.total_ore() if stats != null else 0.0))
	var listed := 0.0
	for line in lines:
		listed += float(line[1])
	if total - listed >= 1.0:
		lines.append([&"other", total - listed])
	if lines.size() > 5:
		var rest := 0.0
		for line in lines.slice(4):
			rest += float(line[1])
		lines = lines.slice(0, 4)
		lines.append([&"other", rest])
	var slots := clampi(lines.size(), 3, 5)
	var state := {"lines": 0, "total": 0.0}
	var victory := is_victory()
	var kills := stats.total_kills() if stats != null else 0
	var footer := tr("Kills %d  ·  Time %s  ·  Hull %d/%d") % [kills, _clock(float(stats.elapsed_seconds) if stats != null else 0.0), int(data.get("hull", 0)), int(data.get("max_hull", 0))]
	var waves := tr("Waves %d / %d") % [int(data.get("waves_done", 0)), int(data.get("waves_total", 0))]
	var receipt := _painter(Rect2(1010, 140, 420, 480), func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2(6, 8), c.size), Color(0, 0, 0, 0.3))
		c.draw_rect(Rect2(Vector2.ZERO, c.size), CREAM)
		_text_c(c, tr("ORE HAUL"), c.size.x * 0.5, 52, 30, INK)
		c.draw_line(Vector2(30, 76), Vector2(c.size.x - 30, 76), Color(INK, 0.3), 2)
		if lines.is_empty():
			_text_c(c, tr("No ore this time"), c.size.x * 0.5, 160, 20, MUTED)
		for i in range(mini(int(state["lines"]), lines.size())):
			var y := 120.0 + i * 40.0
			var label := tr(String(BattleStats.SOURCE_NAMES.get(lines[i][0], "Other")))
			c.draw_string(_font, Vector2(30, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
			for d in range(13):
				c.draw_circle(Vector2(170 + d * 12, y - 6), 1.4, Color(MUTED, 0.7))
			c.draw_string(_font, Vector2(c.size.x - 230, y), "%d" % roundi(float(lines[i][1])), HORIZONTAL_ALIGNMENT_RIGHT, 200, 24, INK)
		var base := 120.0 + slots * 40.0 - 10.0
		c.draw_line(Vector2(30, base), Vector2(c.size.x - 30, base), INK, 2)
		c.draw_line(Vector2(30, base + 6), Vector2(c.size.x - 30, base + 6), INK, 2)
		c.draw_string(_font, Vector2(30, base + 62), tr("Total"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, MUTED)
		Palette.draw_crystal(c, Vector2(220, base + 48), 1.4)
		var total_text := "%d" % roundi(float(state["total"]))
		c.draw_string(_font, Vector2(c.size.x - 330, base + 72), total_text, HORIZONTAL_ALIGNMENT_RIGHT, 300, 54, INK if victory else MUTED)
		if not victory and float(state["total"]) > 0.0:
			var w := _font.get_string_size(total_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
			c.draw_line(Vector2(c.size.x - 30 - w - 6, base + 52), Vector2(c.size.x - 24, base + 52), RED, 5)
		c.draw_string(_font, Vector2(30, base + 118), footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, MUTED)
		c.draw_string(_font, Vector2(30, base + 144), waves, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, MUTED))
	receipt.pivot_offset = receipt.size * 0.5
	receipt.rotation = 0.025
	var _pin_310 := _painter(Rect2(200, -6, 20, 20), func(c: Control) -> void:
		c.draw_circle(Vector2(12, 13), 8, Color(0, 0, 0, 0.3))
		c.draw_circle(Vector2(10, 10), 8, RED)
		c.draw_circle(Vector2(8, 8), 3, Color(1, 1, 1, 0.6)))
	_move_to(_pin_310, receipt)
	_slide_in(receipt, 0.35, Vector2(80, 0))
	var printing := _track(create_tween())
	printing.tween_interval(0.6)
	for i in range(lines.size()):
		printing.tween_callback(func() -> void:
			state["lines"] = i + 1
			receipt.queue_redraw())
		printing.tween_interval(0.14)
	printing.tween_method(func(v: float) -> void:
		state["total"] = v
		receipt.queue_redraw(), 0.0, total, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not victory:
		var lost := _painter(Rect2(1220, 470, 150, 56), func(c: Control) -> void:
			var r := Rect2(Vector2.ZERO, c.size)
			c.draw_rect(r, Color(RED, 0.14))
			c.draw_rect(r, RED, false, 4.0)
			c.draw_rect(r.grow(-7), RED, false, 1.5)
			_stamp_text(c, tr("LOST"), 28))
		lost.rotation = -0.2
		lost.visible = false
		lost.z_index = 40
		_stamps.append(lost)


## New weapons (blueprints) and new magic artifacts, pinned under the
## receipt: one wide card, two halves, or up to three compact cards (+N).
func _reward_cards(delay: float) -> void:
	var rewards: Array = []
	for id in data.get("unlocks", []):
		rewards.append({"kind": &"weapon", "id": id, "name": tr(String(ModuleCatalog.get_entry(id).get("name", id)))})
	var stats: BattleStats = data.get("stats")
	if stats != null:
		for artifact in stats.artifacts:
			rewards.append({"kind": &"artifact", "id": artifact["id"], "name": tr(String(artifact["name"])), "rarity": int(artifact["rarity"])})
	if rewards.is_empty():
		return
	var area := Rect2(1020, 646, 410, 150)
	var shown := rewards.slice(0, 3)
	var extra := rewards.size() - shown.size()
	var gap := 14.0
	var w := (area.size.x - gap * float(shown.size() - 1)) / float(shown.size())
	var tilts: Array[float] = [-0.03, 0.025, -0.02]
	for i in range(shown.size()):
		var rect := Rect2(area.position + Vector2(i * (w + gap), 0), Vector2(w, 132))
		var card := _reward_card(rect, shown[i], shown.size(), extra if i == shown.size() - 1 else 0)
		card.pivot_offset = card.size * 0.5
		card.rotation = tilts[i]
		_slide_in(card, delay + i * 0.15, Vector2(0, 60))


func _reward_card(rect: Rect2, reward: Dictionary, count: int, extra: int) -> Control:
	var weapon: bool = reward["kind"] == &"weapon"
	var wide := count == 1
	var icon_box := 100.0 if wide else 64.0
	var label := tr("NEW WEAPON BLUEPRINT") if weapon else tr("NEW MAGIC ARTIFACT")
	var rarity := int(reward.get("rarity", 0))
	var accent := Color("D6EDFF") if weapon else ARTIFACT_VISUAL.rarity_color(rarity)
	var name: String = reward["name"]
	var card := _painter(rect, func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		Palette.draw_rounded_rect(c, Rect2(Vector2(5, 7), c.size), 6.0, Color(0, 0, 0, 0.3))
		Palette.draw_rounded_rect(c, r, 6.0, BLUEPRINT if weapon else ARTIFACT_PAPER)
		if weapon:
			for k in range(1, int(c.size.x / 32.0) + 1):
				c.draw_line(Vector2(k * 32, 0), Vector2(k * 32, c.size.y), Color(1, 1, 1, 0.08), 1)
			for k in range(1, 4):
				c.draw_line(Vector2(0, k * 33), Vector2(c.size.x, k * 33), Color(1, 1, 1, 0.08), 1)
			c.draw_rect(r.grow(-8), Color(1, 1, 1, 0.5), false, 1.5)
		else:
			c.draw_rect(r.grow(-7), Color(accent, 0.7), false, 2.0)
			var glow_at := Vector2(80, c.size.y * 0.5) if wide else Vector2(c.size.x * 0.5, 50)
			c.draw_circle(glow_at, icon_box * 0.55, Color(accent, 0.16))
			c.draw_circle(glow_at, icon_box * 0.4, Color(accent, 0.12))
			ARTIFACT_VISUAL.draw_icon(c, glow_at, icon_box, reward["id"], rarity)
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if wide:
			c.draw_string(_font, Vector2(150, 54), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, accent)
			c.draw_string(_font, Vector2(150, 96), name, HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 160, 30, Color.WHITE)
		else:
			_text_c(c, label, c.size.x * 0.5, 100, 13, accent)
			_text_c(c, name, c.size.x * 0.5, 122, 17 if count == 2 else 15, Color.WHITE)
		if extra > 0:
			Palette.draw_rounded_rect(c, Rect2(c.size.x - 46, -10, 52, 28), 14.0, ORANGE)
			_text_c(c, "+%d" % extra, c.size.x - 20, 10, 18, Color.WHITE))
	if weapon:
		var icon := ModuleIcon.new()
		icon.show_backdrop = false
		icon.setup(reward["id"], icon_box, _module_icon_scale(reward["id"]) * (1.0 if wide else 0.65))
		icon.position = Vector2(30, 16) if wide else Vector2((rect.size.x - icon_box) * 0.5, 14)
		card.add_child(icon)
	# Pin.
	var pin := _painter(Rect2(rect.size.x * 0.5 - 10, -4, 20, 20), func(c: Control) -> void:
		c.draw_circle(Vector2(12, 13), 8, Color(0, 0, 0, 0.3))
		c.draw_circle(Vector2(10, 10), 8, RED)
		c.draw_circle(Vector2(8, 8), 3, Color(1, 1, 1, 0.6)))
	_move_to(pin, card)
	return card


## A small sticky note with the weapon that knocked out the most enemies.
func _best_weapon_note(delay: float) -> void:
	var stats: BattleStats = data.get("stats")
	var best := stats.best_weapon() if stats != null else &""
	if best == &"":
		return
	var best_name := tr(String(ModuleCatalog.get_entry(best).get("name", best)))
	var best_kills := int(stats.weapon_kills.get(best, 0))
	var note := _painter(Rect2(170, 712, 330, 96), func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_rect(Rect2(Vector2(5, 7), c.size), Color(0, 0, 0, 0.3))
		c.draw_rect(r, NOTE)
		c.draw_rect(Rect2(0, 0, c.size.x, 12), Color(0, 0, 0, 0.06))
		c.draw_string(_font, Vector2(104, 38), tr("BEST WEAPON"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, BROWN_INK)
		c.draw_string(_font, Vector2(104, 66), best_name, HORIZONTAL_ALIGNMENT_LEFT, 150, 22, INK)
		c.draw_string(_font, Vector2(104, 88), tr("%d knockouts") % best_kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED))
	var icon := ModuleIcon.new()
	icon.show_backdrop = false
	icon.setup(best, 80, _module_icon_scale(best) * 0.85)
	icon.position = Vector2(14, 10)
	note.add_child(icon)
	note.pivot_offset = note.size * 0.5
	note.rotation = 0.03
	_slide_in(note, delay, Vector2(0, 50))


## Base weapons are small in their scenes; fused ones are already large.
func _module_icon_scale(id: StringName) -> float:
	return 0.75 if String(ModuleCatalog.get_entry(id).get("scene", "")).contains("/Fusion/") else 1.4


# ------------------------------------------------------------ drawing helpers

func _draw_board(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	Palette.draw_rounded_rect(c, Rect2(Vector2(0, 12), c.size), 14.0, Color(0, 0, 0, 0.35))
	Palette.draw_rounded_rect(c, r, 14.0, WOOD_FRAME)
	for i in range(8):
		var y := 12.0 + i * 94.0
		Palette.draw_rounded_rect(c, Rect2(12, y, c.size.x - 24, 88), 6.0, WOOD_A if i % 2 == 0 else WOOD_B)
		var gx := 40.0 + float((i * 173) % 900)
		c.draw_line(Vector2(gx, y + 30), Vector2(gx + 120, y + 34), WOOD_FRAME, 2)


func _text_c(c: CanvasItem, text: String, center_x: float, baseline: float, size: int, color: Color) -> void:
	c.draw_string(_font, Vector2(center_x - 500.0, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, 1000.0, size, color)


## Stamp lettering: an outline pass makes the thin serif read as ink.
func _stamp_text(c: Control, text: String, size: int) -> void:
	var at := Vector2(c.size.x * 0.5 - 500.0, c.size.y * 0.5 + size * 0.36)
	c.draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 1000.0, size, maxi(2, size / 9), RED)
	c.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 1000.0, size, RED)


func _clock(seconds: float) -> String:
	var s := maxi(roundi(seconds), 0)
	return "%02d:%02d" % [s / 60, s % 60]


func _painter(rect: Rect2, fn: Callable, parent: Node = null) -> Control:
	var p := Painter.new()
	p.fn = fn
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else _stage).add_child(p)
	return p


func _move_to(node: Control, parent: Node) -> void:
	node.get_parent().remove_child(node)
	parent.add_child(node)


func _track(tween: Tween) -> Tween:
	tween.set_ignore_time_scale(true)
	_tweens.append(tween)
	return tween


func _drop_in(node: Control, delay: float) -> void:
	var to := node.position
	node.position = to - Vector2(0, 60)
	node.modulate.a = 0.0
	var t := _track(create_tween()).set_parallel(true)
	t.tween_property(node, "position", to, 0.4).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 1.0, 0.2).set_delay(delay)


func _pop_in(node: Control, delay: float) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * 1.25
	node.modulate.a = 0.0
	var t := _track(create_tween()).set_parallel(true)
	t.tween_property(node, "scale", Vector2.ONE, 0.25).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 1.0, 0.12).set_delay(delay)


func _slide_in(node: Control, delay: float, offset: Vector2) -> void:
	var to := node.position
	node.position = to + offset
	node.modulate.a = 0.0
	var t := _track(create_tween()).set_parallel(true)
	t.tween_property(node, "position", to, 0.35).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 1.0, 0.2).set_delay(delay)


func _slam(stamp: Control, delay: float) -> void:
	stamp.pivot_offset = stamp.size * 0.5
	stamp.scale = Vector2.ONE * 2.2
	stamp.modulate.a = 0.0
	var t := _track(create_tween())
	t.tween_interval(delay)
	t.tween_callback(func() -> void:
		stamp.visible = true
		if not _finished:
			_sound.pitch_scale = randf_range(0.92, 1.08)
			_sound.play())
	t.tween_property(stamp, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(stamp, "modulate:a", 1.0, 0.08)


class Painter extends Control:
	var fn: Callable

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


## A live, inert copy of an enemy scene used as card art (same idea as
## ModuleIcon): it never moves, attacks or counts as an enemy.
class EnemyPortrait extends Node2D:
	var _enemy: Node2D

	static func create(scene_path: String, fit_radius: float) -> EnemyPortrait:
		var scene := load(scene_path) as PackedScene
		if scene == null:
			return null
		var enemy := scene.instantiate() as Node2D
		if enemy == null:
			return null
		var portrait := EnemyPortrait.new()
		portrait._enemy = enemy
		var radius := _shape_radius(enemy)
		portrait.scale = Vector2.ONE * clampf(fit_radius / maxf(radius, 1.0), 0.15, 4.0)
		enemy.rotation = -PI * 0.5
		portrait.add_child(enemy)
		return portrait

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_make_inert()
		# One frame of processing lets visuals settle, then freeze for good.
		await get_tree().process_frame
		if is_instance_valid(_enemy):
			_make_inert()
			_enemy.process_mode = Node.PROCESS_MODE_DISABLED

	func _make_inert() -> void:
		if not is_instance_valid(_enemy):
			return
		for group in _enemy.get_groups():
			_enemy.remove_from_group(group)
		var area := _enemy as Area2D
		if area != null:
			area.set_deferred("monitoring", false)
			area.set_deferred("monitorable", false)
			area.collision_layer = 0
			area.collision_mask = 0
		if _enemy is BasicEnemy:
			(_enemy as BasicEnemy).set_physics_process(false)

	static func _shape_radius(enemy: Node) -> float:
		for child in enemy.get_children():
			var col := child as CollisionShape2D
			if col == null or col.shape == null:
				continue
			var shape := col.shape
			if shape is CircleShape2D:
				return (shape as CircleShape2D).radius
			if shape is CapsuleShape2D:
				return maxf((shape as CapsuleShape2D).radius, (shape as CapsuleShape2D).height * 0.5)
			if shape is RectangleShape2D:
				return (shape as RectangleShape2D).size.length() * 0.5
		return 20.0
