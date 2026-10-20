extends Node

## The wizard is an explicit click-pop exception, not a change to large tiers.
func _ready() -> void:
	var wizard := load("res://Scenes/Enemies/snow_monster_wizard.tscn").instantiate() as BasicEnemy
	var large := load("res://Scenes/Enemies/big_snow_monster.tscn").instantiate() as BasicEnemy
	var common := load("res://Scenes/Enemies/snow_monster.tscn").instantiate() as BasicEnemy
	wizard.reward_ore = 0.0
	add_child(wizard)
	add_child(large)
	add_child(common)
	var ok := wizard.enemy_tier == BasicEnemy.EnemyTier.LARGE and wizard.is_clickable()
	ok = ok and large.enemy_tier == BasicEnemy.EnemyTier.LARGE and not large.is_clickable()
	ok = ok and common.enemy_tier == BasicEnemy.EnemyTier.COMMON and common.is_clickable()
	for index in range(BasicEnemy.CLICKS_TO_POP):
		ok = wizard.register_click() and ok
		if index < BasicEnemy.CLICKS_TO_POP - 1:
			ok = ok and not wizard.is_dying()
	ok = ok and wizard.is_dying() and not wizard.is_clickable()
	print("SNOW_WIZARD_CLICK_TEST: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
