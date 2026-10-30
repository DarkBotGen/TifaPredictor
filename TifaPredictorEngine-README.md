# Readable Beequip simulation engine

Execute TifaPredictorEngine.luau in the connected game to install getgenv().TifaPredictorEngine. The complete GUI version is TifaPredictor.luau. See TifaPredictor-GUI-README.md for current semantics, offset definitions, validation and limits.

Evaluate(data, options): returns generated Bee, hive and ability modifiers plus RNG counters.
Single(data, wax, skip, options): evaluates one specified successful future wax with skip 1–32.
Batch(data, chain, predicate, groupBy, options): exact weighted state search for 1–5 future waxes. Predicate receives (result, planningBaseline, integerWeight). Consumers counting per-stat chances MUST add integerWeight, not 1. Group counts include these multiplicities.
Inventory(): reads the current player's local Storage, Inbox and Case data, omitting ownership IDs. Permanents is removed.

Important options: BaseOffset skips before base generation; ResetWaxes clears W, uses UC for RC and restores OS when known; UseOriginalSeed chooses OS; ShowBase strips waxes and RC. Offset is a legacy RC override. Cancelled, OnStage and OnProgress support responsive UI. Defaults: MaxStates=50000, MaxSeconds=600, TransitionCacheSize=512, TerminalMergeSize=8192. The completed frontier is retained when streaming. Incomplete runs never return partial percentages.

Optional Targets projection is for predicates/groupBy inspecting only those target fields; unrelated numeric values may represent one merged history. All upgrade counts and ability-upgrade values remain. Omit Targets for complete arbitrary-snapshot consumers. See Optimization-notes.md for measured timings and validation.

PreviewFull was removed: it was a single illustrative branch, not the requested probability report. Exact counts do not establish Greg-specific offset-label parity or guarantee which skip the game server will choose next.

Guide(data, finishingWax, targetPredicate, options) compares up to six 1–3-step chains. targetPredicate receives result and the common planning baseline. Guide includes non-destructive failure patterns and treats destruction as zero target probability. It returns rows sorted by TargetChance, then slots. This differs from Batch, whose statistics condition on all future waxes succeeding.
