class_name BattleStats
extends Node

## Per-battle tallies for the result board: kills per enemy type, the boss,
## kills credited to each weapon, ore by source and the battle time.
## Presentation data only - nothing is saved and no rule reads it.
## BattleMain adds one per battle and calls freeze() when the battle ends.

## Ore sources passed to ResourceManager.add_mission_ore(amount, source).
const SOURCE_ORDER: Array[StringName] = [&"drill", &"dwarf", &"crystal", &"qte", &"chest", &"treasure", &"tree", &"bounty", &"other"]
const SOURCE_NAMES := {
	&"drill": "Drilling",
	&"dwarf": "Dwarf Mining",
	&"crystal": "Crystals",
	&"qte": "Mining Events",
	&"chest": "Salvage Chests",
	&"treasure": "Stolen Treasure",
	&"tree": "Logging",
	&"bounty": "Bounties",
	&"other": "Other",
}

## enemy_id -> {"name", "scene", "boss", "count"} in first-kill order.
var kills: Dictionary = {}
## weapon_type_id -> kills credited to that weapon type.
var weapon_kills: Dictionary = {}
## One entry per installed weapon (turret) instance: instance_id ->
## {"id": weapon_type_id, "cell": Vector2i, "damage": float, "kills": int}.
## Cells are looked up on the ship (refresh_turret_cells, done at freeze).
var turret_damage: Dictionary = {}
var _turret_refs: Dictionary = {}
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
	refresh_turret_cells()
	frozen = true


func total_turret_damage() -> float:
	var total := 0.0
	for entry in turret_damage.values():
		total += float(entry["damage"])
	return total


## Turret rows for the result board, most damage first (ties: more kills,
## then ship cell order). Turrets that dealt no damage are listed too.
func turret_rows() -> Array[Dictionary]:
	if not frozen:
		refresh_turret_cells()
	var rows: Array[Dictionary] = []
	for key in turret_damage.keys():
		var entry: Dictionary = turret_damage[key].duplicate()
		if entry["id"] == &"":
			continue
		rows.append(entry)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["damage"]), float(b["damage"])):
			return float(a["damage"]) > float(b["damage"])
		if int(a["kills"]) != int(b["kills"]):
			return int(a["kills"]) > int(b["kills"])
		var ca: Vector2i = a["cell"]
		var cb: Vector2i = b["cell"]
		return ca.x < cb.x or (ca.x == cb.x and ca.y < cb.y))
	return rows


## Records which ship cell each tracked turret sits in (while it still exists).
func refresh_turret_cells() -> void:
	for key in _turret_refs.keys():
		var weapon: Object = (_turret_refs[key] as WeakRef).get_ref()
		if weapon == null or not is_instance_valid(weapon):
			continue
		var cell := _ship_cell_of(weapon as WeaponModule)
		if cell.x >= 0:
			turret_damage[key]["cell"] = cell
		turret_damage[key]["id"] = (weapon as WeaponModule).weapon_type_id


func _ship_cell_of(weapon: WeaponModule) -> Vector2i:
	var node: Node = weapon.get_parent()
	while node != null and not node is Ship:
		node = node.get_parent()
	var ship := node as Ship
	if ship == null:
		return Vector2i(-1, -1)
	for cell in ShipLoadout.get_all_cells():
		if ship.get_module_at(cell.x, cell.y) == weapon:
			return cell
	return Vector2i(-1, -1)


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
	if not weapon.damage_dealt.is_connected(_on_weapon_damage):
		weapon.damage_dealt.connect(_on_weapon_damage.bind(weapon))
	_turret_entry(weapon)


## Only weapons mounted on a ship count as turrets (not base or test props).
func _turret_entry(weapon: WeaponModule) -> Dictionary:
	var key := weapon.get_instance_id()
	if not turret_damage.has(key):
		var node: Node = weapon.get_parent()
		while node != null and not node is Ship:
			node = node.get_parent()
		if node == null and weapon.is_inside_tree():
			return {}
		turret_damage[key] = {"id": weapon.weapon_type_id, "cell": Vector2i(-1, -1), "damage": 0.0, "kills": 0}
		_turret_refs[key] = weakref(weapon)
	return turret_damage[key]


func _on_weapon_damage(amount: float, weapon: WeaponModule) -> void:
	if frozen or not is_instance_valid(weapon):
		return
	var entry := _turret_entry(weapon)
	if not entry.is_empty():
		entry["damage"] = float(entry["damage"]) + amount


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
	var entry := _turret_entry(weapon)
	if not entry.is_empty():
		entry["kills"] = int(entry["kills"]) + 1


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
