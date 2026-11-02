extends Node2D

## Battle presentation for module artifacts (Claude sync 97). ArtifactManager
## adds one of these next to each module artifact effect; `setup` returns
## false when the artifact has no presentation. No gameplay here.
## Load with preload(); no class_name on purpose.

const DECOR := preload("res://Scripts/VFX/ArtifactShotDecor.gd")
const BURST := preload("res://Scripts/VFX/ArtifactBurstFx.gd")
const SHOT_KINDS := {
	&"amplifier": &"amplifier",
	&"fast_hourglass": &"fast",
	&"slow_hourglass": &"slow",
	&"heavy_shell": &"heavy",
	&"magnifying_glass": &"magnify",
}

var artifact_id: StringName
var module: ShipModule
var effect: Node
var _t: float = 0.0


func setup(definition: MagicArtifactDefinition, target_module: ShipModule, artifact_effect: Node) -> bool:
	artifact_id = definition.artifact_id
	module = target_module
	effect = artifact_effect
	var weapon := module as WeaponModule
	if SHOT_KINDS.has(artifact_id) and weapon != null:
		weapon.projectile_spawned.connect(_on_projectile_spawned)
		return true
	if artifact_id == &"treant_soul" and weapon != null:
		weapon.projectile_spawned.connect(_on_projectile_spawned)
		weapon.artifact_attack_started.connect(_on_attack_started)
		return true
	if artifact_id == &"fairy_curse" and module.has_signal("ship_healed_by_pulse"):
		module.connect("ship_healed_by_pulse", _on_ship_healed)
		return true
	return false


func _ready() -> void:
	z_index = 7


func _process(delta: float) -> void:
	_t += delta
	if artifact_id == &"treant_soul":
		queue_redraw()


func _boosted() -> bool:
	return is_instance_valid(effect) and bool(effect.get("_attack_boosted"))


func _charges() -> int:
	return int(effect.get("_charges")) if is_instance_valid(effect) else 0


func _on_projectile_spawned(projectile: Node2D) -> void:
	if not is_instance_valid(projectile):
		return
	var kind: StringName = SHOT_KINDS.get(artifact_id, &"")
	if artifact_id == &"treant_soul":
		if not _boosted():
			return
		kind = &"treant"
	var decor := DECOR.new()
	decor.kind = kind
	projectile.add_child(decor)


## Beam / saw / flame turrets have no projectile: flash the muzzle instead.
func _on_attack_started() -> void:
	if not _boosted() or not is_instance_valid(module):
		return
	if module is MachineGun or module is DwarfCannon or module is FusionWeapon:
		return  # projectile weapons decorate the shot itself
	var scene := get_tree().current_scene
	if scene == null:
		return
	var muzzle := module.get_node_or_null("Turret/Muzzle") as Node2D
	var fx := BURST.new()
	fx.kind = &"treant_flash"
	fx.size = 6.0
	scene.add_child(fx)
	fx.global_position = muzzle.global_position if muzzle != null else _turret_centre()


func _turret_centre() -> Vector2:
	var turret := module.get_node_or_null("Turret") as Node2D
	return turret.global_position if turret != null else module.global_position


func _on_ship_healed(_amount: float, origin: Vector2, radius: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var fx := BURST.new()
	fx.kind = &"fairy"
	fx.radius = radius
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as BasicEnemy
		if enemy != null and not enemy.is_dying() and enemy.global_position.distance_to(origin) <= radius:
			fx.targets.append(enemy.global_position)
	scene.add_child(fx)
	fx.global_position = origin


## Treant Soul: stored charges orbit the turret as glowing leaves.
func _draw() -> void:
	if artifact_id != &"treant_soul" or not is_instance_valid(module):
		return
	var charges := mini(_charges(), 6)
	if charges <= 0:
		return
	var c := to_local(_turret_centre())
	for k in range(charges):
		var a := _t * 1.6 + TAU * float(k) / float(charges)
		var p := c + Vector2(cos(a) * 30.0, sin(a) * 30.0 * 0.6)
		draw_circle(p, 6.0, Color(0.5, 0.95, 0.4, 0.25))
		var v := Vector2.from_angle(a * 2.0) * 5.0
		draw_colored_polygon(PackedVector2Array([p - v, p + v.orthogonal() * 0.45, p + v, p - v.orthogonal() * 0.45]), Color(0.45, 0.85, 0.3, 0.95))
