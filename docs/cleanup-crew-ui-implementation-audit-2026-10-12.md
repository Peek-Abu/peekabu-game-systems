# UI tasks 1–3 implementation audit

## Implemented
- DepotServiceClient registers the illustrated Jobs/Guide/Gear/Settings HUD. It disappears for a crew during starting/running/results and while a travel card is showing. Transitioning into a shift closes depot scenes.
- Jobs reads the server-authored replicated contract-board ContractId and opens the existing contract view, preserving the last-shift receipt and actual dispatch instructions. It cannot bypass boarding or depart validation.
- Guide gives the actual four-step job/clear/bank/noise/clock-off loop. Gear explains the issued vacuum and carrying behavior; it promises no fictional purchases, cosmetics or progression.
- Settings observes and changes the existing persisted SettingServiceClient definitions: Music/SFX/UI/Ambient volumes and CameraShake. Ten-percent steps are clamped; reset restores those five definitions individually. Reduced motion follows Roblox's preference; no duplicate save layer.
- PaperButton supports illustrated `prop` and transparent `surface` presentations. All retain the existing fixed input target and smooth 160 ms grow/tilt, 90 ms press, hover/focus/press strip and reduced-motion contract. Selected outline is separate from transient colour.
- Compact HUD crew/tool buttons now share that interaction. Vacuum's original filled silhouette appears at desktop equipment-card size. No new permanent HUD panels; phone layout remains quiet.
- Performance reviews keep the actual quota/rating/metrics, award titles, user identification, joke detail, vote choices/counts/open flag/countdown, and mobile two-note fold. Cream receipt, teal rules, clip, company footer, dedicated award symbols and real player headshots elevate presentation.
- Personalized physical review boards also use the matching title-specific award symbols. Unknown titles have no invented icon. No guessing avatar identities from names; existing personalized-board isolation remains.
- Contract paperwork uses the filled clipboard prop and cream/clip treatment. Travel tickets, queue cards and rehire letterheads adopt the company teal; danger/hazard reds remain semantic.

## Audit: preserve purpose
| Screen family | Outcome |
|---|---|
| Hub/navigation | Original filled props, fixed targets, actual pages, mouse/gamepad/touch selectable |
| Contract/depot card/pad | Same kit colours, actual contract and returning receipt, native boarding/depart unchanged |
| Quiet shift/carry/tool | Compact/contextual density preserved; shared smooth input feedback and equipment art |
| Interaction prompt | Existing single-target range/hold/key-gap rules preserved; avoid replacing hold input with click-only button |
| Results/awards | Title-specific art shared across screens, actual player portraits on desktop, vote/rating/phone-fold preserved |
| Catch/CCTV | Preserve intentional surveillance aesthetic and native spectate controls; rehire letterhead matches company stationery |
| Physical signs | SurfaceGui contract and private-review host remain unchanged; illustrated awards are shared with results |

## Verification evidence
- New pure behavior specs written before implementations: DepotHubViewModel.spec (visibility, touch size, adjustment bounds); PaperPropViewModel.spec (distinct complete bounded shapes). ShiftReviewViewModel.spec adds actual userId and unknown-award shape behavior.
- Targeted luau-lsp analyze across Depot/Paper/Catch, compact HUD, review model/panel, physical results and DepotServiceClient: no diagnostics in final pass. Output tmp/codex-mcp/ui-typecheck.log.
- Selene: 0 errors/0 warnings/0 parse errors. Stylua check passes all touched screen directories/files. Entire repository file-length check passes.
- UI Labs: DepotHubScreen.story shows guide/equipment; PaperPropIcon.story includes phone/desktop, disabled and selected treatment. Existing board/shift/review/catch fixtures continue to cover their data states.
- Parent still owns Studio visual verification and the isolated TestEZ run. Those gates must be filled with actual execution evidence; static results are not a substitute.
- Native editable shape rendering requires no UI image upload. No assets uploaded or place published.

## Remaining limitations to verify live
- Thumbnail API may return an engine placeholder while loading; UI remains usable, and cancelled loads cannot write after unmount.
- Very narrow portrait viewports are outside existing landscape phone fixtures; verify wrapping and scroll in actual devices.
- Results remain the functional receipt structure rather than replacing voting with a decorative sample-screen layout.
