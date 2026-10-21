extends Node2D

## An individual crystal; the battlefield owns placement and battle owns rewards.
signal broken(world_position: Vector2, is_red: bool)

const MINING_DURATION := 10.0
var is_red := false
var _gold := false
var _size := 1.0
var _base_rotation := 0.0
var _broken := false
var _shake: Tween
## Shared mining progress belongs to the crystal, not an individual miner.
var mining_progress: float = 0.0
## Planet ore deposit (OreArt kind, e.g. &"amber"); empty for Rocky crystals.
## Same mining rules as a blue crystal; pays its planet's ore value.
var ore_kind: StringName = &""
## Mission ore paid per fully mined deposit (user values, before research
## multipliers): Verdant 80, Frozen 160, Volcanic 250, Graveyard 400.
const ORE_VALUES := {
	&"amber": 80.0,
	&"aurora": 160.0, &"silver": 160.0,
	&"obsidian": 250.0, &"fire": 250.0,
	&"biomass": 400.0, &"soul": 400.0,
}
const ORE_ART := preload("res://Scripts/Mining/OreArt.gd")
## Ore deposits are drawn bigger than a single crystal.
const ORE_DRAW_SCALE: float = 1.3
var _ore_time: float = 0.0

func can_be_mined() -> bool:
	return not _broken and not is_queued_for_deletion()

## Returns the ore once to the miner that completes the deposit.
func advance_mining(seconds: float) -> float:
	if not can_be_mined() or seconds <= 0.0:
		return 0.0
	mining_progress += seconds
	queue_redraw()
	if mining_progress < ResearchManager.get_crystal_mining_seconds():
		return 0.0
	_broken = true
	var reward := 30.0 if _gold else 50.0
	if not ore_kind.is_empty():
		reward = float(ORE_VALUES.get(ore_kind, reward))
	elif is_red:
		if ArtifactManager.owns_artifact(&"red_crystal"):
			reward = 100.0
		else:
			# The unique artifact is a permanent discovery; ore is carried home.
			reward = 30.0
			ArtifactManager.grant_artifact(&"red_crystal")
	var respawn_delay := ResearchManager.get_crystal_respawn_seconds()
	if respawn_delay > 0.0 and is_inside_tree():
		hide()
		get_tree().create_timer(respawn_delay, false).timeout.connect(_regrow)
	else:
		queue_free()
	return reward * ResearchManager.get_crystal_value_multiplier()


func _regrow() -> void:
	if not is_inside_tree():
		return
	var battle := get_tree().current_scene
	if battle != null and battle.get("_battle_ended") == true:
		return
	mining_progress = 0.0
	_broken = false
	show()
	queue_redraw()


func configure(crystal_size: float, angle: float, gold: bool, red: bool) -> void:
	_size = crystal_size
	_base_rotation = angle
	rotation = angle
	_gold = gold
	is_red = red


## Planet ore deposit (see ore_kind). Animated (flicker / glow).
func configure_ore(kind: StringName, deposit_size: float) -> void:
	ore_kind = kind
	_size = deposit_size
	_base_rotation = 0.0
	rotation = 0.0
	_ore_time = randf() * 10.0


## Presentation: how far a mining dwarf is drawn back from the centre.
func get_visual_radius() -> float:
	return 22.0 * _size if ore_kind != &"" else 10.0


func _process(delta: float) -> void:
	if ore_kind == &"":
		set_process(false)
		return
	_ore_time += delta
	queue_redraw()


func contains_world_point(point: Vector2) -> bool:
	if ore_kind != &"":
		return not _broken and to_local(point).length() <= 26.0 * _size
	var local := to_local(point) / _size
	return not _broken and Rect2(-10.0, -23.0, 20.0, 38.0).has_point(local)


func register_click() -> void:
	if _broken:
		return
	if _shake != null and _shake.is_valid():
		_shake.kill()
	rotation = _base_rotation
	_shake = create_tween()
	_shake.tween_property(self, "rotation", _base_rotation + 0.10, 0.04)
	_shake.tween_property(self, "rotation", _base_rotation - 0.07, 0.05)
	_shake.tween_property(self, "rotation", _base_rotation, 0.05)


func _draw() -> void:
	if ore_kind != &"":
		_draw_ore()
		return
	var light := Palette.GOLD if _gold else Palette.COBALT
	var dark := Palette.GOLD_SHADOW if _gold else Palette.COBALT_SHADOW
	var shine := Palette.GOLD_LIGHT if _gold else Palette.COBALT_LIGHT
	if is_red:
		light = Color("e04b42")
		dark = Color("87292b")
		shine = Color("ffb2a2")
	var glow := light
	glow.a = 0.10
	draw_circle(Vector2.ZERO, 30.0 * _size, glow)
	draw_circle(Vector2(2.0, 14.0 * _size), 9.0 * _size, Palette.SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _size)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -22), Vector2(8, -12), Vector2(8, 6), Vector2(0, 14)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -22), Vector2(-8, -12), Vector2(-8, 6), Vector2(0, 14)]), light)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -22), Vector2(-8, -12), Vector2(0, -9)]), shine)
	# Presentation: cracks spread over the crystal as it is mined.
	_draw_cracks(clampf(mining_progress / ResearchManager.get_crystal_mining_seconds(), 0.0, 1.0))
	_draw_progress_bar(-36.0)


func _draw_ore() -> void:
	var batch := MeshBatch2D.new()
	batch.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _size * ORE_DRAW_SCALE)
	ORE_ART.draw(batch, ore_kind, _ore_time)
	batch.flush_to(self)
	draw_set_transform(Vector2(0, -4) * _size, 0.0, Vector2.ONE * _size * ORE_DRAW_SCALE)
	_draw_cracks(clampf(mining_progress / ResearchManager.get_crystal_mining_seconds(), 0.0, 1.0))
	_draw_progress_bar(-48.0 * _size)


func _draw_progress_bar(height: float) -> void:
	# Display the shared progress even after the workers have been recalled.
	if mining_progress > 0.0 and not _broken:
		draw_set_transform(Vector2(0.0, height), -rotation, Vector2.ONE)
		draw_rect(Rect2(-24.0, -3.0, 48.0, 6.0), Color("24201d"))
		draw_rect(Rect2(-23.0, -2.0, 46.0 * clampf(mining_progress / ResearchManager.get_crystal_mining_seconds(), 0.0, 1.0), 4.0), Color("69ddd8"))


## Presentation: white hairline cracks, one more every ~20% of mining progress
## (crystal-local, drawn inside the current size transform).
const CRACKS := [
	[Vector2(0, -16), Vector2(-2, -10), Vector2(1, -5), Vector2(-1, 1)],
	[Vector2(-6, -11), Vector2(-3, -7), Vector2(-5, -1)],
	[Vector2(5, -8), Vector2(2, -3), Vector2(4, 3), Vector2(1, 8)],
	[Vector2(-6, 1), Vector2(-2, 5), Vector2(-4, 10)],
]

func _draw_cracks(progress: float) -> void:
	if progress < 0.15:
		return
	var shown := mini(int(ceil((progress - 0.15) / 0.85 * float(CRACKS.size()))), CRACKS.size())
	for index in range(shown):
		var points := PackedVector2Array(CRACKS[index])
		draw_polyline(Palette.offset_points(points, Vector2(0.6, 0.6)), Color(0, 0, 0, 0.3), 1.0)
		draw_polyline(points, Color(1, 1, 1, 0.85), 1.2)
