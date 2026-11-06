--!strict
--[=[
	VacuumPullSystem: piles fight the suction on this client (vacuum feel pass 2026-11-06; visual only, the server's
	pile, its shrink and the suction are untouched; VacuumFeelFormulas decides the shape).

	While a pile is sucked (VacuumFeedbackSystem calls `follow` every frame with the nozzle and the progress), this client
	hides the real pile (LocalTransparencyModifier) and shows a stand-in in its place: the same part, following the
	server's size and spot each frame, leaned toward the nozzle about its base, stretched up and thinned, and wobbling,
	more as it nears done. Each tug (`tug`, a puff of goo) hops it on a spring. When the suction stops (`release`) the
	stand-in springs back upright and is removed, and the real pile shows again; when the real pile is gone (popped) the
	stand-in goes with it at once.

	Spec-exempt shell (Instances, RunService); the shapes are the specced VacuumFeelFormulas.

	@class VacuumPullSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VacuumFeelFormulas = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumFeelFormulas)
local VacuumMotionFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMotionFormulas)

type Spring = { x: number, v: number }

type Pull = {
	pile: BasePart,
	copy: BasePart,
	nozzle: Vector3?,
	progress: number,
	held: boolean,
	lean: Spring,
	hop: Spring,
	seed: number,
	-- The direction it leans (flat, unit), kept after the suction stops so it settles back the same way.
	toward: Vector3,
}

local LEAN_HZ, LEAN_DAMPING = 3.2, 0.55
local HOP_HZ, HOP_DAMPING = 5, 0.35
local HOP_IMPULSE = 14
-- Below this lean and hop a released stand-in is removed.
local SETTLED = 0.01

local pulls: { [BasePart]: Pull } = {}
local folder: Folder? = nil
local connection: RBXScriptConnection? = nil

local VacuumPullSystem = {}

local function ease(s: Spring, target: number, dt: number, frequency: number, damping: number): number
	s.x, s.v = VacuumMotionFormulas.step(s.x, s.v, target, dt, frequency, damping)
	return s.x
end

local function remove(pull: Pull)
	pull.copy:Destroy()
	if pull.pile.Parent ~= nil then
		pull.pile.LocalTransparencyModifier = 0
	end
	pulls[pull.pile] = nil
end

local function place(pull: Pull, dt: number)
	local pile, copy = pull.pile, pull.copy
	local nozzle = pull.nozzle
	local base = pile.Position - Vector3.new(0, pile.Size.Y / 2, 0)
	if pull.held and nozzle ~= nil then
		local flat = Vector3.new(nozzle.X - base.X, 0, nozzle.Z - base.Z)
		if flat.Magnitude > 0.05 then
			pull.toward = flat.Unit
		end
	end
	local distance = if nozzle ~= nil then (nozzle - base).Magnitude else math.huge
	local leanTarget = if pull.held then VacuumFeelFormulas.lean(distance, pull.progress) else 0
	local lean = ease(pull.lean, leanTarget, dt, LEAN_HZ, LEAN_DAMPING)
	local hop = ease(pull.hop, 0, dt, HOP_HZ, HOP_DAMPING)
	local wobble = if pull.held then VacuumFeelFormulas.wobble(os.clock(), pull.seed, pull.progress) else 0
	local up, across = VacuumFeelFormulas.stretch(if pull.held then pull.progress else 0, hop)
	-- Leaning toward the nozzle is a turn about the horizontal axis across that direction.
	local axis = Vector3.new(0, 1, 0):Cross(pull.toward)
	if axis.Magnitude < 1e-3 then
		axis = Vector3.xAxis
	end
	local tilt = CFrame.fromAxisAngle(axis.Unit, lean) * CFrame.fromAxisAngle(pull.toward, wobble)
	local size = Vector3.new(pile.Size.X * across, pile.Size.Y * up, pile.Size.Z * across)
	copy.Size = size
	copy.CFrame = CFrame.new(base) * tilt * CFrame.new(0, size.Y / 2, 0) * pile.CFrame.Rotation
	if not pull.held and math.abs(lean) < SETTLED and math.abs(hop) < SETTLED then
		remove(pull)
	end
end

local function step(dt: number)
	for pile, pull in pulls do
		if pile.Parent == nil then
			pull.copy:Destroy()
			pulls[pile] = nil
		else
			place(pull, math.min(dt, 0.1))
		end
	end
end

--[=[
	`pile` is being sucked this frame by a nozzle at `nozzle` (nil: none in reach), `progress` (0..1) along.
]=]
function VacuumPullSystem.follow(pile: BasePart, nozzle: Vector3?, progress: number)
	local pull = pulls[pile]
	if pull == nil then
		local parent = folder
		if parent == nil then
			return
		end
		local copy = pile:Clone()
		copy.Name = "PullStandIn"
		copy:ClearAllChildren()
		copy.Anchored, copy.CanCollide, copy.CanQuery, copy.CanTouch = true, false, false, false
		for _, tag in copy:GetTags() do
			copy:RemoveTag(tag)
		end
		copy.Parent = parent
		pile.LocalTransparencyModifier = 1
		pull = {
			pile = pile,
			copy = copy,
			nozzle = nozzle,
			progress = progress,
			held = true,
			lean = { x = 0, v = 0 },
			hop = { x = 0, v = 0 },
			seed = (math.abs(pile.Position.X * 13.7 + pile.Position.Z * 7.3)) % 6.28,
			toward = Vector3.new(0, 0, -1),
		}
		pulls[pile] = pull
	end
	pull.nozzle = nozzle
	pull.progress = progress
	pull.held = true
end

--[=[
	The suction on `pile` stopped: its stand-in settles back and goes.
]=]
function VacuumPullSystem.release(pile: BasePart)
	local pull = pulls[pile]
	if pull ~= nil then
		pull.held = false
	end
end

--[=[
	A tug on `pile` (a puff of goo leaving it): its stand-in hops.
]=]
function VacuumPullSystem.tug(pile: BasePart)
	local pull = pulls[pile]
	if pull ~= nil then
		pull.hop.v += HOP_IMPULSE
	end
end

function VacuumPullSystem.start()
	if connection ~= nil then
		return
	end
	local made = Instance.new("Folder")
	made.Name = "VacuumPull"
	made.Parent = Workspace
	folder = made
	connection = RunService.RenderStepped:Connect(step)
end

function VacuumPullSystem.stop()
	local current = connection
	if current ~= nil then
		current:Disconnect()
	end
	connection = nil
	for _, pull in pulls do
		remove(pull)
	end
	table.clear(pulls)
	local current2 = folder
	if current2 ~= nil then
		current2:Destroy()
	end
	folder = nil
end

return VacuumPullSystem
