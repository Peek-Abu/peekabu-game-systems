-- p05 D1 (2026-11-13): apply lighter meshes onto the live employee templates, Studio Edit mode, one undo step.
-- Run with execute_luau (plugin security: ApplyMesh and CreateEditableMeshAsync are Studio-only). Set DRY to true to
-- only check.
--
-- For each listed part, the uploaded MeshPart of the same name is applied with MeshPart:ApplyMesh. ApplyMesh resets
-- the part's TextureID (found 2026-11-13: 58 palette textures were cleared), so Size, CFrame and TextureID are carried
-- over explicitly. The old MeshId is kept in the PreDecimateMeshId attribute (revert: CreateMeshPartAsync(old) +
-- ApplyMesh, the same carry-over).
--
-- Gates:
-- 1. Shape: the new mesh's area-weighted surface centre (as a share of its box) is within 2% of the old one's on every
--    axis, and its surface area within 5%. A mirrored, turned or wrong mesh fails; plain vertex centroids do NOT work
--    for this (decimation thins dense areas and moves them).
-- 2. Nothing but the mesh changed: a fingerprint of every part of the three characters WITHOUT MeshId (size, offset,
--    colour, material, transparency, TextureID, SurfaceAppearance maps, attachments, joints, welds, cages) is taken
--    before and after; any difference undoes the whole swap and returns FAILED.
local DRY = false
local IS = game:GetService("InsertService")
local AS = game:GetService("AssetService")
local CH = game:GetService("ChangeHistoryService")
local chars = game.ReplicatedStorage.Assets.CleanupCrew.Characters
-- Icey Labs uploads (reports/p05-decimation-assets.json): 10k, uneven per-part budget.
local PLAN = {
	Pippa = { assets = { 121831375393658 }, parts = { "Head", "FacePlate", "LeftEar", "RightEar", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" } },
	Prickles = { assets = { 137010044011782, 119997776729942, 137899872075531 }, parts = { "Head", "FacePlate", "Flower_Head", "HardHat_Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" } },
	Cappy = { assets = { 129334512397399, 101043745487395, 138632442766031, 134776856534115 }, parts = { "Head", "FacePlate", "Cap_Head", "Hoodie_UpperTorso", "UpperTorso", "Hoodie_LeftUpperArm", "Hoodie_RightUpperArm", "Hoodie_LeftLowerArm", "Hoodie_RightLowerArm", "Hoodie_LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "Sneakers_LeftFoot", "Sneakers_RightFoot", "LowerTorso" } },
}

local function r(x)
	return string.format("%.3f", x)
end
local function v3(v)
	return r(v.X) .. "," .. r(v.Y) .. "," .. r(v.Z)
end
local function cf(c)
	local rx, ry, rz = c:ToEulerAnglesXYZ()
	return v3(c.Position) .. "@" .. r(math.deg(rx)) .. "," .. r(math.deg(ry)) .. "," .. r(math.deg(rz))
end
local function hash(s)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % 4294967296
	end
	return string.format("%08x", h)
end

-- Everything about the three characters except their MeshIds.
local function meshBlindFingerprint()
	local out = {}
	for _, name in { "Pippa", "Cappy", "Prickles" } do
		local model = chars[name]
		local pivot = model:GetPivot()
		local list = {}
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				local extra = { p.Name, v3(p.Size), cf(pivot:ToObjectSpace(p.CFrame)), p.Color:ToHex(), p.Material.Name, r(p.Transparency), p:IsA("MeshPart") and p.TextureID or "" }
				for _, c in p:GetChildren() do
					if c:IsA("SurfaceAppearance") then
						table.insert(extra, "SA:" .. tostring(c.ColorMap) .. tostring(c.NormalMap) .. tostring(c.RoughnessMap))
					elseif c:IsA("Attachment") then
						table.insert(extra, "AT:" .. c.Name .. "=" .. cf(c.CFrame))
					elseif c:IsA("JointInstance") then
						table.insert(extra, "J:" .. c.Name .. "=" .. tostring(c.Part0 and c.Part0.Name) .. ">" .. tostring(c.Part1 and c.Part1.Name) .. "/" .. cf(c.C0) .. "/" .. cf(c.C1))
					elseif c:IsA("WeldConstraint") then
						table.insert(extra, "WC:" .. tostring(c.Part0 and c.Part0.Name) .. ">" .. tostring(c.Part1 and c.Part1.Name))
					elseif c:IsA("BaseWrap") then
						table.insert(extra, "WR:" .. c.ClassName .. "=" .. tostring(c.CageMeshId))
					end
				end
				table.sort(extra)
				table.insert(list, p:GetFullName():sub(#model:GetFullName() + 2) .. "=" .. table.concat(extra, ";"))
			end
		end
		table.sort(list)
		table.insert(out, name .. "|" .. #list .. "|" .. hash(table.concat(list, "\n")))
	end
	return table.concat(out, " ")
end

-- Area-weighted surface centre (share of the box) and total area of a mesh.
local function shape(meshId)
	local em = AS:CreateEditableMeshAsync(Content.fromUri(meshId))
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, v in em:GetVertices() do
		local p = em:GetPosition(v)
		mn, mx = mn:Min(p), mx:Max(p)
	end
	local sum, area = Vector3.zero, 0
	for _, f in em:GetFaces() do
		local vs = em:GetFaceVertices(f)
		local a, b, c = em:GetPosition(vs[1]), em:GetPosition(vs[2]), em:GetPosition(vs[3])
		local w = (b - a):Cross(c - a).Magnitude / 2
		sum += (a + b + c) / 3 * w
		area += w
	end
	em:Destroy()
	local size = mx - mn
	return (sum / area - (mn + mx) / 2) / Vector3.new(math.max(size.X, 1e-3), math.max(size.Y, 1e-3), math.max(size.Z, 1e-3)), area
end

local before = meshBlindFingerprint()
local swaps, notes, loaded = {}, {}, {}
for charName, plan in PLAN do
	local model = chars[charName]
	local new = {}
	for _, id in plan.assets do
		local m = IS:LoadAsset(id)
		table.insert(loaded, m)
		for _, d in m:GetDescendants() do
			if d:IsA("MeshPart") then
				new[d.Name] = d
			end
		end
	end
	for _, name in plan.parts do
		local target
		for _, d in model:GetDescendants() do
			if d:IsA("MeshPart") and d.Name == name then
				target = d
			end
		end
		local src = new[name]
		if target == nil or src == nil or target:GetAttribute("PreDecimateMeshId") ~= nil then
			table.insert(notes, charName .. "." .. name .. " skipped (missing or already done)")
		else
			local oldOffset, oldArea = shape(target.MeshId)
			local newOffset, newArea = shape(src.MeshId)
			local d = oldOffset - newOffset
			if math.abs(d.X) < 0.02 and math.abs(d.Y) < 0.02 and math.abs(d.Z) < 0.02 and math.abs(newArea / oldArea - 1) < 0.05 then
				table.insert(swaps, { target = target, src = src })
			else
				table.insert(notes, string.format("%s.%s REFUSED shape %.3f,%.3f,%.3f area %.3f", charName, name, d.X, d.Y, d.Z, newArea / oldArea))
			end
		end
	end
end
local result
if DRY then
	result = "DRY RUN: " .. #swaps .. " would swap"
else
	local rec = CH:TryBeginRecording("p05 D1 lighter meshes")
	for _, s in swaps do
		local size, frame, texture = s.target.Size, s.target.CFrame, s.target.TextureID
		s.target:SetAttribute("PreDecimateMeshId", s.target.MeshId)
		s.target:ApplyMesh(s.src)
		s.target.Size = size
		s.target.CFrame = frame
		s.target.TextureID = texture
	end
	if rec then
		CH:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end
	local after = meshBlindFingerprint()
	if after ~= before then
		CH:Undo()
		result = "FAILED (undone): something besides the meshes changed\nbefore " .. before .. "\nafter  " .. after
	else
		result = "APPLIED " .. #swaps .. " swaps; mesh-blind fingerprint unchanged: " .. after
	end
end
for _, m in loaded do
	m:Destroy()
end
return result .. "\n" .. table.concat(notes, "\n")
