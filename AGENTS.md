# Repository Guidelines

## Project Structure & Module Organization
- Godot 4 project. Open `project.godot`.
- Core code: `main/`, `autoloads/`, `tower/`, `projectile/`, `bloon/`, `gui/`.
- Data & assets: `data/`, `resources/`, `meshes/`, `ground/`, `path/`, `icon.svg`, `preview.png`.
- Addons: `addons/` (AI-Context-Generator). No external package manager.

## Build, Test, and Development Commands
- Open editor: `godot4 -e --path .` (or `godot -e`).
- Run game: `godot4 --path .`.
- Headless (logs only): `godot4 --headless --path .`.
- Export (after presets): `godot4 --path . --export-release "Linux/X11" build/game.x86_64`.

## Coding Style & Naming Conventions
- Language: GDScript; UTF-8; 4-space indent.
- Files/variables/functions: `snake_case` (e.g., `wave_manager.gd`, `take_damage`).
- Classes/Nodes: `PascalCase` (e.g., `Bloon`, `Tower`, `WaveManager`).
- Signals: `snake_case` (e.g., `bloon_popped`, `cash_changed`).
- Keep `res://` paths stable; update references when renaming scenes/resources.
- Use Godot editor formatter (or `gdformat` defaults). Avoid mass reformatting unrelated files.

## Testing Guidelines
- No automated tests yet (see `CLAUDE.md`). Perform manual checks:
  - Start waves, place towers, verify damage, upgrades, pooling, and immunity behavior.
- If adding tests, prefer GUT or GdUnit:
  - Location: `tests/`; naming: `*_test.gd`; focus on factories/managers and pure logic.

## Commit & Pull Request Guidelines
- Conventional Commits (seen in history):
  - `feat(tower): add ice slow aura`
  - `fix(bloon): prevent instant pop on spawn`
  - `refactor(factory): centralize bloon stat generation`
- Commits: small, focused, clear scope (`bloon/`, `tower/`, `gui/`).
- PRs: include description, linked issues, repro steps, screenshots/clips, and test plan. Note any scene/resource migrations.

## Agent-Specific Instructions
- Scope: this file applies to the entire repo.
- Keep diffs minimal; don’t introduce new dependencies.
- Preserve node names and resource paths; avoid broad renames.
- Update `CLAUDE.md` and this file when conventions or architecture change.

