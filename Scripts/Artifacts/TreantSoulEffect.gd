extends MagicArtifactEffect

## Each credited kill stores one boosted firing action for this weapon alone.
## A volley consumes one charge, regardless of its pellet count or hit count.
var weapon: WeaponModule
var _charges: int = 0
var _attack_boosted: bool = false


func configure_weapon(target_weapon: WeaponModule) -> void:
	weapon = target_weapon


func _ready() -> void:
	if not is_instance_valid(weapon):
		return
	weapon.enemy_defeated.connect(_on_enemy_defeated)
	weapon.artifact_attack_started.connect(_on_attack_started)
	weapon.artifact_attack_finished.connect(_on_attack_finished)
	weapon.add_artifact_damage_multiplier(Callable(self, "_damage_multiplier"))


func _on_enemy_defeated(_death_position: Vector2, _max_health: float) -> void:
	_charges += 1


func _on_attack_started() -> void:
	_attack_boosted = _charges > 0
	if _attack_boosted:
		_charges -= 1


func _on_attack_finished() -> void:
	_attack_boosted = false


func _damage_multiplier() -> float:
	return maxf(float(definition.effect_parameters.get("next_attack_multiplier", 2.0)), 0.0) if _attack_boosted else 1.0


func cleanup() -> void:
	if is_instance_valid(weapon):
		if weapon.enemy_defeated.is_connected(_on_enemy_defeated):
			weapon.enemy_defeated.disconnect(_on_enemy_defeated)
		if weapon.artifact_attack_started.is_connected(_on_attack_started):
			weapon.artifact_attack_started.disconnect(_on_attack_started)
		if weapon.artifact_attack_finished.is_connected(_on_attack_finished):
			weapon.artifact_attack_finished.disconnect(_on_attack_finished)
		weapon.remove_artifact_damage_multiplier(Callable(self, "_damage_multiplier"))
	_charges = 0
	_attack_boosted = false
	queue_free()
