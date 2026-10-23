# Odd Hours office map: match the generator to the approved spike (design delta)

Date: 2026-10-23. Status: draft for owner approval. Amends
[2026-10-22-odd-hours-office-map-design.md](2026-10-22-odd-hours-office-map-design.md). That spec stays the authority
wherever this delta is silent. Source of the values: the spike `Workspace.ClaudeSpike` in the "Odd Hours: Shift" place,
its builder `design/production-art/map-kits/odd-hours-b1/spike/BuildSpike.CommandBar.luau`, its captures in the same
folder, and `HANDOFF-office-map-2026-10-23.md`.

## Intent

Stage 2 built the "odd-hours-b1" art kit and the owner rejected the look. The halls were cramped, the walls joined
badly, the light was cool and dim, and the rooms didn't feel like the mock room. A throwaway spike, an open office
hand-built in the mock-room style, got "Oh my lord – worlds better!" (owner, 2026-10-23). This work makes every
**generated** office look and feel like that spike while keeping everything stage 1 proved: doors, Mr. Harlow's
traversal, the economy and the shift length.

The why behind the open space is gameplay, not just looks. The owner wants long sightlines so Mr. Harlow can't catch
a player off guard round a corner ("Even Lethal is more open in the hallways").

## Goals

1. **Scale (from the spike):**
   - main halls 14 wide, side halls 10 wide;
   - junctions/atrium at least 20×20;
   - ceilings 13 above the floor;
   - long straight hall runs.
2. **Rooms at the spike's sizes,** each with the spike's dressing:

   | Room | Size | Notes |
   |---|---|---|
   | Open-plan pods (large) | 60×44 | Columns, 12 desks in 3 pods, rug, window bay with blinds, floor-standing whiteboard, copier, shelf |
   | Conference | 22×18 | Framed glass wall to the hall |
   | Breakout | 32×26 | |
   | Server | 20×18 | Blue rack LEDs |
   | Storage | 12×12 | |
   | Reception | 28×28 | Warm reception glow |

   **Added (my call, owner said "fine for now"):** a medium pods room of about 44×32 with 8 desks. With fewer rooms
   per run, a single pods size would repeat too visibly.
3. **Walls built like the spike, not stretched templates:**
   - Each wall is two 0.5-thick OH_Plaster slabs (1 thick in all), from 1 below the floor top to 1 above the ceiling (spike: Y 9–24 for a
     floor top at 10 and a 13-stud ceiling).
   - Every run extends 0.5 past its corners, so corners overlap and never show a sliver.
   - OH_Oak wainscot 3 tall, 0.3 proud of the plaster.
   - Rail 0.25×0.5 on top of the wainscot.
   - Skirt 0.6 tall, 0.4 proud (pushed out so it doesn't z-fight the wainscot).
   - Everything is Parts with MaterialVariants. No `wallSolid` / `floorTile` / `ceilingTile` stretching.
4. **Doorways:**
   - a 6.8×9.4 rough opening with a 0.35 oak casing (about 6.1×9.05 clear);
   - plaster pilasters on wide openings;
   - leaves from the `doorLeaf` / `doorLeafGlass` templates.
5. **Glass reads as glass:**
   - the mock's ConfGlass (Glass, Transparency 0.6, tinted);
   - dark 0.4 mullions about every 6 studs;
   - header and base rails.
6. **Ceilings:** the mock's 4-stud grid strips and CeilingPanel troffers.
7. **Lighting:** one warm colour everywhere. Owner: "like Lethal", same style, different amounts per room.
   - Colours: panels (255,240,220), fills (255,232,205).
   - Rooms: panels brightness 0.22, range 14, with about 2/3 lit. Fills brightness 1.7, range 11.5. Conference fills 1.5.
   - Halls: a panel every 8 studs, all lit, brightness 0.2. A fill (brightness 1.3, range 12) every 16 studs on
     alternating sides, each under a wall sconce.
   - Server: panels 0.12 (2/3 lit); fill 0.6, range 10; rack LEDs blue, brightness 0.4, range 6.
   - Storage: panel 0.15; fill 0.8, range 10.
   - Accents: monitors 0.7 r6, reception glow 1.6 r11 (255,200,140), floor lamps 1.6 r11 (255,168,90).
   - Harlow's light tells still flicker these lights. Every light the tells used before is still tagged.
8. **Hallway dressing:** wainscot, troffers, sconces, art frames, plants, the odd bench. Halls must not read as bare
   boxes.
9. **Props fixed:** the whiteboard stands on the floor on its legs (never wall-mounted at a height).

## The size decision (owner, 2026-10-23)

**Keep the building about today's size: fewer, bigger rooms.** Walks, quota and the 8:30 shift stay as they are.

- Total generated floor area (rooms and hallways, bay excluded) stays within ±30 % of `TARGET_FLOOR_AREA` (24,300,
  stage 1's measured mean). Re-measure after the change, not before.
- The room count drops from 14–20 to whatever fits that area, expected about 7–11 (my guess).
- The farthest room stays within 40 s of walking (640 studs) from the bay.
- At least 8 hiding places per run. One pods room alone supplies them.
- The contract guarantee (`CONTRACT_SHARE_MAX`, top-up piles) must still hold on every seed. With fewer rooms, the
  bigger kits carry more pile and item markers each, so the 4–6 dirty rooms × 3–5 piles roll still works.
- **Fallback (owner):** if this doesn't feel right in play, the owner may switch to the Lethal Company approach: a
  bigger building, then re-tune quota and shift time. Don't build for that now.

## Non-goals

- The outside (stage 3) and per-run toggles and anomalies (stage 4).
- New room types, new door rules, new Mr. Harlow behaviour.
- Desk dividers. The mock's green dividers came from the old desk mesh. The current desk keeps the hide space.
  Dividers come back only if the owner asks, as a separate low prop clear of the knee-hole.
- New uploads. Everything the spike uses is already uploaded (the mock-room set and stage 2).

## Anti-goals

- **It still looks like stage 2:** narrow halls, slivers at corners, cool or dim light, bare halls.
- **A generated room looks worse than the spike's version of it.** The spike is the bar, room by room.
- **Mr. Harlow regresses:** any traversal failure on seeds 1–20 with all doors closed.
- **The economy drifts:** longer walks or thinner sites than today without the owner agreeing.
- **Furniture clipping** or floating props.
- **Phone performance falls off a cliff** from the extra lights or parts.

## Constraints

Everything in the parent spec, plus:

- **Art stays in the place.** The spike reuses parts of `Workspace.ClaudeMockRoom`: CeilingPanel lit and unlit, Rug,
  ReceptionPanel/Glow, the window bay, the monitor. The generator must not depend on the mock room or the spike, so
  every piece it needs becomes a template in the odd-hours-b1 kit (`ReplicatedStorage.Assets.CleanupCrew.ArtKits`),
  added in Studio and recorded in `KIT_MAP.md` and `AssembleKit.CommandBar.luau`.
- **MaterialVariants** (OH_Plaster, OH_Oak, OH_Ceiling, OH_Carpet, OH_Lino, OH_Vinyl) live in the place. Code refers
  to them by name and must still build sensibly when one is missing (specs, an unsaved place): plain material and
  colour.
- **Keep what works:**
  - doors: hinge at local +X, the occluder rules, Mr. Harlow's door beat;
  - depth by walking distance;
  - `ART_SIZES` and `markerSize`;
  - the default-kit fallback;
  - `surfaceTopFor`;
  - the hide-space rule (`HUG_FREE_MIN`).
- Studio rules from the handoff: specs run in Play only, the Shift playtest lock, no wally/rokit/check.sh while the
  owner is connected, no driving the owner's screen.
- **Remove the spike** (`Workspace.ClaudeSpike` and `ClaudeSpikeSpawn`) once the generator matches it. The owner has
  to save the place first.

## Settled after review (my calls; the owner can overrule)

1. **What "floor area" means.** It is what `TARGET_FLOOR_AREA` already measures: every room **including the
   hallways**, without the bay. This is literally "the building stays about today's size". Wider halls take a bigger
   share, so fewer rooms fit, which is the owner's pick. **If the targets conflict, the walking limit
   (640 studs), the hide minimum (8) and the contract guarantee win.** The area band is a proxy for "today's size" and
   gives way first; report any seed outside it.
2. **No large pods room is guaranteed.** The existing rule holds: a layout short of 8 hiding places is re-rolled.
   Desks and closets both count.
3. **Lights budget.**
   - Panel SurfaceLights and accent lights cast no shadows; only fills may.
   - The plan records the total light count per seed (seeds 1–20) next to the spike's light count per area. A
     generated office may not be denser than the spike.
   - The owner's play-check includes one session on a phone. If that shows a cliff, cap the hall panels first (every
     other panel lit).
   - Harlow's tells keep working as they do today. The new lights carry the same tag the old ceiling lights did.
4. **The loading bay gets the new build** (walls, trim, ceiling grid, warm light, 13-stud ceiling) at its current size.
   It's the first room players see, and it must not stay in the rejected style. Stage 3 replaces the bay with the dock
   outside.
5. **Studio work is done by the agent through the Studio MCP,** as in stages 1 and 2. New templates go in through a
   command-bar script, are recorded in `KIT_MAP.md` and `AssembleKit.CommandBar.luau`, and the owner saves the place.
   Code falls back to the default kit and plain Parts when a template is missing, so specs stay green before the
   templates exist.
6. **Hall dressing clearance.**
   - Collidable dressing (benches, plants) stands within 1.5 studs of a wall. That leaves at least 7 studs clear
     in a 10-wide hall.
   - It keeps 3 studs from any door casing or junction mouth.
   - It stands no closer than 12 studs to the next dressing prop on the same wall.
   - Wall-mounted dressing (art, sconces) is visual only.
7. **Glass walls.** Every kit keeps the glass spans it already has, and conference faces the hall in glass as in the
   spike. All glass gets the framed style (mullions, rails). No new glass on other room types.

## Left to the builder

- How the lattice spacing, `ROOM_MARGIN`, `KIT_ROOMS` and the kit weights are re-derived so the bigger kits fit and
  the area target holds.
- Kit marker layouts for the new sizes, within the hide, aisle (≥ 4 studs for Mr. Harlow) and door-approach rules.
- Whether the wall/trim/ceiling/light build lives in `OfficeBuildSystem` or a new sibling system (per
  `module-placement`).
- How hall dressing is placed: markers on corridor pieces or a rule along corridor walls. Either way it must keep
  doors, junctions and sightlines clear.
- How "2/3 of room panels lit" is chosen. It must be seeded, so a seed always builds the same office.

## Done means

- Specs green, and the traversal harness passes seeds 1–20 (all doors closed).
- Floor area and walking measured over seeds 1–20 and reported against the targets above.
- **The owner's play-check** says generated offices feel like the spike. Only that counts as done.
