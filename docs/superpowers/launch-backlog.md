# Odd Hours: first-launch backlog

These are kept separate from the MVP board, as the user asked. Writing an item here does not mean
building it now. Each one is planned in the first-launch ideation, after the remaining MVP board items.

## From the 2-player tests with family (2026-10-18)

- **Voice chat doesn't work.**
  - The game uses the routed proximity voice (Audio API, `VoiceChatService.UseAudioApi = Enabled`).
  - Check the experience's voice settings on the Creator Dashboard, account eligibility (voice needs an
    ID-verified 13+ account), and the routing in a live server.
- **Map quality, the big one.**
  - The office is a code-generated blockout. It looks low quality next to the characters and UI, and it
    has no real hallways.
  - It probably needs a full rework, built by hand in Studio.
  - Check props and valuables to the same quality bar.
- **Hiding looks bad to other players.** There's a lot of clipping and the poses look wrong from outside.
  The local view is fine.
- **Separate places for maps.** Running the hub and office in the same place causes many bugs. Use
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
- Per-player rate limit on interaction prompts (base Interaction).
- `InputControlsSystem` movement lock needs reference counting (base).
- About 1,300 decor props cast shadows. Check whether turning shadows off on small props is worth the
  visual change on phones.
- Stamina is sent to every player 20 times a second.
- Measure on a real low-end phone or tablet: the MicroProfiler, and the cost of the screen-effects fix.
- `SpecRoots.luau` is over the 400-line limit and needs splitting.
- `UISuppression.luau` fails `check_pr_rules` on the game branch. Port PR #11's Modal approach.
- Merge base PRs #10 and #11.

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
- **Sound groups in SoundService:** route sounds through SoundGroups by place, e.g. a Building group muted (or heavily
  muffled) while the player is outside, an Outside group for the yard, so office zaps, phones and ambience don't carry
  into the yard through the thin shell (seen in the stage 3 review).
- **Carry drift:** an idle character holding a carried item slowly slides (about 5 studs in 20 s, seen with a Monitor
  and a Bottle bag). Root-cause it in the Carry feature (`CarrySpeedSystem`, `CarryPlacementSystem`).
- **ByteNet "No readable entity found for ID: 17":** 10 server errors around a teleport-door Enter and a Harlow
  catch. Find which packet is ID 17 and why its reader fails.
