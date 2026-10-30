# Tifa Predictor GUI

Run TifaPredictor.luau in the supported Bee Swarm Simulator executor context. It simulates detached item data and never applies wax or sends inventory/trade remotes.

## Additional wax simulations

Select an item from the sidebar or native inspector. Existing waxes are preserved by default. The header shows RC and the existing-to-planned wax count. A 2/5 item can receive up to three additional simulated waxes.

Choose a wax and quantity. ADD is visible in both SINGLE and BATCH; ADD switches to BATCH and appends the selected waxes. REM removes the last wax, CLR clears the plan. START searches the planned chain; an empty chain uses the selected wax/quantity. Changing items clears the old planned chain. A full 5/5 item needs a simulated reset in OPTIONS before additional-wax predictions; that does not reset the real item.

Filters in SINGLE/BATCH count any selected stat improvement relative to the planning start. Results show exact counts and groups; the screen rounds percentages, while COPY REPORT preserves more precision. Waxes must succeed for conditional batch percentages; chain success is shown separately. DebugWax is hypothetical/simulation-only.

## Simple GUIDE: offsets and hive bonuses

Choose wax, open GUIDE, set FROM RC and COUNT (1..64), then SHOW. The default range starts at the item's cumulative upgrade-wax count UC and includes 16 reset-offset scenarios.

The report first includes the current item with its existing waxes, if a slot remains. It then lists post-reset RC scenarios in ascending order. Each predicts ONE next wax, enumerating its 32 possible successful random skips. It groups identical full hive-bonus combinations and lists their matching skips, conditional chances and chances including wax success. No target filters are required. The results pane expands to use the space previously occupied by filters.

A reset scenario clears existing waxes and restores the original seed when available. These explicit RC scenarios are not resource instructions or verified reachable-route recommendations. RC values below the real cumulative attempt counter may not be reachable. The previous multi-reset recommendation display is removed from GUIDE; the advanced Engine.Guide API remains available separately.

## EXPLORE

Explore enumerates all 32 next-wax successful skips for the current planning state. All selected targets must improve; without filters it lists every branch. It shows full resulting stats, absolute draw positions and conditional/unconditional target probability.

## Offsets

RC is the stored skip AFTER base bee stats and hive bonuses. Wax skip is the random 1..32 skip before successful upgrade rolls. Final RNG draw is an absolute position, not a unique outcome identifier. Artificial base skip is a predictor-only advanced control before base stats. Guide ignores display/reset/base-skip options and uses the real current file plus explicit reset scenarios.

See Beequip-offset-findings.md for the recovered generation order and 2,048 independently checked cases. offset-outcomes-example.json contains 512 synthetic example branches, not live player item data. Full wax history, quality, seed and upgrade pools matter; an offset by itself cannot determine the stats.

## Item selection

Sources: Storage, Case, Inbox, Trade and detached JSON import. Permanents is removed. Native Case/Storage/Inbox inspector changes select the item in Tifa; the trade inspector uses the same read-only observation approach. Trade selection wiring has not been tested in an active player trade. Selection changes are ignored during a search.

## Runtime and validation

Large exact batch frontiers switch to streaming instead of failing at the state-memory threshold. Complex chains may take longer. STOP cancels; timeout/cancellation never produces partial percentages. Default per-batch time limit is ten minutes.

Latest Madium GUI checks: selected an unwaxed real Lei; ADD worked from SINGLE and switched to BATCH, adding twice then REM left one SoftWax; CLR/ADD/START produced 32 exact branches; header displayed RC. GUIDE with no filters produced current-item hive outcomes plus reset offsets 0..15, including hive bonus text, matching skips and chances. Luau compilation passed. No actual waxes, Turpentine, game inventory writes, auth changes or trade writes were used. Server-side reset transitions and parity with Greg's labels remain unverified.

GitHub main is updated after completed changes. The loader's cache-busting query helps avoid stale executor downloads.
