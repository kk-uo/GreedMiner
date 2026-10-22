extends HostileProjectile

## A locked-direction saw. Working tree-chopping dwarves can intercept it;
## otherwise the existing ShipDamageArea collision path handles the ship hit.
var _spin: float = 0.0

func _physics_process(delta: float) -> void:
	var battle := get_tree().current_scene
	if battle != null and battle.get("_battle_ended") == true:
		queue_free()
		return
	var previous := global_position
	super(delta)
	if _has_hit or not is_inside_tree():
		return
	_spin += delta * 17.0
	for node in get_tree().get_nodes_in_group("mining_dwarves"):
		if not is_instance_valid(node) or not node.has_method("is_enemy_targetable") or not node.call("is_enemy_targetable"):
			continue
		var target: Vector2 = node.call("get_enemy_target_position")
		if target.distance_to(Geometry2D.get_closest_point_to_segment(target, previous, global_position)) <= 14.0:
			_has_hit = true
			node.call("take_damage", damage)
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color("9A9F99"))
	for index in range(8):
		var angle := _spin + TAU * float(index) / 8.0
		draw_line(Vector2.RIGHT.rotated(angle) * 9.0, Vector2.RIGHT.rotated(angle) * 17.0, Color("D9D9CB"), 4.0)
	draw_circle(Vector2.ZERO, 5.0, Color("644B39"))
