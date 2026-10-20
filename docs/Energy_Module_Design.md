> **Update:** fuel and purchased expedition energy were removed. Energy Modules now only supply power (and future expansion capacity); planets are unlocked with ore instead (see `PLANET_LOCATE_SYSTEM.md`). Fuel notes below are historical.

# Energy Module v0.1

## Purpose

The Energy Module is a one-cell ship module that supplies independent fuel and
power capacities. It also exposes expansion capacity for later research without
changing the current 3×3 grid.

## Basic Energy Module attributes

| Attribute | Value |
| --- | ---: |
| Fuel capacity | 5 |
| Power capacity | 4 |
| Expansion capacity | 0 |
| Power consumption | 0 |
| Grid size | 1 cell |

Fuel, power, and expansion values are independent. No value is converted into
another, and expansion capacity has no gameplay effect in v0.1.

## Power consumption rules

- Current weapon module scenes consume 1 power per installed instance.
- Mining Module scenes consume 2 power per installed instance.
- Energy Modules consume 0 power.

Each scene stores its own exported `power_consumption` value. Future module
definitions can therefore use a different value without adding module-name
checks to `Ship.gd`.

## Calculation formulas

`ShipEnergySystem` aggregates only live module instances installed in a Ship:

```text
TotalFuelCapacity = sum(module.get_fuel_capacity())
TotalPowerCapacity = sum(module.get_power_capacity())
TotalPowerConsumption = sum(module.get_power_consumption())
AvailablePower = TotalPowerCapacity - TotalPowerConsumption
TotalExpansionCapacity = sum(module.get_expansion_capacity())
```

Scene templates, previews, and inactive placeholders are not included.

## Installation restrictions

- Every loadout must contain at least one Energy Module.
- A fresh loadout receives one Basic Energy Module in cell `(1, 1)`.
- If that cell is occupied in a legacy loadout, the first empty cell is used.
- Existing occupied cells are never overwritten during bootstrap.
- Installing or replacing a module is rejected when consumption would exceed
  capacity.
- Removing the last Energy Module is rejected.
- Removing an Energy Module is rejected when the remaining capacity would be
  lower than current consumption.
- Replacements are atomic: the old module remains installed if validation fails.

`Ship.last_module_error` and `Ship.module_operation_failed(reason)` expose a
human-readable rejection reason such as `Insufficient Power`.

## Interfaces for presentation and future systems

`Ship` exposes these read-only aggregate properties:

- `total_power_capacity`
- `total_power_consumption`
- `available_power`
- `total_fuel_capacity`
- `total_expansion_capacity`

It also exposes:

- `energy_changed(...)` for signal-driven UI updates.
- `get_energy_snapshot()` for debugging, UI initialization, and travel checks.
- `module_configuration_changed` after a successful install, replacement, or
  removal.

The Base energy panel reads these values; it does not perform calculations.
Future planet-travel logic may read `total_fuel_capacity`, but fuel purchasing
and consumption are intentionally outside v0.1.

## Configuring future modules

All installable module roots should inherit `ShipModule` directly or through a
specialized base such as `WeaponModule`. Override the relevant getter methods
and expose per-scene values where designers need tuning. Do not add module names
to `ShipEnergySystem`; it operates only through the shared data interface.

## Future hooks

- Current fuel can later be added and clamped against `total_fuel_capacity`.
- Research may raise an Energy Module's `expansion_capacity`.
- Grid expansion can consume the aggregate expansion value later.
- Energy upgrades may change individual scene capacities without changing the
  aggregation formulas.
