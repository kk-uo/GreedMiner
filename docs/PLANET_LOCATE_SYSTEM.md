# Planet Locate (replaces expedition energy and fuel)

Expedition energy (buying "batteries" with ore) and Energy Module fuel capacity
were removed. Ore is now spent on research, chips and **locating planets**.

## Rules

- Each planet in `PlanetSelect.PLANETS` may define `locate_cost` (ore).
  - Rocky Planet: 0 (always located).
  - Verdant (Goblin) Planet: **250 ore**.
  - Frozen / Volcanic: still `unlocked = false` (coming soon), cannot be located.
- On an uncharted planet the deploy button reads **PRECISE LOCATE · ◆ cost**.
  Pressing it spends the ore once (atomic, refunded if the save fails), plays a
  lock-on reticle, and the button becomes **DEPLOY**.
- Launching only needs a located planet and an operational loadout
  (at least one Energy Module and power consumption ≤ capacity). Launching
  costs nothing.
- Old saves: a planet that was already cleared counts as located.

## Interfaces

- `WeaponUnlockManager.is_planet_located(planet_id, locate_cost) -> bool`
- `WeaponUnlockManager.locate_planet(planet_id, locate_cost) -> bool`
- `WeaponUnlockManager.planet_located(planet_id)` signal
- Saved in the `weapon_unlocks` section as `located_planets`.
- `PlanetSelect.evaluate_launch_requirements(planet, energy_profile, stored_ore)`
  returns `unlocked, located, locate_cost, can_locate, missing_ore,
  loadout_valid, eligible`.

## Removed

- `ResourceManager.stored_energy`, `stored_energy_changed`, `purchase_energy`,
  `fill_energy_to_capacity`, `try_consume_stored_energy`,
  `restore_stored_energy`, `get_energy_unit_price`; `EconomyConfiguration`.
- `ShipModule.get_fuel_capacity`, `EnergyModule.fuel_capacity`,
  `total_fuel_capacity` (the `Ship.energy_changed` / `totals_changed` signals
  lost their first argument).
- `EnergyPurchasePanel` → replaced by `Scripts/UI/OrePanel.gd`.
- `Tests/EnergyPurchaseLaunchTest` → replaced by `Tests/PlanetLocateLaunchTest`.
