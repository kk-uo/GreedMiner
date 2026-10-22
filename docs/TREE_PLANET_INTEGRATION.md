# Tree Planet integration notes

Tree Planet is a playable forest expedition (`tree_planet`) with ten waves. The
current wave quotas in `Resources/Waves/TreePlanetWaves.tres` are provisional
balance defaults because final counts were not specified. Godot Inspector can
edit the quotas and timing without changing scripts.

## Editable gameplay data

- `Resources/Forest/ForestPlanetSettings.tres`: clearing radius, sparse ring,
  tree spacing/count, rainstorm interval, warning and duration. Storm enemies
  are paced with `respawn_spread_duration` (0.8 seconds) and
  `maximum_respawns_per_frame` (4 requests); a slow frame never spawns the
  entire remaining queue at once.
- `Scenes/Enemies/fairy.tscn`, `treant.tscn`, `big_treant.tscn`, and
  `chainsaw_spaceship_treant.tscn`: enemy health, speed, attack values and
  forest-specific exports. The boss scene also exposes saw timing and lure
  range. Projectile scenes expose their own speed and damage settings.
- `Resources/Waves/TreePlanetWaves.tres`: scheduled enemies and wave timing.
  Storm respawns are extra and do not consume these quotas.

## Tree / spot / storm loop (user design, Claude 2026-10-22)

- Every tree on the map is a `ForestTree` (about 3,600 with the default
  `tree_spacing` 46). A scheduled treant tears itself out of a standing tree
  (`take_spawn_tree()` prefers trees within `spawn_view_radius` of the map
  centre) and the tree becomes an empty SPOT (`uprooted`).
- A rainstorm regrows a tree on every spot (`ForestTree.regrow()`, animated
  over ~1.2 s); storms spawn NO enemies any more. The next waves can uproot
  the regrown trees again.
- Dwarves can dig out a standing tree or a spot (`chop()`); it never regrows.
- Trees are drawn in baked chunks by `ForestTreeChunks` (re-baked per chunk
  on `state_changed`); `ForestCanopyLayer` is only the static floor / rim.

## Presentation hooks

- `ForestTerrain.trees` contains `ForestTree` nodes. Each tree has `chopped`,
  `has_spawned_treant`, `spawned_enemy_id`, `dig_progress`, and a `felled(tree)` signal. A felled
  tree remains a closed spawn point for the entire expedition.
- `ForestStormController` emits `storm_warning(seconds_until_storm)`,
  `storm_started(respawned)`, `respawns_finished`, and `storm_ended`.
  `start_storm()` returns the queued count; the `storm_started` count is also
  the planned count, while `total_storm_respawns` counts actual spawns.
  `get_pending_respawn_count()` exposes the remaining work. Every previously
  used, still-standing tree point is queued, and a point cut before its turn
  is skipped. Its rain and text are
  functional placeholders that can be replaced without changing wave logic.
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

Each storm intentionally creates one additional enemy at every used, uncut
tree spawn point. These enemies do not replace existing living enemies and
there is no storm-spawn cap. Chopping trees reduces future storm load; the
storm interval can be tuned in `ForestPlanetSettings.tres` if later playtests
show too many concurrent enemies. Forest enemies now redraw only for hit flash
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
