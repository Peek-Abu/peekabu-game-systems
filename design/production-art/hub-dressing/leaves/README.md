# Hub leaves from a CC0 scan (owner OK 2026-11-11: "one CC0 autumn-leaf scan set", look before any upload)

Source: ambientCG **ScatteredLeaves008** (CC0), 2K JPG, in `$TEXPIPE_WORK/cc0/ScatteredLeaves008` (F:/Dev/temp/claude/texwork).

1. Texture pass: `texstyle.py leaves leaves_scan2k` with the new `leaves` style class (keep_color: the yellow/green/orange
   mix kept, mean pulled toward a warm autumn swatch) at the scan's full 2048 px, so each leaf is ~0.35 studs on a
   4-stud employee.
2. Cards: `leafcards.py` cuts a drift card (560 px of the scan -> 1024 px, a leafy oval whose rim follows the leaves
   via the scan's height map, islands removed) and four scatter clumps (150 px -> 256 px), each with colour (RGBA),
   normal, roughness (and the drift's height).
3. Look: `leaf_look.py` (Blender 5.1) renders the drift as a 4.4 x 3.4 x 0.45-stud mound displaced by the scan's height
   (96 x 96 grid, under the 20k-triangle limit) with scatter cards around it.

Look sheet: notes `hub-leaves-scan-look-2026-11-11.jpg`. Nothing uploaded; the scripts point at the scratch work
folder (edit the paths at the top to rerun).
