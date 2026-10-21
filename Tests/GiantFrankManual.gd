extends Node2D

## Isolated encounter: this scene does not start or alter planet waves.
const BATTLE := preload("res://Scenes/Battle/BattleMain.tscn")
const FRANK := preload("res://Scenes/Enemies/giant_frank.tscn")
var boss: GiantFrank
var status: Label

func _ready() -> void:
	var battle := BATTLE.instantiate()
	battle.get_node("WaveManager").auto_start = false
	battle.get_node("MiningQteManager").auto_trigger = false
	battle.get_node("ShipLaunchController").play_landing_on_ready = false
	add_child(battle)
	var field := battle.get_node("Battlefield") as Battlefield
	field.planet_theme = &"graveyard"
	field.generate(4242)
	var ship := battle.get_node("Ship") as Ship
	boss = FRANK.instantiate() as GiantFrank
	boss.target_ship = ship
	battle.get_node("Enemies").add_child(boss)
	boss.global_position = ship.to_global(Ship.SHIP_SIZE * 0.5) + Vector2(300, 0)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(24, 100)
	layer.add_child(box)
	status = Label.new()
	box.add_child(status)
	var hit := Button.new()
	hit.text = "Deal 1000 damage"
	hit.pressed.connect(func(): if is_instance_valid(boss): boss.take_damage(1000.0))
	box.add_child(hit)
	var kill := Button.new()
	kill.text = "Deplete current phase HP"
	kill.pressed.connect(func(): if is_instance_valid(boss): boss.take_damage(100000.0))
	box.add_child(kill)
	boss.zombies_summoned.connect(func(count: int): print("Grave summons: ", count))
	boss.lightning_struck.connect(func(_point: Vector2): print("Lightning strikes Giant Frank"))

func _process(_delta: float) -> void:
	if status == null:
		return
	if is_instance_valid(boss):
		status.text = "Giant Frank phase %d | HP %.0f | mission ore %.0f" % [boss.phase, boss.get_current_health(), ResourceManager.mission_ore]
	else:
		status.text = "Giant Frank defeated | mission ore %.0f" % ResourceManager.mission_ore
