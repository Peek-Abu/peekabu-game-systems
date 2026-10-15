# Integration gates

- [x] G1: Parent static/TestEZ rerun
  EVIDENCE: Fresh native TestEZ 2328 passed / 0 failed. Whole-source Selene, StyLua, strict Luau-LSP, file cap, module map and PR rules pass.
- [x] G2: Native held-jump chase/airborne catch/loading models/door render/navigation
  EVIDENCE: Two physics jumps, continuous chase movement and airborne catch; opaque-wall sensing and separate-height reach controls pass. Real recycling-box bank arc uses MeshPart and cleans up. 124/124 isolated seed paths plus 36/36 dressed-map paths pass. Native captures inspect both doorway faces. See docs/cleanup-crew-jump-door-layout-verification-2026-10-13.md for scope and exact observations.
- [x] G3: Door proposal and accurate remaining scope
  EVIDENCE: Selective interactive doors proposed in verification document, not claimed implemented. Art backlog, broader playtests, audio and public-player validation remain explicit.
