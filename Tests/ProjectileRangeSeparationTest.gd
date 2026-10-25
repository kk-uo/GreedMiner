extends Node2D

## Verifies that weapon targeting range and projectile travel range are two
## independent gameplay stats and that Projectile Range changes both the
## projectile collision radius and its matching visual scale.

const MACHINE_GUN := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
const MACHINE_BULLET := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun_projectile.tscn")
const DWARF_CANNON := preload("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon.tscn")
const CANNONBALL := preload("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon_projectile.tscn")
const FLAMETHROWER := preload("res://Scenes/Modules/Weapons/Flamethrower/flamethrower.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _attack_bonus() -> float:
	return 0.5


func _projectile_bonus() -> float:
	return 0.25


func _run() -> void:
	var gun := MACHINE_GUN.instantiate() as MachineGun
	add_child(gun)
	gun.assembly_mode = true
	check(is_equal_approx(gun.attack_range, 400.0), "machine gun targeting range remains 400")
	check(is_equal_approx(gun.projectile_range, 4.0), "machine gun projectile radius remains 4")
	gun.attack_range = 120.0
	gun.projectile_range = 8.0
	check(is_equal_approx(gun.get_modified_attack_range(gun.attack_range), 120.0), "changing projectile range does not change targeting range")
	check(is_equal_approx(gun.get_modified_projectile_range(gun.projectile_range), 8.0), "changing targeting range does not change projectile range")
	gun.add_artifact_range_bonus(Callable(self, "_attack_bonus"))
	check(is_equal_approx(gun.get_modified_attack_range(gun.attack_range), 180.0), "targeting modifier applies only to targeting range")
	check(is_equal_approx(gun.get_modified_projectile_range(gun.projectile_range), 8.0), "targeting modifier does not leak into projectile range")
	gun.add_artifact_projectile_range_bonus(Callable(self, "_projectile_bonus"))
	check(is_equal_approx(gun.get_modified_projectile_range(gun.projectile_range), 10.0), "projectile modifier uses its own pipeline")
	check(is_equal_approx(gun.get_modified_attack_range(gun.attack_range), 180.0), "projectile modifier does not leak into targeting range")

	var cannon := DWARF_CANNON.instantiate() as DwarfCannon
	cannon.assembly_mode = true
	add_child(cannon)
	check(is_equal_approx(cannon.attack_range, 500.0), "cannon targeting range remains 500")
	check(is_equal_approx(cannon.projectile_range, 6.0), "cannon projectile radius remains 6")
	var prism_definition := load("res://Resources/Artifacts/DemonPrism.tres") as MagicArtifactDefinition
	var prism_effect := prism_definition.effect_script.new() as MagicArtifactEffect
	prism_effect.configure(prism_definition, null)
	prism_effect.call("configure_weapon", cannon)
	cannon.add_child(prism_effect)
	check(is_equal_approx(cannon.get_modified_attack_range(cannon.attack_range), 500.0), "Demon Prism does not modify targeting range")
	check(is_equal_approx(cannon.get_modified_projectile_range(cannon.projectile_range), 12.0), "Demon Prism explicitly modifies projectile range")
	prism_effect.cleanup()
	check(is_equal_approx(cannon.get_modified_attack_range(cannon.attack_range), 500.0), "artifact cleanup restores targeting range")
	check(is_equal_approx(cannon.get_modified_projectile_range(cannon.projectile_range), 6.0), "artifact cleanup restores projectile range")

	var flame := FLAMETHROWER.instantiate() as Flamethrower
	flame.assembly_mode = true
	add_child(flame)
	flame.attack_range = 80.0
	flame.projectile_range = 30.0
	check(is_equal_approx(flame.get_modified_attack_range(flame.attack_range), 80.0), "flamethrower lock range is independent")
	check(is_equal_approx(flame.get_modified_projectile_range(flame.projectile_range), 30.0), "flamethrower puff range is independent")
	check(is_equal_approx(flame.get_flame_size_scale(), 2.0), "flamethrower projectile range scales puff model and collision")

	var bullet := MACHINE_BULLET.instantiate() as MachineGunProjectile
	bullet.speed = 600.0
	bullet.projectile_range = 8.0
	add_child(bullet)
	var shell := CANNONBALL.instantiate() as DwarfCannonProjectile
	shell.speed = 600.0
	shell.projectile_range = 12.0
	add_child(shell)
	check(is_equal_approx((bullet.get_node("CollisionShape2D") as CollisionShape2D).scale.x, 2.0), "machine gun collision radius follows projectile range")
	check(is_equal_approx(bullet.get_projectile_visual_scale(), 2.0), "machine gun model follows projectile range")
	check(is_equal_approx((shell.get_node("CollisionShape2D") as CollisionShape2D).scale.x, 2.0), "cannon collision radius follows projectile range")
	check(is_equal_approx(shell.get_projectile_visual_scale(), 2.0), "cannon model follows projectile range")
	bullet._process(0.5)
	shell._physics_process(0.5)
	check(is_equal_approx(bullet.position.x, 300.0), "projectile range does not limit bullet travel distance")
	check(is_equal_approx(shell.position.x, 300.0), "projectile range does not limit cannonball travel distance")

	if failures.is_empty():
		print("PROJECTILE_RANGE_SEPARATION_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("PROJECTILE_RANGE_SEPARATION_TEST: " + failure)
		get_tree().quit(1)
