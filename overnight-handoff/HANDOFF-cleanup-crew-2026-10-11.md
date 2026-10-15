# Handoff: Cleanup Crew (2026-10-11)

This is for the agent who picks up Cleanup Crew next. Read all of it before you change anything.

## Where the work is

- **Repo:** `E:/Projects/peekabu-game-systems`. Start by reading the repo's `AGENTS.md`; it holds the non-negotiable rules.
- **Worktree:** `E:/Projects/peekabu-game-systems/.claude/worktrees/mvp-demo-pack-052599`. Do all the work here.
- **Branch:** `game/cleanup-crew`, at `59de2a0`. It is fully pushed and in sync with origin.
- **Draft PR:** https://github.com/Peek-Abu/peekabu-game-systems/pull/3, titled "review only — do not merge".
- **Game design spec:** `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md`.
- **Milestone plans:** `docs/superpowers/plans/2026-10-10-m*-cleanup-crew-*.md`, `2026-10-11-m3-cleanup-crew-ui.md` and `2026-10-11-m3b-cleanup-crew-world-ui.md`.
- **Base-system specs** in `docs/superpowers/specs/`, especially:
  - carry: `2026-10-09-carry-design.md`
  - input: `2026-10-09-input-design.md`
  - interaction: `2026-10-09-interaction-design.md`
  - sound: `2026-10-09-sound-design.md`
  - UI: `2026-07-22-ui-framework-design.md`
  - inventory: `2026-07-15-inventory-item-model-design.md`

## Rules the user has set (in addition to AGENTS.md)

- **Branches and PRs**
  - `game/*` branches are never PR'd or merged into `main` or `base/*`. A fix to the base code gets its own `base/*` PR.
  - Push only when the user says so. Push with `env -u GITHUB_TOKEN -u GH_TOKEN git push origin game/cleanup-crew`.
- **Commits**
  - Plain commit messages. No `Co-Authored-By` or `Claude-Session` trailers.
  - Never stage `assets/` or `overnight-handoff/`. Both stay untracked on purpose.
- **Tooling while Rojo is live:** never run `wally install`, `rokit install` or the full `bash scripts/check.sh`. The package-types step is not idempotent and breaks package links. Run these instead:
  - `stylua --check src`
  - `selene src`
  - `rojo sourcemap default.project.json --output sourcemap.json && luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau --ignore="**/*.spec.luau" src tasks`
- **Tests:** TestEZ runs only in Studio.
  - Studio MCP instance "Place1" (Rojo-connected to this worktree).
  - Set the Workspace attribute `RunTests = true`, press Play, read the console, stop, then clear the attribute.
  - Last run: **2118 passed, 0 failed.**
  - If Studio is already in Play mode, that's probably the user playtesting. Ask before you stop it.
- **Assets and uploads**
  - **Never upload anything to the VentureMMO group (9738205).**
  - Ask before every upload, and name the assets and how many.
  - The owner is the **Icey Labs** group (id **189923277**).
  - No paid services.
- **Python:** `python3` is a broken Windows Store stub. Use `C:/Users/Bruk Abu/AppData/Local/Programs/Python/Python313/python.exe`.
- **UI style:** every Cleanup Crew UI is diegetic paperwork (paper, manila, cork, wood, stamps, sticky notes), with no generic dark bordered boxes and no emoji glyphs. Any new design is mocked up in Figma (file `PYtXsNlpV1MW2nOVx0wXl4`) and the user approves it before it is built.
- **Questions to the user:** ask concrete yes/no questions about things they can see. They don't read Figma node descriptions; send them images.

## Uploading assets to Icey Labs

- **Script:** `C:/Users/Bruk Abu/.claude/skills/publishing-roblox-assets/publish.py`. Run it with these flags:

  ```
  --key-env ICEY_LABS_OPEN_CLOUD_KEY --group 189923277
  ```

- **The key is a user key**, so it can publish to the user's account and to every group they manage. The script refuses to run with this key unless `--group` is given.
  - Never print the key or write it anywhere.
  - Without `--key-env`, the script uses the VentureMMO key and group. Never do that for this game.
- **After every upload, check the owner:** `https://economy.roblox.com/v2/assets/<id>/details` must show `Creator.CreatorTargetId == 189923277`.
- **Images:** Open Cloud creates a Decal (type 13), but UI needs the Image under it (type 1). In Studio Edit mode, resolve it with `InsertService:LoadAsset(decalId)` and read the Decal's `Texture`.
- **Audio:** comes back as type 3 and is usable as-is. New audio sits in "Reviewing" for a short while. To check approval, call `publish.req("GET", API + "/assets/<id>?readMask=moderationResult")` with `publish.KEY_ENV` set to the Icey Labs key variable.

## Done this session (all pushed)

1. **World UI and paper texture pass (M3b).**
   - In-world billboards (truck tags, contract board, result board, cargo price tags, load floater, Harlow's "!" disc and memo) and the drive/arrival cards are in the paperwork style.
   - The 6 tiled textures (cream, manila, manila deep, sticky, cork, wood) are uploaded to Icey Labs and wired into `src/ReplicatedStorage/Client/Features/UI/Data/UIAssets.luau` (`UIAssets.paper`).
2. **Sound pass.** All SFX picked by the user over 3 rounds are uploaded to Icey Labs, approved by Roblox moderation, and wired into each feature's `Data/<Feature>Assets.luau`:
   - Shift: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftAssets.luau`
   - Vacuum: `src/ReplicatedStorage/Shared/Features/Vacuum/Data/VacuumAssets.luau`
   - Cargo: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoAssets.luau`
   - Occupant (Harlow): `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantAssets.luau`
   - Office: `src/ReplicatedStorage/Client/Features/Office/Data/OfficeAssets.luau`
   - Library sounds (ProSoundEffects) play in place and were not uploaded: cargoPocket, cargoShatter, cargoRummage, harlowGrab.
   - **New `vacuumStop` cue:** a motor wind-down. `VacuumFeedbackSystem` plays it at the whine's current pitch when suction stops.
   - **Vacuum loop re-cut:** the user rejected the first cut, which ended in a wind-down. The current 2 s loop is cut from the steady part of the raw render.
   - **Harlow has no voice anymore.** Generated voices sounded like AI and cheap horror. He's now heard only through office habits, using the existing slot names:
     - `harlowMutter`: a pen tapping on a clipboard, looped on him.
     - `harlowCurious`: one deliberate pen click.
     - `harlowSigh`: his clipboard clip snapping shut.
     - `harlowGibberish1`: him scribbling. Slots 2-4 stay PENDING; `OccupantFeedbackUtils.clipFor` reuses whatever clips are uploaded.
   - Generation workspace: `assets/sfx/cleanup-crew/` (`cues.json`, `round2/` and `round3/`, each with its own `cues.json` and `results.json`). Skill: `sourcing-roblox-sfx`, run with the ComfyUI Stable Audio 3 install at `F:/AI/ComfyUI_windows_portable`.
3. **The desktop HUD now scales to the window.**
   - Before, it was laid out in fixed px for 1920x1080 and overlapped in short windows; the carry panel landed on the interaction prompt.
   - New modules in `src/ReplicatedStorage/Client/UI/React/Screens/Paper/`:
     - `PaperHudScaleViewModel` (specced): scale = min(w/1920, h/1080), clamped to 0.55..1. Phone stays at 1.
     - `usePaperHudScale`: gives the scale and the "virtual" viewport.
     - `PaperHudFrame`: applies a UIScale and the PaperScaleContext.
   - Wrapped widgets: ShiftHud, ShiftPromptChip, PaperToastStack, ShiftReviewTab, DepotPad, CatchRehiredCard, CatchOverlay.
   - **Viewport maths:** all viewport-based layout maths (`ShiftHudViewModel.centreShift` / `carryLeft`) must use the virtual viewport.
   - **Not checked yet:** the user hasn't seen the scaled HUD live. Read size at 0.55 is the open risk; `UIPaperConstants.HUD_SCALE_MIN` is the dial.
4. **Branding.** The Roblox group is **Icey Labs** (created by the user). The emblem and cover files are in `branding/icey-labs/final/`, which is untracked.

## On hold

- **Carry panel redesign.** `ShiftCarryPanel` is still the dark HANDS / POCKETS / CANISTER tray.
  - A paper "clipboard" mockup exists in Figma (frame `72:2621`, page Screens), with images in `overnight-handoff/ui-previews/carry/`.
  - **The user shelved it** because the next prompt may move the vacuum into the **Roblox inventory / hotbar (press 1, etc.)**. Redesign the panel only after that, and against the new model.

## Background for the expected next task (vacuum in the hotbar)

- **Vacuum today:**
  - Hold LMB to vacuum. The input action is `VacuumConstants.ACTION = "vacuum"`, registered through the Input feature: `src/ReplicatedStorage/Client/Features/Input/`, with `InputActionRegistry` and `InputBindingRules`.
  - Server: `src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau` (channels on piles through the Interaction system, with `VacuumChannelTracker`) and the canister maths in `VacuumCanisterUtils`.
  - Client: `VacuumServiceClient`, `VacuumAimUtils`, and `VacuumFeedbackSystem` (suction particles, whine/pop/stop sounds, canister tick/chime).
- **Carrying:** the Carry feature handles hands and pockets. Files: `src/ServerScriptService/Features/Carry/`, `src/ReplicatedStorage/Shared/Features/Carry/` and `CarryServiceClient`. Keys: G drop, F throw, Q pocket, E load/search.
- **Key hints:** the HUD reads them live from the Input bindings (`ShiftHudViewModel.keyHints`, `pocketKey`), so rebinding updates the hints automatically.
- **Mobile:** `ShiftMobileButtons` is the touch-only buttons layer.
- **Server authority:** the server is authoritative for everything. Clients never write state, and the server validates every request.
- **Roblox Backpack:** nothing in `src` touches the Backpack or `SetCoreGuiEnabled` today. A hotbar Tool approach would be new ground.
- **Placement rules:** follow `docs/project-structure.md` and the `module-placement` skill. A new module's feature, realm, subfolder and name go in the plan before any code is written.

## Other open items

- **Developer playtest checklist:**
  - a full shift → depot return to see the live result card;
  - a 3-player local server;
  - phone emulation;
  - a real Harlow catch;
  - the scaled HUD in a short window.
- **Music:** the chase theme (`harlowChase`, PENDING).
- **Optional idea for the user:** Harlow's "spotted" and "catch" stings are still orchestral horror stabs, which may clash with his new office-sound identity.
- **Untracked by design:** `assets/` and `overnight-handoff/`.
