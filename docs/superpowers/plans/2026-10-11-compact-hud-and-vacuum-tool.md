# Approved compact HUD and vacuum Tool

Approval: user approved Figma review section 75:2732 on 2026-10-11. Match compact quota/time, collapsed crew, contextual carry/actions and vacuum/canister information. Retain existing catch suppression, server authority and mobile action arc.

## New modules (before implementation)

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Vacuum | shared | Rules | VacuumEquipmentRules | Authoritative suction eligibility and automatic equip policy. |
| Vacuum | server | Systems | VacuumToolSystem | Creates/owns the server Tool; stows for cargo and recreates after respawn. |
| Shift UI | client | UI/React/Screens/Shift | ShiftCompactHudPanel | Presentational approved compact paperwork HUD and crew disclosure. |

Each gets a sibling spec. UI follows the existing screen subtree exception; no new subfolder kind, role, feature, or service. Existing Vacuum services, Shift service lifecycle, ShiftHud/ViewModel and prompt chip are adapted. Update module map after additions.

## Gates

1. Write eligibility/equip, Tool construction, compact visibility/action and panel specs first.
2. Grant a real non-droppable Tool only to shift crew; equip on entry/respawn, stow for cargo, respect manual stow, revoke on results/reset/leave. Validate actual server equip on every suction tick.
3. Implement compact physical-pixel layout, collapsed crew disclosure and contextual cargo/actions. Preserve native Tool hotbar, existing state data and canister ownership. Clear overlays on catch/results.
4. Replace fixed key/text assumptions with measured/horizontal layout. Keep phone touch controls unobstructed.
5. Run format/lint/typecheck/project rules and separate TestEZ. Verify live equip/stow, cargo, clock-out, crew toggle, respawn and short/phone-sized compositions. No asset uploads or publishing.

## Verification completed

- Studio TestEZ: 2,130 passed, zero failed in a separate opt-in session. RunTests cleared afterward.
- Format, Selene, luau-lsp, module placement rules and 400-code-line gate passed. Package links were preserved while Rojo was running. Module map regenerated for all six added files.
- Fresh play session: Tool granted/equipped, HUD crew disclosure and Tool button clicked through actual UI paths; manual stow respected; E pickup stowed Tool, G drop restored selection; ending shift revoked Tool.
- Respawn recreated and equipped the Tool. Real mouse hold cleared a pile through the normal server interaction channel.
- Phone composition rendered at 844x390 with movement/jump reservations: empty hands, cargo, pockets and clock-out reviewed. Final phone clock-out spacing moved by 8px after visual review. This is a layout fixture, not touch-device emulation; physical touch/controller input remains unverified.
- Native hotbar uses a real server-owned Tool. Studio VirtualInput forbids One; the user's manual keypress was not conclusively traced before that shift ended. Do not claim an automated One-key test.
- Diagnostic GUI removed, camera restored, agent-started play stopped. No asset upload, publish, commit or push. The code-built vacuum is a functional prototype pending the cohesive asset pass.

Evidence images are local ignored scratch captures under tmp/codex-mcp: compact-live-empty.jpg, compact-live-crew.jpg, compact-live-stowed.jpg, compact-live-carry.jpg, compact-live-final.jpg, compact-phone-empty.jpg and compact-phone-cargo.jpg (phone cargo capture precedes the final 8px banner spacing adjustment).
