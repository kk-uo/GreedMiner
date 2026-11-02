class_name DragonNestRules
extends RefCounted

## Authoritative V1 data shared by the encounter, developer tools, and tests.

const PLANET_ID: StringName = &"dragon_nest_planet"
const THEME_ID: StringName = &"dragon_nest"
const MAP_SEED: int = 13062026
const MAX_GREED: int = 15
const SCHEDULED_DRAGON_LIMIT: int = 2

## Claude sync 94: fodder (kobolds, lizards) about 3x denser; from Wave 5 the
## Young Dragons arrive as the two escorts every Greater Dragon brings
## (DragonEnemy spawns them; not in these quotas).
const WAVE_QUOTAS: Array[Dictionary] = [
	{&"kobold": 8, &"nest_lizard": 3, &"young_dragon": 0, &"greater_dragon": 0},
	{&"kobold": 8, &"nest_lizard": 4, &"young_dragon": 1, &"greater_dragon": 0},
	{&"kobold": 10, &"nest_lizard": 4, &"young_dragon": 1, &"greater_dragon": 0},
	{&"kobold": 9, &"nest_lizard": 5, &"young_dragon": 1, &"greater_dragon": 0},
	{&"kobold": 9, &"nest_lizard": 4, &"young_dragon": 0, &"greater_dragon": 1},
	{&"kobold": 10, &"nest_lizard": 5, &"young_dragon": 0, &"greater_dragon": 1},
	{&"kobold": 10, &"nest_lizard": 5, &"young_dragon": 0, &"greater_dragon": 1},
	{&"kobold": 10, &"nest_lizard": 5, &"young_dragon": 0, &"greater_dragon": 1},
	{&"kobold": 11, &"nest_lizard": 5, &"young_dragon": 0, &"greater_dragon": 1},
	{&"kobold": 12, &"nest_lizard": 6, &"young_dragon": 2, &"greater_dragon": 1},
]

const HOARDS: Array[Dictionary] = [
	{"id": &"small", "label": "SMALL HOARD", "reward": 100, "steals": 5, "guardian": &"young_dragon", "offset": Vector2(-430.0, -300.0), "pile": 80.0},
	{"id": &"medium", "label": "MEDIUM HOARD", "reward": 150, "steals": 5, "guardian": &"young_dragon", "offset": Vector2(-420.0, 330.0), "pile": 95.0},
	{"id": &"royal", "label": "ROYAL HOARD", "reward": 250, "steals": 5, "guardian": &"greater_dragon", "offset": Vector2(430.0, 300.0), "pile": 125.0},
]

## Fixed lair geometry, relative to the ship centre. The Ancient Dragon comes
## out of a tunnel in the left or right wall and stays there (half of its body
## inside the tunnel); BOSS_ANCHOR_X is where its body centre sits.
const GATE_X: float = 1080.0
const BOSS_ANCHOR_X: float = 850.0
## Guardians sleep coiled on a throne just behind their treasure mountain.
static func throne_offset(pile: float) -> float:
	return pile * 0.8
## Extra world width shown while the Ancient Dragon is on the field.
const BOSS_VIEW_EXTRA: float = 600.0


enum GreedTier { CALM, ALERT, FURIOUS, WRATH }


static func greed_tier(greed: int) -> GreedTier:
	if greed >= 11:
		return GreedTier.WRATH
	if greed >= 7:
		return GreedTier.FURIOUS
	if greed >= 3:
		return GreedTier.ALERT
	return GreedTier.CALM


static func greed_tier_name(greed: int) -> String:
	match greed_tier(greed):
		GreedTier.ALERT: return "ALERT"
		GreedTier.FURIOUS: return "FURIOUS"
		GreedTier.WRATH: return "DRAGON'S WRATH"
	return "CALM"


static func guardian_move_multiplier(greed: int) -> float:
	return 1.1 if greed_tier(greed) >= GreedTier.ALERT else 1.0


static func attack_interval_multiplier(greed: int) -> float:
	match greed_tier(greed):
		GreedTier.FURIOUS: return 0.9
		GreedTier.WRATH: return 0.8
	return 1.0


static func summon_profile(greed: int) -> Dictionary:
	if greed >= 11:
		return {"requested": 2, "cap": 2}
	if greed >= 7:
		return {"requested": 1, "cap": 2}
	return {"requested": 1, "cap": 1}


static func scheduled_total() -> int:
	var total := 0
	for quota in WAVE_QUOTAS:
		for count in quota.values():
			total += int(count)
	return total


static func treasure_reward_total() -> int:
	var total := 0
	for hoard in HOARDS:
		total += int(hoard["reward"]) * int(hoard["steals"])
	return total
