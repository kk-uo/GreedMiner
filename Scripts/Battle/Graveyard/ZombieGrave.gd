extends Node2D

## A fresh grave left by a dead zombie. Gameplay: it can no longer be
## clicked away - only a mining dwarf can dig it up (GraveDigSite: every grave
## inside the dispatch circle); WaveManager summons zombies from every intact one.
## Presentation (Claude): one of ZombieGraveArt's six looks at random. It
## rises out of the ground with a burst of dirt clods once the zombie's sink
## effect (UndeadDeath) has pulled the body under, and crumbles to dust when
## it is dug up. While being dug it trembles and darkens.

const GRAVE_ART := preload("res://Scripts/Battle/Graveyard/ZombieGraveArt.gd")
## Drawn at the same scale as the map's tombstones.
const DRAW_SCALE: float = 1.2
## The grave waits for the zombie to sink (UndeadDeath), then rises.
const RISE_DELAY: float = 0.75
const RISE_TIME: float = 0.45
const CLOD := Color("5A4A38")

static var _PEN := MeshBatch2D.new()

## 0..1 while a dwarf digs it up (presentation).
var dig_progress: float = 0.0
## The GraveDigSite that claimed it (so two dwarves never dig the same grave).
var dig_site: Node = null
## 0..5, random when left at -1.
var variant: int = -1
var rise_delay: float = RISE_DELAY

var _age: float = 0.0
var _clods: Array = []


func _ready() -> void:
	if variant < 0:
		variant = randi() % GRAVE_ART.VARIANTS
	for index in range(7):
		var a := TAU * float(index) / 7.0 + randf_range(-0.3, 0.3)
		_clods.append({"dir": Vector2(cos(a), sin(a) * 0.7), "dist": randf_range(14.0, 24.0), "r": randf_range(1.6, 2.8)})


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


## Dug up by a dwarf: crumbles into dust and is removed.
func crumble() -> void:
	if is_queued_for_deletion():
		return
	StoneDust.spawn(get_parent(), global_position, 8, 9.0, 45.0, 0.8)
	queue_free()


func _draw() -> void:
	var t := (_age - rise_delay) / RISE_TIME
	if t <= 0.0:
		return
	var c := _PEN
	var tremble := Vector2.ZERO
	if dig_progress > 0.0:
		# Being dug: trembles harder and darkens as the dwarf works.
		tremble = Vector2(sin(_age * 47.0), cos(_age * 39.0)) * 1.6 * dig_progress
		modulate = Color(1, 1, 1).lerp(Color(0.6, 0.55, 0.5), dig_progress)
	# Rise: squashes up out of the soil with a little overshoot.
	var k := clampf(t, 0.0, 1.0)
	var lift := 1.0 + 0.12 * sin(PI * k) if k < 1.0 else 1.0
	var grow := Vector2(lerpf(0.8, 1.0, k), lerpf(0.15, 1.0, 1.0 - pow(1.0 - k, 3.0)) * lift)
	c.draw_set_transform(Vector2(0, 6.0 * (1.0 - k)) + tremble, 0.0, grow * DRAW_SCALE)
	GRAVE_ART.draw(c, variant, _age)
	c.draw_set_transform(Vector2.ZERO)
	# Dirt clods thrown out as it breaks the surface.
	var burst := clampf(t * RISE_TIME / 0.5, 0.0, 1.0)
	if burst < 1.0:
		for clod in _clods:
			var out := 1.0 - pow(1.0 - burst, 2.0)
			var p: Vector2 = clod["dir"] * float(clod["dist"]) * out + Vector2(0, -sin(PI * burst) * 10.0 + 8.0)
			c.draw_circle(p, float(clod["r"]), Color(CLOD, 1.0 - burst * burst))
	c.flush_to(self)
