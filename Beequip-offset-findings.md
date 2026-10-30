# Beequip offsets: traced rules and validation

The offset is a position in a seeded random stream, not an independent stat selector. Reproducing an item needs its type, quality, seed, reset skip (RC), full ordered wax history, and the upgrade definitions/pools.

## Generation order confirmed in recovered client code

1. Start `Random.new(S)`.
2. Resolve base bee stats and hive bonuses. RQValue can consume different numbers of random draws depending on the definition/chance.
3. Discard RC random draws. This occurs AFTER base stats, so changing RC alone does not reroll those base bee/hive values for the same seed and quality.
4. Resolve base ability pools.
5. If successful upgrades exist, resolve upgrade-pool weights.
6. Replay successful wax history, in order. For each successful application, discard its stored W[i][3] draws, then perform that wax's upgrade rolls. Failed applications contribute no seeded draw or upgrade, but occupy a wax slot.
7. Apply accumulated upgrades and resolve upgraded ability pools. These late ability rolls happen after ALL waxes, not separately after every wax.

Appending a wax therefore regenerates the entire item. It must not continue a saved RNG object from the old final draw: late ability draws can move when another wax is appended.

## Offset terms used by Tifa

| Field | Meaning |
|---|---|
| Artificial base skip | Predictor-only skip BEFORE base generation. Zero for reachable Guide routes. This is not the game's RC and has no established player action that sets it. |
| Reset skip (RC) | Native stored skip AFTER base stats. |
| After reset (absolute draw) | Base-generation draws + artificial base skip + RC. Not RC itself. |
| Wax skip | The successful application's stored random skip, 1..32 for a new wax. |
| Final RNG draw | Absolute consumed-draw count after upgrades and late ability rolls. This count alone does not identify the result. |

OffsetTrace additionally records after-base, after-reset, after-base-ability, after-upgrade-weight, per-wax start/after-skip/finish, after-wax-roll and final draw positions.

## Reaching reset offsets

Client BeequipFile.IncrementTotalUpgradeCount increases UC by one. RegisterTurpentineUpgradeCount assigns RC=UC. Observed live replicated items have UC=5 after five upgrade-wax attempts even if all Hard Waxes failed; a four-Hard/one-Swirled history has UC=4. UC is not the number of stat upgrade points and does not accumulate the wax's random 1..32 skip.

The planner models each Soft filler as UC+1, then Turpentine as clearing W, restoring OS when available, and setting RC=UC. Example for an unwaxed item with UC=0:

- Soft x5, Turpentine -> RC=5.
- Another Soft x5, Turpentine -> RC=10.
- Another Soft x5, Turpentine -> RC=15.

For an item with two upgrade waxes, UC=2 and three slots left, Soft x3 then Turpentine reaches RC=5. Soft x1 then Turpentine reaches RC=3. The randomly rolled filler skips are discarded with history and do not add to the retained RC.

The server-side BeequipManager that calls the counter/reset methods is unavailable. These route transitions are supported by the client methods and observed fields, but have not been tested by spending real resources. Refresh and inspect after an actual reset before proceeding. The prior community description saying 'one draw per Turpentine' is not sufficient to explain the current observed RC=UC client rule.

## Results and probabilities

Explore enumerates all 32 legal successful branches for the next selected wax, preserving existing history. It shows full resulting stats and abilities, the matching skips, and each branch's draw positions. Each skip has conditional probability 1/32. Overall target chance = matching skips / 32 x wax success probability. Caustic's destructive failure remains outside the successful branches; its overall success probability is 25% in the recovered WaxTypes definition.

Guide searches reachable reset routes and six finishing chains up to three waxes. Single-finishing-wax routes now include matching skips and target outcome groups at that reset offset. Multiple-finishing-wax routes retain exact aggregate target/survival probabilities. It searches at most three resets by default, not every possible resource budget. Results are per planned attempt, not a claim about unlimited retries or a guarantee of hitting an ability.

Two histories can end at the same final RNG draw while producing different stats, because earlier selections and upgrade counts differ. Confirmed synthetic Whistle example (S=1234567, Q=0.73, RC=0, two Soft Waxes):

| History skips | Final draw | Critical Power | Movespeed multiplier |
|---|---:|---:|---:|
| 2, 2 | 19 | 0.23 | 1.0910400442416286 |
| 3, 1 | 19 | 0.20 | 1.1078390619451666 |

## Validation

A separate test extracted the decompiled GenerateModifiers and _ugDefToTag functions and instrumented their actual Random.NextNumber calls. It did not call the predictor's generation function as its reference.

- 2,048 cases: Whistle, Kazoo, Paperclip and Bottle Cap; RC 0..15; new successful Caustic skip 1..32 following an existing Soft application.
- Every resulting bee stat, hive bonus and ability matched.
- Every final absolute draw count and traced base/reset/base-ability draw position matched.
- Per-wax after-skip minus before-skip equalled the stored skip in every case.
- OffsetOutcomes returned exactly 32 branches with correct conditional/unconditional weights.
- A same-final-draw/different-stats collision was reproduced.
- Guide single-wax branches were checked against its detailed matching branch list.

`offset-outcomes-example.json` contains a SYNTHETIC Whistle fixture at RC 0..15, with all 512 next-Caustic successful branches and their actual resulting stats, abilities and draw positions. It is not a prediction for the user's currently selected live item. Use Explore for that item's data.

Source: recovered local BeequipFile.luau, RQValue.luau, RandomPools.luau and WaxTypes.luau. The reference test is work/offset-reference-test.luau. No wax, Turpentine, inventory write, trade write or remote was used. Parity with Greg's offset labels and unrecovered server manager code is not claimed.
