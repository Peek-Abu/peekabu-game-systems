# Gates: modeling

- [x] G1: Revised truck and real multi-row keyboard sources/exports exist with original palette and proportions.
  EVIDENCE: editable `design/production-art/proof-set/cleanup-crew-proof-set.blend`, original regeneration script, company-truck.glb + keyboard.glb; five-row 54-key keyboard plus spacebar; truck cab 9.6 vs 12-stud bed, front axle narrowed, wheel arches and open tail.

- [x] G2: Truck front/side/three-quarter renders inspected; boarding/collision envelope documented, no queue outside visible bed.
  EVIDENCE: truck-front.png, truck-side.png, company-truck.png, truck-rear-boarding.png and keyboard-detail.png inspected. Four 5.4-stud original block reference avatars in truck-four-avatar-boarding.png; footprint centres ±3, ±3 within 12x16 bed, arms 2.8-stud spread. Runtime pad is unchanged and visible across full bed. Two collision treads provide access; avatars are reference sizes, native live check remains parent.

- [x] G3: Runtime visual builders/asset template integration prepared and specs/static checks pass; original source retained.
  EVIDENCE: spec-first DepotTruckVisualSystem + OfficeDeskVisualSystem integrated into existing Build modules; placement below. Selene four modules: 0 errors/warnings/parse errors. StyLua passed. Studio TestEZ 2026-10-12 (2182 green) includes DepotBuildSystem/OfficeBuildSystem/Desk specs. Live 2026-10-12: depot truck beds + tags, office 5-row keyboard on desks, vacuum Tool in hand all visible in tmp/muse-gates/*.jpg. No uploads; GLBs remain local candidates.

## Module placement before implementation

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Depot | server | Systems | DepotTruckVisualSystem | Own non-authoritative company truck decoration around existing bed |
| Office | server | Systems | OfficeDeskVisualSystem | Own office workstation decoration including five-row keyboard |

Existing pad size/CFrame/tags remain unchanged. Cosmetic parts do not collide/query/touch; authoritative bed and cab collider remain separate. No new role/subfolder/service.

## Expert/defect/polish passes

Corrected spacebar orientation (frontmost row), exposed front tires by narrowing chassis/axle, separated physical boarding from queue space, preserved original interactable anchors; all decorative parts nonquery/noncolliding. Source/render geometry remains original, GLB unuploaded.
