class_name Battlefield
extends Node2D

## Defines the finite world-space battlefield independently of the viewport,
## and procedurally generates the planet ground in the style-A flat look.
##
## Generation (once per battle, from one seed):
## 1. Terrain: FBM simplex noise is sampled on a grid, contoured with marching
##    squares at two levels and simplified (Ramer-Douglas-Peucker) into a few
##    large angular patches of ground_dark / ground / ground_light.
## 2. Placement: Poisson-disc sampling (Bridson) spaces every object class
##    evenly; noise fields modulate density so rocks cluster in rocky areas and
##    ore deposits follow "veins". Nothing overlaps and the ship clearing stays free.
## 3. Reserved special sites: evenly spaced empty spots kept clear of all
##    decoration, for interactive map objects added later (see get_special_sites).
## Everything is drawn once with primitives, so the map costs no texture memory.

## Emitted after (re)generation; special sites and terrain queries are ready.
signal generated(seed_value: int)
## Emitted once per broken crystal in global coordinates.
signal crystal_broken(world_position: Vector2, is_red: bool)

## Total playable map size in world pixels.
## Baked static map (see _draw) and the recorder the painters draw into.
var _baked_mesh: ArrayMesh
var _pen: Variant = self

@export var world_size: Vector2 = Vector2(3200.0, 2200.0)

## Ground palette key from Palette.PLANETS (rocky, jungle, frozen, volcanic).
@export var planet_theme: StringName = &"rocky"

## Map seed. 0 = a new random map every battle; any other value reproduces a map.
@export var map_seed: int = 0

## Radius around the map center kept free of rocks so the ship reads clearly.
@export var clear_radius: float = 220.0

@export_group("Terrain")
## Size of the ground patches: lower = bigger, calmer shapes.
@export var terrain_frequency: float = 0.0011
## Noise below this becomes ground_dark, above terrain_light_level ground_light.
@export_range(-1.0, 1.0) var terrain_dark_level: float = -0.16
@export_range(-1.0, 1.0) var terrain_light_level: float = 0.2
## Larger = more angular, fewer vertices in the patch outlines.
@export var terrain_simplify: float = 16.0

@export_group("Placement")
## Minimum spacing between rocks (Poisson-disc radius).
@export var rock_spacing: float = 105.0
@export var crater_spacing: float = 420.0
@export var deposit_spacing: float = 300.0
@export var max_deposits: int = 14
## Keep crystal deposits away from the map edge, including their visual extent.
@export_range(0.0, 1000.0, 10.0) var crystal_edge_margin: float = 200.0
## Screen-space padding for playable Rocky crystals at map generation time.
@export_range(0.0, 300.0, 10.0) var crystal_view_margin: float = 150.0
## Only the battle scene enables interactive Rocky Planet crystals.
@export var interactive_rocky_crystals: bool = false
## Only the battle scene turns Verdant Planet trees into destructible nodes
## (VerdantTree): shots that happen to hit them chop them down for ore.
@export var interactive_verdant_trees: bool = false
## Only the battle scene turns Volcanic Planet craters into clickable oozing
## vents (LavaVent) that erupt and burn nearby enemies.
@export var interactive_lava_vents: bool = false
## Chance that an individual Rocky Planet crystal grants the red artifact.
@export_range(0.0, 1.0, 0.01) var red_crystal_chance: float = 0.01

@export_group("Special sites")
## Spacing between reserved interactive-object sites.
@export var special_site_spacing: float = 560.0
## How many sites to reserve at most.
@export var max_special_sites: int = 6
## Area kept free of decoration around each site.
@export var special_site_radius: float = 110.0
## Draws the reserved sites (for layout checks while developing).
@export var show_special_sites: bool = false

const GRID_CELL: float = 40.0
const EDGE_MARGIN: float = 60.0

var _seed: int = 0
var _noise := FastNoiseLite.new()
var _rock_noise := FastNoiseLite.new()
var _vein_noise := FastNoiseLite.new()

## Generated layout (drawn by _draw).
var _patches: Array[Dictionary] = []
var _craters: Array[Dictionary] = []
var _speckles: Array[Dictionary] = []
var _deposits: Array[Dictionary] = []
## Battle maps of these planets get mineable ore deposits (OreArt kinds) for
## the dwarves instead of the old decorative crystal deposits.
const PLANET_ORES := {
	&"jungle": [&"amber"],
	&"frozen": [&"aurora", &"silver"],
	&"volcanic": [&"obsidian", &"fire"],
	&"graveyard": [&"biomass", &"soul"],
}
@export var ore_sites_per_map: int = 6
@export var ore_site_spacing: float = 220.0
var _ore_sites: Array[Dictionary] = []   # {position, kind, size}
var _rocks: Array[Dictionary] = []
## Goblin huts with a campfire (jungle theme only).
var _camps: Array[Dictionary] = []
## Frozen worlds: decorative snowmen ({position, radius, turn}).
var _snowmen: Array[Dictionary] = []
var _special_sites: Array[Dictionary] = []
## Volcanic theme: thin lava streams ({points, widths}) and cracks ({points, width, ember}).
var _lava_streams: Array[Dictionary] = []
var _cracks: Array[Dictionary] = []
var _lava_layer: Node2D
## Volcanic Planet: big lightning-shaped lava rifts (LavaFissureArt) that
## replace the old thin lava streams; demons climb out of them each wave.
const LAVA_FISSURE_ART := preload("res://Scripts/Battle/LavaFissureArt.gd")
const LAVA_FISSURE_LAYER := preload("res://Scripts/Battle/LavaFissureLayer.gd")
@export var lava_fissure_count: int = 2
var _lava_fissures: Array[Dictionary] = []
var _fissure_layer: Node2D
## Occupied circles [Vector2 center, float radius] in local space.
var _claims: Array = []

## Parent for interactive map objects (above ground decoration and dust,
## below the ship and enemies). See get_interactables_root().
var _interactables: Node2D
const ROCKY_CRYSTAL := preload("res://Scripts/Battle/RockyCrystal.gd")
var _crystal_container: Node2D
## Graveyard theme: tombstones and grave clusters (decor "grave").
const GRAVEYARD_TOMBSTONES := preload("res://Scripts/Battle/Graveyard/GraveyardTombstones.gd")
var _graveyard_tombs: Node2D
## Extra map size currently applied from the theme's "map_extra" (the map
## grows equally on every side, so its center - and the ship - stay put).
var _applied_map_extra: float = 0.0


func _ready() -> void:
	generate(map_seed)


# ==========================================
# Public API
# ==========================================

## (Re)builds the whole map. seed_value 0 picks a random seed.
func generate(seed_value: int = 0) -> void:
	_seed = seed_value if seed_value != 0 else _random_seed()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	_setup_noise()
	_claims.clear()
	_apply_theme_map_size()

	_build_terrain()
	var center := world_size * 0.5
	_claims.append([center, clear_radius])
	_place_special_sites(rng, center)
	# Lava rifts first (volcanic only; a no-op elsewhere) so craters and
	# vents fit around them and both rifts always find room in the view.
	_place_lava(rng, center)
	_place_craters(rng, center)
	_place_deposits(rng, center)
	_place_ore_sites(rng, center)
	_place_camps(rng, center)
	_place_graveyard(rng)
	_place_rocks(rng)
	_place_snowmen(rng, center)
	_place_speckles(rng)

	_ensure_interactables_root()
	_rebuild_rocky_crystals()
	_rebuild_verdant_trees()
	_rebuild_lava_vents()
	_update_lava_layer()
	_update_fissure_layer()
	_baked_mesh = null
	queue_redraw()
	generated.emit(_seed)


## Hit-test individual crystals in reverse draw order, using world coordinates.
func try_click_crystal(world_position: Vector2) -> bool:
	if not is_instance_valid(_crystal_container):
		return false
	var children := _crystal_container.get_children()
	children.reverse()
	for crystal in children:
		if crystal.is_queued_for_deletion():
			continue
		if crystal.call("contains_world_point", world_position):
			crystal.call("register_click")
			return true
	return false


func _rebuild_rocky_crystals() -> void:
	if is_instance_valid(_crystal_container):
		_interactables.remove_child(_crystal_container)
		_crystal_container.queue_free()
	_crystal_container = Node2D.new()
	_crystal_container.name = "RockyCrystals"
	_interactables.add_child(_crystal_container)
	if has_planet_ores():
		_add_ore_nodes()
		return
	if planet_theme != &"rocky" or not interactive_rocky_crystals:
		return
	# A separate RNG preserves the existing terrain layout for a given map seed.
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ 0x524544
	for deposit in _deposits:
		for crystal_data in deposit["crystals"]:
			var crystal := ROCKY_CRYSTAL.new()
			crystal.position = (deposit["position"] as Vector2) + (crystal_data[0] as Vector2)
			crystal.configure(float(crystal_data[1]), float(crystal_data[2]), bool(deposit["gold"]), rng.randf() < red_crystal_chance)
			crystal.broken.connect(_on_crystal_broken)
			_crystal_container.add_child(crystal)


## Whether this battle map has planet ore deposits for the dwarves.
func has_planet_ores() -> bool:
	return interactive_rocky_crystals and PLANET_ORES.has(planet_theme)


## Planet ores live in the same "RockyCrystals" container, so dwarf dispatch,
## clicks and mining progress work exactly like Rocky crystals.
func _add_ore_nodes() -> void:
	for site in _ore_sites:
		var ore := ROCKY_CRYSTAL.new()
		ore.position = site["position"]
		ore.configure_ore(site["kind"], float(site["size"]))
		ore.broken.connect(_on_crystal_broken)
		_crystal_container.add_child(ore)


## Ore deposits inside the opening view (like Rocky crystals), on free ground.
func _place_ore_sites(rng: RandomNumberGenerator, center: Vector2) -> void:
	_ore_sites.clear()
	if not has_planet_ores():
		return
	var kinds: Array = PLANET_ORES[planet_theme]
	var bounds := _inner_bounds(maxf(100.0, crystal_edge_margin))
	var ship := get_node_or_null("../Ship") as Ship
	var zoom := maxf(ship.world_visual_scale, 0.1) if ship != null else 1.0
	var view_size := get_viewport_rect().size / zoom + Vector2.ONE * float(Palette.planet(planet_theme).get("map_extra", 0.0))
	var usable := view_size - Vector2.ONE * (crystal_view_margin + 40.0) / zoom * 2.0
	if usable.x > 0.0 and usable.y > 0.0:
		bounds = bounds.intersection(Rect2(center - usable * 0.5, usable))
	if not bounds.has_area():
		return
	for point in _shuffled(rng, _poisson(rng, ore_site_spacing, bounds)):
		if _ore_sites.size() >= ore_sites_per_map:
			break
		if point.distance_to(center) < clear_radius + 60.0 or not _is_free(point, 44.0):
			continue
		_ore_sites.append({"position": point, "kind": kinds[rng.randi() % kinds.size()], "size": rng.randf_range(0.9, 1.1)})
		_claims.append([point, 44.0])
	# Every planet has at least one ore deposit to mine (user request).
	if _ore_sites.is_empty():
		var spot := _guaranteed_spot(rng, bounds, center, clear_radius + 60.0, 44.0)
		_ore_sites.append({"position": spot, "kind": kinds[rng.randi() % kinds.size()], "size": 1.0})
		_claims.append([spot, 44.0])


const LAVA_VENT := preload("res://Scripts/Battle/LavaVent.gd")
var _vent_container: Node2D


func _lava_vents_active() -> bool:
	return interactive_lava_vents and Palette.planet(planet_theme).get("decor", &"rock") == &"lava"


## Volcanic battle maps: each crater spot becomes a small oozing LavaVent.
func _rebuild_lava_vents() -> void:
	if is_instance_valid(_vent_container):
		_interactables.remove_child(_vent_container)
		_vent_container.queue_free()
	_vent_container = Node2D.new()
	_vent_container.name = "LavaVents"
	_interactables.add_child(_vent_container)
	if not _lava_vents_active():
		return
	for crater in _craters:
		var vent: Node2D = LAVA_VENT.new()
		vent.position = crater["position"]
		_vent_container.add_child(vent)


## Click on a lava vent (world coordinates); true if one took the click.
func try_click_vent(world_position: Vector2) -> bool:
	if not is_instance_valid(_vent_container):
		return false
	for vent in _vent_container.get_children():
		if vent.call("contains_world_point", world_position):
			return bool(vent.call("register_click"))
	return false


const VERDANT_TREE := preload("res://Scripts/Battle/VerdantTree.gd")
## Foliage clumps at least this big are large trees.
const LARGE_CLUMP_RADIUS: float = 30.0
var _tree_container: Node2D


func _verdant_trees_active() -> bool:
	return interactive_verdant_trees and Palette.planet(planet_theme).get("decor", &"rock") == &"foliage"


## Jungle battle maps: every foliage clump (small tree) and landmark tree
## (large tree) becomes its own destructible VerdantTree node instead of being
## baked into the static map mesh.
func _rebuild_verdant_trees() -> void:
	if is_instance_valid(_tree_container):
		_interactables.remove_child(_tree_container)
		_tree_container.queue_free()
	_tree_container = Node2D.new()
	_tree_container.name = "VerdantTrees"
	_interactables.add_child(_tree_container)
	if not _verdant_trees_active():
		return
	var colors := Palette.planet(planet_theme)
	for rock in _rocks:
		if not rock.get("foliage", false):
			continue
		var tree: Area2D = VERDANT_TREE.new()
		tree.position = rock["center"]
		tree.call("configure_small", rock["blobs"], float(rock["size"]), colors)
		# The big canopies count as large trees (more HP, more ore).
		if float(rock["size"]) >= LARGE_CLUMP_RADIUS:
			tree.call("mark_large")
		_tree_container.add_child(tree)
	for deposit in _deposits:
		var crystals: Array = deposit["crystals"]
		var turn: float = (crystals[0][2] as float) * 3.0
		var lobes: Array = []
		for index in range(7):
			var angle: float = turn + TAU * float(index) / 7.0
			var reach: float = 26.0 + 6.0 * float((index * 5) % 3)
			lobes.append([Vector2.RIGHT.rotated(angle) * reach, 22.0 + 4.0 * float(index % 2)])
		var tree: Area2D = VERDANT_TREE.new()
		tree.position = deposit["position"]
		tree.call("configure_large", lobes, turn, colors)
		_tree_container.add_child(tree)


func _on_crystal_broken(world_position: Vector2, is_red: bool) -> void:
	crystal_broken.emit(world_position, is_red)


## The seed of the current map (store it to reproduce the map).
func get_map_seed() -> int:
	return _seed


## Returns the map boundary in global world coordinates.
func get_world_bounds() -> Rect2:
	var top_left := to_global(Vector2.ZERO)
	var bottom_right := to_global(world_size)
	return Rect2(top_left, bottom_right - top_left).abs()


## Reserved empty spots for interactive objects, nearest to the ship first.
## Each entry: {"position": Vector2 (global), "radius": float,
## "band": int (-1 dark ground, 0 normal, 1 light ground), "distance": float}.
func get_special_sites() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site in _special_sites:
		result.append({
			"position": to_global(site["position"]),
			"radius": site["radius"],
			"band": site["band"],
			"distance": site["distance"],
		})
	return result


## Node to add interactive map objects to (drawn above decoration, below units).
func get_interactables_root() -> Node2D:
	_ensure_interactables_root()
	return _interactables


## Terrain noise at a global position, -1..1.
func get_terrain_value(global_point: Vector2) -> float:
	var local_point := to_local(global_point)
	return _noise.get_noise_2d(local_point.x, local_point.y)


## -1 dark ground, 0 normal ground, 1 light ground.
func get_terrain_band(global_point: Vector2) -> int:
	return _band_of(get_terrain_value(global_point))


## Whether a circle is free of rocks, craters, deposits, sites and the ship clearing.
func is_area_free(global_point: Vector2, radius: float) -> bool:
	return _is_free(to_local(global_point), radius)


## Like is_area_free, but ignores the clearing around the ship (for things
## that must sit close to the ship, e.g. graveyard tombstones).
func is_area_free_near_ship(global_point: Vector2, radius: float) -> bool:
	var point := to_local(global_point)
	var center := world_size * 0.5
	for claim in _claims:
		var claim_center: Vector2 = claim[0]
		if claim_center.is_equal_approx(center) and is_equal_approx(float(claim[1]), clear_radius):
			continue
		if point.distance_to(claim_center) < radius + float(claim[1]):
			return false
	return true


## Distance from a world point to the ship's hull edge (0 on or inside it).
## Uses the battle's Ship when it is placed; otherwise the unrotated hull
## square at the map center.
func get_ship_hull_distance(global_point: Vector2, object_radius: float = 0.0) -> float:
	var ship := get_parent().get_node_or_null("Ship") as Ship if get_parent() != null else null
	if ship != null and ship.is_inside_tree() and ship.is_node_ready():
		return ship.get_distance_to_hull(global_point, object_radius)
	var local := to_local(global_point) - world_size * 0.5
	var half := Ship.SHIP_SIZE * 0.5
	var outside := Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0))
	return maxf(outside.length() - maxf(object_radius, 0.0), 0.0)


## Marks a circle as occupied (call when placing objects at runtime).
func claim_area(global_point: Vector2, radius: float) -> void:
	_claims.append([to_local(global_point), radius])


# ==========================================
# Terrain: noise -> marching squares -> RDP
# ==========================================

func _setup_noise() -> void:
	_noise.seed = _seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = terrain_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3

	_rock_noise.seed = _seed + 101
	_rock_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_rock_noise.frequency = 0.0022
	_rock_noise.fractal_type = FastNoiseLite.FRACTAL_NONE

	_vein_noise.seed = _seed + 202
	_vein_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_vein_noise.frequency = 0.0016
	_vein_noise.fractal_type = FastNoiseLite.FRACTAL_NONE


func _band_of(value: float) -> int:
	if value < terrain_dark_level:
		return -1
	if value > terrain_light_level:
		return 1
	return 0


func _build_terrain() -> void:
	var colors := Palette.planet(planet_theme)
	var nx: int = int(ceil(world_size.x / GRID_CELL)) + 2
	var ny: int = int(ceil(world_size.y / GRID_CELL)) + 2
	var values := PackedFloat32Array()
	values.resize((nx + 1) * (ny + 1))
	for j in range(ny + 1):
		for i in range(nx + 1):
			var point := _grid_point(i, j)
			values[j * (nx + 1) + i] = _noise.get_noise_2d(point.x, point.y)

	var loops: Array[Dictionary] = []
	# Dark patches: inside where value < level. Light patches: value > level.
	loops.append_array(_contour(values, nx, ny, terrain_dark_level, -1.0, colors["ground_dark"], colors["ground"]))
	loops.append_array(_contour(values, nx, ny, terrain_light_level, 1.0, colors["ground_light"], colors["ground"]))
	# Painter's order: a containing loop is always larger than the loops inside it.
	loops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["area"] > b["area"])
	_patches = loops


func _grid_point(i: int, j: int) -> Vector2:
	return Vector2((float(i) - 1.0) * GRID_CELL, (float(j) - 1.0) * GRID_CELL)


## Marching squares for one level. sign_dir -1: inside means value < level,
## +1: value > level. Grid border is padded as "outside" so every loop closes.
func _contour(values: PackedFloat32Array, nx: int, ny: int, level: float, sign_dir: float,
		inside_color: Color, outside_color: Color) -> Array[Dictionary]:
	var stride: int = nx + 1
	var field := PackedFloat32Array()
	field.resize(values.size())
	for j in range(ny + 1):
		for i in range(nx + 1):
			var index: int = j * stride + i
			if i == 0 or j == 0 or i == nx or j == ny:
				field[index] = -1.0
			else:
				field[index] = (values[index] - level) * sign_dir

	var points: Dictionary = {}
	var links: Dictionary = {}
	for j in range(ny):
		for i in range(nx):
			var fa: float = field[j * stride + i]
			var fb: float = field[j * stride + i + 1]
			var fc: float = field[(j + 1) * stride + i + 1]
			var fd: float = field[(j + 1) * stride + i]
			var case_index: int = (8 if fa > 0.0 else 0) | (4 if fb > 0.0 else 0) | (2 if fc > 0.0 else 0) | (1 if fd > 0.0 else 0)
			if case_index == 0 or case_index == 15:
				continue
			var top: int = (j * stride + i) * 2
			var bottom: int = ((j + 1) * stride + i) * 2
			var left: int = (j * stride + i) * 2 + 1
			var right: int = (j * stride + i + 1) * 2 + 1
			var a := _grid_point(i, j)
			var b := _grid_point(i + 1, j)
			var c := _grid_point(i + 1, j + 1)
			var d := _grid_point(i, j + 1)
			points[top] = a.lerp(b, _cross(fa, fb))
			points[bottom] = d.lerp(c, _cross(fd, fc))
			points[left] = a.lerp(d, _cross(fa, fd))
			points[right] = b.lerp(c, _cross(fb, fc))
			var center_inside: bool = (fa + fb + fc + fd) > 0.0
			match case_index:
				1, 14: _link(links, left, bottom)
				2, 13: _link(links, bottom, right)
				3, 12: _link(links, left, right)
				4, 11: _link(links, top, right)
				6, 9: _link(links, top, bottom)
				7, 8: _link(links, top, left)
				5:
					if center_inside:
						_link(links, top, left)
						_link(links, bottom, right)
					else:
						_link(links, top, right)
						_link(links, left, bottom)
				10:
					if center_inside:
						_link(links, top, right)
						_link(links, left, bottom)
					else:
						_link(links, top, left)
						_link(links, bottom, right)

	var result: Array[Dictionary] = []
	var visited: Dictionary = {}
	for start in links.keys():
		if visited.has(start):
			continue
		var raw := PackedVector2Array()
		var previous: int = -1
		var current: int = start
		while not visited.has(current):
			visited[current] = true
			raw.append(points[current])
			var neighbours: Array = links[current]
			var next: int = neighbours[0] if neighbours[0] != previous else (neighbours[1] if neighbours.size() > 1 else neighbours[0])
			previous = current
			current = next
		if raw.size() < 3:
			continue
		var simple := _simplify_closed(raw, terrain_simplify)
		if simple.size() < 3:
			continue
		var area: float = absf(_signed_area(simple))
		if area < 3000.0:
			continue
		var inside: bool = _region_inside(raw, level, sign_dir)
		result.append({"points": simple, "area": area, "color": inside_color if inside else outside_color})
	return result


func _cross(from_value: float, to_value: float) -> float:
	var denominator: float = from_value - to_value
	if absf(denominator) < 0.00001:
		return 0.5
	return clampf(from_value / denominator, 0.0, 1.0)


func _link(links: Dictionary, a: int, b: int) -> void:
	if not links.has(a):
		links[a] = []
	if not links.has(b):
		links[b] = []
	(links[a] as Array).append(b)
	(links[b] as Array).append(a)


## Whether the contour's region (sign_dir side of level) lies inside the loop.
func _region_inside(loop: PackedVector2Array, level: float, sign_dir: float) -> bool:
	for index in range(loop.size()):
		var a: Vector2 = loop[index]
		var b: Vector2 = loop[(index + 1) % loop.size()]
		if a.distance_to(b) < 2.0:
			continue
		var middle := (a + b) * 0.5
		var normal := (b - a).normalized().orthogonal() * 3.0
		var probe := middle + normal
		if not Geometry2D.is_point_in_polygon(probe, loop):
			probe = middle - normal
			if not Geometry2D.is_point_in_polygon(probe, loop):
				continue
		return (_noise.get_noise_2d(probe.x, probe.y) - level) * sign_dir > 0.0
	return false


func _simplify_closed(loop: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	var far_index: int = 0
	var far_distance: float = -1.0
	for index in range(loop.size()):
		var distance: float = loop[0].distance_squared_to(loop[index])
		if distance > far_distance:
			far_distance = distance
			far_index = index
	var first := loop.slice(0, far_index + 1)
	var second := loop.slice(far_index)
	second.append(loop[0])
	var result := _rdp(first, epsilon)
	var tail := _rdp(second, epsilon)
	result.remove_at(result.size() - 1)
	tail.remove_at(tail.size() - 1)
	result.append_array(tail)
	return result


func _rdp(line: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if line.size() < 3:
		return line
	var start: Vector2 = line[0]
	var end: Vector2 = line[line.size() - 1]
	var max_distance: float = 0.0
	var max_index: int = 0
	for index in range(1, line.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(line[index], start, end)
		var distance: float = line[index].distance_to(closest)
		if distance > max_distance:
			max_distance = distance
			max_index = index
	if max_distance <= epsilon:
		return PackedVector2Array([start, end])
	var left := _rdp(line.slice(0, max_index + 1), epsilon)
	var right := _rdp(line.slice(max_index), epsilon)
	left.remove_at(left.size() - 1)
	left.append_array(right)
	return left


func _signed_area(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for index in range(points.size()):
		total += points[index].cross(points[(index + 1) % points.size()])
	return total * 0.5


# ==========================================
# Placement: Poisson-disc sampling
# ==========================================

## Bridson's algorithm: evenly spaced points at least `spacing` apart.
func _poisson(rng: RandomNumberGenerator, spacing: float, bounds: Rect2, attempts: int = 24) -> PackedVector2Array:
	var cell: float = spacing / sqrt(2.0)
	var columns: int = int(ceil(bounds.size.x / cell))
	var rows: int = int(ceil(bounds.size.y / cell))
	var grid := PackedInt32Array()
	grid.resize(columns * rows)
	grid.fill(-1)
	var samples := PackedVector2Array()
	var active: Array[int] = []

	var first := bounds.position + Vector2(rng.randf() * bounds.size.x, rng.randf() * bounds.size.y)
	samples.append(first)
	active.append(0)
	grid[_poisson_cell(first, bounds, cell, columns, rows)] = 0

	while not active.is_empty():
		var active_slot: int = rng.randi_range(0, active.size() - 1)
		var origin: Vector2 = samples[active[active_slot]]
		var placed := false
		for attempt in range(attempts):
			var candidate := origin + Vector2.RIGHT.rotated(rng.randf() * TAU) * spacing * (1.0 + rng.randf())
			if not bounds.has_point(candidate):
				continue
			var cx: int = int((candidate.x - bounds.position.x) / cell)
			var cy: int = int((candidate.y - bounds.position.y) / cell)
			var ok := true
			for oy in range(maxi(cy - 2, 0), mini(cy + 3, rows)):
				for ox in range(maxi(cx - 2, 0), mini(cx + 3, columns)):
					var other: int = grid[oy * columns + ox]
					if other >= 0 and samples[other].distance_to(candidate) < spacing:
						ok = false
						break
				if not ok:
					break
			if ok:
				samples.append(candidate)
				active.append(samples.size() - 1)
				grid[cy * columns + cx] = samples.size() - 1
				placed = true
				break
		if not placed:
			active.remove_at(active_slot)
	return samples


func _poisson_cell(point: Vector2, bounds: Rect2, cell: float, columns: int, rows: int) -> int:
	var cx: int = clampi(int((point.x - bounds.position.x) / cell), 0, columns - 1)
	var cy: int = clampi(int((point.y - bounds.position.y) / cell), 0, rows - 1)
	return cy * columns + cx


func _is_free(point: Vector2, radius: float) -> bool:
	for claim in _claims:
		if point.distance_to(claim[0]) < radius + float(claim[1]):
			return false
	return true


func _inner_bounds(margin: float = EDGE_MARGIN) -> Rect2:
	return Rect2(Vector2.ONE * margin, world_size - Vector2.ONE * margin * 2.0)


func _shuffled(rng: RandomNumberGenerator, points: PackedVector2Array) -> PackedVector2Array:
	var list := points.duplicate()
	for index in range(list.size() - 1, 0, -1):
		var swap: int = rng.randi_range(0, index)
		var temp: Vector2 = list[index]
		list[index] = list[swap]
		list[swap] = temp
	return list


func _place_special_sites(rng: RandomNumberGenerator, center: Vector2) -> void:
	_special_sites.clear()
	var candidates := _shuffled(rng, _poisson(rng, special_site_spacing, _inner_bounds(180.0)))
	for point in candidates:
		if _special_sites.size() >= max_special_sites:
			break
		if point.distance_to(center) < clear_radius + 280.0:
			continue
		_special_sites.append({
			"position": point,
			"radius": special_site_radius,
			"band": _band_of(_noise.get_noise_2d(point.x, point.y)),
			"distance": point.distance_to(center),
		})
		_claims.append([point, special_site_radius])
	_special_sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])


func _place_craters(rng: RandomNumberGenerator, center: Vector2) -> void:
	_craters.clear()
	for point in _poisson(rng, crater_spacing, _inner_bounds(100.0)):
		if rng.randf() > 0.6:
			continue
		var radius: float = rng.randf_range(34.0, 82.0)
		if point.distance_to(center) < clear_radius * 0.6 or not _is_free(point, radius * 0.9):
			continue
		_craters.append({"position": point, "radius": radius})
		_claims.append([point, radius * 0.9])


func _place_deposits(rng: RandomNumberGenerator, center: Vector2) -> void:
	_deposits.clear()
	var foliage: bool = Palette.planet(planet_theme).get("decor", &"rock") == &"foliage"
	# The 40 px allowance covers a crystal's random offset and drawn size.
	# Verdant deposits become trees, so retain their existing placement.
	var margin := 100.0 if foliage else maxf(100.0, crystal_edge_margin + 40.0)
	var bounds := _inner_bounds(margin)
	if has_planet_ores() and not foliage:
		# The old decorative crystal deposits are replaced by planet ores.
		return
	if planet_theme == &"rocky" and interactive_rocky_crystals:
		# Battlefield initializes before the ship camera, so read its configured
		# zoom and center the visible rectangle on the stationary ship's map center.
		var ship := get_node_or_null("../Ship") as Ship
		var zoom := maxf(ship.world_visual_scale, 0.1) if ship != null else 1.0
		var view_size := get_viewport_rect().size / zoom
		var padding := (crystal_view_margin + 40.0) / zoom
		var usable_size := view_size - Vector2.ONE * padding * 2.0
		if usable_size.x > 0.0 and usable_size.y > 0.0:
			bounds = bounds.intersection(Rect2(center - usable_size * 0.5, usable_size))
	if not bounds.has_area():
		return
	for point in _shuffled(rng, _poisson(rng, deposit_spacing, bounds)):
		if _deposits.size() >= max_deposits:
			break
		# Veins: deposits sit near the zero-crossings of the vein noise.
		var vein: float = 1.0 - absf(_vein_noise.get_noise_2d(point.x, point.y))
		if rng.randf() > clampf((vein - 0.55) * 2.5, 0.15, 0.95):
			continue
		var keep_free: float = 60.0 if foliage else 46.0
		if point.distance_to(center) < clear_radius + 40.0 or not _is_free(point, keep_free):
			continue
		_deposits.append(_make_deposit(rng, point))
		_claims.append([point, keep_free])
	# The Rocky Planet always has at least one crystal deposit (user request).
	if _deposits.is_empty() and planet_theme == &"rocky" and interactive_rocky_crystals:
		var spot := _guaranteed_spot(rng, bounds, center, clear_radius + 40.0, 46.0)
		_deposits.append(_make_deposit(rng, spot))
		_claims.append([spot, 46.0])


func _make_deposit(rng: RandomNumberGenerator, point: Vector2) -> Dictionary:
	var crystals: Array = []
	for index in range(rng.randi_range(2, 4)):
		crystals.append([
			Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-12.0, 14.0)),
			rng.randf_range(0.55, 1.15),
			rng.randf_range(-0.4, 0.4),
		])
	return {"position": point, "gold": rng.randf() < 0.75, "crystals": crystals}


## A spot for a guaranteed deposit inside `bounds`, away from the ship: the
## freest of many random tries (free ground first, else just in bounds).
func _guaranteed_spot(rng: RandomNumberGenerator, bounds: Rect2, center: Vector2, min_distance: float, keep_free: float) -> Vector2:
	var fallback := Vector2.INF
	for attempt in range(200):
		var point := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if point.distance_to(center) < min_distance:
			continue
		if _is_free(point, keep_free):
			return point
		if fallback == Vector2.INF:
			fallback = point
	if fallback != Vector2.INF:
		return fallback
	# Tiny view: straight out from the ship toward the nearest roomy side.
	var dir := Vector2.RIGHT if bounds.end.x - center.x >= center.x - bounds.position.x else Vector2.LEFT
	return center + dir * min_distance


func _place_rocks(rng: RandomNumberGenerator) -> void:
	_rocks.clear()
	var colors := Palette.planet(planet_theme)
	# Jungle worlds are overgrown: tighter spacing and a much higher fill rate.
	var foliage: bool = colors.get("decor", &"rock") == &"foliage"
	var spacing: float = rock_spacing * (0.8 if foliage else (2.0 if colors.get("decor", &"rock") == &"grave" else 1.0))
	for point in _poisson(rng, spacing, _inner_bounds(30.0)):
		var rocky: float = _rock_noise.get_noise_2d(point.x, point.y)
		var chance: float = clampf(smoothstep(-0.25, 0.55, rocky) * 0.85 + (0.4 if foliage else 0.06), 0.0, 1.0)
		if rng.randf() > chance:
			continue
		var size: float = rng.randf_range(9.0, 16.0) + 12.0 * clampf(rocky, 0.0, 1.0) * rng.randf()
		if not _is_free(point, size):
			continue
		_add_rock(rng, point, size, colors)
		# Rocky areas get a few pebbles around the bigger stones.
		if rocky > 0.2:
			for pebble in range(rng.randi_range(0, 2)):
				var offset := Vector2.RIGHT.rotated(rng.randf() * TAU) * (size + rng.randf_range(10.0, 22.0))
				var pebble_size: float = rng.randf_range(5.0, 9.0)
				if _is_free(point + offset, pebble_size):
					_add_rock(rng, point + offset, pebble_size, colors)


func _add_rock(rng: RandomNumberGenerator, rock_center: Vector2, size: float, colors: Dictionary) -> void:
	if colors.get("decor", &"rock") == &"foliage":
		_add_foliage(rng, rock_center, size)
		return
	if colors.get("decor", &"rock") == &"ice":
		_add_ice(rng, rock_center, size)
		return
	var points := PackedVector2Array()
	var sides := rng.randi_range(5, 7)
	var start := rng.randf() * TAU
	for side in range(sides):
		var angle := start + TAU * float(side) / float(sides)
		points.append(rock_center + Vector2.RIGHT.rotated(angle) * size * rng.randf_range(0.75, 1.1))
	# Lit facet: the upper vertices plus a point pulled up from the center.
	var facet := PackedVector2Array()
	for point in points:
		if point.y <= rock_center.y + size * 0.1:
			facet.append(point)
	if facet.size() >= 2:
		facet.append(rock_center + Vector2(size * 0.1, -size * 0.15))
		facet = _sorted_around(facet)
	else:
		facet = PackedVector2Array()
	_rocks.append({"points": points, "facet": facet, "size": size})
	_claims.append([rock_center, size])


func _place_speckles(rng: RandomNumberGenerator) -> void:
	_speckles.clear()
	var colors := Palette.planet(planet_theme)
	for index in range(340):
		var dot := Vector2(rng.randf() * world_size.x, rng.randf() * world_size.y)
		var dot_color: Color = colors["crater"] if rng.randf() < 0.65 else colors["ground_light"]
		_speckles.append({"position": dot, "radius": rng.randf_range(1.5, 3.5), "color": dot_color})


## Grows (or shrinks back) the map by the theme's "map_extra" pixels on
## each axis, keeping its center where it was.
func _apply_theme_map_size() -> void:
	var extra := float(Palette.planet(planet_theme).get("map_extra", 0.0))
	if is_equal_approx(extra, _applied_map_extra):
		return
	var delta := extra - _applied_map_extra
	position -= Vector2(delta, delta) * 0.5
	world_size += Vector2(delta, delta)
	_applied_map_extra = extra


## Graveyard maps: random tombstones and grave clusters, placed before rocks
## so they claim their ground first.
func _place_graveyard(rng: RandomNumberGenerator) -> void:
	_ensure_interactables_root()
	if is_instance_valid(_graveyard_tombs):
		_interactables.remove_child(_graveyard_tombs)
		_graveyard_tombs.queue_free()
		_graveyard_tombs = null
	if Palette.planet(planet_theme).get("decor", &"rock") != &"grave":
		return
	_graveyard_tombs = GRAVEYARD_TOMBSTONES.new()
	_graveyard_tombs.name = "GraveyardTombstones"
	_interactables.add_child(_graveyard_tombs)
	_graveyard_tombs.call("generate", self, rng.randi())


## Points zombies could claw out of on a graveyard map (empty elsewhere).
func get_grave_emerge_points() -> Array[Vector2]:
	if is_instance_valid(_graveyard_tombs):
		return _graveyard_tombs.call("get_emerge_points")
	return []


## Zombie graves are separate from map graves used by skeletons and the boss.
const ZOMBIE_GRAVE := preload("res://Scripts/Battle/Graveyard/ZombieGrave.gd")
var _zombie_graves: Array[Node2D] = []

func add_zombie_grave(world_position: Vector2) -> void:
	if planet_theme != &"graveyard":
		return
	var grave := ZOMBIE_GRAVE.new() as Node2D
	get_interactables_root().add_child(grave)
	grave.global_position = world_position
	_zombie_graves.append(grave)

## Zombie graves can no longer be clicked away (user rule) - only a mining
## dwarf digs them up (GraveDigSite). Kept so BattleMain's click routing
## stays valid; never takes the click.
func try_click_zombie_grave(_world_position: Vector2) -> bool:
	return false


## Intact, unclaimed zombie graves within radius of a world position.
func get_zombie_graves_in(world_position: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for grave in _zombie_graves:
		if not is_instance_valid(grave) or grave.is_queued_for_deletion():
			continue
		if is_instance_valid(grave.get("dig_site")):
			continue
		if grave.global_position.distance_to(world_position) <= radius:
			result.append(grave)
	return result

func get_zombie_grave_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for grave in _zombie_graves:
		if is_instance_valid(grave) and not grave.is_queued_for_deletion():
			result.append(grave.global_position)
	return result


func _ensure_interactables_root() -> void:
	if is_instance_valid(_interactables):
		return
	_interactables = Node2D.new()
	_interactables.name = "Interactables"
	# Absolute z: above ground decoration (-100) and dust (-50), below units (0).
	_interactables.z_as_relative = false
	_interactables.z_index = -10
	add_child(_interactables)


static func _centroid_of(points: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for point in points:
		total += point
	return total / float(maxi(points.size(), 1))



# ==========================================
# Volcanic theme: lava streams, cracks, extinct volcanoes
# ==========================================

const LavaFlowScript := preload("res://Scripts/Battle/LavaFlow.gd")
const LAVA_CRUST := Color("241A18")
const LAVA_DARK := Color("A8320C")
const LAVA := Color("F2641E")
const LAVA_GLOW := Color(1.0, 0.42, 0.14, 0.16)
const CRACK_EMBER := Color("7A2A12")


## Two big rifts, one on each side of the ship, entirely inside the opening
## view (user: never off screen) and out of the ship clearing; they claim the
## ground along their trunk and side cracks.
func _place_lava_fissures(rng: RandomNumberGenerator, center: Vector2) -> void:
	_lava_fissures.clear()
	var ship := get_node_or_null("../Ship") as Ship
	var zoom := maxf(ship.world_visual_scale, 0.1) if ship != null else 1.0
	var view_size := get_viewport_rect().size / zoom
	var view := Rect2(center - view_size * 0.5, view_size).grow(-24.0).intersection(_inner_bounds(40.0))
	var keep_out := clear_radius + 70.0
	var sides := [-1.0, 1.0] if rng.randf() < 0.5 else [1.0, -1.0]
	for side in sides:
		if _lava_fissures.size() >= lava_fissure_count:
			break
		for attempt in range(400):
			# Start near the top or bottom of the view on this side and run
			# roughly vertically through the free band beside the ship.
			var from_top := rng.randf() < 0.5
			var origin := Vector2(
				center.x + side * rng.randf_range(view_size.x * 0.24, view_size.x * 0.42),
				(view.position.y + rng.randf_range(10.0, 60.0)) if from_top else (view.end.y - rng.randf_range(10.0, 60.0))
			)
			var heading := (PI * 0.5 if from_top else -PI * 0.5) + rng.randf_range(-0.4, 0.4)
			# Later attempts try shorter rifts so both sides always get one.
			var size := lerpf(0.8, 0.42, float(attempt) / 400.0) * rng.randf_range(0.9, 1.0)
			var fissure: Dictionary = LAVA_FISSURE_ART.generate_rift(rng, origin, heading, size)
			if _fissure_fits(fissure, view, center, keep_out, _hud_rects(center, view_size)):
				_lava_fissures.append(fissure)
				for branch in fissure["branches"]:
					var points: PackedVector2Array = branch["points"]
					var widths: PackedFloat32Array = branch["widths"]
					for index in range(0, points.size(), 2):
						_claims.append([points[index], widths[index] * 0.5 + 18.0])
				break


## Opening-view areas under the battle HUD (wave panel top left, ore counter
## top right, evacuate button bottom right), so rifts never hide under them.
func _hud_rects(center: Vector2, view_size: Vector2) -> Array[Rect2]:
	var origin := center - view_size * 0.5
	var k := view_size.x / 1600.0
	return [
		Rect2(origin, Vector2(320.0, 230.0) * k),
		Rect2(origin + Vector2(view_size.x - 260.0 * k, 0.0), Vector2(260.0, 110.0) * k),
		Rect2(origin + view_size - Vector2(250.0, 250.0) * k, Vector2(250.0, 250.0) * k),
	]


func _fissure_fits(fissure: Dictionary, view: Rect2, center: Vector2, keep_out: float, avoid: Array[Rect2] = []) -> bool:
	if fissure["emerge"].size() < 3:
		return false
	for branch in fissure["branches"]:
		var points: PackedVector2Array = branch["points"]
		var widths: PackedFloat32Array = branch["widths"]
		for index in range(points.size()):
			var p := points[index]
			var half := widths[index] * 0.5 + 10.0
			if not view.grow(-half).has_point(p) or p.distance_to(center) < keep_out + half:
				return false
			for rect in avoid:
				if rect.grow(half).has_point(p):
					return false
			if index % 2 == 0 and not _is_free(p, half):
				return false
	return true


func _update_fissure_layer() -> void:
	if _lava_fissures.is_empty():
		if is_instance_valid(_fissure_layer):
			_fissure_layer.queue_free()
		_fissure_layer = null
		return
	if not is_instance_valid(_fissure_layer):
		_fissure_layer = LAVA_FISSURE_LAYER.new()
		_fissure_layer.name = "LavaFissures"
		add_child(_fissure_layer)
	_fissure_layer.set_fissures(_lava_fissures)


## Global points along the rifts where enemies can climb out (widest spots).
func get_lava_emerge_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for fissure in _lava_fissures:
		for point in fissure["emerge"]:
			result.append(to_global(point))
	return result


## Lava rifts (local space), for tests and map objects.
func get_lava_fissures() -> Array[Dictionary]:
	return _lava_fissures


func _place_lava(rng: RandomNumberGenerator, center: Vector2) -> void:
	_lava_streams.clear()
	_lava_fissures.clear()
	_cracks.clear()
	if Palette.planet(planet_theme).get("decor", &"rock") != &"lava":
		return
	var bounds := _inner_bounds(90.0)
	_place_lava_fissures(rng, center)
	# The old thin curved cracks are gone with the streams (user: the rifts
	# replace the twisty look); keep the code path for other lava decor.
	var crack_count: int = 0
	for attempt in range(80):
		if _cracks.size() >= crack_count:
			break
		var start := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if start.distance_to(center) < clear_radius + 60.0 or not _is_free(start, 16.0):
			continue
		var crack := _grow_path(rng, start, rng.randf() * TAU, rng.randi_range(5, 10), rng.randf_range(15.0, 24.0), 0.6, center, clear_radius + 40.0, 7.0)
		if crack.size() < 4:
			continue
		var ember: bool = rng.randf() < 0.55
		var width: float = rng.randf_range(6.0, 9.0)
		_cracks.append({"points": crack, "width": width, "ember": ember})
		# Some cracks fork once.
		if rng.randf() < 0.45:
			var at: int = crack.size() / 2
			var heading: float = (crack[at] - crack[at - 1]).angle() + (0.7 if rng.randf() < 0.5 else -0.7)
			var branch := _grow_path(rng, crack[at], heading, rng.randi_range(3, 5), rng.randf_range(12.0, 18.0), 0.5, center, clear_radius + 40.0, 6.0, true)
			if branch.size() >= 3:
				_cracks.append({"points": branch, "width": width * 0.7, "ember": ember})
		for point in crack:
			_claims.append([point, 9.0])


## Lava stream as a hard-edged zigzag: straight runs alternating with diagonal
## kinks to the left and right (now and then a sharper elbow), sampled every
## 11 px so the flow highlights can travel along it. Stops at the map edge,
## near the ship clearing or at anything already placed.
func _grow_zigzag(rng: RandomNumberGenerator, start: Vector2, heading: float, segments: int,
		center: Vector2, keep_out: float, keep_free: float) -> PackedVector2Array:
	var bounds := _inner_bounds(40.0)
	var points := PackedVector2Array([start])
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	var position_now := start
	for segment in range(segments):
		var angle := heading
		var length := rng.randf_range(45.0, 95.0)
		if segment % 2 == 1:
			var kink := PI * 0.25 if rng.randf() < 0.7 else PI * 0.38
			angle = heading + side * kink
			side = -side
			length = rng.randf_range(25.0, 55.0)
		else:
			# Straight runs drift a touch so the whole stream wanders.
			heading += rng.randf_range(-0.25, 0.25)
			angle = heading
		var direction := Vector2.RIGHT.rotated(angle)
		var steps := maxi(int(length / 11.0), 2)
		for step in range(1, steps + 1):
			var p := position_now + direction * 11.0 * float(step)
			if not bounds.has_point(p) or p.distance_to(center) < keep_out or not _is_free(p, keep_free):
				return points
			points.append(p)
		position_now = points[points.size() - 1]
	return points


## Wanders from start in steps of step_length, turning a little each step.
## Stops at the map edge, near the ship clearing or at anything placed.
func _grow_path(rng: RandomNumberGenerator, start: Vector2, heading: float, steps: int, step_length: float,
		wiggle: float, center: Vector2, keep_out: float, keep_free: float, ignore_first: bool = false) -> PackedVector2Array:
	var bounds := _inner_bounds(40.0)
	var points := PackedVector2Array([start])
	var turn: float = 0.0
	for index in range(steps):
		turn = turn * 0.65 + rng.randf_range(-wiggle, wiggle)
		heading += turn
		var next: Vector2 = points[points.size() - 1] + Vector2.RIGHT.rotated(heading) * step_length
		if not bounds.has_point(next) or next.distance_to(center) < keep_out:
			break
		if not (ignore_first and index == 0) and not _is_free(next, keep_free):
			break
		points.append(next)
	return points


func _paint_cracks(colors: Dictionary) -> void:
	# Pass 0: lit lower lip; pass 1: the dark gap; pass 2: faint embers.
	for pass_index in range(3):
		for crack in _cracks:
			var points: PackedVector2Array = crack["points"]
			var count := points.size()
			if pass_index == 2 and not crack["ember"]:
				continue
			for index in range(count - 1):
				var taper: float = 1.0 - float(index) / float(count)
				var width: float = maxf(float(crack["width"]) * taper, 1.2)
				var a: Vector2 = points[index]
				var b2: Vector2 = points[index + 1]
				match pass_index:
					0:
						var lip := Vector2(0.8, 1.6)
						_pen.draw_line(a + lip, b2 + lip, colors["ground_light"], width + 1.0)
						_pen.draw_circle(b2 + lip, (width + 1.0) * 0.5, colors["ground_light"])
					1:
						_pen.draw_line(a, b2, LAVA_CRUST, width)
						_pen.draw_circle(b2, width * 0.5, LAVA_CRUST)
						if index == 0:
							_pen.draw_circle(a, width * 0.5, LAVA_CRUST)
					2:
						if width > 2.4:
							_pen.draw_line(a, b2, CRACK_EMBER, width * 0.32)


## Static part of the lava streams: soft glow on the ground, cooled crust
## banks and the lava itself. LavaFlow draws the moving highlights on top.
func _paint_lava_beds() -> void:
	for stream in _lava_streams:
		var points: PackedVector2Array = stream["points"]
		var widths: PackedFloat32Array = stream["widths"]
		var count := points.size()
		for pass_index in range(3):
			for index in range(count - 1):
				var w: float = widths[index]
				var t: float = float(index) / float(count - 1)
				var a: Vector2 = points[index]
				var b2: Vector2 = points[index + 1]
				match pass_index:
					0:
						_pen.draw_line(a, b2, LAVA_GLOW, w + 9.0)
						_pen.draw_circle(b2, (w + 9.0) * 0.5, LAVA_GLOW)
					1:
						_pen.draw_line(a, b2, LAVA_CRUST, w + 3.5)
						_pen.draw_circle(b2, (w + 3.5) * 0.5, LAVA_CRUST)
					2:
						# The tail end cools down toward the crust colour.
						var color: Color = LAVA.lerp(LAVA_DARK, smoothstep(0.55, 1.0, t))
						_pen.draw_line(a, b2, color, w)
						_pen.draw_circle(b2, w * 0.5, color)
		# Vent the stream wells up from.
		var vent: Vector2 = points[0]
		_pen.draw_colored_polygon(_ellipse(vent, 11.0, 0.75), LAVA_CRUST)
		_pen.draw_colored_polygon(_ellipse(vent + Vector2(-1.0, -1.0), 6.0, 0.7), LAVA)
		_pen.draw_colored_polygon(_ellipse(vent + Vector2(-1.5, -1.5), 2.8, 0.7), Color("FFC061"))


## Extinct volcano: a low cone with radial gullies, a dark rim and a
## cold caldera full of cracked, ash-grey crust.
func _draw_extinct_volcano(crater: Dictionary, colors: Dictionary) -> void:
	var c: Vector2 = crater["position"]
	var r: float = crater["radius"]
	_pen.draw_colored_polygon(_ellipse(c + Palette.SHADOW_OFFSET * 1.6, r, 0.7), Palette.SHADOW_COLOR)
	_pen.draw_colored_polygon(_ellipse(c, r, 0.7), colors["ground_dark"])
	_pen.draw_colored_polygon(_ellipse(c + Vector2(-r * 0.06, -r * 0.05), r * 0.9, 0.68), colors["ground_light"])
	# Lit upper-left slope.
	_pen.draw_colored_polygon(_ellipse(c + Vector2(-r * 0.2, -r * 0.16), r * 0.55, 0.6), Color(colors["rock_light"], 0.35))
	for index in range(9):
		var angle: float = TAU * float(index) / 9.0 + r
		var direction := Vector2(cos(angle), sin(angle) * 0.7)
		_pen.draw_line(c + direction * r * 0.58, c + direction * r * 0.88, colors["ground_dark"], 2.0)
	_pen.draw_colored_polygon(_ellipse(c, r * 0.56, 0.62), colors["rock_light"])
	_pen.draw_colored_polygon(_ellipse(c + Vector2(r * 0.02, r * 0.03), r * 0.47, 0.6), colors["rock"])
	var floor_center := c + Vector2(r * 0.06, r * 0.05)
	_pen.draw_colored_polygon(_ellipse(floor_center, r * 0.36, 0.58), Color("3D3330"))
	# Cold crust: one jagged fissure across the floor and a few cinders.
	var across := Vector2.RIGHT.rotated(r * 0.37)
	across.y *= 0.58
	var fissure := PackedVector2Array()
	for index in range(5):
		var k: float = float(index) / 4.0 - 0.5
		fissure.append(floor_center + across * r * 0.56 * k + across.orthogonal() * r * (0.04 if index % 2 == 0 else -0.04))
	_pen.draw_polyline(fissure, LAVA_CRUST, 2.0)
	for index in range(3):
		var angle: float = r * 1.7 + float(index) * 2.1
		_pen.draw_circle(floor_center + Vector2(cos(angle), sin(angle) * 0.58) * r * 0.2, 1.8, LAVA_CRUST)


func _update_lava_layer() -> void:
	if _lava_streams.is_empty():
		if is_instance_valid(_lava_layer):
			_lava_layer.queue_free()
		_lava_layer = null
		return
	if not is_instance_valid(_lava_layer):
		_lava_layer = LavaFlowScript.new()
		_lava_layer.name = "LavaFlow"
		add_child(_lava_layer)
	_lava_layer.set_streams(_lava_streams)


## Thin lava streams (local space), for tests and map objects.
func get_lava_streams() -> Array[Dictionary]:
	return _lava_streams


# ==========================================
# Jungle theme: foliage and goblin camps
# ==========================================

## A leafy clump seen from above: a few overlapping octagons (bigger ones read
## as tree canopies), drawn as one shadow, a dark body and lit top-left leaves.
func _add_foliage(rng: RandomNumberGenerator, foliage_center: Vector2, size: float) -> void:
	var scale_up: float = 1.7 if rng.randf() < 0.35 else 1.2
	var radius: float = size * scale_up
	var blobs: Array = []
	for index in range(rng.randi_range(3, 5)):
		var offset := Vector2.RIGHT.rotated(rng.randf() * TAU) * radius * rng.randf_range(0.2, 0.6)
		blobs.append([offset, radius * rng.randf_range(0.5, 0.75), rng.randf() * TAU])
	_rocks.append({"foliage": true, "center": foliage_center, "blobs": blobs, "size": radius})
	_claims.append([foliage_center, radius])


## An ice crystal cluster seen from above: 2-4 long faceted shards fanning
## out from a common base, each with a dark body, a lit half and a glint.
func _add_ice(rng: RandomNumberGenerator, ice_center: Vector2, size: float) -> void:
	var shards: Array = []
	var heading := rng.randf() * TAU
	var count := rng.randi_range(3, 5) if size > 8.0 else rng.randi_range(1, 2)
	for index in range(count):
		var angle := heading + (float(index) - float(count - 1) * 0.5) * rng.randf_range(0.45, 0.75)
		var along := Vector2.RIGHT.rotated(angle)
		var across := Vector2(-along.y, along.x)
		var base := ice_center + along * size * rng.randf_range(-0.2, 0.15)
		var length := size * rng.randf_range(1.5, 2.3)
		var width := size * rng.randf_range(0.5, 0.68)
		shards.append({
			"body": PackedVector2Array([
				base - along * width * 0.4, base + across * width * 0.8, base + along * length * 0.7 + across * width,
				base + along * length, base + along * length * 0.7 - across * width, base - across * width * 0.8,
			]),
			"lit": PackedVector2Array([
				base - along * width * 0.4, base + across * width * 0.8, base + along * length * 0.7 + across * width, base + along * length,
			]),
			"glint": PackedVector2Array([base + along * length * 0.15 + across * width * 0.2, base + along * length * 0.75 + across * width * 0.3]),
		})
	_rocks.append({"ice": true, "center": ice_center, "shards": shards, "size": size})
	_claims.append([ice_center, size * 1.2])


## A few snowmen dotted around frozen maps, well clear of the ship.
func _place_snowmen(rng: RandomNumberGenerator, center: Vector2) -> void:
	_snowmen.clear()
	if Palette.planet(planet_theme).get("decor", &"rock") != &"ice":
		return
	var wanted := rng.randi_range(6, 9)
	for point in _shuffled(rng, _poisson(rng, 400.0, _inner_bounds(120.0))):
		if _snowmen.size() >= wanted:
			break
		var radius := rng.randf_range(16.0, 21.0)
		if point.distance_to(center) < clear_radius + 180.0 or not _is_free(point, radius * 2.2):
			continue
		_snowmen.append({"position": point, "radius": radius, "turn": rng.randf_range(-0.9, 0.9), "scarf": rng.randi_range(0, 2)})
		_claims.append([point, radius * 2.2])


func _draw_ice(item: Dictionary, colors: Dictionary) -> void:
	var size: float = item["size"]
	var shadow := Palette.SHADOW_OFFSET * (0.7 + size / 35.0)
	for shard in item["shards"]:
		_pen.draw_colored_polygon(Palette.offset_points(shard["body"], shadow), Palette.SHADOW_COLOR)
	for shard in item["shards"]:
		_pen.draw_colored_polygon(shard["body"], colors["ice_dark"])
		_pen.draw_colored_polygon(shard["lit"], colors["ice"])
		_pen.draw_polyline(shard["glint"], colors["ice_light"], maxf(size * 0.12, 1.5))


## Snowman seen from above (tilted toward the viewer like the rocks): big
## base ball, head, stick arms, coal eyes, carrot nose and a scarf.
func _draw_snowman(snowman: Dictionary, colors: Dictionary) -> void:
	var p: Vector2 = snowman["position"]
	var r: float = snowman["radius"]
	var turn: float = snowman["turn"]
	var head := p + Vector2(0.0, -r * 0.95)
	var hr := r * 0.62
	_pen.draw_circle(p + Palette.SHADOW_OFFSET * 1.2, r, Palette.SHADOW_COLOR)
	_pen.draw_circle(head + Palette.SHADOW_OFFSET * 1.2, hr, Palette.SHADOW_COLOR)
	# Stick arms.
	for side in [-1.0, 1.0]:
		var root := p + Vector2(side * r * 0.75, -r * 0.35)
		var tip: Vector2 = root + Vector2(side * r * 0.9, -r * 0.45).rotated(turn * 0.3)
		_pen.draw_line(root, tip, Palette.GOBLIN_WOOD_DARK, 2.4)
		_pen.draw_line(tip.lerp(root, 0.35), tip.lerp(root, 0.35) + Vector2(side * r * 0.2, -r * 0.3), Palette.GOBLIN_WOOD_DARK, 1.8)
	# Body.
	_pen.draw_circle(p, r, colors["snow_shade"])
	_pen.draw_circle(p + Vector2(-r * 0.12, -r * 0.12), r * 0.86, colors["snow"])
	for k in range(2):
		_pen.draw_circle(p + Vector2(0.0, -r * 0.1 + float(k) * r * 0.42), r * 0.1, Palette.UI_PANEL)
	# Scarf.
	var scarf: Color = [Color("D9534F"), Color("3E8ED0"), Color("E0A030")][int(snowman["scarf"])]
	_pen.draw_colored_polygon(_ellipse(head + Vector2(0.0, hr * 0.75), hr * 1.0, 0.45), scarf)
	_pen.draw_colored_polygon(PackedVector2Array([head + Vector2(hr * 0.5, hr * 0.8), head + Vector2(hr * 0.95, hr * 1.9), head + Vector2(hr * 0.35, hr * 1.85)]), scarf)
	# Head.
	_pen.draw_circle(head, hr, colors["snow_shade"])
	_pen.draw_circle(head + Vector2(-hr * 0.12, -hr * 0.12), hr * 0.86, colors["snow"])
	var face := Vector2.RIGHT.rotated(turn) * hr * 0.25
	for side in [-1.0, 1.0]:
		_pen.draw_circle(head + face + Vector2(side * hr * 0.32, -hr * 0.15), hr * 0.11, Palette.UI_PANEL)
	var nose := head + face + Vector2(0.0, hr * 0.12)
	_pen.draw_colored_polygon(PackedVector2Array([nose + Vector2(0.0, -hr * 0.12), nose + Vector2(hr * 0.75, hr * 0.05).rotated(turn * 0.5), nose + Vector2(0.0, hr * 0.14)]), Color("F08A24"))


func _place_camps(rng: RandomNumberGenerator, center: Vector2) -> void:
	_camps.clear()
	var colors := Palette.planet(planet_theme)
	if colors.get("decor", &"rock") != &"foliage":
		return
	for point in _shuffled(rng, _poisson(rng, 620.0, _inner_bounds(140.0))):
		if _camps.size() >= 5:
			break
		if point.distance_to(center) < clear_radius + 260.0 or not _is_free(point, 70.0):
			continue
		var fire := point + Vector2.RIGHT.rotated(rng.randf() * TAU) * 52.0
		_camps.append({"position": point, "fire": fire, "radius": rng.randf_range(26.0, 34.0), "turn": rng.randf() * TAU})
		_claims.append([point, 70.0])


func _draw_foliage(item: Dictionary, colors: Dictionary) -> void:
	var foliage_center: Vector2 = item["center"]
	var shadow := Palette.SHADOW_OFFSET * (0.8 + float(item["size"]) / 40.0)
	for blob in item["blobs"]:
		_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(8, blob[1], blob[2]), foliage_center + blob[0] + shadow), Palette.SHADOW_COLOR)
	for blob in item["blobs"]:
		_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(8, blob[1], blob[2]), foliage_center + blob[0]), colors["rock"])
	for blob in item["blobs"]:
		_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(8, blob[1] * 0.78, blob[2]), foliage_center + blob[0] + Vector2(-1.5, -2.0)), colors["canopy_mid"])
	for blob in item["blobs"]:
		var r: float = blob[1]
		_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(6, r * 0.42, blob[2]), foliage_center + blob[0] + Vector2(-r * 0.3, -r * 0.32)), colors["rock_light"])


## Round thatched goblin hut (top-down) with a crude spike and a campfire.
func _draw_camp(camp: Dictionary, colors: Dictionary) -> void:
	var hut: Vector2 = camp["position"]
	var radius: float = camp["radius"]
	var turn: float = camp["turn"]
	# Campfire: ring of stones, ember glow and a small flame.
	var fire: Vector2 = camp["fire"]
	_pen.draw_circle(fire, 20.0, Color(Palette.ACCENT, 0.12))
	for index in range(7):
		var stone := fire + Vector2.RIGHT.rotated(TAU * float(index) / 7.0) * 10.0
		_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(5, 3.4, float(index)), stone), colors["crater"])
	_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(3, 7.0, -PI / 2.0), fire), Palette.ACCENT)
	_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(3, 3.6, -PI / 2.0), fire + Vector2(0.0, 1.0)), Palette.GOLD)
	# Hut: shadow, thatch roof in rings, ridge cap, a doorway mat.
	var door := hut + Vector2.RIGHT.rotated(turn) * radius
	_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(5, 9.0, turn), door), colors["crater_inner"])
	_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(10, radius, turn), hut + Palette.SHADOW_OFFSET * 1.4), Palette.SHADOW_COLOR)
	_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(10, radius, turn), hut), colors["thatch_dark"])
	_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(10, radius * 0.86, turn), hut + Vector2(-1.5, -2.0)), colors["thatch"])
	for ring in [0.62, 0.38]:
		var points := Palette.offset_points(Palette.regular_polygon(10, radius * ring, turn), hut + Vector2(-1.0, -1.5))
		points.append(points[0])
		_pen.draw_polyline(points, colors["thatch_dark"], 2.0)
	for index in range(10):
		var spoke := Vector2.RIGHT.rotated(turn + TAU * float(index) / 10.0)
		_pen.draw_line(hut + spoke * radius * 0.38, hut + spoke * radius * 0.84, colors["thatch_dark"], 1.5)
	_pen.draw_circle(hut + Vector2(-1.0, -1.5), radius * 0.16, Palette.MECH)
	_pen.draw_circle(hut + Vector2(-2.0, -2.5), radius * 0.07, Palette.MECH_LIGHT)


func _random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 2147483646)


# ==========================================
# Drawing
# ==========================================

## Static map: painted once into a MeshBatch2D and drawn as a single mesh
## (thousands of polygons on jungle maps would otherwise be thousands of draw
## calls every frame). Rebaked whenever the map is regenerated.
func _draw() -> void:
	if _baked_mesh == null:
		var batch := MeshBatch2D.new()
		_pen = batch
		_paint()
		_pen = self
		_baked_mesh = batch.build()
	if _baked_mesh != null:
		draw_mesh(_baked_mesh, null)


## Paints the whole map through _pen (a MeshBatch2D while baking).
func _paint() -> void:
	var colors := Palette.planet(planet_theme)
	_pen.draw_rect(Rect2(Vector2.ZERO, world_size), colors["ground"], true)

	for patch in _patches:
		_pen.draw_colored_polygon(patch["points"], patch["color"])

	var lava: bool = colors.get("decor", &"rock") == &"lava"
	if lava:
		_paint_cracks(colors)
		_paint_lava_beds()

	# Shallow craters: dark rim, slightly lighter floor offset toward the light.
	# Volcanic worlds show extinct volcano cones instead.
	for crater in _craters:
		if lava:
			if not _lava_vents_active():
				_draw_extinct_volcano({"position": crater["position"], "radius": crater["radius"] * 1.25}, colors)
			continue
		var crater_center: Vector2 = crater["position"]
		var crater_radius: float = crater["radius"]
		_pen.draw_colored_polygon(_ellipse(crater_center, crater_radius, 0.66), colors["crater"])
		_pen.draw_colored_polygon(
			_ellipse(crater_center + Vector2(crater_radius * 0.12, crater_radius * 0.1), crater_radius * 0.78, 0.6),
			colors["crater_inner"]
		)

	for speckle in _speckles:
		_pen.draw_circle(speckle["position"], speckle["radius"], speckle["color"])

	# Ore deposits: the most saturated thing on the map ("greed" draws the eye).
	if (planet_theme != &"rocky" or not interactive_rocky_crystals) and not _verdant_trees_active():
		for deposit in _deposits:
			_draw_deposit(deposit)

	for camp in _camps:
		_draw_camp(camp, colors)

	# Rocks: one hard shadow, a dark body and a lit top facet (foliage clumps
	# on jungle worlds).
	for rock in _rocks:
		if rock.get("foliage", false):
			if not _verdant_trees_active():
				_draw_foliage(rock, colors)
			continue
		if rock.get("ice", false):
			_draw_ice(rock, colors)
			continue
		var size: float = rock["size"]
		_pen.draw_colored_polygon(Palette.offset_points(rock["points"], Palette.SHADOW_OFFSET * (0.6 + size / 40.0)), Palette.SHADOW_COLOR)
		_pen.draw_colored_polygon(rock["points"], colors["rock"])
		var facet: PackedVector2Array = rock["facet"]
		if facet.size() >= 3:
			_pen.draw_colored_polygon(facet, colors["rock_light"])

	for snowman in _snowmen:
		_draw_snowman(snowman, colors)

	if show_special_sites:
		for site in _special_sites:
			var ring := Palette.offset_points(Palette.regular_polygon(6, site["radius"], 0.0), site["position"])
			ring.append(ring[0])
			_pen.draw_polyline(ring, Color(Palette.UI_TEXT, 0.55), 3.0)
			_pen.draw_circle(site["position"], 6.0, Palette.ACCENT)


func _draw_deposit(deposit: Dictionary) -> void:
	# Jungle worlds show a big landmark tree where other planets show ore.
	if Palette.planet(planet_theme).get("decor", &"rock") == &"foliage":
		_draw_big_tree(deposit)
		return
	var deposit_center: Vector2 = deposit["position"]
	var gold: bool = deposit["gold"]
	var glow := Palette.GOLD if gold else Palette.COBALT
	glow.a = 0.10
	_pen.draw_circle(deposit_center, 54.0, glow)
	glow.a = 0.12
	_pen.draw_circle(deposit_center, 30.0, glow)
	for crystal in deposit["crystals"]:
		var offset: Vector2 = crystal[0]
		var crystal_scale: float = crystal[1]
		_pen.draw_circle(deposit_center + offset + Vector2(2.0, 14.0 * crystal_scale), 9.0 * crystal_scale, Palette.SHADOW_COLOR)
		_crystal(deposit_center + offset, crystal_scale, crystal[2], gold)


## Large old tree seen from above: a broad lobed canopy with a deep shadow,
## a darker inner crown and lit leaves toward the top-left.
func _draw_big_tree(deposit: Dictionary) -> void:
	var colors := Palette.planet(planet_theme)
	var tree_center: Vector2 = deposit["position"]
	var lobes: Array = []
	var crystals: Array = deposit["crystals"]
	var turn: float = (crystals[0][2] as float) * 3.0
	for index in range(7):
		var angle: float = turn + TAU * float(index) / 7.0
		var reach: float = 26.0 + 6.0 * float((index * 5) % 3)
		lobes.append([Vector2.RIGHT.rotated(angle) * reach, 22.0 + 4.0 * float(index % 2)])
	var shadow := Vector2(10.0, 14.0)
	_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(12, 34.0, turn), tree_center + shadow), Palette.SHADOW_COLOR)
	for lobe in lobes:
		_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(8, lobe[1], turn), tree_center + lobe[0] + shadow), Palette.SHADOW_COLOR)
	_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(12, 36.0, turn), tree_center), colors["rock"])
	for lobe in lobes:
		_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(8, lobe[1], turn), tree_center + lobe[0]), colors["rock"])
	for lobe in lobes:
		_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(8, lobe[1] * 0.74, turn), tree_center + lobe[0] * 0.92 + Vector2(-2.0, -3.0)), colors["canopy_mid"])
	_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(10, 22.0, turn), tree_center + Vector2(-3.0, -4.0)), colors["canopy_mid"])
	for lobe in lobes:
		var offset: Vector2 = lobe[0]
		if offset.x + offset.y < 8.0:
			_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(6, lobe[1] * 0.4, turn), tree_center + offset * 0.85 + Vector2(-6.0, -7.0)), colors["rock_light"])
	_pen.draw_colored_polygon(Palette.offset_points(Palette.regular_polygon(7, 12.0, turn), tree_center + Vector2(-9.0, -11.0)), colors["rock_light"])


## Ore crystal (same shape as Palette.draw_crystal) drawn through _pen.
func _crystal(center: Vector2, scale: float, rotation: float, gold: bool) -> void:
	var light := Palette.GOLD if gold else Palette.COBALT
	var dark := Palette.GOLD_SHADOW if gold else Palette.COBALT_SHADOW
	var shine := Palette.GOLD_LIGHT if gold else Palette.COBALT_LIGHT
	var xf := Transform2D(rotation, Vector2.ONE * scale, 0.0, center)
	_pen.draw_colored_polygon(PackedVector2Array([
		xf * Vector2(0.0, -22.0), xf * Vector2(8.0, -12.0), xf * Vector2(8.0, 6.0), xf * Vector2(0.0, 14.0),
	]), dark)
	_pen.draw_colored_polygon(PackedVector2Array([
		xf * Vector2(0.0, -22.0), xf * Vector2(-8.0, -12.0), xf * Vector2(-8.0, 6.0), xf * Vector2(0.0, 14.0),
	]), light)
	_pen.draw_colored_polygon(PackedVector2Array([
		xf * Vector2(0.0, -22.0), xf * Vector2(-8.0, -12.0), xf * Vector2(0.0, -9.0),
	]), shine)


func _ellipse(ellipse_center: Vector2, radius: float, squash: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(ellipse_center + Vector2(cos(angle), sin(angle) * squash) * radius)
	return points


func _sorted_around(points: PackedVector2Array) -> PackedVector2Array:
	var pivot := Vector2.ZERO
	for point in points:
		pivot += point
	pivot /= float(points.size())
	var list: Array = Array(points)
	list.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return (a - pivot).angle() < (b - pivot).angle()
	)
	return PackedVector2Array(list)
