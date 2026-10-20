# GreedMiner — AI Development Responsibilities

## Core Principle

This project uses two AI coding assistants with separate responsibilities:

- **Codex:** Gameplay programming, architecture, GDScript, data systems, integration, and testing.
- **Claude Code:** Visual design, polished UI/UX, art direction, scene presentation, animation, and visual effects.

The developer makes all final game design decisions.

## Codex Responsibilities

Codex should focus on:

1. Gameplay mechanics and functional implementation.
2. Modular architecture and reusable systems.
3. GDScript programming.
4. Module installation and validation.
5. Enemy AI, spawning, and combat logic.
6. Data management, persistence, and progression systems.
7. Debugging, refactoring, and automated testing.
8. Minimal functional UI required to test features.

## UI Restrictions for Codex

When implementing a gameplay feature:

- Create only the minimum UI needed to operate and test the feature.
- Prefer simple labels, buttons, containers, and basic progress indicators.
- Do not spend development time on visual polish.
- Do not redesign existing interfaces unless explicitly requested.
- Do not generate decorative art assets.
- Do not introduce elaborate animations or visual effects.
- Do not change the project's established visual style.
- Do not create complex UI themes or custom visual frameworks without approval.

**Functionality and correctness take priority over appearance.**

## Claude Code Responsibilities

Claude Code will handle:

- Final UI layouts and visual hierarchy.
- UI themes, colors, fonts, and icons.
- Game art and visual asset integration.
- Scene composition and presentation.
- Visual animations, transitions, and particle effects.
- Weapon and module visual presentation.
- Visual consistency across the game.

Claude Code should preserve gameplay behavior and avoid rewriting core mechanics unless explicitly authorized.

## Separation of Logic and Presentation

Gameplay logic must not depend on decorative UI nodes.

Prefer signals, reusable data interfaces, and clear ownership between gameplay systems and presentation components.

For example, an energy system should expose values such as:

- `total_power_capacity`
- `total_power_consumption`
- `total_fuel_capacity`
- `total_expansion_capacity`

A UI component should read or receive these values without implementing energy calculations itself.

When possible, use signals to notify UI components that gameplay data has changed.

Avoid hardcoding UI node paths deep inside gameplay scripts.

## Scene and File Organization

Keep gameplay scripts, UI scripts, and visual assets clearly organized.

Do not mix gameplay calculations into visual presentation scripts.

When implementing a new system, document the interfaces that Claude Code may use to build the final UI.

## Collaboration Safety

- Inspect existing scenes and scripts before editing.
- Preserve existing functionality.
- Avoid unnecessary modifications to files primarily owned by the other assistant.
- Do not overwrite existing visual work.
- Do not modify unrelated systems.
- Do not commit or push unless explicitly requested.
- When changing an interface used by UI, document the change clearly.

## Definition of Done for Codex

A feature is complete when:

1. Its core gameplay logic works.
2. Required data and state are correctly managed.
3. Existing systems remain functional.
4. A minimal UI or debugging method is available when necessary.
5. Validation has been performed where possible.
6. Public signals, methods, and data needed by Claude Code are documented.

**Do not treat polished visuals as a requirement for Codex feature completion.**

## Final Report

After each feature, report:

- Implemented gameplay functionality.
- Files created or modified.
- Tests performed.
- Known issues.
- Interfaces available for Claude Code.
- Any visual elements intentionally left as placeholders.
