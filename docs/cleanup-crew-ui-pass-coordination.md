# UI pass coordination — 2026-10-12

User assigned this agent UI/interactions/playability and another agent vacuum/art/style/office expansion. Studio MCP remains with the other agent by explicit user reply. This pass makes no Studio or Figma calls, no Play stops/starts/device/camera changes, and no art/office/animation edits.

Owned files: existing client UI Screens/Depot/DepotHubViewModel + spec, DepotHubScreen + story; expand to other UI families only after review identifies a concrete issue. No new runtime modules planned. Existing live evidence in tmp/muse-gates is historical evidence from the previous pass, not validation of subsequent edits.

Current fix: Guide/Gear fixed-height copy blocks can overlap on narrow screens; header title width collapses below 560px. Replace copy offsets with content-sized vertical layout, add tested viewport geometry, stack settings labels on narrow panels. Preserve saved settings and server-authored gameplay.

Next live handoff: 390x844 portrait, 844x390 landscape, 1366x768 desktop; long guide/control text, all five settings controls/reset, scroll to last section; mouse/focus/press/reduced-motion, actual vote-button click. Only run once Studio ownership is handed over. No singleton TestEZ in a gameplay session.

## Local completion evidence

Guide/Gear content now uses nested content-sized UIListLayouts; wrapped heading/body text sets section height and scroll extent. Portrait headers separate subtitle from title/close; narrow settings labels sit above unchanged 48px steppers. Screen bounds derive from the tested existing DepotHubViewModel helper. Story has separate portrait (390x844) and landscape (844x390) controls. No new modules or changes to art/layout/server code.

Added TestEZ specs before implementation for panel/header/body bounds and compact selection. These new specs have NOT run: Studio remains assigned to the other agent. Targeted Luau type analysis exits 0 with no diagnostics. Depot Selene reports 0 errors/warnings/parse errors; StyLua passes after formatting. Repository file-length gate passes.

Screen-family source audit: hub, contract/depart, results vote/fold/reopen and CCTV buttons share PaperButton feedback. Prompts and mobile action arc use specialized press/hold controls; preserve hold lifecycle and quiet HUD. Prior screenshots confirm existing styling only, not the new responsive layout. Remaining live checks are listed above; performance review, vote and device interactions must still be inspected after integration with new art.

## Progress motion module placement (before writing)

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| UI tree | client | React/Hooks | ProgressTweenUtils | Pure normalized-target / snap policy, spec first |
| UI tree | client | React/Hooks | useProgressTween | TweenService NumberValue bridge to React binding; cancels superseded tweens, reduced motion and unmount cleanup |

Clearance uses 220ms Quad Out; hold display uses 50ms Linear without forward extrapolation, immediate release/target switch reset. Authoritative numbers and completion remain immediate. Scope includes compact + existing expanded clearance renderers and prompt strip. No Studio calls.

## Progress motion implementation evidence

Compact and expanded clearance bars share useProgressTween (220ms Quad Out); displayed totals stay immediate. Prompt strips use 50ms Linear interpolation of measured hold progress, snap on decrease, and reset by prompt identity + hold start. No completion prediction and no delayed gameplay callback. Initial mount starts at current progress. Superseded tweens cancel from their current value; subscriptions/tweens/driver are cleaned up. Reduce Motion changes snap to target. Shared PaperButton uses TweenService:GetValue Cubic Out for the existing 160/90ms pose animation.

Official API reference reviewed: https://create.roblox.com/docs/reference/engine/classes/TweenService . TweenService drives a private NumberValue and React.Binding; it does not mutate a GUI Size also controlled by React. Existing health/XP easing, FadeGroup and specialized touch controls were retained. Animated numeric tally/panel entry/exit are not added in this pass.

Targeted types and Selene pass; repository file-length passes. Policy specs written before implementation (nonfinite/bounds, interruption reset, reduced motion). TestEZ and live visual timing remain unrun for these changes because user reserved Studio for the other agent. New verification cases: mid-sweep quota update, new shift decrease, cancel/switch/restart hold, reduced motion during tween, panel unmount while tweening.
