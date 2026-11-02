class_name DragonNestMelee
extends BasicEnemy

var _animation_time: float = 0.0


func _process(delta: float) -> void:
	_animation_time += delta
	super(delta)


var _pen := MeshBatch2D.new()


func _get_visual_radius() -> float:
	return 13.0 if enemy_id == &"kobold" else 30.0


func _draw() -> void:
	var bob := sin(_animation_time * 8.0) * (1.0 if not _is_attacking else 0.25)
	# Attacks lunge the body forward a little.
	var lunge := maxf(sin(_animation_time * 9.0), 0.0) * 3.0 if _is_attacking else 0.0
	DragonNestArt.mono = Palette.HIT_FLASH if _is_flashing() else Color(0, 0, 0, 0)
	DragonNestArt.begin(_pen, Transform2D(_facing, Vector2(0.0, bob) + Vector2.from_angle(_facing) * lunge))
	if enemy_id == &"kobold":
		DragonNestArt.kobold(_pen, 13.0, _animation_time)
	else:
		DragonNestArt.lizard(_pen, 26.0, _animation_time)
	DragonNestArt.mono = Color(0, 0, 0, 0)
	_pen.flush_to(self)
