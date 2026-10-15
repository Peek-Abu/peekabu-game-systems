# integration gates

- [x] G1 parent reruns export/static checks and complete coverage matches 47 keys
  EVIDENCE: export audit 47 keys / 30,040 triangles / 47 unique geometry buffers; full lint/format/types, PR rules, module map, file length and 21 Python tests pass.
- [ ] G2 separate Studio TestEZ green and persistent native client/cargo lifecycle verified
  EVIDENCE: isolated TestEZ 2,215 passed / 0 failed; actual server builder 166 art models; all13 local hide/reveal/grips pass. Persistent client/carry/load check pending uploads. Local EditableMesh replication failed and temporary assets isolated away from production.
  2026-10-13 (post-organize, Place1 eb68b2b0): isolated RunTests Play re-run **2,215 passed / 0 failed**. Server-side production lifecycle on installed templates: **46/46 attach, 46/46 hide/reveal roundtrip, 0 physics-flag failures, deskCalendar fallback holds (nil)**. Client rendering + carry/load on client still pending owner observation.
- [x] G3 source textures/scale/room readability inspected and issues fixed
  EVIDENCE: family sheets and native Edit office/cargo screenshots inspected; atlas UV issue and carpet colour fixed; Figma113:3470 source/native review distinguishes local preview from production.
- [ ] G4 production asset persistence/import/owner approval resolved before claiming final shipped integration
  EVIDENCE: user selected Icey Labs189923277. Exact47-model manifest and reviewed batch prepared; uploads explicitly held by user; calendar excluded; future draft batch46 models, not approved. No asset/place upload performed.
  2026-10-13: user uploaded 46 models (Asset Manager folder `Office-slate`) and inserted them into Place1 (each key twice, as `Scene` wrappers with inner keyed Model). Organized via Studio bridge into `ReplicatedStorage.Assets.CleanupCrew.ArtKits["client-office-slate"]` — **building 12/12, furniture 13/13, cargo 13/13, props 8/8 (deskCalendar correctly missing), 0 missing**; contract verified live (RuntimeApproved=true, BaseSize=bbox within tol, pivot bottom-centred, OpeningWidth=2.78 on wallDoorway, FitMode=Stretch on desk, no scripts/humanoids/prompts). 46 duplicate `Scene` copies left in Workspace for owner to delete; place save is owner-side. Final shipped-integration claim still needs owner save + client-side approval.
