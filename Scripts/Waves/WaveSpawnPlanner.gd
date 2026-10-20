class_name WaveSpawnPlanner
extends RefCounted

## Converts exact wave quotas and optional special-event rules into requests.

const CARDINAL_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.RIGHT,
]


static func build_plan(
	wave: WaveDefinition,
	rules: Array[SpecialSpawnEventRule],
	rng: RandomNumberGenerator
) -> WaveSpawnPlan:
	var plan := WaveSpawnPlan.new()
	if wave == null:
		plan.validation_errors.append("Cannot plan a null wave.")
		return plan
	if wave.configuration_pending:
		return plan

	var allowed_directions := wave.get_allowed_direction_vectors()
	if (
		wave.spawn_direction_mode != WaveDefinition.SpawnDirectionMode.RANDOM_EDGES
		and allowed_directions.is_empty()
	):
		plan.validation_errors.append("Wave %d has no allowed spawn directions." % wave.wave_number)
		return plan
	if wave.spawn_direction_mode == WaveDefinition.SpawnDirectionMode.SINGLE_DIRECTION:
		plan.selected_direction = _pick_direction(allowed_directions, rng)

	var remaining_by_entry: Dictionary = {}
	for entry in wave.enemy_entries:
		if entry == null:
			plan.validation_errors.append("Wave %d contains an empty spawn entry." % wave.wave_number)
			continue
		if entry.spawn_count < 0 or entry.spawn_cost <= 0:
			plan.validation_errors.append("Wave %d has invalid quota or cost for '%s'." % [wave.wave_number, entry.enemy_id])
			continue
		if entry.spawn_count > 0 and entry.resolve_scene() == null:
			plan.validation_errors.append("Wave %d cannot resolve '%s'." % [wave.wave_number, entry.enemy_id])
			continue
		remaining_by_entry[entry] = entry.spawn_count
		plan.quota_by_enemy_id[String(entry.enemy_id)] = int(plan.quota_by_enemy_id.get(String(entry.enemy_id), 0)) + entry.spawn_count

	if not plan.validation_errors.is_empty():
		return plan

	var special_requests: Array[WaveSpawnRequest] = []
	for rule in rules:
		if rule == null or rule.maximum_events_per_wave <= 0:
			continue
		var entry := _find_entry(wave, rule.enemy_id)
		if entry == null:
			continue
		var available := int(remaining_by_entry.get(entry, 0))
		if (
			rule.trigger_mode == SpecialSpawnEventRule.TriggerMode.FIXED_PHASE_FRACTION
			and rule.exact_wave == wave.wave_number
			and available < rule.get_required_minimum()
		):
			plan.validation_errors.append("Wave %d cannot afford fixed event '%s'." % [wave.wave_number, rule.event_id])
			continue
		var event_count := 0
		while event_count < rule.maximum_events_per_wave and rule.is_eligible(wave.wave_number, available):
			if not rule.roll(rng):
				break
			var group_size := rule.choose_group_size(available, rng)
			if group_size <= 0:
				plan.validation_errors.append("Wave %d cannot afford fixed event '%s'." % [wave.wave_number, rule.event_id])
				break
			var direction := plan.selected_direction
			if direction == Vector2.ZERO:
				direction = _pick_direction(
					allowed_directions if not allowed_directions.is_empty() else CARDINAL_DIRECTIONS,
					rng
				)
			var request := WaveSpawnRequest.new()
			request.entry = entry
			request.spawn_count = group_size
			request.pattern = (
				WaveDefinition.SpawnPattern.FORMATION
				if rule.pattern == SpecialSpawnEventRule.Pattern.FORMATION
				else WaveDefinition.SpawnPattern.CLUSTER
			)
			request.direction = direction
			request.cluster_radius = rule.cluster_radius
			request.formation_spacing = rule.formation_spacing
			request.special_event_id = rule.event_id
			request.with_flag_bearer = rule.with_flag_bearer
			if rule.trigger_mode == SpecialSpawnEventRule.TriggerMode.FIXED_PHASE_FRACTION:
				request.trigger_phase_fraction = clampf(rule.trigger_phase_fraction, 0.0, 1.0)
				plan.timed_requests.append(request)
			else:
				special_requests.append(request)
			plan.special_events.append({
				"event_id": rule.event_id,
				"enemy_id": rule.enemy_id,
				"group_size": group_size,
				"direction": direction,
				"cluster_radius": rule.cluster_radius,
				"pattern": request.pattern,
				"formation_spacing": rule.formation_spacing,
				"with_flag_bearer": rule.with_flag_bearer,
				"trigger_phase_fraction": request.trigger_phase_fraction,
				"trigger_time": wave.get_effective_spawn_phase_duration() * maxf(request.trigger_phase_fraction, 0.0),
			})
			available -= group_size
			remaining_by_entry[entry] = available
			event_count += 1

	var normal_requests := _build_normal_requests(
		wave,
		remaining_by_entry,
		allowed_directions,
		plan.selected_direction,
		rng
	)
	# Keep each pack contiguous while placing it inside, rather than on top of,
	# the normal schedule. This makes the event visible without changing totals.
	var insertion_index := normal_requests.size() / 3
	for request in special_requests:
		normal_requests.insert(insertion_index, request)
		insertion_index += 1
	plan.requests = normal_requests
	plan.timed_requests.sort_custom(func(a: WaveSpawnRequest, b: WaveSpawnRequest) -> bool: return a.trigger_phase_fraction < b.trigger_phase_fraction)
	plan.total_spawn_count = _count_requests(plan.requests) + _count_requests(plan.timed_requests)
	plan.total_spawn_budget = _budget_requests(plan.requests) + _budget_requests(plan.timed_requests)

	if plan.total_spawn_count != wave.get_total_spawn_count():
		plan.validation_errors.append("Wave %d plan count %d does not match quota %d." % [wave.wave_number, plan.total_spawn_count, wave.get_total_spawn_count()])
	if plan.total_spawn_budget != wave.get_total_spawn_budget():
		plan.validation_errors.append("Wave %d plan budget %d does not match quota budget %d." % [wave.wave_number, plan.total_spawn_budget, wave.get_total_spawn_budget()])
	return plan


static func _build_normal_requests(
	wave: WaveDefinition,
	remaining: Dictionary,
	allowed_directions: Array[Vector2],
	shared_direction: Vector2,
	rng: RandomNumberGenerator
) -> Array[WaveSpawnRequest]:
	var requests: Array[WaveSpawnRequest] = []
	if wave.interleave_enemy_types:
		var still_available := true
		while still_available:
			still_available = false
			for entry in wave.enemy_entries:
				var count := int(remaining.get(entry, 0))
				if count <= 0:
					continue
				requests.append(_ordinary_request(
					entry,
					wave.spawn_pattern,
					_resolve_request_direction(wave, allowed_directions, shared_direction, rng)
				))
				remaining[entry] = count - 1
				still_available = true
		return requests

	for first_pass in [true, false]:
		for entry in wave.enemy_entries:
			if entry == null or entry.spawn_first != first_pass:
				continue
			for _count in range(int(remaining.get(entry, 0))):
				requests.append(_ordinary_request(
					entry,
					wave.spawn_pattern,
					_resolve_request_direction(wave, allowed_directions, shared_direction, rng)
				))
	return requests


static func _ordinary_request(
	entry: EnemySpawnEntry,
	pattern: WaveDefinition.SpawnPattern,
	direction: Vector2
) -> WaveSpawnRequest:
	var request := WaveSpawnRequest.new()
	request.entry = entry
	request.pattern = pattern
	request.direction = direction
	return request


static func _resolve_request_direction(
	wave: WaveDefinition,
	allowed_directions: Array[Vector2],
	shared_direction: Vector2,
	rng: RandomNumberGenerator
) -> Vector2:
	match wave.spawn_direction_mode:
		WaveDefinition.SpawnDirectionMode.SINGLE_DIRECTION:
			return shared_direction
		WaveDefinition.SpawnDirectionMode.RESTRICTED_DIRECTIONS:
			return _pick_direction(allowed_directions, rng)
		_:
			# Vector2.ZERO preserves EnemySpawner's existing random/multi-edge pattern.
			return Vector2.ZERO


static func _pick_direction(
	directions: Array[Vector2],
	rng: RandomNumberGenerator
) -> Vector2:
	if directions.is_empty():
		return Vector2.ZERO
	return directions[rng.randi_range(0, directions.size() - 1)]


static func _find_entry(wave: WaveDefinition, enemy_id: StringName) -> EnemySpawnEntry:
	for entry in wave.enemy_entries:
		if entry != null and entry.enemy_id == enemy_id:
			return entry
	return null


static func _count_requests(requests: Array[WaveSpawnRequest]) -> int:
	var total := 0
	for request in requests:
		total += request.spawn_count
	return total


static func _budget_requests(requests: Array[WaveSpawnRequest]) -> int:
	var total := 0
	for request in requests:
		total += request.get_budget_cost()
	return total
