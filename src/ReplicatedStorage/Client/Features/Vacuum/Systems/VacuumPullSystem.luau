--!strict
--[=[
	VacuumPullSystem: how a dust pile looks on this client while it is vacuumed (vacuum feel pass 2026-11-06, P1
	2026-11-14; visual only, the server's pile, its shrink and the suction are untouched; VacuumFeelFormulas decides
	the shapes).

	While a pile is sucked (VacuumFeedbackSystem calls `follow` every frame with the nozzle and the progress), this client
	hides the real pile and shows a stand-in in its place: a copy of its art (the pile's ArtVisual under its
	VacuumConstants.PILE_ART_HOST, its pieces laid about the art's floor point), or of the block where the place has no
	art. The stand-in leans toward the nozzle about its base, stretches up and thins, and wobbles, more as it nears
	done; each tug (`tug`, a puff of goo) hops it on a spring. Its size glides toward the server's (P1: the server
	shrinks the block in 0.1 s steps and keeps the art at full size, VacuumPileArtSystem), so the pile shrinks smoothly.
	Into the nozzle (P1 v2 2026-11-15): an art pile also turns so a flat side faces the nozzle and stretches toward
	it about its back, its front pulled at the mouth, more as it nears done (VacuumFeelFormulas.pulledPiece), and goo
	blobs tear off it and swirl into the nozzle (VacuumAirSystem.tear), more at each tug.
	When the suction stops (`release`) the stand-in springs back upright; a block's then goes and the real block shows,
	while an art pile's stays at the pile's size (the server's art is full size). `track` gives a pile that is already
	partly vacuumed (seen late, or let go) its stand-in. When the real pile is gone (popped) the stand-in goes at once.

	Spec-exempt shell (Instances, RunService); the shapes are the specced VacuumFeelFormulas.

	@class VacuumPullSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VacuumAirSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumAirSystem)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumFeelFormulas = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumFeelFormulas)
local VacuumMotionFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMotionFormulas)

type Spring = { x: number, v: number }

-- One piece of an art stand-in: its frame about the art's floor point and its size, both at full size.
type Piece = { part: BasePart, frame: CFrame, size: Vector3 }

type Pull = {
	pile: BasePart,
	copy: Instance,
	-- An art stand-in's pieces and the art's floor point (nil for a block's).
	pieces: { Piece }?,
	floor: CFrame?,
	-- The real parts hidden on this client while the stand-in shows.
	hidden: { BasePart },
	nozzle: Vector3?,
	progress: number,
	held: boolean,
	lean: Spring,
	hop: Spring,
	-- The shown scale (1 = full size), gliding toward the server's.
	shown: Spring,
	seed: number,
	-- The direction it leans (flat, unit), kept after the suction stops so it settles back the same way.
	toward: Vector3,
	-- Laid at rest at the server's size (nothing to move until something changes).
	still: boolean,
	-- Into the nozzle (P1 v2): the art's turn (radians) so a flat side faces the nozzle, and its stretch toward it.
	yaw: Spring,
	along: Spring,
	-- When the last goo blob tore off it (os.clock).
	toreAt: number,
}

local LEAN_HZ, LEAN_DAMPING = 3.2, 0.55
local HOP_HZ, HOP_DAMPING = 5, 0.35
local HOP_IMPULSE = 14
-- Below this lean and hop a released stand-in is settled.
local SETTLED = 0.01
-- A pile this close to full size needs no stand-in once let go.
local FULL = 0.999
-- Into the nozzle: the turn's and the stretch's springs.
local YAW_HZ, YAW_DAMPING = 2.5, 0.8
local ALONG_HZ, ALONG_DAMPING = 2.6, 0.6
-- A goo blob tears off a sucked pile this often (s), from this share of its height; a tug tears off this many more.
local TEAR_EVERY = 0.14
local TEAR_HEIGHT = 0.6
local TUG_BLOBS = 2

local pulls: { [BasePart]: Pull } = {}
local folder: Folder? = nil
local connection: RBXScriptConnection? = nil

local VacuumPullSystem = {}

local function ease(s: Spring, target: number, dt: number, frequency: number, damping: number): number
	s.x, s.v = VacuumMotionFormulas.step(s.x, s.v, target, dt, frequency, damping)
	return s.x
end

-- The pile's art (its ArtVisual under its host) and the art's floor point, or nil where the place has none.
local function artOf(pile: BasePart): (Model?, CFrame?)
	local host = pile:FindFirstChild(VacuumConstants.PILE_ART_HOST)
	if host == nil or not host:IsA("BasePart") then
		return nil, nil
	end
	local visual = host:FindFirstChild("ArtVisual")
	if visual == nil or not visual:IsA("Model") then
		return nil, nil
	end
	return visual, host.CFrame * CFrame.new(0, -host.Size.Y / 2, 0)
end

-- The pile's scale now (1 = full size), from the server's size and its recorded full size.
local function targetOf(pile: BasePart): number
	local base = pile:GetAttribute(VacuumConstants.BASE_SIZE_ATTRIBUTE)
	return VacuumFeelFormulas.pileScale(pile.Size, if typeof(base) == "Vector3" then base else nil)
end

-- A client-only copy that nothing touches, collides with or queries.
local function inert(part: BasePart)
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	for _, tag in part:GetTags() do
		part:RemoveTag(tag)
	end
end

-- The stand-in for `pile` (its art's copy, else the block's), its pieces and floor point, and the real parts it hides.
local function standIn(pile: BasePart, parent: Instance): (Instance, { Piece }?, CFrame?, { BasePart })
	local visual, floor = artOf(pile)
	if visual ~= nil and floor ~= nil then
		local copy = visual:Clone()
		copy.Name = "PullStandIn"
		local pieces: { Piece } = {}
		for _, child in copy:GetDescendants() do
			if child:IsA("JointInstance") or child:IsA("WeldConstraint") or child:IsA("Constraint") then
				-- Its welds still name the real host: a client copy must never be joined to it.
				child:Destroy()
			elseif child:IsA("BasePart") then
				inert(child)
				table.insert(pieces, { part = child, frame = floor:ToObjectSpace(child.CFrame), size = child.Size })
			end
		end
		local hidden: { BasePart } = {}
		for _, child in visual:GetDescendants() do
			if child:IsA("BasePart") then
				child.LocalTransparencyModifier = 1
				table.insert(hidden, child)
			end
		end
		copy.Parent = parent
		return copy, pieces, floor, hidden
	end
	local copy = pile:Clone()
	copy.Name = "PullStandIn"
	copy:ClearAllChildren()
	inert(copy)
	copy.Parent = parent
	pile.LocalTransparencyModifier = 1
	return copy, nil, nil, { pile }
end

-- Makes `pile`'s stand-in at the pile's size now (none before `start`).
local function make(pile: BasePart, held: boolean): Pull?
	local parent = folder
	if parent == nil then
		return nil
	end
	local copy, pieces, floor, hidden = standIn(pile, parent)
	local pull: Pull = {
		pile = pile,
		copy = copy,
		pieces = pieces,
		floor = floor,
		hidden = hidden,
		nozzle = nil,
		progress = 0,
		held = held,
		lean = { x = 0, v = 0 },
		hop = { x = 0, v = 0 },
		shown = { x = targetOf(pile), v = 0 },
		seed = (math.abs(pile.Position.X * 13.7 + pile.Position.Z * 7.3)) % 6.28,
		toward = Vector3.new(0, 0, -1),
		still = false,
		yaw = { x = 0, v = 0 },
		along = { x = 1, v = 0 },
		toreAt = 0,
	}
	pulls[pile] = pull
	return pull
end

local function remove(pull: Pull)
	pull.copy:Destroy()
	for _, part in pull.hidden do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = 0
		end
	end
	pulls[pull.pile] = nil
end

-- A goo blob tears off `pull`'s pile (from up its middle) and swirls into the nozzle it is sucked by.
local function tear(pull: Pull)
	if pull.nozzle == nil then
		return
	end
	local pile = pull.pile
	local height = pile.Size.Y
	local pieces = pull.pieces
	if pieces ~= nil then
		height = 0
		for _, piece in pieces do
			height = math.max(height, piece.part.Size.Y)
		end
	end
	local from = pile.Position - Vector3.new(0, pile.Size.Y / 2, 0) + Vector3.new(0, height * TEAR_HEIGHT, 0)
	pull.toreAt = os.clock()
	VacuumAirSystem.tear(from, function()
		return pull.nozzle
	end)
end

local function place(pull: Pull, dt: number)
	local pile = pull.pile
	local target = targetOf(pile)
	if pull.still and math.abs(pull.shown.x - target) < 1e-3 then
		return
	end
	local nozzle = pull.nozzle
	local base = pile.Position - Vector3.new(0, pile.Size.Y / 2, 0)
	if pull.held and nozzle ~= nil then
		local flat = Vector3.new(nozzle.X - base.X, 0, nozzle.Z - base.Z)
		if flat.Magnitude > 0.05 then
			pull.toward = flat.Unit
		end
	end
	local distance = if nozzle ~= nil then (nozzle - base).Magnitude else math.huge
	if pull.held and nozzle ~= nil and os.clock() - pull.toreAt >= TEAR_EVERY then
		tear(pull)
	end
	local leanTarget = if pull.held then VacuumFeelFormulas.lean(distance, pull.progress) else 0
	local lean = ease(pull.lean, leanTarget, dt, LEAN_HZ, LEAN_DAMPING)
	local hop = ease(pull.hop, 0, dt, HOP_HZ, HOP_DAMPING)
	pull.shown.x, pull.shown.v = VacuumFeelFormulas.shrinkTo(pull.shown.x, pull.shown.v, target, dt)
	local shown = pull.shown.x
	local wobble = if pull.held then VacuumFeelFormulas.wobble(os.clock(), pull.seed, pull.progress) else 0
	local up, across = VacuumFeelFormulas.stretch(if pull.held then pull.progress else 0, hop)
	-- Leaning toward the nozzle is a turn about the horizontal axis across that direction.
	local axis = Vector3.new(0, 1, 0):Cross(pull.toward)
	if axis.Magnitude < 1e-3 then
		axis = Vector3.xAxis
	end
	local tilt = CFrame.fromAxisAngle(axis.Unit, lean) * CFrame.fromAxisAngle(pull.toward, wobble)
	local pieces, floor, copy = pull.pieces, pull.floor, pull.copy
	local alongSettled = true
	if pieces ~= nil and floor ~= nil then
		-- Into the nozzle: turned so a flat side faces it, stretched toward it about its back.
		local yawTarget = 0
		if pull.held then
			yawTarget = pull.yaw.x
				+ VacuumFeelFormulas.alignYaw(CFrame.Angles(0, pull.yaw.x, 0) * floor.Rotation, pull.toward)
		end
		local yaw = ease(pull.yaw, yawTarget, dt, YAW_HZ, YAW_DAMPING)
		local alongTarget = if pull.held then VacuumFeelFormulas.reach(pull.progress, distance) else 1
		local along = math.max(ease(pull.along, alongTarget, dt, ALONG_HZ, ALONG_DAMPING), 0.5)
		local turn = CFrame.Angles(0, yaw, 0) * floor.Rotation
		local back = 0
		for _, piece in pieces do
			local rotation = turn * piece.frame.Rotation
			local reach = VacuumFeelFormulas.extentAlong(rotation, piece.size, pull.toward)
			back = math.max(back, reach - (turn * piece.frame.Position):Dot(pull.toward))
		end
		for _, piece in pieces do
			local frame, size = VacuumFeelFormulas.pulledPiece(
				floor,
				tilt,
				yaw,
				piece.frame,
				piece.size,
				shown,
				up,
				across,
				pull.toward,
				along,
				back
			)
			piece.part.CFrame = frame
			piece.part.Size = size
		end
		alongSettled = math.abs(along - 1) < SETTLED and math.abs(yaw) < SETTLED
	elseif copy:IsA("BasePart") then
		-- The block at the shown share of its size (the server's size now, carried back to the glide's scale).
		local size = pile.Size * (if target > 0 then shown / target else 1)
		size = Vector3.new(size.X * across, size.Y * up, size.Z * across)
		copy.Size = size
		copy.CFrame = CFrame.new(base) * tilt * CFrame.new(0, size.Y / 2, 0) * pile.CFrame.Rotation
	end
	local settled = not pull.held
		and alongSettled
		and math.abs(lean) < SETTLED
		and math.abs(hop) < SETTLED
		and math.abs(shown - target) < 1e-3
	pull.still = settled
	if settled and (pieces == nil or target >= FULL) then
		remove(pull)
	end
end

local function step(dt: number)
	for pile, pull in pulls do
		if pile.Parent == nil then
			pull.copy:Destroy()
			pulls[pile] = nil
		elseif pull.pieces == nil and artOf(pile) ~= nil then
			-- The art streamed in after the stand-in was made from the block: remake it from the art.
			local held, nozzle, progress = pull.held, pull.nozzle, pull.progress
			remove(pull)
			local remade = make(pile, held)
			if remade ~= nil then
				remade.nozzle, remade.progress = nozzle, progress
			end
		else
			place(pull, math.min(dt, 0.1))
		end
	end
end

--[=[
	`pile` is being sucked this frame by a nozzle at `nozzle` (nil: none in reach), `progress` (0..1) along.
]=]
function VacuumPullSystem.follow(pile: BasePart, nozzle: Vector3?, progress: number)
	local pull = pulls[pile] or make(pile, true)
	if pull == nil then
		return
	end
	pull.nozzle = nozzle
	pull.progress = progress
	pull.held = true
	pull.still = false
end

--[=[
	`pile` exists on this client, or its progress changed: one already partly vacuumed gets its stand-in at its size,
	so its full-size art never shows (a plain block already shows its own size).
]=]
function VacuumPullSystem.track(pile: BasePart)
	if pulls[pile] ~= nil or targetOf(pile) >= FULL or artOf(pile) == nil then
		return
	end
	make(pile, false)
end

--[=[
	The suction on `pile` stopped: its stand-in settles back (and a block's goes).
]=]
function VacuumPullSystem.release(pile: BasePart)
	local pull = pulls[pile]
	if pull ~= nil then
		pull.held = false
		pull.still = false
	end
end

--[=[
	A tug on `pile` (a puff of goo leaving it): its stand-in hops.
]=]
function VacuumPullSystem.tug(pile: BasePart)
	local pull = pulls[pile]
	if pull ~= nil then
		pull.hop.v += HOP_IMPULSE
		pull.still = false
		for _ = 1, TUG_BLOBS do
			tear(pull)
		end
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
