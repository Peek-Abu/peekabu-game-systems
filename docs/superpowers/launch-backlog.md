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
