# Cleanup Crew: retention, persistent goals and monetization validation

2026-10-12. User confirmed **no public test yet**. This is a researched product hypothesis and executable validation plan, not measured retention, a revenue forecast, or an implemented economy. Existing gameplay/UI work remains intact. No products created, purchases, ads, publishing or player messages sent.

## Candid diagnosis

The current design explicitly excluded persistence and paid items. A shift gives a temporary quota, optional salvage bonus and funny review, then resets. That can validate moment-to-moment enjoyment and voluntary replay, but it cannot fairly validate a proposed long-term progression business that does not exist yet. More rooms and art improve variety/presentation; they do not themselves give a player an unfinished personal goal tomorrow.

My design assessment: present risk is **fun for two evenings, little personal reason to return**. One occupant may also become predictable. Seven-minute runs plus waiting/teleports are expensive onboarding if the first meaningful action or reward arrives late. Co-op can create exceptional moments, but dependence on friends being available can reduce spontaneous solo returns. These are hypotheses, not observed player drop-offs.

Simulator monetization is more structurally obvious: numerical upgrades, faster progress, collections and repeated purchases fit the loop. That does not make simulator revenue easy or guaranteed; acquisition, competition, pacing and content supply still matter. Our advantages could be a recognizable horror-comedy identity, emotionally memorable failures/saves, friends recruiting friends, skill improvement, and tool/crew identity that players actually see during play. Those advantages must earn lower acquisition costs, repeat sessions or purchases to become a business advantage. They do not compensate automatically for weak retention.

Comparable public pages establish design precedents, not financial results: [Dandy's World](https://www.roblox.com/games/16116270224/Dandys-World) advertises collectible characters, research and playstyle trinkets; [DOORS](https://www.roblox.com/games/6516141723/DOORS) combines horror with Knobs/Revive benefits; [Lethal Company](https://store.steampowered.com/app/1966720/Lethal_Company/) combines risky extraction with equipment, destinations and suits/ship decoration. These support the possibility of combining tension and progression. Public visits/current players are not D1/D7 or profit, and these are successful survivors, not a representative genre sample. Lethal Company's paid-PC business model is not a Roblox revenue benchmark.

## Smallest persistent loop worth testing

**Choose a personal goal → complete a shift → bank career progress + wages → unlock/equip something visible → preview the next goal → return for another contract.** Keep risk inside the run; banked career progress survives catches and future sessions. Do not turn cleaning into a mandatory idle/grind simulator or let paid power erase Harlow's threat.

| Feature | Concrete first version | Reason to return | Risk / validation |
|---|---|---|---|
| Crew passport | Three early career milestones; first earned badge/patch after a successful first shift, next target visible | A player identity and an unfinished reachable goal | An XP bar alone may do nothing; test goal visibility and equip behavior |
| Personal gear locker | Saved earned wages, three deliberately chosen unlocks and a loadout preview | Work visibly accumulates rather than resetting | Cosmetics need to be desirable; too much currency or grind kills motivation |
| Salvage casebook | Record banked/discovered items from the actual 13-item registry; completion marks and one collection reward | Discovery and a specific missing item | Thirteen entries are a starter collection, not months of content; do not force frustrating rare drops |
| Career challenges | Pick one achievable mastery goal: bank an intact fragile item, clear with a teammate, bank overtime salvage | Mastery and meaningful run variation | Avoid goals rewarding deliberate noise, catches or griefing; individual goals must not sabotage the crew |
| Contract variety | Two or three clearly distinct objective/modifier cards over the existing office kit | A fresh decision, not just another seed | Room count/seed changes alone may be imperceptible; test whether players can describe the difference |
| Weekly inspection sheet | Optional multi-shift checklist and company cosmetic; progress does not require consecutive days | A planned return with friends | Delay until core progression works; do not use daily streak loss to conceal weak gameplay |

First build recommendation: **passport + locker + one earned cosmetic + one next goal**. Add a lightweight salvage casebook next because it reuses real cargo. Keep the first test to two/three ranks, a few cosmetics and two mastery goals. A deep rank tree, pets, trading, guilds, battle pass and ten new buildings would make the experiment slow and ambiguous.

Example player journey (tuning hypotheses): first 60–90 seconds: clear and bank something, understand danger and where safety is. End of first shift: career badge and a visible small locker reward. Next one/two shifts: unlock a distinctive nozzle/body or uniform patch. Later sessions: complete a harder license challenge and a collection page. A missed quota can still grant honest contribution progress; catch count is not rewarded as a farmable progression objective. No paid purchase is required for the next job.

Career levels/licenses and rare mastery rewards must remain earned. Cosmetics can have paid and earned variants; paid spending does not count toward career mastery. Functional tools, if added later, should initially be earned sidegrades with explicit tradeoffs, rather than paid quietness/speed/capacity that dominates horror gameplay. Define solo tuning and fair crew contribution before progression payouts.

## Monetization: credible offers, not invented demand

[Roblox developer products](https://create.roblox.com/docs/production/monetization/developer-products) are repeatable purchases; passes fit permanent one-time privileges. Repeatability alone does not create demand. Our most credible repeatable demand is new cosmetic choices over time, which also creates an art/content cost.

| Offer | Product form | Why it fits | Priority / concern |
|---|---|---|---|
| Tool style credits, spent on a guaranteed selected skin/sound | Repeatable developer-product credit packs; explicit catalogue and owned-item checks | Different vacuums, nozzle shells, enamel finishes and motor styles are always visible | Best dev-product candidate once there is enough desirable catalogue content; avoid adding a premium currency for just one skin |
| Selected company equipment set | Permanent cosmetic entitlement; pass for a fixed one-time pack | Original branded vacuum + matching vest/patch, no strength advantage | Strong first paid offer; show exact contents and preview before purchase |
| Crew gift | Repeatable developer product granting a specified cosmetic credit/item to a selected eligible recipient | Social generosity in a co-op game | Later; requires duplicate/offline recipient/durable delivery handling; demand unproven |
| Company celebration pack | Repeatable consumable: a selected end-of-shift confetti/stamp effect, cosmetic only | Fits funny crew results without rescuing a bad run | Low-confidence optional test; do not assume this will be a revenue pillar |
| Truck/locker/nameplate styles | Guaranteed persistent cosmetic unlocks, catalogue purchase | Hub status and company identity | Later: truck ownership/host selection is undefined; crew members must understand whose style applies |
| Supporter/company pack | One-time pass with cosmetic identity, presets and a transparent fixed bundle | Simple launch shop before recurring catalogue exists | Finite lifetime revenue; not a substitute for ongoing content |

For the first paid validation, show a **real preview of one finished equipment set and two alternate styles** after the player understands the game. Keep a free earned style equally well presented. Do not treat a concept-art survey or shop click as payer conversion; use successful durable receipt grants and actual equipping. Prices are not locked; test with displayed current prices and the actual country/price cohort. Prefer one catalogue and plain offers over layers of token currencies.

Different motor sounds can be paid identity, but they must preserve server-authoritative noise radius/timing and threat balance. Provide a preview, normalize perceived loudness, protect Harlow warning cues, and allow the player's cosmetic audio volume to be reduced. Rare cosmetic means presentation/collection status, not secretly safer equipment. Compare whether players notice another person's customization at normal gameplay size.

Do not start with paid revives: the present game already rehired caught players after about eight seconds, so charging for survival would either sell a trivial wait skip or change the core fairness model. Avoid paid quota completion, bribing Harlow, paid speed/quietness, rescue popups at death, and progression skips before the progression is enjoyable. Paid random vacuum crates are not the recommended launch route; guaranteed choice is clearer and tests demand for the actual art. If paid randomness is ever proposed, [Roblox's paid-random-item requirements](https://create.roblox.com/docs/production/monetization/paid-random-items) become part of that design, including per-user restrictions and odds disclosure.

[Creator Rewards](https://create.roblox.com/docs/creator-rewards) may provide eligible engagement/audience revenue, but eligibility and user mix matter. Do not assume every ten-minute session pays or prolong the lobby to hit a threshold. Treat rewards as a measured additional line, not the business case.

## What is already instrumented, and what is missing

Verified repo events include contract_started, first_cleanup_started, pile_cleared, cargo_picked_up/dropped/banked, noise_investigation, chase_started, player_caught, quota_met, optional_salvage_attempted, shift_ended and replay_started. There is a vocabulary whitelist, build/platform/party/variant context and an in-memory Studio evidence ring. Studio analytics do not constitute public-platform retention data. No persisted career/wage payout is wired into Shift banking.

Missing for the next test: first visit and depot onboarding/queue/teleport failure boundaries; first bank timestamps; persistent reward granted and actually equipped; goal exposure/selection/completion; experiment enrollment/exposure; catalogue impression/preview/prompt plus successful receipt grant. Separate receipt grants from purchase-finished callbacks. Add bounded SKU/goal/experiment vocabulary through the existing analytics layer, not arbitrary strings or a second receipt owner. Audit the existing three custom-field packing before extending it. Measure core-loop funnels from the server. [Roblox funnel guidance](https://create.roblox.com/docs/production/analytics/funnel-events) documents published server event requirements.

Across depot/reserved shifts/replays, count one player acquisition journey and a distinct canonical run ID. JobId is a server session, not a whole user visit. A teleport, reconnect or replay must not mint career rewards twice. Atomic persistent payout records belong with profile transactions; reuse Currency, Inventory and the Marketplace receipt architecture, rather than allowing clients to award XP/skins.

## Validation plan and decision rules

### Phase 0: technical and qualitative validation

Test with 20–30 unfamiliar players, deliberately including solo entrants, friends and phone players. Family feedback is useful for bugs but not evidence of general retention. Observe silently: can they begin cleaning, bank, interpret threat, understand overtime, and choose a next goal without the developer? Ask afterward what they were trying to earn and whether the second shift felt meaningfully different. Do not coach or pay players contingent on returning.

Record first action, first bank, first shift completion, optional salvage participation, voluntary second shift, quitting/waiting points and errors. Internal provisional gates: median first meaningful action ≤90 s; at least 70% of entrants complete their first bank within 5 min; at least 35% of first-shift finishers start another shift in that visit. These are chosen planning gates, NOT Roblox benchmarks and NOT already achieved. Always show the all-entry completion/replay rates too; a high finisher-only replay rate can conceal massive early churn. Do not treat these short-term indicators as D1/D7.

### Phase 1: baseline with the minimal persistent loop

Recruit a cohort across multiple days and allow everyone at least seven full days to mature. A practical initial 200–500 new players is directional evidence, not an adequately powered A/B test for a small lift. Track acquisition source, device and party situation at entry. D1/D7 use eligible first-play cohorts; count all assigned/entering players, not just finishers, payers or goal users. Separate D7 exact-day return from cumulative 'returned sometime in the first week' and total seven-day playtime. Use Roblox's cohort definition/time boundaries for comparisons. [Retention documentation](https://create.roblox.com/docs/production/analytics/retention).

Initial internal goals for a commercial candidate: D1 20%, D7 8%, to be revised using our actual audience, acquisition economics and the [similar-experience benchmark](https://create.roblox.com/docs/production/analytics/analytics-dashboard) once available. These numbers are planning assumptions, not universal success bars or sourced genre averages. Also track time to next goal, goal recall, unlock/equip rates, solo versus friend behavior, catches-to-quit, teleport failure, and actual repeat-shift variety. If core voluntary replay is poor, stop expanding the shop and repair the loop first. If D1 is acceptable but D7 weak, examine exhausted goals, repeated threat/layout patterns and progression pace; do not assume the XP amount is the sole cause.

### Phase 2: causal feature tests

Test one hypothesis at a time on comparable acquisition cohorts. Assign persistently per player across places and visits for personal goals, with server enforcement. Shared contract/crew experiments need consistent crew assignment and cluster-aware analysis. Friends can influence each other; ordinary independent-player power calculations are optimistic for co-op groups.

Experiment A: control has the same rewards; treatment clearly displays one next passport/locker target after the first shift. Primary metric D1; guardrails first-shift completion, time to fun, player confusion and crash/teleport rate. Freeze the existing per-shift hidden-salvage A/B at B during this test; it is not a persistent player-retention assignment and must not be conflated with the new experiment.

Experiment B, after A: keep presentation/progression fixed; add casebook/mastery choice or a distinct contract modifier, one at a time. Primary metric D7; secondary seven-day distinct play days and cumulative playtime, not just longer single sessions. Adding an entire feature bundle may validate the bundle but cannot identify the feature responsible. Do not compare goal users with non-users as proof: motivation causes both adoption and retention.

Pre-register primary metric, assignment, expected baseline, minimum useful lift, sample/time window, harm criteria and decision. Avoid peeking daily and calling a fluctuating percentage a winner. [Roblox Experiments](https://create.roblox.com/docs/production/experiments) supports player-specific configurations; eligibility/access must be verified before relying on it. A specced game-side stable assignment is the fallback, not the current per-shift alternation.

Calculated planning examples, 95% two-sided / 80% power, independent players: D1 20%→25% needs about **1,094 per arm**; D7 8%→11% about **1,499 per arm**. These use hypothetical baselines, normal two-proportion approximations, no multiple-test correction and no crew clustering. Observed 20/100 returning gives a Wilson 95% interval about 13.3–28.9%; 100/500 gives 16.7–23.7%. Observed D7 40/500 gives 5.9–10.7%. Small samples cannot 'prove' a modest lift. Wait for the last included cohort to mature before the final readout; low traffic means longer tests or explicitly directional decisions.

### Phase 3: actual monetization test

Only once players demonstrate repeat interest: one finished free unlock and a small guaranteed paid catalogue. Track eligible shop exposure, previews, prompts, receipt grants, equipped purchases, payer conversion, net creator earnings per acquired player, repeat spend and seven-day retention. Retention versus revenue is a joint decision: higher spend with worse return/crew fairness may not improve lifetime value. Survey willingness and click-through are weak evidence; actual grants are stronger. Paying-user counts will be small initially, so revenue estimates need uncertainty and may be dominated by one spender.

Business gate: compare acquired-player cohort revenue (including actual measured Creator Rewards if any) over a declared horizon against acquisition cost, ongoing art/content/support cost and delivery cadence. Positive gross revenue is not profit; a seven-day revenue deficit does not establish negative lifetime value, either. Public competitors do not reveal these numbers. Scaling acquisition before these measurements would be a bet, not validation.

## Recommended next work

1. Retain the working horror/cleaning loop and existing event signals. Fix first-minute friction before adding a shop.
2. Define a tiny server-authoritative career passport/locker slice, run payout ledger, one earned equipment style and a visible next goal. Spec payouts/duplicate runs/cross-place persistence before implementation.
3. Add onboarding and goal instrumentation; publish a controlled playable build through the sanctioned manual process when authorized, then conduct stranger cohorts. No public test has been run yet.
4. Add casebook/mastery/contract variety only according to observed boredom and return reasons.
5. Validate an actual cosmetic catalogue. Start with permanent earned identity + guaranteed paid customization; expand repeatable dev products only when catalogue demand exists.

## Production-art feedback recorded

Keyboard and truck are rejected as finished candidates. The keyboard is literally six elongated keys in one row: replace with a readable staggered multi-row layout, spacebar/modifier/navigation clusters and a coherent case silhouette; bake small legends rather than constructing excessive key geometry.

The cab currently inherits the 12-stud bed width and is a shallow 12×6×5.8 box with flat glass and no wheel arches. It reads like an oversized bus front on a flatbed. Rebuild silhouette from a specific compact work-truck reference: distinguish cab/body/chassis, windshield rake, nose, wheel arches, tire stance, wheelbase and boarding step. Keep company material language, but do not let the initial queue volume dictate every visible proportion. If bed scale changes, adjust visual and gameplay boarding bounds together and verify four avatars; do not leave an invisible queue extending outside the bed. Review front/side/three-quarter views before detail. The previous art proof remains a study, not approved final art.
