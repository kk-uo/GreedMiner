# Claude Code → Codex sync (2026-10-20)

The user asked Claude Code to implement several gameplay changes directly (beyond
the visual-only split in AGENTS.md). This note lists everything Claude changed on
2026-10-20 so Codex can re-sync. All changes are in the working tree (nothing
committed). All 40 tests in Claude's snapshot of `Tests/*Test.tscn` passed after
the last change (Codex has since added more tests that Claude has not run).

---

## 1. Weapons

### Flamethrower – every visible flame puff now hits
- **Files:** `Scripts/Modules/Weapons/Flamethrower/FlamethrowerProjectile.gd` (rewritten),
  `Scripts/Modules/Weapons/Flamethrower/Flamethrower.gd`.
- One `FlamethrowerProjectile` = one **shot** (fired once per attack interval). For
  `emit_window` seconds (= one interval) it pours `EMIT_RATE` (45/s) hexagon puffs
  out of `muzzle`, following the turret. Each puff has its own `CollisionShape2D`
  matching the drawn hexagon; the shot both draws and hits.
- Each puff flies to the attack range, then **hangs in place ~0.5 s**
  (`LINGER_TIME`) before fading; it still hits while hanging.
- Damage rule unchanged: one shot damages each enemy / destructible prop **once**.
- Range bonuses scale every puff: `Flamethrower.get_flame_size_scale()` =
  modified range / base range → `projectile.size_scale`.
- `Flamethrower.gd` no longer adds `FlameSpray`. **`FlameSpray.gd` is now unused
  and can be deleted** (Claude had no delete permission at the time).
- Public: `FlamethrowerProjectile.is_lingering()`, `get_puff_count()`,
  `get_puff_positions()`; vars `muzzle`, `emit_window`, `size_scale`.
- Side effect: real hit coverage is wider than the old invisible hit circle, so the
  flamethrower is effectively stronger.

### Laser – range bonuses widen the beam
- **File:** `Scripts/Modules/Weapons/Laser/Laser.gd`.
- `get_effective_beam_width()` = `beam_width × (1 + range_bonus × BEAM_WIDTH_RANGE_FACTOR)`,
  `BEAM_WIDTH_RANGE_FACTOR = 10.0` (+35 % range → +350 % width). Used by both the
  hit query and the `Line2D`.

### Chainsaw
- `Scripts/Modules/Weapons/Chainsaw/Chainsaw.gd`: `basic_damage` 10 → **8**.

### Range preview ring
- `Scripts/Battle/BattleMain.gd` `get_weapon_range()` now returns
  `get_modified_attack_range()` (chips + artifacts), so the ring matches play.

## 2. Demon Prism (new legendary magic artifact)
- **Files:** `Resources/Artifacts/DemonPrism.tres` (new),
  `Resources/Artifacts/ArtifactConfiguration.tres`,
  `Scripts/Artifacts/WeaponRangeArtifactEffect.gd` (new),
  `Scripts/Modules/Weapons/WeaponModule.gd`, `Scripts/Enemies/DemonLord.gd`,
  `Scripts/UI/Artifacts/ArtifactVisual.gd`, `Scripts/VFX/WeaponArtifactAura.gd`.
- `artifact_id = &"demon_prism"`, rarity Legendary, module artifact for all five
  weapons, `effect_parameters = {"range_bonus": 1.0}` (+100 % attack range, battle
  only). Granted once in `DemonLord._perform_death_effect()`.
- New hook: `WeaponModule.artifact_range_bonus: Callable` → added as a
  `base_additive_ratio` modifier (`source_id = &"equipped_magic_artifact_range"`)
  in `get_modified_attack_range()`. Stacks additively with the Range Chip.
- Because it goes through `get_modified_attack_range()` it also enlarges flame
  puffs, chainsaw radius and laser width/length.

## 3. Demon Lord
- **File:** `Scripts/Enemies/DemonLord.gd`.
- `special_clicks_per_part` 3 → **2** (phase-2 QTE: head, hands, feet × 2 = 10 clicks).
- **Teleport fix:** the half-health teleport used to be skipped when every
  candidate spot overlapped another enemy (crowded boss wave, collision radius 66).
  Now: (1) clear spot, (2) spot ignoring physics overlaps (`_is_valid_world_position(..., check_overlaps = false)`),
  (3) mirror point clamped into the map. New helper `_teleport_to()`.
  The teleport therefore always happens.
- Boss bar: Demon Lord badge + red theme in `Scripts/UI/BossHealthBar.gd` (visual).

## 4. Energy research tree (from the user's mind map)
- **Files:** `Resources/Research/ResearchConfiguration.tres`, `Resources/Research/EnergyTree.tres`,
  `Scripts/Research/ShipResearchEffect.gd`, `Scripts/Research/ResearchManager.gd`,
  `Scripts/Modules/Energy/EnergyModule.gd`, `Scripts/UI/ResearchTreeView.gd`.

| research_id | prerequisite | cost | effect |
|---|---|---|---|
| `energy_install_slot_unlock` (existing) | – | 300 | 2nd Energy Module |
| `energy_core_1` (existing) | install slot | 500 | +1 power per Energy Module |
| `energy_slot_support_1` **new** | `energy_core_1` | 1000 | `expansion_capacity_bonus = 1` – **interface only** |
| `energy_shielded_cells_1` **new** | `energy_core_1` | 500 | +5 max hull HP per installed Energy Module |
| `energy_range_1` (existing) | install slot | 250 | Verdant + Frozen |
| `energy_range_2` **new** | `energy_range_1` | 500 | Volcanic + Graveyard |

- New `ShipResearchEffect` exports: `expansion_capacity_bonus: int`,
  `energy_module_hp_bonus: float`.
- New `ResearchManager` API: `get_energy_module_expansion_bonus()`,
  `is_energy_slot_expansion_supported()`, `get_energy_module_hp_bonus()`.
- `EnergyModule.get_expansion_capacity()` now adds the research bonus, so
  `Ship.total_expansion_capacity` rises by 1 per battery. **Nothing consumes it
  yet** – the user wants the actual slot expansion later in the Ship (hull) tree;
  that research should check `is_energy_slot_expansion_supported()` /
  `Ship.total_expansion_capacity`.
- `EnergyModule.get_max_hp_bonus()` returns the Shielded Cells bonus (picked up by
  `Ship._recalculate_health_stats()`).
- **Behaviour change:** Volcanic is now gated by **both** `ship_air_conditioning_1`
  and `energy_range_2` (all gating research must be complete, same as Frozen).

## 5. Graveyard Planet (appearance + map only – not playable yet)
- `Scripts/PlanetSelection/PlanetSelect.gd`: new entry `graveyard_planet`
  ("GRAVEYARD PLANET", `playable = false`, `locate_cost = 2000`, theme `graveyard`).
  Shows "WAVES COMING SOON". No `EXPEDITION_CONFIGS` entry / wave config yet.
- `Scripts/PlanetSelection/PlanetVisual.gd`: star-map planet art.
- `Scripts/Core/Palette.gd`: `graveyard` ground palette, `decor = &"grave"`,
  **`map_extra = 200.0`**.
- `Scripts/Battle/Battlefield.gd`:
  - `_apply_theme_map_size()`: a theme's `map_extra` grows `world_size` by that
    much on each axis and shifts the node by −extra/2, so the map center (ship)
    stays put. Reverts on other themes.
  - `_place_graveyard()` runs before rocks; rocks use 2× spacing on grave maps.
  - New public: `is_area_free_near_ship(point, r)` (ignores the ship clearing),
    `get_ship_hull_distance(point, r = 0)`, `get_grave_emerge_points() -> Array[Vector2]`.
- `Scripts/Battle/Graveyard/GraveyardTombstones.gd` (new) – placement rules
  (distances from the hull edge):
  - 1 cluster of 9 stones (3×3 fenced plot) at 200–300 px,
  - 2 more clusters ≥ 450 px from the ship, ≥ 700 px apart,
  - ≥ 5 single stones at 100–200 px (spread around the ship),
  - ~20 single stones anywhere ≥ 260 px.
  - **Every stone is a monster spawn point:** `get_emerge_points()` (in front of
    each stone). Static art is baked into meshes; only the biomass glow pulses.

## 6. Graveyard weather (presentation only – no mechanics yet)
- `Scripts/VFX/GraveyardWeatherOverlay.gd` (new), `Scripts/Battle/WeatherManager.gd`.
- `WeatherManager.play_graveyard_lightning()` – flash ×2, ~1.45 s near-black night,
  reveal flash. Overlay signals **`blackout_started` / `blackout_ended`**
  (get it with `WeatherManager.get_graveyard_weather()`), plus
  `is_lightning_playing()`, `is_blacked_out()`. Intended use: spawn zombies from
  `Battlefield.get_grave_emerge_points()` during the blackout.
- During the blackout only nodes in group **`"glowing_eyes"`** that implement
  `get_eye_world_positions() -> Array[Vector2]` are visible (as glowing eyes).
- `WeatherManager.set_blood_moon(active)` – red monochrome regrade, red ash,
  heartbeat vignette, red aura under every `"enemies"` node. **The user's
  intended blood-moon mechanic (all units: 0.5 damage reduction, +10 move speed)
  is NOT implemented.**
- Nothing schedules lightning or the blood moon yet.

## 7. Tests
- **New:** `Tests/DemonPrismTest`, `Tests/FlamethrowerLingerTest`,
  `Tests/GraveyardMapTest`.
- **Modified (Codex-owned):**
  - `FlamethrowerResearchTest` – damage checks use `weapon.basic_damage`
    (base damage is 5, test assumed 2).
  - `DemonLordTest` – 2 clicks per part / 10 total; new `_test_teleport_in_crowd()`.
  - `ResearchTreeSystemTest` – Long-Long-Range Cells, Expandable / Shielded Cells,
    HP expectation includes +5 per battery.
  - `PlanetLocateLaunchTest` – Volcanic gated by Air Conditioning **and** `energy_range_2`.

## 8. Docs Codex may want to update
- `docs/RESEARCH_TREE_SYSTEM.md` – new energy nodes / effect fields.
- `docs/PLANET_LOCATE_SYSTEM.md` – already outdated (Frozen/Volcanic are live);
  add Graveyard (2000 ore, not playable) and the research gating above.

## 9. Known issues / placeholders
- Graveyard Planet has no waves, enemies or `EXPEDITION_CONFIGS` entry (user will
  provide the undead roster table later).
- Zombie emerge visuals were only prototyped (not in the project).
- `FlameSpray.gd` dead file (see §1).

## Earlier on 2026-10-20 (before the items above, already in the tree)
Range chips enlarge flame puffs; flamethrower research + chip slot (Codex added
the same definitions); laser range 1500, attack_interval 0.05; Flamethrower
unlocks on Volcanic, Laser on Frozen; Frozen boss freeze 10 s with click-to-break
(−0.5 s per click, `WeatherManager.freeze_qte_clicked`); Demon Lord damage
reduction 0.5, invulnerable while charging, 2.25× model; module research cost
200 × L; per-enemy ore rewards table; Verdant destructible trees (20/100 HP →
1/5 ore); Volcanic clickable lava vents (5 clicks → 50 damage, radius 110).

## 10. Graveyard undead art (added later on 2026-10-20)
- **New:** `Scripts/Enemies/UndeadVisual.gd` (`class_name UndeadVisual`) – user-picked
  style C "gothic night" for Zombie / Skeleton / Vampire / Werewolf and style A
  "classic Frankenstein" for Giant Frank. Arms hang at the sides; an attack
  swipes one arm forward. Everything is batched through one `MeshBatch2D`
  flush per enemy.
- **Presentation-only edits to Codex files:** `Zombie.gd`, `GraveyardEnemy.gd`,
  `GiantFrank.gd` now call `UndeadVisual` in `_draw()` and add animation state
  (`_anim_time`, `_attack_pose_time`, `_on_attack_timer_timeout()` override that
  calls `super()`). `GiantFrank.gd` also adds `_ready()` (calls `super()`, connects
  `lightning_struck` to a 0.6 s bolt effect) and `_advance_presentation()` called at
  the top of its `_process()`. Frank draws lifeless (eyes shut, arms splayed)
  during `FIRST_DEATH` and with electric arcs while `ENRAGED`. No gameplay
  values or timings changed; `GiantFrankTest` and `GraveyardWaveTest` pass.
- `Scripts/UI/BossHealthBar.gd`: Giant Frank badge, subtitle and green theme.

## 11. Graveyard follow-ups (later on 2026-10-20)
- `Scripts/Battle/BattleMain.gd`: new `apply_planet_view(planet_theme) -> float`,
  called at the end of `_configure_current_expedition()`. When the theme has
  `map_extra` (Graveyard: 200), the ship camera zooms out once so the visible
  width grows by that many pixels (≈ 0.89×). `EnemySpawner` reads the camera
  zoom, so graveyard enemies now spawn ~100 px farther out on each side.
- `GraveyardTombstones.gd`: stones drawn smaller (`DRAW_SCALE` 1.6 → 1.2,
  footprints 26/150 → 20/115); clusters no longer have a fence (`fences` renamed
  `plots`). Placement rules unchanged.
- `UndeadVisual.draw_skeleton()`: simpler bones-only skeleton (no body shell),
  black eye sockets, short sword.

## 12. Lightning, skeleton summons and Giant Frank (later on 2026-10-20)
- **Lightning** (`GraveyardWeatherOverlay.gd`): the blackout is now pure black
  (nothing shows through, blood-moon effects hidden too) and 1 s longer:
  `DARK_END` 1.9 → 2.9, `LIGHTNING_TIME` 2.4 → 3.4. The glowing-eyes pass was removed.
- **Lightning skeletons** (`WaveManager.gd`): the wave lightning no longer
  summons immediately. It connects (one-shot) to the overlay's
  `blackout_started` and then `_spawn_lightning_skeletons()` spawns
  **1–3 skeletons per grave** (`LIGHTNING_SKELETONS_PER_GRAVE = Vector2i(1, 3)`)
  through `GraveSummoner.spawn` (still origin `&"extra_weather"`, no wave budget).
  `GraveyardWaveTest` was merged with Codex's latest version: it now waits 0.7 s
  and expects graves ≤ extras ≤ 3 × graves.
- **Giant Frank size ×2** (`giant_frank.tscn`): collision radius 38 → 76,
  `attack_range` 25 → 63 (so his edge still stops where it did),
  `_get_visual_radius()` 76, art drawn at `UndeadVisual.FRANK_SCALE = 2.0`.
- **Resurrection cinematic** (new `Scripts/VFX/FrankResurrectionFx.gd`): started by
  `GiantFrank` on `first_death_started`. The world goes black (z 4000) with Frank
  raised above it (z 4001), HUD (`BattleUI`) and `WeatherManager/GraveyardWeather`
  hidden; on `lightning_struck` a huge forked bolt + screen flash hits him; after
  `resurrection_completed` + 0.5 s the light fades back and everything is restored
  (7 s safety cap; restores on `_exit_tree`).
- `WaveManager._on_frank_lightning()` no longer plays the weather lightning
  (the cinematic replaces it), so the boss never triggers a second blackout.
  (Codex has since made `_on_frank_lightning()` awaken zombie graves instead –
  that is fine, it still does not play the weather lightning.)

## 13. Ship hull: Segmented → Blade Armor, Bubblegum accent (later on 2026-10-20)
Presentation only, `Scripts/Ship/ShipHullVisual.gd`:
- The `&"segmented"` hull id is kept (saves keep working) but now draws
  **Blade Armor** (display name "Blade Armor"): slanted plates painted in the
  style's `rim` colour with a steel outer lip, one steel bolt and a glowing
  accent seam per cell. The old `plates` feature + `hazard` stripes are no
  longer used by any hull (code left in place).
- New design key `"armor"` (currently only `&"blade"`), drawn by new
  `_draw_armor()` after the frame; helpers `_bevel()`, `_glow_line()`,
  `_bolt()` and `STEEL_*` colours.
- Bubblegum style `accent` 5FD8E0 (cyan) → **FFF2F7 (pearl white)**; this also
  changes the pod rings and every accent pattern in that style.
- No gameplay or interface change; all 42 tests pass.

## 14. Chinese font subset (later on 2026-10-20)
The full `NotoSerifCJKsc-Regular.otf` (24.5 MB) was packed into every export
(web build ~40 → ~65 MB) although the game only uses ~450 Chinese characters.
- Moved the full font to `tools/fonts/source/` (inside the already
  `.gdignore`d `tools/`, so it is neither imported nor exported).
- New `Assets/Fonts/NotoSerifSC-Subset.otf` (~318 KB, 729 characters: every
  CJK / symbol character found in `Translations/`, `Scripts/`, `Scenes/`,
  `Resources/` plus the 500 most common characters in
  `tools/fonts/common_chars.txt`).
- `Resources/UI/greedminer_theme.tres` fallback now points at the subset.
- **After adding Chinese text** (e.g. editing `zh_CN.po`), run
  `pip install fonttools && python3 tools/fonts/subset_cjk_font.py`.
- New `Tests/FontCoverageTest` fails (and names the missing characters) when
  a translation uses a character the subset lacks. 44 tests pass.

## 15. Loadout click notices (later on 2026-10-20)
User request: clicking a locked weapon says which planet unlocks it; clicking a
battery at its limit says how to raise the limit.
- `LoadoutPanel`: new `signal module_card_pressed(module_id)` (emitted after
  `show_detail()` when a list card is clicked).
- `BaseMain`: new public `get_module_notice(module_id) -> String` ("" when the
  module can be installed): locked → `"LOCKED  ·  <requirement_text>"`; an
  Energy Module that would exceed `ResearchManager.get_module_installation_limit`
  (replacing a battery in the selected cell does not count) →
  `"BATTERY LIMIT REACHED (n/m)  ·  Research ENERGY MODULE EXPANSION I in the
  Laboratory for one more"` (just the first part once that research is done).
  Shown as the top toast for `NOTICE_TIME` 3.2 s on card click, and also used by
  `_on_install_requested` (+ button and drag-drop) before calling the Ship,
  which still validates authoritatively. `_show_toast(text, hold = 1.4)` gained
  an optional hold time.
- `zh_CN.po`: the new strings plus every `WeaponUnlockConfiguration`
  `requirement_text`. Font subset regenerated (733 characters).
- New `Tests/LoadoutNoticeTest`. 45 tests pass.

## 16. Graveyard undead death effects + zombie grave looks (later on 2026-10-20)
Presentation only; the user picked style C "signature" deaths.
- New `Scripts/VFX/UndeadDeath.gd` (`UndeadDeath.spawn(parent, at, kind,
  scale, facing)`, LIFE 2.6 s, frees itself): zombie sinks into the ground
  (hand reaches up, hole closes by ~1.2 s); skeleton blows apart (flash,
  spinning bones + skull, one bounce); vampire bursts into bats; werewolf
  howls (ice-blue rings) and dissolves into sparkles.
- Hooked through the existing `_spawn_death_visual()` presentation hook:
  `Zombie.gd` and `GraveyardEnemy.gd` (skeleton / vampire / werewolf; other ids
  keep the BasicEnemy burst). Giant Frank is unchanged.
- `ZombieGrave.gd` (presentation rewritten, gameplay API unchanged:
  `CLICKS_TO_REMOVE`, `clicks`, `register_click()`): draws one of six random
  looks from new `ZombieGraveArt.gd` (wood cross, pushed-up slab, reaching
  hand, coffin, skull cairn, broken slab with candle). It rises out of the
  soil after `RISE_DELAY` 0.75 s (+0.45 s) with a dirt-clod burst, so it
  appears as the zombie finishes sinking; removal spawns `StoneDust`. The node
  exists (clickable, counted by `get_zombie_grave_points`) from the moment of
  death as before. `variant` / `rise_delay` can be set before adding it.
- New `Tests/UndeadDeathTest`. 46 tests pass.

## 17. Dwarf mining art - style A "pickaxe" (later on 2026-10-20)
Presentation only; gameplay of `DwarfMiner` / `DwarfMiningController` /
`RockyCrystal` unchanged (speeds, distances, HP, rewards, signals).
- New `Scripts/Mining/DwarfMinerArt.gd`: the BaseDwarf-style dwarf with a
  pickaxe (swings at 1.6/s while MINING, lamp beam, crystal chips after each
  blow), carries a glowing chunk in the crystal's colour over its head while
  RETURNING with ore.
- `DwarfMiner.gd`: `_draw()` now uses it (stands 10 px back from the crystal
  centre while mining); facing follows movement / the crystal; HP bar only
  while `is_carrying_ore()`. Presentation vars live in a marked section.
  On completion spawns new `Scripts/VFX/CrystalShatter.gd`; when the dwarf
  dies the carried chunk shatters (small). z_index 1.
- `RockyCrystal.gd`: `_draw_cracks()` - hairline cracks grow with
  `mining_progress` (progress bar kept).
- `DwarfMiningController.gd`: `_draw()` - dashed animated gold dispatch line
  that snaps to the crystal under the cursor (pulsing ring); a gold recovery
  dial on a module during its 15 s `RESPAWN_SECONDS` cooldown.
- Zombie graves: checked in a real graveyard battle (BattleMain via
  change_scene, zombies killed) - `add_zombie_grave` runs and the graves rise
  and show. Note `add_zombie_grave()` only works when the battlefield theme is
  `graveyard` (zombies spawned on other planets leave no grave).
- 47 tests pass.

## 18. Planet ores for the dwarves (later on 2026-10-20)
User picks: Verdant amber; Frozen aurora frost + silver vein; Volcanic
obsidian + fire crystal; Graveyard biomass + soul crystal; "remove the old
crystals". Rewards are still to be decided - **placeholder: same as a blue
Rocky crystal (50 ore, 10 s)**.
- `Battlefield.gd`: `PLANET_ORES` {theme: [kinds]}, `has_planet_ores()`
  (needs `interactive_rocky_crystals`, i.e. battle maps), `ore_sites_per_map`
  6, `ore_site_spacing` 220. `_place_ore_sites()` (after `_place_deposits`)
  puts them inside the opening view on free ground and claims the area.
  On frozen / volcanic / graveyard battle maps `_place_deposits()` no longer
  places the old decorative crystal deposits (jungle deposits stay - they
  are the big VerdantTrees). The ores are RockyCrystal nodes in the same
  `RockyCrystals` container (`_add_ore_nodes()`), so dispatch, clicks,
  shared progress and `advance_mining()` are unchanged.
- `RockyCrystal.gd`: `ore_kind` + `configure_ore(kind, size)`; ores draw with
  new `Scripts/Mining/OreArt.gd` (animated, so `_process` runs only for ores),
  bigger hit circle, `get_visual_radius()` (presentation: how far the dwarf is
  drawn back while mining).
- `BattleMain.gd`: the DwarfMiningController is created on rocky **or** any
  planet with ores.
- `DwarfMiner.gd`: carried chunk / chips use `OreArt.chunk_color(kind)`.
- `Tests/RockyCrystalTest` updated: "other planets unaffected" now checks that
  frozen has no *Rocky* crystals (its ore deposits are expected).
- New `Tests/PlanetOreTest`. 48 tests pass.

## 19. First-battle mining tutorial (later on 2026-10-20)
User request: the first time the player plays the first level, show how to
use the mining module and let them try it.
- New `Scripts/UI/MiningTutorial.gd` (Control under `BattleUI/UIRoot`, same
  caption + bouncing arrow style as the base TutorialGuide, SKIP / GOT IT).
  `should_run(controller)`: a DwarfMiningController exists, the ship has an
  enabled MiningModule, and ProgressionStore section `mining_tutorial` is not
  `done`. Steps: SEND (arrow on the module + ghost cursor dragging to the
  nearest crystal) -> DWARF AT WORK (arrow on the crystal) -> BRING IT HOME
  (arrow follows the dwarf) -> ORE DELIVERED (GOT IT). Reads
  `controller.workers` / `cooldowns` and the worker's `is_carrying_ore()` /
  `state`; waits while ShipLaunchController `is_busy()`.
- **Gameplay touch:** while on the SEND step it holds the first wave by
  keeping `WaveManager.set_process(false)` (re-applied after the deferred
  `start_wave_system`), released on the first dispatch, SKIP, leaving the
  scene or after `HOLD_LIMIT` 60 s. Only when the current wave is <= 1.
- `BattleMain.gd`: `_build_mining_tutorial()` right after creating the
  DwarfMiningController.
- `zh_CN.po` + font subset (755 characters). New `Tests/MiningTutorialTest`.
  49 tests pass.

## 20. Volcanic lava rifts + demons climbing out (later on 2026-10-20)
User picks: template C "fault rift", two per map; every wave 5-6 ordinary
demons climb out of the lava at once.
- New `Scripts/Battle/LavaFissureArt.gd` (`generate_rift(rng, origin, angle)`
  -> {branches, emerge}; lightning-like midpoint displacement, side cracks)
  and `LavaFissureLayer.gd` (baked static mesh + two pulsing core meshes).
- `Battlefield.gd`: `_place_lava_fissures()` places `lava_fissure_count` (2)
  rifts inside the map, out of the ship clearing (+140 px), on free ground,
  claiming their area. **The old thin lava streams and the small curved
  cracks are no longer generated** on volcanic maps (`_lava_streams` stays
  empty, so LavaFlow is not created; `get_lava_streams()` returns []).
  Lava vents (craters) unchanged. New `get_lava_emerge_points()` (global,
  widest spots of the rift trunks) and `get_lava_fissures()`.
- New `Scripts/Waves/LavaEmergence.gd` (added by `BattleMain` on volcanic maps
  with rifts): on every `WaveManager.wave_started`, after `EMERGE_DELAY` 4 s
  (if the wave system is still running and the battle not ended) it spawns
  `PACK_SIZE` 5-6 `&"demon"` (EnemyCatalog) into `$Enemies` at emerge points of
  one rift >= 220 px from the hull, meta `spawn_origin = &"lava_fissure"`.
  They are extras on top of the wave budget (tracked by WaveManager via the
  Enemies container, so a wave also waits for them to be cleared). Each
  demon's physics is off for the ~1.5 s climb-out (staggered 0.15 s, grows
  0.45 -> 1, cools from glowing orange) with new `Scripts/VFX/LavaEmergeFx.gd`.
  Signal `pack_emerged(count, at)`.
- New `Tests/LavaRiftTest`. 50 tests pass.
- Follow-up (user: "rifts must not be generated off screen"):
  `_place_lava_fissures()` now places one rift on each side of the ship,
  running roughly vertically, entirely inside the opening view (viewport /
  ship `world_visual_scale`, 24 px margin), out of the clearing
  (`clear_radius + 70`) and out of the HUD corners (`_hud_rects()`); later
  attempts use shorter rifts so both always fit (checked on 40 seeds).
  `generate()` now calls `_place_lava()` **before** `_place_craters()` (no-op
  on non-lava planets, so other maps are unchanged) so craters / vents fit
  around the rifts. `LavaRiftTest` checks 20 seeds stay inside the view.

## 21. Trophy snowman in the base (later on 2026-10-20)
User request: after beating the Frozen Planet boss there is a snowman in the base.
- New `Scripts/Base/BaseTrophies.gd` (`has_trophy(id)`, `grant(id)`;
  ProgressionStore section `base_trophies`).
- `FrozenEnemy._perform_death_effect()`: `enemy_id == &"mega_monster"` grants
  `&"snowman"` (genuine kills only, like every death effect).
- `AsteroidHangar.gd`: `_spawn_trophies()` adds new `Scripts/Base/BaseSnowman.gd`
  ("TrophySnowman", top hat, scarf, waving arm) at mock `SNOWMAN_AT`
  (470, 480) and adds it to `_crew_obstacles()`.
- New `Tests/BaseTrophyTest`. 51 tests pass.

## 22. Research lab redesign: curved bench along the wall (later on 2026-10-20)
User: the lab (dark iron slab) looked out of place; picked "a curved research
bench running along the cave wall". Presentation + hotspot geometry only.
- `ResearchLab.gd` rewritten: the bench centre line is the hall outline
  pushed in by `BENCH_INSET` (34 mock px, round joins) from `BENCH_FROM` to
  `BENCH_TO`, smoothed (`bench_path_mock()` / `bench_path_local()`). Warm
  worktop with brass lip, stone end caps, copper pipes along the wall;
  stations along it: smelter -> curved belt with ingots -> power hammer ->
  alchemy flasks -> chip console -> crystal rack; anvil + LabScientist in front.
  `get_hit_rect()` / `SIZE` are gone - use `contains_local(point)`.
  New statics `center_mock_point()`, `tag_mock_point()`, `obstacle_circles_mock()`.
- `AsteroidHangar.gd`: LAB hotspot uses `_lab.contains_local()`;
  `get_hotspot_center(HOTSPOT_LAB)` is the bench middle; LAB tag uses
  `tag_mock_point()`; crew obstacles use the bench circles (old lab rect removed).
- New `Tests/LabBenchTest`. 52 tests pass.

## 23. Zombie graves: dug up by dwarves, not clicked (later on 2026-10-20)
User rule: zombie graves can no longer be clicked away; only a mining dwarf
digs them up - every grave inside the dispatch circle - in half the crystal
mining time (may be shortened later).
- `Battlefield.try_click_zombie_grave()` now always returns false (kept for
  BattleMain's click routing). New `get_zombie_graves_in(world_pos, radius)`
  (intact graves not already claimed by a dig site).
- `ZombieGrave.gd`: `CLICKS_TO_REMOVE` / `clicks` / `register_click()` removed;
  new `dig_progress` (trembles + darkens), `dig_site` (claim) and `crumble()`
  (StoneDust + free).
- New `Scripts/Battle/Graveyard/GraveDigSite.gd`: a mining target with the
  RockyCrystal contract (`can_be_mined`, `advance_mining` -> always 0 ore,
  `get_visual_radius`, `get_chip_color`). `DIG_RADIUS` 70 px,
  `DIG_TIME_FACTOR` 0.5 x `RockyCrystal.MINING_DURATION` (= 5 s). When done
  all its graves crumble and it frees itself; `release()` un-claims them.
- `DwarfMiningController.gd`: releasing a drag where there is no crystal but
  there are graves calls new `dispatch_to_graves(module, point)` (creates the
  site under the interactables root). A dwarf returning / dying before the
  site is done releases it. Drag preview: lilac circle + rings on the graves
  that will be dug.
- `DwarfMiner.gd`: `_target_site`; chip colour from `get_chip_color()`.
- `Tests/UndeadDeathTest` updated (no more click removal); new
  `Tests/GraveDigTest`. 53 tests pass.

## 24. Boss finisher + Rocky Planet finale (Claude, user request)

User pick: finisher "B" (cinema) on every boss kill, and finale "V1" only the
first time the Rock Titan is defeated.

- New `Scripts/VFX/BossFinisher.gd` (presentation): `BossFinisher.play(boss,
  at, keep_camera)` - hit-stop, ~1.2 s bullet time (`Engine.time_scale` 0 ->
  0.2 -> 1, real-time driven, always restored in `_exit_tree`), letterbox
  bars, white flash, world desaturated under the death effects, camera shake
  + zoom punch. Hooked in `BasicEnemy._die()` for `enemy_tier == BOSS` when
  death effects are enabled. New overridable `_finisher_keeps_camera()`.
- `RockTitan._perform_death_effect()`: its own death shake removed (the
  finisher shakes now). **Gameplay change:** if `RockyFinale.should_play()`
  (finale not seen, scene is a BattleMain still running) the titan does NOT
  split into golems; it calls `BattleMain.play_rocky_finale(pos)` instead.
  Later kills split as before.
- `BattleMain.play_rocky_finale()`: ends the battle like completion
  (`_battle_ended`, weather/artifacts/QTE cleared, `stop_wave_system(&"rocky_finale")`,
  modules off), hides BattleUI, crumbles remaining enemies (no reward) and
  removes mining dwarves, then adds `RockyFinale`.
- New `Scripts/Battle/RockyFinale.gd`: rubble that stays, 9 dwarves walk out
  and mine it, camera pulls back over the map, fade to space with the planet,
  "GREED MINER" + "THE ROCKY PLANET IS YOURS". Any click/key after the title
  -> `bank_current_mission_ore()`, `record_planet_completion(&"rocky_planet")`,
  saves `ProgressionStore["story"]["rocky_finale"] = true`, landing at base.
  Idle 6 s after the title -> small white "CLICK ANYWHERE TO RETURN TO BASE".
  No completion panel on that run.
- zh_CN.po: 2 new entries (merged on top of Codex's newest entries); font
  subset regenerated (also covers Codex's Ghost Bullet / salvage chest text).
- New `Tests/RockyFinaleTest`. Tests that kill the titan outside BattleMain
  are unaffected (no finale there).

### 24b. Finale tweak (user)
- Subtitle is now the credit "DESIGNED BY KUOSS" (not translated); the
  "THE ROCKY PLANET IS YOURS" po entry was removed.
- The space planet slowly rotates (craters/patches travel across the globe,
  the landing-site glint turns with it).

### 24c. Planet ore values + finale planet fix (user)
- **Gameplay values (user):** `RockyCrystal.ORE_VALUES` - a fully mined
  planet ore deposit pays (x research value multiplier) Verdant (amber) 80, Frozen (aurora/silver) 160,
  Volcanic (obsidian/fire) 250, Graveyard (biomass/soul) 400 mission ore.
  Rocky crystals unchanged. `Tests/PlanetOreTest` now checks the values.
- Finale planet spins slower (0.07 rad/s); surface features are clipped to
  the planet disc (`Geometry2D.intersect_polygons`), no more poking past the edge.

## 25. Base tutorial rework + Laboratory guide (Claude, user request)

`Scripts/UI/TutorialGuide.gd` (presentation + its own saved flags):
- New arrow (shared `Scripts/UI/GuideArrow.gd`, also used by MiningTutorial):
  no dark outline - notched head, rounded shaft, lit side, soft glow.
- SKIP button removed (GOT IT too).
- Mining step: when the MINING card is scrolled out of the loadout list, a
  "SCROLL DOWN" pill + bouncing chevrons show at the bottom of the list.
- Step 4 is now "USE ALL YOUR POWER": install one more Machine Gun; it moves
  on when no Machine Gun fits the remaining Power (or no slot is free). The
  POWER row is outlined meanwhile. `acknowledge_power()` was removed.
- New second part: the first time the player is back at the base with stored
  ore (`tutorial.done` and not `tutorial.lab_done`): arrow on the Laboratory,
  then inside it (caption moves to the top, guide re-ordered above the
  LaboratoryPanel) an arrow on the first affordable UPGRADE / RESEARCH button.
  Any `ResearchManager.research_level_changed` finishes it (`lab_done`).
  While it runs, the Laboratory's own "POWER FIRST" tip is held back
  (`lab_hints.energy_tip_shown` reset so it shows on the next visit).
- zh_CN entries for the new texts; font subset regenerated.
- New `Tests/BaseTutorialTest`.

### 25b. Laboratory "POWER FIRST" tip on every visit (user)
- `LaboratoryPanel._maybe_show_energy_tip()`: the tip now shows every time
  the Laboratory opens until `energy_install_slot_unlock` is researched
  (no longer first visit only); LATER hides it for that visit.
  `lab_hints.energy_tip_shown` is still written but no longer gates it.
- New `Tests/LabEnergyTipTest`.

## 26. Ghost Bullet + Red Crystal icons and effects (Claude, presentation)

- `ArtifactVisual.draw_icon`: custom icons for `ghost_bullet` (translucent
  pale bullet unravelling into a ghost wisp) and `red_crystal` (three red
  crystals on a dark rock with sparks), with silhouettes.
- New `Scripts/VFX/GhostShotArt.gd`: when ghost piercing is on,
  `MachineGunProjectile` / `DwarfCannonProjectile._draw()` draw a
  translucent spirit-shot with a wavering afterimage tail instead of the
  normal shot (they redraw per frame only while ghost is on). No gameplay
  change.
- `WeaponArtifactAura`: new kinds `red_crystal` (red ring, drifting red
  crystal shards + sparks) and `ghost_bullet` (pale wisps circling). Added by
  `ExplosionDamageArtifactEffect` (to its module) and `GhostBulletEffect` (to
  its weapon) in `_ready`, freed in `cleanup()`.

## 27. Mining research tree icons (Claude, presentation)

- `ResearchTreeView.node_info()`: Mining tree nodes (no effect resource yet)
  get a glyph by research id via `MINING_GLYPHS` (tier suffix stripped):
  value -> `crystal_value`, respawn -> `regrow`, qte -> `qte`,
  passive -> `ore_flow`, hp -> `dwarf_hp`, time -> `dig_speed`,
  worker -> `dwarf_pair`. New glyphs in `draw_glyph()` plus helpers
  `_draw_crystal()` / `_draw_helmet()`. If a mining node later gets a real
  effect resource, the id mapping still wins for these ids.

## 28. At least one ore deposit per map (user request)

- `Battlefield._place_deposits()` (Rocky crystals) and `_place_ore_sites()`
  (planet ores): if the normal placement produced nothing, one deposit is
  placed by `_guaranteed_spot()` (freest of 200 random spots inside the
  opening-view bounds, away from the ship). Crystal creation moved into
  `_make_deposit()` (same RNG order, so existing seeds are unchanged).
  Seen empty before on large windows (2526x1421: rocky seeds 8, 10, 18...).
- New `Tests/OreGuaranteeTest` (120 seeds x every planet).

## 29. Artifact acquired card + friendlier first-artifact hint (Claude, presentation)

- New `Scripts/UI/Artifacts/ArtifactAcquiredCard.gd`: `show_for(host,
  definition, first)` drops a card at the top (own CanvasLayer 59, real-time,
  mouse-ignore, ~6 s): icon popping in over rarity light rays, ARTIFACT
  ACQUIRED + rarity chip, name, description (what it does), and for the
  first artifact "The Magic Stall has awakened at the base."
- `BattleMain._on_artifact_granted()` now just calls it (old
  ArtifactAcquiredToast removed); `BaseMain._on_artifact_granted_at_base()`
  uses it instead of the plain toast.
- `ArtifactTutorialHint` restyled: caption card (rune-teal top border, the
  first artifact's icon in a turning rune badge, friendlier text, TAKE ME
  THERE button) + GuideArrow bobbing over the Magic Stall in the overview.
  SKIP button removed (`skip_requested` signal kept, unused). New `base`
  property set by `BaseMain._build_artifact_tutorial_hint()`.
- zh_CN entries for the new texts; font subset regenerated.

## 30. Homecoming at the base: ore haul / wrecked-ship repair (Claude, presentation)

- New `Scripts/Base/BaseHomecoming.gd`. Static `pending` ({kind, ore}) is set
  by the battle right before going home; `BaseMain._ready()` calls
  `consume(self)`.
  - `&"haul"` (ore > 0): 3-6 dwarves (by ore) come out of the warehouse,
    carry glowing ore chunks from the ship to the warehouse twice each (gold
    sparkle + "+" on delivery), then go back in.
  - `&"wrecked"`: black smoke plumes + embers on the ship, scorched hull tint;
    4 wrench mechanics come out of the tunnel and repair round the pad
    (~12 s), the smoke thins and the tint fades, then they leave.
- `BattleMain`: evacuation and completion return set `haul` with the banked
  amount (`bank_current_mission_ore()` return value); defeat return
  (`_on_return_to_base_pressed`) sets `wrecked` **and now also
  `ShipLaunchController.landing_pending_at_base = true`** (the wreck lands).
  `RockyFinale.return_to_base()` sets `haul` too.
- `BaseDwarf`: new `cargo` (&"crate" default / &"ore") for what `carrying`
  draws.
- New `Tests/BaseHomecomingTest`.
- Font subset regenerated (Codex's new text: 础隐蔽降低 were missing; FontCoverageTest).

## 31. Laboratory guide merged with the "POWER FIRST" tip (user request)

- `TutorialGuide` lab part now leads to `energy_install_slot_unlock`:
  LAB_OPEN (first time back with ore; `lab_done` saved on entering the lab),
  then LAB_RESEARCH on **every** Laboratory visit until that research is
  bought: arrow on the ENERGY tab -> selects the project -> arrow on
  RESEARCH (or on the node if the player selected another one). Caption shows
  the missing ore when it can't be afforded. Other research no longer ends
  the guide; buying the energy expansion does. `should_run_lab()` updated.
- `LaboratoryPanel`: its own energy tip is off
  (`ENERGY_TIP_MERGED_INTO_GUIDE = true`; code kept).
- Tests updated: `BaseTutorialTest` (lab part), `LabEnergyTipTest` (now
  checks the guide on every visit).
- 30b fix: repair mechanics now come out of the tunnel mouth (mock 640,655)
  instead of next to the tunnel crate pile, where one got wedged; plus a
  watchdog in `BaseHomecoming._unstick()` nudges any crew member that has not
  moved for 0.8 s toward its target. `BaseHomecomingTest` checks all 4
  mechanics reach the ship.

## 32. Goblin Giant Chariot speed 10 -> 15 (user request, gameplay value)

- `Scenes/Enemies/goblin_giant_chariot.tscn`: `move_speed = 15.0` (berserk
  x2 is now 30). `Tests/GoblinChariotTest` expectations updated (15 / 30).

## 33. Icons for the new Mining tree nodes (Claude, presentation)

- `ResearchTreeView.MINING_GLYPHS`: `mining_detection` -> `dwarf_stealth`
  (eye struck through), `mining_move_speed` -> `dwarf_run` (helmet with speed
  lines). `mining_hp_3` already uses `dwarf_hp` (tier III).

## 34. Smaller research lab (Claude, presentation)

- `AsteroidHangar.LAB_SCALE` 0.8 -> 0.62; `ResearchLab` bench shorter
  (BENCH_FROM 176,365 / BENCH_TO 475,104), BENCH_INSET 26, and the two big
  round stone end caps removed. LAB hotspot / crew obstacles follow
  automatically (LabBenchTest passes).

## 35. Rocky finale: skip only 2 s after the title (user request)

- `RockyFinale.SKIP_DELAY = 2.0`: clicks / keys are ignored until
  `TITLE_AT + SKIP_DELAY` (11 s). `RockyFinaleTest` checks an early click
  does not leave.

## 36. Base name tags only on hover + white hover outline (user request)

- `AsteroidHangar`: facility name tags are now drawn on the live layer and
  fade in (0.18 s, small rise) only while that facility is hovered or listed
  in the new `pinned_tags` (Magic Stall also while `artifact_guide_active`);
  `show_tags` still hides all of them outside the overview.
  `get_tag_alpha(hotspot)` for tests.
- Hover outlines are white (`Palette.HOVER_OUTLINE`) for hangar, star map,
  lab, warehouse and magic stall (the first-artifact guide ring stays orange).
- `TutorialGuide._pin_tags()` pins the tag of whatever its arrow points at
  (hangar / star map / lab) and clears pins on exit.
- 36b: hover outline softened: warm cream `HOVER_OUTLINE` (F2E3C6, 55%)
  over a faint wide `HOVER_GLOW`, via `Palette.draw_hover_outline()`.

## 37. ModuleSlotUnlockTest: Mining unlock costs 200 (user confirmed)

- The configured 200 Ore for `mining_install_slot_unlock` is intended;
  `Tests/ModuleSlotUnlockTest` now expects 200 (was 500). All tests pass.

## 38. Module artifact socket moved to a vertical dock (user request)

- `LoadoutPanel`: in the detail view the "ARTIFACT · THIS MODULE" socket no
  longer sits in the scrolling body; it is shown in `_artifact_dock`, a slim
  vertical tab (92 px, rune-teal edge) hanging off the panel's top-left, left
  of the LOADOUT title: "ARTIFACTS" written vertically, the socket, and the
  equipped artifact's name written vertically. Same rules for when it shows
  (stall unlocked + a compatible owned/equipped artifact) and same picker.
- 38b: dock text is horizontal now (user): label + wrapped name, dock 104 px wide.

## 39. Laboratory restyle: soft "Thronefall-like" cards (user pick)

- `LaboratoryPanel` (presentation only, same nodes / API / button texts):
  no dark panel - warm veil (`VEIL`), cream header text, round ESC;
  `category_buttons` is now an **HBoxContainer** (type `BoxContainer`) of
  round cream icons on top (name under the selected/hovered one);
  `ResearchCard` = cream rounded card: level badge, big module art
  (`ModuleIcon.show_backdrop = false`), name, now -> next, stat; level track /
  chip slots / milestone fade in on hover; price button styled soft
  (`style_button`); clicking the card body presses its button. Grid 4 wide,
  centred. Research tree / chip lab views unchanged inside.
- `ModuleIcon.show_backdrop` (default true).
- `TutorialGuide`: ENERGY tab arrow now points down (tabs are on top).
- 39b (user): clicking the card body no longer upgrades - only the button.
  UI motion added: cards pop in staggered on a tab change (`appear()`),
  lift slightly on hover, buttons grow on hover / squash when pressed,
  category icons lift on hover and the selection ring sweeps in; a purchase
  flies gold from the ore counter into the card, punches the ore number and
  bumps the card and its new value (plus the existing "+1 LV" sparks).

## 40. Selectable thruster styles (Claude)

- Hangar > SHIP STYLE has a new THRUSTERS section (between HULL and ROTATION):
  Round Pods (default), Diamond, Ring, Stilts, Fans. Cards show the unfolded
  thruster on the current hull; hovering a card fires it.
- ShipLoadout: `thruster_id` (default &"pod"), `set_thruster()`,
  `signal thruster_changed`; saved as "thruster" in the loadout data.
- ShipHullVisual: `THRUSTERS`, `THRUSTER_ORDER`, `draw_pods(canvas, geometry,
  thrust, thruster_id := &"", deploy := 0.0)` (&"" = saved style),
  `nozzle_points()` (exhaust FX positions per style; stilts = hull centre),
  `thruster_needs_redraw()`.
- Ship: new `thruster_deploy` (0 ground .. 1 flight). get_thruster_* now use
  the style's nozzle points.
- ShipLaunchController: takeoff unfolds thrusters (0.45 s) before igniting;
  landing starts unfolded and folds them away (0.5 s) after the engine cut.
  So takeoff/landing are each ~0.5 s longer.
- LoadoutPersistenceTest extended (default, every style has nozzles,
  persistence, unknown id ignored). zh_CN.po + font subset updated.

## 41. Flat lava rifts + werewolf blood burst (Claude)

- LavaFissureArt: rifts are flat now (charred rim, dark lava, lava, one
  lighter middle band). No glow halo, no hot-streak/core gradient; the middle
  band pulses evenly (LavaFissureLayer alpha 0.8..1.0, phase 1 mesh is empty).
  Midpoint displacement uses 4 levels instead of 5 (cleaner low-poly kinks).
- UndeadDeath werewolf: no more moonlight rings / soul sparkles. The body
  swells, flushes red and twitches for BURST_AT (0.22 s), then bursts: red
  flash + mist, blood drops arc out and land as splats, fur-and-meat chunks
  spin out and bounce, a pool spreads; all fade at the end of LIFE.
- Note: BloodMoonCombatTest currently fails ("blood moon and existing armor
  multiply", Frank 9975) on the synced copy; not touched by this change.

## 42. Red screen edge on ship damage (Claude)

- Ship: new `signal damaged(amount)`, emitted in take_damage after the
  interceptors (fully blocked hits do not emit).
- New Scripts/UI/DamageVignette.gd (CanvasLayer, layer 1, moved just before
  BattleUI so the HUD stays clean): soft red gradient round the screen edge,
  strength 0.45..1 by hit size (10 % max HP = full), fades over 0.55 s.
  BattleMain adds it as "DamageVignette" and calls watch(ship).
- New Tests/DamageVignetteTest.
- Suite on the synced copy: BloodMoonCombatTest (3 checks) and
  VolcanicWaveSystemTest (wave interval/duration, index 9 out of bounds) fail;
  both come from current wave/blood-moon data, not from this change.

## 43. Tutorial pointer restyle: "lock-on" (Claude, user pick D)

- GuideArrow: the glossy orange arrow is gone. draw() is now a small flat
  orange triangle with an ink outline (same signature; pulse ignored).
  New draw_lock(rect, time) / draw_lock_circle(center, radius, time): four
  cream corner brackets with ink outline that close in and breathe.
- TutorialGuide / MiningTutorial / ArtifactTutorialHint use brackets instead
  of the orange outline / ring, and a smaller bob (4 px at 1.2 Hz).
- TutorialGuide: ENERGY tab is locked as a circle round the icon
  (new _point_at_circle) with the marker below pointing UP (above it was
  hidden by the caption); the RESEARCH button marker now comes from above
  (DOWN) so it no longer covers the cost to its left.

## 44. Battle end beat before the result panels (Claude)

- New Scripts/VFX/BattleEndBeat.gd: `await BattleEndBeat.play(parent, ship,
  &"victory"|&"defeat")`. Real-time (ignores time scale), restores
  Engine.time_scale and the camera offset on finish / exit.
  - victory: slow motion 0.35 for 0.55 s, eases back, cream rings sweep out
    from the ship; panel after 1.6 s.
  - defeat: slow motion, 7 blasts round the hull with smoke, camera shake,
    ship darkens; panel after 2.2 s.
- BattleMain: _handle_ship_destroyed and _on_planet_completed await the beat
  before showing GameOverPanel / CompletionPanel (bookkeeping such as
  record_planet_completion still happens immediately).
- DeveloperBattleSpeed: `_cinematic_owns_time()` also yields to an active
  BattleEndBeat (static `_active`, same pattern as BossFinisher).
- BattleGameOverTest updated: the panel is hidden during the beat, time is
  slowed, then restored and the panel shows after ~2.6 s.
- Font subset regenerated (FontCoverageTest was missing 免).
- Result panel redesign: 3 options sent to the user (cream card / stamp +
  bottom ledger / expedition receipt); waiting for a pick.

## 45. Tree Planet art pass 1: dense forest, planet A, rain 1 (Claude)

User picks: planet look A ("ancient grove", denser), rain style 1, map "all
trees, almost no gaps, one big clearing in the middle". Gameplay untouched.
- New Scripts/Battle/Forest/ForestArt.gd: static tree drawing (oak canopy,
  giant oak with roots, willow, bushes, stump, log) for any pen
  (CanvasItem or MeshBatch2D).
- New Scripts/Battle/Forest/ForestCanopyLayer.gd: purely visual dense forest,
  baked into one mesh. ForestTerrain.generate() now ends with _build_canopy():
  a "Canopy" child at index 0 (gameplay ForestTree nodes draw on top), filling
  the map outside a wobbly clearing of empty_radius + sparse_ring_width * 0.8,
  with a dark forest floor under the crowns and bushes/stumps/logs on the rim.
  No filler crown sits on a gameplay tree. `ForestTerrain.canopy_layer`.
- ForestTree._draw: oak canopy (canopy_radius * 1.55) via ForestArt; chopped
  = mossy stump; dig_progress arc kept.
- Palette &"forest": olive A palette for the clearing ground.
- ForestStormController.RainView._draw: rain style 1 (slanted streaks,
  splash rings, cool tint); heavy (storm) = denser/faster/darker. Logic
  unchanged.
- PlanetVisual._draw_forest_planet: dense crowns, river, small clearing, rain.
- Font subset regenerated (FontCoverageTest missing 木雨森砍阻止暴仙缠绕).
- Pre-existing on the synced copy (not from this): ForestPlanetTest fails
  "mining module available for forest" / "dwarf dispatch to tree" + a null
  `set`; BloodMoonCombatTest and VolcanicWaveSystemTest as before.
- Next (waiting for the user): treant ("long tree spirit") art, three options
  on the design canvas, and the rise-from-the-ground animation.

## 46. Treant / fairy art + emergence, calmer storm rain (Claude)

- User pick: treant style A ("Kingdom Rush ent") recoloured green + brown.
  New Scripts/Enemies/ForestVisual.gd (class_name ForestVisual, MeshBatch
  pen like UndeadVisual): draw_treant(canvas, facing, step, flash, big, rise)
  - bulky bark body, leafy crown on back/shoulders, thick arms + fists, root
  feet, carved face with moss beard and amber eyes; big = 30/17 scale.
  draw_fairy(canvas, facing, flash, time) - glowing leaf sprite with wings.
- ForestEnemy (presentation only): _draw uses ForestVisual (ForestBoss keeps
  its own _draw). _process now also advances _anim_time and redraws ~12 times
  a second for the walk cycle/facing (every frame only during hit flash /
  emergence) - still far below per-frame redraws for big storm packs.
  Treant emergence (emerge_duration) draws it growing out of the ground and
  spawns new Scripts/VFX/ForestEmergeFx.gd (deferred, since spawners set the
  position after add_child): the ground splits, clods + leaves fly, a hole
  stays ~4.5 s; added as first child of the enemy's parent (under enemies).
- RainView: the storm streaks looked like a regular lattice; every drop now
  lives a short random cycle at a hashed position with its own length,
  angle and brightness (fewer, fainter). Splash positions hashed too.
- Suite: same pre-existing failures (BloodMoonCombat, ForestPlanetTest,
  VolcanicWaveSystem).

## 47. Tree Planet: every tree is a treant spawn, spots, storm regrowth (Claude)

User design (2026-10-22): "remove the willow kind; every tree is an object
that can become a monster; enemies tear out of the ground where they stand,
leaving a spot; every rainstorm regrows a tree on the spot and the next wave
can come out of it again; dwarves can dig a place out so it never comes
back." Gameplay changes - please review:
- ForestPlanetSettings defaults: maximum_trees 6000, tree_spacing 46,
  sparse_ring_density 0.06 (about 3,600 trees, one big clearing).
- ForestTree: new `uprooted` (empty spot), `kind` (&"oak"/&"giant"),
  `is_standing()`, `uproot()`, `regrow(delay)`, `finish_regrow()`,
  `get_crown_radius()`, signal `state_changed`. chop() works on a standing
  tree or a spot and closes it for good.
- ForestTerrain.take_spawn_tree(): uproots a standing tree, preferring ones
  within `spawn_view_radius` (950) of the map centre; cached pools rebuilt
  only after regrow/chop. used_active_trees() = spots (uprooted, not chopped).
  Clearing edge wobbles outward only (never inside empty_radius).
- ForestStormController.start_storm(): regrows every spot (staggered over
  respawn_spread_duration), returns that count, emits storm_started(count) and
  respawns_finished at once. It NO LONGER spawns enemies or reserves external
  spawns (get_pending_respawn_count() = 0, total_storm_respawns stays 0,
  new total_storm_regrown).
- Rendering: new ForestTreeChunks.gd draws all trees in 300 px chunks (ground /
  shadow / crown passes) from cached per-tree triangles; a state change
  re-bakes one chunk (10 spawns ~15 ms on this machine). ForestCanopyLayer is
  now only floor + rim (bushes, logs) + border crowns outside the bounds.
  Willow removed. Battle load builds the forest in ~1.3 s.
- Tests updated: ForestPlanetTest storm block (spot regrows, dug spot does
  not, no enemies), ForestWaveRuntimeTest (storm regrows 4 / 24 spots, no
  reservations). TREE_PLANET_INTEGRATION.md has a new section.
- Pre-existing failures unchanged (ForestPlanetTest mining module /
  dispatch, BloodMoonCombat, VolcanicWaveSystem).

## 48. Fusion weapon art (Claude, user picks from the design canvas)

Presentation only; recipes, combat values and scenes unchanged.
- New Scripts/Modules/Fusion/FusionArt.gd (class_name FusionArt): base,
  turret, beam, projectile and wave art per weapon_type_id. Picks: scatter A
  (bigger flared muzzles), knockback MG B (one barrel + gyroscope core),
  laser MG B (bigger finned barrel), sawblade MG A + single launcher barrel,
  flame MG B (gatling), laser chainsaw A (laser-edged disc), heavy laser A
  (moved back, double calibre), automatic cannon C (revolver), siege cannon
  C (mortar), knockback cannon B (gravity orb, bigger calibre), flame cannon
  A, knockback laser A (slit emitter), flame laser A (fins glow with the
  ramp, read from FlameLaser._doublings).
- FusionWeapon._draw: the fused octagon base with an element-coloured seam.
- FusionTurretVisual: draws the turret, sets Turret/Muzzle.position.x to
  FusionArt.muzzle_x(id) at _ready (barrel tips moved out), makes the Beam
  Line2D transparent (self_modulate.a = 0) and draws a styled beam from its
  points/width/visibility instead. Fire flash from the weapon's _cooldown.
- FusionProjectile._draw / FusionKnockbackWave._draw use FusionArt.
- Font subset regenerated (FontCoverageTest missing 30 new characters).
- Suite on the synced copy has other failures not from this change
  (AngryStone, ChipSystemV2 `_open_picker`, DeveloperMode, UniversalChip
  Healing, StoneAndFrost writes to /private/tmp, ForestPlanet, BloodMoon,
  VolcanicWave).

## 49 · 新魔法道具图标（Claude，2026-10-24）

- `Scripts/UI/Artifacts/ArtifactVisual.gd`：给 8 个新道具补了手绘图标（之前都回落到 `_gem`），都支持 silhouette 模式：
  - black_stone 黑石卵 + 紫色符文；red_stone 红石卵 + 金色符文（共用 `_pebble`）
  - frost_breath 冰蓝吐息云 + 雪花；true_ice 六棱冰晶
  - goblin_glove 绿皮指向手套 + 黄铜指扣；goblin_scope 黄铜望远镜 + 皮带
  - snow_monster_eyeball 冰蓝虹膜血丝眼球 + 霜边；necronomicon 骷髅封面黑书 + 绿眼
- 只加了 `draw_icon` 的 match 分支和静态绘制函数，没动数据和逻辑。

## 50 · 融合武器音效（Claude，2026-10-24）

- 新增 `tools/generate_fusion_sfx.mjs`（与 generate_weapon_sfx.mjs 同配方，可复现）→ `Assets/Audio/Weapons/Fusion/*.wav`（13 个 + .import）。
- `FusionWeapon.gd`：`SOUNDS` 表按 weapon_type_id 配置 [文件, 是否循环, volume_db, max_polyphony]；`_ready` 里 `_build_sound()` 代码生成 `Sound`（WeaponSound）子节点，**13 个 .tscn 没改**。`fire()` 开头调 `_play_attack_sound()`：子弹/冲击波每次齐射播一次，光束每 tick `sustain_for(0.15)`。
- `FlameLaser.gd`：`fire()` 里同样调 `_play_attack_sound()`，并按 `_doublings` 抬高音调（每次翻倍 +7%，最多 8 级）。
- 新武器若要声音：往 `SOUNDS` 加一行即可；没配的 id 不建 Sound 节点。
- Fusion 相关测试都过；WeaponFusionSystemTest 的 4 个 Dwarf Cannon install 失败是改动前就有的。

## 51 · UI 点击音效（Claude，2026-10-24）

- 用户选了方案 B「soft pop」。`tools/generate_ui_sfx.mjs` → `Assets/Audio/UI/click_pop.wav`。
- 新 autoload **`UiClickSound`**（`Scripts/Audio/UiClickSound.gd`，`project.godot` 的 [autoload] 末尾加了一行）：
  - `_input` 里左键按下时取 `gui_get_hovered_control()`，往上最多 4 层：启用的 `BaseButton`，或 `mouse_default_cursor_shape == CURSOR_POINTING_HAND` 的自定义控件 → 播放。禁用按钮、普通面板不响。
  - 焦点在按钮上按 `ui_accept` 也会响；暂停时照常响；40 ms 防抖，±3% 音高随机。
  - **自定义可点击控件想要点击声，只要把鼠标指针设成 pointing hand 就行**；想临时静音可设 `UiClickSound.enabled = false`。
- 新测试 `Tests/UiClickSoundTest`。

## 52 · 结算界面「开采战报」+ 打完 BOSS 后的延迟（Claude，2026-10-24）

用户选了方案 C（木板公告栏），但不要“通缉”——矮人是入侵去挖矿的，所以主题改成「开采战报」。

**流程**
- 打完 BOSS：`BossFinisher` 的子弹时间先播完（`BattleEndBeat` 不再抢 `Engine.time_scale`），然后屏幕中央「行星肃清 / 星球名」横幅 + 残留矿石飞回飞船（约 2.1 s），横幅淡出后才出结算板。从击杀到结算约 4 s。没有 BOSS 终结技时用原来的短慢镜头。
- 失败：原来的爆炸节拍（2.2 s）后出同一块板的失败版（「开采中止」，合计划掉 + 「未带回」章）。撤离仍是直接起飞，不出板。岩石星球的 RockyFinale 不变。

**新文件**
- `Scripts/Battle/BattleStats.gd`（class_name BattleStats）：BattleMain 每局建一个（节点名 `BattleStats`），`freeze()` 于战斗结束。记录 `kills`（enemy_id → name/scene/boss/count，来自 `BasicEnemy.died`）、`weapon_kills`（来自 `WeaponModule.enemy_defeated`，按 weapon_type_id）、`ore_by_source`、`artifacts`（`ArtifactManager.artifact_granted`，freeze 后仍记录）、`elapsed_seconds`（真实时间）。只读展示数据，不存档。
- `Scripts/UI/Result/ResultBoard.gd`（class_name ResultBoard）：代码构建，1600×900 舞台缩放适配；`setup(dict)`、`signal return_requested`、`skip_animation()`、`is_victory()`、`get_return_button()`。点击任意处跳过动画。敌人卡片用 `EnemyPortrait`（实例化敌人场景后移出所有组、关碰撞、停处理，同 ModuleIcon 思路）。奖励卡：新武器（蓝图）+ 新魔法物品（`ArtifactVisual.draw_icon`），最多 3 张 +N。左下便签：最佳武器。
- `Assets/Audio/UI/stamp_thud.wav`（`tools/generate_ui_sfx.mjs` 新增，click_pop 不变）。

**接口改动（请注意）**
- `ResourceManager.add_mission_ore(amount, source := &"other")` 新增可选 `source`，并新增 `signal mission_ore_added(amount, source)`。只用于结算板分类，**不影响数值**。已改调用点：mining_module `&"drill"`、DwarfMiner `&"dwarf"`、MiningQteEvent `&"chest"`（SalvageDiscoveryEvent）/`&"qte"`、VerdantTree `&"tree"`、BattleMain 水晶 `&"crystal"`、BasicEnemy 击杀奖励 `&"bounty"`。新的加矿点请传 source（标签见 `BattleStats.SOURCE_NAMES`）。
- BattleMain：`GameOverPanel` / `CompletionPanel` 不再 show()，保留为逻辑载体（按钮、UnlockLabel 文本照旧设置，WeaponUnlockSystemTest 不受影响）；`_show_result_board()` 在 `ResultLayer`（CanvasLayer 25）下加 `ResultBoard`，返回按钮走原来的 `_on_completion_return_to_base_pressed` / `_on_return_to_base_pressed`。
- `BattleEndBeat.play(parent, ship, outcome, banner_subtitle := "")` 多了可选参数。

**测试**
- 新 `Tests/ResultBoardTest`（统计计数 + 胜利流程出板）。
- 改 `Tests/BattleGameOverTest`：原“GameOverPanel.visible”断言改为检查 `ResultLayer/ResultBoard` 出现、是失败版、返回信号连到 `_on_return_to_base_pressed`。
- 全量：其余失败均为改动前已有。另：`FlameLaserTest` 的 “combined power cost is three” 失败是 flame_laser.tscn 的 power_consumption 被改成 4 了（不是这次改动），请确认哪个是对的。
- 新增中文翻译 + 重新生成了字体子集。

## 53 · 树木星球：一圈一圈拔地而起 + 树人 = 会走的树（Claude，2026-10-25）

用户反馈：树人数量不对、没按周围一圈出、树人出来后原地的树还在（密林里树冠盖住了坑）、树和树人长得不一样。新设计（用户确认）：

**玩法**
- 树按离空地的距离分圈：`ForestTree.ring`（1 = 空地边缘那一排 + 空地里稀疏的树，往外每排 +1；圈宽 `ForestPlanetSettings.ring_width`，0 = tree_spacing）。
- **第 N 波开始时，第 1..N 圈所有还站着的树一起变成树人**（第 N 圈 + 被暴雨长回来的内圈树）。一棵树 = 一个树人 = 一个坑，同一帧发生。约 1.6 s 内绕空地扫一圈依次起身（`ring_raise_duration`）。
- 当前地图每圈约 62–114 棵（累计：62/124/203/273/353/443/542/646/748/864）。**数量比原配置（4–11 个/波）多得多，请评估数值**（树人血量/伤害/奖励，或 ring_width 加宽 / 只取部分）。
- 波次配置里的 treant / big_treant 条目**不再生成**（EnemySpawner 直接 free，WaveManager 的报错抑制改为 `rings_own_treants or not has_spawn_trees()`）；big_treant 的 spawn_count 仍有用：该波起身的树里最大的 N 棵变成大树人。仙子、BOSS 照旧走配置。
- 起身期间用 `set_pending_external_spawns(&"forest_rings", n)` 挡住清波。暴雨逻辑不变（只把坑长回树）。矮人挖掉的树永久不再出现；起身扫到前被挖掉的树不出树人。

**新文件 / 接口**
- `Scripts/Battle/Forest/ForestRingRaise.gd`（class_name ForestRingRaise）：BattleMain 在森林星球创建（节点 `ForestRings`），监听 `wave_started`。`raise_rings(n) -> int`、`flush()`、`stop()`、`get_pending_count()`、`raised_by_wave`、`total_raised`。树人带 meta `forest_crown`（radius/seed/giant）和 `spawn_origin = &"forest_ring"`。
- `ForestTerrain`: `ring_width`、`rings_own_treants`（默认 true；改 false 恢复旧的单棵随机逻辑）、`take_ring_trees(n)`（只预约，`ForestTree.reserved`）、`count_ring_trees(n)`、`get_center()`。`ForestTree`: `ring`、`reserved`、`get_crown_seed()`；`is_standing()` 现在也排除 reserved。
- `ForestEnemy.emerge_duration` 默认 0.8 → 1.1（起身演出：先在原地颤 → 睁眼、树根拔出 → 开走）。

**画面**
- 树人改成“会走的树”：直接用它原来那棵树的树冠（同 seed/半径，与 ForestTreeChunks 完全一致），下面 4 条树根腿交替迈步，树冠上 5 只发光眼睛（2 大 1 小 2 微，会眨眼），受击整棵闪白。大树人起身时树冠胀大 1.4 倍。`ForestVisual.build_tree_crown()` / `draw_walking_tree()`；旧的 `draw_treant()` 保留未删。
- 同等数量树人下帧率与旧画法基本相同。

**测试**：`ForestWaveRuntimeTest` 按圈重写（第 1 波 = 第 1 圈全部 + 1 仙子，一树一坑一树人，暴雨长回，第 2 波 = 第 2 圈 + 长回的内圈）。ForestPlanetTest 的 mining module / dispatch 失败是之前就有的；GoblinGloveTest（缺 .gd）、ResearchTreeSystemTest 失败是 Codex 进行中的改动。
