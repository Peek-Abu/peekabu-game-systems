# Cleanup Crew UI: V1 "Gloom & Gleam" implementation plan (2026-10-17)

The user picked kit V1 "Gloom & Gleam" (`characters/ui/kits/v2/V1-gloom-gleam/`) with V2's lilac selected state
(`#B79CFF`), and asked for two goo fixes: goo must never look cut off at a corner, and must never hang or float below a
component. Style rules: the `game-ui-design` skill's Cleanup Crew profile and `depth-stack.md`.

## How the goo is fixed

Goo is drawn **inside** the component it belongs to, never at a negative offset and never across a clip edge:

- **cap** goo is poured along the component's top edge: a flat top under the component's own ink rim, a band edge to
  edge and drips flowing down over the face; its ends taper into the edge as rounded blobs.
- **pool** goo is puddled on the component's floor: a flat bottom, mounds rising up the face.
- Both carry the component's 4 px ink outline on their free contour, the lilac gloss streak on the lit side and
  bubble dots, and are composed as `end + N whole tiles + end` (`ToonGooViewModel`), inset from the rounded corners,
  so a drip is never cut by the component's side and nothing crosses a corner.
- Goo sits on at most one edge, and only on Gloom things: modal header lips, locked building cards, the danger
  plate, the Gloom meter. Never on rewards, never on the hub menu tiles.

## New modules

All in the UI tree (`src/ReplicatedStorage/Client/UI/React/Screens/Toon/`, client), named by the UI-tree convention
(components for what they show, `use<Thing>` hooks beside the family that uses them, view models end in `ViewModel`,
constants are `UI<Thing>Constants`).

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| UI tree | client | React/Screens/Toon | UIToonConstants | V1 palette, fonts, depth-stack geometry, motion timings (static) |
| UI tree | client | React/Screens/Toon | ToonStyleViewModel | Pure: per-variant colours and the hover/press/disabled/selected pose targets (spec) |
| UI tree | client | React/Screens/Toon | ToonGooViewModel | Pure: lays goo pieces (ends + whole tiles) along a component edge (spec) |
| UI tree | client | React/Screens/Toon | ToonMotionViewModel | Pure: pop-in curve, wipe sweep, sparkle twinkle, number formatting (spec) |
| UI tree | client | React/Screens/Toon | useToonPose | Hook: TweenService eases the Pose binding between states (exempt; poses and blend specced) |
| UI tree | client | React/Screens/Toon | useToonPlay | Hook: TweenService plays a 0 → 1 binding once or looping (exempt; curves specced) |
| UI tree | client | React/Screens/Toon | ToonSurface | The 7-layer depth stack as Frames (exempt, story) |
| UI tree | client | React/Screens/Toon | ToonButton | Stateful button on the stack, every state tweened (exempt, story) |
| UI tree | client | React/Screens/Toon | ToonPanel | Panel with optional header lip, goo, pop-in and wipe (exempt, story) |
| UI tree | client | React/Screens/Toon | ToonSlot | Hotbar slot with render, key number and selected ring (exempt, story) |
| UI tree | client | React/Screens/Toon | ToonPill | Capsule tag / number pill with an overlapping render (exempt, story) |
| UI tree | client | React/Screens/Toon | ToonBar | Meter (Gloom, XP, stamina, load) with bubbles and meniscus (exempt, story) |
| UI tree | client | React/Screens/Toon | ToonText | Luckiest Guy text: ink stroke, gradient fill, hard drop (exempt, story) |
| UI tree | client | React/Screens/Toon | ToonIcon | Rendered icon with its ink drop copy (exempt, story) |
| UI tree | client | React/Screens/Toon | ToonGoo | Draws the goo pieces ToonGooViewModel lays out (exempt, story) |
| UI tree | client | React/Screens/Toon | ToonSparkle | Gleam sparkles twinkling on a stagger (exempt, story) |
| UI tree | client | React/Screens/Toon | ToonWipe | The dirty → clean squeegee pass on open (exempt, story) |

Asset ids go in the existing `Features/UI/Data/UIAssets` (`UIAssets.toon`), the only place `rbxassetid://` literals
may live. The ids and their Decal/Image pairs are recorded in `characters/ui/shipped-ui-assets.md`.

Screens are restyled in place (DepotHub, DepotPadPanel, ShiftHud's panels, ShiftReviewPanel, DepotBoardPanel,
DepotHubScreen, ShiftTransitPanel); their view models keep the data flow and gain pure, specced helpers where a screen
needs a new derived value. The paperwork components are removed once nothing uses them.
