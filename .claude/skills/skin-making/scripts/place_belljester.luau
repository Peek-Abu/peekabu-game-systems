-- Bell Jester Pippa (registered skin Pippa.BellJester): places its art in a place. EDIT mode, lobby (113354563835664) or
-- Shift (118845637680835). Builds ReplicatedStorage.Assets.CleanupCrew.Outfits.PippaBellJester (Outfit meshes + Rig
-- bones, HideParts = "UpperTorso,LowerTorso,LeftFoot,RightFoot") and ...Accessories.PippaBellJesterBow (fitted gear on
-- UpperTorso). The bells mesh is Metal with Reflectance 0.25 (the owner's "yes try shine"); bells and bow have
-- CastShadow off (their shadows read as smudges on the cream diamonds). Replaces any earlier copy. Nothing is saved.
-- Icey Labs assets: outfit 105264153238774, bow 126687199561393.
assert(game.PlaceId == 118845637680835 or game.PlaceId == 113354563835664, "wrong place " .. game.PlaceId)
local IS = game:GetService("InsertService")
local cc = game.ReplicatedStorage.Assets.CleanupCrew
local tpl = cc.Characters.Pippa
local out = {}
do
	local m = IS:LoadAsset(126687199561393)
	local mp = m:FindFirstChildWhichIsA("MeshPart", true)
	assert(mp, "bow: no MeshPart in the asset")
	local old = cc.Accessories:FindFirstChild("PippaBellJesterBow"); if old then old:Destroy() end
	local g = Instance.new("Model"); g.Name = "PippaBellJesterBow"
	local p = mp:Clone(); p.Name = "Bow"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.CastShadow = false
	p.CFrame = tpl.UpperTorso.CFrame * CFrame.new(0.0, 0.4708, -0.7690); p.Parent = g
	g.WorldPivot = tpl.UpperTorso.CFrame; g:SetAttribute("MountPart", "UpperTorso")
	g:SetAttribute("Source", "characters/skins/release/gloom_carnival/r2_pippa (p7_bow.py), asset 126687199561393")
	g.Parent = cc.Accessories
	table.insert(out, string.format("PippaBellJesterBow mesh %s size %.2f,%.2f,%.2f", p.MeshId, p.Size.X, p.Size.Y, p.Size.Z))
	m:Destroy()
end
local holder = IS:LoadAsset(105264153238774)
local coat = holder:FindFirstChildWhichIsA("Model"); coat.Parent = nil; holder:Destroy()
coat:ScaleTo(coat:GetScale() * 0.01) -- the FBX is in cm
local function jointOf(part)
	for _, d in tpl:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 == part and d.Part0 ~= nil then return d.Part0.CFrame * d.C0 end
	end
	return nil
end
local bones = {}
for _, d in coat:GetDescendants() do if d:IsA("Bone") and d.Name ~= "ExportRoot" then table.insert(bones, d) end end
local offset, n, rows = Vector3.zero, 0, {}
for _, b in bones do
	local pn = b.Name:match("^(.+)Bone$"); local part = pn and tpl:FindFirstChild(pn); local j = part and jointOf(part)
	if j then local dd = j.Position - b.WorldPosition; offset += dd; n += 1; table.insert(rows, dd) end
end
offset /= math.max(n, 1)
local worst = 0
for _, dd in rows do worst = math.max(worst, (dd - offset).Magnitude) end
assert(worst < 0.02, "outfit bones do not line up with the template joints")
coat:PivotTo(coat:GetPivot() + offset)
local old = cc.Outfits:FindFirstChild("PippaBellJester"); if old then old:Destroy() end
local root = Instance.new("Model"); root.Name = "PippaBellJester"
root:SetAttribute("HideParts", "UpperTorso,LowerTorso,LeftFoot,RightFoot") -- her torso (under the romper) and her feet (inside the boots)
root:SetAttribute("Source", "characters/skins/release/gloom_carnival/r2_pippa (p7_cut.py, p7_export.py), asset 105264153238774")
local meshes = Instance.new("Folder"); meshes.Name = "Outfit"; meshes.Parent = root
local rig = Instance.new("Folder"); rig.Name = "Rig"; rig.Parent = root
local nb = 0
for _, b in bones do
	local part = tpl:FindFirstChild(b.Name:match("^(.+)Bone$"))
	if part and part:IsA("BasePart") then
		local grp = rig:FindFirstChild(part.Name)
		if grp == nil then
			grp = Instance.new("Part"); grp.Name = part.Name; grp.Size = Vector3.new(0.1, 0.1, 0.1); grp.CFrame = part.CFrame
			grp.Anchored = true; grp.CanCollide = false; grp.CanQuery = false; grp.CanTouch = false; grp.Transparency = 1; grp.Parent = rig
		end
		local c = Instance.new("Bone"); c.Name = b.Name; c.CFrame = part.CFrame:ToObjectSpace(b.WorldCFrame); c.Parent = grp; nb += 1
	end
end
for _, mp in coat:GetDescendants() do
	if mp:IsA("MeshPart") then
		local c = mp:Clone()
		for _, k in c:GetChildren() do if not k:IsA("SurfaceAppearance") then k:Destroy() end end
		c.Anchored = true; c.CanCollide = false; c.CanQuery = false; c.CanTouch = false; c.Massless = true
		c:SetAttribute("StyleSlot", "Opaque")
		if c.Name == "BellJester_Bells" then c.Material = Enum.Material.Metal; c.Reflectance = 0.25; c.CastShadow = false end
		c.Parent = meshes
		table.insert(out, string.format("mesh %s %s shadow=%s mat=%s", c.Name, c.MeshId, tostring(c.CastShadow), c.Material.Name))
	end
end
coat:Destroy()
root.Parent = cc.Outfits
table.insert(out, string.format("bones %d, worst residual %.4f", nb, worst))
local has = game.ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry.Source:find("PippaBellJester", 1, true) ~= nil
table.insert(out, "place " .. game.PlaceId .. " code has the skin: " .. tostring(has))
return table.concat(out, "\n")
