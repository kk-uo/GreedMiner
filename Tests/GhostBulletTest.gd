extends Node2D

const SAVE := preload("res://Tests/TestSave.gd")
const ENEMY := preload("res://Scenes/Enemies/little_rock.tscn")
const BULLET := preload("res://Scenes/Modules/Weapons/MachineGun/machine_gun_projectile.tscn")
const CANNON := preload("res://Scenes/Modules/Weapons/DwarfCannon/dwarf_cannon_projectile.tscn")
var errors: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	if not condition:
		errors.append(label)

func enemy_at(point: Vector2, hp: float) -> BasicEnemy:
	var enemy := ENEMY.instantiate() as BasicEnemy
	enemy.max_health = hp
	enemy.move_speed = 0.0
	enemy.reward_ore = 0.0
	add_child(enemy)
	enemy.global_position = point
	return enemy

func _run() -> void:
	SAVE.isolate("ghost_bullet")
	var def := ArtifactManager.get_definition(&"ghost_bullet")
	check(def != null and def.rarity == "Epic", "registered epic artifact")
	check(def.is_compatible_with_module(&"machine_gun") and def.is_compatible_with_module(&"dwarf_cannon"), "projectile weapons compatible")
	check(not def.is_compatible_with_module(&"laser") and not def.is_compatible_with_module(&"flamethrower"), "non-projectile weapons rejected")
	check(def in ArtifactManager.get_unowned_mining_chest_artifacts(&"graveyard_planet"), "graveyard chest eligible")
	check(def not in ArtifactManager.get_unowned_mining_chest_artifacts(&"rocky_planet"), "other planet excluded")
	check(ArtifactManager.grant_artifact(&"ghost_bullet"), "first grant")
	check(not ArtifactManager.grant_artifact(&"ghost_bullet"), "unique grant")
	ArtifactManager.reload_progress()
	check(ArtifactManager.owns_artifact(&"ghost_bullet"), "ownership persists")
	check(def not in ArtifactManager.get_unowned_mining_chest_artifacts(&"graveyard_planet"), "owned artifact excluded")
	ShipLoadout.install_module(0, 0, "res://Scenes/Modules/Weapons/MachineGun/machine_gun.tscn")
	ResearchManager.progress.levels["weapon_damage.machine_gun"] = 10
	check(ArtifactManager.equip_module_artifact(Vector2i(0, 0), &"ghost_bullet"), "equip on machine gun")
	ArtifactManager.reload_progress()
	check(ArtifactManager.get_module_artifact(Vector2i(0, 0)) == &"ghost_bullet", "equipment persists")
	var ship := load("res://Scenes/Ship/ship.tscn").instantiate() as Ship
	add_child(ship)
	await get_tree().process_frame
	var gun := ship.get_module_at(0, 0) as WeaponModule
	ArtifactManager.attach_battle_effects(ship)
	check(gun.get_artifact_projectile_pierces() == 1, "equipped weapon receives configured pierce")
	ArtifactManager.clear_battle_effects(ship)
	check(gun.get_artifact_projectile_pierces() == 0, "battle cleanup removes modifier")
	ship.queue_free()
	var bullet := BULLET.instantiate() as MachineGunProjectile
	add_child(bullet)
	bullet.enable_ghost_piercing(1)
	bullet.damage = 5.0
	var a := enemy_at(Vector2(200, 0), 5.0)
	var b := enemy_at(Vector2(300, 0), 5.0)
	var c := enemy_at(Vector2(400, 0), 20.0)
	var d := enemy_at(Vector2(500, 0), 20.0)
	bullet._on_area_entered(a)
	bullet._on_area_entered(b)
	check(not bullet.is_queued_for_deletion(), "consecutive kills continue")
	bullet._on_area_entered(c)
	bullet._on_area_entered(c)
	check(is_equal_approx(c.get_current_health(), 15.0), "same enemy hit once")
	check(not bullet.is_queued_for_deletion(), "first survivor consumes penetration")
	bullet._on_area_entered(d)
	check(bullet.is_queued_for_deletion() and is_equal_approx(d.get_current_health(), 15.0), "second survivor stops projectile; damage unchanged")
	var shell := CANNON.instantiate() as DwarfCannonProjectile
	shell.speed = 0.0
	shell.damage = 5.0
	shell.explosion_radius = 20.0
	add_child(shell)
	shell.enable_ghost_piercing(1)
	var x := enemy_at(Vector2(800, 0), 20.0)
	var y := enemy_at(Vector2(900, 0), 20.0)
	await get_tree().physics_frame
	shell.global_position = x.global_position
	shell._on_area_entered(x)
	await get_tree().process_frame
	check(is_equal_approx(x.get_current_health(), 15.0) and not shell.is_queued_for_deletion(), "first cannon explosion and continuation")
	shell.global_position = y.global_position
	shell._on_area_entered(y)
	await get_tree().process_frame
	check(is_equal_approx(y.get_current_health(), 15.0), "final cannon impact explodes")
	if errors.is_empty():
		print("GHOST_BULLET_TEST: PASS")
		get_tree().quit(0)
	else:
		for error in errors:
			push_error("GHOST_BULLET_TEST: " + error)
		get_tree().quit(1)
