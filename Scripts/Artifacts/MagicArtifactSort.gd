extends RefCounted

## Shared default order for the hangar picker and Magic Stall collection.
## Higher rarity first, then Boss -> world -> mining chest -> shop; ties are
## deterministic so the list does not jump after equipping or reopening.
const RARITY_ORDER: Array[String] = ["COMMON", "RARE", "EPIC", "LEGENDARY"]


static func less_by_rarity_and_source(a: MagicArtifactDefinition, b: MagicArtifactDefinition) -> bool:
	if a == b:
		return false
	if a == null:
		return false
	if b == null:
		return true
	var a_rarity := maxi(RARITY_ORDER.find(a.rarity.strip_edges().to_upper()), 0)
	var b_rarity := maxi(RARITY_ORDER.find(b.rarity.strip_edges().to_upper()), 0)
	if a_rarity != b_rarity:
		return a_rarity > b_rarity
	var a_method := a.get_acquisition_method()
	var b_method := b.get_acquisition_method()
	if a_method != b_method:
		return a_method < b_method
	var a_planet := String(a.source_planet_id)
	var b_planet := String(b.source_planet_id)
	if a_planet != b_planet:
		return a_planet < b_planet
	return String(a.artifact_id) < String(b.artifact_id)
