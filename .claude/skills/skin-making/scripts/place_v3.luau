-- SmartBone test (owner 11-17 "Yes lets do smartbone!"): places ReplicatedStorage.Assets.CleanupCrew.Outfits.
-- PricklesShowstopperSB from Icey Labs model 101847990925723 (cr/SB: the textured remake + 6 skirt chains
-- Tail<RF|RS|RB|LF|LS|LB><1..3>Bone riding on the thigh weights). Same build as place_tex.luau, plus: every Tail bone FLAT
-- under the LowerTorso holder, the <4> end markers added back, and the heavy-wool SmartBone settings as Tail* attributes
-- (EmployeeTailSmartBoneUtils). Worn with `employeeoutfittest PricklesShowstopperSB`. The live V2 is not touched.
-- Edit mode, never saved by an agent.
assert(game.PlaceId == 118845637680835 or game.PlaceId == 113354563835664, "wrong place " .. game.PlaceId)
local IS = game:GetService("InsertService")
local ASSET = 101847990925723
local NAME = "PricklesShowstopperV3"
local MAPS = {
	SSR_Hat = { color = 101667662706494, normal = 75951197212053, rough = 95380614652385 },
	SSR_Lower = { color = 87252559026424, normal = 125740080147811, rough = 105667216271777 },
	SSR_Robe = { color = 104949947866848, normal = 117468377339262, rough = 115886055834343 },
	SSR_Upper = { color = 77674441163023, normal = 98344977945233, rough = 137174073064117 },
}
local WOOL = {
	TailPhysics = "SmartBone", TailConstraint = "Spring", TailDamping = 0.18, TailElasticity = 4, TailStiffness = 0.35,
	TailGravity = Vector3.new(0, -30, 0), TailInertia = 0.1, TailWindType = "",
	TailBoneRotationLimit = 35, TailBoneRadius = 0.04, TailBoneYAxisLimits = NumberRange.new(-4, 0.05),
}
local outfits = game.ReplicatedStorage.Assets.CleanupCrew.Outfits
local live = outfits:FindFirstChild("PricklesShowstopperV2")
assert(live, "the live V2 outfit is missing here")
local tpl = game.ReplicatedStorage.Assets.CleanupCrew.Characters.Prickles
local function image(decalId)
	local m = IS:LoadAsset(decalId)
	local d = m:FindFirstChildWhichIsA("Decal", true)
	assert(d, "no Decal in " .. decalId)
	local t = d.Texture
	m:Destroy()
	return t
end
local out = {}
local holder = IS:LoadAsset(ASSET)
local coat = holder:FindFirstChildWhichIsA("Model")
assert(coat, "the asset holds no Model")
coat.Parent = nil
holder:Destroy()
coat:ScaleTo(coat:GetScale() * 0.01)
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
	local pn = b.Name:match("^(.+)Bone$")
	local part = pn and tpl:FindFirstChild(pn)
	local j = part and part:IsA("BasePart") and jointOf(part)
	if j then local dd = j.Position - b.WorldPosition; offset += dd; n += 1; table.insert(rows, { b = b, d = dd }) end
end
offset /= math.max(n, 1)
local worst = 0
for _, r in rows do worst = math.max(worst, (r.d - offset).Magnitude) end
table.insert(out, string.format("body bones matched %d of %d, worst residual %.4f", n, #bones, worst))
assert(worst < 0.02, "outfit bones do not line up with the template joints")
coat:PivotTo(coat:GetPivot() + offset)
local root = Instance.new("Model"); root.Name = NAME
for k, v in live:GetAttributes() do root:SetAttribute(k, v) end
for k, v in WOOL do root:SetAttribute(k, v) end
root:SetAttribute("Source", "Showstopper remake, LIVE skin outfit from 17 Nov 2026 (Icey Labs " .. ASSET .. " rev 5 = the round 3 file, SmartBone round 3: skirt + lapel fringe chains, vent split, own colliders); characters/skins/release/gloom_carnival/showstopper_remake")
local meshes = Instance.new("Folder"); meshes.Name = "Outfit"; meshes.Parent = root
local rig = Instance.new("Folder"); rig.Name = "Rig"; rig.Parent = root
local tails = 0
for _, b in bones do
	local pn = b.Name:match("^(.+)Bone$")
	local part = pn and tpl:FindFirstChild(pn)
	if pn and pn:match("^Tail%a+%d+$") then part = if pn:match("^TailU") then tpl.UpperTorso else tpl.LowerTorso; tails += 1 end
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
		for _, k in c:GetChildren() do k:Destroy() end
		c.Anchored = true; c.CanCollide = false; c.CanQuery = false; c.CanTouch = false; c.Massless = true
		c:SetAttribute("StyleSlot", "Opaque")
		local maps = MAPS[c.Name]
		assert(maps, "no maps for mesh " .. c.Name)
		local sa = Instance.new("SurfaceAppearance")
		sa.ColorMap = image(maps.color); sa.NormalMap = image(maps.normal); sa.RoughnessMap = image(maps.rough)
		sa.Parent = c
		c.TextureID = ""
		c.Parent = meshes
		table.insert(out, string.format("mesh %s %s", c.Name, c.MeshId))
	end
end
coat:Destroy()
-- Roblox's importer drops bones with no weights, so each chain's end marker never arrives: add it back, one link past
-- the last (the skirt under LowerTorso, the lapel fringe under UpperTorso).
for _, holderName in { "LowerTorso", "UpperTorso" } do
	local h = rig:FindFirstChild(holderName)
	local sides = {}
	for _, b in (h and h:GetChildren() or {}) do
		local side, n = b.Name:match("^Tail(%a+)(%d+)Bone$")
		if side then sides[side] = math.max(sides[side] or 0, tonumber(n)) end
	end
	for side, last in sides do
		local b1, b2 = h:FindFirstChild("Tail" .. side .. (last - 1) .. "Bone"), h:FindFirstChild("Tail" .. side .. last .. "Bone")
		if b1 and b2 then
			local tip = Instance.new("Bone"); tip.Name = "Tail" .. side .. (last + 1) .. "Bone"
			tip.CFrame = b2.CFrame + (b2.CFrame.Position - b1.CFrame.Position)
			tip.Parent = h
			table.insert(out, "end marker " .. tip.Name)
		end
	end
end
-- SmartBone colliders sized to what you SEE (cr/SB3/sb3.json, Blender template studs; each shrunk to clear the chain
-- bones at rest). The Blender->Roblox axes are solved from the imported bones themselves (three known Blender heads).
local B = { LowerTorsoBone = Vector3.new(0, 0, 1.1), LeftUpperLegBone = Vector3.new(0.25, 0, 1.0), UpperTorsoBone = Vector3.new(0, 0, 1.3), TailLF1Bone = Vector3.new(0.314, -0.367, 1.32) }
local W = {}
for _, holder in rig:GetChildren() do
	for _, b in holder:GetChildren() do if b:IsA("Bone") and B[b.Name] then W[b.Name] = (holder.CFrame * b.CFrame).Position end end
end
local o_b, o_r = B.LowerTorsoBone, W.LowerTorsoBone
local cols = { "LeftUpperLegBone", "UpperTorsoBone", "TailLF1Bone" }
local bm, rm = {}, {}
for i, n in cols do bm[i] = B[n] - o_b; rm[i] = W[n] - o_r end
-- M = R * Binv (3x3, columns), Binv by cofactors
local a, b2, c = bm[1], bm[2], bm[3]
local det = a:Dot(b2:Cross(c))
local r1, r2, r3 = b2:Cross(c) / det, c:Cross(a) / det, a:Cross(b2) / det -- rows of Binv
local function toR(p)
	local d = p - o_b
	local k = Vector3.new(r1:Dot(d), r2:Dot(d), r3:Dot(d))
	return o_r + rm[1] * k.X + rm[2] * k.Y + rm[3] * k.Z
end
local COLS = {
	{ "LeftThigh", "LeftUpperLeg", Vector3.new(0.29, 0, 1.0), Vector3.new(0.30, 0, 0.70), 0.322 },
	{ "RightThigh", "RightUpperLeg", Vector3.new(-0.29, 0, 1.0), Vector3.new(-0.30, 0, 0.70), 0.322 },
	{ "LeftShin", "LeftLowerLeg", Vector3.new(0.30, 0, 0.60), Vector3.new(0.32, -0.02, 0.22), 0.198 },
	{ "RightShin", "RightLowerLeg", Vector3.new(-0.30, 0, 0.60), Vector3.new(-0.32, -0.02, 0.22), 0.199 },
	{ "Seat", "LowerTorso", Vector3.new(-0.30, 0, 1.08), Vector3.new(0.30, 0, 1.08), 0.266 },
	{ "Chest", "UpperTorso", Vector3.new(0, 0, 1.40), Vector3.new(0, 0, 1.95), 0.413 },
}
local scaleR = (toR(Vector3.new(1, 0, 1.1)) - o_r).Magnitude -- studs per Blender unit (1 after the cm fix)
local cf = Instance.new("Folder"); cf.Name = "SmartColliders"; cf.Parent = root
for _, spec in COLS do
	local pa, pb = toR(spec[3]), toR(spec[4])
	local dir = (pb - pa).Unit
	local up = if math.abs(dir.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local zv = dir:Cross(up).Unit
	local yv = zv:Cross(dir).Unit
	local p = Instance.new("Part"); p.Name = spec[1]
	p.Size = Vector3.new((pb - pa).Magnitude, spec[5] * 2 * scaleR, spec[5] * 2 * scaleR)
	p.CFrame = CFrame.fromMatrix((pa + pb) / 2, dir, yv, zv)
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1
	p:SetAttribute("Body", spec[2]); p:SetAttribute("ColliderShape", "Capsule")
	p.Parent = cf
end
table.insert(out, string.format("colliders %d, axes det %.3f, studs per unit %.3f", #COLS, det, scaleR))
local old = outfits:FindFirstChild(NAME); if old then old:Destroy() end
root.Parent = outfits
return table.concat(out, "\n")
