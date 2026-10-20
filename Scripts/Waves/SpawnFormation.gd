class_name SpawnFormation
extends RefCounted

## Data-driven block formations for group spawns (Goblin Pack, Chariot throws).
##
## A layout is a list of rows, front row (closest to the ship) first:
##   "G" = ordinary unit, "F" = flag bearer, "." = empty spot.
## Add or change a layout by editing PRESETS (keyed by unit count). Counts
## without a preset get an automatic near-square block.

const PRESETS: Dictionary = {
	5: ["GGG", "GG"],
	6: ["GGG", "GFG"],
	7: ["GGGG", "GFG"],
	8: ["GGGG", "GFGG"],
	9: ["GGG", "GFG", "GGG"],
	10: ["GGGGG", "GGFGG"],
	12: ["GGGG", "GFGG", "GGGG"],
}


## Rows for count units (preset or generated). with_flag: generated layouts
## put a flag bearer in the middle of the second row.
static func get_rows(count: int, with_flag: bool = true) -> PackedStringArray:
	var rows := PackedStringArray()
	if PRESETS.has(count):
		for row in PRESETS[count]:
			rows.append(String(row) if with_flag else String(row).replace("F", "G"))
		return rows
	var width: int = maxi(ceili(sqrt(float(count))), 1)
	var left: int = count
	while left > 0:
		var take: int = mini(width, left)
		rows.append("G".repeat(take))
		left -= take
	if with_flag and rows.size() > 0:
		var row_index: int = mini(1, rows.size() - 1)
		var row := rows[row_index]
		var middle: int = row.length() / 2
		rows[row_index] = row.substr(0, middle) + "F" + row.substr(middle + 1)
	return rows


## Unit slots as [{lateral: float, depth: float, flag: bool}], centred on the
## block. lateral runs along the front line, depth grows away from the front.
static func get_slots(count: int, spacing: float, with_flag: bool = true) -> Array[Dictionary]:
	var rows := get_rows(count, with_flag)
	var slots: Array[Dictionary] = []
	var depth_center: float = float(rows.size() - 1) * spacing * 0.5
	for row_index in range(rows.size()):
		var row: String = rows[row_index]
		var row_center: float = float(row.length() - 1) * spacing * 0.5
		for column in range(row.length()):
			var mark := row[column]
			if mark == ".":
				continue
			slots.append({
				"lateral": float(column) * spacing - row_center,
				"depth": float(row_index) * spacing - depth_center,
				"flag": mark == "F",
			})
	return slots


## World positions for a block whose front faces `forward`, centred on center.
static func place(center: Vector2, forward: Vector2, count: int, spacing: float, with_flag: bool = true) -> Array[Dictionary]:
	var front := forward.normalized() if forward.length_squared() > 0.0 else Vector2.RIGHT
	var side := Vector2(-front.y, front.x)
	var result: Array[Dictionary] = []
	for slot in get_slots(count, spacing, with_flag):
		result.append({
			"position": center + side * float(slot["lateral"]) - front * float(slot["depth"]),
			"flag": bool(slot["flag"]),
		})
	return result
