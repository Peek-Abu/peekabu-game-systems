# Camera and two-asset repair verification

## Camera

Native CameraType.Custom and DevCameraOcclusionMode.Zoom were already active, with normal 0.5–16 zoom limits. Imported art hid the collidable structural roots (Transparency 1) and disabled mesh queries/collisions, leaving no suitable opaque obstacle for native Zoom. Roblox documents the transparency threshold at https://create.roblox.com/docs/workspace/camera .

OfficeBuildSystem now creates opaque structural backing outside the transparent roots' descendant trees. This hierarchy matters: ray exclusions on a transparent root also exclude its descendants. Wall cores use 45% of wall depth to stay behind the cream body and slate dado. Ceiling backing is inset; existing recessed floor underlays are queryable/collidable. No custom PlayerModule fork, new camera service, or manager change was introduced.

Native fresh normal-play check with the final source: wall camera distance 2.888 studs and roof distance 7.724 studs, both inside the building envelope, versus approximately 16 studs outside the wall/roof before the hierarchy fix. Camera remained Custom. Camera near-plane placement permits the camera point inside the thickness of a wall/ceiling; verification uses the outer building envelope. Native wall-art capture confirmed the slate dado remains visible.

Tests: 2329 passed, 0 failed in a separate TestEZ session. Whole-source Selene, StyLua, strict Luau-LSP and code-line caps pass; module map and PR rules pass. Test mode was cleared and Studio returned to Edit after normal-play checks.

## Art

Canonical build_catalog.py no longer builds the dust-bag badge. Printer buttons moved from outside the scanner lid footprint onto it; buttons/display intersect the lid instead of floating above it. Focused repair_requested_assets.py regenerated only the two GLBs, manifest records and dustbag-printer-repair.blend. Full 47-asset binary audit passes; dustBag audit rejects the ivory badge cell. Other models were not replaced.

Studio local template previews contain the repaired geometry with existing atlas materials, semantic keys and carry data. Native rendered review confirms the unbranded bag and supported printer controls. Original templates are preserved in ServerStorage.ArtBeforeDustPrinterRepair. New previews use local EditableMesh content, are not newly uploaded durable asset IDs, and require a deliberate import/upload decision before release. Source GLBs are durable local files. The historical full-catalog blend/review sheets were not regenerated.

No game publishing or asset uploading occurred. Temporary review models and gameplay probes were removed/ended. Equipment integration audit and manager design ideas are in cleanup-crew-manager-direction-and-mvp-2026-10-13.md; manager code was deliberately untouched.
