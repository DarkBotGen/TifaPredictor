# Automatic target planner

Select a Beequip and the target filters (Token Link, another ability, a hive bonus or bee stat). Open the top-right menu and choose FIND BEST WAX PLAN. RESETS controls the maximum modeled Turpentine cycles (0..3); SECONDS controls the search budget (default 90). Press FIND BEST. No waxes or items are actually used.

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
