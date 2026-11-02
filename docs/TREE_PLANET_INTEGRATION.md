# Tree Planet integration notes

Tree Planet is a playable forest expedition (`tree_planet`) with twelve waves. The
current wave quotas in `Resources/Waves/TreePlanetWaves.tres` are provisional
balance defaults because final counts were not specified. Each wave releases
its scheduled enemies together and the next wave begins as soon as the field
is clear, with no inter-wave timer. Godot Inspector can edit the quotas.

## Editable gameplay data

- `Resources/Forest/ForestPlanetSettings.tres`: clearing radius, sparse ring,
  tree spacing/count, final canopy wave, rainstorm interval, warning and
  duration. Storm regrowth stays visible; treant instantiation is capped per
  frame to limit stalls without a blackout.
- `Scenes/Enemies/fairy.tscn`, `treant.tscn`, `big_treant.tscn`, and
  `chainsaw_spaceship_treant.tscn`: enemy health, speed, attack values and
  forest-specific exports. The boss scene also exposes saw timing and lure
  range. Projectile scenes expose their own speed and damage settings.
- `Resources/Waves/TreePlanetWaves.tres`: scheduled enemies and wave timing.
  Storm-regrown trees rise in addition to, not instead of, these quotas.

## Tree / spot / storm loop (user design, Claude 2026-10-22)

- Every tree on the map is a `ForestTree` (about 3,600 with the default
  `tree_spacing` 46). A scheduled treant tears itself out of a standing tree
  (`take_spawn_tree()` prefers trees within `spawn_view_radius` of the map
  centre) and the tree becomes an empty SPOT (`uprooted`).
- A rainstorm regrows a tree on every used, uncut spot (`ForestTree.regrow()`),
  with a short stagger so the return remains visible. The next wave uproots
  ALL standing regrown trees from
  earlier waves in addition to its fixed new-tree quota. The 12th wave
  uproots every standing tree overlapping the visible screen and summons the
  Chainsaw Spaceship Treant boss. Trees permanently felled by dwarves stay off.
- Dwarves can dig out a standing tree or a spot (`chop()`); it never regrows.
- Trees are drawn in baked chunks by `ForestTreeChunks` (re-baked per chunk
  on `state_changed`); `ForestCanopyLayer` is only the static floor / rim.

## Presentation hooks

- `ForestTerrain.trees` contains `ForestTree` nodes. Each tree has `chopped`,
  `has_spawned_treant`, `spawned_enemy_id`, `dig_progress`, and a `felled(tree)` signal. A felled
  tree remains a closed spawn point for the entire expedition.
- `ForestStormController` emits `storm_warning(seconds_until_storm)`,
  `storm_started(respawned)`, `respawns_finished`, and `storm_ended`.
  `start_storm()` returns the count of regrowing trees; no enemies spawn at
  storm start. `ForestRingRaise.raised_by_wave` reports reserved tree emergence,
  including the extra storm-returned trees. Rain and text are functional
  placeholders that can be replaced without changing wave logic.
- `ForestEnemy.committed_to_attack` becomes permanently true when a fairy
  reaches ship attack range. Fairies heal only before that transition.
- `ForestBoss` locks its saw direction at windup start. It prioritizes dwarves
  currently chopping a tree or the escape root inside `dwarf_lure_range`.
- `ForestRoot.felled` releases the boss escape lock. The evacuation panel uses
  `set_external_lock(bool)` and `reset_attempt()` for this interaction.
- `StrandedDwarfMarker` is presentation only; it does not affect progression
  or future dwarf availability.

The tree, rain, fairy, boss, saw, root and stranded-dwarf drawings are basic
placeholders. Final art, animations, VFX and polished UI remain separate from
these gameplay interfaces.

## Performance note

Each post-storm wave may raise one additional enemy at every regenerated,
uncut tree spawn point, besides the scheduled quota. Chopping trees reduces
future load; the storm interval can be tuned in `ForestPlanetSettings.tres` if
playtests show too many concurrent enemies. Final-wave emergence is limited to
the visible screen, and `maximum_ring_raises_per_frame` spreads the cost over
frames. Forest enemies now redraw only for hit flash
or emergence, and repetitive combat/ore console logging is disabled by
default through opt-in debug properties.

Enemies keep their target collision layer and remain monitorable, but do not
monitor other areas themselves. Machine-gun and cannon projectiles use layer 0,
mask 1; enemy projectiles keep their existing ship mask. This retains physics
hits and removes enemy/enemy and projectile/projectile overlap bookkeeping.

`WeaponModule.target_search_interval` and
`BasicEnemy.mining_target_search_interval` default to 0.2 seconds. First
acquisition is immediate, later group scans are staggered, and valid targets
remain tracked each frame. Fairy healing keeps its one-second interval with a
small initial phase offset. `WaveManager.set_pending_external_spawns(source,
count)` reserves queued extra spawns without changing scheduled wave quotas.
