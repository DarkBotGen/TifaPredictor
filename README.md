# TifaPredictor

Readable Bee Swarm Simulator Beequip prediction simulator with a dark GUI and image inventory sidebar.

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
