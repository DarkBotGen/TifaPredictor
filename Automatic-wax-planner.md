# Automatic target planner

Select a Beequip and the target filters (Token Link, another ability, a hive bonus or bee stat). Open the top-right menu and choose FIND BEST WAX PLAN. RESETS controls the maximum modeled Turpentine cycles (0..3); SECONDS controls the search budget (default 8). Press FIND BEST. Quick checks examine up to three waxes; 30+ seconds enables five-wax finishing plans. No waxes or items are actually used.

## Three risk/reward choices

The report shows SAFEST TARGET ROUTE, MORE RISK / MORE BONUSES, and HIGHER RISK / HIGHER REWARD. Safest prioritizes survival, then target chance. Riskier alternatives must have strictly lower survival and a greater expected net count of additional improved traits, conditional on obtaining the target and retaining the item. The third must be riskier and higher in this score than the second. Missing alternatives are explicitly reported rather than fabricated. Highest unconditional target chance is also shown separately, since it need not be the safest route.

Additional reward counts distinct improved traits minus reduced traits; it is not a monetary score or a comparison of raw numerical magnitudes across different stats. Actual bonus values, new abilities, reductions, example combinations, combination probabilities, expected trait gains/losses and chance of any extra improvement are displayed. All relevant stat values are retained during this calculation; selected-target-only projection is disabled to avoid false extra-bonus probabilities.

A one-wax successful branch can be 1/32 or 3/32. Before a random Soft setup is observed, Soft then Caustic has 1,024 successful-skip paths, not just 32. Exact successful-roll hit counts are shown for Soft/Caustic chains; Hard plans instead identify their success/failure mixtures. Recheck after each actual wax to condition predictions on its observed outcome. No skip is controllable or guaranteed.

After a result, the panel widens; TARGET reopens the filter selector. The searched target stays selected when switching to compatible Beequips. Incompatible items clearly say the saved target is unavailable instead of silently changing the objective. Repeating an unchanged check reuses the result; changing the item, history, target, reset limit, depth or budget invalidates the key. Increase SECONDS to extend coverage rather than repeating an identical bounded check.

Live Smiley Sticker validation with a Max Bee Energy hive target completed 67/95 candidates in an eight-second scan. It produced genuine 0%, 75% and 98.4375% destruction choices, with approximately 1.94, 2.57 and 2.94 additional improved traits conditional on a surviving target hit. Their overall target probabilities were 16.146729%, 8.298492% and 0.871181% for that item. These are item-specific calculations, not universal Smiley odds or resource-consuming server tests. Strict ordering, full-snapshot reward counts, grouped probability sums, independent two-Hard binomial reward mixtures, sticky targets, incompatible-target messaging and wide results were checked.

The planner starts from the actual current file. It counts every reset in the route cost; the After Turp display option does not give it a free setup reset. Ability targets require presence; stat/hive targets require improvement over the original current stats. All selected targets must hold together. An ability already present needs no further waxing when it is the only target.

## What changes an outcome

The recovered Paperclip definition marks Token Link as CausticOnly, with Max=1. Soft and Hard cannot grant it directly. Its Chance field is a relative upgrade-pool weight, not the final probability of obtaining the ability.

Successful Soft applications consume their random skips and upgrade rolls. Their upgrades change counts and can remove capped entries from later pools. A later Caustic therefore selects from a different pool at different positions in the deterministic seeded stream. More upgrade rolls can make a target reachable even when the 32 single-Caustic branches contain no hit. This does not mean each Soft monotonically improves the target chance.

Turpentine is modeled as clearing W, restoring known OS, and setting RC to the cumulative upgrade-wax attempt count UC. Soft fillers add one attempt each; their random 1..32 skips are not added to RC. Resetting also removes their stat upgrades and caps. The combined server manager transition has not been verified by consuming real items; refresh and re-evaluate the actual item after each real wax/reset.

## Search and ranking

The bounded family includes the current state, reachable Soft/Turpentine reset routes, and Soft prefixes followed by repeated Soft, Hard or Caustic finishers, up to the five-slot limit. It detects targets needing Caustic-only upgrades. It evaluates cheap short plans first, then deeper plans including five consecutive Caustics. Duplicate/reset routes use a lower-resource representative.

Every completed candidate uses exact weighted skip counts. Consecutive Hard failures are included through binomial success-count mixtures: failures consume slots but do not advance seeded generation. A destructive Caustic failure contributes no surviving target item. Ranking prioritizes target-plus-surviving-item probability, then fewer Turpentines and waxes. Conditional target probability and destruction risk are separate.

The report contains the best completed plans and an ascending offset table with the best completed plan, target outcome values, and their unconditional and survival-conditional percentages. If an individual candidate times out, its partial calculation is discarded. Other fully completed candidates remain valid. STOP retains completed candidates. The report states completed/total candidate counts and whether coverage is incomplete.

This is not an exhaustive search of arbitrary mixed or adaptive stop-on-hit policies, unlimited reset counts, unknown Swirled seeds or all possible resource budgets. Best found means best among completed candidates in this family. Zero hits in a bounded search does not prove impossibility elsewhere. Outcome summaries keep up to 128 distinct combinations per conditional calculation; overflow is explicitly grouped and its full probability retained.

## Reproduced Paperclip example

Synthetic fixture: Paperclip, S=4, Q=0.8, UC=0, no existing waxes. These numbers are not a prediction for the user's live Paperclip.

| Fixed plan | Target chance if item survives | Token Link plus surviving item |
|---|---:|---:|
| One Caustic | 0% | 0% |
| Two Caustics | 10.058594% | 0.628662% |
| Five Caustics | 14.604044% | 0.014262% |
| Soft, Soft, Caustic | 8.923340% | 2.230835% |

The Soft/Soft/Caustic route was best among 80 of 95 completed candidates in a 90-second test with one reset allowed. The remaining 15 were not claimed completed. It demonstrates why a higher all-Caustic conditional percentage can be a much worse surviving-item strategy.

After prioritizing cheap plans, the live GUI found the same positive recommendation within a three-second bounded test, completed 32/95 candidates, displayed RC0..5 comparisons and included Soft x5 / Turpentine / RC5 routes. The full five-Caustic result above came from the longer test.

Other checks: one- and two-Hard failure mixtures matched independently combined batch probabilities; grouped probabilities summed to each plan's target chance; a two-wax starting item with UC2 reached RC10 through three Softs/reset then five Softs/reset, with two Turpentines and eight filler Softs; cancellation retained only completed candidates; UI controls, ability selection, partial-budget notices and positive recommendations passed; Luau compilation passed. No real resources, inventory/trade remotes or authentication changes were used.
