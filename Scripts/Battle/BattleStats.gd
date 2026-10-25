class_name BattleStats
extends Node

## Per-battle tallies for the result board: kills per enemy type, the boss,
## kills credited to each weapon, ore by source and the battle time.
## Presentation data only - nothing is saved and no rule reads it.
## BattleMain adds one per battle and calls freeze() when the battle ends.

## Ore sources passed to ResourceManager.add_mission_ore(amount, source).
const SOURCE_ORDER: Array[StringName] = [&"drill", &"dwarf", &"crystal", &"qte", &"chest", &"tree", &"bounty", &"other"]
const SOURCE_NAMES := {
	&"drill": "Drilling",
	&"dwarf": "Dwarf Mining",
	&"crystal": "Crystals",
	&"qte": "Mining Events",
	&"chest": "Salvage Chests",
	&"tree": "Logging",
	&"bounty": "Bounties",
	&"other": "Other",
}

## enemy_id -> {"name", "scene", "boss", "count"} in first-kill order.
var kills: Dictionary = {}
## weapon_type_id -> kills credited to that weapon type.
var weapon_kills: Dictionary = {}
## source -> ore added during the battle.
var ore_by_source: Dictionary = {}
## Magic artifacts granted this battle: {"id", "name", "rarity"}. Still
## recorded after freeze() - a boss can grant one as the battle ends.
var artifacts: Array[Dictionary] = []
var elapsed_seconds: float = 0.0
var frozen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().get_nodes_in_group(&"enemies"):
		_watch(node)
	_watch_weapons(get_tree().root)
	ResourceManager.mission_ore_added.connect(_on_ore_added)
	ArtifactManager.artifact_granted.connect(_on_artifact_granted)


func _exit_tree() -> void:
	if ResourceManager.mission_ore_added.is_connected(_on_ore_added):
		ResourceManager.mission_ore_added.disconnect(_on_ore_added)
	if ArtifactManager.artifact_granted.is_connected(_on_artifact_granted):
		ArtifactManager.artifact_granted.disconnect(_on_artifact_granted)


func _process(delta: float) -> void:
	if not frozen:
		# Real seconds, so slow motion and developer speed do not skew it.
		elapsed_seconds += delta / maxf(Engine.time_scale, 0.01)


func freeze() -> void:
	frozen = true


func total_kills() -> int:
	var total := 0
	for entry in kills.values():
		total += int(entry["count"])
	return total


func total_ore() -> float:
	var total := 0.0
	for amount in ore_by_source.values():
		total += float(amount)
	return total


## Enemy rows, bosses first, then by count (largest first).
func enemy_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id in kills.keys():
		var entry: Dictionary = kills[id].duplicate()
		entry["id"] = id
		rows.append(entry)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["boss"]) != bool(b["boss"]):
			return bool(a["boss"])
		return int(a["count"]) > int(b["count"]))
	return rows


## [source, amount] pairs in a stable order, without empty sources.
func ore_rows() -> Array:
	var rows: Array = []
	for source in SOURCE_ORDER:
		var amount := float(ore_by_source.get(source, 0.0))
		if amount > 0.0:
			rows.append([source, amount])
	for source in ore_by_source.keys():
		if not SOURCE_ORDER.has(source) and float(ore_by_source[source]) > 0.0:
			rows.append([source, float(ore_by_source[source])])
	return rows


## The weapon type with the most credited kills, or &"" if none.
func best_weapon() -> StringName:
	var best: StringName = &""
	var best_count := 0
	for id in weapon_kills.keys():
		if int(weapon_kills[id]) > best_count:
			best = id
			best_count = int(weapon_kills[id])
	return best


func _on_node_added(node: Node) -> void:
	if node is BasicEnemy:
		_watch(node)
	elif node is WeaponModule:
		_watch_weapon(node as WeaponModule)


func _watch(node: Node) -> void:
	var enemy := node as BasicEnemy
	if enemy == null or enemy.died.is_connected(_on_enemy_died):
		return
	enemy.died.connect(_on_enemy_died.bind(enemy))


func _watch_weapons(root: Node) -> void:
	for child in root.get_children():
		if child is WeaponModule:
			_watch_weapon(child as WeaponModule)
		_watch_weapons(child)


func _watch_weapon(weapon: WeaponModule) -> void:
	if not weapon.enemy_defeated.is_connected(_on_weapon_kill):
		weapon.enemy_defeated.connect(_on_weapon_kill.bind(weapon))


func _on_enemy_died(enemy_id: StringName, _at: Vector2, enemy: BasicEnemy) -> void:
	if frozen:
		return
	var key: StringName = enemy_id
	if not kills.has(key):
		kills[key] = {
			"name": enemy.enemy_name if is_instance_valid(enemy) else String(enemy_id),
			"scene": enemy.scene_file_path if is_instance_valid(enemy) else "",
			"boss": is_instance_valid(enemy) and enemy.enemy_tier == BasicEnemy.EnemyTier.BOSS,
			"count": 0,
		}
	kills[key]["count"] = int(kills[key]["count"]) + 1


func _on_weapon_kill(_at: Vector2, _max_health: float, weapon: WeaponModule) -> void:
	if frozen or not is_instance_valid(weapon):
		return
	var id := weapon.weapon_type_id
	if id == &"":
		return
	weapon_kills[id] = int(weapon_kills.get(id, 0)) + 1


func _on_ore_added(amount: float, source: StringName) -> void:
	if frozen:
		return
	ore_by_source[source] = float(ore_by_source.get(source, 0.0)) + amount


func _on_artifact_granted(definition: MagicArtifactDefinition, _first: bool) -> void:
	if definition == null:
		return
	artifacts.append({
		"id": definition.artifact_id,
		"name": definition.display_name,
		"rarity": preload("res://Scripts/UI/Artifacts/ArtifactVisual.gd").rarity_index(definition),
	})
