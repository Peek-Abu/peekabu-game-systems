# Shipping a skin, and the Studio rules

Ids, places, tools and code files: [odd-hours.md](odd-hours.md).

## Which asset

| Situation | Do |
|---|---|
| A new skin's first upload | A NEW **test** model asset (`create_model.py`), after the owner's OK for that upload. |
| Next build round of that skin | PATCH the same test asset (`patch_model.py <id> <fbx>`, a new revision, same id). The owner prefers same ids. |
| A live skin needs a new look | Prefer a NEW outfit Model name in the places (`...V3`, `V4`), from its own test asset: rollback is one registry revert. |
| A fix to the live look the owner asked for (re-texture, the fetch-failure nudge) | May PATCH the live outfit's asset and re-place the SAME Model name (Showstopper V2's texture round and rev 7 did), only on his OK. Rollback is then a re-PATCH of the old FBX, so keep it. |
| Texture maps | One image per map per mesh (`publish.py image ... --group`); check the first one's creator before sending the rest. |

Verify the creator after every upload: the group, never VentureMMO. Uploads come back as Decals for images.

## Place (Studio Edit, never saved by an agent)

Every placing script (`place_remake.luau`, `place_tex.luau`, `place_v4.luau` in [scripts/](scripts/README.md)) does:
- `assert(game.PlaceId == <lobby> or game.PlaceId == <shift>)` first;
- loads the asset with `InsertService:LoadAsset`, builds `...Outfits.<Name>`: Outfit meshes in a **Folder**, Rig
  holders per body part with `<Part>Bone` Bones at the template joints (asserts within 0.02 of the template), any
  `Tail<name><n>Bone` chains flat under their holder;
- sets `HideParts` / `HideAccessories` / `SoloMeshes` (copied from the Model it replaces when there is one);
- the skinned meshes weld to **LowerTorso** (HumanoidRootPart leaves them rigid);
- builds the new Model completely, THEN swaps out an old one of the same name, so a failed run leaves the live outfit
  untouched; sets a `Source` attribute saying build, asset, revision and date.

**Textured outfits** (`place_tex.luau`): an Open Cloud image upload is a Decal. A SurfaceAppearance needs its Image:
`InsertService:LoadAsset(decalId)` -> the Decal's `Texture`. Put one SurfaceAppearance (ColorMap / NormalMap /
RoughnessMap) on each MeshPart and clear `TextureID`.

**Fitted gear** (a hat, glasses, a bow; precedent `r2_pippa/tools/place_belljester.luau`): a Model named
`<Employee><Skin><Piece>` under `...CleanupCrew.Accessories`, its parts Anchored, CanCollide / CanQuery / CanTouch
false, `CastShadow` false for small shiny bits; `Model.WorldPivot` = the TEMPLATE's mount part CFrame
(`...Characters.<Employee>.<Part>`), attribute `MountPart = "<Part>"` (usually Head or UpperTorso). Modelled at the
template's authored size: `EmployeeGearSystem` scales it with the character. Listed in the SkinDef's `accessories`.
Never an Accessory instance (Accessories don't follow `ScaleTo(1.25)`).

**Art must be in BOTH places** (lobby and Shift). Copying between Studio windows drops joints to things outside the
copy: run the placing script in each place instead of pasting.

## Engine check (before the owner sees it in game)

1. Temp Workspace script (a Rojo sync wipes ServerScriptService temps), named `__TEMP_<what>_delete_me`: builder-made
   employees (`EmployeeCharacterSystem.build`, no player, no data), dressed with `EmployeeOutfitSystem.fit`, looping
   the live clips by asset id (precedent `scripts/tex_check_server.luau`). Builder models placed with
   `CFrame.lookAt(pos, pos - Z)` face -Z: put the camera on that side.
2. One muted Play. **On the client, check `ContentProvider:GetAssetFetchStatus` for every worn mesh and map** right
   after any upload or PATCH: all `Success`. Captures with a `BindToRenderStep` camera override that also sets
   `Camera.Focus` (focus-radius systems like the tail spring stop without it), ScreenGuis hidden. Judge unlit AND in the
   game light.
3. Check the shared poses with the skin on: vacuum hold, hide, sit, carry. Report clipping there; fixes stay generic.
4. Stop the Play, delete the temps, report what you removed.
5. The owner tries `employeeoutfittest <OutfitModel>`. Every round ends with the exact command he types.
   `employeeoutfittest` only fits OUTFIT Models. For a gear-only skin (a hat, glasses) there is no test command: leave
   a temp lineup in the place he will play (builder-made characters wearing the gear via `EmployeeGearSystem`, looping
   the live clips, at a spot you name, e.g. the depot start), tell him where to walk, and delete it after his look.
   Never grant the item to test it; `cosmeticgrant` is the owner's own choice and writes to his account.

## Register (only on the owner's explicit OK)

His OK counts only when he gives it after seeing the look on the page and the test in game (or, when he can't open
Studio, engine captures on the page). "Just push it" before he has seen it is not the OK; nor is a general "go" an OK
for an upload: each upload batch gets its own yes. When time is short he may choose to cut scope (drop a piece, keep
one look, ship later). Tell him plainly what a cut costs, with a picture (e.g. the flat swatch next to the textured
one); if he still picks it, that is his call: write it in the ledger and the commit.

Order matters:
1. Art for the final outfit Model (and gear) placed in BOTH places, fetch status checked.
2. Code: the four files in [odd-hours.md](odd-hours.md), spec first, strict Luau, on the game branch. Gate, plain
   commit, push. A place without the art shows the employee Classic, so the art goes in first.
3. The owner saves and publishes both places (agents never do).
4. His real-play check. Never mark the item done yourself: "Ready to check".

**Rollback:** revert the registry commit (or point the SkinDef back at the previous Model). The previous outfit Model
stays in both places for exactly this; keep it until the owner says the new one is final.

## Studio rules (all standing)

- Ask the coordinator for a slot before ANY Studio MCP call, Edit and read-only probes included. One Play at a time.
- Match the Studio window name AND `game.PlaceId` before acting. Studio's own ids change on every restart.
- **Mute every Play**: right after Play starts, in the Client DataModel, set Volume = 0 on every Sound and hook
  `game.DescendantAdded` for new ones. Never touch MasterVolume.
- **No profile writes**: never grant, equip, punch in or buy on a real account, by script or by click. Older handoffs
  (Backstage, Bell Jester) granted skins with `CosmeticServiceServer:grant`: that is now forbidden. Dress through the
  builder or `employeeoutfittest`; Studio Play saves data.
- Never save or publish places. Team Create keeps temps through crashes: clean up after every step.
- No computer-use on the owner's desktop.
- Owner images go on an artifact page (he works over Remote Control), one figure per image, plain caption.
