# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PMF City — a 2-player (Blue vs Green) turn-based digital board game built in **Godot 4.6** (GDScript, Node2D). Teams roll dice, drag their token to sectors, invest, battle via quiz questions, and draw street/sector cards that apply temporary good/bad effects. UI text and many code comments are in **Arabic**.

Main scene: `scenes/board_background.tscn`. Primary deployment target is the **Web (HTML5) export** (preset `PFM-City-v1.0`, exports to `../PFM-City-Deployments/V1/`).

## Running & validating

Godot executable lives one directory up from the project:

```
& "..\Godot_v4.6.1-stable_win64_console.exe" --path . --editor      # open editor
& "..\Godot_v4.6.1-stable_win64_console.exe" --path .               # run the game
& "..\Godot_v4.6.1-stable_win64_console.exe" --path . --headless --check-only --script <file.gd>  # parse-check a script
& "..\Godot_v4.6.1-stable_win64_console.exe" --path . --headless --export-release "PFM-City-v1.0"  # web export
```

After editing scripts, run and test the change (don't just edit blind). Press **F9** in-game to open the debug event panel (`debug_event_panel.tscn`) for triggering effects manually.

## Architecture essentials

Eight autoload singletons carry all game state (no save system — state is in-memory only):

- `GameManager` — turns/rounds, team state, effect orchestration; signals like `turn_changed`, `street_event_finished`
- `GameManagerHelper` — the effects/signals bus: per-team effect dictionaries, `EffectType`/`Category`/`Handler`/`Trigger` enums, `effect_added/removed/effects_changed` signals
- `GoodEffects` / `BadEffects` / `GameEffects` — effect logic and dispatch
- `SectorCardsData` / `StreetCardsData` / `SectorQuestionsData` — card and quiz data

`board.gd` wires signals in `_ready()`. Temporary effects count down via `reduce_temporary_effects()` each turn.

## Gotchas

- **Enum ordinals don't match comments.** `EffectType` values in `GameManagerHelper.gd` are implicit ordinals; the numbers in the Arabic comments are wrong. Never rely on the commented numbers — use the enum names.
- **Fragile group names.** Player token dropping validates via physics point queries against node groups `board_sectors` and `sectors` (with fallbacks). Keep group names intact when touching sector scenes.
- Web export has **thread support disabled** — don't introduce Thread/Mutex-dependent code.
- Naming is intentionally mixed (PascalCase `GameManager.gd` vs snake_case `board.gd`) — match nearby files, don't rename to unify.
- `.gd.uid` sidecar files are committed; keep them alongside their scripts.
