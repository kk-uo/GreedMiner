# GreedMiner Project Structure

GreedMiner uses a feature-based layout. Scenes and scripts remain in separate
top-level directories, while matching feature names make related files easy to
find. Gameplay behavior is implemented in GDScript and the project targets the
Godot Standard editor and Web export.

## Major directories

- `Scenes/Base/` — ship assembly scene.
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
- `Scripts/UI/` — reusable HUD scaling and evacuation controls.
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
