extends HostileProjectile

## A locked-direction, destructible saw. Friendly weapons use the shared
## destructible_props collision path; the ship and chopping dwarves use the
## existing hostile-projectile paths.
@export_range(1.0, 100000.0, 1.0) var max_health: float = 4000.0
var current_health: float = 4000.0
var _spin: float = 0.0

func _ready() -> void:
	current_health = max_health
	add_to_group(&"destructible_props")
	super()

func take_damage(amount: float) -> void:
	if _has_hit or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	if current_health <= 0.0:
		_has_hit = true
		set_physics_process(false)
		set_deferred("monitoring", false)
		queue_free()

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
		if target.distance_to(Geometry2D.get_closest_point_to_segment(target, previous, global_position)) <= 25.0:
			_has_hit = true
			node.call("take_damage", damage)
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 22.0, Color("9A9F99"))
	for index in range(8):
		var angle := _spin + TAU * float(index) / 8.0
		draw_line(Vector2.RIGHT.rotated(angle) * 17.0, Vector2.RIGHT.rotated(angle) * 28.0, Color("D9D9CB"), 6.0)
	draw_circle(Vector2.ZERO, 9.0, Color("644B39"))
