# Native R15 idle correction

The inherited Venture idle visibly raises both arms on a native block R15 avatar. Stock R15 idle 507766666 restores the normal resting pose on the same live rig. Stopping the facial mood track and disabling retargeting did not resolve the inherited pose.

No new runtime modules. Existing shared Animation/Data/AnimationLocomotionRegistry and its sibling spec change in the isolated codex/fix-r15-idle base worktree and the game checkout. No place-property changes.

1. Write stock-idle regression spec; confirm it fails against the old registry.
2. Replace only idle with the verified engine R15 clip and document the provenance.
3. Run separate Studio TestEZ, format/lint/type checks, and live pose verification.
4. Keep base change separate from game-only HUD work. No push or merge without user instruction.
