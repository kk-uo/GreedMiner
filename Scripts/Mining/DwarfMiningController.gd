extends Node2D

## Drag from a mining module to a crystal. Right-click the module to recall.
const DWARF := preload("res://Scripts/Mining/DwarfMiner.gd")
## Zombie graves are dug up by dwarves: releasing a drag on graves (no crystal
## under the cursor) digs every grave inside GraveDigSite.DIG_RADIUS.
const GRAVE_DIG_SITE := preload("res://Scripts/Battle/Graveyard/GraveDigSite.gd")
const RESPAWN_SECONDS := 15.0
const PICK_RADIUS := 32.0
var battle: Node2D
var ship: Ship
var field: Battlefield
var workers: Dictionary = {}
var cooldowns: Dictionary = {}
var extra_workers: Dictionary = {}
var extra_cooldowns: Dictionary = {}
var dragging: MiningModule
var drag_position := Vector2.ZERO
var _time: float = 0.0
## Keeps redrawing one more frame after the drag / dials end to clear them.
var _drawn: bool = false

func _process(delta: float) -> void:
	for timers in [cooldowns, extra_cooldowns]:
		for module in timers.keys():
			if not is_instance_valid(module) or float(timers[module]) <= delta:
				timers.erase(module)
			else:
				timers[module] = float(timers[module]) - delta
	var animated := dragging != null or not cooldowns.is_empty() or not extra_cooldowns.is_empty()
	if animated or _drawn:
		_time += delta
		queue_redraw()
	_drawn = animated

func handle_input(event: InputEvent) -> bool:
	var mouse := event as InputEventMouse
	if mouse == null:
		return false
	var point := battle.to_global((battle.make_input_local(mouse) as InputEventMouse).position)
	if event is InputEventMouseMotion and is_instance_valid(dragging):
		drag_position = point
		queue_redraw()
		return true
	var button := event as InputEventMouseButton
	if button == null:
		return false
	if button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		var module := _module_at(point)
		if module != null:
			var recalled := false
			for slots in [workers, extra_workers]:
				var worker: Variant = slots.get(module)
				if is_instance_valid(worker):
					worker.recall()
					recalled = true
			if recalled:
				return true
	if button.button_index != MOUSE_BUTTON_LEFT:
		return false
	if button.pressed:
		dragging = _module_at(point)
		if dragging != null:
			drag_position = point
			queue_redraw()
			return true
	elif is_instance_valid(dragging):
		var selected := dragging
		dragging = null
		queue_redraw()
		var target := _crystal_at(point)
		if target != null:
			dispatch(selected, target)
		else:
			dispatch_to_graves(selected, point)
		return true
	return false

func _module_at(point: Vector2) -> MiningModule:
	for child in ship.installed_modules.get_children():
		if child is MiningModule:
			var local: Vector2 = child.to_local(point)
			if absf(local.x) <= 30.0 and absf(local.y) <= 30.0:
				return child
	return null

func _crystal_at(point: Vector2) -> Node2D:
	var container := field.get_interactables_root().get_node_or_null("RockyCrystals")
	if container == null:
		return null
	var nearest: Node2D
	var best := PICK_RADIUS
	for crystal in container.get_children():
		if not crystal.call("can_be_mined"):
			continue
		var distance: float = crystal.global_position.distance_to(point)
		if distance < best:
			best = distance
			nearest = crystal
	return nearest

func dispatch(module: MiningModule, crystal: Node2D) -> bool:
	if not is_instance_valid(module) or not module.mining_enabled or not is_instance_valid(crystal) or not crystal.call("can_be_mined"):
		return false
	var use_extra := is_instance_valid(workers.get(module)) or float(cooldowns.get(module, 0.0)) > 0.0
	if use_extra and (not ResearchManager.is_research_completed(&"mining_worker") or is_instance_valid(extra_workers.get(module)) or float(extra_cooldowns.get(module, 0.0)) > 0.0):
		return false
	var dwarf := DWARF.new()
	dwarf.module = module
	dwarf.crystal = crystal
	dwarf.set("_target_site", crystal if crystal.has_method("release") else null)
	dwarf.battle = battle
	if use_extra:
		extra_workers[module] = dwarf
	else:
		workers[module] = dwarf
	dwarf.returned.connect(_worker_returned.bind(module))
	dwarf.died.connect(_worker_died.bind(module))
	battle.add_child(dwarf)
	dwarf.global_position = module.global_position
	return true

## Sends the module's dwarf to dig up every unclaimed zombie grave inside
## the circle around point. False when there are none (or no dwarf free).
func dispatch_to_graves(module: MiningModule, point: Vector2) -> bool:
	var graves := _graves_at(point)
	if graves.is_empty():
		return false
	var site: Node2D = GRAVE_DIG_SITE.new()
	site.call("setup", graves)
	field.get_interactables_root().add_child(site)
	site.global_position = point
	if not dispatch(module, site):
		site.call("release")
		return false
	return true


func _graves_at(point: Vector2) -> Array[Node2D]:
	if field == null or not field.has_method("get_zombie_graves_in"):
		return []
	return field.get_zombie_graves_in(point, GRAVE_DIG_SITE.DIG_RADIUS)


## A dwarf that leaves a dig site unfinished lets the graves go again.
func _release_site(worker: Node2D) -> void:
	var site: Variant = worker.get("_target_site")
	if is_instance_valid(site) and site.has_method("release") and site.call("can_be_mined"):
		site.call("release")


func _worker_returned(worker: Node2D, module: MiningModule) -> void:
	_release_site(worker)
	if workers.get(module) == worker:
		workers.erase(module)
	elif extra_workers.get(module) == worker:
		extra_workers.erase(module)

func _worker_died(worker: Node2D, module: MiningModule) -> void:
	_release_site(worker)
	if workers.get(module) == worker:
		workers.erase(module)
		cooldowns[module] = RESPAWN_SECONDS
	elif extra_workers.get(module) == worker:
		extra_workers.erase(module)
		extra_cooldowns[module] = RESPAWN_SECONDS

## Presentation: a dashed gold dispatch line that snaps to the crystal under
## the cursor (pulsing ring), and a recovery dial on modules whose dwarf fell.
func _draw() -> void:
	const GOLD := Color("F5CE6A")
	for timers in [cooldowns, extra_cooldowns]:
		for module in timers.keys():
			var left := float(timers[module])
			if left <= 0.0 or not is_instance_valid(module):
				continue
			var at := to_local(module.global_position)
			draw_circle(at, 15.0, Color(0, 0, 0, 0.45))
			draw_arc(at, 12.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - left / RESPAWN_SECONDS), 24, GOLD, 3.0)
	if not is_instance_valid(dragging):
		return
	var from := to_local(dragging.global_position)
	var target := _crystal_at(drag_position)
	var graves: Array[Node2D] = []
	if target == null:
		graves = _graves_at(drag_position)
	var to := to_local(target.global_position) if target != null else to_local(drag_position)
	var length := from.distance_to(to)
	var dir := (to - from) / maxf(length, 0.001)
	var dash := 9.0
	var gap := 6.0
	var offset := fposmod(_time * 40.0, dash + gap)
	var x := -offset
	while x < length:
		var a := maxf(x, 0.0)
		var b := minf(x + dash, length - (22.0 if target != null else 0.0))
		if b > a:
			draw_line(from + dir * a + Vector2(1.5, 1.5), from + dir * b + Vector2(1.5, 1.5), Color(0, 0, 0, 0.3), 3.0)
			draw_line(from + dir * a, from + dir * b, GOLD, 3.0)
		x += dash + gap
	draw_circle(from, 5.0, GOLD)
	if target != null:
		var pulse := 0.5 + 0.5 * sin(_time * 8.0)
		draw_circle(to, 22.0 + 3.0 * pulse, Color(GOLD, 0.12))
		draw_arc(to, 22.0 + 3.0 * pulse, 0.0, TAU, 32, GOLD, 2.5)
		for k in range(4):
			var a := TAU * float(k) / 4.0 + _time * 1.5
			draw_line(to + Vector2.RIGHT.rotated(a) * 27.0, to + Vector2.RIGHT.rotated(a) * 33.0, GOLD, 2.5)
	elif not graves.is_empty():
		# Dig circle: every grave inside is dug up.
		const LILAC := Color("C4A0FF")
		var pulse := 0.5 + 0.5 * sin(_time * 8.0)
		draw_circle(to, GRAVE_DIG_SITE.DIG_RADIUS, Color(LILAC, 0.1))
		draw_arc(to, GRAVE_DIG_SITE.DIG_RADIUS, 0.0, TAU, 48, LILAC, 2.5)
		for grave in graves:
			draw_arc(to_local(grave.global_position) + Vector2(0, -8), 16.0 + 2.0 * pulse, 0.0, TAU, 20, Color(LILAC, 0.9), 2.0)
	else:
		draw_arc(to, 10.0, 0.0, TAU, 20, Color(GOLD, 0.6), 2.0)
