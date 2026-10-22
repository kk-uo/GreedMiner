extends CanvasLayer

## Red glow round the screen edge whenever the ship takes hull damage
## (Ship.damaged). Bigger hits flash stronger; the glow fades out over
## FADE_TIME. Flat soft gradient (vertex colors), no textures; ignores input.
## Load with preload(); no class_name on purpose.

const COLOR := Color("D8313A")
const FADE_TIME: float = 0.55
## Edge depth as a share of the shorter screen side.
const DEPTH: float = 0.13
const MIN_FLASH: float = 0.45
const MAX_ALPHA: float = 0.75

var flash: float = 0.0
var _ship: Node = null
var _edge: Control


func _init() -> void:
	# Same layer as the battle HUD but placed before it, so the HUD stays clean.
	layer = 1
	_edge = Control.new()
	_edge.name = "Edge"
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge.draw.connect(_draw_edge)
	add_child(_edge)


## Listens to a ship's damage signal.
func watch(ship: Node) -> void:
	_ship = ship
	if ship != null and ship.has_signal("damaged"):
		ship.connect("damaged", _on_damaged)


func _on_damaged(amount: float) -> void:
	var max_hp := 1.0
	if _ship != null and is_instance_valid(_ship):
		max_hp = maxf(float(_ship.get("max_hp")), 1.0)
	# A hit of 10 % max HP or more flashes at full strength.
	var strength := clampf(MIN_FLASH + (1.0 - MIN_FLASH) * amount / (max_hp * 0.1), MIN_FLASH, 1.0)
	flash = maxf(flash, strength)
	_edge.queue_redraw()


func _process(delta: float) -> void:
	if flash <= 0.0:
		return
	flash = maxf(flash - delta / FADE_TIME, 0.0)
	_edge.queue_redraw()


func _draw_edge() -> void:
	if flash <= 0.0:
		return
	var size := _edge.size
	var alpha := MAX_ALPHA * ease(flash, 0.6)
	var depth := minf(size.x, size.y) * DEPTH * (0.8 + 0.2 * flash)
	var outer := [Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]
	var inner := [Vector2(depth, depth), Vector2(size.x - depth, depth), size - Vector2(depth, depth), Vector2(depth, size.y - depth)]
	var solid := Color(COLOR, alpha)
	var clear := Color(COLOR, 0.0)
	for side in range(4):
		var next := (side + 1) % 4
		_edge.draw_polygon(
			PackedVector2Array([outer[side], outer[next], inner[next], inner[side]]),
			PackedColorArray([solid, solid, clear, clear]))
