# Dragon Nest Planet V1

Dragon Nest is a deterministic, low-density 11-wave expedition using the existing `BattleMain`, `WaveManager`, ship damage, targeting, hostile projectile, Ore, evacuation, and progression systems.

## Runtime ownership

- `DragonNestController` owns the three fixed hoards, optional guardians, expedition Greed, fixed layout, Dragon Nest HUD, and development controls.
- `WaveManager` owns the exact 58 regular scheduled enemies and the Wave 11 Ancient Dragon. It holds scheduled Young/Greater Dragon requests while two scheduled dragons are active.
- Guardians are deliberately outside the `Enemies` wave container and never gate wave clear or planet completion. While sleeping they are removed from weapon targeting, ignore damage, and have no projectile collision. Treasure excavation wakes the linked guardian, restores targeting/collision, and its attacks and damage intake become active with 50% damage reduction.
- Boss reinforcements are inside `Enemies`, tagged `dragon_nest_boss_summon`, counted separately, and must be defeated before the final wave clears.
- `AncientDragon` owns the ten real 15,000-HP gates (150,000 total), nine mandatory dives, Fire Breath, Wingstorm, summon triggers, and balance metrics.
- `BasicEnemy.movement_type` separates `WALK` and `FLYING` enemies for future ground-only and air-only weapon filters. Young, Greater, and Ancient Dragons are flying enemies; Kobolds and Nest Lizards walk.

## Public gameplay/debug interfaces

- `DragonNestController.set_greed(value)` updates all live guardians and the live Ancient Dragon without stacking modifiers.
- `DragonNestController.get_live_guardian_count()` and `get_pending_scheduled_count()` expose debug accounting.
- `AncientDragon.get_segment_remaining_hp()`, `get_boss_state_name()`, `get_qte_status()`, `get_next_special_cooldown()`, and `get_balance_metrics()` are presentation/debug APIs.
- `BasicEnemy.is_flying_enemy()` exposes the movement layer, and `get_weapon_damage_phase()` lets ramping weapons reset at protected boss phase changes.
- `AncientDragon.route_qte_click(world_position)` consumes input only inside active dragon zones. `BattleMain` calls it before unhandled mining/world input.
- `DragonHoard.route_click(world_position)` consumes input only in the active hoard region; clicks elsewhere continue to other systems.

## Playtest controls

Enable Developer Mode and press F12. `Start Dragon Nest` launches the expedition without changing permanent planet completion. Inside Dragon Nest, press F11 to reveal the normally hidden test panel; it can jump to Waves 1–11, spawn both dragon sizes, set Greed, set the boss segment to 1 HP, trigger Dive or Fire Breath, spawn reinforcements, heal/set ship HP, and reset the session.

Treasure stealing: click a hoard to begin its 2.5-second excavation, then click the three highlighted targets. Starting excavation is the only event that wakes that hoard's guardian, even if the attempt expires. Five successes deplete a hoard.

Visuals are intentionally primitive placeholders for later presentation work.
