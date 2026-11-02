extends Node

const FROST_EFFECT := preload("res://Scripts/Artifacts/FrostBreathArtifactEffect.gd")


func _ready() -> void:
	var cases: Array[Rect2] = [
		Rect2(0.0, 0.0, 120.0, 40.0),
		Rect2(0.0, 0.0, 3.0, 3.0),
		Rect2(0.0, 0.0, 0.0, 24.0),
		Rect2(15.0, 5.0, -30.0, 12.0),
	]
	for bounds in cases:
		var points := Palette.rounded_rect_points(bounds, 20.0)
		if bounds.size.x == 0.0:
			if not points.is_empty():
				_fail("zero-width rounded rectangle should not draw")
				return
		elif Geometry2D.triangulate_polygon(points).is_empty():
			_fail("rounded rectangle should triangulate: %s" % bounds)
			return
	var weapon := (load("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn") as PackedScene).instantiate() as WeaponModule
	var enemy := (load("res://Scenes/Enemies/little_rock.tscn") as PackedScene).instantiate() as BasicEnemy
	weapon.set("current_target", enemy)
	var effect := FROST_EFFECT.new()
	effect.configure_weapon(weapon)
	enemy.free()
	effect._physics_process(0.016)
	if is_instance_valid(effect.get("_frozen_target")):
		_fail("freed locked target should be ignored")
		return
	weapon.free()
	effect.free()
	print("PALETTE AND FROST REGRESSION TEST PASS")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("PALETTE AND FROST REGRESSION TEST FAIL: " + message)
	get_tree().quit(1)
