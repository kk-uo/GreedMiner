extends Node2D

## A patch of zombie graves a mining dwarf digs up (user rule: graves can no
## longer be clicked away; a dwarf dispatched to a grave clears every grave
## inside the dispatch circle, taking half the time of mining a crystal).
## It looks like a mining target to DwarfMiner / DwarfMiningController
## (can_be_mined, advance_mining, get_visual_radius, get_chip_color); it pays
## no ore - when the digging is done the graves crumble and the site frees
## itself, so the dwarf walks home empty-handed.

## Radius of the dispatch circle (world px).
const DIG_RADIUS: float = 70.0
## Digging time relative to mining a crystal (RockyCrystal.MINING_DURATION).
const DIG_TIME_FACTOR: float = 0.5
const RING := Color("C4A0FF")

var graves: Array[Node2D] = []
var mining_progress: float = 0.0
var _done: bool = false
var _time: float = 0.0


## Claims the given graves for this site (see Battlefield.get_zombie_graves_in()).
func setup(claimed: Array[Node2D]) -> void:
	graves = claimed
	for grave in graves:
		grave.set("dig_site", self)


static func dig_duration() -> float:
	return preload("res://Scripts/Battle/RockyCrystal.gd").MINING_DURATION * DIG_TIME_FACTOR


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _live_graves() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for grave in graves:
		if is_instance_valid(grave) and not grave.is_queued_for_deletion():
			result.append(grave)
	return result


func can_be_mined() -> bool:
	return not _done and not is_queued_for_deletion() and not _live_graves().is_empty()


## Same contract as RockyCrystal.advance_mining(); always returns 0 ore.
func advance_mining(seconds: float) -> float:
	if not can_be_mined() or seconds <= 0.0:
		return 0.0
	mining_progress += seconds
	var k := clampf(mining_progress / dig_duration(), 0.0, 1.0)
	for grave in _live_graves():
		grave.set("dig_progress", k)
	if k >= 1.0:
		_done = true
		for grave in _live_graves():
			grave.call("crumble")
		queue_free()
	return 0.0


func get_visual_radius() -> float:
	return 14.0


func get_chip_color() -> Color:
	return Color("8A8F96")


## Release any graves still claimed if the dwarf gives up (recalled / died).
func release() -> void:
	for grave in _live_graves():
		grave.set("dig_site", null)
		grave.set("dig_progress", 0.0)
		grave.modulate = Color.WHITE
	queue_free()


func _draw() -> void:
	# Dashed lilac circle marking the patch being dug, plus a progress bar.
	var segments := 28
	for k in range(segments):
		if k % 2 == 1:
			continue
		var a := TAU * float(k) / float(segments) + _time * 0.3
		draw_arc(Vector2.ZERO, DIG_RADIUS, a, a + TAU / float(segments), 4, Color(RING, 0.7), 2.0)
	if mining_progress > 0.0:
		var k := clampf(mining_progress / dig_duration(), 0.0, 1.0)
		draw_rect(Rect2(-24.0, -DIG_RADIUS - 14.0, 48.0, 6.0), Color("24201d"))
		draw_rect(Rect2(-23.0, -DIG_RADIUS - 13.0, 46.0 * k, 4.0), RING)
