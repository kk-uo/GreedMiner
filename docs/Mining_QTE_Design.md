# Mining QTE System (v0.7)

Optional bonus events that happen while Mining Modules work during a battle.
They never pause combat, never stop normal mining, never disable weapons.
Everything happens in the battlefield, attached to the triggering module —
there are no separate panels.

## Files

| File | Role |
|---|---|
| `Scripts/Mining/QTE/MiningQteConfig.gd` + `Resources/Mining/MiningQteConfig.tres` | All timing / reward / trigger values (Inspector-editable). |
| `Scripts/Mining/QTE/MiningQteManager.gd` | Global coordinator: one global scheduler, one-at-a-time lock, reward formula, cleanup, developer hotkeys. Node `MiningQteManager` in `Scenes/Battle/BattleMain.tscn`. |
| `Scripts/Mining/QTE/MiningQteEvent.gd` | Base event: lifecycle, single-claim payout (`_reward_for`, `_pay`, `paid_total`), click hit-testing. |
| `Scripts/Mining/QTE/OreBurstEvent.gd` | QTE 1 — Ore Burst (rapid clicking). |
| `Scripts/Mining/QTE/PrecisionMiningEvent.gd` + `MiningSkillCheck.gd` | QTE 2 — Precision Mining and its arc skill check (world space, above the module). |
| `Scripts/Mining/QTE/SalvageDiscoveryEvent.gd` | QTE 3 — Salvage Chest (unchanged behaviour). |
| `Scripts/Mining/QTE/MiningQteVisual.gd` | Presentation only: "!" marker, chest, ore chips, compact world-space text/plates. |
| `Scripts/Modules/Mining/mining_module.gd` | `get_effective_ore_per_second()`, `play_qte_burst()` and `play_qte_impact()` (Ore Burst click punch). Ore production unchanged. |
| `Scripts/Modules/Mining/MiningDrillVisual.gd` | Drill drawing; `draw_module(..., impact)` draws the click punch (shake, smaller bit, flash) without touching the node transform. |
| `Tests/MiningQteTest.tscn` | Headless test for every rule below. |

## The three events

All rewards are `triggering module's effective ore/s × seconds`
(`MiningQteManager.calculate_reward_for_seconds`), so mining upgrades carry
over. Ore goes into the normal mission pool (`ResourceManager.add_mission_ore`).

**QTE 1 — Ore Burst (rapid clicking).**
1. A yellow hexagonal "!" sits above the Mining Module for `marker_lifetime`
   (6 s). Ignored → expires, nothing paid.
2. Clicking the "!" starts `burst_duration` (5 s) of clicking on the module
   itself. The activation click does not pay.
3. Each valid click pays `burst_reward_seconds_per_click` (5 s) of production
   at once. A click is valid only if at least `burst_click_cooldown` (0.1 s)
   passed since the previous valid one; faster clicks are ignored, not
   queued. Only real press events count — holding the button does nothing.
4. Each valid click: drill punch + jolt + flash (0.11 s), 6 gold ore chips
   bursting out (0.45 s, visual only), a rising "+X" (0.65 s).
5. A compact counter above the module shows `ORE BURST / +N Ore / 3.2s`.
6. At the end: `ORE BURST COMPLETE / TOTAL +N Ore` for 1.3 s. This is a recap
   of ore already paid — never a second payout. Outcome is `success` with at
   least one click, `failed` with none.
Clicks on the module during the burst are consumed, so they never reach enemy
popping or turret selection.

**QTE 2 — Precision Mining (arc skill check).**
1. Round-badge "!" above the module for 6 s. Ignored → expires, nothing paid.
2. Clicking it shows an arc right above the module (`MiningSkillCheck`,
   a child of the event). Near the screen edge the arc is nudged back inside
   the view. Warning: `precision_warning_duration` (2 s), "GET READY" +
   countdown, arc dimmed.
3. A needle sweeps the arc once (`arc_sweep_degrees` 240° at
   `needle_speed_degrees` 240°/s ≈ 1 s). Green Success region
   (`success_zone_degrees` 60°) at a random spot in
   [`zone_min_start_degrees`, `zone_max_start_degrees`] (clamped to fit);
   gold Perfect region (`perfect_zone_degrees` 12°) centred inside it.
4. One attempt: **Space** or a left click anywhere on the battlefield (on the bar or on empty ground; HUD buttons keep their clicks).
5. Rewards: Perfect `precision_perfect_reward_seconds` (120 s), Success
   `precision_success_reward_seconds` (60 s), Failed / no input
   `precision_failed_reward_seconds` (10 s) — paid once.
6. Feedback near the module: `PERFECT! +120 Ore` (gold pulse),
   `SUCCESS! +60 Ore` (green), `FAILED +10 Ore` (grey). Values shown are the
   actual paid amounts.

**QTE 3 — Salvage Chest.** Unchanged: a crate pops out of the module, lands
160 px from the ship centre, waits `salvage_lifetime` (30 s, blinking at the
end); clicking it pays `reward_seconds` (30 s) of production. No minigame.

## Global scheduling

One timer in `MiningQteManager._process` for the whole ship:
- An event is **guaranteed every 30 s**: first at `initial_delay` (30 s),
  then every `check_interval` (30 s), with `chance_per_check` = 1. The timer
  keeps running during events.
- If a check lands while an event is still active, the next event starts as
  soon as that one ends (`start_when_free`; at most one waiting, never
  stacked). Set it to false to skip such checks instead.
- Each roll picks one random eligible Mining Module (installed, in the tree,
  `mining_enabled`) and one type by weight — `weight_ore_burst` 45 /
  `weight_precision` 40 / `weight_salvage` 15.
- More Mining Modules never increase the frequency (one roll per check).
- Optional `cooldown_after_event` (default 0) delays the next check after an
  event ends.

`try_start_event(type, module)` starts an event directly and obeys the lock;
`set_next_check_in(seconds)` reschedules the next check.

### Global one-QTE rule

Only one event exists across the ship (`max_concurrent_events` = 1). These
all hold the lock: a waiting "!", the Ore Burst clicking phase, the Precision
warning and arc check, a chest popping out or waiting. The lock is released on
`resolved` — success, failure, expiry, cancellation. Result text, summaries
and particles that outlive the event don't hold it.

Cancellation (no further payout):
- Battle end / defeat / evacuation: `BattleMain` calls `shutdown()`.
- Triggering module removed or freed: cancelled the next frame.
- Scene change: `_exit_tree` resolves everything as cancelled.
- Arc removed from outside: counted as a failed check.

## Developer controls

In debug builds with Developer Mode (`DeveloperCommands.is_available()`),
during a battle: **F6** Ore Burst, **F7** Precision Mining, **F8** Salvage
Chest on a random Mining Module. They respect the single-event rule and do
nothing in release builds.

## Input handling

- World clicks ("!", module during a burst, crate, arc) use `_unhandled_input`
  on the event / arc nodes with `make_input_local`; only hits are marked
  handled, so other clicks reach the battle (enemy popping, turret range).
- Space is consumed only while the arc needle is moving.
- Nothing pauses the tree or changes `Engine.time_scale`.

## Tests (`Tests/MiningQteTest.tscn`)

Covers: config defaults; Ore Burst activation, exact 5 s, 5 s per click,
0.1 s cooldown, holding the button, real clicks on/off the module, impact and
chips, counter, no double payout, expiry, idle burst; Precision warning,
arc placement above the module, Perfect 120 / Success 60 / miss 10 / timeout
10, Space and arc click, ignored prompt pays nothing, rate scaling, centred
Perfect region, region always fits; Salvage click + expiry; global lock;
scheduler frequency independent of module count; skipped (not queued) checks;
45/40/15 weights; debug keys; mining/combat continue; cleanup on module
removal, ship destroyed, planet completed, scene free, evacuation.

## Extension points

- New event types: subclass `MiningQteEvent`, add a `TYPE_*` constant, a
  weight in the config and a branch in `MiningQteManager._create_event`.
- Per-outcome rewards: override `_reward_for(result)`.
- Salvage loot tables: replace the reward in `SalvageDiscoveryEvent.open()`.
- Per-planet tuning: give BattleMain's manager a different `MiningQteConfig`.
