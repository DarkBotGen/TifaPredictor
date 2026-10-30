# Tifa’s Predictor — exact batch reports

Run TifaPredictor.luau directly in Madium with Bee Swarm Simulator loaded. The file includes the readable simulation core and compact GUI. It does not use a remote loader or the original protected predictor.

## How to use

1. Choose the source and item.
2. Choose SoftWax, HardWax, CausticWax or DebugWax from WAX. DebugWax is a hypothetical simulation definition, not a way to acquire or use that item.
3. The adjacent arrows choose WAX COUNT (1–5). SINGLE searches that many repetitions of the selected wax. In BATCH, ADD inserts that quantity into a mixed chain; REM removes its last entry and CLR clears it.
4. Select the stat improvements to count. ANY selected improvement qualifies as a match. No filters lists every resulting stat combination.
5. Leave RESET FIRST off to keep existing wax history. Turn it on only to simulate Turpentine: the copy’s wax history is cleared and RC becomes the stored total-upgrade count UC. The physical item stays unchanged. A full 5/5 item has no free slots without a hypothetical reset.
6. START performs the exact search. STOP cancels. Time/memory limits produce SEARCH INCOMPLETE, with no fabricated percentages.
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

EXPLORE now scans pre-generation base offsets on detached unwaxed copies. ZOOM IN imports that copied state. Show base affects the left display only; it does not secretly reset prediction history. The current/original seed toggle selects known S or OS values. Unknown future Swirled seeds are not predicted.

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

Complex four/five-step chains can exceed the default 200,000-state or 120-second limit. Such runs stop explicitly instead of silently sampling or returning partial probabilities.

## Beequip image cards

The sidebar displays the current source’s items with game-native Beequip images, names, potential, five wax-history slots, and a wax count. Failed waxes are marked with a red cross. Click a card to select it. The green outline marks the current selection. ITEMS (or the sidebar close button) toggles the panel; the combined layout scales to the viewport. Images are referenced through the game’s BeequipTypes and WaxTypes asset IDs; no external image download is needed.

The GitHub main loader is updated with each completed change, as requested. Its entry point is the readable TifaPredictor.luau bundle.
