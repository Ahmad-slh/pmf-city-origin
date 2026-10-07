# Game and V5 audit — 2026-10-07

## Confirmed fix

Leaving a match after rolling the dice could leave `GameManager.has_rolled_this_turn`
set in the next match. Unfinished double-roll values in the `GoodEffects` autoload
also survived a new game. `reset_for_new_game()` now resets both states.
The new play-flow regression reproduced the failures before the fix and passes after it.

## Automated verification

All six tests passed against the newly exported V5 `PmfCity.pck`, independently
of the source checkout, using Godot 4.6.1 headless:

- `review_resources.gd`: all 47 scripts/scenes/theme resources load; scenes instantiate;
  28 questions have valid answer keys and loadable images; all 34 event IDs are unique.
- `review_no_destination.gd`: no open destination produces a dismissible message,
  advances the turn, and releases the input lock; ordinary destinations still work.
- `review_investment_transfer.gd`: both teams transfer open and closed investments;
  ownership, question progress, colors, locks, actual sector names and streets remain correct.
- `review_lock_colors.gd`: all 14 sectors use owner-matching lock colors.
- `review_game_end.gd`: all 14 sectors closed or timer zero ends the match; no premature
  finish; no subsequent turns; winner and final tie-breaker work; new game resets finish state.
- `review_play_flow.gd`: restart resets dice; correct/incorrect normal answers consume one
  question only; information closes and advances turn; all four attacker/defender outcomes;
  redirect preserves time; battle timeout neutralizes sector; dice input unlocks afterward.

The game-end test now completes its startup roll-off and waits for entrance animations
before freeing scenes, avoiding warnings caused by tearing down suspended test coroutines.

## Web verification

V5 export completed successfully. Its HTML loader sizes match its PCK/WASM files.
All nine generated files were fetched over local HTTP and matched local SHA256 hashes.
The server served WASM as `application/wasm`. Browser startup, opening dice rolls,
blue/red dragging, correct answer, information close/turn transition and a second question
timeout were exercised. No browser error/warning entries were captured in that session.
The red character appeared on the right; no green character was visible; background and
the separated timer/hourglass rendered correctly. The refreshed export opened successfully.

## Server limitation and deployment instructions

`http://10.10.10.244:8000/PmfCity.html` timed out from this machine. The actual server
copy, cache and HTTP configuration therefore remain unverified. No claim is made that
the server has been updated or that every possible gameplay/effect combination is bug-free.

Copy **all nine PmfCity files together** from V5 to the server's served directory;
do not copy only HTML, JS or PCK. Refresh the browser cache after copying.
Once the server is reachable, compare it with this local V5:

```powershell
& .\tools\verify_web_deployment.ps1 -BaseUrl 'http://10.10.10.244:8000'
```

This verifies each server file byte-for-byte against V5 and rejects a mixed, stale,
incomplete deployment or wrong WASM MIME type. A failure identifies the exact file.
Omit `-BaseUrl` to check local files only.
