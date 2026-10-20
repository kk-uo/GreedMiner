# GreedMiner Project Structure

GreedMiner uses a feature-based layout. Scenes and scripts remain in separate
top-level directories, while matching feature names make related files easy to
find. Gameplay behavior is implemented in GDScript and the project targets the
Godot Standard editor and Web export.

## Major directories

- `Scenes/Base/` — the asteroid-hold base: overview (hangar pad + star map) and the zoomed-in ship assembly view.
- `Scenes/Battle/` — active mission scene.
- `Scenes/PlanetSelection/` — destination carousel and deployment screen.
- `Scenes/Ship/` — reusable ship scene and its 3×3 module grid.
- `Scenes/Modules/` — installable module scenes, grouped by module category and
  concrete weapon.
- `Scenes/Enemies/` — reusable enemy scenes.
- `Scripts/Core/` — persistent global resource state and shared drawing palette.
- `Scripts/Base/`, `Scripts/Battle/`, and `Scripts/PlanetSelection/` — controllers
  for the three main game states.
- `Scripts/Ship/` — ship grid behavior and the persistent loadout Autoload.
- `Scripts/Modules/` — shared module behavior and concrete module scripts.
- `Scripts/Enemies/` — enemy behavior and the enemy scene catalog.
- `Scripts/UI/` — reusable HUD scaling and evacuation controls; `Scripts/UI/Loadout/` holds the base loadout panel (module catalog, live module icons, list/detail views).
- `Scripts/VFX/` — shared lightweight visual effects.
- `Resources/UI/` — project-wide Godot UI theme resources.
- `Assets/Fonts/` — font files and their license.
- `docs/` — design and art-direction documentation.
- `tools/` — local development utilities excluded from Godot imports.

Generated exports belong in `build/` and are intentionally ignored by Git.
Local `_art_backup_*` snapshots remain on disk but are not active project files
and are also ignored by Git. Superseded generated builds are preserved locally
under `Archived/LegacyWebExport/`, which Godot and Git both ignore.

## Adding gameplay content

### Weapons

Put each weapon in a matching subdirectory under both:

- `Scenes/Modules/Weapons/<WeaponName>/`
- `Scripts/Modules/Weapons/<WeaponName>/`

Weapons inherit the shared `WeaponModule` class in
`Scripts/Modules/Weapons/WeaponModule.gd`. Keep projectile scenes and scripts
beside their owning weapon. Add the weapon scene to the Base module-selection
data or controller only when it becomes installable.

Example for a future PlasmaCannon:

```text
Scenes/Modules/Weapons/PlasmaCannon/plasma_cannon.tscn
Scenes/Modules/Weapons/PlasmaCannon/plasma_cannon_projectile.tscn
Scripts/Modules/Weapons/PlasmaCannon/PlasmaCannon.gd
Scripts/Modules/Weapons/PlasmaCannon/PlasmaCannonProjectile.gd
```

### Other module categories

- Mining modules: `Scenes/Modules/Mining/` and `Scripts/Modules/Mining/`
- Shield modules: create `Scenes/Modules/Shield/` and `Scripts/Modules/Shield/`
  when the first shield module is implemented.
- Energy modules: create matching `Modules/Energy/` directories when needed.
- Cargo modules: create matching `Modules/Cargo/` directories when needed.
- Support modules: create matching `Modules/Support/` directories when needed.

Empty placeholder implementations and empty category directories are avoided.
All concrete modules remain ordinary reusable scenes so multiple instances can
be installed in different ship cells.

### Enemies and planets

- Add enemy scenes to `Scenes/Enemies/` and scripts to `Scripts/Enemies/`.
  Register spawnable enemy IDs in `Scripts/Enemies/EnemyCatalog.gd`.
- Add planet-selection presentation and data to
  `Scripts/PlanetSelection/PlanetSelect.gd`. New planet-specific battle content
  can be split into its own scene/resource later when it has gameplay behavior.

## Shared systems

- `ShipLoadout` Autoload: `Scripts/Ship/ShipLoadout.gd`
- `ResourceManager` Autoload: `Scripts/Core/ResourceManager.gd`
- Shared visual palette: `Scripts/Core/Palette.gd`
- Shared UI theme: `Resources/UI/greedminer_theme.tres`

Autoloads are registered by their explicit feature paths in `project.godot`.
There is only one instance of each global manager.

## Scene flow

```text
Scenes/Base/base_main.tscn
    -> Scenes/PlanetSelection/planet_select.tscn
    -> Scenes/Battle/BattleMain.tscn
    -> evacuation success returns to Base
```

The Base and Battle scenes both instance `Scenes/Ship/ship.tscn`. Installed
modules are preserved by `ShipLoadout`; mission and stored ore are owned by
`ResourceManager`.

## Audit notes

- `Scenes/Enemies/basic_enemy.tscn` currently duplicates the Little Rock setup
  and is not used by `EnemyCatalog`. It is retained as a compatibility/manual
  test scene because this refactor does not delete files.
- The project currently defines no custom input actions in `project.godot`.
- The former root-level `greedminer.*` Web runtime files are preserved under
  `Archived/LegacyWebExport/`; they are generated artifacts, not dependencies.

## Ship presentation (visual only)

- `Scripts/Ship/ShipHullVisual.gd` builds the hull ("forged anvil" style) from
  `Ship.get_hull_cells()`. The outline, chamfers, rune studs and thruster pods
  are generated from the cell set, so irregular grid expansion only needs
  `Ship._rebuild_hull()` to see the new cells.
- `Ship.visual_altitude` (0 = landed) and `Ship.thruster_power` (0..1) are
  presentation-only properties; they never affect gameplay.
- `Scripts/Ship/ShipLaunchController.gd` plays landing/take-off
  (`play_landing()`, `play_takeoff()`, both awaitable; `sequence_finished`).
  BattleMain lands on start and takes off after evacuation; the base lands on
  arrival when `ShipLaunchController.landing_pending_at_base` is set.
- `Scripts/VFX/ThrusterFX.gd` draws the hexagonal fire/smoke puffs under the
  nozzles, driven by `Ship.thruster_power`.

## Base buildings (visual only)

- `Scripts/Base/ResearchLab.gd` draws the research lab (top-left of the hold)
  with animated roof details; `Scripts/Base/LabScientist.gd` is the idling
  dwarf scientist at its door.
- `AsteroidHangar.HOTSPOT_LAB` is the lab's hotspot. BaseMain currently shows
  a "coming soon" toast on click; hook the future lab UI there.

## Stone enemies (visual only)

- `Scripts/Enemies/StoneVisual.gd` (`class_name StoneVisual`): code-drawn grey stone bodies with purple eyes for Rock Golem and Little Rock. Two variants, `Variant.BOULDER` (big fists, purple crack) and `Variant.CRYSTAL` (boulder pile with a purple crystal cluster). Walk cycle, attack slam / lunge pose and dust are presentation only.
- Golem and Titan fists are angular blocks (`StoneVisual._block_fist` / `_slab_fist`). Their walk uses `StoneVisual.heavy_swing(time, cycles_per_second)`: each fist swings slowly over, then is planted and held for a beat (golem 0.45 cycles/s, titan 0.26 cycles/s; the titan's footfall dust and camera bump fire when a fist is planted).
- `RockGolem.visual_variant` / `LittleRock.visual_variant` (`-1` = random on spawn). A golem's two split Little Rocks inherit its variant.
- Both enemies override `_on_attack_timer_timeout()` only to call `super()` and start the attack pose; damage logic is unchanged.
- Colors: `Palette.STONE_*`, `Palette.ENEMY_EYE*`, `Palette.STONE_DUST`. `Palette.ENEMY` / `ENEMY_LIGHT` now alias the stone tones (death-burst shards are grey). `Palette.THREAT` stays red for danger UI.
- Rock Titan boss visual ("mountain colossus", design canvas concept 1): `StoneVisual.draw_titan(canvas, facing, swing, slam, flash, time)`, drawn at `TITAN_DRAW_SCALE` 1.5 (about 1.6x the 3x3 ship width), `TITAN_VISUAL_RADIUS` 165 px.

## Rock Titan boss

- `Scenes/Enemies/rock_titan.tscn` + `Scripts/Enemies/RockTitan.gd` (`class_name RockTitan`, id `&"rock_titan"`, registered in `EnemyCatalog`). Stats from the enemy table: HP 1000, speed 10, contact damage 20, attack interval 1, attack range 10, damage reduction 0, melee, tier `BOSS`.
- `BasicEnemy.EnemyTier.BOSS` was appended (existing values unchanged).
- Attack range is measured from the titan's fists: `body_reach` (130) is added to `attack_range` on spawn so the body never walks over the ship. Collision radius 130.
- Death: releases `split_count` (4) Rock Golems in a ring of `split_radius` (70) around the death position, each with a random look.
- Presentation: slow walk with a light camera bump per step, two-fist slam with shockwave + heavy camera shake on every attack, bigger shake on death. Shakes tween `Ship.world_camera.offset` and restore it.
- Spawning: `enemy_spawner.gd` now counts waves (`get_wave()`; the first batch is wave 1, each `SpawnTimer` tick is one more wave, every 2 s). `boss_enemy_id` (`&"rock_titan"`) spawns once on `boss_spawn_wave` (10), on top of the normal batch; `boss_spawn_wave = 0` disables it. Spawn weights / per-enemy start waves from the table are not implemented yet; little rock and golem still alternate as before.
- UI: `Scripts/UI/BossHealthBar.gd` (`BattleUI/UIRoot/BossHealthBar` in BattleMain), design B "crystal segments": a hex stone portrait, the name plus a subtitle (`SUBTITLES` by enemy_id), "current / max" health, and 20 purple crystal cells. Cells fill in when the boss appears. Lost health turns pale first and drains after 0.45 s, and each emptied cell shatters into shards. The bar shows while any `BOSS` tier enemy is alive and fades out after it dies.
- VFX: `Scripts/VFX/StoneDust.gd` (`StoneDust.spawn(parent, world_pos, count, size, speed, life, direction, spread)`, ground-layer hex dust, z -50) for footfalls, the walking trail and slams; `Scripts/VFX/TitanCollapse.gd` (`TitanCollapse.spawn(parent, world_pos, radius)`) on death: purple flash + shock ring, crystal shards, thrown boulders that bounce and fade, a big dust cloud, and a crater with purple fissures that lingers ~7 s. Both are presentation only and free themselves. The collapse plays inside `_perform_death_effect()`, so it is skipped together with the split when death effects are disabled.
- Test: `Tests/RockTitanTest.tscn` (boss wave, stats, boss bar, 4-golem split).

## Procedural battlefield

- `Scripts/Battle/Battlefield.gd` generates the battle map once per battle. `map_seed = 0` (default) picks a new random map each battle; any other value reproduces a map. `get_map_seed()` returns the seed in use, and `generate(seed)` rebuilds the map. The `generated(seed)` signal fires after each build.
- Terrain: `FastNoiseLite` FBM simplex → marching squares at `terrain_dark_level` / `terrain_light_level` → Ramer-Douglas-Peucker (`terrain_simplify`) → angular ground_dark / ground / ground_light patches. `terrain_frequency` sets the patch size.
- Placement: Poisson-disc sampling (Bridson) per object class (`rock_spacing`, `crater_spacing`, `deposit_spacing`, `max_deposits`). A second noise clusters rocks and a third places ore deposits along "veins". Map ore deposits are decoration only.
- Reserved for future interactive objects:
  - `get_special_sites()` → `[{position (global), radius, band (-1 dark / 0 / 1 light ground), distance}]`, sorted nearest-to-ship first. Up to `max_special_sites` (6), spaced `special_site_spacing` (560) apart, each kept clear of decoration for `special_site_radius` (110).
  - `get_interactables_root()` → `Battlefield/Interactables` node (absolute z -10: above ground decoration and dust, below ship and enemies). Add interactive objects here.
  - `is_area_free(global_pos, radius)` / `claim_area(global_pos, radius)` for runtime placement without overlaps.
  - `get_terrain_value(global_pos)` / `get_terrain_band(global_pos)` for terrain-aware rules.
  - `show_special_sites = true` draws the reserved sites for layout checks.
- Generation takes about 35–55 ms in the editor build and is drawn once (no textures).
- `AsteroidHangar` (base) extends Battlefield but overrides `_ready` / `_draw`, so it does not generate a battle map.
- Test: `Tests/BattlefieldGenerationTest.tscn`.

## Enemy rewards

- `BasicEnemy.reward_ore` (exported, default 0): ore added to the current mission (`ResourceManager.add_mission_ore`) when the enemy is killed. A floating gold "+N" pops up (`Scripts/VFX/RewardPopup.gd`, `RewardPopup.spawn(parent, world_pos, amount)`). It is skipped after battle shutdown, together with the other death effects (`set_death_effects_enabled(false)`).
- Current values: Little Rock 0, Rock Golem 0, Rock Titan 200 (golems split from the titan give 0). Rock Titan HP is 2000.

## Loadout drag-and-drop and persistence

- Drag a module card from the loadout list onto any ship slot. `LoadoutPanel.drag_started(module_id)` fires after 8 px of mouse travel. BaseMain shows a ghost icon and highlights the slot under the mouse (orange = fits, red = not enough power). On release it calls `drop_module_on_cell(module_id, Vector2i(row, column))`, which selects the slot and installs exactly like the "+" button, then keeps the panel on the module list. Esc cancels a drag.
- `Ship.select_cell(row, column)` selects a slot from code (emits `cell_selected`). `Ship.get_cell_at_global(point)` returns the slot under a global point, or `Vector2i(-1, -1)` if there is none.
- `ShipLoadout` saves to `ProgressionStore` section `"loadout"` (`{"cells": {"row,column": scene_path}}`) via `ShipLoadout.save()` and restores it on startup (`load_saved()`). BaseMain saves after every successful install or remove from the loadout panel. Tests that install directly through Ship do not save.
- Test: `Tests/LoadoutPersistenceTest.tscn` (uses its own save file).

## Laboratory UI

- `Scripts/UI/LaboratoryPanel.gd` (node `BaseUI/UIRoot/LaboratoryPanel`, now a full-screen `Control`), design A "workbench cards". The screen is dimmed and a 1040×610 panel holds:
  - a header with the stored ore and ESC;
  - a left category rail (`category_buttons`); unfinished categories show a lock and "COMING SOON";
  - one `ResearchCard` per research definition, laid out 2 per row and scrollable.
- Each card shows the target module's icon (`ModuleIcon`, using `target_id`), the current → next bonus (`WeaponDamageResearchEffect`), a level bar and the upgrade button. Button states: UPGRADE ◆cost / NEED MORE ORE (red) / LOCKED (unlock requirements) / MAX LEVEL (gold). A purchase plays an orange border + gold sparks + "+1 LV" for 0.5 s. Failure reasons from `ResearchManager.purchase_failed` show at the bottom.
- Clicking outside the panel or pressing ESC emits `close_requested`. All rules stay in ResearchManager; the panel calls `purchase_research()` and refreshes on `research_level_changed` / `stored_ore_changed`.
- Compatibility for `LaboratorySystemTest`: `open_panel()`, `close_panel()`, `_select_category()`, `category_buttons` (one child per category), and `upgrade_button` (first card's button, or a disabled "LOCKED" button for unfinished categories).

## Battle end: modules paused

- `Ship.set_all_modules_active(active)` pauses or resumes every installed module (weapons via `set_weapon_attacks_enabled`, mining drills via `MiningModule.set_mining_enabled`). BattleMain calls `set_all_modules_active(false)` on planet completion, ship destruction and evacuation, so no ore is mined after the battle ends. Test: `Tests/BattleEndPauseTest.tscn`.

## Mining drill animation + Mining QTEs

- Drill animation (visual only): `Scripts/Modules/Mining/MiningDrillVisual.gd` — auger bites down 3×, breakthrough slam (flash, shockwave ring, vector shards, smoke burst), yanks out an ore nugget; thick black smoke column from the exhaust pipe. Smoke / shockwave draw on the module's `DrillFX` child (z above neighbours); smoke rises screen-up even at 45°. Production stays on `MiningTimer`.
- `MiningModule.get_effective_ore_per_second()` (= `mining_rate / MiningTimer.wait_time`) and `play_qte_burst()` (presentation hook).
- Mining QTEs: `Scripts/Mining/QTE/` — `MiningQteManager` (node in BattleMain, one QTE at a time, `shutdown()` called on defeat / evacuation / completion), events `OreBurstEvent`, `PrecisionMiningEvent` (+ `MiningSkillCheck` UI), `SalvageDiscoveryEvent`, visuals `MiningQteVisual`. Config: `Resources/Mining/MiningQteConfig.tres`. Reward = effective ore/s × 30 into `ResourceManager.add_mission_ore`. Design doc: `docs/Mining_QTE_Design.md`. Test: `Tests/MiningQteTest.tscn`.

## Verdant (goblin) planet — visuals only

- `Palette.PLANETS[&"jungle"]`: green ground tones plus `decor = &"foliage"`, `canopy_mid`, `thatch`, `thatch_dark`.
- `Battlefield` with `planet_theme = &"jungle"` draws leafy octagon clumps and tree canopies instead of rocks (denser), mud patches instead of craters, and up to 5 goblin camps (thatched hut + campfire). Ore deposits are drawn as big landmark trees on jungle worlds (`_draw_big_tree`), since map deposits are decoration only. Camps are placed with Poisson spacing and claim their area.
- Planet select: new entry `goblin_planet` "VERDANT PLANET" (2nd in the carousel, theme `jungle`, locked). `PlanetVisual._draw_jungle_planet()` draws the globe.
- Goblin enemy art (option A "green-skin tribe"): `Scripts/Enemies/GoblinVisual.gd` draws all three goblins and the thrown spear, flat style A (dark rim + base + lit facet), red eyes (`Palette.GOBLIN_EYE`), colors `Palette.GOBLIN_*`. Goblin = knife, slashes on attack; Goblin Hunter = fur hood + quiver, winds the spear back during the last `GoblinVisual.WINDUP_TIME` s before a throw, then follows through empty-handed; Elite Goblin = iron helmet with bone horns, wooden round shield + spiked club, shield bash on attack. `Goblin.gd` / `GoblinHunter.gd` / `EliteGoblin.gd` only keep presentation clocks (`_anim_time`, `_attack_pose_time`); `GoblinHunterProjectile._draw()` calls `GoblinVisual.draw_thrown_spear()`.
- Not done yet (gameplay): a goblin `PlanetWaveConfig`, and passing the selected planet / theme from PlanetSelect into BattleMain (see the TODO in `PlanetSelect.gd`). Unlock the entry once those exist.

## Rendering performance (GL Compatibility / Web)

- `Scripts/Core/MeshBatch2D.gd` records CanvasItem-style draw calls (`draw_colored_polygon`, `draw_circle`, `draw_line`, `draw_polyline`, `draw_rect`, `draw_arc`, `draw_set_transform`) as triangles. `build()` bakes them into one ArrayMesh; `flush_to(canvas)` submits them as one triangle array.
- `Battlefield` paints the static map once through `_pen` into a MeshBatch2D and draws it with a single `draw_mesh` (jungle maps went from ~8,700 draw calls per frame to ~200). The bake is redone on `generate()`. New map painting code must draw through `_pen.`, not `draw_*` directly.
- `GoblinVisual` records each goblin into a shared MeshBatch2D and flushes it as one command per goblin per frame (~30 → 1).

## Base resource bar (top-right)

- `Scripts/UI/OrePanel.gd` (node `BaseUI/UIRoot/OrePanel`, base overview only) is a compact ◆ stored-ore pill that grows to the left. Expedition energy, its [+] purchase button and fuel were removed (see `docs/PLANET_LOCATE_SYSTEM.md`).

## Verdant goblins, Goblin Pack formation, Goblin Giant Chariot

- Stats (scenes): Goblin HP 20 / 1 ore, Hunter range 100 / 1 ore, Elite 5 ore. Goblin + Hunter are drawn 18 % smaller (`GoblinVisual.COMMON_SCALE`, radius 10); Elite unchanged.
- Goblin Pack: `SpecialSpawnEventRule.Pattern.FORMATION` → `WaveDefinition.SpawnPattern.FORMATION` → `EnemySpawner.spawn_formation()`. Layouts are data in `Scripts/Waves/SpawnFormation.gd` (`PRESETS`, rows of G/F/.). One unit is the flag bearer (`Goblin.is_flag_bearer`, banner only).
- Waves: `Resources/Waves/VerdantPlanetWaves.tres` waves 1-10 fixed table (890 total), wave 11 = Goblin Giant Chariot (boss entry).
- Boss: `Scripts/Enemies/GoblinGiantChariot.gd` + `Scenes/Enemies/goblin_giant_chariot.tscn` — throws 5 goblins (cooldown 8 s, 4 s stationary throw with the release at 75 %, 2 s pause; all exported), thrown goblins rooted 3 s (`Goblin.throw_to` / `root_for`), berserk once within 200 (speed ×2), death spawns 10 goblins, 500 ore. Placeholder art `GoblinVisual.draw_chariot`.
- Docs: `docs/VERDANT_WAVE_SYSTEM.md`. Tests: `VerdantEnemyTest`, `VerdantWaveSystemTest`, `GoblinChariotTest`.

## Settings menu

- `Scripts/UI/SettingsMenu.gd` (`class_name SettingsMenu`, node `BaseUI/UIRoot/SettingsMenu` in base_main): a gear button in the top-left (only in the base overview; BaseMain calls `set_available()`) that opens a dropdown with MAIN MENU, DEVELOPER MODE and QUIT GAME.
- QUIT GAME asks once more ("CONFIRM QUIT?", 3 s), then calls `get_tree().quit()`. On web builds it shows "Close the browser tab to quit." instead.
- MAIN MENU and DEVELOPER MODE are shown disabled with a "SOON" tag. Turn them on with the `main_menu_enabled` / `developer_mode_enabled` exports and handle the `main_menu_requested` / `developer_mode_requested` signals (BaseMain currently shows a "coming soon" toast for them).
- Clicking outside the dropdown or pressing Esc closes it. The node is self-contained and can be added to other scenes (e.g. battle) as a full-rect Control.

## Rearranging modules by drag (hangar)

- In assembly, press on an installed module and move > 8 px: it is picked up (ghost icon follows the cursor, the original dims). Dropping on another slot swaps the two modules; dropping on an empty slot moves it; dropping off the ship or Esc cancels. A plain click still only selects the slot.
- `BaseMain._handle_ship_drag_input` / `move_module_to_cell(source, target)`; `Ship.swap_modules(row_a, col_a, row_b, col_b)` moves the existing module instances (they slide to their new cells) and updates `ShipLoadout` — no power / limit validation needed since the installed set doesn't change. Saved immediately. Works on the 45° layout.
- Test: `Tests/ShipDragSwapTest.tscn` (real simulated mouse input).

## Ship styles (hull colors)

- `ShipHullVisual.STYLES` / `STYLE_ORDER` / `style_colors(id)`: hull color schemes `bone_iron` (default), `charcoal_red`, `bubblegum` and `deep_space` (with a soft glow around the thrusters). A scheme recolors floor tiles, the forged frame, thruster pods and rune studs; modules keep their own colors. `FRAME_RIM` / `FRAME_IRON` / `POD_BAND` remain the default-scheme constants (used by ResearchLab).
- `ShipLoadout.style_id` + `set_style(id)` (emits `style_changed`; Ship redraws). It is saved in the `"loadout"` section as `"style"` and restored on startup.
- Hangar: the loadout list footer has a "SHIP STYLE" button. `LoadoutPanel.show_style()` lists the schemes with swatches; a click applies and saves the scheme, and "‹ LOADOUT" goes back.
- Ship rotation (gameplay, not cosmetic): `ShipLoadout.layout_rotation` (0 or 45, `ROTATIONS`), set with `set_layout_rotation()` (emits `rotation_changed`) and saved with the loadout (`"rotation"` key). `Ship.apply_layout_rotation()` rotates the Ship node around the hull center, so everything that goes through `to_local`/`to_global` follows: enemy contact edges (`_get_nearest_ship_boundary_world`), slot picking (`get_cell_at_global`), thrusters and module positions. Weapons aim with `global_rotation`, so targeting is unchanged. Hull and module plate shadows are converted back to screen space (`get_shadow_offset().rotated(-global_rotation)`, `Palette.local_shadow_offset`). Picked in the SHIP STYLE view under ROTATION.
- Test: `Tests/ShipRotationTest.tscn` (center stays put, contact meets a corner on the axis and a side on the diagonal, slot picking follows, only 0/45 allowed).
