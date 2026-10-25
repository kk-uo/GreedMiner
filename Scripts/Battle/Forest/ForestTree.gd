class_name ForestTree
extends Node2D

## One tree of the forest; every tree is a potential treant (user design):
## - standing: a normal tree. A scheduled treant tears itself out of it
##   (uproot()), leaving an empty SPOT (a hole with torn roots).
## - spot: during a rainstorm the tree regrows from the spot (regrow()); the
##   next wave can uproot it again.
## - chopped: dwarves dug it out (a standing tree or an empty spot); the point
##   is closed for the rest of the battle and never regrows.
## Standing / spot / chopped trees are drawn by ForestTerrain in baked chunks;
## this node itself only draws transient things (dig ring, regrow growth).
signal felled(tree: ForestTree)
## Presentation: the chunk renderer re-bakes this tree's chunk.
signal state_changed(tree: ForestTree)

const ART := preload("res://Scripts/Battle/Forest/ForestArt.gd")
const REGROW_TIME: float = 1.2

@export var canopy_radius: float = 24.0
## &"oak" or &"giant" (bigger crown with roots).
var kind: StringName = &"oak"
## Row round the clearing (1 = the edge); wave N raises rings 1..N.
var ring: int = 1
var chopped: bool = false
## True while the tree is an empty spot after a treant left it.
var uprooted: bool = false
## True between being picked for a ring raise and the treant appearing: the
## tree still stands (drawn as a tree) but can no longer be picked again.
var reserved: bool = false
## True once a treant has come out of this tree at least once.
var has_spawned_treant: bool = false
var spawned_enemy_id: StringName = &"treant"
var chop_site: Node2D
var dig_progress: float = 0.0
var _regrow_delay: float = 0.0
var _regrow_age: float = -1.0


func can_be_chopped() -> bool:
	return not chopped and not is_queued_for_deletion() and not is_instance_valid(chop_site)


## Standing and able to release a treant.
func is_standing() -> bool:
	return not chopped and not uprooted and not reserved and _regrow_age < 0.0


func chop() -> void:
	if chopped:
		return
	chopped = true
	chop_site = null
	_regrow_age = -1.0
	set_process(false)
	felled.emit(self)
	state_changed.emit(self)
	queue_redraw()


## A treant tore itself out: the tree becomes an empty spot.
func uproot() -> void:
	reserved = false
	if chopped or uprooted:
		return
	uprooted = true
	has_spawned_treant = true
	state_changed.emit(self)


## Storm: grow back from the spot after `delay` seconds (animated here).
func regrow(delay: float = 0.0) -> void:
	if chopped or not uprooted or _regrow_age >= 0.0:
		return
	_regrow_delay = maxf(delay, 0.0)
	_regrow_age = 0.0
	set_process(true)


## Finishes any running regrowth at once (tests / battle end).
func finish_regrow() -> void:
	if _regrow_age < 0.0:
		return
	_regrow_age = -1.0
	uprooted = false
	set_process(false)
	state_changed.emit(self)
	queue_redraw()


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if _regrow_age < 0.0:
		set_process(false)
		return
	_regrow_age += delta
	if _regrow_age >= _regrow_delay + REGROW_TIME:
		finish_regrow()
		return
	queue_redraw()


func get_crown_radius() -> float:
	return canopy_radius * 1.55


## Seed of this tree's crown art (same as the chunk renderer uses), so a
## treant rising from it looks exactly like the tree.
func get_crown_seed() -> int:
	return int(position.x * 7.0 + position.y * 13.0)


func _draw() -> void:
	if _regrow_age >= 0.0:
		var t := clampf((_regrow_age - _regrow_delay) / REGROW_TIME, 0.0, 1.0)
		if t > 0.0:
			var e := 1.0 - pow(1.0 - t, 3.0)
			# Overshoot a little, like a sprout popping up.
			var pop := e + 0.12 * sin(PI * e)
			ART.canopy(self, Vector2.ZERO, get_crown_radius() * maxf(pop, 0.05), int(position.x * 7.0 + position.y * 13.0), ART.OAK, 7)
	if dig_progress > 0.0 and not chopped:
		draw_arc(Vector2.ZERO, get_crown_radius() * (0.5 if uprooted else 1.0) + 6.0, -PI * 0.5, -PI * 0.5 + TAU * dig_progress, 24, Color("B5D879"), 3.0)
