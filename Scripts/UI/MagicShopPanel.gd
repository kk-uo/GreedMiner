class_name MagicShopPanel
extends Control

## Wandering merchant's storefront (Claude sync 99, design 1 "rug stall"):
## the hooded merchant on the left talks in a speech bubble; the wares lie on
## a patterned rug with price tags hanging on strings; the chosen ware is
## described in a strip at the bottom of the rug with a gold-coin BUY button.
## Product data, prices, ownership and purchases belong to ArtifactManager;
## this panel only presents them.

signal close_requested

const ArtifactVisual := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")
const FRAME_SIZE := Vector2(1460.0, 760.0)
const RUG_RECT := Rect2(420.0, 110.0, 1020.0, 560.0)
const CARD_SIZE := Vector2(184.0, 250.0)

const PARCH := Color("E9D9B6")
const INK := Color("3A2618")
const RUG := Color("8F2A2A")
const RUG_FIELD := Color("2F4D6A")
const RUG_TRIM := Color("C2843A")
const GOLD := Color("E9C15D")
const GOLD_D := Color("A16225")
const CLOAK_D := Color("2E2240")
const CLOAK := Color("4B3768")
const WOOD_D := Color("3B2A1E")

var _frame: Control
var _ore_label: Label
var _status_label: Label
var _hint_label: Label
var _items: HBoxContainer
var _info_icon: Control
var _info_name: Label
var _info_rarity: Label
var _info_text: Label
var _buy: Button
var _definitions: Array[MagicArtifactDefinition] = []
var _selected: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	ArtifactManager.collection_changed.connect(_on_data_changed.unbind(2))
	ResourceManager.stored_ore_changed.connect(_on_data_changed.unbind(1))
	WeaponUnlockManager.planet_completion_recorded.connect(_on_data_changed.unbind(1))
	hide()


func open_panel() -> void:
	show()
	_say(tr("Hehe... shiny ore for shiny treasures."))
	refresh()
	_fit_frame()
	_frame.modulate.a = 0.0
	create_tween().tween_property(_frame, "modulate:a", 1.0, 0.16)


## The stall is laid out at FRAME_SIZE and scaled down to fit the UI root.
func _fit_frame() -> void:
	if _frame == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var k := minf(1.0, minf(size.x * 0.96 / FRAME_SIZE.x, size.y * 0.96 / FRAME_SIZE.y))
	_frame.scale = Vector2.ONE * k
	_frame.position = (size - FRAME_SIZE * k) * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_frame()


func close_panel() -> void:
	hide()


func refresh() -> void:
	_ore_label.text = "%d" % int(ResourceManager.stored_ore)
	_definitions = ArtifactManager.get_shop_artifacts()
	for child in _items.get_children():
		_items.remove_child(child)
		child.queue_free()
	var any_unpriced := false
	for index in range(_definitions.size()):
		var definition := _definitions[index]
		any_unpriced = any_unpriced or definition.shop_price_ore <= 0
		var card := ShopCard.new()
		card.setup(definition, index)
		card.chosen.connect(select_item)
		_items.add_child(card)
	_hint_label.visible = any_unpriced
	select_item(clampi(_selected, 0, maxi(_definitions.size() - 1, 0)))


## Cards on the rug, one per product (exposed for tests).
func get_item_cards() -> Array[Node]:
	return _items.get_children()


func get_buy_button() -> Button:
	return _buy


func select_item(index: int) -> void:
	_selected = index
	for card in _items.get_children():
		(card as ShopCard).selected = (card as ShopCard).index == index
		card.queue_redraw()
	if index < 0 or index >= _definitions.size():
		_info_name.text = ""
		_info_rarity.text = ""
		_info_text.text = ""
		_buy.disabled = true
		_buy.text = tr("PRICE TBD")
		return
	var definition := _definitions[index]
	var rarity := ArtifactVisual.rarity_index(definition)
	_info_icon.set_meta("artifact_id", definition.artifact_id)
	_info_icon.set_meta("rarity", rarity)
	_info_icon.queue_redraw()
	_info_name.text = tr(definition.display_name)
	_info_rarity.text = tr(ArtifactVisual.rarity_name(rarity))
	_info_rarity.add_theme_color_override("font_color", ArtifactVisual.rarity_color(rarity))
	_info_text.text = tr(definition.description)
	var owned := ArtifactManager.owns_artifact(definition.artifact_id)
	if owned:
		_buy.text = tr("OWNED")
	elif definition.shop_price_ore <= 0:
		_buy.text = tr("PRICE TBD")
	else:
		_buy.text = tr("BUY · %d ORE") % definition.shop_price_ore
	_buy.disabled = not ArtifactManager.is_shop_unlocked() or owned or definition.shop_price_ore <= 0 or ResourceManager.stored_ore < definition.shop_price_ore
	_buy.set_meta("price", definition.shop_price_ore)
	_buy.set_meta("owned", owned)
	_buy.queue_redraw()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_frame = Control.new()
	_frame.size = FRAME_SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_frame)

	# Merchant and his speech bubble.
	var merchant := MerchantView.new()
	merchant.position = Vector2(20.0, 300.0)
	merchant.size = Vector2(360.0, 440.0)
	_frame.add_child(merchant)
	var bubble := PanelContainer.new()
	bubble.position = Vector2(0.0, 120.0)
	bubble.custom_minimum_size = Vector2(380.0, 120.0)
	bubble.add_theme_stylebox_override("panel", Palette.make_panel_style(PARCH, 18, 22.0, 16.0))
	_frame.add_child(bubble)
	_status_label = _label("", 24, INK)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size.x = 330.0
	bubble.add_child(_status_label)
	var tail := BubbleTail.new()
	tail.position = Vector2(150.0, 236.0)
	_frame.add_child(tail)

	# The rug and the wares on it.
	var rug := RugView.new()
	rug.position = RUG_RECT.position
	rug.size = RUG_RECT.size
	_frame.add_child(rug)
	var scroll := ScrollContainer.new()
	scroll.position = RUG_RECT.position + Vector2(48.0, 52.0)
	scroll.size = Vector2(RUG_RECT.size.x - 96.0, CARD_SIZE.y + 10.0)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_frame.add_child(scroll)
	_items = HBoxContainer.new()
	_items.add_theme_constant_override("separation", 6)
	_items.alignment = BoxContainer.ALIGNMENT_CENTER
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items)

	# Info strip with the coin button.
	var info := PanelContainer.new()
	info.position = RUG_RECT.position + Vector2(52.0, 366.0)
	info.size = Vector2(RUG_RECT.size.x - 104.0, 160.0)
	info.add_theme_stylebox_override("panel", Palette.make_panel_style(Color(0.08, 0.06, 0.05, 0.88), 14, 20.0, 14.0))
	_frame.add_child(info)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	info.add_child(line)
	_info_icon = Control.new()
	_info_icon.custom_minimum_size = Vector2(120.0, 120.0)
	_info_icon.draw.connect(func() -> void:
		if _info_icon.has_meta("artifact_id"):
			ArtifactVisual.draw_icon(_info_icon, _info_icon.size * 0.5, 108.0, _info_icon.get_meta("artifact_id"), int(_info_icon.get_meta("rarity", 0)))
	)
	line.add_child(_info_icon)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	line.add_child(details)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 16)
	details.add_child(title_row)
	_info_name = _label("", 30, Palette.UI_TEXT)
	title_row.add_child(_info_name)
	_info_rarity = _label("", 18, Palette.UI_MUTED)
	_info_rarity.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(_info_rarity)
	_info_text = _label("", 18, Color("BFAF9A"))
	_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(_info_text)
	_buy = CoinButton.new()
	_buy.custom_minimum_size = Vector2(132.0, 132.0)
	_buy.pressed.connect(func() -> void:
		if _selected >= 0 and _selected < _definitions.size():
			_purchase(_definitions[_selected].artifact_id)
	)
	line.add_child(_buy)

	# Header: title, hint, ore and close.
	var title := _label("WANDERING MERCHANT", 40, Palette.UI_TEXT)
	title.position = Vector2(RUG_RECT.position.x + 10.0, 6.0)
	_frame.add_child(title)
	_hint_label = _label("Prices are pending. Unpriced artifacts cannot be purchased.", 16, Palette.UI_MUTED)
	_hint_label.position = Vector2(RUG_RECT.position.x + 12.0, 58.0)
	_frame.add_child(_hint_label)
	var ore_icon := Control.new()
	ore_icon.position = Vector2(FRAME_SIZE.x - 210.0, 34.0)
	ore_icon.size = Vector2(22.0, 22.0)
	ore_icon.draw.connect(func() -> void:
		ore_icon.draw_colored_polygon(PackedVector2Array([Vector2(11, 0), Vector2(22, 11), Vector2(11, 22), Vector2(0, 11)]), GOLD)
	)
	_frame.add_child(ore_icon)
	_ore_label = _label("", 26, Palette.UI_TEXT)
	_ore_label.position = Vector2(FRAME_SIZE.x - 180.0, 26.0)
	_frame.add_child(_ore_label)
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 40)
	close.add_theme_color_override("font_color", Palette.UI_TEXT)
	close.add_theme_color_override("font_hover_color", Palette.ACCENT)
	close.position = Vector2(FRAME_SIZE.x - 64.0, 10.0)
	close.size = Vector2(56.0, 56.0)
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.pressed.connect(func() -> void: close_requested.emit())
	_frame.add_child(close)


func _purchase(artifact_id: StringName) -> void:
	var definition := ArtifactManager.get_definition(artifact_id)
	if ArtifactManager.purchase_shop_artifact(artifact_id):
		_say(tr("Deal! Fine wares deserve a fine turret.") + "\n" + tr("Artifact added to your collection. Equip it in the Hangar."))
	elif not ArtifactManager.is_shop_unlocked():
		_say(tr("Clear Verdant Planet to unlock the Magic Shop."))
	elif definition != null and definition.shop_price_ore <= 0:
		_say(tr("That one isn't priced yet."))
	elif definition != null and ResourceManager.stored_ore < definition.shop_price_ore:
		_say(tr("Not enough ore, friend..."))
	else:
		_say(tr("Purchase unavailable."))
	refresh()


func _say(text: String) -> void:
	_status_label.text = text


func _on_data_changed() -> void:
	if visible:
		refresh()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if not _frame.get_global_rect().has_point(click.global_position):
			close_requested.emit()
			accept_event()


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# ------------------------------------------------------------ pieces

## The patterned rug the wares lie on.
class RugView extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(10, 12), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, MagicShopPanel.RUG)
		draw_rect(r.grow(-18), MagicShopPanel.RUG_TRIM, false, 4.0)
		draw_rect(r.grow(-36), MagicShopPanel.RUG_FIELD)
		for x in range(8, int(size.x), 14):
			draw_line(Vector2(x, size.y), Vector2(x, size.y + 16), MagicShopPanel.RUG_TRIM, 3.0)
			draw_line(Vector2(x, 0), Vector2(x, -16), MagicShopPanel.RUG_TRIM, 3.0)
		for k in range(12):
			var c := Vector2(66.0 + k * 81.0, 330.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(10, 0), c + Vector2(0, 12), c + Vector2(-10, 0)]), Color(MagicShopPanel.RUG_TRIM, 0.45))


## One ware on its little cloth with a price tag hanging on a string.
class ShopCard extends Control:
	signal chosen(index: int)

	const Visual := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")
	var definition: MagicArtifactDefinition
	var index: int = 0
	var selected: bool = false
	var _hover: float = 0.0
	var _hovered: bool = false
	var _t: float = 0.0

	func setup(artifact: MagicArtifactDefinition, card_index: int) -> void:
		definition = artifact
		index = card_index
		custom_minimum_size = MagicShopPanel.CARD_SIZE
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void: _hovered = true)
		mouse_exited.connect(func() -> void: _hovered = false)

	func _process(delta: float) -> void:
		_t += delta
		_hover = move_toward(_hover, 1.0 if _hovered else 0.0, delta * 8.0)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			chosen.emit(index)
			accept_event()

	func _draw() -> void:
		if definition == null:
			return
		var rarity := Visual.rarity_index(definition)
		var color := Visual.rarity_color(rarity)
		var owned := ArtifactManager.owns_artifact(definition.artifact_id)
		var c := Vector2(size.x * 0.5, 150.0 + (10.0 if index % 2 == 1 else 0.0)) - Vector2(0, 6.0 * _hover)
		if selected:
			draw_circle(c, 84.0, Color(color, 0.16))
			draw_arc(c, 82.0, 0.0, TAU, 48, color, 3.0)
		# Cloth.
		draw_colored_polygon(PackedVector2Array([c + Vector2(-66, 38), c + Vector2(66, 38), c + Vector2(76, 62), c + Vector2(-76, 62)]), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(c + Vector2(-62, 32), Vector2(124, 26)), Color("E6D3B0"))
		draw_circle(c + Vector2(0, 6), 54.0, Color(color, 0.12 + 0.1 * _hover))
		Visual.draw_icon(self, c + Vector2(0, sin(_t * 1.8 + index) * 2.0 * _hover), 100.0, definition.artifact_id, rarity, false)
		if owned:
			draw_set_transform(c + Vector2(0, 10), -0.25, Vector2.ONE)
			draw_rect(Rect2(-56, -16, 112, 32), Color("7A1D24", 0.85), false, 3.0)
			draw_string(get_theme_default_font(), Vector2(-56, 9), tr("OWNED"), HORIZONTAL_ALIGNMENT_CENTER, 112, 20, Color("E0554A"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Price tag on a string, swaying a little.
		var sway := sin(_t * 1.6 + float(index) * 1.3) * 3.0
		var knot := c + Vector2(42, -46)
		var tag_at := Vector2(size.x * 0.5 - 6.0 + sway, 12.0)
		draw_line(knot, tag_at + Vector2(10, 38), MagicShopPanel.INK, 2.0)
		var tag := Rect2(tag_at, Vector2(86, 40))
		draw_rect(tag, MagicShopPanel.PARCH)
		draw_circle(tag.position + Vector2(10, 20), 4.0, Color("1E1813"))
		var price := "%d" % definition.shop_price_ore if definition.shop_price_ore > 0 else tr("TBD")
		draw_string(get_theme_default_font(), tag.position + Vector2(18, 29), price, HORIZONTAL_ALIGNMENT_CENTER, 64, 22, MagicShopPanel.INK)


## Gold-coin BUY button; greys out when the ware cannot be bought.
class CoinButton extends Button:
	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color", "font_hover_pressed_color"]:
			add_theme_color_override(state, Color(0, 0, 0, 0))
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.47
		var pressed_k := 3.0 if is_pressed() else 0.0
		var hover_k := 1.06 if is_hovered() and not disabled else 1.0
		var rim := MagicShopPanel.GOLD_D if not disabled else Color("5A524B")
		var face := MagicShopPanel.GOLD if not disabled else Color("8A8078")
		draw_circle(c + Vector2(4, 6), r, Color(0, 0, 0, 0.35))
		draw_circle(c + Vector2(0, pressed_k), r * hover_k, rim)
		draw_circle(c + Vector2(0, pressed_k), r * 0.87 * hover_k, face)
		draw_arc(c + Vector2(0, pressed_k), r * 0.74 * hover_k, 0.0, TAU, 40, rim, 2.0)
		var font := get_theme_default_font()
		var owned := bool(get_meta("owned", false))
		var price := int(get_meta("price", -1))
		var top := tr("OWNED") if owned else tr("BUY")
		var bottom := "" if owned else ("◆ %d" % price if price > 0 else tr("TBD"))
		draw_string(font, c + Vector2(-r, -2 + pressed_k), top, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 28, MagicShopPanel.INK)
		if not bottom.is_empty():
			draw_string(font, c + Vector2(-r, 28 + pressed_k), bottom, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 19, MagicShopPanel.INK)


## Hooded merchant, front view: glowing blinking eyes, pipe smoke.
class MerchantView extends Control:
	var _t: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var k := 1.6
		var c := Vector2(size.x * 0.5, 190.0 + sin(_t * 1.2) * 2.0)
		draw_circle(c + Vector2(6, 10) * k, 70 * k, Color(0, 0, 0, 0.3))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-70, 90) * k, c + Vector2(-58, -30) * k, c + Vector2(0, -78) * k, c + Vector2(58, -30) * k, c + Vector2(70, 90) * k]), MagicShopPanel.CLOAK_D)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-56, 90) * k, c + Vector2(-46, -22) * k, c + Vector2(0, -62) * k, c + Vector2(46, -22) * k, c + Vector2(56, 90) * k]), MagicShopPanel.CLOAK)
		draw_circle(c + Vector2(0, 6) * k, 36 * k, Color("140E1A"))
		var blink := 0.15 if fposmod(_t, 4.1) < 0.13 else 1.0
		var pulse := 0.8 + 0.2 * sin(_t * 2.4)
		for side in [-1.0, 1.0]:
			var eye: Vector2 = c + Vector2(14.0 * side, 0.0) * k
			draw_circle(eye, 10 * k * pulse, Color(1, 0.85, 0.4, 0.2))
			draw_set_transform(eye, 0.0, Vector2(1.0, blink))
			draw_circle(Vector2.ZERO, 5 * k, Color("FFD86A"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var bowl := c + Vector2(42, 22) * k
		draw_line(c + Vector2(8, 22) * k, bowl, MagicShopPanel.WOOD_D, 5 * k)
		draw_rect(Rect2(c + Vector2(36, 22) * k, Vector2(12, 14) * k), MagicShopPanel.WOOD_D)
		draw_circle(bowl, 4 * k, Color("FF7A2A").lerp(Color("FFD06A"), 0.5 + 0.5 * sin(_t * 3.0)))
		for i in range(4):
			var phase := fposmod(_t * 0.35 + float(i) * 0.25, 1.0)
			var puff := bowl + Vector2(sin(phase * 4.0 + float(i)) * 10.0 + phase * 14.0, -phase * 120.0)
			draw_circle(puff, (5.0 + phase * 14.0), Color(1, 1, 1, 0.28 * (1.0 - phase)))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-50, 60) * k, c + Vector2(50, 60) * k, c + Vector2(44, 80) * k, c + Vector2(-44, 80) * k]), Color("B8452F"))
		draw_circle(c + Vector2(-34, 96) * k, 9 * k, MagicShopPanel.GOLD_D)
		draw_circle(c + Vector2(-34, 96) * k, 6 * k, MagicShopPanel.GOLD)


class BubbleTail extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(44, 0), Vector2(12, 40)]), MagicShopPanel.PARCH)
