extends RefCounted

## Shared look for every QTE in the game (mining and boss): a translucent white
## circle with thin white hint rings that keep shrinking into it ("tap here,
## quickly"). No progress is shown. The very first QTE the player ever sees
## also gets a "CLICK" label; after that the label never appears again.
## Load with preload(); no class_name on purpose.

const SAVE_SECTION: StringName = &"qte_hints"
const WHITE := Color(1.0, 1.0, 1.0)
## Seconds for one hint ring to shrink from HINT_START x radius to the circle.
const HINT_PERIOD: float = 1.2
const HINT_START: float = 2.0
const HINT_RINGS: int = 3
const POP_TIME: float = 0.28


## Translucent white target circle with shrinking hint rings.
## time: any running clock; alpha fades the whole thing; hints: draw the rings.
static func draw_target(canvas: CanvasItem, center: Vector2, radius: float, time: float, alpha: float = 1.0, hints: bool = true) -> void:
	if alpha <= 0.01 or radius <= 0.0:
		return
	canvas.draw_circle(center, radius, Color(WHITE, 0.16 * alpha))
	canvas.draw_arc(center, radius, 0.0, TAU, _segments(radius), Color(WHITE, 0.75 * alpha), 2.4)
	if not hints:
		return
	for index in range(HINT_RINGS):
		var k: float = fposmod(time / HINT_PERIOD + float(index) / float(HINT_RINGS), 1.0)
		var ring_radius: float = radius * lerpf(HINT_START, 1.0, k)
		# Fades in while far out, peaks just before reaching the circle.
		var ring_alpha: float = (k / 0.6 if k < 0.6 else (1.0 - k) / 0.4) * 0.6
		canvas.draw_arc(center, ring_radius, 0.0, TAU, _segments(ring_radius), Color(WHITE, ring_alpha * alpha), 1.8)


## Ripple played when a click lands (k: 0..1 over POP_TIME).
static func draw_pop(canvas: CanvasItem, center: Vector2, radius: float, k: float) -> void:
	if k < 0.0 or k >= 1.0:
		return
	var eased: float = 1.0 - pow(1.0 - k, 2.0)
	var ring_radius: float = radius * lerpf(0.9, 1.6, eased)
	canvas.draw_arc(center, ring_radius, 0.0, TAU, _segments(ring_radius), Color(WHITE, 0.9 * (1.0 - k)), 3.0 * (1.0 - k) + 0.6)
	canvas.draw_circle(center, radius, Color(WHITE, 0.22 * (1.0 - k)))


## "CLICK" label under a target, only for the player's first QTE.
static func draw_click_label(canvas: CanvasItem, center: Vector2, radius: float, time: float, alpha: float = 1.0) -> void:
	var font: Font = MiningQteVisual.ui_font()
	if font == null:
		return
	var pulse: float = 0.8 + 0.2 * sin(time * 6.0)
	var size: int = 16
	var text := TranslationServer.translate("CLICK")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := center + Vector2(-width * 0.5, radius + 22.0)
	canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.08, 0.06, 0.05, 0.7 * alpha * pulse))
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(WHITE, alpha * pulse))


## True only the first time it is called in the player's whole save: the
## caller (a QTE that is starting) shows the "CLICK" label for its lifetime.
static func claim_click_hint() -> bool:
	var store: Node = Engine.get_main_loop().root.get_node_or_null("ProgressionStore") if Engine.get_main_loop() is SceneTree else null
	if store == null:
		return false
	var section: Dictionary = store.get_section(SAVE_SECTION)
	if bool(section.get("click_label_shown", false)):
		return false
	section["click_label_shown"] = true
	store.set_section(SAVE_SECTION, section)
	return true


static func _segments(radius: float) -> int:
	return clampi(int(radius * 0.6) + 16, 20, 72)
