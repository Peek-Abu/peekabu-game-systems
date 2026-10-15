# M3 design: Cleanup Crew UI (for approval)

**Figma file:** https://www.figma.com/design/PYtXsNlpV1MW2nOVx0wXl4 ("Cleanup Crew — UI (for approval)", the developer's drafts, team "Bruk Abu's team")

## Update 2026-10-11: screens 2–5 are built
Built with the figma-console MCP (Desktop Bridge plugin), which has no Starter-plan call limit. Every new frame was screenshotted and fixed: overlapping stamps and stickies, a 16 px desktop hint, and phone label clashes. The 1e and 1f leftovers were checked (1f's small stamp was moved). The sticky-note component's tape now has a CENTER constraint, so resized toasts keep the tape centred. The approval decisions below are still open.

### Review changes applied (2026-10-11, all 9 of the design review's pre-demo changes)
1. 2a/2b (rebuilt, ids 31:458 / 31:516): a "→ JOIN A SHIFT" panel (walk into a truck bed); the phone version had lost the join line.
2. 2a/2b: a red **⚠ HAZARD** row: "Occupant on site. Hears vacuums and dropped items. Empty hands run faster."
3. 1b and 1f quota-met toast: "Quota met! Clock out at the truck any time, or stay: salvage ×1.5 in 0:30."
4. Crew strip (icon + name + state text) on 1a/1b/1c, plus a two-line version on 1d/1e. 4b/4d show the cause ("Caught by Mr. Harlow · cargo dropped in the Copy Room") and the teammate's cargo. New 1f toast: "Alex was caught! Back in 0:08."
5. Phone action buttons re-arced around LOAD/VACUUM with ≥16 px gaps (DROP 512,282 · THROW 555,194 · POCKET 651,173).
6. Clock-out countdown moved out of the centre into a strip under the time card (1c, 1e).
7. All in-play desktop HUD text is now ≥20 px (key hints at 80% opacity; pocket labels in Oswald Medium).
8. Results rebuilt: QUOTA MET / MISSED is the headline stamp, the rating is a smaller second stamp, and your vote is marked. New **5c quota-missed** frame (31:611). 5a 31:557, 5b 31:665.
9. 4a: no text during the scare; "You're FIRED!" moves to the ragdoll throw (caption only). The Rehired cards add "Go back for them!"
Rating tiers (developer, 2026-10-11, three tiers): quota missed → NEEDS IMPROVEMENT · quota met → SATISFACTORY · quota met + salvage threshold → EXCEEDS EXPECTATIONS. The threshold (≥ 2 of 3 salvage loaded) is a proposal, noted on the Screens page beside 5c.
Restyle (2026-10-11, the developer said these looked "AI-esque"): the clock-out countdown is now a stapled, torn time-card slip (1c/1e); the join panel is a pinned dispatch slip with a green marker underline (2a/2b); spectating is a CCTV feed (REC · CAM 04, corner brackets, scanlines, timestamp, Q/E key chips) with a paper incident report (4b/4d). The ⚠ emoji was removed from the HAZARD rows. The crew strip is now a clipped "CREW ROSTER · TRUCK 2" card (tick boxes, caught names struck through with a marker X, status in coloured ink) on 1a–1e; before/after is in `crew-strip-compare/`. The developer approved this paperwork style as the direction.
Deferred until after playtesting (from the review): darken the in-shift paper, green or neutral success stamps, a separate threat-toast style, cut PRESSURE, make the canister/pockets/hints contextual, a first-time depot variant, stamp timing, icons.

### Earlier design questions (developer, 2026-10-11): keep every default
Harlow's catch grace (10 s) stays even though spectate uses ~8 s of it; pockets scatter at the catch point; a `caught` drop counts any death (M5 N5); a pocket round-trip reads as an `open` source (N4).

### Game-rule decisions (developer, 2026-10-11)
- Vote tie-break → **Another shift** (as in 5a).
- Spectating while caught (teammate view, Q/E to switch) → **yes**.
- Overall rating stamp → **varies by performance** (not always "NEEDS IMPROVEMENT"). 5a/5b still show the old fixed stamp; the tiers still need defining.
- Look and layout: an independent design critique was requested before approval (see the review output).

## Status (2026-10-10): partly done. The Figma MCP limit cut the work off.
After about 20 calls the Figma MCP returned *"You've reached the Figma MCP tool call limit on the Starter plan"*. Every Figma tool call fails from that point on, reads included.
- **Done in Figma:** the Reference board, the Style page with components, and the full Shift HUD set (3 desktop frames, 2 phone frames, and a states frame). Every one of these frames was screenshotted and fixed, except the last fixes listed below.
- **Not in Figma yet:** screens 2–5 (Depot contract board, Queue pad, Catch overlay, Performance review). Their build scripts are written and pass a syntax check, but they have **never been run**. They are in `scratchpad/m3-figma-scripts/` (see `00_README.txt`). Each script runs as one `use_figma` call (`_prelude.js` + the screen file) once the limit resets or the plan is upgraded. After that, screenshot each frame and fix what you find.
- **Last fixes not re-checked:** 1e (the phone clock-out countdown moved to the centre so it no longer overlaps the clearance panel) and the small stamp's position in 1f. I made both edits but could not screenshot them before the limit hit.
- The Starter plan also allows only **3 pages**, so the file has: Reference board · Style · Screens. Each screen is a labelled row on the Screens page instead of its own page.

## Pages and frames
- **Reference board:** 20 cards (thumbnail, title, URL, takeaway, tag for the screen it informs).
- **Style:** "Style guide" frame (14-colour palette with uses, type specimens with Roblox font names). "Components" frame: Toast / Sticky note, Stamp, Button (Primary / Secondary / Danger / Go), Mobile button (Large / Small × Default / Highlighted), Pocket slot (Empty / Filled), Punch clock, Manila tab, plus the mobile and legibility rules. There are also 14 colour styles (`CC/…`) and 6 text styles.
- **Screens:**
  - 1a Shift HUD desktop (normal) · 1b quota met (stamp + break toast) · 1c overtime + clock-out countdown
  - 1d phone (in the truck bed holding a monitor, LOAD highlighted) · 1e phone (overtime + clock-out, hands empty)
  - 1f states: 6 sticky-note toasts, QUOTA MET / OVERTIME / CLOCKED OUT stamps, phone sizes, motion notes
  - Pending scripts: 2a/2b Depot board · 3a/3b Queue pad · 4a scare beat, 4b spectate, 4c "Rehired." card, 4d/4e phone · 5a/5b Performance review

## References (Interface In Game; Game UI Database showed a Cloudflare bot check, which I did not get past)
| # | Reference | Take |
|---|---|---|
| 1 | https://interfaceingame.com/screenshots/hitman-2-mission-score/ | One emblem and a few big numbers on results. Our emblem is the rubber stamp |
| 2 | https://interfaceingame.com/screenshots/hitman-2-briefing/ | Numbered dossier tiles. The contract board uses numbered work-order sections |
| 3 | https://interfaceingame.com/screenshots/deep-rock-galactic-assignment-board/ | Co-op job board in the company's voice. Copy tone for Harlow & Finch |
| 4 | https://interfaceingame.com/screenshots/deep-rock-galactic-extraction/ | Big countdown that appears only during extraction. Same for clock-out |
| 5 | https://interfaceingame.com/screenshots/control-correspondence/ | A bureaucratic memo on paper over dark UI. The "corporate horror" register |
| 6 | https://interfaceingame.com/screenshots/alan-wake-ii-case-board/ | Pinned folders and notes. The depot board as a physical pinboard |
| 7 | https://interfaceingame.com/screenshots/resident-evil-2-inventory/ | A few honest slots on near-black. Hands + 2 pockets |
| 8 | https://interfaceingame.com/screenshots/resident-evil-2-officers-notebook/ | One paper document centred on black. How to show the Rehired card |
| 9 | https://interfaceingame.com/screenshots/dead-by-daylight-match-start-in/ | The lobby keeps the world visible, with a small READY + timer. The truck is the lobby |
| 10 | https://interfaceingame.com/screenshots/dead-by-daylight-repair/ | Near-empty horror HUD with a thin hold bar. Vacuum and search progress |
| 11 | https://interfaceingame.com/screenshots/overcooked-2-cooking/ | Co-op score and timer in chunky, friendly plates |
| 12 | https://interfaceingame.com/screenshots/overcooked-2-times-up/ | One bold centred banner. The QUOTA MET moment |
| 13 | https://interfaceingame.com/screenshots/overcooked-2-score/ | Results as a paper card: line items, total, stars |
| 14 | https://interfaceingame.com/screenshots/fall-guys-ultimate-knockout-eliminated/ | Failing shown as a big funny banner + spectate. Kid-safe catch tone |
| 15 | https://interfaceingame.com/screenshots/fall-guys-ultimate-knockout-looking-for-more-players/ | One huge count. "CREW 3/4" |
| 16 | https://interfaceingame.com/screenshots/hello-neighbor-pick-up-objects/ | Kid-friendly horror: item held in the hands, tiny slot strip |
| 17 | https://interfaceingame.com/screenshots/last-year-results/ | "Leaving in 17 s" auto-timer. The vote needs a visible timer |
| 18 | https://interfaceingame.com/screenshots/last-year-lobby/ | Crew line-up with names overhead + READY. Name tags on the truck bed |
| 19 | https://interfaceingame.com/screenshots/last-year-hold-search/ | "HOLD [E] SEARCH" with a thin bar. Desk and locker search |
| 20 | https://interfaceingame.com/screenshots/death-stranding-results-2/ | Itemised grades + one emblem. Joke awards as grades |

I uploaded the thumbnails by fetching them in the built-in browser and posting the bytes straight to Figma, so nothing was saved to disk. #1 is a video, so its card has no picture. They are for internal reference only.

## Decisions for the developer to approve or change
1. **Fonts:** Special Elite (typewriter body, `Enum.Font.SpecialElite`), Oswald Bold (numbers, headings, buttons, stamps, `Enum.Font.Oswald`), Roboto Mono Bold (timers only, so digits don't jitter, `Enum.Font.RobotoMono`), Permanent Marker (sticky notes only, `Enum.Font.PermanentMarker`). Bangers (`Enum.Font.Bangers`) is listed as an optional comic accent and is not used yet.
2. **Colour meaning:** paper = information you read; dark plates = live numbers; red = Harlow and danger; green = safe or done; blue = salvage, bonus and spectating.
3. **HUD layout:** clearance folder + finder's fee top-left, **below the Roblox top bar**; punch clock top-centre (5 punch holes for shift progress, 3 tier pips); toasts top-right; carry panel (hands, pockets, canister) bottom-left on desktop and **top-right on phone**, because the thumbstick owns the bottom-left.
4. **Phone buttons:** one large primary slot that switches **VACUUM ↔ LOAD** (you can't vacuum while holding something, so they never compete). Small DROP / THROW / POCKET buttons arc above it, all clear of the Roblox Jump button. POCKET lights up only when a tiny item is held.
5. **Units:** finder's fee is shown as a plain "+140" (no $). Clearance reads "212 / 350 cleared".
6. **Overtime:** red tint on the screen, the punch clock reads OVERTIME, a "SALVAGE ×1.5" stamp sits under the clock, and the fee plate says "×1.5 now".
7. **Clock-out:** a large centred "CLOCKING OUT 7" panel with "Unbanked cargo stays behind".
8. **Vote rule (in the pending 5a script):** majority wins, auto-pick at 0:20, **a tie goes to Another shift**. The spec doesn't say; this needs a call.
9. **Joke awards (pending 5a):** Employee of the Night, Most Rehired, Butterfingers, Quietest Feet. The overall rating stamp reads "NEEDS IMPROVEMENT".
10. **Catch:** no HUD during the 0.6 s scare beat. Harlow's face is a labelled placeholder ("Flux, pending"). The Rehired card is an HR "Notice of Re-employment" that lists what you dropped.
11. **Depot board copy (pending 2a):** a work-order form with an APPROVED stamp, a sticky note from the night guard, and the returning player's last-shift card clipped on.

## What I couldn't do
- Game UI Database: blocked by the Cloudflare bot check. I didn't try to get past it.
- Screens 2–5 in Figma: blocked by the Figma Starter-plan MCP limit. The scripts are ready but have never been run (above).
- No art was generated (as instructed). Every art spot is a labelled placeholder.
- Nothing in the repo was changed and nothing was uploaded to Roblox.
