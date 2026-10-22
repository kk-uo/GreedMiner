class_name HostileProjectile
extends Area2D

## Shared single-hit projectile used by ranged enemies.

@export var speed: float = 300.0
@export var damage: float = 5.0
@export var maximum_lifetime: float = 3.0
@export var debug_hit_logging: bool = false

var direction: Vector2 = Vector2.RIGHT
var target_ship: Ship
var _remaining_lifetime: float
var _has_hit: bool = false


func _ready() -> void:
	_remaining_lifetime = maximum_lifetime
	add_to_group("hostile_projectiles")
	var callback := Callable(self, "_on_area_entered")
	if not area_entered.is_connected(callback):
		area_entered.connect(callback)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _has_hit:
		return
	global_position += direction.normalized() * speed * delta
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _has_hit or not area is ShipDamageArea:
		return
	var damage_area := area as ShipDamageArea
	if is_instance_valid(target_ship) and damage_area.get_parent() != target_ship:
		return
	_has_hit = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	damage_area.apply_damage(damage)
	_on_ship_hit()
	queue_free()


## Presentation/log hook for projectile families.
func _on_ship_hit() -> void:
	if debug_hit_logging:
		print("Hostile projectile hit! Damage: %s" % damage)
