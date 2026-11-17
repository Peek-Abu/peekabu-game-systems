# Shipping a skin, and the Studio rules

## Upload

- Owner: Roblox group **Icey Labs (189923277)** only. **Never VentureMMO (9738205)**: the publishing-roblox-assets
  skill defaults to it. Verify the creator afterwards.
- Only after the owner's OK for that upload batch.
- New model asset: `characters/skins/release/gloom_carnival/showstopper_tails/create_model.py`.
- Same id, new revision (preferred by the owner): `characters/skins/release/gloom_carnival/lc_pilot/tools/patch_model.py <id> <fbx>`.
- Upload a **test** asset first. Showstopper's test asset 108833355972983 became the live one only on the owner's word.

## Place (Studio Edit, never saved by an agent)

`$SSR/place_remake.luau` (run through Studio MCP `execute_luau` in Edit):
- builds `ReplicatedStorage.Assets.CleanupCrew.Outfits.<Name>`: Outfit meshes in a **Folder**, Rig holders per body
  part with `<Part>Bone` Bones at the template joints (asserts within 0.02); `Tail<side><n>Bone` chains flat under the
  LowerTorso holder if any;
- copies HideParts from the live outfit and sets HideAccessories / SoloMeshes;
- the skinned meshes weld to **LowerTorso** (HumanoidRootPart leaves them rigid).
- Art must be in **both** places: "Odd Hours" (lobby 113354563835664) and "Odd Hours: Shift" (118845637680835). A place
  without it leaves the character in Classic. Remove old test models from both.

## Engine check

1. Temp Workspace script (a Rojo sync wipes ServerScriptService temps): build employees with the game's builder
   (`EmployeeCharacterSystem.build`), dress with `EmployeeOutfitSystem.fit`, loop the live clips.
2. One muted Play. Captures with a `BindToRenderStep` camera override that also sets `Camera.Focus` (or focus-radius
   systems like the tail spring stop), ScreenGuis hidden.
3. Stop the Play, delete the temps, report what you removed.
4. Owner command: `employeeoutfittest <OutfitModel>`. Every round ends with the exact command he types.

## Register (only on the owner's explicit OK)

- Point the skin's SkinDef in `EmployeeRegistry` at the new outfit (and gear, or none). Spec first, strict Luau.
- Commit on `game/cleanup-crew` (game branches never PR into base or main). Gate:
  `bash scripts/check.sh --skip-install`. Plain commit message, no trailers.
- The owner saves and publishes both places. Rollback = revert the commit (old outfit stays in the places).
- Then the owner's real-play check. Never mark the item done yourself.

## Studio rules (all standing)

- Ask the coordinator session for a slot before ANY Studio MCP call, Edit included. One Play at a time. The
  coordinator is the session that started yours or hands out Studio slots (in Odd Hours: the "Polish and remaining
  features checklist" session); if you can't tell which, ask the user before touching Studio.
- Match the Studio window name AND placeId before acting. Ids change on every restart.
- **Mute every Play**: right after Play starts, in the Client DataModel, set Volume = 0 on every Sound and hook
  `game.DescendantAdded` for new ones. Never touch MasterVolume.
- **No profile writes**: never grant, equip, punch in or buy on a real account, by script or by click. Dress through the
  builder.
- Never save or publish places. Team Create keeps temps through crashes: clean up after every step.
- No computer-use on the owner's desktop.
- Owner images go on an artifact page (he works over Remote Control), one figure per image, plain caption.
