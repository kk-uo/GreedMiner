class_name RangedEnemy
extends BasicEnemy

## Reusable ranged-enemy behavior. The base movement logic stops at
## attack_range; each attack creates a configurable hostile projectile.

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 300.0
@export var projectile_spawn_offset: float = 0.0


func _perform_attack(ship: Ship) -> void:
	if projectile_scene == null:
		push_warning("%s: projectile scene is missing." % enemy_name)
		return
	var projectile := projectile_scene.instantiate() as HostileProjectile
	if projectile == null:
		push_error("%s: projectile scene must inherit HostileProjectile.gd." % enemy_name)
		return

	var direction_to_ship := global_position.direction_to(
		ship.to_global(Ship.SHIP_SIZE * 0.5)
	)
	projectile.direction = direction_to_ship
	projectile.speed = projectile_speed
	projectile.damage = attack_damage
	projectile.target_ship = ship

	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_parent()
	spawn_parent.add_child(projectile)
	projectile.global_position = global_position + direction_to_ship * projectile_spawn_offset
	print("%s fires! Damage: %s" % [enemy_name, attack_damage])
