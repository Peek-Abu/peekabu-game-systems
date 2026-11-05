# Odd Hours: first-launch backlog

> **The live list is now the Odd Hours Launch List: https://claude.ai/artifact/Ax27MKsdzqr2gkX1b9dESB**
> (rebuilt 2026-11-05 from this file, the pre-launch inventory, the Launch Board, the old checklist and the
> git log). Its rows live in the page's db collection `items` (statuses check / decide / doing / todo / cut /
> done) and the play-check route in `steps`. Update rows there with ArtifactData; only the owner sets done,
> after real play. This file keeps the history and the reasoning. The route is also in
> [odd-hours-play-check-2026-11-05.md](odd-hours-play-check-2026-11-05.md).
> Tags below: **[built, waiting for check: sha]**, **[not a bug]**, **[cut]**, **[passed]** (the owner played it).

These are kept separate from the MVP board, as the user asked. Writing an item here does not mean
building it now. Each one is planned in the first-launch ideation, after the remaining MVP board items.

## From the 2-player tests with family (2026-10-18)

- **Voice chat doesn't work.**
  - The game uses the routed proximity voice (Audio API, `VoiceChatService.UseAudioApi = Enabled`).
  - Check the experience's voice settings on the Creator Dashboard, account eligibility (voice needs an
    ID-verified 13+ account), and the routing in a live server.
- ~~**Map quality, the big one.**~~ **[passed]** Office stages 1-4 (kit generator, real halls, outside,
  per-run variety) signed off by the owner on 2026-10-24. Polish rounds and lighting stay open on the list.
  - The office is a code-generated blockout. It looks low quality next to the characters and UI, and it
    has no real hallways.
  - It probably needs a full rework, built by hand in Studio.
  - Check props and valuables to the same quality bar.
- ~~**Hiding looks bad to other players.**~~ **[passed]** (old checklist, 2026-10-24). There's a lot of
  clipping and the poses look wrong from outside. The local view is fine.
- **Separate places for maps.** Built in code (hub + one Shift place); the real hop still needs a test on the
  published places. Running the hub and office in the same place causes many bugs. Use
  TeleportService: one lobby/hub place plus one place per map. The base Queue already does
  reserved-server teleports, arrivals and return trips, so this is mostly setup.
- **Hub built in Studio, and a team-friendly workflow.** If the game earns enough, the user will hire
  modelers, builders and designers. Maps and the hub should be built in Studio, with code finding gameplay
  points through tags and attributes, so non-coders can work in the usual Roblox way.

## Earlier post-MVP feedback (2026-10-18), done or in progress

- Character portraits (viewport): done.
- UI scaling and readability: done.
- Settings sliders, trimmed to 3: done.
- Vacuum invisible after respawn: done.
- Moving under the Rehired card: done.
- Name tag and health bar on dead players: done.
- Face mismatch between players: done.
- Trackpad UX: dropped by the user.

## Carried over from the security, performance and base passes

- Faked party in the teleport ticket: the departing server should store the real party server-side
  (MemoryStore), since a cheater can edit the ticket.
- Movement anti-cheat: speed and teleport checks.
- Per-player rate limit on interaction prompts (base Interaction). **[built, waiting for check: 9be42939]**
- `InputControlsSystem` movement lock needs reference counting (base).
- About 1,300 decor props cast shadows. Check whether turning shadows off on small props is worth the
  visual change on phones.
- Stamina is sent to every player 20 times a second.
- Measure on a real low-end phone or tablet: the MicroProfiler, and the cost of the screen-effects fix.
- `SpecRoots.luau` is over the 400-line limit and needs splitting (653 lines on 2026-11-05).
- `UISuppression.luau` fails `check_pr_rules` on the game branch. Port PR #11's Modal approach.
- ~~Merge base PRs #10 and #11.~~ **[done]** merged 2026-10-24.
- `RankServiceServer.spec:178` fails in every full suite run (2026-11-04).
- `TeleportOptions.ReservedServerAccessCode` is deprecated; move the base Queue to `ReservedServerId` (base fix,
  test on the published places).

## Future updates: keeping the first minutes engaging (owner, 2026-10-23)

Raised while planning the outside (stage 3): the truck now parks about 200 studs (12.5 s) from the dock door, and the
owner worries about players getting bored on the walk and leaving in the first minutes. Not for stage 3; noted for
later updates. (The exterior hints, Gloom ooze under the dock door and the anomaly pool, are already in the office map
plan and are not repeated here.)

- **Arrival as an event.** The truck drives in and parks while the crew stands in the back (like Lethal Company's
  landing), plus a short dispatch radio line with tonight's quota and one hint ("Facilities reports a leak in the east
  wing"). Biggest hook; new work, since the truck is never animated today.
- **First payoff within ~30 s of entering.** Guarantee Gloom and an item or two in the dock room or the first hall.
- **Cheap walking outside.** Outside and empty-handed: free sprint, slightly faster than normal. The trip in is quick;
  only the loaded trip back is slow (the tense part). Sprint and carry slow-down already exist (`CarrySpeedSystem`).
- **Fewer banking trips, not shorter ones,** only if play-tests show carrying feels like chores: a dolly/cart at the
  dock, or let crews stage loot by the dock door like Lethal players pile scrap at the entrance.
- **Measure drop-off.** Extend shift analytics with when each player leaves (shift second) and where (truck, yard,
  inside), to see whether the walk actually loses people.

## Future: office map growth (owner, 2026-10-23)

- The generated office is built inside the fixed exterior shell (wrapped, so door teleports are 12-24-stud hops and
  Roblox's lighting is already built around you). For bigger or different maps later, either give each map its own
  exterior sized to its envelope, or move the interior underground beneath the site (Lethal Company style) so it can
  be any size. Test first how far a door jump can be before Roblox's lighting stalls (20-40 studs: instant;
  1,600: a visible stall; 100-200 untested).

## Polish phase (owner, 2026-10-23)

To do together on a polish day, not now:
- **Underground interior test (100-200 studs):** measure whether a door jump of 100-200 studs is as quick for Roblox's
  lighting as the current 12-24-stud hops (see "Future: office map growth" above). If it is, the interior can move
  under the site and grow freely.
- **Sound groups in SoundService:** **[built, waiting for check: 0d278e4d]** (sound places: each player hears only
  their own place). route sounds through SoundGroups by place, e.g. a Building group muted (or heavily
  muffled) while the player is outside, an Outside group for the yard, so office zaps, phones and ambience don't carry
  into the yard through the thin shell (seen in the stage 3 review).
- **[not a bug]** **Carry drift: not reproduced (2026-11-04).** Eight clean 20-30 s idle windows in the shift place held still at
  0.00 studs: Monitor, fish tank, mug, plaque, Bottle bag; with and without an Enter teleport; arm IK on and off; no
  Harlow. Every drift in the stage 3 report came right after an Enter, along the player's facing, once without any item,
  in a probe session (server `pickUp`, a camera override). Two sudden jumps (not a slow slide) were seen only in probe
  runs right after server-side pickups. Watch for it in the owner's real-input play; nothing to fix until it shows there.
- ~~**ByteNet "No readable entity found for ID: 17"**~~ **Not a game bug (2026-11-04):** a Studio-tooling artifact. A
  Studio MCP `execute_luau` call runs in the plugin VM with its own module cache. Requiring any module there that loads
  ByteNet (a service, an Events module) starts a second ByteNet copy. That copy makes a second `BytenetStorage` folder
  and hooks the same `ByteNetReliable` remote, with a packet table holding only what it loaded. Every client packet it
  doesn't know then logs `process.read:108 ... No readable entity found for ID: N` from `onServerEvent`, the report's
  exact stack. Reproduced: one plugin-VM `require(CarryEvents)`, then a real client `Sprint` packet (ID 38) gave that
  error, while the game's own reader read it fine. A live server has no plugin VM. In Studio probes, require game
  modules only from an injected Script (the game VM), never from `execute_luau` itself.
- **Office map leftovers from the spec (not in stage 4):** the glass lift that moves on its own (no glass lift exists
  yet) and the rare set piece per run.
- **Per-skin reveal clips (2026-10-29):** every skin purchase now plays the employee's hire reveal in that skin
  (owner, 2026-10-29). The Legendary unlock reveals (Bubble Buddy, Sheriff, PJ Cappy's Cozy Unlock 86895730118507) are
  uploaded and registered but unused; a skin's own reveal slot stays for a later, separate Legendary reveal.

- **Legendary skins get their own idles and fidgets (owner, 2026-11-03):** **[built, waiting for check:
  f957a755, b1d92351, 8b91ea1f]** each Legendary skin (Bubble Buddy,
  Sheriff Prickles, PJ Cappy) gets its own idle and fidget. A skin whose showcase idle holds props skips the employee's
  default fidget, because it will have its own. Fidgets stop while vacuuming or knocked out (already built).

From the owner's stage 4 play-check (2026-10-24):
- **Inside sounds heard outside:** **[built, waiting for check: 0d278e4d]** standing in the yard you hear the office's sounds, Mr. Harlow's footsteps and
  more. This is the "Sound groups" item above, now confirmed by the owner in play: the building's sounds must be cut
  or heavily muffled while the player is outside (and the yard's while inside).
- ~~**The "TOGETHER WE THRIVE" banner is off-style:**~~ **[cut, 2026-11-04]** the anomaly became a leaning lamp
  post on the walk (59357c2c, waiting for check). the plain navy cloth with plain text (the `banner` anomaly slot
  on the podium front) doesn't match the game's look. Restyle it to the Odd Hours art style (drawn detail, the house
  palette and type, kid-level wording), keeping its default and upside-down states.
- **Make the outside its own place, not a quiet backdrop:** **[built, waiting for check]** yard bed, booth radio and
  lamp buzz (06e3db6f, 781bcf96, 3fdeeea8), yard dressing (c0437e6d), cars (726c7464), outdoor footsteps with the
  asphalt fix (52a802c4). Creatures **[cut, 2026-11-05]** (a46332da); the moths and fireflies stay (7b0ec759).
  - its own ambience bed (night wind, distant traffic, buzzing lamps, insects), separate from the office's;
  - more set dressing and assets in the yard, car park and around the building;
  - possibly outdoor creatures or monsters (gameplay or just set dressing: to decide);
  - outdoor footstep surface sounds (asphalt, grass, gravel, puddles) layered on the employee's footsteps, so walking
    outside doesn't sound like the office carpet.
- **Mr. Harlow (the Manager), from the owner's play (2026-10-24):**
  - **Wide turns get him stuck:** he sometimes swings wide round a corner or doorway and snags on walls and furniture.
    Look at his turn rate and path-following in the NPC mover (tighter turns at waypoints, and an unstick step).
  - **Chases start through walls and closed doors:** the chase can begin when he clearly has no line of sight (the
    player is behind a wall, or behind a door he is not looking through). Check his sight test: a ray that ignores
    walls or doors, a view range or cone that is too generous, or a sense that starts a chase without a sight check.
  - **Chases start from sound alone:** vacuuming in another room while he is out of sight can trigger the full chase
    VFX, screen effects and music. Noise should draw him to *investigate* the spot, not start a chase until he
    actually sees the player. Check what the Noise feature feeds into his state, and whether the chase effects key off
    "hunting" rather than "chasing".
  - **[built, waiting for check: 68c71954, 41957a32, c897828a]** **Fixed, awaiting the owner's play-check (2026-11-04):** he slides along walls and jambs instead of wedging
    (NpcPathRules.slide); searching, he sees the one he lost all round only within CERTAIN_RANGE; a noise gives only
    the near look (OccupantDreadFormulas). The pure brain never chased on noise, and walls and closed doors do block
    his ray.
- ~~**Truck departure sometimes never arrives**~~ **Not a game bug (2026-10-24):** it came from the Studio probe, not
  the game. The probe called `departNow` from an injected Script and destroyed that Script at once. `depart` hands the
  arrival to `task.defer`, and the deferred thread belongs to the calling Script, so destroying it killed the arrival.
  Proven: the same call with the Script kept alive 1 s arrives every time, and the real countdown path arrived 3 of 3
  times on fresh Play sessions (1-2 s after boot), with the shift running. Probes must keep the calling Script alive
  for a second or so (`.superpowers/sdd/common-rules.md` notes it).

From the owner (2026-10-29), for polish, not now:
- **Clock out at once still pays XP:** **[built, waiting for check: 832b3ab2]** a shift counts as worked only after
  a cleaned pile or a banked item, and 180 s or a made contract. a player can clock out right after a shift starts and still earn rank XP, so
  XP can be farmed by joining and leaving fast. Look at how the rank award reads a shift as "worked"
  (`RankFormulas.factsFor`) and what a clock-out with nothing done should earn. Check the other quick-leave paths too
  (leaving the server, a fast clock-out vote), and Credits and badges (Clocked In) that ride the same "worked" fact.

## Added 2026-11-05 (truck remake)

- **Truck v3 Moving Van, size B (16 x 24 floor):** **[built, waiting for check: 91f9db7a, 06a86e74]** one template for the
  hub bays and the yard truck, livery line "WE CLEAN UP THE NIGHT!" on the band. Both places must be saved in Studio.
