# Harlow direction and the remaining MVP

Design proposal only. No manager behaviour, speed, sensing, catch or noise code changed in this pass.

## The problem

Navigation fixes make a pursuer function; they do not make an encounter interesting. A large map plus a uniform patrol can produce long empty stretches. A pursuer that simply runs faster produces the opposite problem once spotted: an inevitable catch without a meaningful decision. We need control over encounter pacing, readable suspicion, and an escape sequence with counterplay.

## Recommended MVP identity: the manager who expects you to work

Harlow alternates between paperwork, a telegraphed inspection and a short pursuit. Keep one memorable special behaviour and one clear escape system before adding a catalogue of powers.

1. **Paperwork / quiet start.** Start with a proposed 45–75 seconds to orient, clean and joke with the crew. Harlow is physically present at a desk with a lamp, pen scratches and chair creaks. A slow head turn toward activity behind him is a warning before his body turns. Make this readable on mobile as well as audible. These timings are hypotheses for playtests, not settled balance.
2. **Inspection.** He puts down the pen, stands and announces an inspection through a light/voice cue. Choose a plausible inspection destination based on the last heard activity or actual work areas, then navigate there; do not feed hidden player coordinates into pursuit. Route inspections across active work clusters so a solo player does not need to hunt him for five minutes. Aim to test a first meaningful encounter around 60–120 seconds, while allowing some variation.
3. **Suspicion / look busy.** A visible cleaner who makes real cleaning progress can reduce suspicion before a chase. Holding the vacuum over an already clean patch must not count. Carrying marked salvage, rummaging, or running through his inspection gives a different response. Clear gestures and a short readable warning let a newcomer learn the rule. Cleaning must not become permanent invulnerability; he eventually asks you to clear his route or moves the inspection elsewhere.
4. **Chase / escape.** Once he commits, merely pressing the vacuum or sitting down does not cancel him. He has a brief, loudly telegraphed burst, then a recovery period. Use that window to break line of sight and take a different route or hide behind appropriate furniture. He checks the last seen location and a small number of plausible nearby hiding positions, without knowing which one contains the player. Staying quiet and unseen ends the search. Running indefinitely around one chair should not be the optimal escape.
5. **Back to work.** The end of a search has a distinct audible/visual tell. Harlow resumes an inspection or returns to a desk, with a short pressure break before targeting the same player again. In co-op, evaluate target changes visibly and avoid rapid arbitrary switching.

### What to do with desks

Use sitting primarily for Harlow's identity. A player pretending to work at a terminal could be a later pre-chase bluff with an actual short task and limited tolerance. Instant sit-to-erase-aggro would trivialize the monster and confuse the cleaning fantasy. Do not add it as a chase escape button.

### One optional horror signature

During paperwork, his head turns farther than his torso, pauses while facing a sound, then his chair slowly rotates. During an inspection, nearby fluorescent lights warn of his approach. These cues create anticipation and work with the office theme. Avoid unexplained teleporting onto players, random unavoidable catches, full-map omniscience and paid escape items.

### How we would test it

Compare solo and four-player shifts: time to first encounter, long stretches with no nearby Harlow, chase duration, escape/catch ratio, repeated-player targeting, and whether newcomers can explain what caused suspicion and how they escaped. Log whether an escape used sight breaks, hiding or the safe bay. Provisional target: clean play should sometimes avoid a chase; a chase should sometimes be escaped on the first session without an exploit. Do not promise retention from this design alone.

## Equipment audit

The native Tool/hotbar vacuum, suction/canister/bag loop and carry integration exist. Studio has no approved `ReplicatedStorage.Assets.CleanupCrew.Vacuum` template, so the source-shape fallback is active. New vacuum A/B Blender candidates exist but are not the selected runtime mesh. Custom equip/hold/use/stow clip sources exist; permanent activation and broad avatar/contact checks remain.

The truck boarding/queue and bed banking systems exist. Runtime `DepotTruckVisualSystem` builds the native-part truck. The newer truck-B mesh export exists but is not loaded by that builder. Integrating selected art must preserve the bed volume, crew boarding, cab clearance, cargo drop/throw banking and collision behaviour. Equipment art selection/integration is the next coherent art task, rather than creating another disconnected candidate.

## Necessary before an external MVP test

1. This camera repair, obvious asset defects, and a complete repeated shift loop: queue → equip/clean/empty → search/carry/drop/throw/load → quota → clock out/results → return → another shift.
2. Agree and implement the small Harlow encounter design above, then tune map workload and travel with solo and co-op. Existing 16–24-room generation can stay while we first test encounter routing; use smaller end of that range for solo if travel is still excessive.
3. Integrate one vacuum and one truck art choice; validate essential animation/contact and readable vacuum/truck feedback.
4. Finish a brief contextual first-shift tutorial and cross-device input/HUD checks, especially touch and gamepad.
5. Run real 2–4-player tests for concurrent pickup/search/banking, catching/respawning/leaving and repeated shifts. Profile a real phone, not only Studio.
6. Verify analytics for first clean, first bank, first encounter, catch/escape, quota, completion and replay; then invite unfamiliar players. Retention and paid demand remain unvalidated until public tests.

## First public version, after the private loop works

One saved reward and visible next goal (earned equipment style or company milestone), a clear gear preview, data/persistence checks and release ownership/moderation validation. Keep monetization small and cosmetic after there is something desirable to buy. Do not block the first learning test on a large shop, many ranks, multiple monsters or an enormous art expansion.

Still queued: recycling-box interior, fish-tank/static replacement decision, room-purpose dressing and wayfinding, selected interactive doors, broader sound/light polish, vacuum-noise investigation tuning, uniforms/name/rank tags and secondary animation polish. Prior backlog documents contain wider launch ambitions; those are not all prerequisites for testing the MVP.
