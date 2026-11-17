-- Places the TEST outfit Model ReplicatedStorage.Assets.CleanupCrew.Outfits.PricklesShowstopperRemake (Edit mode, Shift;
-- never saved by an agent) from the Icey Labs model ASSET (showstopper_remake/r17/export/Showstopper_Remake.fbx: SSR_Robe
-- = the one robe (skirt skinned to hips + thighs), SSR_Upper = sleeves/waistcoat/shirt/toggles, SSR_Lower = bloomers + boots,
-- SSR_Hat = the earlier hat). Same build as ../showstopper_tails/place_tails.luau: body bones go under a holder per
-- body part, every Tail<side><n>Bone FLAT under the LowerTorso holder (EmployeeTailSystem swings them). Worn with
-- `employeeoutfittest PricklesShowstopperRemake`. Run through Studio MCP execute_luau (Edit).
assert(game.PlaceId == 118845637680835 or game.PlaceId == 113354563835664, "wrong place " .. game.PlaceId)
local IS = game:GetService("InsertService")
local ASSET = 108833355972983
local NAME = "PricklesShowstopperRemake"
local outfits = game.ReplicatedStorage.Assets.CleanupCrew.Outfits
local live = outfits:FindFirstChild("PricklesShowstopper")
assert(live, "the live Showstopper outfit is missing here")
local tpl = game.ReplicatedStorage.Assets.CleanupCrew.Characters.Prickles
local out = {}
local holder = IS:LoadAsset(ASSET)
local coat = holder:FindFirstChildWhichIsA("Model")
assert(coat, "the asset holds no Model")
coat.Parent = nil
holder:Destroy()
coat:ScaleTo(coat:GetScale() * 0.01) -- the FBX is in cm
local function jointOf(part: BasePart): CFrame?
	for _, d in tpl:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 == part and d.Part0 ~= nil then
			return d.Part0.CFrame * d.C0
		end
	end
	return nil
end
local bones = {}
for _, d in coat:GetDescendants() do
	if d:IsA("Bone") and d.Name ~= "ExportRoot" then table.insert(bones, d) end
end
local offset, n, rows = Vector3.zero, 0, {}
for _, b in bones do
	local pn = b.Name:match("^(.+)Bone$")
	local part = pn and tpl:FindFirstChild(pn)
	local j = part and part:IsA("BasePart") and jointOf(part)
	if j then
		local dd = j.Position - b.WorldPosition
		offset += dd; n += 1; table.insert(rows, { b = b, d = dd })
	end
end
offset /= math.max(n, 1)
local worst = 0
for _, r in rows do worst = math.max(worst, (r.d - offset).Magnitude) end
table.insert(out, string.format("body bones matched %d of %d, worst residual %.4f", n, #bones, worst))
assert(worst < 0.02, "outfit bones do not line up with the template joints")
coat:PivotTo(coat:GetPivot() + offset)
local old = outfits:FindFirstChild(NAME); if old then old:Destroy() end
local root = Instance.new("Model"); root.Name = NAME
root:SetAttribute("HideParts", live:GetAttribute("HideParts"))
-- his hard hat, and the Showstopper skin's own hat gear if he wears that skin: this outfit brings the hat itself
root:SetAttribute("HideAccessories", "HardHat,ShowHatGear")
root:SetAttribute("SoloMeshes", "SSR_Robe,SSR_Upper,SSR_Lower,SSR_Hat")
root:SetAttribute("Source", "TEST ONLY: Showstopper remake round 4 (Icey Labs " .. ASSET .. "); worn with employeeoutfittest")
local meshes = Instance.new("Folder"); meshes.Name = "Outfit"; meshes.Parent = root
local rig = Instance.new("Folder"); rig.Name = "Rig"; rig.Parent = root
local tails = 0
for _, b in bones do
	local pn = b.Name:match("^(.+)Bone$")
	local part = pn and tpl:FindFirstChild(pn)
	if pn and pn:match("^Tail%a+%d+$") then part = tpl.LowerTorso; tails += 1 end
	if part and part:IsA("BasePart") then
		local grp = rig:FindFirstChild(part.Name)
		if grp == nil then
			grp = Instance.new("Part"); grp.Name = part.Name; grp.Size = Vector3.new(0.1, 0.1, 0.1)
			grp.CFrame = part.CFrame; grp.Anchored = true; grp.CanCollide = false; grp.CanQuery = false; grp.CanTouch = false
			grp.Transparency = 1; grp.Parent = rig
		end
		local c = Instance.new("Bone"); c.Name = b.Name
		c.CFrame = part.CFrame:ToObjectSpace(b.WorldCFrame); c.Parent = grp
	end
end
table.insert(out, "tail bones " .. tails)
for _, mp in coat:GetDescendants() do
	if mp:IsA("MeshPart") then
		local c = mp:Clone()
		for _, k in c:GetChildren() do if not k:IsA("SurfaceAppearance") then k:Destroy() end end
		c.Anchored = true; c.CanCollide = false; c.CanQuery = false; c.CanTouch = false; c.Massless = true
		c:SetAttribute("StyleSlot", "Opaque")
		c.Parent = meshes
		table.insert(out, string.format("mesh %s %s tex %s tris? size %s", c.Name, c.MeshId, c.TextureID, tostring(c.Size)))
	end
end
coat:Destroy()
-- Roblox's importer drops bones with no weights, so the Tail<side>4Bone end markers never arrive: add them, one link
-- length past link 3 (the links are equal thirds of the skirt).
local lt = rig.LowerTorso
for _, s in { "RF", "RS", "RB", "LF", "LS", "LB" } do
	local b2, b3 = lt:FindFirstChild("Tail" .. s .. "2Bone"), lt:FindFirstChild("Tail" .. s .. "3Bone")
	if b2 and b3 and not lt:FindFirstChild("Tail" .. s .. "4Bone") then
		local tip = Instance.new("Bone"); tip.Name = "Tail" .. s .. "4Bone"
		tip.CFrame = b3.CFrame + (b3.CFrame.Position - b2.CFrame.Position)
		tip.Parent = lt
		table.insert(out, "added end marker " .. tip.Name)
	end
end
root.Parent = outfits
return table.concat(out, "\n")
