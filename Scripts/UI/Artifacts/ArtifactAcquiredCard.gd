extends Control

## "Artifact acquired" reveal, shown in battle and at the base when a magic
## artifact is granted: a card drops in at the top of the screen with the
## artifact's icon spinning up in a burst of rarity-coloured light, its name,
## rarity and what it does. The first artifact also says the Magic Stall has
## awakened. Non-blocking (ignores the mouse), runs in real time (so a boss
## finisher's slow motion does not stretch it) and removes itself.
## Load with preload(); no class_name on purpose.

const ARTIFACT_VISUAL := preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd")
const HOLD: float = 5.5
const WIDTH: float = 520.0

var definition: MagicArtifactDefinition
var first_artifact: bool = false

var _start_us: int = 0
var _card: PanelContainer
var _icon: Control
var _rarity: int = 0
var _color := Color.WHITE


## Shows the card on its own canvas layer under `host` (the battle or base
## scene), so it stays visible when the scene hides its HUD (e.g. the Rocky
## Planet finale). A newer card replaces an older one.
static func show_for(host: Node, artifact: MagicArtifactDefinition, first: bool) -> Control:
	if host == null or artifact == null or not host.is_inside_tree():
		return null
	var old := host.get_node_or_null("ArtifactAcquiredLayer")
	if old != null:
		old.name = "ArtifactAcquiredLayerOld"
		old.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "ArtifactAcquiredLayer"
	layer.layer = 59
	host.add_child(layer)
	var card: Control = load("res://Scripts/UI/Artifacts/ArtifactAcquiredCard.gd").new()
	card.name = "ArtifactAcquiredCard"
	card.set("definition", artifact)
	card.set("first_artifact", first)
	layer.add_child(card)
	return card


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_us = Time.get_ticks_usec()
	_rarity = ARTIFACT_VISUAL.rarity_index(definition)
	_color = ARTIFACT_VISUAL.rarity_color(_rarity)
	_build()


func _build() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := Palette.make_panel_style(Color(Palette.UI_PANEL, 0.97), 14, 18.0, 14.0)
	style.border_width_top = 3
	style.border_color = _color
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 14
	_card.add_theme_stylebox_override("panel", style)
	_card.custom_minimum_size = Vector2(WIDTH, 0.0)
	add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_card.add_child(row)
	_icon = Control.new()
	_icon.custom_minimum_size = Vector2(96.0, 96.0)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_icon)
	row.add_child(_icon)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	head.add_child(_label(tr("ARTIFACT ACQUIRED"), 11, Palette.UI_MUTED))
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", Palette.make_panel_style(Color(_color, 0.18), 6, 7.0, 1.0))
	chip.add_child(_label("◆ " + ARTIFACT_VISUAL.rarity_name(_rarity), 10, _color))
	head.add_child(chip)
	column.add_child(_label(tr(definition.display_name), 22, _color.lightened(0.25)))
	var body := _label(tr(definition.description), 13, Palette.UI_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(WIDTH - 170.0, 0.0)
	column.add_child(body)
	if first_artifact:
		column.add_child(_label("✦ " + tr("The Magic Stall has awakened at the base."), 12, Palette.ACCENT_LIGHT))


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _elapsed() -> float:
	return float(Time.get_ticks_usec() - _start_us) / 1000000.0


func _process(_delta: float) -> void:
	var t := _elapsed()
	if t > HOLD + 0.5:
		var layer := get_parent()
		if layer is CanvasLayer:
			layer.queue_free()
		else:
			queue_free()
		return
	var card_size := _card.get_combined_minimum_size()
	_card.size = card_size
	var drop := 1.0 - pow(1.0 - smoothstep(0.0, 0.45, t), 3.0)
	var leave := smoothstep(HOLD, HOLD + 0.45, t)
	_card.position = Vector2((size.x - card_size.x) * 0.5, lerpf(-card_size.y - 20.0, 24.0, drop) - 30.0 * leave)
	_card.modulate.a = minf(drop * 1.4, 1.0) * (1.0 - leave)
	_icon.queue_redraw()


func _draw_icon() -> void:
	var t := _elapsed()
	var c := _icon.size * 0.5
	# Light burst: rays turning behind the icon, brightest on arrival.
	var burst := 1.0 - smoothstep(0.3, 2.2, t)
	var glow := 0.35 + 0.65 * burst
	_icon.draw_circle(c, 46.0, Color(_color, 0.12 * glow + 0.06))
	for k in range(10):
		var a := t * 0.6 + TAU * float(k) / 10.0
		var dir := Vector2.RIGHT.rotated(a)
		var side := dir.orthogonal()
		var reach := 46.0 + 8.0 * burst
		_icon.draw_colored_polygon(PackedVector2Array([c + dir * 12.0 + side * 2.0, c + dir * reach + side * 7.0, c + dir * reach - side * 7.0, c + dir * 12.0 - side * 2.0]), Color(_color, (0.16 + 0.3 * burst) * (0.6 + 0.4 * float(k % 2))))
	_icon.draw_circle(c, 34.0, Color(Palette.UI_PANEL, 0.9))
	_icon.draw_arc(c, 34.0, 0.0, TAU, 40, Color(_color, 0.8), 2.0)
	# The icon pops in with a little overshoot, then floats.
	var pop := smoothstep(0.1, 0.55, t)
	var scale := pop * (1.0 + 0.18 * sin(PI * pop))
	var bob := sin(t * 2.2) * 2.0
	if scale > 0.01:
		ARTIFACT_VISUAL.draw_icon(_icon, c + Vector2(0, bob), 62.0 * scale, definition.artifact_id, _rarity)
	# Sparkles drifting up.
	for k in range(6):
		var ph := fposmod(t * 0.5 + float(k) / 6.0, 1.0)
		var x := c.x + sin(float(k) * 2.3) * 36.0
		var p := Vector2(x, c.y + 30.0 - 64.0 * ph)
		_icon.draw_circle(p, 2.2 * (1.0 - ph), Color(_color.lightened(0.5), sin(PI * ph)))
