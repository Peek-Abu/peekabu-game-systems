--!strict
--[=[
	EmployeeLanyardStrapSystem: builds the v4 fitted ribbon strap on an employee's `UpperTorso`: one `EditableMesh`
	`MeshPart` (`buildStrapMesh`), or, when the editable mesh budget refuses (or for a preview), a chain of plain Parts
	along the fitted runs (`fallbackRibbonParts`). Split out of EmployeeLanyardSystem.

	@class EmployeeLanyardStrapSystem
]=]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeeConstants = require(EmployeeShared.Data.EmployeeConstants)
local EmployeeLanyardConstants = require(EmployeeShared.Data.EmployeeLanyardConstants)
local EmployeeLanyardFormulas = require(EmployeeShared.Utils.EmployeeLanyardFormulas)
local EmployeeLanyardPartUtils = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeeLanyardPartUtils)

type Fit = EmployeeLanyardFormulas.Fit

local v3 = EmployeeLanyardPartUtils.v3
local rgb = EmployeeLanyardPartUtils.rgb
local quiet = EmployeeLanyardPartUtils.quiet

local EmployeeLanyardStrapSystem = {}

function EmployeeLanyardStrapSystem.buildStrapMesh(
	fit: Fit,
	rank: number,
	scale: number,
	ut: BasePart
): (MeshPart?, EditableMesh?)
	local g = EmployeeLanyardFormulas.geometry(fit, EmployeeLanyardFormulas.width(fit, rank), scale)
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, p in g.pos do
		for a = 1, 3 do
			lo[a] = math.min(lo[a], p[a])
			hi[a] = math.max(hi[a], p[a])
		end
	end
	local cx, cy, cz = (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2
	local createdEm: EditableMesh? = nil
	local ok, mp = pcall(function(): MeshPart
		local em = AssetService:CreateEditableMesh()
		createdEm = em
		local ids = table.create(#g.pos)
		for i, p in g.pos do
			ids[i] = em:AddVertex(Vector3.new(p[1] - cx, p[2] - cy, p[3] - cz))
		end
		local col = EmployeeLanyardConstants.COLOURS[rank] or EmployeeLanyardConstants.COLOURS[1]
		local cMain = em:AddColor(rgb(col.main), 1)
		local cEdge = em:AddColor(rgb(col.edge or col.main), 1)
		for t, tri in g.tris do
			local f = em:AddTriangle(ids[tri[1]], ids[tri[2]], ids[tri[3]])
			local c = if g.triBand[t] == 1 then cEdge else cMain
			em:SetFaceColors(f, { c, c, c })
		end
		return AssetService:CreateMeshPartAsync(Content.fromObject(em), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
	end)
	if not ok or not mp then
		if createdEm ~= nil then
			pcall(function()
				createdEm:Destroy()
			end)
		end
		return nil, nil
	end
	mp.Name = EmployeeConstants.LANYARD_STRAP
	mp.Material = Enum.Material.SmoothPlastic
	mp.Color = Color3.new(1, 1, 1)
	quiet(mp)
	mp.CFrame = ut.CFrame * CFrame.new(cx, cy, cz)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = ut, mp
	w.Parent = mp
	return mp, createdEm
end

-- Synchronous 3D part-ribbon fallback along the fitted stations: renders in both Workspace and ViewportFrames even
-- when EditableMesh is disabled in Experience Settings -> Security. One Part per straight run within `tolerance` studs
-- of the fitted strap (EmployeeLanyardFormulas.ribbonRuns), not one per station: 96 Parts became 8-67.
function EmployeeLanyardStrapSystem.fallbackRibbonParts(
	fit: Fit,
	rank: number,
	scale: number,
	ut: BasePart,
	parent: Instance,
	tolerance: number
)
	local rb = fit.ribbon
	local col = EmployeeLanyardConstants.COLOURS[rank] or EmployeeLanyardConstants.COLOURS[1]
	local color = rgb(col.main)
	local width = EmployeeLanyardFormulas.width(fit, rank)
	local w = width * scale
	local thickness = math.max(0.012, EmployeeLanyardConstants.STRAP_T * scale * 2)
	for _, run in EmployeeLanyardFormulas.ribbonRuns(fit, width, tolerance) do
		local i, j = run[1], run[2]
		local p0 = (v3(rb.centre[i]) + v3(rb.offset[i][3])) * scale
		local p1 = (v3(rb.centre[j]) + v3(rb.offset[j][3])) * scale
		local delta = p1 - p0
		local len = delta.Magnitude
		if len > 1e-4 then
			local mid = (p0 + p1) * 0.5
			local nrm = (v3(rb.normal[i]) + v3(rb.normal[j])).Unit
			local tan = delta / len
			local bin = tan:Cross(nrm)
			if bin.Magnitude < 1e-4 then
				bin = v3(rb.binormal[i]).Unit
			else
				bin = bin.Unit
			end
			local trueNrm = bin:Cross(tan).Unit
			local seg = Instance.new("Part")
			seg.Name = EmployeeConstants.LANYARD_STRAP
			seg.Material = Enum.Material.SmoothPlastic
			seg.Color = color
			seg.Size = Vector3.new(w, thickness, len + 0.008 * scale)
			quiet(seg)
			seg.CFrame = ut.CFrame * CFrame.fromMatrix(mid + trueNrm * (thickness * 0.5), bin, trueNrm, -tan)
			local wc = Instance.new("WeldConstraint")
			wc.Part0, wc.Part1 = ut, seg
			wc.Parent = seg
			seg.Parent = parent
		end
	end
end

return EmployeeLanyardStrapSystem
