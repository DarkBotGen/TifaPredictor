# All bonuses by every reachable offset

Open the top-right menu and select ALL BONUSES BY OFFSET. Set RESETS (default 3, range 0..10) and SHOW. No target or wax selection is needed.

The view includes the current item and EVERY RC reachable within that many Soft-only setup/reset cycles. An unwaxed item with UC0 and three resets includes current RC0 and RC1 through RC15. A partially waxed item uses its actual remaining slots and cumulative UC: with two existing waxes and UC2, two resets reach RC2 through RC10, plus the current item. Routes list only Soft fillers and Turpentine; the exact counter/reset model still needs checking against the actual item after real actions.

For each offset the quick finishing family is: no wax, Soft, Hard, one Caustic, Soft then Hard, and Soft then one Caustic. Finishers are included only if the current file has enough free slots. The full 5/5 current item shows its existing bonuses; reset routes then have free slots.

For each individual hive bonus and ability, the report shows its highest attainable numeric value in that finishing family, all wax choices attaining it, exact successful-skip hit counts, unconditional chance and destruction risk. Other attainable values show their most likely option. Already present means no wax is needed. Hard failures preserving the existing or first-Soft state are included. Single waxes have 32 successful-skip paths; two-wax chains have 1,024, plus the separately weighted Hard-failure branch.

Best values for different traits may come from different outcomes. They are not a guaranteed combined Beequip, and probabilities for different traits should not be added as disjoint events. This is a bounded Soft/Turpentine reachability view and a small finishing family, not every future wax history or an infinite offset scan. More resets reach further RCs. COPY retains the complete report if the screen's line limit is reached.

The automatic target planner also now follows the requested policy: only Soft fillers before resets, and at most ONE Caustic in a finishing chain. Soft prefixes and Hard finishers fit the available slots. It no longer evaluates repeated/two-to-five-Caustic chains. Two Caustic alternatives can therefore share the same 75% destruction risk; an additional alternative is shown only when its extra-trait score is greater, and its actual risk is displayed.

Validation: the live Smiley Sticker view covered all 16 current/reachable rows in about 1.1 seconds, including the 1,024-path finishers. Checks covered 55 individual probability options and 19 direct Hard probability cases, explicit Hard failure mixtures after a Soft setup, reachable RC bounds for partial items, slot constraints, and absence of multiple-Caustic automatic candidates. The revised eight-second target scan completed 72 candidates in a live check. No real waxes, Turpentine or inventory/trade writes were used.
