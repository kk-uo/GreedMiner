extends Node2D

## One temporary worker per mining module. Combat state never enters saves.
signal returned(worker: Node2D)
signal died(worker: Node2D)
const SPEED := 120.0
const MAX_HP := 50.0
const ARRIVAL_DISTANCE := 12.0
enum State { OUTBOUND, MINING, RETURNING }
var state: State = State.OUTBOUND
var hp := MAX_HP
var max_hp := MAX_HP
var ore := 0.0
var module: MiningModule
var crystal: Node2D
var battle: Node

# ------------------------------------------------------------------ presentation (Claude)
const ART := preload("res://Scripts/Mining/DwarfMinerArt.gd")
const CRYSTAL_SHATTER := preload("res://Scripts/VFX/CrystalShatter.gd")
const ORE_ART := preload("res://Scripts/Mining/OreArt.gd")
var _time: float = 0.0
## GraveDigSite this dwarf was sent to (released if it gives up early).
var _target_site: Node2D = null
var _facing: float = 0.0
var _last_position := Vector2.ZERO
var _moving: bool = false
var _chunk := Palette.COBALT

func _ready() -> void:
	max_hp = ResearchManager.get_dwarf_max_hp()
	hp = max_hp
	add_to_group("mining_dwarves")
	_time = randf() * 10.0
	_last_position = global_position
	z_index = 1

func _physics_process(delta: float) -> void:
	if not is_instance_valid(battle) or battle.get("_battle_ended") or not is_instance_valid(module):
		queue_free()
		return
	if state != State.RETURNING and (not is_instance_valid(crystal) or not crystal.call("can_be_mined")):
		recall()
	if state == State.RETURNING:
		if _move_toward(module.global_position, delta):
			if ore > 0.0:
				ResourceManager.add_mission_ore(ore)
				RewardPopup.spawn(battle, global_position, ore)
			returned.emit(self)
			queue_free()
	elif state == State.OUTBOUND:
		if _move_toward(crystal.global_position, delta):
			state = State.MINING
	elif state == State.MINING:
		var mined_from := crystal.global_position
		var crystal_color := _crystal_color(crystal)
		var reward: float = crystal.call("advance_mining", delta)
		if reward > 0.0:
			ore = reward
			_chunk = crystal_color
			CRYSTAL_SHATTER.spawn(battle, mined_from, crystal_color)
			recall()
	_update_presentation(delta)
	queue_redraw()

func _move_toward(destination: Vector2, delta: float) -> bool:
	var distance := global_position.distance_to(destination)
	if distance <= ARRIVAL_DISTANCE:
		return true
	global_position = global_position.move_toward(destination, minf((SPEED + ResearchManager.get_dwarf_movement_speed_bonus()) * delta, distance - ARRIVAL_DISTANCE))
	return global_position.distance_to(destination) <= ARRIVAL_DISTANCE + 0.01

func recall() -> void:
	state = State.RETURNING
	crystal = null

func is_carrying_ore() -> bool:
	return state == State.RETURNING and ore > 0.0 and hp > 0.0 and not is_queued_for_deletion()


## Outbound and empty-handed returning dwarves remain protected.
func is_enemy_targetable() -> bool:
	return hp > 0.0 and not is_queued_for_deletion() and (state == State.MINING or is_carrying_ore())


## Match the drawn worker position when mining beside a deposit.
func get_enemy_target_position() -> Vector2:
	if state == State.MINING and is_instance_valid(crystal):
		var back := float(crystal.call("get_visual_radius")) if crystal.has_method("get_visual_radius") else 10.0
		return to_global(-Vector2.RIGHT.rotated(_facing) * back)
	return global_position


func take_damage(amount: float) -> void:
	if not is_enemy_targetable() or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	queue_redraw()
	if hp <= 0.0:
		ore = 0.0
		# Presentation: the carried chunk shatters where the dwarf falls.
		CRYSTAL_SHATTER.spawn(get_parent(), global_position, _chunk, 0.6)
		died.emit(self)
		queue_free()

func _update_presentation(delta: float) -> void:
	_time += delta
	var step := global_position - _last_position
	_moving = step.length() > 0.05
	if _moving:
		_facing = step.angle()
	elif state == State.MINING and is_instance_valid(crystal):
		_facing = (crystal.global_position - global_position).angle()
	_last_position = global_position


static func _crystal_color(target: Node2D) -> Color:
	if not is_instance_valid(target):
		return Palette.COBALT
	if target.has_method("get_chip_color"):
		return target.call("get_chip_color")
	var kind: StringName = target.get("ore_kind") if target.get("ore_kind") != null else &""
	if kind != &"":
		return ORE_ART.chunk_color(kind)
	if bool(target.get("is_red")):
		return Color("E04B42")
	return Palette.GOLD if bool(target.get("_gold")) else Palette.COBALT


## Style A pickaxe dwarf (DwarfMinerArt). While mining it stands back from the
## crystal centre so the pick lands on the crystal's face.
func _draw() -> void:
	var batch := MeshBatch2D.new()
	var mining := state == State.MINING and is_instance_valid(crystal)
	var forward := Vector2.RIGHT.rotated(_facing)
	# Drawn back from the crystal / ore so the pick lands on its face.
	var back := float(crystal.call("get_visual_radius")) if mining and crystal.has_method("get_visual_radius") else 10.0
	var at := -forward * back if mining else Vector2.ZERO
	ART.draw(batch, {"at": at, "time": _time, "facing": _facing, "walking": _moving,
		"working": mining, "carrying": ore > 0.0, "chunk": _chunk})
	if mining:
		ART.draw_chips(batch, at + forward * 20.0, _time, -forward, _crystal_color(crystal))
	batch.flush_to(self)
	# Show health whenever enemies can attack the dwarf.
	if is_enemy_targetable():
		draw_rect(Rect2(at + Vector2(-13, -25), Vector2(26, 4)), Color("2A221D"))
		draw_rect(Rect2(at + Vector2(-12, -24), Vector2(24 * hp / max_hp, 2)), Color("88D469") if hp > max_hp * 0.35 else Color("E8604C"))
