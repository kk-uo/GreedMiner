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

## 54 · 树木星球：圈变窄 + 每圈只起一部分（Claude，2026-10-25）

用户要求在第 53 节基础上“一圈变窄，同时每圈只起一部分树”：
- `ForestPlanetSettings.ring_width` 默认 0 → **23**（半排树深），新增 **`ring_raise_fraction = 0.4`**（Battlefield 传给 `ForestTerrain.ring_raise_fraction`）。
- 规则改为：第 N 波 = 第 N 圈里 40% 的树（按角度均匀隔几棵挑一棵，确定性）+ 内圈里**曾经出过树人、被暴雨长回来**的树。第 N 圈没被挑中的树永远是普通森林，以后不会再起（`has_spawned_treant` 区分）。
- 当前地图每波约 18 / 11 / 14 / 10 / 14 / 16 / 14 / 16 / 18 / 16 个树人（+ 长回来的），接近原配置量级。两个参数都可在 Inspector 调。
- `ForestWaveRuntimeTest` 下限从 20 改为 5（第一圈只起一部分）。

## 55 · 树木星球外观：去掉雨 + 环间细河（Claude，2026-10-25）

- `PlanetVisual._draw_forest_planet`：去掉雨线；改为中央小空地 + 三条轻微起伏的同心细河（0.36 / 0.58 / 0.8 半径），树冠只长在河与河之间的环带里，呼应“一圈一圈起树人”。只改星球选择界面的球体画法，战斗地图不变。

## 56 · 修正第 55 节：星球外观只去雨；细河加进树木星球战斗地图（Claude，2026-10-25）

- 第 55 节理解错了。`PlanetVisual._draw_forest_planet` 已恢复原样（一条河 + 空地），**只去掉了雨线**。
- 战斗地图：每两圈树之间一条细河（`ForestTerrain.river_loops`，按空地边缘同样的起伏画同心环，铺到地图边；`ForestCanopyLayer.build(..., rivers)` 画在地面之上、树冠之下：泥岸 + 水 + 高光）。
  - 河中心线两侧 26 px 内不长树；靠河的树树冠按离河距离缩小，保证水面露出来。巨树基本不会再出现（环带放不下）。
  - `ring_width` 23 → **92**（= 一排树 + 一条河），`ring_raise_fraction` 0.4 → **0.2**。每波约 20/12/14/18/20/22/22/24/27/23 个树人（+长回来的）。树总数约 1600（以前 ~6000，因为河和环带占了位置）。
  - 树人/起身/坑/暴雨逻辑不变。河只是地面装饰，不挡路。

## 57 · 撤掉树木星球战斗地图的河（Claude，2026-10-25）

用户看了几版河流方案（每 3 圈完整 / 每 2 圈断续 / 断续小溪 + 水塘）都不喜欢，决定不要河。`ForestTerrain.gd`、`ForestCanopyLayer.gd`、`ForestPlanetSettings.gd` 恢复到第 54 节的状态（`ring_width = 23`，`ring_raise_fraction = 0.4`，无河）。星球选择界面的球体保持第 56 节（原样，只去掉了雨）。

## 58 · 岩石星球敌人音效（Claude，2026-10-25）

- 新 `tools/generate_enemy_sfx.mjs` → `Assets/Audio/Enemies/Rocky/`：little_rock_attack/death、red_rock_fuse/explode、rock_golem_attack/death、rock_titan_attack/death（可复现）。
- 新 `Scripts/Audio/EnemySfx.gd`（class_name EnemySfx）：共享 18 个 AudioStreamPlayer2D 的池（挂在 current_scene 下，节点名 EnemySfx），`EnemySfx.play(node_or_world_pos, stream, volume_db, pitch_var)`。同一音效最多 3 个同时、间隔 ≥45 ms，一大群同时死只响一声干净的碎裂。其他星球敌人以后也用这个接口。
- 挂点（只加了播放调用，逻辑不变）：
  - LittleRock / RockGolem：`_on_attack_timer_timeout` 中 `_is_attacking` 时（攻击动作那一刻）播攻击音；`_spawn_death_visual` 播死亡音。
  - RedRock：`_start_attacking` 点燃引信时播嘶嘶声；`_spawn_death_visual` 播爆炸。
  - RockTitan：攻击 slam 时播重击；`_perform_death_effect` 播崩塌（终章也会响）。
- 测试：RockTitan / RockyFinale / ExplosiveEnemy / DwarfEnemyTarget / RockyCrystal 均通过（本地临时换回上一版 Ship.gd 才能跑——**同步时 device 上的 Ship.gd 正在被改，调用了不存在的 `_cell()` / `_cell_at_visual()`，解析失败**，Ship.gd 我没动）。

## 59 · Verdant / Frozen 敌人、天气、挖矿音效（Claude，2026-10-25）

新 `tools/generate_world_sfx.mjs`（可复现）→ `Assets/Audio/Enemies/Verdant/`、`Enemies/Frozen/`、`Weather/`、`Mining/`（48 个 wav + .import；`Weather/*_loop.wav` 的 import 设为 loop_mode=2 循环）。所有调用都只是播放，不改任何逻辑。`EnemySfx` 现在是通用世界音效池（敌人、挖矿、QTE、拾取）。

**敌人**（攻击 = `_on_attack_timer_timeout` 里 `_is_attacking` 时；死亡 = `_spawn_death_visual`）
- Goblin / EliteGoblin / GoblinHunter / GoblinEngineer：各自攻击 + 死亡（工程师死亡 = 炸药爆炸）。`GoblinDynamite._explode` 爆炸声。
- GoblinGiantChariot：`_release_goblins` 投掷声、`_enter_berserk` 战争号角、**新增 `_perform_attack` 覆写**（super + 冲撞声）、`_perform_death_effect` 战车解体。
- FrozenEnemy：按 `_visual_kind()`（snow/big/wizard/sled/mega）选攻击/死亡音（`SFX_BY_KIND`）；`_launch_freezing_snowball` 冰冻雪球声。sled 的死亡音在 early return 之前。

**天气**：新 `Scripts/Audio/WeatherSfx.gd`（class_name WeatherSfx），BattleMain `_ready` 里创建（节点 `WeatherSfx`，在 `_stats` 之后），`_freeze_stats()` 时 `stop_all()`。监听 WeatherManager：weather_changed（暴风雪循环，BOSS 暴风雪更响）、ship_freeze_changed（结冰 / 碎冰）、freeze_qte_clicked、boss_entrance_started（轰隆）、lightning_triggered（雷）、blood_moon_started/ended（不祥和弦 + 低沉循环）；以及 ForestStorms 的 storm_warning（远雷）/ storm_started（雨循环 + 雷）/ storm_ended。

**挖矿**
- DwarfMiner：每次挥镐落下（`DwarfMinerArt.swing_cycle` 过 0.62）按目标播：水晶/矿 = 镐敲石、ForestChopSite = 斧砍木、GraveDigSite = 铲土；完成时：水晶碎裂 / 树倒 / 坟开。
- `RewardPopup.spawn`：所有 +N 矿石弹字都带“叮”的收矿声（限流）。
- RockyCrystal.register_click（玩家点水晶）镐敲；mining_module 每次产出很轻的钻机声；VerdantTree 被打倒时树倒声。
- QTE：Ore Burst / Precision 出现提示音；Burst 每次有效点击敲击声；Precision 开始计时声 + 完美 / 成功 / 失败三种结果音；宝箱落地 / 打开。

**测试**：Verdant / Frozen / Goblin / Graveyard / Forest / MiningQte / MiningTutorial / RedCrystal / RockyCrystal / DwarfEnemyTarget / Explosive / ResultBoard 等 18 个相关测试通过（本地临时换回旧 Ship.gd 才能跑）。**device 上 Ship.gd 依旧解析失败（`_cell()` / `_cell_at_visual()` 不存在），游戏打不开，请 Codex 修。** BloodMoonCombatTest 的 3 个失败是之前就有的。

## 60 · 研究树：去掉滚动条，改为鼠标拖动（Claude，2026-10-25）

- `ResearchTreeView`：ScrollContainer 两个方向都改为 `SCROLL_MODE_SHOW_NEVER`（不显示滚动条，滚轮仍可滚）。
- `TreeCanvas._gui_input`：按住左键移动超过 6 px 即拖动平移（改 `scroll_horizontal/vertical`，拖动时光标为抓手）；不拖动的点击在**松开**时选中节点（原来是按下时），拖动松开不会误选。
- LaboratorySystemTest / ResearchTreeSystemTest / MiningResearchTreeTest 通过。

## 61 · 火山 / 墓地 / 树木星球音效（Claude，2026-10-25）

新 `tools/generate_planet_sfx.mjs`（可复现）→ `Assets/Audio/Enemies/{Volcanic,Graveyard,Forest}/`、`Assets/Audio/{Volcanic,Graveyard,Forest}/`（44 个 wav）。只加了播放调用，逻辑不变。`EnemySfx.play()` 新增可选第 5 参数 `pitch`（基础音高，大树人用低音高复用树人音效）。

- **火山**：Imp / Demon / BigDemon / Hellhunter 攻击（`_on_attack_timer_timeout`）+ 死亡（`_spawn_death_visual`，化灰）。DemonLord：`_ready` 里连自己的信号——boss_qte_started 蓄力、boss_qte_progress 每次点击、boss_qte_finished(成功) 破防、laser_fired 激光、summons_spawned 召唤；`_teleport_to` 两端传送声；**新增 `_perform_attack` 覆写**（super + 爪击）；`_perform_death_effect` 死亡。LavaVent 每次点击（音高随压力升高）+ 喷发；LavaEmergence `emerge_pack` 岩浆冒出声。
- **墓地**：Zombie 攻击/死亡；GraveyardEnemy 按 enemy_id（skeleton / vampire / werewolf）攻击/死亡；GiantFrank 攻击 + `_ready` 连信号（倒下、坟墓苏醒、僵尸破土、雷击 + 复活电流、最终死亡）；`Battlefield.add_zombie_grave` 坟包升起声。
- **树木**：ForestEnemy 树人起身（`_spawn_emerge_fx`）、树人攻击、仙子攻击 / 治疗（`_heal_nearest_treant` 成功时）；**新增 `_spawn_death_visual` 覆写**（super + 按 id 播树人倒下 / 仙子消散 / BOSS 引擎熄火解体）。ForestBoss 电锯蓄力 + 发射锯片。ForestRingRaise 一圈树起身时一声大地轰鸣。
- 测试：DemonLord / DemonPrism / GiantFrank / Graveyard×3 / Lava×2 / ForestRainTransition / ForestWaveRuntime 通过；BloodMoonCombat、ForestPlanet、VolcanicWaveSystem 的失败是之前就有的。

## 62 · 树木星球 BOSS 新模型：树精驾驶的悬浮锯台（Claude，2026-10-27）

用户从三版里选了 B。
- `ForestVisual.draw_saw_rig()`（+ `_saw_blade`、`RIG_*` 常量，`RIG_SCALE = 1.6`）：圆形金属悬浮平台（甲板、边缘一圈追逐闪烁的警示灯、下方 8 个树汁喷口随时间脉动），树精树冠作为身体（世界光照、不旋转，`build_tree_crown(40, 77)` 缓存），树根抓住甲板，两条树枝手臂握着两侧支架上的锯片；树冠前侧 3 只发光眼睛（会眨，蓄力时变橙）。平台上下浮动，影子随高度变化；受击整体闪白。
- `ForestBoss`：`_process` 每帧重绘；`_rig_rot` 平滑转向 `_facing`，蓄力时转向锁定的瞄准方向；`_reload`（发射后 1.4 s 锯片从小长回来）；蓄力 `rev` 0→1 时锯片加速、外推、冒火星，瞄准线渐亮。`_get_visual_radius` 60 → 96。
- `chainsaw_spaceship_treant.tscn`：`saw_side_offset = 75`、`saw_forward_offset = 80`（锯片从画出来的位置发射，原 45/45 在放大后的模型里面）。碰撞半径 45 没动。
- 测试：ForestWaveRuntime / ForestRainTransition 通过；ForestPlanetTest 的失败是之前就有的。

## 63 · 龙巢星球：固定地图美术、红龙模型、远古巨龙半身 + 喷火 + 入场（Claude，2026-10-31）

用户定的方向：地面用“古王陵/龙巢”，敌人用 A 红龙；地图固定不随机；视野和树木星球一样大；远古巨龙只露出半截身子、在左右两侧洞口、靠喷火进攻、俯冲改成就地扑击，开场先有黑影掠过再缓缓降落，BOSS 出场时视野再拉远。参考图在设计稿 3 画布「龙巢 v2」。

**美术（新 `Scripts/Battle/DragonNest/DragonNestArt.gd`，static，画进 MeshBatch2D）**：`dragon()`（wyrm/great/ancient，翅膀可前摆、扇动、扑击 lunge、嘴里火光）、`coiled()`（盘在王座上睡觉，眼可睁开）、`kobold()`、`lizard()`、`wing_wrist()/head_centre()`（给 QTE 点用）。`mono` 静态色用于受击闪白和黑影剪影。
- `DragonNestFixedMap`：整张手绘龙巢，一次烘焙成 mesh（只有熔岩流光和热气每帧画）：矮人古王厅八角石厅 + 飞船符文圆环、四周“金币海”、两条熔岩渠 + 石桥、左右两个巨型龙洞口、倒下的矮人王石像头、焦黑冒险者骸骨、龙骨、蛋窝、石笋/岩壁、三座王座（王室那座带红地毯）。节点 z = -20（在矿石 -10、财宝堆 -15 之下），节点放在飞船中心，局部坐标绘制。
- `DragonHoard`：画成金币山（缓存 mesh），每偷一次缩小，偷空变暗；`pile_radius`，`interaction_radius` = pile × 0.75（整座山都能点）。
- `DragonEnemy`：睡觉/苏醒时画盘睡的龙（苏醒睁眼 + 黄圈），醒后画飞行红龙（幼龙 = wyrm 大头，巨龙 = great）；`art_radius()`、`get_target_point` 跟着变大。`DragonNestMelee`：狗头人（头顶蜡烛、镐、钱袋）/ 龙巢蜥（背上发光火疮）。`DragonFireProjectile`：火球带尾焰，`visual_scale`（远古巨龙 2.4）。

**数值/布局**
- `Palette` dragon_nest `map_extra` 200 → **300**（和树木星球一样大的视野）。
- `DragonNestRules.HOARDS` offset 改为 (-430,-300) / (-420,330) / (430,300)，加 `pile` 80/95/125；新增 `GATE_X = 1080`、`BOSS_ANCHOR_X = 850`、`BOSS_VIEW_EXTRA = 600`、`throne_offset(pile) = pile × 0.8`。
- 守卫龙睡在财宝山后面的王座上（hoard + 远离飞船方向 × throne_offset），不再在 hoard 前 85 px。
- 碰撞半径：龙巢蜥 15 → 20、幼龙 21 → 28、巨龙 29 → 42；`projectile_spawn_offset` 幼龙 24 → 56、巨龙 32 → 100。其他数值没动。

**远古巨龙（`AncientDragon`）**
- `BossState` 末尾新增 `ENTRANCE`、`RELOCATE`（伤害锁定）。`configure_lair(gates, ship_center, index)` 由 `DragonNestController._setup_boss` 调用：`lair_mode = true`，锚在右侧洞口（body 中心 ±850），面向飞船；碰撞圆移到可见的颈/胸（半径 130，shape 已 duplicate）；`get_target_point` 返回头/胸中离得近的点（离飞船中心 < 560，普通武器够得着）。
- `lair_mode` 下 GROUND_COMBAT 不走路（`_stationary_combat`），只用火球攻击（`_perform_attack` 从嘴里发射大火球）；Fire Breath 蓄力时嘴里火光变大，没被打断时画一道火焰喷向飞船。
- 俯冲 → **就地扑击**：`_update_airborne_position` 改为空（不再飞来飞去），TAKEOFF/QTE 时后仰抬翅，DIVE_RESOLUTION 头往前扑，LANDING 收回。QTE 三个点 = 两侧翅膀腕关节 + 头（随模型），`qte_zone_radius` 34 → 58。
- 入场：黑影从远侧墙飞过大厅（1.5 s），然后巨龙从高处缓缓降落进洞口（2.3 s，放大 + 半透明 → 落位）。`skip_entrance()` 给测试/开发用。
- 第 3/6/9 段（召唤的那几次）落地后进入 RELOCATE：飞起 → 黑影掠过 → 落到另一侧洞口，然后才召唤幼龙（左右轮换）。不在 lair_mode 时（单独实例化，如 PrototypeTest）行为和以前一样直接召唤。
- 洞里的后半身用 16 条渐暗条带压黑。
- BOSS 出场时 `DragonNestController._widen_view_for_boss()` 把镜头 2.4 s 拉远到再多看 600 px。

**测试**：`DragonNestBattleRuntimeTest` 改了（原来要求入口离飞船 < 550，现在入口在左右洞口）：检查两个洞口位置、守卫在王座上、BOSS 入场状态/伤害锁定/不走路/瞄准点距离/换边。DragonNestPrototype / WaveCap / BattleRuntime 通过；DeveloperModeTest 的失败是之前就有的。

## 64 · 龙巢：两侧改成城堡、到处散落的金币小山、财宝堆中间放龙蛋（Claude，2026-10-31）

用户反馈：左右两边要像城堡；金币不要规则的椭圆，要四处散落的金币和到处一座座小山，里面有宝石和各种道具；财宝堆中间要一颗龙蛋。
- `DragonNestFixedMap`：去掉椭圆“金币海”和两侧洞口。新增 `_scatter_treasure()`：全图散落约 3000 枚金币（大厅里稀一些），约 40 座不规则金币小山（大厅外半径 48–105，大厅里 24–40），避开飞船圆环、熔岩渠、财宝堆、石像。新增 `_castle(side)`：每侧一道带城垛的城墙（x 970–1180）、中间被撞破的城门（y ±175，黑暗门洞 + 断掉的铁闸 + 碎石，门上钉着龙头骨）、两座门楼圆塔 + 两座角楼（红瓦锥顶 + 小旗，其中一座塌顶）、墙后两座大厅屋顶。远古巨龙仍锚在 ±850，从城门里探出半身。
- `DragonNestArt` 新增：`gold_mound()`（多个不规则金团叠成的一堆，带溢出的金币、宝石、道具、闪光）、`egg()`（红色龙蛋，金色鳞斑，微微发光）、`treasure(kind)`（酒杯/王冠/剑/盾/头盔/小宝箱/烛台/项链）、`coin()`、`gem()`、`sparkle()`。
- `DragonHoard`：金币山改成一大四小的不规则金堆（`gold_mound`），中间画一颗龙蛋（不随偷取缩小，慢慢发光，每 0.1 s 重画一次）。
- `AncientDragon`：门洞里压黑后半身的条带高度改为 ±0.72R（只盖门洞，不再把两边塔楼压黑）。
- 测试：DragonNestBattleRuntime / Prototype / WaveCap 通过。

## 65 · 龙巢星球的选关星球外观（Claude，2026-10-31）

`PlanetVisual` 新增 `_draw_dragon_nest_planet()`（theme `dragon_nest`），之前用的是岩石星球的默认画法：缩小版的战斗地图——中间矮人王厅八角石厅 + 降落圆环、到处散落的金币和小金山（带宝石）、三座带红色龙蛋的财宝堆、两条熔岩渠、左右边缘的城墙 + 城门 + 红顶塔楼（用 `intersect_polygons` 裁在圆盘内）。加 `_draw_orbiting_dragon()`：一条小红龙（`DragonNestArt.dragon`，R=18）绕着星球飞。辅助：`_draw_gold_heap()`、`_draw_clipped()`。

## 66 · 龙巢：两侧改成环形城堡、降落特效、星球外观简化（Claude，2026-10-31）

- `DragonNestFixedMap._castle()` 重写：每侧一座**环形城堡**（中心 x = ±1190，半径 340）：圆形城墙 + 城垛、8 座红顶塔楼（一座塌顶）、院子里铺石板堆着金币小山、中间一座烧空的主塔（里面有火光）；朝大厅的一侧城墙被撞开（碎石 + 爪痕），远古巨龙（锚点仍是 ±850）就趴在这道破墙上，身体和尾巴压在城堡上。去掉了原来的直城墙、黑色门洞和墙后的屋顶；删掉 `_mrect/_mline`。
- `AncientDragon`：去掉门洞里压黑后半身的条带。新增降落特效（`_fx` 粒子，局部坐标）：下降过程中下压气流吹起尘土和金币、身上掉火星；落地瞬间 `_touchdown()` = 橙色冲击波 + 尘土圈、碎石、金币四散、嘴里喷一口火、镜头震动 0.7 s（`_shake_camera`，只改 camera.offset）；换边起飞时也有一阵尘土。只是表现，状态机/伤害没变。
- `PlanetVisual._draw_dragon_nest_planet()` 简化：不再是缩小地图，改成暗色火山星球 + 两条蜿蜒熔岩河 + 散落金币和小金堆 + 三座小环形城堡（`_draw_ring_castle`），小红龙继续绕着飞。
- 测试：DragonNestBattleRuntime / Prototype / WaveCap 通过。

## 67 · 龙巢：熔岩河改成金水河、远古巨龙戴王冠、金色 BOSS 血条和头像（Claude，2026-10-31）

- `DragonNestFixedMap`：两条熔岩渠改成**熔金河**（暗金岸 → 金色 → 浅金芯，流光和辉光也改成金色）；`LAVA` 常量现在是金色（名字没改）。`PlanetVisual` 星球上的河同样改成金色。
- `DragonNestArt._ancient_regalia()`（只给 ancient）：头顶一顶带宝石的尖刺金冠（会微微闪光）、两只主角套金角尖、脖子上一圈金片项圈 + 红宝石；去掉了原来额头的第三只眼（被王冠盖住）。
- `BossHealthBar`：新增 `ancient_dragon` 主题（金色血格：body B07A1A / top F2C14A / chip FFF1B0）、副标题 "CROWNED KING OF THE HOARD"、新头像 `_draw_dragon_badge()`（金边六边形底板，正面的戴冠红龙头，发光的眼睛，底部一排金币）。
- 测试：DragonNestBattleRuntime / Prototype / RockTitan（用到 BossHealthBar）通过。

## 68 · 石之心护甲跟随船体形状、金水河自然流动、龙翅膀、龙巢四角装饰（Claude，2026-10-31）

- `StoneHeartArmorVisual`：护甲石块不再固定 3×4 摆在 3×3 船体外，改为按 `Ship.get_hull_cells()` 在**每条外露的船体边**外面放一块（内角处离已有石块 < 40 px 的跳过），船体扩展（加格子）后形状跟着变；`ShipLoadout.expansion_changed` / `hull_changed` 时重建（deferred，在 Ship 重建之后）。恢复光圈、碎裂冲击波、倒计时小石之心的位置/半径改用船体包围盒中心和半径。默认 3×3 时和以前一样（12 块，半径约 160）。
- `DragonNestFixedMap`：金水河去掉中间的细亮线和滑动的白色短线；改为 `_draw_river_flow()`：浅金色的鼓包和深色的涡流沿河道慢慢往下漂（椭圆，左右轻微摆动），外加温暖的光晕。地板 + 河单独烘焙成 `_mesh_under`，流动效果画在它和其余地图（桥等）之间，所以**不会再盖到桥上**。
- 四个角的装饰 `_corner_pieces()`：左上半埋在金币里的巨龙头骨（眼窝里有金币，插着一把剑）、右上石台上的金色龙像（用 `DragonNestArt.dragon` 的 mono 三层上色）、左下一窝龙蛋（5 颗 + 一颗已孵化的空壳，树枝和骨头围成的窝）、右下宝箱堆 + 两个火盆（火焰每帧动）+ 破战旗。去掉了原来两个小蛋窝。
- `DragonNestArt._wing()` 重画：更深的扇形后缘、靠近身体处更暗、膜上细血管、后缘一道亮边（远古巨龙为金边）、手臂前缘一排骨刺、每根指尖带钩爪、腕部大拇指爪（远古巨龙的爪是金色）。
- 测试：DragonNestBattleRuntime / Prototype / ArtifactSystem 通过。

## 69 · 受击反馈改为按伤害染白 + 抖动；攻城炮特效 C「金色符文陨星」（Claude，2026-10-31）

**受击反馈（`BasicEnemy`，所有敌人一起生效）**：原来每次受击把整个身体换成纯白 0.08 s，机枪等高频武器会让敌人一直是白的。现在：
- `_register_hit_damage(amount)`：强度 = clamp(0.22 + 伤害/最大血量 × 6, 0.22, 1)；BOSS 最多 0.5。新的弱击不会把正在褪的强闪压下去。持续时间 0.08 × (1 + 强度)。
- `_update_hit_feedback(delta)`（`_process` 里调用；`ForestEnemy` 自己的 `_process` 也改为调用它）：用 `self_modulate` 把身体**提亮**（最多 ×2.3），所以小伤害只是轻轻一亮、大伤害接近全白，细节和颜色一直看得见；只在数值变化时才设置（大群树人不受影响）。
- 受击抖动：0.2 s 的 `rotation` 摆动（±0.14 rad × 强度）+ `scale` 先缩后弹（±12 % × 强度）；点击膨胀的 tween 正在播时不动 scale；BOSS 不抖。
- `_flash(c)` 现在原样返回颜色、`_is_flashing()` 恒为 false（各敌人画法里的“整块换白”退役，参数保留不用改）。`ForestEnemy` / `ForestBoss` 里直接读 `_hit_flash_time > 0.0` 的地方改成 `_is_flashing()`。`register_click` 用强度 0.6。`ForestTreantBatch` 仍然用 `_hit_flash_time` 判断是否离开批量绘制，不受影响。

**攻城炮（`SiegeAirstrike`，原占位图形全部替换；时序/伤害不变）**：
- 标记阶段（mark 0.6 s）：目标处金色符文法阵展开（外圈从大收到 1.6 × 爆炸半径，内圈 = 真实伤害半径，两圈反向旋转），金色底色随时间变浓；下落阶段地上的阴影变大变黑。
- 下落阶段（fall 0.4 s）：一颗金色陨星从攻城炮那一侧的高空斜着砸下来，拖着金/橙火尾。
- 落地：FusionProjectile 照旧结算伤害（之后移出 `siege_airstrikes` 组，组里只保留未落地的打击）；画面上有一道光柱、白闪、金色大火球、符文冲击环 + 尘土冲击环、22 颗金色火花、烟、镜头轻震 6 px 0.3 s，地上留一个发金光的焦坑 2.4 s 后消失。
- `SiegeCannon._spawn_strike` 在炮塔处加 `AIRSTRIKE.LaunchFx`：开炮星芒白闪 + 扩散的金色符文环 + 一道金光冲上天 + 烟。
- 测试：SiegeCannon / Explosive / MiningQte / RockyCrystal / ForestWaveRuntime / GiantFrank / SnowWizardClick / UndeadDeath / DragonNestPrototype 通过；WeaponFusionSystemTest 的失败是之前就有的。

## 70 · 攻城炮特效大小和真实爆炸范围对齐（Claude，2026-10-31）

用户要求画面和伤害范围一致。`SiegeAirstrike` 的绘制半径改回 `R = blast_radius`（原来是 ×1.6、最少 60）：标记外圈在标记阶段结束时正好收到 R，内圈 0.55R；火球、符文冲击环、尘土环、火花、焦坑都止于 R（白闪 0.5R→R，烟在 R 内）。光柱宽度 0.8R 不变。逻辑/时序不变；SiegeCannonTest 通过。

## 71 · 攻城炮爆炸范围 40 → 65（Claude，2026-10-31）

用户确认调大：`siege_cannon.tscn` 的 `aoe_radius` 40 → **65**（伤害、间隔不变）。特效按真实半径绘制（第 70 节），所以法阵和爆炸跟着变大。SiegeCannonTest 通过。

## 72 · 武器融合动画改成"锻炉锤击"（Claude，2026-10-31）

用户从三版方案里选了 B。触发方式不变（拖到可融合的格子上就开始，时长仍为配方 `duration` 1 秒）。

- `BaseMain._start_weapon_fusion`：原来的进度条 tween 改为 `tween_method(_update_fusion_forge, 0→1)`。新增 `_begin_fusion_forge / _update_fusion_forge / _restore_fusion_forge`，直接驱动两把**真实武器节点**：
  - 被拖武器沿来时方向后撤，再撞向目标，共 3 下（HITS 0.28/0.58/0.86）。
  - 每下都会挤压变形、抖动、把目标顶开一点，两把武器越撞越红（modulate）。
  - 最后一下之后被拖武器沉进目标。
  - 原来的 scale/modulate/z_index 会先保存，结束或取消时还原。
  - 开始那一帧不移动武器，所以测试里"拖拽的武器停在目标上"仍然成立。
- `FusionProgressIndicator` 重写，类名和 `progress`/`label_text` 都保留：
  - 顶部 3 个锤击格代替进度条。
  - 静态函数 `forge_pose()` 计算姿态，`heat_color()` 计算烧红颜色。
  - 加法混合的子节点负责热光、每次撞击的火花和闪光。
  - `play_reveal(result)`：融合完成后，新武器带回弹弹出，从红热冷却回原色（0.75 秒），同时有火花爆散、冒蒸汽，结束后自动释放。
- `WeaponFusionSystemTest`：攻城炮半径断言 40 → 65（第 71 节按用户要求调大后遗留）。其余 9 个失败（Dwarf Cannon/Laser 安装、电量相关）在改动前就存在，改动前后对比完全一致。

## 73 · 激光电锯改为近战电锯 + 激光环绕外观（Claude，2026-10-31）

用户要求：激光电锯应该是电锯（近战范围伤害），范围比电锯稍大，外观是被激光环绕的电锯。

- `FusionWeapon` 新增 `AttackKind.SAW`（=3）：
  - 不瞄准、不转塔。每次 tick 对模块周围半径 `attack_range` 内的所有敌人（以及 destructible_props）各造成一次伤害。
  - 实现在 `_process_saw` / `_fire_saw`，用 CircleShape 做物理查询。
  - 命中时 `saw_engaged = 1`（只用于表现），并维持循环音效。
- `laser_chainsaw.tscn`：
  - `attack_kind` 1（光束）→ **3（SAW）**。
  - `attack_range` 3000 → **100**（电锯是 80）。
  - 伤害 8、间隔 0.1、耗电 4 都没改。
  - Beam Line2D 节点保留但不再使用。
- `FusionArt._laser_chainsaw` 重画：
  - 钢锯片在中间旋转，齿尖是激光色。
  - 三条倾斜的激光轨道像原子一样环绕锯片，前后分层画；每条轨道上有一颗带拖尾的光点。
  - 命中时锯片转得更快，轨道变亮。
- 新增 `FusionArt.laser_saw_reach()`：只在战斗中显示，在实际攻击半径处画一圈淡淡的旋转激光虚线环，命中时变亮。由 `FusionTurretVisual` 调用。
- 新测试 `Tests/LaserChainsawTest.tscn`：攻击类型为 SAW；半径大于电锯且不超过 1.5 倍；半径内的敌人受伤，半径外的敌人不受伤。结果 PASS。
- 其余测试：FusionArtifactCompatibility、FusionWeaponLocalization、CombatOptimization 都 PASS。WeaponFusionSystemTest 还是原来那 9 个旧失败。

## 74 · 激光电锯：五道无限射程旋转激光（Claude，2026-10-31）

用户要求激光电锯射出五道无限射程的激光，攻击时不断全屏旋转。近战锯片（半径 100）保留。

- `FusionWeapon` 新增 export：`saw_beam_count`（默认 0）、`saw_beam_turn_speed`（弧度/秒）、`saw_beam_damage_ratio`。新增状态 `saw_beam_angle` / `saw_beam_power`。
  - 只要场上还有活着的敌人，`saw_beam_power` 就在 0.3 秒内升到 1，激光开始以 `turn_speed × power` 旋转；没有敌人时淡出、停转。
  - `_fire_saw_beams`：每个 tick 按扇区判定，伤害上一个 tick 到这一个 tick 之间被激光扫过的敌人（角度余量 = 半宽 + 14px，距离不限），扫得再快也不会漏判。同一 tick 已被近战打到的敌人不重复受伤。destructible_props 也会被打到。
- `laser_chainsaw.tscn`：`saw_beam_count = 5`、`turn_speed = 1.6`（约 3.9 秒转一圈；5 道激光，每个敌人约每 0.8 秒被扫到一次），`damage_ratio = 1.0`（每次扫中 8 伤害）。
- 外观：新增 `FusionArt.laser_saw_beam()`，包括光晕、光束主体、高亮内芯，靠近锯片的 420px 内有流动的锯齿，根部有亮点。`FusionTurretVisual` 用 `SAW_BEAM_LENGTH = 4000` 画出五道光束，角度扣除了 global_rotation。
- `LaserChainsawTest` 新增断言：激光数量为 5；1000px 外被扫过的敌人受伤（无限射程）；夹在两道激光中间（偏 36°）的敌人不受伤。结果 PASS。

## 75 · 树木星球卡顿：树人全部 MultiMesh 合批（Claude，2026-10-31）

用户反馈树木星球明显卡顿，从三个方向里选了 A + B + C（E 发现早已存在，见下）。

**测量**（最后一波一次长出 450–850 只树人，软件渲染统计绘制调用）：
- 每只单独绘制的树人约 31 次绘制调用；破土阶段全部单独绘制，峰值 12195 次。
- 远处被打中的树人会离开合批 0.12 秒，激光扫过就是一大片。
- 改完后整场稳定在约 900 次，这些基本都是地图本身。

**A · `ForestTreantBatch` 重写**：近处、远处、大树人、破土中、受击中的所有树人都由它绘制。
- 每组 16 层 MultiMesh：腿（3 个步态姿势，按朝向旋转）、树冠（9 种普通 + 3 种巨型，世界光照不旋转）、眼睛（按朝向旋转，随根拔出逐渐显现）。
- 实例颜色 = 节点 `self_modulate × modulate`，所以受击变亮、冰冻染色照常生效。
- 实例变换会读取节点的 `rotation` / `scale`，所以受击晃动、挤压和点击膨胀都能看到。
- 破土（抖动、跳起、大树人膨胀）在批量里实现。
- 分 7 组：近处或破土中的树人每帧刷新；远处的按 `instance_id % 6` 分 6 组，每帧轮流刷新一组，即 10 Hz，和 ForestTreantScheduler 移动远处树人的分桶一致。成员换组时，新旧两组在当帧都刷新。
- 无战斗（headless）开销：850 只树人约 1.2 ms/帧。
- 注册：`ForestEnemy._ready` 自动找 group `forest_treant_batch`；ForestRingRaise 现在也注册大树人（register 幂等）。
- `ForestEnemy`：受击和点击不再离开合批，只临时开启 `_process` 跑受击反馈，跑完自己关掉；`can_batch_visual()` 恒为 true。
- `BattleMain`：批量节点移到 `Enemies` 之前、z 0。树人画在飞船之上，在其他敌人、死亡爆散和弹体之下（以前远处的批量树人在 z -1）。

**B + C · 单独绘制的后备路径**（没有批量节点时，例如测试或其他场景）：
- `ForestVisual.draw_walking_tree` 把腿和眼睛各自用 `MeshBatch2D.flush_to` 合成一个三角形数组，每只 3 次调用。
- 拆出 `walking_legs()` / `walking_eyes()`。简化版没有根脚趾和高光线，3 只眼睛也不带光晕和高光点；远处的不画腿（新增参数 `legs`）。
- 批量用的网格（`batch_legs_mesh` / `batch_eyes_mesh`）保留完整细节，因为它们不额外花调用。

**E**：`BasicEnemy._ready` 里早就有 `collision_mask = 0`，我之前给用户报的"最坏帧少 35%"是两次运行之间的随机波动，已经向用户更正。树人挤在飞船边时的物理耗时，实际是近处树人的 `_physics_process` 脚本。

**测试**：
- `ForestPerformanceTest` 更新：批量数量必须等于全部树人（以前是"只有远处的普通树人"）；不允许有树人单独绘制；被打中的树人留在批量里，只开启 process。结果 PASS。
- ForestWaveRuntime / ForestRainTransition / CombatOptimization / LaserChainsaw 都 PASS。
- ForestPlanetTest 的失败（采矿模块 / 矮人派遣）是之前就有的。

**另外注意**：一次 64 只的生成批次本身约 40–56 ms（实例化开销），破土那一下仍会掉一帧。这属于用户没选的方案 D（分批破土）。

## 76 · 修复 ForestTreantBatch "Trying to cast a freed object"（Claude，2026-10-31）

用户运行时报错 `ForestTreantBatch._process: Trying to cast a freed object`。原因是条目里的树人已经被 free，之后又对它执行 `entry[0] as ForestEnemy`。在 GDScript 里，把已释放的对象 cast，甚至赋值给 `Object` 类型的变量，都会报错。现在先 `is_instance_valid(entry[0])`，确认有效后再 cast。复现脚本（直接 free 5 只、打死 5 只）跑完无报错，ForestPerformanceTest 也 PASS。

## 77 · 拖拽模块时幽灵图标错位（Claude，2026-10-31）

用户截图：在编辑器的 Game 视图里（Retina，2476×1393）从列表拖模块到飞船时，幽灵图标偏到高亮格的右下方。`BaseMain._update_drag` 原来写的是 `ui_root.screen_to_ui(viewport.get_mouse_position()) - (32, 32)`，只除了 UI 缩放，没算上画布、拉伸和内嵌窗口那一层变换。现在改成 `ui_root.get_local_mouse_position() - ghost.size / 2`，所有变换都会被算进去，并按实际尺寸居中。我这边在 2476×1393 下测过新旧两版都对齐（偏差 0），没能复现用户环境里的偏移，所以请用户在编辑器里再确认一次。`ScaledUIRoot.screen_to_ui` 其他地方没有用到。

## 78 · 魔法道具选择器：标签分类 + 不再被"飞船扩展"面板挡住（Claude，2026-10-31）

用户截图：基地里打开魔法道具选择器（左侧网格）时，左上的 SHIP EXPANSION 面板盖在它上面。另外用户要求魔法道具按标签分类。

- **遮挡**：
  - `LoadoutPanel` 新增 `signal storage_toggled(open)`（`_refresh_storage` 里可见性变化时发出）和 `is_storage_open()`。
  - `BaseMain` 连接 `_on_storage_toggled` → `_refresh_expansion_panel()`。选择器打开时扩展面板隐藏，同时按原有逻辑关闭扩展选格模式；关闭选择器后恢复。
- **标签**：
  - 新文件 `Scripts/UI/Artifacts/ArtifactTags.gd`（preload，无 class_name）：`ORDER` 定义标签顺序，`TAGS` 是 artifact_id → 标签数组（可以有多个），`tags_for(id)`；没登记的道具归入 "OTHER"。
  - **没有改任何 .tres**，因为 Codex 正在改这些道具资源。**以后新增道具，请在 `ArtifactTags.TAGS` 里加一行。**
  - 现有分组：DAMAGE（黑石/红石/哥布林牙/红水晶）、FIRE RATE（哥布林旗/号角）、REACH（哥布林瞄具/雪怪眼/龙翼）、PROJECTILES（幽灵子弹/蝙蝠眼/恶魔棱镜）、SPLASH（愤怒石/死灵书/红水晶）、CONTROL（冰息/真冰）、SHIP（石心/哥布林轮盘）。
  - `LoadoutPanel._artifact_entry` 给每个条目加上 `"tags"`。
  - `StoragePicker`：标题下面是一排可换行的标签按钮（HFlowContainer）：全部 + 当前列表里实际出现的标签，每个带数量。至少有两种标签才显示；芯片选择器和飞船槽位（只有 SHIP）不显示。
  - "移除"格子在每个标签页都会显示。选中的标签用 static 变量记住，下次打开时如果该标签还有道具就保持选中。
  - 面板高度按全部道具计算，所以切换标签不会改变面板大小。
  - 测试用接口：`select_tag(tag)`、`get_tab_tags()`。
- `zh_CN.po` 新增：REACH 射程、PROJECTILES 弹道、SPLASH 范围（本来想用"溅射"，但"溅"不在字体子集里）、CONTROL 控制、OTHER 其他。DAMAGE / FIRE RATE / SHIP / ALL 原来就有。
- **测试**：
  - 截图验证：选择器打开时扩展面板隐藏、关闭后恢复；中文标签和数量正确；"伤害"页只显示红石、黑石和哥布林牙（红水晶不兼容机枪）。
  - ArtifactSystem / ArtifactSlotsV2 / GoblinArtifacts / GoblinWheel / LoadoutNotice / NewArtifactExpansion 通过。
  - FontCoverageTest 缺的 8 个字（异引虚兼操防抵融）不是这次加的。ChipSystemV2Test 调用的 `LoadoutPanel._open_picker` 已经不存在（之前就坏了）。NewMagicArtifacts 在我这边是因为存档路径写不进去；StoneAndFrost 的失败之前就有。

## 79 · 结算界面：每个炮台本局造成的伤害（Claude，2026-10-31）

用户要求结算界面显示每个炮台本局造成的伤害。

- `WeaponModule` 新增 `signal damage_dealt(amount)`。`BasicEnemy.take_damage` 在实际扣血后，如果 `source_weapon` 有效，就 emit 实际扣掉的血量（护甲减伤后的值，不含溢出伤害）。弹体、光束、溅射、燃烧、带 weapon 参数的道具伤害（如愤怒石）都会计入；不带来源的（死灵书灵魂、石心冲击波、熔岩等）不计入。
- `BattleStats`：
  - `turret_damage`：按炮台**实例**统计，键为 instance_id，值为 `{id, cell, damage, kills}`。所以两把机枪会分开显示。只统计装在飞船上的武器。
  - `turret_rows()`：按伤害排序，伤害相同按击倒数，再相同按格子顺序。
  - `total_turret_damage()`、`refresh_turret_cells()`（`freeze()` 时记录每个炮台所在的格子）。
- `ResultBoard`：有炮台数据时，敌人卡片压成一行（`_enemy_grid` 新增参数 `max_rows`；BOSS 卡高度 500 → 360），下面是夹在夹板上的「炮台伤害」纸。
  - 每行：图标、名称、格子（R·C）、相对第一名的进度条、占比、伤害数值（≥1 万显示为 K）。第一名整行高亮，进度条为橙色，并带 MVP 标签。
  - 5 个及以下单栏；更多时双栏，最多 10 行，其余合成「+N 个炮台」。
  - 进度条和数字带滚动动画。原来的「最佳武器」便签在有炮台数据时不再显示（没有数据时照旧）。
- `zh_CN.po`：TURRET DAMAGE 炮台伤害；Total %s 合计 %s；+%d more turrets → "+%d 个炮台"（本来想用"另有…座"，但"另"和"座"不在字体子集里）。
- `ResultBoardTest`：新增断言：一个炮台一行，正确标出武器和格子；伤害等于实际扣血（不含溢出）；每个炮台的击倒数正确。结果 PASS。FontCoverage 仍是之前缺的 8 个字；CombatOptimization / LaserChainsaw / SiegeCannon / AngryStone / GoblinArtifacts 都通过。

## 80 · 修复龙翼图标三角化报错 + TurretRangeIndicator"找不到类型"（Claude，2026-10-31）

- `ArtifactVisual._dragon_wing`（第 641 行）：翼膜那一块的多边形是锯齿形，自己和自己相交，`draw_colored_polygon` 每帧都报 "Invalid polygon data, triangulation failed"。现在拆成 3 个三角形，外观一样，不再报错。
- `ManualTurretController.gd:12 Could not find type "TurretRangeIndicator"`：代码本身没问题。我用 device 上最新的全部文件做了一次全新导入，类注册正常，ManualTurretControlTest 也 PASS。原因是用户编辑器里的全局类缓存（`.godot/global_script_class_cache.cfg`）缺了这一项，可能是编辑器开着的时候文件在外部被改了。在编辑器里 Project → Reload Current Project 即可。没有改任何代码。

## 81 · ManualTurretController 不再依赖 TurretRangeIndicator 这个全局类名（Claude，2026-10-31）

用户运行时仍然报 `Parser Error: Could not find type "TurretRangeIndicator"`，重新加载项目后也一样。检查用户的 `.godot`：`editor/filesystem_cache` 里能看到 `class_name TurretRangeIndicator`，但 `global_script_class_cache.cfg` 里就是没有这一项（Godot 4.7.2 编辑器；没有重名，代码在 4.7.1 的全新导入下正常）。

修法：`ManualTurretController` 改用 `const RangeIndicator := preload("res://Scripts/Battle/TurretRangeIndicator.gd")` 作为类型（变量和 `set_range_indicator` 的参数）；`ManualTurretControlTest` 的 `as TurretRangeIndicator` 改成 `as RANGE_INDICATOR`。`class_name` 保留。验证：临时去掉 class_name、重新导入（全局缓存里 0 条），ManualTurretControl / BattleClick 两个测试都 PASS。**Codex：在用户的编辑器里，新加的 class_name 可能不会被注册；跨脚本引用新类时，最好用 preload 常量当类型。**

## 82 · 火焰机枪射程 200 → 400（Claude，2026-10-31）

用户要求：`flame_machine_gun.tscn` 的 `attack_range` 200 → **400**。子弹最远飞行距离（`maximum_distance` = attack_range）也跟着变成 400。其他数值不变，没有测试检查这个值。

## 83 · 火焰机枪子弹无限穿透（Claude，2026-10-31）

用户要求：`flame_machine_gun.tscn` 加上 `projectile_pierces_all_targets = true`（FusionProjectile 原本就支持：同一个敌人只打一次，子弹一直飞到最大距离）。子弹外观和哥布林轮盘改成老虎机，都还在出方案，等用户挑选。

## 84 · 火焰机枪新子弹 + 哥布林轮盘改成哥布林老虎机（Claude，2026-10-31）

**火焰机枪子弹**（用户要求：保留喷火器那种扩散感，但看起来还是子弹）：
- `FusionArt._flame_bullet`：前端是尖头弹（白热弹尖、发红的弹壳、一道亮环）。
- 后面不断甩出喷火器同款的六边形火团，用的是喷火器同一套颜色渐变（白→黄→橙→红→烟）。每个火团大致停在甩出的位置（drag 0.75），随时间变大、往两侧散开。
- 火团位置由子弹飞行时间算出来，不需要额外状态。每颗子弹同时约 13 个六边形。
- `draw_projectile` 新增可选参数 `speed`（默认 300），`FusionProjectile._draw` 传入自己的 speed。其他弹种不变。
- 配合第 83 节的无限穿透，打出来是一条连续的火焰弹流。

**哥布林轮盘 → 哥布林老虎机**（用户选了 B 极简三格，并要求哥布林风格）：`GoblinWheelPanel` 重写。
- 外观：200×132，暗木板机身，带铁箍、铆钉和骨刺；顶上一个哥布林头（尖耳、红眼、牙齿；平时会眨眼，中奖时咧嘴、瞪眼）。三个骨白色转轴只显示图标：红心＝船体，剑加绿色「+」＝伤害 +1，剑加「%」＝伤害 %，准星＝射程，闪电＝攻速，镐＝采矿；未知 buff 显示金币。
- 流程：从下方滑入，三个转轴依次在 0.45 / 0.7 / 0.95 秒停下，带回弹。鼠标悬停时该格描金边，底部显示一行 tr(label)。点击后，选中的格子闪金光并移到中间，另外两格缩没，哥布林嘴里喷出金币；0.6 秒后 `spin_finished` 发放 buff；停留 0.9 秒后下滑淡出，发出 `presentation_finished`。
- 接口不变：`start_spin(options, result_index)`、`choose_option(i)`（转轴还在转时点击会立即停下）、`finish_immediately()`、`is_presenting()`、`options`、`selected_index`，以及两个信号。GoblinWheelEffect 不用改，GoblinWheelTest PASS。
- `zh_CN.po` 补上 6 个 buff 名称（船体 +25、武器伤害 +1、武器伤害 +5%、武器射程 +10%、攻速 +5%、采矿 +0.5/秒），字体覆盖没有新增缺字。

## 85 · 激光电锯平衡：只有敌人进入近战范围才发射激光（Claude，2026-10-31）

用户觉得激光电锯超模。`FusionWeapon._has_live_enemy()`（以前只要地图上有活着的敌人，五道激光就一直全屏转）改成 `_has_enemy_in_saw_reach()`：只有当有可攻击的敌人（考虑 `can_target_enemy`、跳过正在死亡的）距离 ≤ 攻击半径（100，含射程加成）+ 敌人碰撞半径时，`saw_beam_power` 才升起来；没人在近战范围内时，0.3 秒淡出并停转。激光一旦亮起，射程和扫描判定不变（仍然无限射程）。`LaserChainsawTest` 新增两条断言（敌人在 600px 外时不出激光；进入 60px 后激光开启），结果 PASS。

## 86 · 激光电锯每次扫中伤害 = 一次基础激光伤害（Claude，2026-10-31）

用户要求每次扫中只造成激光一次攻击的伤害。
- `FusionWeapon` 新增 `@export var saw_beam_damage: float = 0.0` 和 `get_saw_beam_damage()`：大于 0 时返回 `get_modified_damage(saw_beam_damage)`（研究、道具加成和普通伤害走同一套），否则沿用 `get_damage() × saw_beam_damage_ratio`。
- `laser_chainsaw.tscn` 设 `saw_beam_damage = 1.0`，等于 `Laser.basic_damage`（1）。之前每次扫中是电锯的 8 点。近战锯片的伤害（8 / 0.1 秒）不变。
- `LaserChainsawTest`：新增断言「每次扫中伤害 = 基础激光 basic_damage」，远处敌人被扫中后扣血按 `get_saw_beam_damage()` 计算。结果 PASS。

## 87 · 修复 FusionKnockbackWave 的 "Trying to assign invalid previously freed instance"（Claude，2026-11-01）

用户运行时报错：`FusionKnockbackWave._physics_process` 第 66 行 `var enemy: BasicEnemy = state["enemy"]`。敌人已经被释放后，又把它赋值给有类型的变量，这一步本身就会报错，后面的 `is_instance_valid` 根本来不及检查。现在先检查 `is_instance_valid(state["enemy"])` 再赋值。全项目搜索同类写法，还发现 `DwarfCannonProjectile._resolve_ghost_impacts` 里的 `impact["target"] as BasicEnemy`（延迟处理的命中，目标可能已经被释放），按同样方式先检查再 cast。直接在 device 上原地修改。FusionKnockbackWave / GhostBullet / SiegeCannon 测试 PASS。**规则：存起来的敌人引用，要先 `is_instance_valid(原值)`，再赋给有类型的变量或做 `as` 转换。**

## 88 · 火山星球回到星图：和冰冻星球做成"冰火星系"双子位（Claude，2026-11-01）

用户要求把 Volcanic 加回来，和 Frozen 放在同一个选项里绕着转，玩家点任意一颗进入对应挑战。
- `PlanetSelect.PLANETS`：Volcanic 去掉 `hidden_from_star_map`；Frozen 和 Volcanic 都加上 `"pair": &"fire_ice"`。注册表顺序和 ID 不变。
- 轮播改成按**槽位**排：`_build_slots()` 把 pair 相同的星球放进同一个槽（`_slots` / `_planet_slot`）。`selected_index` 仍然是可见星球的下标（测试和其他逻辑不受影响）。
  - 左右键按槽移动；切到双子槽时，回到上次选的那颗（`_pair_choice`）。
  - 上下键在双子之间切换。
- 布局：原来是每个星球单独 tween，现在改为 tween 一个小数 `_scroll`，每帧 `_apply_layout()` 计算位置。
  - 双子沿椭圆轨道（`TWIN_ORBIT` 122×34）慢慢互相绕转（`TWIN_SPIN` 0.45 rad/s），基础缩放 0.62。前面的那颗稍大、层级更高。
  - 选中的那颗放大 1.1 倍并带选中光圈，另一颗略暗。
  - `_draw` 里为双子槽画一圈淡橙色的轨道线。
- `PlanetVisual._has_point`：只有点在星球圆盘内（半径 128）才算点中，避免两颗重叠时互相抢点击。
- 信息面板：双子槽的描述后面加一行 "FIRE & ICE TWINS · CLICK A PLANET TO SWITCH CHALLENGE"（中文：冰火星系 · 点击星球切换目的地；为了避开字体子集缺的"双""挑"）。位置指示器改成按槽位显示。
- 测试：`PlanetVisibilityTest` 重写（每颗星球都可见；槽数 = 星球数 - 1；冰冻槽里有火山双子；点击切换；信息面板跟随；左右来回后记住双子选择）；`PlanetLocateLaunchTest` 里三处"火山被隐藏"的断言改成"可见"。PlanetVisibility / PlanetLocateLaunch / DeveloperMode 都 PASS。
- 另外看到：研究名 "LONG-LONG-RANGE CELLS" 没有中文翻译（原来就是这样，不是这次改动造成的）。

## 89 · 远古巨龙 QTE 改用全游戏统一的 QteStyle（Claude，2026-11-01）

用户觉得巨龙 QTE 难看（以前是纯色圆弧加 fallback 字体的数字）。`AncientDragon` 第 4 步的覆盖层改用 `QteStyle`（和采矿、魔王一样）：
- 俯冲 QTE：两个翼腕和头部各一个白色半透明靶（半径 = qte_zone_radius × 0.82），带向内收缩的提示环，三个靶的相位错开。每次点中都有涟漪（`_qte_pop_at[part]`）；点满的部位弹一下后消失。不显示数字。
- 喷火蓄力：头部一个靶，提示环随蓄力进度越收越快；每次点击有涟漪（`_breath_pop_at`）。
- 玩家第一次遇到 QTE 时显示 CLICK 标签（`claim_click_hint`）。
- 点击判定和数值都没改（`route_qte_click` 只多记录涟漪时间）。DragonNestBattleRuntime / DragonNestPrototype 测试 PASS。
- 二阶段设计在等用户选择。

## 90 · 远古巨龙二阶段「暴怒王座」+ 每次换洞口吐浓烟 + 龙巢杂物随机化 + 龙蛋位置偏移（Claude，2026-11-01）

用户三个二阶段方案都要；浓烟改成"每次换位置都吐，持续 3 秒"；另外要求地图上的金币堆、宝石、敌人残骸等随机生成，龙蛋位置也稍微偏移。

**AncientDragon**（新状态 `PHASE_TRANSITION` / `SMOKE_BREATH` / `FIRE_EYES`，新信号 `phase_two_started` / `smoke_breath_resolved` / `fire_wyrms_summoned`）：
- **二阶段**：打断第 5 格（`PHASE_TWO_BREAKS`）后，`_finish_landing` 进入 3 秒咆哮转场（不受伤害，镜头震动，冲击波环，张嘴）。
  - 之后 `phase_two = true`：眼睛变成白热色，两眼往后喷火焰，头部有红色光晕（`_draw_phase_two_fx`）。
  - 喷火冷却 25 → **18** 秒（`PHASE_TWO_FIRE_BREATH_COOLDOWN`）。
  - 开发/测试接口：`force_phase_two()`、`skip_phase_transition()`。
- **浓烟吐息**：每次换洞口（`_update_relocation` 结束）都会触发，一阶段也算。
  - 先是 0.9 秒的吐气，然后 0.6 秒烟团滚向飞船；烟落下时 `set_weapon_attacks_enabled(false)`，飞船武器失灵 **3 秒**（`SMOKE_JAM`，和翼风共用 `_weapon_disruption_left`）。
  - 失灵期间飞船被浓烟笼罩（`_draw_smoke`）。
- **炎眼三龙**：二阶段进场 6 秒后第一次，之后每 35 秒（随 greed 缩放）一次。
  - 先是 1.4 秒双眼大火并画出三条预警线，然后从龙头扇形放出 3 条火焰龙（`spawn_fire_wyrms`）。
  - meta 为 `dragon_nest_boss_summon`，计入 extra_boss_spawned。
- 以上新状态中，`SMOKE_BREATH` / `FIRE_EYES` 可以受伤害；`PHASE_TRANSITION` 不行。

**新敌人 火焰龙**：`Scenes/Enemies/DragonNest/fire_wyrm.tscn` + `Scripts/Enemies/DragonNest/FireWyrm.gd`（无 class_name）。
- 数值：HP 5000，速度 38，地面单位，所有武器都能打。近战，攻击范围 26，每 0.25 秒 3 伤害 = 贴上飞船后 **12 HP/秒**。
- 外观：半透明火焰长蛇，身体跟随轨迹，带火舌，眼睛白热，前方一直喷火锥。
- 没有加进 EnemyCatalog，不会出现在普通波次里。

**孵蛋**：`DragonNestController` 监听 `phase_two_started`：地图 `set_raging(true)`，然后 `hatch_remaining_eggs()` —— 每个**没被偷空**的宝堆孵出 1 只幼龙（meta `dragon_nest_hatchling`，计入 boss summon）。
- `DragonHoard.hatch_egg()`：只能孵一次；孵化时有闪光和蛋壳碎片，之后只剩两半破蛋壳；宝堆照样可以偷。

**地图**（`DragonNestFixedMap`）：
- 大厅本体（平台、金河、城堡、洞口、地面）不变。以下按每局 seed 随机：散落的金币、金堆、宝石，以及残骸和战利品（骑士尸骸、肋骨、雕像头、石块、剑、宝箱、王冠、高脚杯、焦痕、爪痕；`_pick_props`，会避开着陆台、宝堆、金河，互相也不重叠）。
- 四个角落的巨物（巨龙头骨、金像、蛋窝、宝箱和火盆）随机换角并带偏移；火盆跟着宝箱角走（`BRAZIER_OFFSETS`）。
- seed 来源：`Battlefield.map_seed` 不为 0 时用它（测试可以固定），否则 `randi()`。注意 BattleMain 会把 Battlefield 自己的 seed 固定成 MAP_SEED，所以这里不能用 `get_map_seed()`。
- `set_raging()`：2.5 秒内渐变到满：整体红光、从着陆台向外蔓延的 11 条发光裂缝、金河冒泡沸腾、空中飘火星，火盆也变大。
- **龙蛋偏移**：宝堆位置加上 ±60 / ±45 的随机偏移，并且限制在离飞船 540 以内（`HOARD_MAX_REACH`），保证停在原地也偷得到。

**血条**：`BossHealthBar` 在 boss 的 `phase_two` 为真时换成红金主题 `ancient_dragon_rage`，副标题改为 THE HOARD BURNS。

**测试**：
- `DragonNestPrototypeTest`：第 5 次打断进入二阶段咆哮（期间不受伤害），之后才算二阶段；PASS。
- `DragonNestBattleRuntimeTest` 新增：换洞口后吐了一次浓烟，武器失灵，3 秒后恢复；二阶段 3 颗蛋孵化且只孵一次；喷火冷却 ≤ 18 秒；炎眼召唤出 3 条火焰龙。新增断言都通过。
- 唯一失败的 "optional guardians are outside scheduled enemy container" 是之前就有的：用 device 原文件跑也一样失败，应该和 Codex 最近的波次改动有关。

## 91 · 僵尸手臂 / 暴雪瓶 特效与图标（Claude，2026-11-01）

纯表现，玩法数值和逻辑未改（ZombieArmBlizzardTest、ArtifactSystemTest 均 PASS）。

- **图标**（`ArtifactVisual.gd` 新增 `_zombie_arm` / `_blizzard_bottle`，含剪影）：
  - 僵尸手臂：破袖口里伸出腐烂绿手，伤口露骨、缝线、滴绿液。
  - 暴雪瓶：软木塞烧瓶，瓶内暴风雪漩涡，瓶底结霜，雪花从瓶口飘出。
- **僵尸手臂弹**（`ZombieArmProjectile.gd`，class_name 和接口不变）：
  - 外观：飞行中翻滚的腐烂前臂，手指不断抓握，后面拖一串绿液尾迹。`ART_SCALE` 为 1.35，比普通子弹大。
  - 新 `Scripts/VFX/ZombieArmFx.gd`（无 class_name），三种模式：
    - `launch`：发射时一圈绿色灵质。
    - `hit`：命中时半透明大手合拢成拳，绿液飞溅，并崩出碎骨。
    - `fade`：飞到射程尽头时碎掉消散。
  - `_on_area_entered` 先调 super，确认这次真的命中了敌人才播放 hit 特效。
- **暴雪瓶光环**（`BlizzardBottleEffect.gd`）：
  - 在 radius 处画霜带和旋转的虚线边，加上 34 片环绕雪花和 5 道风痕。
  - 被减速的敌人由子节点 `BlizzardMarks` 绘制（top_level，z 8）：刚进圈时一圈雪花炸开，之后脚下有霜环，三颗冰晶环绕，头顶一片雪花。
  - 新增 `_chill_age`，随 `_affected` 同步增删。
- 备注：radius 100 只比船体半宽 96 大一点，实际上只有贴着船体侧边的敌人才会被减速，光环也基本压在船体边缘。如果要更明显，可以考虑加大 radius。

## 92 · 暴雪瓶半径 100 → 200（Claude，2026-11-01）

用户决定把暴雪瓶光环半径调到 200 px。
- 改动：`BlizzardBottle.tres` 的 radius 改为 200，description 同步改为 200 px；`zh_CN.po` 的 msgid / msgstr 同步更新；`BlizzardBottleEffect.gd` 中 radius 的默认值也改为 200。
- **测试改动**：`ZombieArmBlizzardTest` 的距离按新半径调整：圈内 boss 80 → 160，圈外敌人 150 → 250，离开光环 130 → 230。测试 PASS。

## 93 · 远古巨龙浓烟改为"致盲"，二阶段火焰龙随浓烟一起出现（Claude，2026-11-01）

用户反馈：原来召唤三条火焰龙时，炮台一直锁着 boss（锁定的目标不死、不出射程就不换），玩家没法处理火焰龙。改成：浓烟让炮台暂时失去目标、不能锁定，但仍然可以攻击；并且浓烟吐息的同时召唤三条龙。

- **`WeaponModule.target_lock_suppressed`**（新变量，默认 false）：为 true 时，`keep_or_find_target` 每次搜索（`target_search_interval`，0.2 s）都不保留当前目标，重新选最近的敌人；两次搜索之间照常跟踪和开火。
  - 所有走 `keep_or_find_target` 的武器都会受影响：机枪、矮人炮、激光、喷火器、融合武器、FlameLaser。手动炮台不受影响。
- **AncientDragon**：
  - 浓烟落下后不再调用 `set_weapon_attacks_enabled(false)`，改为 `_apply_smoke_blind(SMOKE_BLIND = 3.0)`：遍历飞船下所有 WeaponModule，设置 `target_lock_suppressed`；3 秒后 `_release_smoke_blind()` 恢复。boss 死亡或 `_exit_tree` 时也会恢复。新增查询接口 `is_ship_blinded()`。
  - 一阶段每次换洞口的浓烟同样改为致盲。换洞口时刚召唤的援军会成为最近的敌人，炮台会转过去打它们。
  - **二阶段**：每次浓烟落下时召唤 3 条火焰龙，换洞口的浓烟也算。另外每 35 秒（`FIRE_WYRM_COOLDOWN`，第一次在二阶段开始 6 秒后）主动吐一次浓烟；吐气期间双眼大火，并画出三条预警线（原 FIRE_EYES 的表现移到这里）。
    - 火焰龙生成在龙头前方 150 px，比 boss 的瞄准点更靠近飞船，所以致盲期间炮台会自动转向火焰龙。致盲结束后炮台锁定当时的目标，打完火焰龙再回去打 boss。
  - `start_fire_eyes()` 保留，现在等同于二阶段的 `begin_smoke_breath()`。`FIRE_EYES` 状态已不再进入（枚举保留）。
  - 新增 `FIRE_WYRM_MAX_ALIVE = 6`：场上火焰龙最多 6 条，浓烟只会补到这个数。
  - 罩住飞船的浓烟透明度从 0.6 降到 0.42，方便看清炮台转向。
- **测试改动**：`DragonNestBattleRuntimeTest` 中浓烟相关断言改为：吐浓烟后武器不停火、全部炮台致盲、3 秒后恢复；`start_fire_eyes` 进入 SMOKE_BREATH，2 秒后出现 3 条火焰龙；用 probe 武器验证致盲时会放弃 boss 改打最近的敌人；火焰龙数量上限 6。
  - 结果：新增断言全部通过，只剩之前就有的 "optional guardians…" 失败。DragonNestPrototype、WaveCap、ZombieArmBlizzard、LaserChainsaw、ManualTurretControl 均 PASS。

## 94 · 龙巢普通波次：龙的帅气出场和空战动作，杂兵数量约 ×3，大龙带两条小龙护卫，龙加速 +5 px/s（Claude，2026-11-01）

- **波次**（`DragonNestPlanetWaves.tres` 和 `DragonNestRules.WAVE_QUOTAS` 同步修改）：
  - 狗头人 20 → 97，巢蜥 18 → 46。
  - 波次排布：小龙只在第 2–4 波单独出现，第 10 波另有 2 条；大龙从第 5 波起每波 1 条，共 6 条。
  - 第 1–10 波计划生成数 58 → 154；另有 12 条小龙作为护卫跟大龙一起来（不计入 quota），小龙总数 15 → 17。
  - 第 1–10 波：`spawn_interval` 2.0 → 0.9，`maximum_simultaneous_enemies` 8 → 24。第 11 波 boss 不变。
- **速度**：young_dragon 45 → 50，greater_dragon 30 → 35。
- **护卫**：大龙计划生成时（spawn_origin 为空，即 scheduled）会在下一帧带出 2 条 young_dragon，meta 为 `dragon_nest_escort`，spawn_origin 为 `&"dragon_nest_escort"`。
  - `WaveManager._is_capped_dragon_request` 计算"计划内的龙同时最多 2 条"时排除护卫，和 boss summon 一样不占名额。这是 Codex 文件，只改了这一行。
- **DragonEnemy 空战**（只作用于 young / greater；守宝龙、远古巨龙不受影响，孵化的幼龙不播出场）：
  - **俯冲入场 DIVE_IN**：从高空高速飞来，速度最高约 4.2 倍；画面放大最多 1.55 倍、抬高 150 px，地面有一个随高度变小、变淡的影子，身后拖 4 帧橙色残影。
    - 飞到距船体 attack_range + 120 时开始减速下降。至少下降 0.9 秒；超过 7 秒还没到也会强制结束。
  - **展翼咆哮 FLARE**：大龙 0.95 秒、小龙 0.6 秒。双翼张开、昂头张嘴，打出冲击波圈和吼叫线；大龙会让镜头震动。
  - 入场期间不攻击，但可以被打。
  - 护卫入场时在大龙身后两侧（-150, ±150）保持编队，大龙咆哮时一起咆哮。
  - **战斗 FIGHT**：进入射程后绕船飞行（切向速度等于移动速度，保持在约 85% 射程处），每 5–9 秒换一次方向。
    - 小龙每 4.5–7 秒做一次 0.45 秒的 4 倍速突进，带残影。
    - 大龙每第 4 次攻击改为扇形三连火球：0.6 秒前摇，嘴部发光并画出三条预警线；每发是普通伤害的 60%，夹角 ±0.32 rad。
  - 新接口：`is_air_entrance_playing()`、`skip_air_entrance()`。
- **测试改动**：
  - `DragonNestPrototypeTest`：数量 58 → 154，各兵种总数 {97, 46, 5, 6}，小龙 / 大龙速度 50 / 35。
  - `DragonNestWaveCapTest`：统计计划内的龙时排除护卫；新增"大龙带 2 条护卫"断言。
  - 结果：两项 PASS；DragonNestBattleRuntime 只剩之前就有的 "optional guardians…" 失败。
  - 另用一个临时脚本验证了入场 → 咆哮 → 绕船飞行，以及扇形火球确实发出 3 发。

## 95 · 龙巢开局视野恢复为普通大小（Claude，2026-11-01）

用户：开局视野太大，要调回去，选了"和岩石星球一样"。
- `Palette` dragon_nest 新增 `"view_extra": 0.0`；`map_extra` 仍为 300，因为龙巢的布局（洞口、宝堆）需要这么大的地图，地图尺寸不变。
- `BattleMain.apply_planet_view()`：主题有 `view_extra` 时用它决定镜头放大，没有时仍用 `map_extra`。其他星球不受影响。这是 Codex 文件，只改了三行。
- 结果：开局镜头 zoom 从 0.842 变为 1.0，视野宽 1600，原来是 1900。远古巨龙出场时仍会再拉远 600，视野宽从 2500 变为 2200，左右洞口仍在画面内。敌人刷在视野边缘，所以会离得近一些。
- 测试：GraveyardMapTest PASS；DragonNestBattleRuntime 只剩之前就有的那条失败。

## 96 · 装备魔法物品后不关闭选择面板（Claude，2026-11-01）

用户：装备魔法物品后，魔法物品面板不要因为装备完成就消失。
- `LoadoutPanel`：飞船 / 模块魔法物品选择面板里的 EQUIP 和 REMOVE 不再调用 `_close_picker()`，改为 `_after_artifact_pick()`（即 `_rebuild()`）。所选槽位保持打开，面板原地刷新，显示新的 REMOVE 项和"IN USE"标记。关闭面板用 ✕，或再点一次该槽位。
  - 装备后会自动跳到下一个已解锁的空槽位（`_advance_ship_artifact_picker` / `_advance_module_artifact_picker`），方便连续装备；没有空槽位就停在当前槽位。
  - 如果槽位因此失去解锁条件（槽位本身锁定、只是因为装着东西才显示的情况下 REMOVE），面板仍会照常关闭。
- `StoragePicker.show_entries()`：刷新同一个面板时保留网格的滚动位置；分类标签原本就会保留。
- 芯片选择器（ChipSystemV2Test 第 221 行"picker closes after installing"）不受影响。
- 用临时脚本验证过：EQUIP 后面板保持打开，并装上了所选物品。

## 97 · 七个新魔法物品的图标和特效；双子恶魔的额外弹体和原弹并排飞（Claude，2026-11-01）

**图标**（`ArtifactVisual.gd`，均含剪影）：
- 增幅器 amplifier：铜喇叭喷出紫色声波，旁边一个 "+1"。
- 仙女的诅咒 fairy_curse：粉色蝶翼小仙女，手里捧着紫色诅咒骷髅，周围有闪光。
- 快沙漏 fast_hourglass：青色沙漏，沙子快漏完了，左侧有速度线。
- 慢沙漏 slow_hourglass：琥珀色沙漏，沙子几乎都还在上面，外面一圈时钟弧和箭头。
- 重弹 heavy_shell：粗铁炮弹，弹头烧红，带箍和重量刻线。
- 放大镜 magnifying_glass：铜框放大镜，镜片里一颗放大的子弹。
- 树人之魂 treant_soul：绿色灵火，两只亮眼，底部围一圈树叶。

**特效**（纯表现，不改玩法）：
- `WeaponModule` 新增信号 `projectile_spawned(projectile)`，MachineGun / DwarfCannon / FusionWeapon 每生成一发弹体发一次。这几个是 Codex 文件，每个文件只加了一行 emit。
- `ArtifactManager.attach_battle_effects()`：每个模块魔法物品的 effect 旁边再挂一个 `Scripts/VFX/ArtifactFx.gd`；不需要表现的物品 `setup()` 返回 false，直接 free 掉。
- 新文件 `ArtifactShotDecor.gd`：挂在弹体下的子节点。
  - 增幅器：紫色电弧在弹体周围噼啪闪动。
  - 快沙漏：青色速度拖线。
  - 慢沙漏：琥珀色时钟环（指针在转），身后飘落沙粒。
  - 重弹：弹头红热，身后拖烟。
  - 放大镜：玻璃镜框，带一个绕圈移动的高光。
  - 树人之魂：只有带加成的那一发才挂，绿色光晕加一串飘落的树叶。
  - 弹体被 free 时（命中或到达射程），重弹 / 增幅器 / 树人之魂会留下一个命中爆点。
- 新文件 `ArtifactBurstFx.gd`：
  - 重弹：暗色冲击环加碎屑。
  - 增幅器：紫色星芒。
  - 树人之魂：树叶炸开，飘起一个 "x2"。
  - `treant_flash`：激光 / 电锯 / 喷火器没有弹体，带加成的那次攻击在枪口闪一下绿光。
  - 仙女的诅咒：再生模块治疗时，粉色脉冲环扩散到治疗半径，同时向范围内每个敌人射出一道闪光，敌人身上炸开粉色星光。
- 树人之魂存着的充能（最多显示 6 个）会以绿色叶片的形式绕炮台旋转。
- 喷火器没有单独的弹体，所以快沙漏 / 慢沙漏 / 放大镜装在喷火器上时没有弹体特效；激光的光束已经会被放大镜加粗，没有另加特效。

**双子恶魔并排**：
- `WeaponModule.get_volley_lateral_spacing(r) = max(r × 3, 14)`。机枪和矮人炮的横向间距从 `max(r × 1.25, 4)` 改为这个值，原来两发只差 5 px，看起来像一发。
- `FusionWeapon`：原本单发的武器，加出来的弹体和原弹左右对称排开；本身是扇形散射的武器，原扇形不变，多出来的弹体放在中线两侧，以前是和中间那发完全重叠。
- 测试：`SturdyStoneTwinDemonTest` 新增机枪、矮人炮两发间距 ≥ 14 的断言。用 /tmp 存档路径跑是 PASS；原测试写死的 /private/tmp 路径在沙盒里不可写，这个问题之前就有。ArtifactSystem、TreeArtifacts、MagicShopAndProjectileSpeed、FusionArtifactCompatibility、ZombieArmBlizzard 均 PASS。

## 98 · 基地商店外观：流浪商人地毯摊（Claude，2026-11-01）

用户从商店外观方案里选了 B（地毯摊），要求去掉阳伞。
- 新文件 `Scripts/Base/MerchantRug.gd`（无 class_name，和 RuneShrine 一样是静态 draw）：
  - 摊位：一张红底、金边、蓝心、菱形花纹的流苏地毯，上面摆着 5 瓶会闪烁的药水、一卷卷轴和一把匕首。
  - 商人：后面坐着紫色兜帽的流浪商人，眼睛发光、会眨眼，叼着烟斗冒烟，身体轻微起伏；身后是巨大的行囊（铁锅、水壶、铺盖卷），左边挂一盏会闪烁的灯笼。
  - 悬停：外框描边，药水和商人的眼睛变亮。
  - 也支持 `guide` 引导圈参数，目前没有调用。
- `AsteroidHangar._draw_magic_shop_placeholder()` 改为调用 `MerchantRug.draw(_live, _time, hovered == HOTSPOT_MAGIC_SHOP)`；`MAGIC_SHOP_RECT` 点击区和 SHOP 标签不变。这是 Codex 文件，只改了这一处，外加一行 preload。
- 灯笼放在左边，避开摊位右上方的雪人。
- 商店内部 UI 还没选。

## 99 · 商店界面：流浪商人地毯摊（Claude，2026-11-01）

用户从商店内部 UI 方案里选了 1（地毯摊陈列）。`MagicShopPanel.gd` 整体重写，购买逻辑仍全部调用 ArtifactManager。
- **布局**：按 1460×760 排版，用 `_fit_frame()` 等比缩放并居中到 UI 根节点。打开时淡入；点框外关闭，和原来一样。
- **商人**（`MerchantView`）：左侧是正面的兜帽商人，眼睛发光并会眨眼，烟斗冒烟，身体轻微起伏。
- **对话气泡**：气泡就是原来的 `_status_label`。开场说"嘿嘿……亮闪闪的矿石，换亮闪闪的宝贝。"；买成功说"成交！好货就该配好炮台。"，后面接原来的"道具已加入收藏…"；未定价说"这件还没定价呢。"；矿石不够说"矿石不够啊，朋友……"。
- **地毯**（`RugView`）：商品卡片（`ShopCard`）横排在地毯上，可以横向滚动，滚动条隐藏。每张卡片是布垫上放一个物品图标，上方用细绳吊一张会轻晃的价签，没定价时写"待定"；悬停时卡片抬起、发光；选中时有稀有度色的圈；已拥有的商品盖一个斜着的"已拥有"印章。
- **信息条**：地毯下部显示大图标、名称、稀有度和描述，右边是金币形的购买按钮（`CoinButton`），上面写"购买"和"◆ 价格"；买不了时变灰，已拥有时写"已拥有"。按钮的 `text` 仍然是 "BUY · %d ORE" / "PRICE TBD" / "OWNED"，只是不显示出来，测试和旧接口照常可用。
- **标题区**：标题"流浪商人"；有未定价商品时显示原来的"价格待定…"提示；右上是矿石数和 ×。
- 新增接口：`get_item_cards()`、`get_buy_button()`、`select_item(i)`。原来的 `_items` 从 VBoxContainer 改成了 HBoxContainer。
- **测试改动**：`MagicShopAndProjectileSpeedTest` 不再通过 `_items` 去找行里的按钮，改为 `get_item_cards()` 数到 5 张，再对每张 `select_item(i)` 后检查 `get_buy_button()` 是禁用的 PRICE TBD。测试 PASS。
- `zh_CN.po` 新增：WANDERING MERCHANT、BUY、TBD，以及四句商人台词。
- 物品价格仍然都是 -1（待定），截图里的 300 / 900 是测试时临时设在内存里的。

## 100 · 修复：敌人站在挖矿矮人旁边却不攻击（Claude，2026-11-01）

用户反馈：所有星球都有这个问题，矮人挖矿时附近的敌人不攻击矮人。
- **原因**：`BasicEnemy._physics_process` 的矮人分支用严格比较 `distance <= _dwarf_attack_reach()` 来判断是否开始攻击，而移动是 `move_toward(..., distance - reach)`。浮点误差会让敌人停在离攻击距离差一点点（几微米）的地方，比较永远不成立；它每帧只再挪一点点，所以一直贴着矮人不出手。离地图原点越远误差越大，实际战斗里坐标在 2000 左右，几乎每次都会出现。打飞船的分支早就加了 `ATTACK_RANGE_TOLERANCE`（0.5），矮人分支漏了。
- **修复**：矮人分支改为 `distance <= _dwarf_attack_reach() + ATTACK_RANGE_TOLERANCE`。攻击计时器结算时本来就带这个容差，两边现在一致。
- **复现**：在真实的 BattleMain（岩石星球）里派矮人去挖一个真实的矿，在它周围放小石头怪、哥布林、狗头人、雪怪。修复前小石头怪、狗头人、雪怪停在距离 = 攻击距离处，`_is_attacking` 为 false，只有哥布林在打；修复后四个都在攻击，矮人被打死。
- **测试**：`DwarfEnemyTargetTest` 新增"敌人离攻击距离只差 0.0004 时仍会开始攻击"。用旧代码跑这条会失败，新代码 PASS。

## 101 · 胜利后从结算界面回基地，飞船也会降落（Claude，2026-11-01）

用户：从结算界面返回基地时，要有飞船落下的动画。
- 原状：撤离（`_on_evacuation_completed`）和坠毁（`_on_return_to_base_pressed`）回基地时都会设 `ShipLaunchController.landing_pending_at_base = true`，BaseMain 进场时据此播放 `play_landing()`；唯独胜利结算的"返回基地"（`_on_completion_return_to_base_pressed`）没有设，所以飞船直接出现在停机坪上。
- 修复：`_on_completion_return_to_base_pressed` 切场景前设置这个标志，切换失败时复原。BattleMain 是 Codex 的文件，只改了这一处。
- ResultBoardTest PASS。

## 102 · 暴风雪音效：更小声，听起来是风而不是雨（Claude，2026-11-01）

用户反馈：暴风雪音效太吵，而且听起来像下雨，不像暴风雪。
- **原因**：旧的 `Assets/Audio/Weather/blizzard_loop.wav` 能量大部分在 1.5 kHz 以上（1.5–4k 占 32%，>4k 占 24%），是"沙沙"的白噪声，听起来像雨。
- **新素材**：`blizzard_loop.wav` 重新合成，22050 Hz 单声道，8 秒无缝循环；`.import` 不变，仍为 loop_mode 2。
  - 构成：棕噪声低频轰鸣；6 条 300–820 Hz 的窄带啸叫轮流起伏，形成风声忽高忽低的呼啸；少量 500–1400 Hz 的气流声；整体每 4 秒涌起一阵阵风。最后再做 2.6 kHz 低通。
  - 能量分布：<500 Hz 占 53%，500–1500 Hz 占 45%，1.5 kHz 以上只剩约 1%。
  - 循环衔接：滤波时把信号首尾拼接三份、只取中间一段，接缝处的跳变和正常波形起伏一样大，听不出接口。
  - 素材本身的 RMS 从 0.219 降到 0.112，约 -6 dB。
- **音量**：`WeatherSfx` 中普通暴风雪 -11 → -14 dB，BOSS 暴风雪 -5 → -9 dB。加上素材本身变小，普通暴风雪比原来小约 9 dB。
- 生成脚本没有放进项目；如需再调，可以按上面的参数重新生成。ForestRainTransitionTest PASS。
