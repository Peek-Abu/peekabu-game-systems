--!strict
--[=[
	OfficeDressingSystem: floor clutter that varies per run. On the layout's free pile spots (its `pile` markers the
	shift's spawn plan did not use for a pile or an item), OfficeVariationRules.dressing picks some to carry a dried
	Gloom stain (1-3 flat blobs, the ooze palette at 60% opacity, no shadow) or a paper scatter (2-4 white sheets with a
	slight random yaw). Every part is non-colliding, not queried, not touchable. Placement is a pure function of the
	seed and the marker id. A nil seed builds nothing.

	Built under the office model, so a rebuild removes it.

	@class OfficeDressingSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeTypes = require(script.Parent.Parent.Data.OfficeTypes)
local OfficeVariationRules = require(script.Parent.Parent.Rules.OfficeVariationRules)
local OfficeOozeSystem = require(script.Parent.OfficeOozeSystem)
local OfficeSeedUtils = require(ReplicatedStorage.Shared.Features.Office.Utils.OfficeSeedUtils)

local STAIN_OPACITY = 0.6
local STAIN_SPREAD = 1.2
local PAPER_SPREAD = 1.2
local PAPER_SIZE = Vector3.new(1.1, 0.05, 1.5)
local PAPER_YAW = math.rad(35)
-- Sheets rise this much each so two never fight over a plane.
local PAPER_STEP = 0.004

local OfficeDressingSystem = {}

-- A deterministic value in [low, high] for (seed, key).
local function range(seed: number, key: string, low: number, high: number): number
	return low + (high - low) * OfficeSeedUtils.hash01(seed, key)
end

local function inert(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function stain(folder: Folder, seed: number, id: string, at: CFrame)
	local count = 1 + math.floor(range(seed, `stainN:{id}`, 0, 2.999))
	local colors = { OfficeOozeSystem.PALETTE.ink, OfficeOozeSystem.PALETTE.dark }
	for index = 1, count do
		local key = `stain:{id}:{index}`
		local dx = range(seed, key .. "x", -STAIN_SPREAD, STAIN_SPREAD)
		local dz = range(seed, key .. "z", -STAIN_SPREAD, STAIN_SPREAD)
		local frame = at * CFrame.new(dx, 0, dz) * CFrame.Angles(0, range(seed, key .. "r", 0, math.pi), 0)
		local color = colors[1 + math.floor(range(seed, key .. "c", 0, 1.999))]
		local across = range(seed, key .. "w", 1.5, 3.2)
		local deep = range(seed, key .. "d", 1.2, 2.6)
		local part = OfficeOozeSystem.blob(folder, frame, across, deep, color)
		part.Name = "Stain"
		part.Transparency = 1 - STAIN_OPACITY
		inert(part)
	end
end

local function paper(folder: Folder, seed: number, id: string, at: CFrame)
	local count = 2 + math.floor(range(seed, `paperN:{id}`, 0, 2.999))
	for index = 1, count do
		local key = `paper:{id}:{index}`
		local part = Instance.new("Part")
		part.Name = "Paper"
		part.Anchored = true
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.new(1, 1, 1)
		part.Size = PAPER_SIZE
		local dx = range(seed, key .. "x", -PAPER_SPREAD, PAPER_SPREAD)
		local dz = range(seed, key .. "z", -PAPER_SPREAD, PAPER_SPREAD)
		part.CFrame = at
			* CFrame.new(dx, PAPER_SIZE.Y / 2 + index * PAPER_STEP, dz)
			* CFrame.Angles(0, range(seed, key .. "r", -PAPER_YAW, PAPER_YAW), 0)
		inert(part)
		part.Parent = folder
	end
end

--[=[
	Builds the shift's stains and paper under a "Dressing" folder in `parent`, on the layout's `pile` markers not used by
	`plan` (its piles and items), laid out relative to `origin`. Nil when `seed` is nil or nothing was picked.
]=]
function OfficeDressingSystem.build(
	layout: OfficeTypes.Layout,
	plan: OfficeTypes.SpawnPlan,
	seed: number?,
	origin: CFrame,
	parent: Instance
): Folder?
	if seed == nil then
		return nil
	end
	local used: { [string]: boolean } = {}
	for _, pile in plan.piles do
		used[pile.marker] = true
	end
	for _, item in plan.items do
		used[item.marker] = true
	end
	local free: { string } = {}
	local at: { [string]: CFrame } = {}
	for _, marker in layout.markers do
		if marker.kind == "pile" and not used[marker.id] then
			table.insert(free, marker.id)
			at[marker.id] = origin * CFrame.new(marker.x, 0, marker.z)
		end
	end
	local picks = OfficeVariationRules.dressing(seed, free)
	local folder = Instance.new("Folder")
	folder.Name = "Dressing"
	for _, id in free do
		local kind = picks[id]
		local frame = at[id]
		if kind == "stain" then
			stain(folder, seed, id, frame)
		elseif kind == "paper" then
			paper(folder, seed, id, frame)
		end
	end
	if #folder:GetChildren() == 0 then
		folder:Destroy()
		return nil
	end
	folder.Parent = parent
	return folder
end

return OfficeDressingSystem
