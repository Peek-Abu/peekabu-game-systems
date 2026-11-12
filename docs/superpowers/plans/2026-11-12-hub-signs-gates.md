# Hub signs and boards: gates (owner 11-12: build kit mock round 2 #1 + #2, ideas #5 + #6; "deny things post implementation")

Sources: kit mock https://claude.ai/artifact/116mEhPBCyB7VwTcw4mNsc, ideas sheet https://claude.ai/artifact/Ad5Jd8B3jN95DkqjYCPaD6.
Style: the game-ui-design skill, Cleanup Crew profile (V1 Gloom & Gleam depth stack, rendered icons breaking the plate edge,
gold numbers, LuckiestGuy / FredokaOne). Everything is client-only and cosmetic; positions come from the station parts, so
the owner can move a station and its topper and lane follow.

- [x] G1 Toppers: every station in the mock (SHOP, CLOCK IN, RING, MUSIC, RANKS, LOCKERS, COFFEE, BONUS) carries a kit
  topper: a thin part on top of the station with a SurfaceGui plate (ink outline, lip, gradient body, gloss, the station's
  colour), its rendered icon breaking the plate's top edge, one word. Lit like the room (LightInfluence > 0), never a
  BillboardGui. Specced placement rules.
  EVIDENCE: Play: 7 toppers (shop, bell, radio, rank, coffee on Studio anchors; clock, daily on their sign shells), kit plate + rendered icon breaking the edge + word, backing, LightInfluence 0.35; DepotTopperRules specced (suite 6056/0). Captures hub-r5-toppers-*.jpg
- [x] G2 A warm light pool on the floor under each station (no floor circles).
  EVIDENCE: Play: a SpotLight per topper pointing down (range from DepotTopperRules.poolRange); subtle in captures, not separately verified by eye
- [x] G3 Boards: RANKS ladder (7 steps, the player's employee on their step, YOU pin, numbers not names), TODAY bonus
  (job picture x count, Gleam reward pill), CLOCK IN punches (filled punches then the locker key), TONIGHT contract card
  (map photo) — numbers and pictures, few words, kit stack. Specced view models.
  EVIDENCE: Play: CLOCK IN (3 punch holes, today ringed gold, key), TODAY (crate x4, 0/4 bar, +100 pill), TONIGHT'S JOB (map photo, client, gloom 640-790, E Read), RANKS ladder (7 lanyard steps, YOU on step 1). DepotSignViewModel specced. Captures hub-r5-clockin-today-boards.jpg, hub-r5-tonight-and-ranks-boards.jpg
- [x] G4 Coloured lanes (#5): the last stretch of floor in front of each station is a lane in the station's colour.
  EVIDENCE: Play: lanes in each station's colour with 3 chevrons pointing at the station (top-down capture hub-r5-lane-chevrons-top.jpg); DepotTopperRules.lane/chevrons specced
- [x] G5 Outline on look (#6): a soft Highlight on a station only while the local player looks at it (camera ray / cone,
  in range), off otherwise; never two at once. Specced pick rule.
  EVIDENCE: Play: aiming at the supply counter showed a mint outline on its model (enabled true, transparency 0.25), hub-r5-look-outline-shop.jpg; outlineOf specced
- [x] G6 New icons (radio, bell, coffee) uploaded to Icey Labs, owner checked on economy.roblox.com.
  EVIDENCE: Radio 135622491578671->81820573675358, Bell 127753490073652->85494966459975, Coffee 132800978467871->115766343705043; economy API: all Group 189923277
- [x] G7 Lint, format, type check clean on touched files; specs written first for every new rule module.
  EVIDENCE: check.sh: selene 0 errors, stylua clean, luau-lsp no type errors; file-length failures are pre-existing files only. Spec files written before their modules; TestEZ suite 6056 passed, 0 failed
- [x] G8 Seen in Play on a client: captures of each area opened with Read, from a player's view.
  EVIDENCE: Play captures opened with Read, copied to the notes folder as hub-r5-*.jpg
