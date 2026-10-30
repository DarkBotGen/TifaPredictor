# Tifa’s Predictor — exact batch reports

Run TifaPredictor.luau directly in Madium with Bee Swarm Simulator loaded. The file includes the readable simulation core and compact GUI. It does not use a remote loader or the original protected predictor.

## How to use

1. Choose the source and item.
2. Choose SoftWax, HardWax, CausticWax or DebugWax from WAX. DebugWax is a hypothetical simulation definition, not a way to acquire or use that item.
3. The adjacent arrows choose WAX COUNT (1–5). SINGLE searches that many repetitions of the selected wax. In BATCH, ADD inserts that quantity into a mixed chain; REM removes its last entry and CLR clears it.
4. Select the stat improvements to count. ANY selected improvement qualifies as a match. No filters lists every resulting stat combination.
5. Leave RESET FIRST off to keep existing wax history. Turn it on only to simulate Turpentine: the copy’s wax history is cleared and RC becomes the stored total-upgrade count UC. The physical item stays unchanged. A full 5/5 item has no free slots without a hypothetical reset.
6. START performs the exact search. STOP cancels. Large frontiers switch to a bounded-frontier exact streaming search. This can take longer. STOP cancels; the ten-minute time limit produces SEARCH INCOMPLETE without partial percentages.
7. COPY REPORT copies the complete plain-text report, including groups beyond the on-screen display limit. VIEW CURRENT STATS is available outside Batch. The question-mark button explains the workflow in the UI.

## Report and probabilities

Reports include === BATCH MATCHES ===, the wax chain, current stats and stored wax history, potential, RNG counters, individual chances, every matched combination, exact integer counts, percentages. Groups are sorted by descending probability (exact count), with alphabetical tie-breaking. Example skip sequences are omitted from the display and copied report.

There are 32 equally weighted skip choices for each successful future wax. Totals are 32, 1,024, 32,768, 1,048,576 and 33,554,432 for chains of one through five waxes. Equivalent RNG/count/value states are merged with integer multiplicities, preserving the branch totals; there is no sampling. Percentages are calculated from counts / total and displayed to six decimal places. Stat chances are CONDITIONAL on all added waxes succeeding. The separate all-wax success rate uses the loaded WaxTypes definitions. Failure outcomes are not enumerated.

Filters compare to the planning start: existing stats when RESET FIRST is off; the simulated post-reset state when it is on. CURRENT STATS retains the selected item’s existing history under the chosen seed/base offset, so a report can show W:5/5 while explicitly planning a post-reset chain.

## Offsets — exact here, not verified Greg equivalents

BASE OFFSET skips calls to the seeded Random stream BEFORE base stats are generated.
Offset after turp is the absolute draw count after base Bee/hive stats plus the file’s RC skip.
Current offset is the absolute draw count after full generation, including upgrades and ability pools.
These values are instrumented RNG-call counts. Their conversion to Greg’s particular labels remains unverified; matching report headings does not establish identical semantics.

EXPLORE searches the 32 legal RNG skips for one next successful application of the selected wax. Existing history is preserved unless reset is enabled. ALL selected targets must improve. Results are sorted by skip 1 through 32 and include the final RNG draw count. These skips are possible branches, not guaranteed controllable offsets. Wax count is used by SINGLE/BATCH; EXPLORE always checks the next wax. Show base affects the left display only; it does not secretly reset prediction history. The current/original seed toggle selects known S or OS values. Unknown future Swirled seeds are not predicted.

## Validation

- Luau compilation and live GUI interaction passed.
- State-merging search matched the prior brute-force engine across 180 fixtures (45 types × four wax types × all 32 skips).
- One-, two- and three-Caustic searches matched brute-force group counts exactly.
- Six 1,024-branch mixed-chain comparisons passed with existing history, base offset 5, RC skips, and simulated resets across Whistle, Paperclip and Kazoo.
- A five-SoftWax Bottle Cap fixture represented all 33,554,432 paths using 44,052 exact states; 685 grouped counts summed to the full total. It took about 9.3 seconds in the connected client. This is not a universal timing promise.
- The GUI produced a real two-DebugWax report with 1,024 paths and preserved the original 5/5 history in the CURRENT STATS section while planning a reset.
- Cancelling a four-DebugWax run produced SEARCH INCOMPLETE without retaining misleading results.
- Core generation previously matched an isolated copy of the decompiled game function for all 14 available items and 768 synthetic cases. Native direct calls were blocked by Madium’s mixed-script-context require restriction.

No real waxes, Turpentine, inventory remotes or authentication changes were used. Game-server wax outcomes and parity against Greg’s full predictor have not been validated.

Complex searches switch from merged frontiers to exact streaming at 50,000 states. The per-search time limit is 600 seconds. No partial probabilities are reported on cancellation or timeout.

## Beequip image cards

The sidebar displays the current source’s items with game-native Beequip images, names, potential, five wax-history slots, and a wax count. Failed waxes are marked with a red cross. Click a card to select it. The green outline marks the current selection. ITEMS (or the sidebar close button) toggles the panel; the combined layout scales to the viewport. Images are referenced through the game’s BeequipTypes and WaxTypes asset IDs; no external image download is needed.

The GitHub main loader is updated with each completed change, as requested. Its entry point is the readable TifaPredictor.luau bundle.

## Simplified UI and target guide

The Method section is removed. The screen uses compact headings and rounded percentages; COPY REPORT retains exact counts and six-decimal percentages. Reset, seed selection and base RNG offset are behind OPTIONS. Existing offset definitions and limitations are unchanged.

GUIDE: select desired ability/stat filters, choose the finishing wax, and press COMPARE. ALL selected targets must improve. It compares the finisher alone, Soft → finisher, Hard → finisher, Soft → Soft → finisher, Soft → Hard → finisher and Hard → Soft → finisher, subject to remaining slots. These six finishing chains are now evaluated both directly and after reachable Soft/Turpentine setup routes (up to three resets). This bounded search is not a global optimum over all possible plans.

Chains are ranked by target-and-survival probability. Non-destructive Hard failures are included; destructive failures count as misses. The copied guide includes conditional target chance given survival as well as overall chance. Soft is not assumed to improve the result: it advances the seeded RNG and changes upgrades/pools, and the effect is calculated for the selected item.

The guide does not reveal or guarantee the next server skip. A test of a Bottle Cap fixture independently verified all three eligible Caustic-finishing chains, including the Hard-failure mixture; the input stayed unchanged. Live GUI tests verified Guide, Options, rounded screen percentages, exact copied values, and removal of Method text.

## Native selection

Permanents is removed. Selecting a different Beequip in the native Case, Storage or Inbox inspector selects it in Tifa. The trade item inspector is observed the same way; its selected Beequip appears in the Trade source. Observers pause selection changes while a search is running. No game functions are replaced and no inventory or trade remotes are sent. Trade wiring has been inspected but not tested in an active player trade.

Streaming fallback was compared against merged searches for 1,024 branches on Bottle Cap, Whistle, Paperclip and Kazoo. Another 96 next-wax offset results matched direct history evaluation; cancellation was checked in Madium.

Additional waxes: select a partially waxed Beequip, leave Reset before search off, choose SINGLE and ADD WAXES 1 to predict its next application. The header shows existing-to-planned wax count (for example 2/5 to 3/5). BATCH can add a mixed chain within the remaining slots. Improvements are measured against current stats. Verified a two-wax fixture plus third Caustic application against all 32 direct evaluations, without modifying input data.

## Reachable reset plans

GUIDE starts from the current S/history and a zero artificial base offset. Reset-before-search, Show Base and original-seed display options do not create a free setup reset. Every planned reset is counted and restores OS when available. It searches 0–5 Soft fillers per reset, constrained by remaining slots, and up to three Turpentines. It retains the lowest-resource route to each reached reset offset. Routes show ordered steps, filler Soft cost, Turpentine cost, finishing waxes, reset offset, survival and target chance. Ranking: target chance descending, then fewer Turpentines, then fewer waxes. All target improvements compare against the original current stats, including any upgrades a reset removes.

UC counts upgrade-wax attempts, not successful stat points or the random skip. Observed live inventory includes UC=5 with five failed Hard Waxes, UC=4 with four Hard Waxes plus one Swirled, and UC=5 with five Soft Waxes. Client BeequipFile.RegisterTurpentineUpgradeCount assigns RC=UC. The manager that invokes these methods is server-side and has not been recovered; the combined route transition is a model supported by the client methods and observed counters, not a resource-consuming server test. The seed-reset behavior is also documented at https://bee-swarm-simulator.fandom.com/wiki/Beequip/Generation. Refresh/re-evaluate the selected item after each actual reset before following later steps. If UC is absent with a nonzero RC, the planner rejects the unknown cumulative count.

Validation: the full default search produced 96 plans for an unwaxed Bottle Cap, including Soft ×5 / Turpentine repeated three times reaching RC=15. A two-wax starting fixture correctly used three fillers before its first reset to RC=5. A 5/5 fixture produced valid immediate-reset plans. A Whistle target rate after reset matched all 32 direct next-wax branches. Inputs were unchanged. No waxes, Turpentine or inventory/trade remotes were used.

## Offset trace and results update

The UI now distinguishes artificial base skip, native RC, absolute after-reset draw and final draw count. Explore shows matching next-wax skips, target probabilities with/without wax success, full resulting stats and per-branch before/after-skip/after-roll positions. A final draw is not a unique outcome key. Guide single-finishing-wax routes show matching skips and grouped target results at the reached RC.

See Beequip-offset-findings.md for the audited generation order and 2,048-case independent reference test. offset-outcomes-example.json provides 512 synthetic outcomes across RC 0..15; it is not live player item data. The reset counter's server caller remains unverified by resource-consuming actions.
