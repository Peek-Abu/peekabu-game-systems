--!nonstrict
-- ProbeDeskDrawers.CommandBar.luau: Task 9 probe of the kit desk (Studio Edit, Shift place, after AssembleKit).
-- Attaches ArtKits["odd-hours-b1"].furniture.desk to a DESK_SIZE proxy through ArtVisualSystem (Stretch fit), then:
--   1. hide space: every HUG_FREE_MIN placement under the fitted art (all MeshParts' faces as boxes, drawers closed);
--   2. the search: OfficeSearchedDressingSystem.apply keeps the same ArtVisual, adds no fallback, slides each tagged drawer;
--   3. poke-through: drawer faces vs body faces at slide 0, 0.25, 0.5, 0.75, 1 (only contacts already there when
--      closed are allowed; none when open), and each open drawer's back still inside the pedestal.
-- Everything it makes is destroyed at the end. Prints one PROBE line.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local AssetService = game:GetService("AssetService")
local ArtVisualSystem = require(RS.Shared.Features.Art.Systems.ArtVisualSystem:Clone())
local Dressing = require(SSS.Features.Office.Systems.OfficeSearchedDressingSystem:Clone())
local OfficeConstants = require(SSS.Features.Office.Data.OfficeConstants:Clone())
local DESK_SIZE = OfficeConstants.DESK_SIZE
local HUG = Vector3.new(3.6, 4.2, 4.3) -- HideConstants.HUG_FREE_MIN
local TOL = 0.005

local folder = Instance.new("Folder")
folder.Name = "DeskDrawerProbe"
folder.Parent = workspace
local root = Instance.new("Part")
root.Name = "Desk"
root.Size = DESK_SIZE
root.CFrame = CFrame.new(5000, 300 + DESK_SIZE.Y / 2, 5000)
root.Anchored = true
root.Transparency = 1
root.Parent = folder

local ok, result = pcall(function()
	local template = RS.Assets.CleanupCrew.ArtKits["odd-hours-b1"].furniture.desk
	local tagged = 0
	for _, p in template:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("SearchComponent") == "drawer" then
			tagged += 1
		end
	end
	local art = ArtVisualSystem.attach(root, "furniture", "desk", "odd-hours-b1")
	assert(art, "attach returned nil")
	-- face boxes in the root's object space, floor-up (y = 0 at the proxy floor)
	local function faces(mp)
		local em = AssetService:CreateEditableMeshAsync(Content.fromUri(mp.MeshId))
		local vlo, vhi
		for _, vid in em:GetVertices() do
			local q = em:GetPosition(vid)
			vlo = vlo and vlo:Min(q) or q
			vhi = vhi and vhi:Max(q) or q
		end
		local k, c = mp.Size / (vhi - vlo), (vlo + vhi) / 2
		local rel = root.CFrame:ToObjectSpace(mp.CFrame)
		local list = {}
		for _, fid in em:GetFaces() do
			local lo, hi
			for _, vid in em:GetFaceVertices(fid) do
				local p = rel:PointToWorldSpace((em:GetPosition(vid) - c) * k) + Vector3.new(0, DESK_SIZE.Y / 2, 0)
				lo = lo and lo:Min(p) or p
				hi = hi and hi:Max(p) or p
			end
			table.insert(list, { lo, hi })
		end
		em:Destroy()
		return list
	end
	local body, drawers = {}, {}
	local drawerParts = {}
	for _, mp in art:GetDescendants() do
		if mp:IsA("MeshPart") then
			if mp:GetAttribute("SearchComponent") == "drawer" then
				table.insert(drawerParts, mp)
				drawers[mp] = faces(mp)
			else
				for _, f in faces(mp) do
					table.insert(body, f)
				end
			end
		end
	end
	local function hit(a, b, ox)
		return a[1].X < b[2].X - TOL and a[2].X > b[1].X + TOL and a[1].Y < b[2].Y - TOL and a[2].Y > b[1].Y + TOL
			and a[1].Z + ox < b[2].Z - TOL and a[2].Z + ox > b[1].Z + TOL
	end
	-- 1. hide space (drawers closed)
	local all = table.clone(body)
	for _, list in drawers do
		for _, f in list do
			table.insert(all, f)
		end
	end
	local function free(centre, size)
		local box = { centre - size / 2, centre + size / 2 }
		for _, f in all do
			if hit(f, box, 0) then
				return false
			end
		end
		return true
	end
	local placements, xr = 0, { math.huge, -math.huge }
	for x = -DESK_SIZE.X / 2 + HUG.X / 2, DESK_SIZE.X / 2 - HUG.X / 2 + 1e-3, 0.25 do
		for z = -DESK_SIZE.Z / 2 + HUG.Z / 2, DESK_SIZE.Z / 2 - HUG.Z / 2 + 1e-3, 0.05 do
			if free(Vector3.new(x, HUG.Y / 2, z), HUG) then
				placements += 1
				xr = { math.min(xr[1], x), math.max(xr[2], x) }
			end
		end
		task.wait()
	end
	-- 2. the search
	local before = {}
	for _, d in drawerParts do
		before[d] = root.CFrame:ToObjectSpace(d.CFrame).Position
	end
	local dressing = Dressing.new(0)
	dressing.apply(root, "desk")
	local slide = DESK_SIZE.Z * 0.45
	local moved = 0
	for _, d in drawerParts do
		local p = root.CFrame:ToObjectSpace(d.CFrame).Position
		if math.abs(p.Z - (before[d].Z - slide)) < 1e-3 and math.abs(p.X - before[d].X) < 1e-3 then
			moved += 1
		end
	end
	local sameArt = root:FindFirstChild("ArtVisual") == art
	local fallback = root:FindFirstChild("SearchedDressing") ~= nil
	dressing.clear()
	-- 3. poke-through along the slide (pairs already touching when closed are the fronts' 0.04 seat in the shell edge)
	local newHits, openHits, closedPairs, minBackInside = 0, 0, 0, math.huge
	for _, d in drawerParts do
		local list = drawers[d]
		local lo, hi = list[1][1], list[1][2]
		for _, f in list do
			lo, hi = lo:Min(f[1]), hi:Max(f[2])
		end
		local near = {}
		for _, b in body do
			if hit({ lo - Vector3.new(0, 0, slide), hi }, b, 0) then
				table.insert(near, b)
			end
		end
		local closedSet = {}
		for i, f in list do
			for j, b in near do
				if hit(f, b, 0) then
					closedSet[i * 100000 + j] = true
					closedPairs += 1
				end
			end
		end
		for _, frac in { 0.25, 0.5, 0.75, 1 } do
			for i, f in list do
				for j, b in near do
					if hit(f, b, -slide * frac) then
						if frac == 1 then
							openHits += 1
						end
						if not closedSet[i * 100000 + j] then
							newHits += 1
						end
					end
				end
			end
			task.wait()
		end
		minBackInside = math.min(minBackInside, (hi.Z - slide) - (-DESK_SIZE.Z / 2))
	end
	return ("PROBE desk: tagged=%d moved=%d/%d sameArt=%s fallback=%s | HUG_FREE_MIN after Stretch: %d placements (x %.2f..%.2f) | slide %.3f: new contacts while sliding=%d, contacts when open=%d (closed seat contacts %d), open drawer backs >= %.2f inside the front"):format(
		tagged,
		moved,
		#drawerParts,
		tostring(sameArt),
		tostring(fallback),
		placements,
		xr[1],
		xr[2],
		slide,
		newHits,
		openHits,
		closedPairs,
		minBackInside
	)
end)
folder:Destroy()
local line = ok and result or ("PROBE ERROR: " .. tostring(result))
print(line)
return line
