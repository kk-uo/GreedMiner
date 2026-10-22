# Module Magic Artifact Slots V2

The active chip gameplay and chip-facing UI have been retired. Weapon and
shield modules now expose three independent magic artifact slots in the hangar.

## Unlock Rules

- Research level 1-9: 0 artifact slots
- Research level 10-19: 1 artifact slot
- Research level 20-29: 2 artifact slots
- Research level 30: 3 artifact slots

The existing serialized research milestone field names are intentionally kept
for compatibility with old `.tres` resources and player saves. They are exposed
to new code through `ResearchManager.get_weapon_artifact_slot_count()` and
`ResearchManager.get_shield_artifact_slot_count()`.

## Runtime Interface

`ArtifactManager` owns collection and equipment state. UI code should use:

- `get_module_artifacts(cell)`
- `get_module_artifact(cell, slot_index)`
- `get_module_artifact_slot_count(cell)`
- `get_module_artifact_slot_unlock_level(cell, slot_index)`
- `equip_module_artifact(cell, artifact_id, slot_index)`
- `unequip_module_artifact(cell, slot_index)`

Each artifact remains globally unique and each installed module cell owns its
own three-slot array. Weapon and shield module slots are not shared by module
type. Battle effects are attached once per occupied slot and are removed when
the battle ends.

## Save Compatibility

Magic artifact save data is version 2. Version 1 stored one artifact string per
module cell; it is migrated to slot zero when that slot is unlocked and the
assignment is valid. Ownership is never removed when an old equipment assignment
cannot be restored. Legacy chip resources and their autoload remain dormant for
old-save parsing only; no active gameplay calculation or visible UI uses them.

## Presentation Boundary

The hangar currently uses the existing three socket area with functional
artifact icons, lock levels, selection, equip, and remove interactions. It can
be visually restyled later without changing `ArtifactManager` or research logic.
