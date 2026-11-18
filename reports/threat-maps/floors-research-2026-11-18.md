# Floors-mode research (2026-11-18)

Scope: how run-by-floor games structure floors, transitions, threat ramps, deaths, rewards.
Method: web search plus page fetches. Fandom wikis (Dandy's World, DOORS, Lethal Company) returned HTTP 402 or
bot walls, so I used mirrors, guides and fan wikis. Everything is paraphrased. Tags: [V] = read on a fetched page,
[S] = search snippet only, [?] = could not verify or sources conflict.

NOTE: several guide sites here are low-quality content farms. I leaned on them only where two sources agree
or where the claim is mechanical and low-stakes.

---

## 1. Dandy's World (Roblox)

- Per-floor goal: fill ("extract") every machine on the floor, doing skill checks, while Twisteds chase you.
  A failed skill check alerts nearby Twisteds. [V] https://itemlevel.net/?p=228139
- Machines and Twisteds: regular floors have 4 to 20 machines and 2 to 6 Twisteds; both counts depend on how
  many floors you have reached AND how many players are still alive on that floor. [V]
  https://techwiser.com/all-floors-in-dandys-world/
- Transition: when the last machine is done the elevator opens for only a few seconds, and anyone not back
  inside dies. Tip: do the machines nearest the elevator last. [V] https://itemlevel.net/?p=228139
  Design note: this is a short "everyone converge" beat, not a long walk.
- Threat ramp: runs are open-ended ("floors for as long as you survive"). Each floor is harder: more machines,
  tougher Twisteds. New floor layouts unlock by floor count (e.g. some after floor 6, 11, 16). [V] techwiser URL above.
  Spawn-chance of Twisted rarity shifts by floor band (common 69% on floors 0-4 down to ~59% on 25-29). [S]
  https://itemlevel.net/?p=232066
- Challenge floor: "Dyle's floor", 25 machines, 3 common Twisteds plus one lethal one-shot Twisted; voted in via a
  card after odd floors, only after 9 floors; reward is +50 max stamina for the rest of the run. [V]
  https://rblxguide.com/games/dandys-world/floors
- Break floor: a Break Room every 25 floors: 2 machines at fixed spots, no Twisteds, no floor events. [V] rblxguide URL.
- Between floors: team votes on one of three cards before each odd floor; Dandy's Shop sits in the elevator
  before each even floor (3 random items for tapes). If every living player skips the shop 3 floors in a row,
  the (instakill) Dandy shows up. [V] itemlevel URL. Nice: skipping spending creates tension.
- Rewards: tapes per fully extracted machine (10), per unique Twisted met on a floor (5), plus pickups. Ichor
  and research are meta currency; exact rules unclear. [V]/[?] Ichor-on-death details are ambiguous in one source.
- Death: a dead player does not come back on that floor (community comment, [?]). Run ends when everyone is dead.
  Whether the dead spectate: not found.
- Run length / floor time: not found. [?]
- Lobby progress display: not found. [?]

## 2. DOORS (Roblox)

- Structure: Hotel = 100 numbered doors (rooms) in a straight line, one room at a time. [V]
  https://rolearn.dev/guides/doors/ Floor 2 "The Mines" is also ~100 generated rooms per the Fandom wiki snippet [S]
  https://doors-game.fandom.com/wiki/The_Mines , but a boss guide mentions "Door 150" and ~100 new doors, so the
  Mines numbering continues past 100 (doors ~100 to ~152). [V/?] https://itemlevel.net/?p=237555
- Per-room goal: find the key or solve the room puzzle, open the next door; hide from entities.
- Transition: just open the next door (no elevator inside a run). The elevator is the lobby/pre-run space where
  the shop lives. Mid-run "checkpoints": the DOORS wiki's Upcoming page only says mid-run checkpoints were being
  considered [S]; one guide claims rest rooms with save points in the Mines [?] low quality.
- Threat ramp: early entities are brief and teachable (Rush early), then Figure at door 50 (library) and 100
  (finale), Seek chase sequences from roughly door 30-45 and again later, Ambush (a faster Rush with
  bounces) around 65-90. Exact door numbers conflict between guides. [S/?]
  https://www.speedrun.com/roblox_doors/guides/woj64 https://gameleap.com/articles/roblox-doors-all-monsters-how-to-survive
  Pattern: new rule introduced every ~15-30 rooms, then combos.
- Revives: one use per run; 2-minute window; must wait for Rush/Ambush/Seek/A-120 to despawn (anti-camp);
  not usable past Hotel door 90 or Mines door 190, nor in The Rooms. [V] https://wikiwiki.jp/doors_jp/Revive
  Revives come from earning or buying (real money optional). [V] rolearn URL
- Rewards: Gold is per-run, found in rooms, spent at Jeff's shop around doors 53-59; leftover Gold converts to
  Knobs at run end. Knobs persist, spent in the elevator shop before a run. [V] rolearn URL
- Run end: beating door 100 (Hotel) or the finale; death with no revive ends your run (you spectate). [S/?]
- Run length: not verified here (commonly cited about 30-60+ min for a full Hotel run; [?] no source fetched).
- Lobby progress: elevator shop, badges; no depth leaderboard found. [?]

## 3. Pressure (Roblox)

Source quality is low: the main page I could read is a fan "wiki" on pages.dev that looks partly machine-written.
Treat details as [?] unless corroborated.
- Run = a sequence of 100 numbered rooms with a procedurally generated facility, final stretch "The Ridge"
  (rooms 90-100): about 2.5x entity spawn rate, up to 3 Squiddles per room, more locked doors, ~30% less
  long-range visibility. [?] https://pressuregame-wiki.pages.dev/room-types and /how-to-play
- Room archetypes: standard rooms, safe-ish "Oxygen Gardens" with low spawns, narrow high-threat tunnels,
  heat zones, rare dangerous rooms, keycard-locked heavy containment. Generation chains rooms by allowed
  neighbours so sequences feel authored. [?] same page.
- Shops: pre-round shop plus a shop around room 50, prices rise with depth; Kroner currency. [?]
  https://pressuregame-wiki.pages.dev/how-to-play
- Health: 100 HP; a "lethality buffer" sets you to 1 HP instead of a one-shot kill, once per damage source. [?]
- Run end: reach the end airlock with the Crystal; then Endless Mode scales forever. Revive tokens exist
  (code rewards); in-run rule unclear. [?] https://pressuregame-wiki.pages.dev/faq
- Checkpoints: not on the pages I read; sources conflict. [?]

## 4. Lethal Company

- Loop: ship lands on a moon, crew collects scrap, goes back to the ship, takes off, and sells scrap at the
  Company building on the quota deadline day. Quota reset each cycle. [V/S] https://lethal-company.fandom.com/wiki/Profit_Quota (snippet)
- Quota: first quota is 130. Later increases follow a quadratic-ish curve with a random factor, so each step is
  larger than the last. Exact vanilla constants not verified. [S] same wiki; community code analysis:
  https://ambco-iscte.github.io/posts/Using-Probability-Theory-to-Benefit-the-Company
- Deadline: 3 working days per quota (a 4-day counter including day 0). [S]
- Failure: miss the quota on deadline and the crew is ejected into space; ranks reset to the start and a new
  save begins. [V] https://gamertweak.com/what-happens-when-you-die-lethal-company
- Crew death: dead players are not revived mid-trip; they respawn when the ship takes off next. Penalty fines
  apply and are smaller if the body is brought back. If everyone dies the ship leaves with whatever scrap
  is aboard and the scrap carried by the dead is lost. [V] gamertweak URL (some forum sources disagree on exact
  scrap/credit rules, [?]).
- Shop between trips: buy gear with credits from the terminal in orbit. [S]
- Rewards: Credits per sale; banking is implicit (scrap sold is safe, scrap on the ship is kept until sold).
- Calm moments: orbit time, plus the Company building trip (low threat). 
- Length: one moon trip about 10-20 min [?], a quota cycle about 1 hour. No source fetched.

## 5. R.E.P.O.

- Loop: each level has a loot goal (haul). Carry valuables to extraction points, fill them, then everyone gets in
  the truck. Levels 2+ add multiple extraction points; you cannot leave until each point is satisfied. [S]
  https://www.thegamer.com/repo-how-to-extract/ and a level guide https://www.lagofast.com/en/blog/the-complete-guide-of-repo-levels/
- Per-level numbers (one guide, approximate, levels 1-9): extraction points go 1, 2, 2, 3, 3, 4, 4, 4, 4;
  quotas vary rather than climbing steadily (about 8-12k on level 1 up to about 26k on level 9). [V] lagofast URL
  Monsters get nastier and layouts more maze-like.
- Between levels: the truck visits a Service Station (shop; heals; the only checkpoint save per one guide).
  [S] https://repo-2025horror.fandom.com/wiki/Service_Station (snippet only)
- Death/revive: a dead player is reduced to a head; carry the head to the extraction point (or the truck)
  to revive. Sources disagree on the exact spot. If everyone dies, the run is over. [S/?]
  https://www.gamesradar.com/games/horror/repo-revive
- Failure: sources say a failed quota or all-dead leads to a game over that deletes the save. [S/?]
- Rewards: money from banked loot; the shop buys upgrades (carried through the run).
- Run length: no fixed cap; no official level count found. [V]

## 6. Deep Rock Galactic (for the "leave vs push" check)

- One mission = one dig; the team leaves via the drop pod after the primary objective. A mission counts as
  success only if the objective is done AND at least one player is pod-extracted. [S]
  https://deeprockgalactic.wiki.gg/wiki/Mission (snippet)
- Hazard level and "warnings" (mutators) add a payout bonus, so players choose harder content for more reward.
  Pod extraction pays per surviving dwarf. [S] https://deeprockgalactic.wiki.gg/wiki/Anomaly
- Dead dwarves are revived by teammates in-mission; there are no lives. [?] not verified on a fetched page.

## 7. Hades / Spelunky (roguelite descent)

- Hades: runs go chamber by chamber; clearing a room spawns the reward and unlocks doors; doors show the
  reward icon so players pick the path (a choice every room). Death ends the attempt but keeps permanent
  progress. [S] https://hades.fandom.com/wiki/Chambers_and_Encounters
- Spelunky 2: three shortcuts (start at 1-4, 2-4 or 4-4) unlocked by finishing the earlier zone; they give
  new players a feeling of progress. [S] https://twinfinite.net/guides/spelunky-2-use-shortcuts-skip-levels/
  A game-design essay argues checkpoint distance sets how risky progress feels. [S] https://gamedeveloper.com/design/in-defense-of-major-setbacks
  (about a different game; used only for the principle).

---

## Cross-game patterns

| Question | Almost all do | Distinctive |
|---|---|---|
| Per-floor goal | A concrete, countable task (machines, doors, loot haul) | DOORS: just "reach next door"; Dandy's: skill-check mini-games |
| Transition | A crew-gather beat (elevator, truck, pod) | Dandy's: elevator opens a few seconds, stragglers die; REPO: truck waits for everyone |
| Threat ramp | More enemies and more tasks per step; layouts get harder | DOORS: new entity every ~20 rooms; Pressure: last 10 rooms spike; REPO: extraction points 1 to 4 |
| Early calm | First steps teach one rule gently | Dandy's Break Room (every 25 floors); Pressure safe rooms |
| Shop between steps | Yes (elevator / Service Station / terminal) | Dandy's: skipping the shop 3 times spawns Dandy |
| Crew death | Dead players are out until a gather point or a limited revive | DOORS: 1 revive per run with anti-camp rule; REPO: carry the head to revive; Lethal: respawn at takeoff |
| Run end | All dead, or a final goal reached | Lethal: miss quota; Pressure: Endless Mode after the win |
| Reward timing | Per-run currency plus a persistent one | DOORS: Gold converts to Knobs; REPO/Lethal: banked only when sold/extracted |
| Hub progress | Badges, cosmetics, unlocks | No depth leaderboard found in any source (likely exists, not verified) |
| Run length | Open-ended or around 100 steps | Not verified for any game |

---

## Design lessons for Odd Hours Floors mode (short sessions, kids, 3 lives)

1. Keep each floor a full short loop (about 5-8 min) with a clear countable goal. Our contract is already that,
   so a floor = one shift. Dandy's and REPO both anchor on a countable task per level. (Sections 1, 5)
2. Make the floor-to-floor beat a crew-gather moment, not a long walk: the truck/elevator waits, with a short
   "everyone back" window. Skip Dandy's instakill for stragglers; use a visible countdown plus a safe rescue
   (carry or auto-pull). (Section 1, 5)
3. Ramp with one new rule at a time, with a calm opener: Floors 1-2 teach, then introduce one new pressure
   every 2-3 floors (faster Harlow, darker lights, a bigger quota, a second hazard). DOORS adds a new
   entity every ~15-30 rooms, then mixes them. (Section 2, 3)
4. Insert a calm floor on a fixed beat (e.g. every 5th floor): no monster, a small contract, bonus shop.
   Dandy's Break Room every 25 floors; ours should be much more frequent because sessions are short. (Section 1)
5. Scale quota and monster with players ALIVE as well as floor number, as Dandy's does, so a half-dead crew
   is not crushed. (Section 1)
6. Use the "bank or push" choice at the elevator: after a floor, the crew can cash out their haul (safe,
   ends run) or go down with more risk and a multiplier. Gold converting to a permanent currency at the end
   (DOORS) is the safest model; losing banked rewards on a wipe would be harsh for kids, so make the downside
   "lose the run's unspent bonus", not saved progress. (Sections 2, 4, 5, 7)
7. Death rules: keep our 3 coat layers per player, and add a limited rescue instead of permanent death:
   a downed player returns at the next elevator, or a teammate revives them once per floor (REPO head-carry /
   DOORS once-per-run revive with an anti-camp rule). Never permanently bench a kid for a whole run. (Sections 2, 4, 5)
8. Show doors/choices that preview the reward (Hades door icons, Dandy's cards) so each floor ends with a
   quick, readable crew decision, e.g. pick one of three cards: a lamp, a bigger vacuum, an extra layer. (Sections 1, 7)
9. Late-run spike, then a finale: reserve the last stretch of a "set" for a big beat (Pressure's Ridge,
   DOORS door 100). For us: a boss shift every N floors rather than endless drift. (Sections 2, 3)
10. Hub progress: record "deepest floor" for the crew and per player (not found in sources; this is our
    own design), plus a permanent currency conversion at run end. Mark it as untested.

## Gaps (not verified)

- Real run length and floor time for any game; DOORS checkpoints; Pressure details beyond a low-quality fan wiki;
  exact Lethal quota constants; R.E.P.O. level counts and death rules beyond guide sites; DRG revive rules;
  any hub depth leaderboards.
- Fandom wikis blocked automated fetches (HTTP 402), so wiki claims marked [S] come from search snippets only.
