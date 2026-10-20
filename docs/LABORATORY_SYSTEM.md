# GreedMiner Laboratory and Chip Architecture

## Editable research content

Open `res://Resources/Research/ResearchConfiguration.tres` in the Godot Inspector. Its `Categories` array contains the six Laboratory categories. Its `Definitions` array contains the implemented per-weapon damage research projects.

Each `ResearchDefinition` has stable IDs, category and target IDs, maximum level, a cost configuration, optional unlock requirements, an effect Resource, and enabled/implemented flags. Normal research content and balance changes should be made in this Resource rather than in `ResearchManager.gd`.

Weapon damage uses `WeaponDamageResearchEffect`. Its `Damage Bonus Per Level` is additive relative to the untouched weapon `basic_damage`. `ResearchCostConfig` exposes the base (200), linear (30), and quadratic (40) cost coefficients. Levels 1→9 therefore cost 8,040 Ore in total.

Each weapon definition contains configurable chip-slot milestones at Levels 10, 20, and 30. Each installed weapon instance has its own chip assignments while the number of available sockets comes from its weapon research level. Slot availability is derived from current research progress, so existing saves do not need redundant unlock flags.

## Runtime interfaces

- `ResearchManager.get_level(id)` and `get_upgrade_cost(id)` expose progression data.
- `ResearchManager.purchase_research(id)` performs validation, ore spending, rollback on save failure, persistence, and level signals.
- `ResearchManager.get_weapon_stat_modifiers(type_id, stat_id)` is the presentation-independent effect interface.
- `ResearchManager.get_weapon_chip_slot_count(type_id)` exposes reached milestone rewards.
- `StatModifierPipeline` deduplicates modifiers by source ID and always calculates from an original base value.

The minimal `LaboratoryPanel` reads these interfaces. Energy and Mining show their functional one-time installation unlocks. Shield, Weapon Skills, and Chips remain unavailable placeholders and cannot spend ore.

## Energy and Mining installation unlocks

Energy and Mining each contain one implemented, one-time research project:

- `energy_install_slot_unlock`
- `mining_install_slot_unlock`

Both start at Level 0 (locked), cost 500 stored Ore, and finish permanently at Level 1. Their `ModuleInstallationLimitResearchEffect` resources expose the initial limit (1), unlocked limit (2), and button label. The fixed purchase price comes from each definition's `ResearchCostConfig`, so changing `Base Upgrade Cost` in `res://Resources/Research/ResearchConfiguration.tres` changes the authoritative transaction without code edits. Linear and quadratic coefficients remain zero for these unlocks; the weapon cost formula is not used.

`ResearchManager.get_module_installation_limit(module_type_id)` is the gameplay-facing interface. `Ship.install_module()` and `Ship.replace_module()` enforce it before committing a loadout change. Removing a module only frees a grid cell; research permission remains in the research save section. Old loadouts already above a newly introduced limit are restored unchanged and reported with a warning, while further additions of that category are blocked.

## Chip framework

Open `res://Resources/Chips/ChipConfiguration.tres` to tune chips. Four Basic chips exist (Attack +1 flat damage, Attack Speed ×1.2 fire rate, Damage ×1.2 damage, Skill −1 s cast time), each crafted for 500 Ore. Research milestones at weapon Lv 10 / 20 / 30 open up to three chip sockets for that weapon type.

### Where things happen (UI)

- **Laboratory › Chips** only manufactures: blueprint list, CRAFT · 500 Ore, and the quality-upgrade entry (shows QUALITY MAX while no higher quality is configured). Crafted chips go to the Warehouse.
- **Hangar (Loadout panel)**: select an installed turret → its detail page shows STATS plus three sockets (installed / empty "+" / locked "RESEARCH LV xx"). Clicking a socket opens a bottom picker drawer: INSTALL idle chips, MOVE chips from another turret, or REMOVE the current one. Gold segments on the stat bars show the chip bonus.
- **Warehouse** (bottom-left button in the base overview, `Scripts/UI/WarehousePanel.gd`): ALL / RESOURCES / CHIPS tabs, compact grid with divider lines, orange tag = installed on turret R·C, otherwise IDLE. Idle chips can be scrapped (two clicks) for 50% of the Ore invested.

### Per-turret sockets (ChipManagerV2)

Chips belong to one installed turret, keyed by ship cell: `loadout.assignments["turret.R.C.I"] = instance_id`. Two turrets of the same type can carry different chips. The socket count of a cell is `get_unlocked_weapon_slot_count(weapon type in that cell)`.

- `get_turret_weapon_type(cell)`, `get_turret_slot_count(cell)`, `get_turret_chip(cell, i)`, `get_turret_chips(cell)`
- `equip_turret_chip(cell, i, instance_id)` — an instance installed elsewhere moves here; `unequip_turret_chip(cell, i)`
- `get_instance_location(instance_id)` → cell or (-1, -1); `get_instance_slot_index(instance_id)`
- `get_instance_ore_invested`, `get_scrap_refund`, `scrap_chip(instance_id)` (idle only, refunds `SCRAP_REFUND_RATIO` = 0.5)
- `get_weapon_slot_unlock_level(type, i)` — research level that opens socket i (UI lock text)
- `get_stat_modifiers(context)` accepts `{"weapon_instance": WeaponModule}` (resolved through `Ship.get_module_cell`) or `{"cell": Vector2i}` for UI previews. Weapons outside a ship get no chip bonus.

`ShipLoadout` emits `cell_changed(cell, old_path, new_path)` and `cells_swapped(a, b)`. `Ship.swap_modules` uses `ShipLoadout.swap_cells`, so chips travel with a moved turret; removing or replacing a module returns its chips to the Warehouse.

Save version 3. Older saves migrate automatically: V1 chip-type assignments become instances, and V2 weapon-type sockets (`weapon.machine_gun.1`) move to the first installed turret of that type (row-major); if none is installed the chip stays idle.

## Persistence

`ProgressionStore` saves versioned sections to `user://greedminer_progression.json`. Resource storage, research progress, and chip state own separate sections so older saves and unrelated data remain intact.
