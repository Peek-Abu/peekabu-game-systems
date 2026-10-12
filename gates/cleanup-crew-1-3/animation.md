# Gates: animation

- [x] G1: Claude motion skill applied; briefs/seed/provenance and local candidates prepared with actual models/rig mapping checked.
  EVIDENCE: design/animations/vacuum/generation-provenance.json: seed10112, local repo pin/checkpoint hashes, 4 briefs ×3 fixed64f repeats. Native captured15 AnimationConstraints referenced; generic inferred Venture retarget skeleton rejected. Comfy8188 queues idle checked; no downloads/unloads.

- [x] G2: Final equip/hold/use/stow contact-aware clip sources and marker/duration/loop audit exist; no fake uploaded IDs.
  EVIDENCE: final/ four JSON and four editable native-proportion Blender scenes/contact renders. clip-audit.json: source durations0.65/3.2/3.2/0.45s, max wristIK error<6e-16stud, hold/use matrixseam0 and analytic matchedvelocity, no root/feet keys. Native live Animator validation remains parent gate, not claimed from Blender renders. Registry domain intentionally empty pending exact4asset/owner approval; no invented IDs.

- [x] G3: Runtime state/animation integration spec-first; manual stow, carry, respawn, death and shift-end lifecycle covered.
  EVIDENCE: AnimationVacuumSystem.spec.luau written before implementation; 6 lifecycle scenarios plus domainreadiness test. VacuumServiceServer serverauthority callback integration completed. Selene sixchangedruntime/specfiles0errors0warnings; formatting passed. Studio TestEZ 2026-10-12: 2182 passed 0 failed (incl. all vacuum/carry specs). Root fix during validation: Destroying fires DEFERRED, never synchronously inside Destroy() (verified live for detached, ServerStorage and Workspace instances) — AnimationCarrySystem.spec now waits 0.1 s after Destroy() before asserting signal cleanup; implementation unchanged and correct for live play.

- [x] G4: Server-owned carried-object hand contact uses real reachable item surfaces, native arm-only IK, and cleans up on every release path.
  EVIDENCE: 2026-10-12 live: E pickup of Recycling box bound CleanupCarryIKRight+Left on the real character; G drop removed both; Harlow catch mid-carry removed both with cargo drop + carry-variant incident report. Equip/hold/use/stow native clip validation still pending asset upload (registry intentionally empty); no invented IDs.
