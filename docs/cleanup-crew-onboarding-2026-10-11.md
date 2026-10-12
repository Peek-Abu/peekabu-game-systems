# Cleanup Crew onboarding and polish review

Prepared 2026-10-11. The initial investigation below is preserved as context; the verified follow-up at the end supersedes its pre-fix status. The HUD proposal remains awaiting visual approval.

## Checkout and evidence

Game checkout: E:/Projects/peekabu-game-systems/.claude/worktrees/mvp-demo-pack-052599, game/cleanup-crew at 59de2a0. Base checkout is on claude/clever-dirac-20hjqo at a72b4b3. Existing game untracked files were assets/ and overnight-handoff/; leave them unstaged.

Read the handoff, repository architecture/placement/animation references, game spec, relevant source, and Claude skill/MCP inventory. Reviewed archived overnight-handoff/ui-previews/16-live-hud.jpg: it shows substantial HUD overlap but predates the latest scaling fix. No current Studio session was inspected. The handoff's earlier user decisions/test count are historical reports, not new authorization or current validation. Current direct user instructions take precedence.

The base uses native characters, service discovery/lifecycle, ProfileStore transactions, Charm state replication, and ByteNet events. Game-specific systems remain on the game branch; an inherited defect should get a separate base fix once reproduced. Preserve artist ownership and ReplicatedStorage's ignore-unknown-instances flag.

## Claude MCPs and skills

| Capability | Found | Use/status |
|---|---|---|
| Figma Console | Claude global figma-console, npx -y figma-console-mcp@latest | Southleft alternative. User prohibits official Figma MCP. Not callable in this Codex session. |
| Roblox Studio | Claude project Roblox_Studio, cmd.exe /c C:\Users\BRUKAB~1\AppData\Local\Roblox\mcp.bat | Local batch file exists. Not callable here yet. Needed for live rigs, tracks, properties, and runtime checks. |
| Module placement | Game .claude/skills/module-placement/SKILL.md | Required before planning runtime modules; feature/realm/subfolder/name table and spec-first workflow. |
| Venture UI | Global building-venture-ui | Different game, style, and APIs; do not import its fantasy kit into Cleanup Crew. |
| Cleanup Crew UI | Game .agents/skills/cleanup-crew-ui/SKILL.md | Created in this pass: container choice, screenshot-backed design, contextual HUD, prompt selection, spacing, feedback. |
| Animation authoring | Global generating-animations-with-ai and authoring-roblox-combat-animations | Useful tooling/references for later authoring; rig contact and loop finishing matter. |
| SFX/publishing | Global sourcing-roblox-sfx and publishing-roblox-assets | Useful scripts, with Venture-specific instructions to filter. No generation/upload performed. |
| ElevenLabs | Claude global MCP | Not needed; latest handoff replaces Harlow's rejected generated voice with office sounds. |

No MCP configuration was imported. Credentials were not printed or copied into the repo. Reuse Figma Console's Desktop Bridge and the existing Studio server rather than adding the official Figma integration. Verify live connection status and active files before operating. [Figma Console](https://github.com/southleft/figma-console-mcp), [Studio MCP](https://create.roblox.com/docs/studio/mcp), [Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).

The older game spec is stale on personal-account uploads and Harlow voice. The newer handoff names Icey Labs and describes pen/clipboard sounds. Do not execute either document's publishing steps as fresh user authorization.

## Findings

### Surface versus billboard UI

Confirmed: DepotBuildSystem.shell creates BillboardGui for depot boards/signs. UIBillboards/UIBillboardHost are typed specifically for BillboardGui. OfficeDecor already uses some SurfaceGui signs.

Recommendation: SurfaceGui for contract/result/leaderboards and panels covering a physical wall/truck face; billboards for overhead name/rank tags, transient Harlow cues, selected-item hints, and reward floaters. A host migration must update mounting, cleanup, and personalized results rather than merely change a class name. [Roblox world UI behavior](https://create.roblox.com/docs/ui/in-experience-containers).

### Idle and arms

Confirmed: there IS custom animation code in the base. StarterCharacterScripts/Animate.client.luau suppresses stock Animate and binds AnimationLocomotionHumanoidSystem. AnimationLocomotionRegistry still has provisional clips inherited from Venture, including idle 11526063910. These do not follow the default avatar's animation selections. default.project.json does not set Workspace.Retargeting. The custom locomotion implementation deliberately omits stock tool animations.

Leading hypothesis: inherited clip/rig compatibility or retargeting. Asset loading/ownership and competing tracks remain possibilities. Not reproduced live, so no cause is confirmed; an arms-only idle issue does not justify disabling retargeting globally.

Next diagnosis: inspect rig type/proportions, idle asset, all playing tracks/weights/priorities, load warnings, and Retargeting. Use F4 Anims and animationreport. In an authorized diagnostic session, isolate our locomotion with LocomotionEnabled, compare a known compatible R15 idle on the same rig, then compare retargeting with clip and rig held constant. Restore diagnostics afterward. Verify base/game, supported avatar proportions, respawn, and a second client. [Workspace](https://create.roblox.com/docs/reference/engine/classes/Workspace#Retargeting), [retargeting modes](https://create.roblox.com/docs/reference/engine/enums/AnimatorRetargetingMode).

Latest game commit also returns harlowGrab to PENDING after a sound ID was pasted into the animation slot; this is separate from player idle.

### HUD and text collision

Confirmed: latest HUD scaling code exists; desktop minimum scale is 0.55. Running composition still shows clearance/fee, roster, time card, carry panel, and hints, plus conditional prompt/toast/clock-out layers. The archived screenshot proves the earlier crowding, not the current post-scaling outcome.

Proposal: compact quota/time header; small canister indicator near the tool; pockets when relevant; crew details on request; available/new action hints only; brief startup instruction. Keep character/crosshair/doors/threat visible. Figma must show recent gameplay beneath the design, including Roblox controls/hotbar, at desktop, short-window, and phone landscape sizes.

Potential key/text fault: ShiftPromptChip reserves a fixed inset while KeyChip grows with AutomaticSize.X. Use measured width or horizontal layout with padding, and test long/rebound legends. This is not a confirmed explanation of the specific Clock out image: that image was not attached in this chat.

### Prompt reach and clutter

Confirmed ranges: Load 16 studs; Search 8; Clock out base default 10. Cargo labels render within a separate camera-based 24 studs. Prompts default to no line-of-sight requirement unless opted in. ShiftPromptStore displays one chip, but ShiftPromptSystem selects the latest Shown event, not an explicitly ranked nearest target. Multiple cargo billboards can still show independently.

Proposal: one eligible actionable target ranked by character reach, visibility, aim, and distance, with stable tie handling. Start close-object tuning around 6-8 studs; evaluate the truck's anchor/zone separately. Prefer a selected-item price over floating prices throughout a room. Release holds on selection changes. Keep all server checks. OneGlobally exists but is not a nearest-target algorithm. [ProximityPrompt](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt), [exclusivity enum](https://create.roblox.com/docs/reference/engine/enums/ProximityPromptExclusivity).

### Vacuum inventory

Recommendation: real Roblox Tool in slot 1, auto-equipped on shift entry; familiar PC toggle/select and a clear phone tool/action button. Cargo pickup stows it; releasing cargo restores it when appropriate. Existing authoritative Vacuum state owns canister contents; the Tool is equipment presentation, not a duplicate inventory source. Validate equipped/alive/empty-hands/range on the server, including channel requests.

Add explicit hold/use poses because custom Animate omits stock tool handling. Decide this interaction model before redesigning the shelved carry tray. This is a design hypothesis to validate with the sibling playtest, not a proven claim about children. [Roblox Tool behavior](https://create.roblox.com/docs/reference/engine/classes/Tool).

## Animation inventory

| Priority | Motion | Purpose |
|---|---|---|
| First | Compatible player idle/walk/run/jump/fall | Repair baseline before adding actions. |
| First | Vacuum equip/stow, held idle, suction loop | Hand/nozzle contact; retain leg locomotion. |
| First | Light/medium carry, heavy lift/hold, bulky push | Readable weight and different silhouettes. |
| First | Pickup, load, drop/throw | Contact/release timing without client authority. |
| First | Harlow patrol/chase, look/search, grab/throw | Existing custom slots are PENDING; fallback motion is not custom performance. |
| Next | Rummage, pocket/unpocket | Short interruptible actions. |
| Next | Harlow clipboard habits/break idle | Match his newer office-sound identity. |
| Later | Clock punch, result reactions, crew emotes | Add after core loop/readability validation. |

Use existing animation registry/track owner, layers/interruption, duration, markers, and cleanup. Animation markers do not grant gameplay rewards. Stop cleanly on death/caught/drop/unequip/respawn. The thrown player's ragdoll already handles the physical reaction.

## First-launch hub and UI feedback

Proposal: dispatch board/queue trucks; gear locker; company ID/rank/next milestone; shift handbook; settings/accessibility; last-shift review. Small on-screen shortcuts open the same destinations. Start shift stays primary. Avoid turning all destinations into permanent HUD panels. XP/rank/cosmetics require new progression scope; the current MVP has no persistence.

Make focus/hover, held/pressed, unavailable, and accepted/rejected states clear. Use subtle paper motion, ink changes, visible hold fill, and purposeful audio; touch cannot depend on hover. More permanent panels and constant motion would worsen visibility.

## Building and procedural layout

Confirmed: OfficeLayoutConstants defines seven fixed rooms, reaching a 130 by 90 stud footprint. The spec explicitly excludes procedural geometry; only contents randomize. OfficeBuildSystem explicitly omits ceilings; DepotBuildSystem builds floor/walls without a roof. No CameraMaxZoomDistance setting was found in inspected source.

First restore enclosure: physical ceilings/roof, believable wall thickness, garage openings with exterior dressing, deliberate zoom limits/camera collision. Verify roof from below and outside; a visible underside alone may not hide the exterior. Do not mount artist-owned Workspace into Rojo.

For launch, use an authored modular kit and seeded room graph: reception, cubicles, meeting rooms, toilets, archive, IT, kitchenette, executive rooms, service corridors. Require connected routes/loops, valid doors, no overlaps, reachable loading bay, quota guarantees, deep optional salvage, and valid Harlow navigation. Tune layout size against travel time and seven-minute pacing, not room count alone.

Useful tools: existing Studio MCP, Blender with community MCP for repeatable modular edits, Rojo, UI Labs. A modeling MCP does not provide art direction or a level-generation algorithm. Optional community runtime-debug bridges can add screenshots/multiplayer testing if the Studio bridge lacks them; verify capability overlap first. [Blender MCP](https://github.com/ahujasid/mcp-for-blender), [Studio MCP](https://create.roblox.com/docs/studio/mcp).

## Cohesive assets, uniforms, name/rank tags

Recommended direction: chunky office realism, simple silhouettes, softened edges, cream/gray/teal company colors, restrained roughness, selected grime. Lock one reference sheet and dress one room before spreading the style. Use one authored furniture kit; match original hero meshes for the truck, vacuum, clipboard, locker, and company signage. Cohesion beats raw asset count.

Verified free candidate: Kenney Furniture Kit lists 140 files under CC0. Evaluate a sample room before adopting; it is not a complete cleanup-game asset pack. Keep provenance/license records and inspect imported models for unwanted scripts. [Kit/license](https://kenney.nl/assets/furniture-kit).

An artist commission could deliver a unified premium kit later, subject to a separate budget decision. The free route is a coherent licensed kit plus deliberate Blender edits and original hero assets. Do not treat raw image-to-3D as final hero art: contact surfaces, silhouettes, topology, and materials need finishing.

Uniform proposal: preserve player's head/body/hair/identity; add a company vest/ID badge or an optional outfit. Use rank patches/colors and unlockable variants rather than replace everyone with one character. Test supported proportions and restore appearance after the shift. Name/rank billboards should be concise and nearby; server-derived rank data prevents spoofed progress. Uniforms may support identity, but retention improvement is unproven.

Roblox HumanoidDescription supports selective appearance changes; use the current applied description when editing chosen clothing/accessory fields. [Character appearance](https://create.roblox.com/docs/characters/appearance).

## Order of work

1. Connect existing Figma Console and Studio bridges; capture post-scaling baseline.
2. Reproduce idle on base/game; root fix with specs, static checks, and live evidence.
3. Correct target selection, prompt ranges/visibility, and measured key/text spacing.
4. Decide Tool/carry behavior; approve screenshot-backed compact HUD.
5. Enclose depot/office and tune camera behavior.
6. Dress a representative room/truck and author essential player/Harlow motions.
7. Expand room graph and launch hub/progression after proving the loop.

No runtime tests ran for this documentation/skill-only pass. Do not present historical TestEZ counts as current validation. Live diagnosis and design iteration still need Studio and alternative Figma access.


## Verified follow-up: idle fix and gameplay HUD review

- Registered Claude's existing alternative Figma Console 1.40.9 and Studio bridges in the Codex user configuration. Preserved unrelated settings and backed up the prior config. Credentials remain outside the repository and were not logged. The installed MCP SDK provided live access in this session; future desktop tool discovery may need a server refresh.
- Figma Console actively probed the correct Cleanup Crew file, PYtXsNlpV1MW2nOVx0wXl4. The official Figma MCP was not used.
- Place1 was in Edit mode, contained Cleanup Crew, and had RunTests unset. Agent-created diagnostics were isolated from test sessions.
- Same-avatar comparison: inherited idle 11526063910 held both arms raised. Stopping the extra facial mood track and disabling retargeting did not fix that visible pose. Stock R15 idle 507766666 restored normal arm position on the same character with Default retargeting.
- Changed only idle in AnimationLocomotionRegistry; other inherited locomotion clips remain unchanged. Added its regression spec first. Old implementation: 2118 passed / 1 failed (expected asset mismatch). Corrected implementation: 2119 passed / 0 failed.
- Fresh non-test session played the replacement at Core priority, weight 1, length 4.3 seconds and showed the corrected pose with the facial mood track still present. This verifies the user's current block R15 avatar; a wider avatar/device/multiplayer check remains useful.
- The same two-file fix is prepared independently in E:/Projects/peekabu-game-systems/.worktrees/fix-r15-idle on codex/fix-r15-idle. No commit, push, PR, or merge was performed.
- Game-wide stylua, selene, and luau-lsp checks passed without package reinstallation or package-type regeneration. The isolated base patch passed targeted formatting/lint and whitespace checks; the full Studio suite was run on the game checkout.
- A fresh 1192x588 shift capture confirmed the existing scaling fix resolved the old overlap. The remaining concern is information density, especially empty carry state and permanent hints.
- Created a new named review section below existing Screens content, leaving prior approved designs intact. It contains the current live capture, a compact normal-shift proposal, and a contextual carrying/clock-out proposal, all backed by actual Roblox screenshots. Tool card and display values are mockups; no Tool/HUD redesign has been implemented. Phone validation is explicitly outstanding.
- Figma review section: https://www.figma.com/design/PYtXsNlpV1MW2nOVx0wXl4?node-id=75-2732 ; normal: 75:2737; carrying: 75:2739.
- Evidence files: tmp/codex-mcp/idle-mood-off.jpg, idle-retarget-off.jpg, idle-stock.jpg, idle-fixed.jpg, shift-fixed-hud.jpg, shift-clean-gameplay.jpg, figma-compact-hud-normal-0.png, figma-compact-hud-carry-0.png, red-test-output.txt, green-test-output.txt. Scratch clients/scripts and images stay ignored under tmp/.
- End state: agent play session stopped; RunTests cleared; temporary client retargeting, locomotion, HUD and billboard changes restored/discarded. Studio artist content and publishing settings were not changed.

Next: approve or revise the compact HUD direction, then plan the Tool/carry and contextual-prompt implementation with module placement and spec-first gates. SurfaceGui migration, camera/ceilings, broader animation inventory, assets, and procedural expansion remain outstanding.


## Current status after the continued polish pass

The earlier Next paragraph and statement that the Tool/HUD are only mockups are historical. The approved compact HUD and real vacuum Tool are now implemented (2,130 tests in that pass). Subsequent repairs add single close/visible prompt selection, one selected cargo label, physical depot SurfaceGui boards/reviews, enclosed depot/office geometry, a 16-stud native camera cap, twelve-room seeded modular office variation and menu-button ink feedback. Final suite: 2,144 passed, zero failed, plus static gates. See docs/superpowers/plans/2026-10-11-remaining-polish.md for live verification and limitations; docs/cleanup-crew-launch-polish-2026-10-11.md covers the remaining launch art, animations, hub, uniforms, name/rank and tooling recommendations. Nothing has been committed/pushed/published.
