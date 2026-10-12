---
name: cleanup-crew-ui
description: Design, implement, or review Cleanup Crew HUDs, menus, world signs, and interaction prompts using its React paperwork kit and gameplay screenshots. Use for Cleanup Crew UI work; exclude Venture's fantasy kit.
---

# Cleanup Crew UI

Read AGENTS.md, docs/project-structure.md, and the current game design. Locate the game/cleanup-crew checkout rather than editing the base checkout. Use the repo's .claude/skills/module-placement/SKILL.md before planning runtime modules; write specs before implementation.

## Kit and Figma

Reuse Client/UI/React/Screens/Paper, UIPaperConstants, and Client/Features/UI/Data/UIAssets. Paper, manila, cork, wood, stamps, and sticky notes are the identity. The global building-venture-ui skill describes a different game's fantasy kit and UIManager; do not transplant those APIs or style rules.

The user explicitly prohibits the official Figma MCP. Use Southleft's figma-console-mcp and its Desktop Bridge when connected. Configuration in Claude does not establish connection in Codex. Verify status and the active file before editing. Existing design file: PYtXsNlpV1MW2nOVx0wXl4. The project design asks for visual approval before implementing new UI designs; honor current user authorization and ask only when still needed. Show images, not node descriptions.

## Icons and visual hierarchy

The user wants icon-led UI, with fewer words, while retaining readable labels for unfamiliar actions. The original monoline family under design/cleanup-crew/icons (Figma sheet 82:2856) was rejected as too generic; retain it as an exploration, not the prescribed final kit. Study design/cleanup-crew/illustrations and docs/cleanup-crew-art-direction-2026-10-11.md for the researched direction: illustrated company props for navigation, simpler data/status symbols, and bold action silhouettes. Do not mix emoji, font glyphs and unrelated icon packs. Keep icon silhouette and optical weight consistent across HUD, navigation, prompts and world paperwork.

Use a large recognizable icon plus a short label for hub shortcuts. Pair HUD symbols with actual numbers (clock/time, crew/count, vacuum/fill, trash/quota); do not hide gameplay values behind symbols. Touch cannot depend on hover tooltips. Distinguish hover/focus, pressed, selected and disabled states through ink/contrast; use motion sparingly and respect reduced motion. Icons provide hierarchy and recognition, not a reason to add more permanent panels.

The SVGs are editable design sources, not live Roblox assets. Before runtime integration, review the intended screens and export sizes/atlas, obtain any required upload authorization, resolve uploaded Image IDs into UIAssets and use a reusable PaperIcon component. Never put raw asset IDs in screens. Verify readability at intended physical size and on phone before broad rollout. Previous icon-led/word-led proposals 81:2792 and 82:2810 are comparisons. Current shared-direction studies are hub 85:2926, shift 85:2996 and results 85:3046; they are proposals, not an approved final kit. Preserve the functional base while finishing shared art, states and motion across screens. User likes the illustrated hub props; current interaction study is 90:3092 and results revision 90:3166. Use teal idle strips, yellow hover/focus/press strips, a separate persistent teal selected outline, fixed hit targets and smooth 160 ms cubic-out lift/scale/tilt feedback; compress to .965x on press, grow to 1.035x on hover/focus, and remove geometric motion when GuiService.ReducedMotionEnabled is true. See design/cleanup-crew/interaction-preview.html for the design prototype; it is not runtime code. Dedicated award symbols live under design/cleanup-crew/awards and Figma 96:3272: medal, rehire punch card, dropped mug, quiet shoe and noisy vacuum. Do not recycle navigation icons for awards. Native implementations share their original shape definitions in ShiftReviewViewModel. Portraits and joke awards use actual shift data; sample letters are placeholders, not final portraits.

## Choose by behavior

- SurfaceGui: UI physically covering a face, such as contract/result/leaderboards, wall paperwork, terminal screens, and truck panels. Choose Face, Adornee, canvas sizing, and lighting deliberately. Normally AlwaysOnTop=false so physical signage is occluded by walls.
- BillboardGui: UI intended to turn toward the camera, such as name/rank tags, a selected object's hint, Harlow's brief cue, or a reward floater. Billboard scale size is in studs; offset size is in pixels. StudsOffset is camera-relative; use world-space offsets when the anchor must remain fixed in the world.
- Both MaxDistance properties measure camera distance, not character reach, and do not authorize an interaction. Interactive billboard/surface buttons need a GUI parented to local PlayerGui with Adornee; an interactive SurfaceGui's target part also needs CanQuery=true.
- UIBillboards/UIBillboardHost accept the typed WorldShell union (BillboardGui | SurfaceGui). Preserve single-root lifecycle and personalized review isolation. Cargo callbacks narrow to BillboardGui explicitly; never bypass the contract with casts. Depot contract/result/review boards use a fixed SurfaceGui canvas on the Back (+Z) face so arriving crew can read them.

Verify orbiting, approaching, viewing from behind, occlusion, and light response. Sources: [world UI](https://create.roblox.com/docs/ui/in-experience-containers), [BillboardGui](https://create.roblox.com/docs/reference/engine/classes/BillboardGui), [SurfaceGui](https://create.roblox.com/docs/reference/engine/classes/SurfaceGui).

## Review HUDs over real gameplay

Put a recent Roblox gameplay screenshot beneath every Figma HUD composition; label the build, viewport, device, and state. Include normal shift, full carry/pockets, four crew, overtime/clock-out, and catch/spectate. Review 1920x1080, 1366x768, a short window, and phone landscape, accounting for Roblox top bar, thumbstick, jump, and tool hotbar.

Keep the character, crosshair, doors, floor hazards, and Harlow visible. Keep routine quota/time compact; reveal carry detail, crew detail, and hints when useful. Scaling is not a substitute for reducing information density. Check minimum readable type separately from minimum HUD scale. Follow PaperHudFrame's virtual viewport contract for layout arithmetic.

KeyChip grows horizontally for legends like LMB, Shift, and rebound keys. Derive the action text gap from its rendered width or use a horizontal layout with padding. Avoid fixed square-width assumptions. Test long item names and Clock out at supported viewport sizes.

## Prompts and feedback

Keep one actionable target selected using character reach, visibility, aim relevance, and distance, with stable selection around ties. Presentation does not replace server validation. Release a hold when selection changes or the target/UI becomes unavailable.

Cargo price labels follow the target recorded by ShiftPromptStore: at most one selected nearby cargo label. ShiftPromptSystem preserves original native reach and locally sets other prompts to zero range, selecting every 0.1 seconds from visible, in-range server-tagged targets. Carry reach is capped at 6 studs, other hints at 8 or their smaller native range. Do not reintroduce camera-distance label clouds. Presentation never grants server authority. ProximityPrompt.Exclusivity includes OneGlobally, but does not by itself establish a nearest-target policy. [Prompt API](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt), [exclusivity](https://create.roblox.com/docs/reference/engine/enums/ProximityPromptExclusivity).

Provide focus/hover, pressed/held, unavailable, and accepted/rejected feedback. Use subtle paper displacement, ink changes, hold fill, and purposeful sound. Touch must work without hover; supported keyboard/gamepad focus needs equivalent feedback. Respect reduced motion. Clean up on close, respawn, teleport, and reset.

## Evidence

Use UI Labs stories for component iteration and a non-test Studio session for full gameplay composition. Do not interrupt a user's live playtest without authorization. Singleton TestEZ tests need a separate session. Report static checks, live visual verification, and proposals separately. This skill grants no permission to upload assets or publish the place.
