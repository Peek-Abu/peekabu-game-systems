# SmartBone cloth - TO ADD

> **Not written yet.** The owner (2026-11-16): "smartbone is next then the entire skin skill can be made! OR we make
> the skill now and edit when we add smartbones stuff right after." This file holds what is known so far. Replace it
> with the tested recipe, its gates and its failures once the SmartBone step is done.

## What it is (known)

- It is the **same mesh**. SmartBone adds a few skirt bone chains that ride ON TOP of the leg weights (chains parented
  to the hips/thighs, their weight shared with the leg weights) and moves them a little each frame.
- At rest it looks identical; in motion the skirt lags and swings, heavier toward the hem. Illustration on the skin
  page (https://claude.ai/artifact/HP5UKfMcSWKy9By7nNq17u, `#remake-r6`), from `$SSR/sway_demo.py`.
- It does NOT fix clipping in general: it only pushes chain bones away from colliders. Parts with no chains are untouched.

## Settings tried ("heavy wool", tails test 2026-11-15)

Constraint Spring, Damping 0.25, Elasticity 6, Stiffness 0.55, Gravity (0, -30, 0), Inertia 0.1, per-bone
RotationLimit 25, Radius 0.3, ZAxisLimits 0.2..3, YAxisLimits -4..0.35, legs as capsule SmartColliders
(`characters/skins/release/gloom_carnival/showstopper_tails/smartbone_owner_try.luau`).

## What it needs before it can ship

- The parked `claude/smartbone-tails` code merged (EmployeeTailSmartBoneUtils; owner pick 11-15).
- The SmartBone 2 package (v0.5.2, MIT) in both places, via a Wally install with both Rojo serves stopped.
- A pose gate that simulates it (today's pose gate is pure linear blend skinning).

## Do not repeat

- Six skirt chains on the game's simple two-tail spring (round 4): twitched, clipped, flipped over on a jump.

## To fill in

- [ ] Chain layout per garment kind (skirt, tails, cape, apron)
- [ ] Weight sharing rule between chains and legs
- [ ] Tuned settings per cloth (heavy wool, light cotton, ...)
- [ ] Simulated pose gate and its pass numbers
- [ ] Jump / crouch / emote behaviour
- [ ] Failures met while building it
