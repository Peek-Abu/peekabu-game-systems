--!strict
--[=[
	DepotTopperRules: where a station's topper, light pool and floor lane go, and what the look outline wraps
	(DepotSpotConstants.TOPPER; owner 11-12, kit mock round 2 #1, ideas #5 and #6). Pure: CFrames and numbers in, out.

	@class DepotTopperRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local TimecardConstants = require(ReplicatedStorage.Shared.Features.Timecard.Data.TimecardConstants)

local TOPPER = DepotSpotConstants.TOPPER
local LANE = TOPPER.LANE
local POOL = TOPPER.POOL

-- The station each hub interaction kind belongs to (a key of DepotTopperConstants.STATIONS).
local STATION_OF: { [string]: string } = {
	[DepotSpotConstants.KINDS.shop] = "shop",
	[DepotSpotConstants.KINDS.coffee] = "coffee",
	[DepotSpotConstants.KINDS.crew] = "crew",
	[DepotSpotConstants.KINDS.rank] = "rank",
	[DepotSpotConstants.KINDS.radio] = "radio",
	[DepotSpotConstants.KINDS.bell] = "bell",
	[DepotSpotConstants.KINDS.locker] = "locker",
	[TimecardConstants.CLOCK_KIND] = "clock",
	[TimecardConstants.DAILY_KIND] = "daily",
}

-- A hit box this see-through is invisible, so the outline wraps what it stands for instead.
local HIT_BOX_TRANSPARENCY = 0.99

local DepotTopperRules = {}

-- The anchor's facing on the floor (its pitch dropped); +Z when it faces straight up or down.
local function flat(anchor: CFrame): Vector3
	local look = anchor.LookVector
	local level = Vector3.new(look.X, 0, look.Z)
	return if level.Magnitude > 1e-6 then level.Unit else Vector3.zAxis
end

--[=[
	The lane in front of the station whose topper anchor is `anchor`: its CFrame (flat, its LookVector running away
	from the station) and size, lying on the floor at `floorY`, from `start` studs ahead of the anchor for `length`
	studs (the LANE defaults when nil).
]=]
function DepotTopperRules.lane(anchor: CFrame, floorY: number, start: number?, length: number?): (CFrame, Vector3)
	local from = start or LANE.START
	local long = length or LANE.LENGTH
	local ahead = flat(anchor)
	local base = Vector3.new(anchor.Position.X, floorY + LANE.LIFT + LANE.THICKNESS / 2, anchor.Position.Z)
	local centre = base + ahead * (from + long / 2)
	return CFrame.lookAt(centre, centre + ahead), Vector3.new(LANE.WIDTH, LANE.THICKNESS, long)
end

-- A chevron's arm: its length and thickness against the lane's width, and its angle off the lane's line.
local ARM_SHARE = 0.42
local ARM_WIDTH = 0.12
local ARM_ANGLE = math.rad(42)

--[=[
	The chevrons on a lane (`lane`, `size` from DepotTopperRules.lane): LANE.CHEVRONS of them spread along it, each
	two flat bars meeting at a point aimed back up the lane at the station (the way a player walks). Returns every
	bar's CFrame (left then right, chevron by chevron from the station end) and the bars' size.
]=]
function DepotTopperRules.chevrons(lane: CFrame, size: Vector3): ({ CFrame }, Vector3)
	local arm = size.X * ARM_SHARE
	local barSize = Vector3.new(ARM_WIDTH, LANE.THICKNESS, arm)
	-- In the lane's own space -Z runs away from the station (its LookVector) and +Z back towards it; the bars lie on
	-- its top face.
	local y = size.Y / 2 + LANE.THICKNESS / 2
	local reach = arm * math.cos(ARM_ANGLE)
	local bars: { CFrame } = {}
	for index = 1, LANE.CHEVRONS do
		-- The tip, set back so the whole chevron stays inside its share of the lane.
		local share = (index - 0.5) / LANE.CHEVRONS
		local tipZ = size.Z / 2 - share * size.Z + reach / 2
		for _, side in { -1, 1 } do
			local direction = Vector3.new(side * math.sin(ARM_ANGLE), 0, -math.cos(ARM_ANGLE))
			local centre = Vector3.new(0, y, tipZ) + direction * (arm / 2)
			table.insert(bars, lane * CFrame.lookAt(centre, centre + direction))
		end
	end
	return bars, barSize
end

--[=[
	The light pool's range for a topper at height `anchorY` over a floor at `floorY`: down to the floor and REACH
	past it, at least MIN_RANGE.
]=]
function DepotTopperRules.poolRange(anchorY: number, floorY: number): number
	return math.max(POOL.MIN_RANGE, anchorY - floorY + POOL.REACH)
end

--[=[
	A topper standing on a sign shell's part (`shell` its CFrame, `size` its size): its canvas bottom SHELL_GAP above
	the part's top, facing the way the part's drawn `face` looks.
]=]
function DepotTopperRules.onShell(shell: CFrame, size: Vector3, face: Enum.NormalId): CFrame
	local normal = shell:VectorToWorldSpace(Vector3.FromNormalId(face))
	local up = shell.UpVector
	local centre = shell.Position + up * (size.Y / 2 + TOPPER.SHELL_GAP + TOPPER.PLATE.Y / 2)
	return CFrame.lookAt(centre, centre + normal, up)
end

--[=[
	The station an interaction `kind` belongs to (a key of DepotTopperConstants.STATIONS), or nil for anything that
	is not a hub station.
]=]
function DepotTopperRules.station(kind: string?): string?
	return if kind ~= nil then STATION_OF[kind] else nil
end

--[=[
	What the look outline wraps for an interactable `target`: the target itself, unless it is an invisible hit box
	inside a model (a rank chart's spot part), then that model.
]=]
function DepotTopperRules.outlineOf(target: Instance): Instance
	if target:IsA("BasePart") and target.Transparency >= HIT_BOX_TRANSPARENCY then
		local parent = target.Parent
		if parent ~= nil and parent:IsA("Model") then
			return parent
		end
	end
	return target
end

return DepotTopperRules
