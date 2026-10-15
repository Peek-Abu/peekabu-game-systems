# Harlow pursuit / Studio verification pending

Local code complete; Studio remains reserved for asset agent. No Studio MCP calls were made for this change. Other art/layout files untouched.

Changes: retain known target when outside acquisition cone but require unobstructed sight; when obscured run to the last observed point then up to two nearby distinct authored route points (within36studs), scanning10seconds per point, max32seconds total. Noise heard while searching preserves urgent running search and original timeout, never uses hidden live player coordinates. Bay safety, catch grace and shift breaks unchanged. Chase speed crew17 / solo16.5, plus0.5 per tier (max18 /17.5). Draft gameplay balance.

Navigation: dedicated Path per computation, serialize active refreshes, retain prior usable route during refresh failures, connect Blocked only for forward waypoints, invalidate after1.5seconds with under1stud movement, tight1stud waypoint arrival versus3stud final goal; stop/destroy cancels stale jobs and clears event connections. Forbidden-cost regions never bypassed by straight-line fallback.

Validation: full selene0errors0warnings, full stylua, full Luau typecheck, PR rules, module map and file length clean. Six new pursuit/path-recovery regressions plus updated speed/search specs written before implementation. These tests HAVE NOT RUN; earlier2215-green belongs to preceding art/UI change, not this AI change.

Next when Studio released: isolated RunTests=true TestEZ session, stop and clear RunTests, fresh play. Verify pursuit around office L-corners/doors, blocked-path recovery, solo and crew escape balance, audible-noise search redirects, timeout, bay exclusion and post-catch grace. Inspect tall rig actual collision envelope versus navmesh clearance. Tighter waypoint following affects all NPC kinds in this game branch, so check normal patrol movement too.

Docs: Roblox forward-blocked path handling https://create.roblox.com/docs/characters/pathfinding . No asset uploads needed.

## Verified after Studio released

Final suite2,247passed/0failed. Real controlled L-corner: sight lost0.75s, target retained, re-acquired1.25s after turning into hall, caught2.25s, resumedpatrol3.75s. This is functional proof, not final multiplayer/running-player balance. Latest source/remaining work in docs/cleanup-crew-remaining-work-2026-10-12.md.
