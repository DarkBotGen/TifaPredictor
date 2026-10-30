# Predictor

Automatic planning: select an ability/hive/stat target, then **··· → FIND BEST WAX PLAN**. It compares setup waxes, reachable reset offsets and up to five finishing waxes, showing target chances, destruction risk, costs and hive/stat outcomes at each offset. **Best found** is bounded by your reset/time budget and completed candidate coverage. See [planner rules and verified example](Automatic-wax-planner.md).

Readable Bee Swarm Simulator Beequip prediction simulator with a dark GUI and image inventory sidebar.

Latest optimization: **NEXT WAX** replaces Explore's range/zoom controls; **After Turp** remains visible. Select desired improvements for a faster exact search. Plans show success/destruction risk, searches show progress and STOP, and unchanged repeat searches reuse their exact result.

Measured fixture: four Caustics with all outcomes improved from 52.5 to 26.2 seconds; five Caustics with Critical Chance selected finished in 22.8 seconds. Results vary by Beequip, targets and runtime load. See [optimization details and validation](Optimization-notes.md); these notes supersede older interface descriptions below.

## Run the latest version

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DarkBotGen/TifaPredictor/main/TifaPredictor.luau?t=" .. tostring(os.time())))()
```

Run inside the supported game/executor context. The query parameter helps avoid stale cached copies. You can also run TifaPredictor.luau directly.

## Features

- Clickable Beequip cards with native game icons, potential and wax-history slots.
- Storage/Case/Inbox/Trade sources and detached JSON import.
- Soft, Hard, Caustic and hypothetical Debug wax selection.
- Exact weighted batch counts, most-likely-first outcome groups, percentages and full plain-text report copying.
- Existing wax history preserved unless RESET FIRST is explicitly enabled for a simulated reset.
- Stop/progress controls and explicit limits for expensive searches.
- Target Guide compares Soft/Hard setup chains for chosen abilities or stats, including survival risk.
- Cleaner results without a Method section; advanced controls are under Options.

No real waxes or Turpentine are used. The code does not fire inventory remotes or modify the original predictor’s authentication. It is a new simulation implementation, not a full deobfuscation of Greg’s script.

## Limits and documentation

The module uses the game’s replicated item definitions. Offset counters are instrumented RNG positions; their mapping to Greg’s naming is unverified. Probabilities are conditional on successful waxes and the 32-skip model; server outcomes and full parity against Greg have not been validated. Expensive searches can stop at memory/time limits without returning partial probabilities.

See [the GUI guide](TifaPredictor-GUI-README.md) for controls, semantics and tests. Game images are referenced by the client’s BeequipTypes and WaxTypes definitions; image files are not redistributed here.

The main loader is updated with each completed change. Use this repository’s main URL for future updates rather than an old commit-pinned URL.

Latest update: native inspector auto-selection, next-wax offset matches sorted nearest first, and exact streaming fallback for large search frontiers. See TifaPredictor-GUI-README.md for offset semantics and validation limits.

Offset investigation: see [Beequip-offset-findings.md](Beequip-offset-findings.md). Explore includes per-branch RNG trace positions and full results; single-finisher Guide plans include target results at reachable reset offsets.

Current GUIDE UI: a simple offset-to-hive-bonus browser. Choose wax, FROM RC and COUNT, then SHOW; no target filters or route recommendations are required. ADD now works from both SINGLE and BATCH; native RC stays visible in the header. See the GUI README for current behavior.

Reference-style UI update: the title is now **Predictor**. The three-tab main layout matches the provided references, including the compact sidebar, Show base control, colored footer and expanded Trade layout. Advanced controls and the hive-offset browser are available in the top-right **···** menu.
