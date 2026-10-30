# Readable Beequip simulation engine

AllOffsetBonuses(data, maxResets, options) returns current/reachable Rows and per-trait best/other Levels with wax Ways, unconditional Probability, successful Hits/Total, Survival and Hard failure preservation. It enumerates all Soft-only reset-reachable RCs within 0..10 resets, then the bounded one/two-step finishing family. AutoPlan now permits at most one Caustic per candidate. HighReward may share Balanced's destruction risk but must improve its extra-trait score. See All-offset-bonuses.md.

Risk/reward AutoPlan options: MaxFutureWaxes (1..5, engine default 5) limits finishing-chain depth. ExtraReward(result, baseline) returns additional improved-trait count and reduced-trait count; when supplied, all stat values are retained for exact reward/group evaluation. Recommendations returns Safest, Balanced and HighReward only when their strict survival/net-extra-trait conditions hold. Rows include ExpectedExtra, ExpectedLoss, ExtraChance (all conditional on a target hit with a surviving item), and SuccessfulMatches/SuccessfulTotal for non-Hard successful-skip enumeration. The GUI defaults to an eight-second, three-wax check and enables depth five at budgets of 30+ seconds. Generic engine PlannerSeconds retains its 90-second default.

AutoPlan(data, targets, matchesTarget, groupBy, options) searches bounded Soft-prefix/finisher routes and reachable reset setups. Options MaxResets defaults to 1 (0..3), PlannerSeconds to 90 (1..600). Returns ranked Rows, ascending Offsets, Completed/Candidates coverage, Complete/Stopped/TimedOut flags and Seconds. Predicates/groups must inspect only target descriptors. Hard failure mixtures are included; interrupted candidates are excluded. Group overflow beyond 128 combinations is explicitly aggregated, without changing total target probability. See Automatic-wax-planner.md.

Execute TifaPredictorEngine.luau in the connected game to install getgenv().TifaPredictorEngine. The complete GUI version is TifaPredictor.luau. See TifaPredictor-GUI-README.md for current semantics, offset definitions, validation and limits.

Evaluate(data, options): returns generated Bee, hive and ability modifiers plus RNG counters.
Single(data, wax, skip, options): evaluates one specified successful future wax with skip 1–32.
Batch(data, chain, predicate, groupBy, options): exact weighted state search for 1–5 future waxes. Predicate receives (result, planningBaseline, integerWeight). Consumers counting per-stat chances MUST add integerWeight, not 1. Group counts include these multiplicities.
Inventory(): reads the current player's local Storage, Inbox and Case data, omitting ownership IDs. Permanents is removed.

Important options: BaseOffset skips before base generation; ResetWaxes clears W, uses UC for RC and restores OS when known; UseOriginalSeed chooses OS; ShowBase strips waxes and RC. Offset is a legacy RC override. Cancelled, OnStage and OnProgress support responsive UI. Defaults: MaxStates=50000, MaxSeconds=600, TransitionCacheSize=512, TerminalMergeSize=8192. The completed frontier is retained when streaming. Incomplete runs never return partial percentages.

Optional Targets projection is for predicates/groupBy inspecting only those target fields; unrelated numeric values may represent one merged history. All upgrade counts and ability-upgrade values remain. Omit Targets for complete arbitrary-snapshot consumers. See Optimization-notes.md for measured timings and validation.

PreviewFull was removed: it was a single illustrative branch, not the requested probability report. Exact counts do not establish Greg-specific offset-label parity or guarantee which skip the game server will choose next.

Guide(data, finishingWax, targetPredicate, options) compares up to six 1–3-step chains. targetPredicate receives result and the common planning baseline. Guide includes non-destructive failure patterns and treats destruction as zero target probability. It returns rows sorted by TargetChance, then slots. This differs from Batch, whose statistics condition on all future waxes succeeding.
