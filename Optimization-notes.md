# Optimization update

The exact engine now caches bounded RNG transitions, replays increments in their original numerical order, retains completed merged work when streaming, and merges terminal states in bounded chunks. Selected-target searches also merge states differing only in irrelevant numeric values. All upgrade counts and ability-upgrade values remain, preserving later pools and rolls. No sampling is used.

The interface keeps the reference-style layout. Explore is now NEXT WAX: it shows all 32 possible successful rolls without range/zoom clutter. After Turp remains visible. Plans explain all-wax success and destruction risk before searching. Results distinguish conditional percentages from all-success-plus-target probability. Failed Hard mixtures remain outside conditional batch results.

Progress includes elapsed time, a bar and an explicitly approximate remaining-time estimate after counting advances. STOP cancels without partial percentages. The screen shows up to 400 lines; COPY retains the complete report. One bounded exact result is cached for unchanged repeat searches, keyed by item/history/seed/chain/targets/options. Item cards are reused on selection and dead event references pruned. Native in-place wax/seed/counter changes are detected after the current search ends.

## Measurements

Madium, synthetic Bottle Cap, S=1234567 and Q=0.73:

| Search | Previous | Optimized |
|---|---:|---:|
| Four Caustics, all groups, 1,048,576 paths | 52.52 s | 26.22 s |
| Five Caustics, Critical Chance selected, 33,554,432 paths | Not timed | 22.77 s |

Every four-wax group/count matched. The five-wax selected-stat timing does not imply the same speed for unfiltered five-wax searches. Timings vary by item, selected targets and machine/runtime load. The live 16-offset Lei hive guide finished in approximately 0.1 s after removing a forced frame wait per roll.

Regression coverage: eight mixed-chain old/new/forced-streaming comparisons; 21 selected-stat comparisons; three-wax ability-pool plus parameter-specific hive target comparison; 32,768-path terminal-chunk comparison; cancellation. Earlier independent recovered-generator checks remain applicable to the unchanged generation rules.

Live GUI checks passed: ADD/REM/CLR/START, five-Caustic risk summary, progress/elapsed display, STOP, repeated exact result reuse, cache miss after item change, card-instance reuse, full-item guidance, After Turp preview, all 32 NEXT WAX rolls and filter-free hive guide. Luau compilation passed. No actual waxes, Turpentine, inventory/trade writes or authentication changes were used.

## Engine options

Default limits: MaxStates=50000, MaxSeconds=600, TransitionCacheSize=512 and TerminalMergeSize=8192. Incomplete searches never return partial probabilities.

Optional Batch Targets accepts filter descriptors with kind, name, op and params. Predicates/groupBy must inspect ONLY these targets. Unrelated snapshot values then represent one merged history; callers needing complete arbitrary snapshots must omit Targets. The GUI uses projection only for selected-stat output and weighted counters. Predicates counting paths must add their integerWeight argument.

Best workflow: choose the Beequip, choose additional waxes, select the improvements you actually want, then START. Existing waxes stay unless After Turp is enabled. Choosing targets can greatly reduce exact-search work. Large unfiltered five-wax searches can still take much longer. Server reset callers and Greg-label parity remain unverified.
