---
name: run-game
description: Launch PMF City in Godot to test changes — validates edited scripts headlessly first, then runs the game. Use when asked to run, test, or verify a change works.
---

1. For each `.gd` file changed this session, parse-check it:
   ```
   & "..\Godot_v4.6.1-stable_win64_console.exe" --path . --headless --check-only --script <file.gd>
   ```
   Fix any parse errors before launching.
2. Launch the game (background, so the session isn't blocked):
   ```
   & "..\Godot_v4.6.1-stable_win64_console.exe" --path .
   ```
3. Watch console output for script errors/warnings at startup and report them.
4. Remind the user: press **F9** in-game to open the debug event panel for manually triggering effects.
