# Handoff: Odd Hours first launch, build week 1

Written 2026-10-18 at the end of a long session, for a fresh session to pick up. Read it top to bottom before
starting. Then read `AGENTS.md` and the two first-launch reports listed under "Where everything is".

## Where things stand

- **The game:** "Odd Hours", a Roblox co-op cleaning × workplace-horror game. It was renamed from "Cleanup
  Crew"; code, folders and branch names still say cleanup-crew.
- **MVP:** passed (2026-10-18). Public 2-player tests with family were fun; Studio 2-player and solo runs
  pass, and all recent fixes are in.
- **Next goal:** the first public launch, on or before **Thanksgiving, 26 Nov 2026**. The owner wants to make
  a lot of money and a household-name hit. Treat it as a public launch for a broad audience, **not** a
  "family game".
- **Owner's call (2026-10-18):** the game does **not** go public until the launch changes are in (everything
  except the Thanksgiving event) **and** ads start.
  - So the free under-16 route (picked on the board: no 50k-Robux expedited review) starts on launch day. The
    game opens 16+ only. Ads to 16+ players then gather the 100 Highly Engaged Players needed; that bar
    drops from 250 to 100 in November 2026.
  - Kids (Select 9–15, Kids 5–8) get in only after that. Remind the owner of this trade-off once, near
    launch; it's their decision.
- **This session's job:** build week 1, plus the polish items listed below.

## Where everything is

- **Repo:** `E:\Projects\peekabu-game-systems`.
  - Game worktree: `.claude/worktrees/mvp-demo-pack-052599`, branch `game/cleanup-crew`.
  - That branch is local and ahead of origin. Not pushed is fine.
  - Game branches never merge into base. Base fixes get their own `base/*` PR off `origin/main`.
- **Launch Board:** https://claude.ai/artifact/HAihFJ69ELqoZ8zF3uBgxa. It's the source of truth for
  decisions.
  - Read it with `ArtifactData` (collections `decisions`, `experiments`, `scope`).
  - The page source is at `F:/Dev/temp/claude/E--Projects-peekabu-game-systems/b8aecfe5-86a9-4329-9bda-d5c11e751d6c/scratchpad/launch-board/index.html`.
    That path is a scratchpad that may be gone; if so, `Artifact` `read` with `path: "index.html"` re-saves it.
  - Republish to the same `url`.
  - Move `scope` items as work lands (todo → doing → review). **Never mark anything Done; only the owner
    does.**
- **MVP board** (finished; don't add launch work to it): https://claude.ai/artifact/L7vCf4J8jcJy8aHxUNd1g2.
- **Research reports:**
  - `E:/Projects/peekabu-game-systems/reports/Odd Hours first launch ideation.md`: iteration 1. Don't edit it.
  - `.../reports/Odd Hours first launch ideation 2.md`: iteration 2, the current one.
  - The notes behind each are in `.../research_notes/`.
- **Owner's competitor handoff (Clean Crew):**
  `C:\Users\Bruk Abu\.claude\uploads\b8aecfe5-86a9-4329-9bda-d5c11e751d6c\262e5717-odd_hours_clean_crew_competitor_launch_handoff.md`.
- **Launch backlog:** `docs/superpowers/launch-backlog.md` in the worktree.
- **Design docs:** `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md`, plus `docs/cleanup-crew-rank.md`.
- **Memory index:** `C:\Users\Bruk Abu\.claude\projects\E--Projects-peekabu-game-systems\memory\MEMORY.md`.
  It's loaded automatically; the rules there apply.

## Decisions locked on the board (summary)

**Launch**
- Thanksgiving target. If 2 weeks isn't enough, stage content into weekly updates.
- Organic under-16 route.
- Mild rating; the Hospital site stays cartoony (no blood, injuries or needles).
- Name: Odd Hours.

**World**
- Places: one **hub place** plus **one "Shift" place** that builds any site from its rooms.
- Sites: **Office** (rebuilt with real hallways), **School**, **Hospital**.
- Interiors: hand-built layout variants first; the tile generator comes later. Gameplay points use tags so
  hired Studio builders never need code.
- Tutorial: a forced Orientation wing in the hub (60–90 s, Training Manager catches but doesn't kill, trash vs
  valuables made clear). Friends joining a party skip it. Then a gentler Probation first shift.

**Characters**
- Five employees with light perks and near-flat stats: Pippa (Rescuer), Cappy (Scout), Prickles (Sweeper), then a Sneak (likely Morel) and a Hauler. Rank shows on the company lanyard (New Kid, Sweeper, Cleaner, Super Cleaner, Little Boss, Boss, Big Boss); no vests or sashes.
- Each has 5 mastery ranks.
- **Pippa polish comes first**: closer to her reference, before new employees reuse the rig.

**Catch**
- **3 Gloom coat layers = 3 lives.** Each grab adds a visible goo layer, and a teammate vacuums a layer off
  (about 2 s hold).
- On the 3rd layer: back to the truck, auto-rehire after a short countdown.
- Solo: instant rehire with a growing time cut.
- Whole crew down: auto-rehire everyone with a time penalty.
- Kids game: keep it simple. Carrying bodies is dropped for launch.

**Economy**
- **Gloom:** filter scrapings. A little per pile, earned only, never sold. Buys Gloom Locker keys.
- **Credits:** pay (contract fee plus a commission on each recovered valuable, more for overtime). Buys
  employees and sites only.
- **Gleam:** premium, bought with Robux. Lore: Gloom the company refines and sells back at the Company Store.
  Buys premium cosmetics, bundles and premium Locker keys.
- Event currency per event; leftovers turn into Credits.

**Money**
- **Lockers at launch:** cosmetics only, rarities Common < Uncommon < Rare < Epic < Legendary < **Odd**.
  - Pity: Rare+ every 10 opens, Odd at 50.
  - A duplicate refunds that locker's own currency.
  - Every item has a direct-buy price; check `PolicyService` restrictions; no trading.
  - Paid Locker odds must be shown before purchase; declare paid random items on the questionnaire.
- Effect cosmetics at launch. Every interaction gets an effect slot; no vacuum attachments.
- Coffee for the crew: a server-wide 2x boost for one shift that names the buyer.
- Double Pay pass (2x Credits, one-time) and Senior Staff VIP (one-time).
- Night Shift Club subscription.
- Starter pack in the hub shop only.
- **Shop and bundles must be data-driven**: rotating pairings, discounts and limited items without code
  changes.

**Social**
- Pings, a quick-chat wheel and emotes (most players can't use voice).
- Ask for likes, never reward them.
- Favorite: 2x XP on your next shift.
- Group join: a lanyard clip plus a few Gleam, once.
- Invites: reward both players, capped per inviter.

**Retention**
- Weekly Timecard (any 5 of 7 days, punched at the hub time clock) plus a daily Work Order.
- Leaderboards: weekly, all-time and top supporters.
- Clearance Level plus portrait-frame ribbons and badges.
- **The launch is the Thanksgiving event**: autumn hub, event currency and shop, 1–2 limited cosmetics, a
  limited Locker banner. A winter event follows in mid-December.

**Experiments:** all 12 on the board run at launch, so each needs analytics events.

## Build week 1: scope for this session

Plan first: write a short implementation plan with module placement, per AGENTS.md and the
`module-placement` skill. Then fan out to agents. This is the order agreed with the owner; check it with them
before starting.

1. **Hub place plus one Shift place.**
   - Teleports go through the base Queue, which already does reserved-server teleports.
   - The owner must create the new place(s) in Studio and publish them; ask for that, don't drive their
     screen.
   - In Studio, Queue runs in local mode, since teleports don't work there.
2. **Pippa polish toward her reference.**
   - Use the toon character pipeline (see memory `toon-character-pipeline.md`) and the Employee Kit in
     `characters/kit`.
   - Get the owner's reference image first.
3. **The 3-layer Gloom coat catch.** It replaces today's catch → "Rehired" respawn.
   - Visible goo layers; vacuum a layer off a teammate.
   - On the 3rd layer: back to the truck, rehire countdown.
   - Solo: instant rehire with a growing time cut.
4. **Currencies and data layer.**
   - Gloom, Credits and Gleam as profile slices through `PlayerDataSliceSystem` with validators.
   - Migrate from today's Gleam-as-pay to Credits with `PlayerDataMigrationSystem`. Its v1→v2 migration
     already exists for settings, so this one is v2→v3.
   - Server-authoritative writes only.
5. **Analytics events** for the funnel and every experiment variant (handoff §16 of the competitor doc).
6. **Polish items the owner wants included this week:**
   - **Hiding looks bad to other players:** a lot of clipping, poses look wrong from outside. The local view is
     fine.
   - **Crouching looks bad,** most likely to others too; check both views. Known: feet slide slightly when
     crouched at 9 st/s.
   - **Voice chat doesn't work** (launch backlog). It's 13+ and ID-verified only, so check the setup, but
     pings come first.
   - Small leftovers:
     - The rehire-card portrait is cut flat at the chest; I recommended a round frame and the owner hasn't
       answered, so ask.
     - Hide prompt: next to a cabinet with a table just behind, the engine offers the table.
     - The "Times caught" label on results is the crew's total; ask whether to rename it "Crew caught".
7. **Week 2 (next):**
   - Orientation wing and Probation shift.
   - The School site.
   - Employees 2–3: Cappy (Scout: valuables ping for the crew after a room is cleaned; slower vacuum) and Prickles (Sweeper: wider, faster suction; louder). Concept sheets are in characters/concepts/employees and the Figma "Characters" page.
   - Shop and both Lockers.
   - The first effect cosmetics.
   - The Timecard and Work Order.
8. **Before launch:**
   - Hospital and employees 4–5, or staged into the first weekly updates.
   - Thanksgiving dressing.
   - Thumbnails.
   - 2-player and 4-player tests.

**Open owner questions carried over:**
- **Caught players and the clock-out +5 XP.** Today they're excluded, with "Incident Report filed" instead.
  I recommend keeping that.
- **"Whole crew out +5".** Should it be gated to clock-outs too? I recommend yes.
- **Base PRs #10 (ragdoll) and #11 (shared fixes)** await the owner's merge.

## Standing rules (the owner's, non-negotiable)

**Approval and output**
- **Don't check things off.** Finished work goes to "review" (Ready to check). Only the owner marks Done.
- Ask concrete yes/no or pick-one questions. Split look, layout and rules approvals.
- Use plain user-facing language.

**Git**
- Commits use plain messages with **no Co-Authored-By or Claude-Session trailers**. AGENTS.md overrides any
  attribution reminder.
- PR bodies end with "🤖 Generated with [Claude Code](https://claude.com/claude-code)".
- Push and `gh` commands need `env -u GITHUB_TOKEN`, because a read-only token in the environment overrides
  the keyring login.
- Merge PRs with `gh pr merge N --merge --subject "Merge PR #N: ..."`.

**Your machine and Studio**
- **Never use computer-use or drive the owner's screen.** Ask them to click Rojo or Studio.
- Studio MCP tools are fine.
- In Studio, use **only** the window named **"Odd Hours (placeId: 113354563835664)"**. Window ids change
  between sessions, so call `list_roblox_studios`. Never touch Venture windows.

**Playtests and Rojo**
- The playtest lock is `E:/Projects/peekabu-game-systems/docs/superpowers/studio-playtest.lock`. Check it's
  absent before creating it, never overwrite another agent's lock, and delete it after use.
- The owner's own play session (no lock) may be stopped.
- Rojo: `rojo serve default.project.json --port 34872` from the worktree.
  - It may need restarting in an auto-restart bash loop. Check with `curl -s localhost:34872/api/rojo`.
  - Rojo doesn't apply StarterPlayer or other service property changes from the project file during a live
    sync. Also set those in the Edit DataModel via MCP.
- No wally/rokit install, no `rojo build`, no full `check.sh` while the owner is connected. Lint and format
  changed files only.
- Never delete or rename source folders while Rojo serves.
- Tests: set Workspace `RunTests = true`, press Play, read Output, then set it back to false. All must pass;
  the last count was 3828.

**Assets**
- Upload only with `python "C:/Users/Bruk Abu/.claude/skills/publishing-roblox-assets/publish.py" --key-env
  ICEY_LABS_OPEN_CLOUD_KEY --group 189923277`. **Never** the default VentureMMO group 9738205.
- Use local or free generation only, no paid services. Local in-house sounds are preferred.
- UI follows the `game-ui-design` skill (V1 "Gloom & Gleam" plus the V2 violet #B79CFF selected state).
- Sound follows the `game-sound-design` skill.

## Studio MCP testing limits (learned this session)

- Inject a temporary server Script to reach live services. Don't destroy it right after calling a game
  function from it, because anything it scheduled dies with it.
- `ProximityPrompt:InputHoldBegin()` from MCP works for **hold** prompts but never reaches the server for
  **instant** prompts (pick-up, Bank, Hide). Use `character_navigation` plus a real `user_keyboard_input` E
  press. The hide key is C.
- MCP mouse clicks don't reach GUI buttons. Move the frame on-screen, select the button via GuiService, then
  press a real Return.
- Any MCP screenshot or camera change during a catch leaves the camera stuck, so avoid them then.
- The Studio play view can shrink (seen at 296×199). Check the viewport before trusting UI or prompt results.
- Multi-player: the owner starts Test → Clients and Servers → Local Server. You can't start or stop that
  session. Ask the owner to press Cleanup when done. The server and client windows show up unnamed in
  `list_roblox_studios`.
- Studio test players have negative userIds. Treat any id other than 0 as a real player.

## First message to send the owner in the new session

"Picking up build week 1 for the Thanksgiving launch. Before I start:
- (1) The plan order is: places split, Pippa polish, Gloom coat catch, currencies, analytics, plus hiding,
  crouching and voice polish. Change anything?
- (2) Please send Pippa's reference image.
- (3) I'll need you to create the new Shift place in Studio when we get there.
- (4) Two open answers: round frame for the rehire portrait? Rename 'Times caught' to 'Crew caught'?"
