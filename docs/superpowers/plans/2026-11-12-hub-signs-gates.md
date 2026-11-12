# Hub signs and boards: gates (owner 11-12: build kit mock round 2 #1 + #2, ideas #5 + #6; "deny things post implementation")

Sources: kit mock https://claude.ai/artifact/116mEhPBCyB7VwTcw4mNsc, ideas sheet https://claude.ai/artifact/Ad5Jd8B3jN95DkqjYCPaD6.
Style: the game-ui-design skill, Cleanup Crew profile (V1 Gloom & Gleam depth stack, rendered icons breaking the plate edge,
gold numbers, LuckiestGuy / FredokaOne). Everything is client-only and cosmetic; positions come from the station parts, so
the owner can move a station and its topper and lane follow.

- [ ] G1 Toppers: every station in the mock (SHOP, CLOCK IN, RING, MUSIC, RANKS, LOCKERS, COFFEE, BONUS) carries a kit
  topper: a thin part on top of the station with a SurfaceGui plate (ink outline, lip, gradient body, gloss, the station's
  colour), its rendered icon breaking the plate's top edge, one word. Lit like the room (LightInfluence > 0), never a
  BillboardGui. Specced placement rules.
  EVIDENCE: pending
- [ ] G2 A warm light pool on the floor under each station (no floor circles).
  EVIDENCE: pending
- [ ] G3 Boards: RANKS ladder (7 steps, the player's employee on their step, YOU pin, numbers not names), TODAY bonus
  (job picture x count, Gleam reward pill), CLOCK IN punches (filled punches then the locker key), TONIGHT contract card
  (map photo) — numbers and pictures, few words, kit stack. Specced view models.
  EVIDENCE: pending
- [ ] G4 Coloured lanes (#5): the last stretch of floor in front of each station is a lane in the station's colour.
  EVIDENCE: pending
- [ ] G5 Outline on look (#6): a soft Highlight on a station only while the local player looks at it (camera ray / cone,
  in range), off otherwise; never two at once. Specced pick rule.
  EVIDENCE: pending
- [ ] G6 New icons (radio, bell, coffee) uploaded to Icey Labs, owner checked on economy.roblox.com.
  EVIDENCE: pending
- [ ] G7 Lint, format, type check clean on touched files; specs written first for every new rule module.
  EVIDENCE: pending
- [ ] G8 Seen in Play on a client: captures of each area opened with Read, from a player's view.
  EVIDENCE: pending
