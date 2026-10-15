# kit-runtime gates

- [x] G1 specs before strict kit/visual implementation
  EVIDENCE: ArtKitRegistry.spec, ArtKitRules.spec and ArtVisualSystem.spec created in initial spec-only write command before implementation files. All production modules --!strict, no any/casts; ArtTypes type-only exemption handed to parent.
- [x] G2 tests cover two map kits, absent/unapproved/unsafe models, fit, moving root, hide/reveal
  EVIDENCE: ArtVisualSystem.spec has seven isolated instance specs covering two-map selection and explicit override; missing/unapproved/Script refusal; uniform fit, root tags/physics, anchored movement, Anchored synchronization, welds, original transparency reveal; scaled recursive grips/source immutability/replacement/clone cleanup; PrimaryPart pivot/rotation/root cleanup; 40x1x60 building coverage; doorway clear-opening fit with missing metadata refusal. ArtKitRules.spec has five safety specs and ArtKitRegistry.spec verifies all 47 semantic keys. Source coverage verified; TestEZ execution requires parent-owned isolated Studio session, not claimed by this leaf.
- [x] G3 lint/style/type clean without package regeneration
  CHECK: selene src/ReplicatedStorage/Shared/Features/Art src/ServerScriptService/Features/Art && stylua --check src/ReplicatedStorage/Shared/Features/Art src/ServerScriptService/Features/Art && luau-lsp analyze --sourcemap=sourcemap.kit-runtime.json --definitions=globalTypes.d.luau --ignore="**/*.spec.luau" src/ReplicatedStorage/Shared/Features/Art src/ServerScriptService/Features/Art
  EXPECT: /0 errors/
  EVIDENCE: [WARN] client does not allow didChangeWatchedFiles registration - automatic updating on sourcemap changes disabled | [INFO] Loading Luau configuration from e:\Projects\peekabu-game-systems\.claude\wor
