# SmartBone cloth (skirts, coat tails, lapel fringe)

Tested on Showstopper Prickles, rounds 1-3 (2026-11-17). Round 3 shipped as `PricklesShowstopperV3` (owner: "good
enough especially for kids"). Round 4 (bones on the cloth surface) is still to come; this file gets its result.
`$SSR` = `characters/skins/release/gloom_carnival/showstopper_remake` (main checkout, untracked).

## What it is

- **The same mesh.** SmartBone 2 (`jakeywastaken/smartbone-2@0.5.2`, MIT, Wally) moves a few bone chains inside the
  cloth each frame, on each client. At rest the outfit looks exactly like the plain skinned build.
- **Chains ride ON TOP of the shipped weights.** Never replace the thigh-follow weights that keep crouch clean. Only a
  share of each point's weight moves onto the chains (see "Weights").
- It does not fix clipping by itself. SmartBone pushes **bones** away from colliders, not the cloth between them.

## Game wiring (code on game/cleanup-crew)

- An outfit opts in with attributes on its Model: `TailPhysics = "SmartBone"` and `Tail<setting>` (root settings) /
  `TailBone<setting>` (per-bone settings: lengths scaled by the character's scale). `EmployeeOutfitSystem.fit` copies
  them onto the fitted `Outfit` folder; `EmployeeTailSystem` hands the character to `EmployeeTailSmartBoneUtils.prepare`.
- Chains are `Tail<name><n>Bone` bones, flat under a Rig holder; prepare nests them, marks the last `_end`, and tags
  each body part in `SMARTBONE_ROOT_PARTS` that carries chains (`LowerTorso` for a skirt, `UpperTorso` for a lapel
  fringe) as its own SmartBone root. All roots share one collider key per character.
- **Colliders:** an outfit `SmartColliders` folder of invisible Parts (`Body` = body part, `ColliderShape` =
  `Capsule`), placed in template space. The fit welds them on, scaled; the client tags them instead of the bare legs.
  SmartBone capsule = the part's X axis is the segment (length = Size.X), radius = min(Size.Y, Size.Z) / 2.
- SmartBone can only load on a client (its debug gizmo hooks RenderStepped as it loads): require it inside `start`,
  never at the top of a module the test runner loads on the server (TestEZ failed to load the spec once).
- Adding the package: `wally install` in the SERVED worktree only in a window with both Rojo serves stopped; pull and
  install together (a client module hard-requires `Packages.SmartBone`).

## Build recipe (`$SSR/ride_chains.py`, `place_sb.luau` / `place_v3.luau`)

1. **Chains:** 6 skirt chains of 3 links (RF RS RB LF LS LB) on the robe's own skirt bones, under LowerTorsoBone, plus
   a zero-weight end marker (Roblox drops it; the place script adds it back one link past the last).
2. **Weights** (on the exported robe, `export_final_r7.blend` so UVs and maps stay valid):
   - the hips' share of every skirt point (1 - thigh-follow) moves onto the chains, fading in below the waist
     (z 1.30 → 1.12) so the waistband stays on the hips;
   - PLUS part of the thigh weight (round 2, "too rigid"): front flaps 45 %, sides and back 35 %, ramping in toward the
     hem (z 1.20 → 0.55). Average share on chains: 41 % (round 1 had 26 % and barely moved the front);
   - around the body a point blends the two nearest chains by angle; down a chain it blends the two nearest links;
   - **the back vent:** below the vent top a back point rides only ITS OWN side's chains (blended over 0.12 above the
     top). An even blend of both back chains held the split rigid while the panels swung ("rigid and weird").
3. **Lapel fringe:** a 2-link chain per lapel under UpperTorsoBone, from the lapel top to its tip; the flap's points
   (the robe's own Lapel groups, same vertex order as the export) move onto it, more toward the tips (LAPK 0.6).
4. **Colliders:** measure the VISIBLE surface (the bloomer puff, the boots, the coat's chest) from the exported meshes,
   then shrink each until no chain bone point touches it at rest (bone radius + 0.02), or SmartBone pushes the cloth
   out while he stands. Showstopper: thighs 0.32 (visible 0.39), seat 0.27 (0.37), shins/boots 0.20, chest 0.41 (0.54).
5. Place with the place script: Tail bones under their holder (`TailU*` → UpperTorso), end markers back, colliders
   from Blender coords through axes **solved from the imported bones** (three known Blender heads), settings as
   attributes. Separate test outfit first (`employeeoutfittest`), the live outfit only after the owner's OK.

## Settings that shipped (round 3)

| Root (outfit `Tail*`) | Value | Per bone (`TailBone*`) | Value |
|---|---|---|---|
| Constraint | Spring (Distance crumples the hem) | RotationLimit | 35 |
| Stiffness | 0.35 (0.55 was "too rigid") | Radius | 0.04 (0.3 ballooned the cloth off the colliders) |
| Elasticity | 4 | YAxisLimits | -4 .. 0.05 (hem ceiling at the hips) |
| Damping | 0.18 | | |
| Gravity | (0, -30, 0) | | |
| Inertia | 0.1, WindType "" (indoors) | | |

The Y ceiling: with 0.35 the hem rose 0.19 above the hips on a jump (a flip); at 0.05 it stays level with them.
Middle links rest just below the hips, so the ceiling cannot go lower without bending the rest shape.

## Gates

- Offline: the pose gate with the chains held rigid to their root part (`pose_gate.py` maps `Tail*` to LowerTorso)
  must match the plain build within a few points (limit-4 can trim thigh weight: crouch 115 → 128 of 4,299).
- In-engine (muted Play, test character from the builder, no profile writes; the owner's account may play another
  employee, so swap the Play character to a builder-made one on the server): per move, the largest hem-tip move from
  rest (swing), lapel-tip swing, the highest hem point vs the hips (flip check), frame-to-frame jitter standing
  (twitch), and chain points inside the VISIBLE volumes (clip depth). Real jumps need `ChangeState(Jumping)`.
- Showstopper round 3: skirt swing walk 0.87 / run 0.98 / stop 0.14 / jumps 1.14; lapel tips 0.54 / 0.70 / 0.10 /
  0.72; hem level with the hips on jumps; deepest clip walk 0.28 → 0.10 with the outfit colliders (run 0.20 both).

## Known limit (round 4 is the fix)

The skirt bones come from the robe rig and sit **inside** the draped cloth, not on it. Colliders act on bones, so they
had to be trimmed below the visible size, and cloth between bones still touches the bloomers (running no better).
Round 4: rebuild the chain bones ON the draped cloth surface, so colliders can be the full visible size; measure the
clipping before and after.

## Failed / rejected

- Six skirt chains on the game's simple two-tail spring (round 4 of the remake, before SmartBone): twitched, clipped,
  flipped over on a jump.
- Heavy wool (stiffness 0.55, elasticity 6, damping 0.25, bend 25): "too rigid".
- Chains carrying only the hips' share: the front flaps barely moved (5 % at the front hem).
- Bone radius 0.3 with body-size colliders: pushes the cloth out at rest.
