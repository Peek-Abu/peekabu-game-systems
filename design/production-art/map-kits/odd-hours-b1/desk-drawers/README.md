# Desk with drawers that open (stage 4, Task 9)

Status: built and rendered, **not uploaded**. Waiting for the owner's OK on the renders below; upload and kit assembly
(`AssembleKit.CommandBar.luau`, `KIT_MAP.md`) come after that.

Hand-built in Blender 5.1 (headless; the Blender MCP addon was not reachable this session) with the texture-pipeline
hard-surface kit (`hardlib.py`: bevelled boxes, oak scan, plaster-bump laminate). No AI meshes. It is `c_desk_nodivider`
rebuilt with a hollow drawer pedestal: same oak top, cream laminate pedestal / leg panel / modesty panel, steel bar pulls,
same footprint, no divider.

- Script: `build_desk_drawers.py` (run line at its top). `stats.json` holds every number below as the script measured it.
- Renders for the owner: `renders/shaded_open_closeup.png` (drawers open, close-up), `renders/shaded_open_tq.png`,
  `renders/shaded_closed_tq.png`, `renders/shaded_kneehole.png`; flat turntables `renders/flat_closed_{front,back,side,below,tq}.png`
  and `renders/flat_open_{front,tq}.png`. Open = every drawer slid by the game's offset (2.07 mesh units; see below).
- Not committed (binaries, local only): `textures/*.png`, `export/*.fbx|obj|glb|blend`.

## Size and orientation

8.8 W x 4.95 H x 4.6 D, worktop underside at 4.67, same as `c_desk_nodivider`. Authored front -Y, Z up; the FBX export
(axis_forward -Z, up Y, FBX_SCALE_UNITS, materials stripped) gives the usual 180-deg-about-Y trap, after which the front is
-Z (NegativeZ) and the pedestal sits at Roblox +X, the leg panel at -X: the same layout as the current desk. Fit: Stretch to
`DESK_SIZE` 8.25 x 4.95 x 4.95, as now.

## Meshes

| Mesh (FBX object / file) | Tris | Size W x H x D | Bbox centre, Roblox axes after export (x, y, z) | SearchComponent |
|---|---|---|---|---|
| `desk_body` (top, leg panel, modesty panel, hollow pedestal shell, front rails, plinth) | 2,532 | 8.8 x 4.95 x 4.6 | (0, 2.475, 0) | none |
| `desk_drawer_1` (top drawer: front, pull, oak box) | 928 | 2.4 x 1.39 x 3.9 | (3.0, 3.895, -0.35) | `"drawer"` |
| `desk_drawer_2` (middle) | 928 | 2.4 x 1.39 x 3.9 | (3.0, 2.445, -0.35) | `"drawer"` |
| `desk_drawer_3` (bottom) | 928 | 2.4 x 1.39 x 3.9 | (3.0, 0.995, -0.35) | `"drawer"` |

All far under 20,000. Centres are relative to the desk's floor-centre origin, in mesh units (before the Stretch to
`DESK_SIZE`). Uploaded meshes are recentred on their bbox, so place each drawer MeshPart at its centre (scaled with the desk)
relative to the body's floor centre.

Exports: `export/desk_drawers.fbx` (all four objects), `export/<mesh>.fbx` and `.obj` per mesh, `export/desk_drawers_parts.glb`
(preview with the colour map), `export/desk_drawers.blend`.

## Textures (colour + normal + roughness)

Two atlases: `textures/desk_body_{color,normal,rough}.png` for the body, and `textures/desk_drawers_{color,normal,rough}.png`
shared by all three drawers (one SurfaceAppearance for the three drawer MeshParts). Colour 1024 (colour x baked AO),
tangent normal 1024 (OpenGL), roughness 512. Each set was baked with the other meshes hidden, so the drawer boxes are not
darkened by the pedestal they sit in, and the pedestal interior keeps its own open-box shading.

## How the drawers fit `OfficeSearchedDressingSystem`

- The search moves every part with `SearchComponent = "drawer"` by `root.Size.Z * 0.45` toward the front. With the proxy at
  `DESK_SIZE.Z` 4.95 that is 2.23 studs = 2.07 mesh units (the mesh is 4.6 deep, stretched x1.076).
- Each drawer box is 3.68 deep (front face at -2.08, box back at 1.6, Blender Y), so fully slid it still has 1.6 inside the
  pedestal: it reads as pulled out, never detached. The shell is hollow (sides, back, floor, cap, rails), so the drawer
  cavity is real when it opens.
- `buildTemplate`'s searchable drawer is the upper pedestal drawer at +X (front x 1.73..3.63, y 3.18..4.34 at DESK_SIZE); this
  desk's top drawer front covers x 1.69..3.94, y 3.2..4.59 after the stretch: the same spot. All three drawers here are separate
  meshes; tag all three `"drawer"` (they slide together, as the system moves every tagged part), or tag only
  `desk_drawer_1` to match the native prototype (the other two then stay shut as part of the art).

## Hide-space measurement (closed drawers, at 8.8 x 4.95 x 4.6)

Measured on the final meshes with a BVH (`hide_space()` in the script):

- Knee-hole clear width 5.6 (pedestal side x -1.75 to leg panel x 3.85, Blender X; the same at 12 probe points from
  z 0.5 to 4.4 and y -1.5 to 1.5), clear height 4.67 (floor to worktop underside), clear depth 4.39 from the worktop's front
  edge to the modesty panel.
- A `HUG_FREE_MIN` box 3.6 W x 4.2 H x 4.3 D on the floor, its front at the worktop front edge (x -0.75..2.85, y -2.3..2.0,
  z 0..4.2): 0 triangle overlaps, 0 vertices inside: **free**.
- After the Stretch to `DESK_SIZE` the knee-hole grows to 5.25 x 4.67 x 4.72 (the current desk's 5.25 / 4.67 / 4.73), so the
  in-Studio probe from `KIT_MAP.md` should still pass.
