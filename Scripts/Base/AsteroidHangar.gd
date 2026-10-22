class_name AsteroidHangar
extends Battlefield

## The dwarven asteroid hold that frames the base (style A, code-drawn).
##
## Layout is authored on a 1280x720 "mock" canvas (the approved concept art)
## and scaled by LAYOUT_SCALE into world space, so the ship ends up exactly on
## the landing pad in the middle. The hangar pad, star map, lab and the
## Warehouse vault door are interactive; BaseMain asks get_hotspot_at() and
## sets `hovered`.

signal hover_changed(hotspot: StringName)

const MOCK_SIZE := Vector2(1280.0, 720.0)
## Mock-to-world scale. 1.875 makes the 192px ship sit on a ~375px pad.
const LAYOUT_SCALE: float = 1.875

const HOTSPOT_NONE: StringName = &""
const HOTSPOT_HANGAR: StringName = &"hangar"
const HOTSPOT_STAR_MAP: StringName = &"star_map"
const HOTSPOT_LAB: StringName = &"lab"
const HOTSPOT_WAREHOUSE: StringName = &"warehouse"
const HOTSPOT_MAGIC_STALL: StringName = &"magic_stall"

## Dwarven vault door in the bottom-right wall that opens the Warehouse.
const WarehouseVault := preload("res://Scripts/Base/WarehouseVault.gd")
const RuneShrine := preload("res://Scripts/Base/RuneShrine.gd")
## Solid rock around the hold and the mine tracks with ore carts.
const CavernRock := preload("res://Scripts/Base/CavernRock.gd")
const MineRails := preload("res://Scripts/Base/MineRails.gd")
## Which MineRails layout the hold uses (0 = A, 1 = B, 2 = C).
const RAIL_LAYOUT: int = 1

## Research lab node origin (mock coords) and its design-to-mock scale; the
## curved bench itself follows the hall wall (ResearchLab.bench_path_mock()).
const LAB_CENTER := Vector2(332.0, 238.0)
const LAB_SCALE: float = 0.62

const PAD_RECT := Rect2(562.0, 282.0, 156.0, 156.0)
const STAR_MAP_CENTER := Vector2(960.0, 230.0)
const STAR_MAP_RADIUS: float = 76.0
const MAGIC_STALL_RECT := RuneShrine.HIT_RECT

const WALL := Color("4A372B")
const WALL_RIM := Color("6A4D3A")
const WALL_CHUNK := Color("5E4636")
const FLOOR_SHADE := Color("6B523D")

const ASTEROID := [
	Vector2(130, 140), Vector2(220, 70), Vector2(380, 40), Vector2(560, 30), Vector2(720, 28),
	Vector2(880, 40), Vector2(1030, 70), Vector2(1140, 130), Vector2(1200, 230), Vector2(1215, 360),
	Vector2(1190, 490), Vector2(1120, 590), Vector2(1000, 660), Vector2(820, 695), Vector2(700, 705),
	Vector2(560, 705), Vector2(400, 690), Vector2(250, 650), Vector2(140, 580), Vector2(80, 470),
	Vector2(65, 340), Vector2(85, 220),
]
const HALL := [
	Vector2(230, 150), Vector2(400, 110), Vector2(640, 98), Vector2(880, 110), Vector2(1050, 160),
	Vector2(1110, 260), Vector2(1120, 380), Vector2(1080, 500), Vector2(980, 580), Vector2(760, 615),
	Vector2(520, 615), Vector2(300, 580), Vector2(190, 490), Vector2(165, 360), Vector2(180, 240),
]
const WALL_CHUNKS := [
	[Vector2(150, 170), Vector2(190, 150), Vector2(205, 185), Vector2(170, 200)],
	[Vector2(1120, 170), Vector2(1160, 190), Vector2(1150, 225), Vector2(1115, 205)],
	[Vector2(95, 380), Vector2(120, 360), Vector2(135, 395), Vector2(105, 410)],
	[Vector2(1165, 420), Vector2(1195, 410), Vector2(1190, 450), Vector2(1160, 445)],
	[Vector2(300, 70), Vector2(340, 62), Vector2(345, 88), Vector2(305, 92)],
	[Vector2(930, 58), Vector2(975, 62), Vector2(965, 88), Vector2(925, 82)],
	[Vector2(200, 610), Vector2(235, 600), Vector2(245, 630), Vector2(210, 640)],
	[Vector2(1040, 620), Vector2(1075, 605), Vector2(1085, 640), Vector2(1050, 648)],
]
## Crane on the pad's top-right corner: swings between the crate pile and the
## ship, picking up and dropping ammo crates (one cycle = CRANE_CYCLE seconds).
const CRANE_BASE := Vector2(752.0, 264.0)
const CRANE_ARM: float = 60.0
const CRANE_PILE_ANGLE: float = 1.15
const CRANE_PAD_ANGLE: float = 2.55
const CRANE_CYCLE: float = 11.0
## Ammo crate piles (mock): at the tunnel mouth, under the crane, by the vault.
const SUPPLY_PILE := Vector2(725.0, 585.0)
const CRANE_PILE := Vector2(777.0, 320.0)
const VAULT_PILE := Vector2(985.0, 545.0)
const CRATE_WOOD := Color("8A5A34")
const CRATE_DARK := Color("3B2A1E")

const LAMPS := [
	Vector2(230, 350), Vector2(1070, 340), Vector2(520, 130), Vector2(780, 130),
	Vector2(470, 590), Vector2(830, 590),
]

## Which hotspot the mouse is over; set by BaseMain, drives the highlight.
var hovered: StringName = HOTSPOT_NONE:
	set(value):
		if hovered == value:
			return
		hovered = value
		hover_changed.emit(value)
		queue_redraw()

## Name tags only make sense in the overview; BaseMain hides them while zoomed in.
## Even then a facility's tag only fades in while it is hovered or pinned.
var show_tags: bool = true:
	set(value):
		show_tags = value
		queue_redraw()

## Facilities whose name tag stays up (a tutorial arrow points at them).
var pinned_tags: Array[StringName] = []
## Per-facility name tag opacity, eased every frame (0 hidden .. 1 shown).
var _tag_alpha: Dictionary = {}

## Set while the first-artifact guide points the player toward this hotspot.
var artifact_guide_active: bool = false:
	set(value):
		artifact_guide_active = value
		queue_redraw()

var _lab: ResearchLab

var _time: float = 0.0
## 0 = vault door shut, 1 = fully open; eases toward the hover state.
var _vault_open: float = 0.0
## Magic Stall wake-up (0 dormant .. 1 awake); animates when the first artifact arrives.
var _stall_wake: float = 0.0
## Set by BaseMain while the Warehouse panel is open: the vault door stays open.
var vault_held_open: bool = false
var _crane_operator: BaseDwarf
## Animated parts (tunnel lights, crane, star map planets, magic stall, vault)
## draw on this child every frame; the hall itself (this node) only redraws
## when the hover state changes.
var _live: Node2D
## Canvas the shared draw helpers paint on (self for static, _live for animated).
var _c: Object = self


func _ready() -> void:
	world_size = MOCK_SIZE * LAYOUT_SCALE
	_spawn_cavern()
	_live = Node2D.new()
	_live.name = "LiveLayer"
	_live.draw.connect(_draw_live)
	add_child(_live)
	_spawn_lab()
	_spawn_trophies()
	_spawn_dwarves()
	_stall_wake = 1.0 if ArtifactManager.is_stall_unlocked() else 0.0
	ArtifactManager.stall_unlocked_changed.connect(queue_redraw.unbind(1))
	queue_redraw()


func _process(delta: float) -> void:
	# Star map spin, vault door, magic stall wake-up and the crane cycle.
	_time += delta
	var vault_target := 1.0 if hovered == HOTSPOT_WAREHOUSE or vault_held_open else 0.0
	_vault_open = move_toward(_vault_open, vault_target, delta / WarehouseVault.OPEN_TIME)
	var stall_target := 1.0 if ArtifactManager.is_stall_unlocked() else 0.0
	_stall_wake = move_toward(_stall_wake, stall_target, delta / RuneShrine.WAKE_TIME)
	if is_instance_valid(_crane_operator):
		_crane_operator.facing = float(_crane_state()["angle"])
	for hotspot in [HOTSPOT_HANGAR, HOTSPOT_STAR_MAP, HOTSPOT_LAB, HOTSPOT_WAREHOUSE, HOTSPOT_MAGIC_STALL]:
		var pinned: bool = hotspot in pinned_tags or (hotspot == HOTSPOT_MAGIC_STALL and artifact_guide_active)
		var target := 1.0 if show_tags and (hovered == hotspot or pinned) else 0.0
		_tag_alpha[hotspot] = move_toward(float(_tag_alpha.get(hotspot, 0.0)), target, delta / 0.18)
	if is_instance_valid(_live):
		_live.queue_redraw()


## Converts a mock-canvas point to this node's local (world) space.
static func mock_to_local(point: Vector2) -> Vector2:
	return point * LAYOUT_SCALE


## Returns which interactive area (if any) contains a global position.
func get_hotspot_at(global_point: Vector2) -> StringName:
	var mock := to_local(global_point) / LAYOUT_SCALE
	if PAD_RECT.grow(16.0).has_point(mock):
		return HOTSPOT_HANGAR
	if mock.distance_to(STAR_MAP_CENTER) <= STAR_MAP_RADIUS + 8.0:
		return HOTSPOT_STAR_MAP
	if _lab != null and _lab.contains_local(_lab.to_local(global_point)):
		return HOTSPOT_LAB
	if WarehouseVault.contains(mock):
		return HOTSPOT_WAREHOUSE
	if MAGIC_STALL_RECT.grow(8.0).has_point(mock):
		return HOTSPOT_MAGIC_STALL
	return HOTSPOT_NONE


## Global position of a hotspot's center, used for camera moves.
func get_hotspot_center(hotspot: StringName) -> Vector2:
	match hotspot:
		HOTSPOT_STAR_MAP:
			return to_global(mock_to_local(STAR_MAP_CENTER))
		HOTSPOT_LAB:
			return to_global(mock_to_local(ResearchLab.center_mock_point()))
		HOTSPOT_WAREHOUSE:
			return to_global(mock_to_local(WarehouseVault.CENTER))
		HOTSPOT_MAGIC_STALL:
			return to_global(mock_to_local(MAGIC_STALL_RECT.get_center()))
		_:
			return to_global(mock_to_local(PAD_RECT.get_center()))


## Static hall, baked once into a single mesh; only the hover highlights and
## name tags are drawn directly (this node redraws only when those change).
var _hall_mesh: ArrayMesh

func _draw() -> void:
	if _hall_mesh == null:
		var batch := MeshBatch2D.new()
		_c = batch
		batch.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * LAYOUT_SCALE)
		_draw_asteroid()
		_draw_hall()
		_draw_lamps()
		_draw_pad()
		_draw_crate_piles()
		_draw_star_map_body()
		_c = self
		_hall_mesh = batch.build()
	if _hall_mesh != null:
		draw_mesh(_hall_mesh, null)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * LAYOUT_SCALE)
	if hovered == HOTSPOT_HANGAR:
		var frame := Palette.rounded_rect_points(PAD_RECT.grow(18.0), 20.0)
		frame.append(frame[0])
		Palette.draw_hover_outline(self, frame, 3.0)
	if hovered == HOTSPOT_STAR_MAP:
		var ring := PackedVector2Array()
		for k in range(73):
			ring.append(STAR_MAP_CENTER + Vector2.RIGHT.rotated(TAU * float(k) / 72.0) * (STAR_MAP_RADIUS + 10.0))
		Palette.draw_hover_outline(self, ring, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Animated parts, every frame, on the live layer (above the rails).
static var _LIVE_BATCH := MeshBatch2D.new()

func _draw_live() -> void:
	# Tunnel lights, crane and planets go out as one batched command.
	_c = _LIVE_BATCH
	_LIVE_BATCH.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * LAYOUT_SCALE)
	_draw_tunnel()
	_draw_crane()
	_draw_star_map_planets()
	_LIVE_BATCH.flush_to(_live)
	_live.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * LAYOUT_SCALE)
	RuneShrine.draw(_live, _time, _stall_wake, hovered == HOTSPOT_MAGIC_STALL, artifact_guide_active)
	_live.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	WarehouseVault.draw(_live, LAYOUT_SCALE, _time, _vault_open, hovered == HOTSPOT_WAREHOUSE)
	_live.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_name_tags()
	_c = self


func _draw_asteroid() -> void:
	var outline := PackedVector2Array(ASTEROID)
	_c.draw_colored_polygon(outline, WALL_RIM)
	_c.draw_colored_polygon(Palette.offset_points(outline, Vector2(5.0, 6.0)), WALL)
	for chunk in WALL_CHUNKS:
		var points := PackedVector2Array(chunk)
		_c.draw_colored_polygon(points, WALL_CHUNK)
		_c.draw_colored_polygon(PackedVector2Array([points[0], points[1], (points[0] + points[1]) * 0.5 + Vector2(0.0, 6.0)]), Palette.planet(&"rocky")["ground_dark"])


func _draw_hall() -> void:
	var ground := Palette.planet(&"rocky")
	var hall := PackedVector2Array(HALL)

	# The wall casts a band of shadow onto the floor along the top-left edges.
	_c.draw_colored_polygon(hall, FLOOR_SHADE)
	for lit in Geometry2D.intersect_polygons(hall, Palette.offset_points(hall, Vector2(12.0, 14.0))):
		_c.draw_colored_polygon(lit, ground["ground"])

	# One large, calm light patch in the middle of the hall.
	var patch := PackedVector2Array()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		patch.append(Vector2(640.0, 360.0) + Vector2(cos(angle) * 300.0, sin(angle) * 230.0))
	for part in Geometry2D.intersect_polygons(patch, hall):
		_c.draw_colored_polygon(part, Color(ground["ground_light"], 0.55))

	# Stone slab seams, clipped to the hall.
	var seam := Color(ground["ground_dark"], 0.6)
	for x in [290.0, 380.0, 470.0, 560.0, 720.0, 810.0, 900.0, 990.0]:
		_draw_clipped_line(Vector2(x, 80.0), Vector2(x, 660.0), hall, seam)
	for y in [180.0, 270.0, 450.0, 540.0]:
		_draw_clipped_line(Vector2(140.0, y), Vector2(1160.0, y), hall, seam)


func _draw_clipped_line(from: Vector2, to: Vector2, polygon: PackedVector2Array, color: Color) -> void:
	for segment in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([from, to]), polygon):
		_c.draw_polyline(segment, color, 2.0)


func _draw_tunnel() -> void:
	var ground := Palette.planet(&"rocky")
	_c.draw_colored_polygon(PackedVector2Array([Vector2(590, 600), Vector2(690, 600), Vector2(712, 760), Vector2(568, 760)]), ground["ground_dark"])
	_c.draw_colored_polygon(PackedVector2Array([Vector2(590, 600), Vector2(600, 600), Vector2(580, 760), Vector2(568, 760)]), WALL)
	_c.draw_colored_polygon(PackedVector2Array([Vector2(680, 600), Vector2(690, 600), Vector2(712, 760), Vector2(700, 760)]), Color("3D2D23"))
	for step in range(4):
		var y := 625.0 + 35.0 * float(step)
		var blink := 0.55 + 0.45 * sin(_time * 3.0 - float(step) * 0.9)
		var light := Color(Palette.ACCENT, blink)
		_c.draw_circle(Vector2(600.0 - 5.0 * float(step), y), 3.0, light)
		_c.draw_circle(Vector2(680.0 + 6.0 * float(step), y), 3.0, light)


func _draw_lamps() -> void:
	for lamp in LAMPS:
		_c.draw_circle(lamp, 38.0, Color(Palette.ACCENT_LIGHT, 0.08))
		_c.draw_circle(lamp, 20.0, Color(Palette.ACCENT_LIGHT, 0.08))
	for lamp in LAMPS:
		_c.draw_circle(lamp, 5.0, Palette.MECH)
		_c.draw_circle(lamp + Vector2(-1.0, -1.0), 2.5, Palette.ACCENT_LIGHT)


func _draw_pad() -> void:
	var outer := PAD_RECT.grow(10.0)
	_c.draw_colored_polygon(Palette.rounded_rect_points(Rect2(outer.position + Vector2(6.0, 6.0), outer.size), 16.0), Palette.SHADOW_COLOR)
	_c.draw_colored_polygon(Palette.rounded_rect_points(outer, 16.0), Palette.MECH)

	# Safety-orange hazard band around the pad.
	var band := Palette.rounded_rect_points(PAD_RECT.grow(5.0), 13.0)
	band.append(band[0])
	_c.draw_polyline(band, Palette.ACCENT, 6.0)
	var stripes := Palette.rounded_rect_points(PAD_RECT.grow(5.0), 13.0)
	for index in range(0, stripes.size(), 2):
		_c.draw_circle(stripes[index], 2.5, Palette.UI_PANEL)

	_c.draw_colored_polygon(Palette.rounded_rect_points(PAD_RECT, 10.0), Palette.MECH)
	_c.draw_colored_polygon(Palette.rounded_rect_points(Rect2(PAD_RECT.position, PAD_RECT.size - Vector2(5.0, 5.0)), 10.0), Color("4A423B"))

	# Bone-white docking clamps at each corner.
	var corners := [
		[PAD_RECT.position + Vector2(6.0, 6.0), Vector2(1.0, 1.0)],
		[Vector2(PAD_RECT.end.x - 6.0, PAD_RECT.position.y + 6.0), Vector2(-1.0, 1.0)],
		[Vector2(PAD_RECT.position.x + 6.0, PAD_RECT.end.y - 6.0), Vector2(1.0, -1.0)],
		[PAD_RECT.end - Vector2(6.0, 6.0), Vector2(-1.0, -1.0)],
	]
	for corner in corners:
		var origin: Vector2 = corner[0]
		var direction: Vector2 = corner[1]
		_c.draw_rect(Rect2(origin, Vector2.ZERO).expand(origin + direction * Vector2(26.0, 8.0)), Palette.SHIP_PART)
		_c.draw_rect(Rect2(origin, Vector2.ZERO).expand(origin + direction * Vector2(8.0, 26.0)), Palette.SHIP_PART)



## Crane cycle: hold over the pile (hook down, grab a crate), swing to the
## ship, hold (lower and release), swing back, then idly look about.
## Returns {angle, crate (on hook), drop (0 up .. 1 hook lowered)}.
func _crane_state() -> Dictionary:
	var t := fposmod(_time, CRANE_CYCLE)
	var pile := CRANE_PILE_ANGLE
	var pad := CRANE_PAD_ANGLE
	if t < 1.4:
		return {"angle": pile, "crate": t > 0.9, "drop": sin(PI * t / 1.4)}
	if t < 4.0:
		return {"angle": lerp_angle(pile, pad, smoothstep(1.4, 4.0, t)), "crate": true, "drop": 0.0}
	if t < 5.4:
		return {"angle": pad, "crate": t < 4.9, "drop": sin(PI * (t - 4.0) / 1.4)}
	if t < 8.0:
		return {"angle": lerp_angle(pad, pile, smoothstep(5.4, 8.0, t)), "crate": false, "drop": 0.0}
	# Idle: the operator glances the boom left and right before the next load.
	var k := (t - 8.0) / (CRANE_CYCLE - 8.0)
	return {"angle": pile + sin(k * TAU) * 0.35 * sin(k * PI), "crate": false, "drop": 0.0}


func _draw_crane() -> void:
	var state := _crane_state()
	var angle: float = state["angle"]
	var dir := Vector2.RIGHT.rotated(angle)
	var side := Vector2(-dir.y, dir.x)
	var base := CRANE_BASE
	var arm_end := base + dir * CRANE_ARM
	var drop: float = state["drop"]
	# Turntable and boom shadow.
	_c.draw_circle(base + Vector2(4.0, 5.0), 13.0, Palette.SHADOW_COLOR)
	_c.draw_line(base + Vector2(6.0, 8.0), arm_end + Vector2(10.0, 13.0), Palette.SHADOW_COLOR, 9.0)
	_c.draw_circle(base, 13.0, Palette.MECH)
	_c.draw_arc(base, 13.0, 0.0, TAU, 28, Palette.ACCENT, 2.0)
	# Counterweight behind the cab.
	var back := base - dir * 18.0
	_c.draw_colored_polygon(PackedVector2Array([back + side * 9.0, back + side * 9.0 - dir * 10.0, back - side * 9.0 - dir * 10.0, back - side * 9.0]), Palette.MECH_LIGHT)
	_c.draw_line(back + side * 9.0 - dir * 5.0, back - side * 9.0 - dir * 5.0, Palette.ACCENT, 2.0)
	# Lattice boom.
	_c.draw_line(base, arm_end, Palette.MECH, 9.0)
	_c.draw_line(base + side * 2.5, arm_end + side * 2.5, Palette.MECH_LIGHT, 2.0)
	for k in range(1, 6):
		var a := base.lerp(arm_end, float(k) / 6.0)
		_c.draw_line(a - side * 3.5, a + side * 3.5 + dir * 6.0, Palette.MECH_LIGHT, 1.2)
	_c.draw_rect(Rect2(arm_end - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), Palette.ACCENT)
	# Cable and hook; the hook (and crate) shrink a little as they go down.
	var hook_scale := lerpf(1.0, 0.78, drop)
	var hook := arm_end + Vector2(2.0, 3.0) * drop * 3.0
	_c.draw_line(arm_end, hook, Palette.MECH_LIGHT, 1.5)
	if state["crate"]:
		_draw_crate(hook + Vector2(0.0, 2.0), 6.0 * hook_scale, angle)
	_c.draw_arc(hook, 3.0 * hook_scale, 0.3, PI + 0.3, 8, Palette.SHIP_PART, 1.6)


## Stacks of ammo crates the haulers and the crane move around.
func _draw_crate_piles() -> void:
	for pile in [[SUPPLY_PILE, 4, 0.2], [CRANE_PILE, 3, -0.3], [VAULT_PILE, 3, 0.5]]:
		var at: Vector2 = pile[0]
		var turn: float = pile[2]
		var offsets := [Vector2(-6, 4), Vector2(6.5, 3.5), Vector2(0, -5.5), Vector2(-1, 1)]
		for k in range(int(pile[1])):
			var size := 6.0 if k < 3 else 5.2
			_draw_crate(at + (offsets[k] as Vector2).rotated(turn) + (Vector2(-1.5, -2.5) if k == 3 else Vector2.ZERO), size, turn + float(k) * 0.35)


## One ammo crate (half-size `half`, mock units): planks, a cross brace and
## brass shell tips.
func _draw_crate(center: Vector2, half: float, turn: float) -> void:
	var xf := Transform2D(turn, center)
	var outer := _rect_points(xf, Vector2(half, half) * 2.0)
	_c.draw_colored_polygon(Palette.offset_points(outer, Vector2(2.5, 3.0)), Palette.SHADOW_COLOR)
	_c.draw_colored_polygon(outer, CRATE_DARK)
	_c.draw_colored_polygon(_rect_points(xf, Vector2(half, half) * 1.65), CRATE_WOOD)
	_c.draw_line(xf * Vector2(-half * 0.8, -half * 0.8), xf * Vector2(half * 0.8, half * 0.8), CRATE_DARK, 1.2)
	for k in [-1.0, 0.0, 1.0]:
		_c.draw_circle(xf * Vector2(k * half * 0.45, -half * 0.45), half * 0.14, Palette.GOLD)


func _draw_star_map_body() -> void:
	var center := STAR_MAP_CENTER
	_c.draw_circle(center + Vector2(6.0, 6.0), STAR_MAP_RADIUS, Palette.SHADOW_COLOR)
	_c.draw_circle(center, STAR_MAP_RADIUS, Palette.MECH)
	_c.draw_circle(center + Vector2(-2.0, -2.0), STAR_MAP_RADIUS - 6.0, Palette.MECH_LIGHT)
	_c.draw_circle(center, STAR_MAP_RADIUS - 16.0, Palette.UI_PANEL)
	_c.draw_arc(center, 22.0, 0.0, TAU, 40, Color(Palette.SHIP_PART, 0.35), 1.5)
	_c.draw_arc(center, 40.0, 0.0, TAU, 56, Color(Palette.SHIP_PART, 0.35), 1.5)
	_c.draw_circle(center, 7.0, Palette.GOLD)

	# Console the navigator dwarf stands at.
	var console := center + Vector2(-85.0, 57.0)
	var xf := Transform2D(deg_to_rad(30.0), console)
	_c.draw_colored_polygon(_rect_points(xf, Vector2(34.0, 22.0)), Palette.MECH)
	_c.draw_colored_polygon(_rect_points(xf * Transform2D(0.0, Vector2(-2.0, -3.0)), Vector2(22.0, 8.0)), Palette.ACCENT)



## The three destinations orbit slowly, matching the planet select screen.
func _draw_star_map_planets() -> void:
	var center := STAR_MAP_CENTER
	var spin := _time * 0.25
	var rocky := center + Vector2.RIGHT.rotated(spin) * 22.0
	var frozen := center + Vector2.RIGHT.rotated(spin * 0.7 + 2.3) * 40.0
	var volcanic := center + Vector2.RIGHT.rotated(spin * 0.7 + 4.4) * 40.0
	_c.draw_circle(rocky, 5.0, Palette.planet(&"rocky")["ground"])
	_c.draw_circle(rocky + Vector2(-1.0, -1.0), 2.0, Palette.GOLD)
	_c.draw_circle(frozen, 5.0, Palette.planet(&"frozen")["ground_light"])
	_c.draw_circle(volcanic, 5.0, Palette.planet(&"volcanic")["ground_light"])
	_c.draw_circle(volcanic, 1.6, Color("FF6A24"))


func _rect_points(xf: Transform2D, rect_size: Vector2) -> PackedVector2Array:
	var half := rect_size * 0.5
	return PackedVector2Array([
		xf * Vector2(-half.x, -half.y), xf * Vector2(half.x, -half.y),
		xf * Vector2(half.x, half.y), xf * Vector2(-half.x, half.y),
	])


## Name tags (live layer, unscaled so the text stays crisp): hidden unless the
## facility is hovered or pinned by a tutorial; they fade and rise in.
func _draw_name_tags() -> void:
	_draw_tag(mock_to_local(Vector2(640.0, PAD_RECT.end.y + 36.0)), "HANGAR", HOTSPOT_HANGAR)
	_draw_tag(mock_to_local(STAR_MAP_CENTER + Vector2(0.0, -STAR_MAP_RADIUS - 24.0)), "STAR MAP", HOTSPOT_STAR_MAP)
	_draw_tag(mock_to_local(ResearchLab.tag_mock_point()), "LAB", HOTSPOT_LAB)
	_draw_tag(mock_to_local(WarehouseVault.CENTER + WarehouseVault.floor_direction() * 74.0), "WAREHOUSE", HOTSPOT_WAREHOUSE)
	_draw_tag(mock_to_local(MAGIC_STALL_RECT.get_center() + Vector2(0.0, 66.0)), "MAGIC STALL", HOTSPOT_MAGIC_STALL)


## Opacity of a facility's name tag right now (0..1).
func get_tag_alpha(hotspot: StringName) -> float:
	return float(_tag_alpha.get(hotspot, 0.0))


func _draw_tag(center: Vector2, text: String, hotspot: StringName) -> void:
	var alpha := get_tag_alpha(hotspot)
	if alpha <= 0.01:
		return
	center += Vector2(0.0, 8.0 * (1.0 - alpha))
	text = tr(text)
	var font := ThemeDB.fallback_font
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.default_font != null:
		font = theme.default_font
	var font_size := 22
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pill := Rect2(center - Vector2(text_size.x * 0.5 + 18.0, 20.0), Vector2(text_size.x + 36.0, 40.0))
	Palette.draw_rounded_rect(_live, pill, 20.0, Color(Palette.UI_PANEL, 0.9 * alpha))
	_live.draw_string(font, Vector2(pill.position.x, center.y + 8.0), text, HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, font_size, Color(Palette.UI_TEXT, alpha))


## Rock all around the hold (behind everything) and the mine tracks on it.
func _spawn_cavern() -> void:
	var rock: Node2D = CavernRock.new()
	rock.name = "CavernRock"
	rock.hold = PackedVector2Array(ASTEROID)
	rock.scale = Vector2.ONE * LAYOUT_SCALE
	add_child(rock)
	var rails: Node2D = MineRails.new()
	rails.name = "MineRails"
	rails.set("layout", RAIL_LAYOUT)
	rails.scale = Vector2.ONE * LAYOUT_SCALE
	add_child(rails)


func _spawn_lab() -> void:
	_lab = ResearchLab.new()
	_lab.name = "ResearchLab"
	_lab.position = mock_to_local(LAB_CENTER)
	_lab.scale = Vector2.ONE * LAB_SCALE * LAYOUT_SCALE
	add_child(_lab)
	hover_changed.connect(func(hotspot: StringName) -> void: _lab.hovered = hotspot == HOTSPOT_LAB)


## Trophy decorations earned in battle (BaseTrophies).
const BaseTrophies := preload("res://Scripts/Base/BaseTrophies.gd")
const BaseSnowman := preload("res://Scripts/Base/BaseSnowman.gd")
## Where the Frozen Planet boss snowman stands (mock coords).
const SNOWMAN_AT := Vector2(470.0, 480.0)


func _spawn_trophies() -> void:
	if BaseTrophies.has_trophy(&"snowman"):
		var snowman: Node2D = BaseSnowman.new()
		snowman.name = "TrophySnowman"
		snowman.position = mock_to_local(SNOWMAN_AT)
		snowman.scale = Vector2.ONE * LAYOUT_SCALE
		add_child(snowman)


## The base crew: everyone has a job or wanders the hall (see BaseDwarf).
func _spawn_dwarves() -> void:
	var obstacles := _crew_obstacles()
	var dwarf_scale := LAYOUT_SCALE * 1.25
	var map := mock_to_local(STAR_MAP_CENTER)
	var pad := mock_to_local(PAD_RECT.get_center())
	var crew := [
		# Navigator studying a star chart, moving between viewpoints round the map.
		{"mode": &"job", "tool": &"chart", "tunic": Color("3F5A78"), "speed": 45.0, "steps": [
			{"to": mock_to_local(Vector2(860, 300)), "wait": 6.0, "face": map},
			{"to": mock_to_local(Vector2(1058, 322)), "wait": 5.0, "face": map},
			{"to": mock_to_local(Vector2(872, 168)), "wait": 5.0, "face": map},
		]},
		# Hauler: tunnel supply -> crane pile.
		{"mode": &"job", "tunic": Color("7A5A3A"), "speed": 85.0, "steps": [
			{"to": mock_to_local(Vector2(746, 576)), "wait": 0.8, "face": mock_to_local(SUPPLY_PILE), "carry": true},
			{"to": mock_to_local(Vector2(800, 343)), "wait": 0.7, "face": mock_to_local(CRANE_PILE), "carry": false},
		]},
		# Hauler: tunnel supply -> vault.
		{"mode": &"job", "tunic": Color("6B4F7A"), "speed": 80.0, "steps": [
			{"to": mock_to_local(Vector2(706, 566)), "wait": 1.0, "face": mock_to_local(SUPPLY_PILE), "carry": true},
			{"to": mock_to_local(Vector2(962, 527)), "wait": 0.8, "face": mock_to_local(VAULT_PILE), "carry": false},
		]},
		# Pad technician repairing the landing pad's edges.
		{"mode": &"job", "tool": &"wrench", "tunic": Color("4F6B4A"), "speed": 60.0, "steps": [
			{"to": mock_to_local(Vector2(534, 300)), "wait": 3.0, "face": pad, "work": true},
			{"to": mock_to_local(Vector2(534, 425)), "wait": 3.0, "face": pad, "work": true},
			{"to": mock_to_local(Vector2(640, 462)), "wait": 2.5, "face": pad, "work": true},
		]},
		# Vault guard with an axe.
		{"mode": &"station", "tool": &"axe", "tunic": Color("8A3B2E"), "at": mock_to_local(Vector2(1064, 468)), "face": mock_to_local(Vector2(760, 420))},
		# Two dwarves wandering the hall.
		{"mode": &"wander", "tunic": Color("A07A3E")},
		{"mode": &"wander", "tunic": Color("5A6E7E")},
	]
	for entry in crew:
		var dwarf := BaseDwarf.new()
		dwarf.mode = entry["mode"]
		dwarf.tool = entry.get("tool", &"")
		dwarf.tunic = entry["tunic"]
		dwarf.body_scale = dwarf_scale
		dwarf.walk_speed = float(entry.get("speed", 70.0))
		dwarf.obstacles = obstacles
		match dwarf.mode:
			&"job":
				dwarf.steps = entry["steps"]
				dwarf.route = PackedVector2Array([entry["steps"][0]["to"]])
			&"station":
				dwarf.route = PackedVector2Array([entry["at"]])
				dwarf.facing = (entry["face"] - entry["at"]).angle()
			&"wander":
				dwarf.pick_point = _random_floor_point
				dwarf.route = PackedVector2Array([_random_floor_point()])
		add_child(dwarf)
	# Crane operator sits in the cab; the hangar turns him with the boom.
	_crane_operator = BaseDwarf.new()
	_crane_operator.mode = &"station"
	_crane_operator.driven = true
	_crane_operator.tunic = Color("8A6A2E")
	_crane_operator.body_scale = LAYOUT_SCALE * 0.95
	_crane_operator.route = PackedVector2Array([mock_to_local(CRANE_BASE)])
	add_child(_crane_operator)


## Things the walking crew steer around (world space).
func _crew_obstacles() -> Array:
	var rects := [PAD_RECT.grow(14.0), MAGIC_STALL_RECT.grow(4.0)]
	var circles := [[STAR_MAP_CENTER, 84.0], [STAR_MAP_CENTER + Vector2(-85.0, 57.0), 18.0], [WarehouseVault.CENTER, 58.0],
			[CRANE_BASE, 15.0], [SUPPLY_PILE, 16.0], [CRANE_PILE, 15.0], [VAULT_PILE, 14.0]]
	if BaseTrophies.has_trophy(&"snowman"):
		circles.append([SNOWMAN_AT, 26.0])
	circles.append_array(ResearchLab.obstacle_circles_mock())
	var result := []
	for rect in rects:
		var r: Rect2 = rect
		result.append({"rect": Rect2(mock_to_local(r.position), r.size * LAYOUT_SCALE)})
	for circle in circles:
		result.append({"center": mock_to_local(circle[0]), "radius": float(circle[1]) * LAYOUT_SCALE})
	return result


var _floor_rng := RandomNumberGenerator.new()
var _floor_inset: PackedVector2Array

## A random free point on the hall floor (world space) for wandering dwarves.
func _random_floor_point() -> Vector2:
	if _floor_inset.is_empty():
		_floor_rng.randomize()
		var inset := Geometry2D.offset_polygon(PackedVector2Array(HALL), -45.0)
		_floor_inset = inset[0] if not inset.is_empty() else PackedVector2Array(HALL)
	var obstacles := _crew_obstacles()
	for attempt in range(40):
		var mock := Vector2(_floor_rng.randf_range(200.0, 1100.0), _floor_rng.randf_range(130.0, 600.0))
		if not Geometry2D.is_point_in_polygon(mock, _floor_inset):
			continue
		var point := mock_to_local(mock)
		var free := true
		for obstacle in obstacles:
			if obstacle.has("rect"):
				if (obstacle["rect"] as Rect2).grow(30.0).has_point(point):
					free = false
					break
			elif point.distance_to(obstacle["center"]) < float(obstacle["radius"]) + 30.0:
				free = false
				break
		if free:
			return point
	return mock_to_local(Vector2(640.0, 540.0))
