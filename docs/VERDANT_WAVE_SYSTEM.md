# Verdant Planet Wave System

The authoritative data is `res://Resources/Waves/VerdantPlanetWaves.tres`.
Waves 1-10 contain exact fixed quotas (3x plan, 534 enemies in total). Wave 10 is
the ARMY wave. Wave 11 spawns one Goblin Giant Chariot boss plus 10 Goblin escorts.

| Wave | Goblin | Hunter | Elite | Engineer | Total |
|---|---|---|---|---|---|
| 1 | 18 | 0 | 0 | 0 | 18 |
| 2 | 29 | 0 | 0 | 1 | 30 |
| 3 | 30 | 6 | 2 | 1 | 39 |
| 4 | 33 | 8 | 3 | 1 | 45 |
| 5 | 32 | 10 | 5 | 1 | 48 |
| 6 | 34 | 12 | 7 | 1 | 54 |
| 7 | 37 | 15 | 10 | 1 | 63 |
| 8 | 38 | 17 | 12 | 2 | 69 |
| 9 | 39 | 20 | 17 | 2 | 78 |
| 10 | 48 | 20 | 20 | 2 | 90 |
| 11 | 10 + Goblin Giant Chariot ×1 | 0 | 0 | 0 | 11 |

Goblin Engineers (spawn cost 3) replace 1 in every 20 Goblins of a wave
(rounded down), so wave totals are unchanged; each one adds 2 to the wave
budget. Rocky Planet does the same with Red Rocks: 1 in every 10 Little Rocks
on waves 2–9 (wave 1 and the Titan wave stay as they were).

## Runtime interfaces

- `WaveSpawnPlanner.build_plan(wave, rules, rng)` validates quotas and budget
  before returning executable requests.
- `WaveDefinition.get_total_spawn_budget()` derives the shared budget from
  each `EnemySpawnEntry.spawn_count * spawn_cost`.
- `WaveDefinition.get_spawn_batch_size()` keeps high-count Verdant waves inside
  their explicit spawn-phase duration. Legacy Rocky waves keep batch spawning
  disabled and retain one-enemy-per-interval behavior.
- `WaveManager.get_scheduled_spawn_budget()` and `get_spent_spawn_budget()`
  expose planned and consumed budget for tests/debugging.
- `WaveManager.get_last_special_events()` reports the selected special events.
- `WaveManager.wave_configuration_blocked` announces a deliberately incomplete
  wave without completing or skipping the planet.

The Goblin Pack rule (pattern `FORMATION`) reorganizes 6-10 Goblins already
present in a fixed quota into one organized block. It never adds quota or
budget. `EnemySpawner.spawn_formation()` places the block just off-screen on one
random cardinal side, front row facing the ship, with `formation_spacing`
(30) between units so nothing overlaps. Layouts are data in
`Scripts/Waves/SpawnFormation.gd` (`PRESETS`, rows of `G` / `F` / `.`, front row
first), e.g. 9 = `GGG / GFG / GGG`. `F` is the flag bearer: a normal Goblin with
`is_flag_bearer = true`, which only adds a banner (drawn on top). After spawning,
every unit uses normal goblin AI. The legacy `CLUSTER` pattern still exists.

## Goblin Giant Chariot (wave 11 boss)

`Scenes/Enemies/goblin_giant_chariot.tscn` / `Scripts/Enemies/GoblinGiantChariot.gd`.
HP 3500, speed 10, contact damage 50, 20 % damage reduction, boss tier, 500 ore.
All tuning values are Inspector exports on the scene:

| Export | Default | Meaning |
|---|---|---|
| `throw_goblin_count` | 10 | Goblins per throw (released all at once, plus `throw_elite_count` = 1 Elite) |
| `throw_distance` | 250 | Landing distance ahead of the boars' snouts |
| `thrown_goblin_root_duration` | 2.0 | Seconds the landed goblins stay in place |
| `throw_cooldown` | 8.0 | Built-in cooldown, counted after the pause ends |
| `first_throw_delay` | 4.0 | Delay before the first throw |
| `throw_animation_duration` | 4.0 | Throw animation; the chariot stands still |
| `throw_release_fraction` | 0.75 | Release point (wind up ~3 s, then all 5 fly) |
| `post_throw_pause` | 2.0 | Stationary pause after the throw |
| `berserk_trigger_distance` | 200 | Distance from the rig's front to the ship hull that triggers berserk |
| `berserk_speed_multiplier` | 2.0 | Speed 10 → 20 |
| `death_spawn_count` / `death_spawn_radius` | 10 / 80 | Goblins released on death |

Look: two armoured war boars pull a goblin catapult wagon (chieftain on the
reins, goblin ammo cage at the back). The rig is long, so contact, landing and
berserk are measured from its front (`FRONT_REACH` = 138 ahead of the node
origin), not from the centre. States: `ADVANCE` → `THROWING` → `PAUSED` →
`ADVANCE`…; `BERSERK` is entered once, when the front is ≤ 200 from the hull. After that it never throws again. Thrown goblins fly in an arc
(`Goblin.throw_to`), land in a small block (`SpawnFormation`, 5 = `GGG / GG`)
and are rooted (`Goblin.root_for`) for 2 s after landing. On death, 10 goblins
appear in an even ring and act immediately. Signals: `throw_started`,
`goblins_thrown(goblins)`, `berserk_started`. Drawn by `GoblinVisual.draw_chariot` (design: concept A + B, boars + catapult).

## Manual testing

Open `res://Tests/Manual/VerdantWaveManualTest.tscn`. Select its root node and
set `Wave Number To Test` to any value from 1 through 10, then run the scene.
This launcher injects only the chosen Verdant wave into a normal BattleMain.
Testing Wave 10 also appends the pending Wave 11 so the development block can be
verified without reporting planet completion.

## Tests

`Tests/VerdantWaveSystemTest.tscn`: quotas, budgets, pack formation from every
cardinal side, one flag bearer, spacing, and wave 11 spawning the chariot.
`Tests/VerdantEnemyTest.tscn`: goblin stats and rewards. `Tests/GoblinChariotTest.tscn`:
boss stats and exports, 10 per throw, landing ahead, 2 s root, standing still while
throwing and pausing, cooldown, berserk (once, ×2), 10 goblins on death, 500 ore.
