# Footwear: a quality gate, not an assumed reuse

Owner 2026-11-18: Bell Jester shoes “look nowhere near quality of other shoes like sheriff prickles”. The remake reused `r2_pippa/p7_cut.py` footwear. It joins separate foot/ankle ellipsoids and a curled tube, with a bumpy tube cuff. It was not 3D generated. Sheriff comparison (`release/sheriff_prickles/build.py`, later fixes) was also built, with deliberate sole/heel/vamp/shaft/cuff construction. Generation method alone does not establish quality.

## Before building or reusing

Inspect the locked skin reference, the actual worn shoe and a close-up of the game's best comparable footwear. State what the shoe needs: silhouette, volume, sole/heel, toe spring or curl, shaft opening, folded cuff, decoration. Old acceptance of a whole outfit does not approve every reused shoe indefinitely. Owner rejection overrides the previous reuse choice.

## Construction

- Build a continuous coherent upper through heel, instep and toe. A curl grows out of the vamp; it does not look like an attached pipe or finger. A closed one-colour upper may be unioned/cleaned before its new UVs, preserving deliberate silhouette.
- Give the sole a designed thickness and side profile. Use the concept's heel height. Do not add western spurs/stitching to unrelated jester boots just because Sheriff is the quality reference.
- The opening has a real inner wall. A folded cuff reads as a turned strip, with broad intentional scallops where shown, not a ring of intersecting balls. Check its inside against the native lower leg.
- Shaft follows shin; foot, sole, heel and toe bell follow foot. A controlled ankle blend keeps one upper continuous; inspect flex instead of using weights to hide disconnected parts. Keep the native leg above the cuff.
- Real material maps follow shape approval. Flat fit maps do not excuse primitive-looking shape, and extra surface noise does not replace shoe construction.

## Jester motion and attachment lessons

- A curled toe can rise into the height of the shin while still belonging entirely to the FOOT. Never classify its weights by height alone. Limit ankle blending to the actual shaft/ankle region; keep the sole, curl and any attached decoration on the foot. Check the curl against the rigid foot transform across all live keys. Bell Jester r14 drifted up to .9915 studs and folded into itself; the corrected r15 curl had zero relative drift.
- An attached ornament needs an actual attachment, not just adjacent centres. If the concept has a bell loop, seat the hanger through that loop and let the bell body hang clear of the shoe. Gate both intersection and movement; a closed mesh can still look detached. The owner subsequently removed BOTH shoe bells and hangers in r16; do not restore them from an older export.
- This construction lesson applies to other props too: design the bow folds, bell mouth/loop, sole profile or buckle structure deliberately. Primitive shapes are useful scaffolding; fused blobs or intersecting tubes are not a finished-quality shortcut.

## 3D generation

The older skill's blanket “AI boots” rejection came from failed generated outfit routes. It was not evidence that all footwear generation is inherently unsuitable. A generated rigid shoe upper can be a candidate/reference only under the existing licensed prop route (TRELLIS; no unsupported/licence-incompatible tool). It still requires coherent topology, thickness, native fit, readable sole/cuff, acceptable colours, export limits and the same owner close-up/worn-motion review. Never substitute a new pipeline merely because the current built pair is weak; compare the actual results. Never silently ship the raw generated mesh or treat an AI success on another prop as footwear approval.

## Review evidence

Show same-angle old/new front, side and three-quarter worn views, plus a close shoe view and underside if the sole needs judgement. Check non-manifold edges, normalized max-four weights and per-mesh triangles. Inspect standing, walk, run, crouch, fidget and the skin's prop clip. Keep toes, cuffs and sole from breaking apart at the ankle. Owner decides the visual quality; numerical clearance alone is insufficient.
