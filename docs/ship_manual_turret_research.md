# Ship research and manual turret control

The Ship laboratory tree is defined in `Resources/Research/ShipTree.tres`; its costs and effects are in `Resources/Research/ResearchConfiguration.tres`.

- `ship_max_hp_1`: +50 maximum hull HP, 100 Ore.
- `ship_auto_regeneration_1`: 5 HP every 10 seconds in battle, 100 Ore; requires the first hull node.
- `ship_air_conditioning_1`: Frozen/Volcanic access, 250 Ore; requires regeneration.
- `ship_max_hp_2` and `ship_max_hp_3`: +10 maximum hull HP each, 500/750 Ore; follow air conditioning in order.
- `ship_magic_slot_1`: first ship artifact slot, 500 Ore; requires the first hull node.
- `ship_power_1` and `ship_style_unlock`: +1 built-in Power and Hangar ship style, 500 Ore each; require the artifact slot.
- `ship_manual_turret_control`: 1000 Ore; requires both built-in Power and ship style.

`ResearchManager.is_manual_turret_control_unlocked()` is the gameplay-facing unlock check. `BattleMain` creates `ManualTurretController` only when that check is true. The controller uses `configure(ship)`, `activate_weapon_control(weapon)`, and `deactivate_manual_control()`. It is disabled at every battle end. Clicking a turret toggles it; clicking another switches turrets; right-click or Esc returns to automatic fire. No artifact equipment is involved.

Goblin Glove is removed from the artifact registry and Verdant mining chest pool. On reload, the existing `ArtifactManager` sanitization removes obsolete glove ownership/equipment while preserving other artifacts. No Ore compensation is granted.

The reticle is functional placeholder presentation. Claude Code may restyle it without changing the controller or the research interface.
