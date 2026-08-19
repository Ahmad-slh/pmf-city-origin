---
name: export-web
description: Export PMF City to HTML5 using the PFM-City-v1.0 web preset.
disable-model-invocation: true
---

1. Ensure the output directory exists: `../PFM-City-Deployments/V1/`.
2. Run the export:
   ```
   & "..\Godot_v4.6.1-stable_win64_console.exe" --path . --headless --export-release "PFM-City-v1.0"
   ```
3. Check the console output for export errors (missing export templates is the usual failure — if so, tell the user to install them via Editor → Manage Export Templates).
4. Confirm `../PFM-City-Deployments/V1/pmfv1.html` was updated (check timestamp).
