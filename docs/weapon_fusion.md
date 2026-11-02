# Weapon Fusion V1

Weapon fusion is available after Graveyard Planet is completed and all five
base weapon research tracks reach level 30. Developer Mode may also persist a
test-only override in the `weapon_fusion` progression section; it does not
forge a planet clear or alter any research level.

## Gameplay API

- `WeaponFusionRegistry.find_recipe(first_id, second_id)` returns a recipe in
  either ingredient order, or an empty dictionary.
- `WeaponFusionRegistry.is_unlocked()` is the authoritative progression guard.
- `Ship.fuse_modules(source_cell, target_cell, result_scene)` atomically
  consumes two installed modules and creates the result in the target cell.
- `ShipLoadout.fuse_cells(...)` persists the scene path and emits both cell
  changes so instance-local artifact assignments are safely released.

Dragging an installed module moves its actual scene node under the cursor;
the module is not replaced by a UI icon. The loadout assignment stays in its
source cell until release. Cancelling returns the node to its original cell;
overlapping a compatible module starts the one-second fusion timer with the
dragged turret positioned over its target.

Heavy Laser is forged from `dwarf_cannon + laser`. Its beam
width is 60 px, ten times the base Laser's 6 px, for both collision and visual
drawing. Demon Prism can equip to Laser and inherited laser fusion modules and
doubles their beam width without changing targeting distance.
The shared duration is `WeaponFusionRegistry.FUSION_DURATION_SECONDS`, copied
into each recipe's `duration` field for the base-scene progress indicator.

Fusion results are registered in `ModuleCatalog` with `fusion_only = true`.
They can be restored from a save and inspected in the loadout panel, but are
not offered as directly installable catalog cards. Every fusion result has an
exported power cost equal to the sum of its two ingredients plus one extra
Power (3 or 4 Power in the current recipe list). The normal ship energy
profile validates that cost before a fusion completes. Each result has an
independent Level 1-30 damage research track and unlocks its own three artifact
slots at Levels 10, 20, and 30. These projects live on the Laboratory's separate
**Fusion Weapons** page, leaving the base Weapons page focused on ingredients.
`artifact_compatibility_ids` still lists both
source module types so compatible artifacts continue to work.

Knockback Laser (`knockback_module` + `laser`) uses `FusionWeapon.AttackKind.WAVE`.
The travelling `FusionKnockbackWave` deals 15 impact damage once per enemy,
pushes every non-boss enemy touching the wave 20 px, then deals 1 damage per second to each hit
enemy until that wave expires. The 100 px wavefront length is stored as the
scene's `projectile_range` and remains independent from `attack_range`.
The wave fires every 5 seconds. Knockback Machine Gun fires every 0.4 seconds;
each bullet pushes at most one non-boss enemy 20 px, even if an artifact lets
that bullet pierce and damage further targets. Impact damage, damage-over-time, movement speed, thickness, and attack cadence
are exported on `knockback_laser.tscn` for tuning. Only the initial impact emits
`WeaponModule.projectile_hit`; later ticks cannot trigger hit-count artifacts.

Flame Laser (`flamethrower` + `laser`) is a non-piercing, single-target beam.
Its 600 px targeting range, 1 base damage, 0.1 s tick interval, 1.0 s
doubling interval, and 256 maximum damage per tick are exported in
`flame_laser.tscn`. Ten successful ticks on the same locked enemy double the
next tick; the ten-tick interval accelerates with fire-rate modifiers. A new
target resets the ramp, and every newly exposed Ancient Dragon health segment
also restarts it at base damage. Research and module artifacts modify the initial
base damage through `WeaponModule.get_damage()` before ramping, and the 256
cap applies to each outgoing hit. The beam does not emit projectile-hit events.

## Ground and flying targets

Weapons have two targeting modes: `GROUND_ONLY` and `GROUND_AND_AIR`. There is
no air-only mode. Dwarf Cannon, Flamethrower, Chainsaw, and the standalone
Knockback module affect ground enemies only. Machine Gun and Laser can attack
both movement layers.

Fusion results keep these authored rules:

- Ground only: Automatic Cannon (Machine Gun + Cannon), Flame Cannon,
  Flame Machine Gun, Sawblade Machine Gun, Knockback Cannon, and Knockback
  Machine Gun.
- Ground and air: Siege Cannon (Cannon + Cannon), Scatter Machine Gun, and all
  Laser combinations: Laser Machine Gun, Laser Chainsaw, Heavy Laser,
  Knockback Laser, and Flame Laser.

The restriction is enforced during target acquisition and again on projectile,
beam, melee, explosion, persistent-fire, and travelling-wave damage. A
ground-only projectile therefore passes through a flying enemy instead of
detonating on it.

## Presentation extension points

`FusionProgressIndicator` is intentionally a minimal functional progress bar.
`FusionWeapon`, `FusionTurretVisual`, `FusionProjectile`, `FusionKnockbackWave`, and
`FusionFirePatch` contain placeholder procedural art that can be replaced by
Claude Code without changing recipes, combat values, persistence, or the
fusion transaction.
