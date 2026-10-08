--!strict
--[=[
	CollisionBlockerSystem (R6 spec 2026-10-08 §4, §5): the capsules.

	- Each other player's puppet gets a capsule (three primitive parts) welded into its anchored root
	  assembly, so the puppet's existing BulkMoveTo carries it: R6 writes no CFrames. It starts not solid.
	- The local rig gets the same capsule as its self-collider: solid, massless, welded to its root.
	- The connection is the spike's measured `puppet` mount: place the part at `root.CFrame * offset`,
	  unanchor it, WeldConstraint root → part, parent it into the rig. Placing first makes the weld's offset
	  exact wherever the root is (a pooled puppet parked far away included).
	- `step` checks the range RANGE_CHECK_HZ times a second with the buffer band and
	  writes `CanCollide` only on a flip.
	- Other players are immovable (no contact velocity): developer decision 2026-10-08, see spec §1.

	Parts are named `CollisionBlocker<Part>` / `CollisionSelf<Part>`, so they never match a rig part name the
	outfit tracker looks up.

	@class CollisionBlockerSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)
local CollisionShapeUtils = require(ReplicatedStorage.Shared.Features.Collision.Utils.CollisionShapeUtils)

export type Capsule = {
	rig: Model,
	root: BasePart,
	parts: { BasePart },
	solid: boolean,
}

export type State = {
	puppets: { [Model]: Capsule },
	solid: { [Model]: Capsule }, -- the solid subset of `puppets`
	own: Capsule?,
	debug: boolean,
	writes: number, -- solid/not-solid flips so far
	sinceRangeCheck: number,
}

local CollisionBlockerSystem = {}

local ROOT_NAME = "HumanoidRootPart"
local SPECS = CollisionShapeUtils.capsule(CollisionConstants.RADIUS, CollisionConstants.BOTTOM, CollisionConstants.TOP)
local RANGE_INTERVAL = 1 / CollisionConstants.RANGE_CHECK_HZ

local function transparency(debug: boolean): number
	return if debug then CollisionConstants.DEBUG_TRANSPARENCY else 1
end

local function build(rig: Model, root: BasePart, isSelf: boolean, debug: boolean): Capsule
	local parts: { BasePart } = {}
	for _, spec in SPECS do
		local part = Instance.new("Part")
		part.Name = (if isSelf then "CollisionSelf" else "CollisionBlocker") .. spec.name
		part.Shape = spec.shape
		part.Size = spec.size
		part.CFrame = root.CFrame * spec.offset
		part.Anchored = false
		part.CanCollide = isSelf
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CustomPhysicalProperties = CollisionConstants.FRICTIONLESS
		part.CollisionGroup = if isSelf then CollisionConstants.SELF_GROUP else CollisionConstants.PUPPET_GROUP
		part.Color = if isSelf then CollisionConstants.SELF_COLOR else CollisionConstants.PUPPET_COLOR
		part.Transparency = transparency(debug)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = rig
		table.insert(parts, part)
	end
	return { rig = rig, root = root, parts = parts, solid = isSelf }
end

local function destroy(capsule: Capsule)
	for _, part in capsule.parts do
		part:Destroy()
	end
end

--[=[
	@param debug boolean -- whether capsules start visible
	@return State
]=]
function CollisionBlockerSystem.new(debug: boolean): State
	return { puppets = {}, solid = {}, own = nil, debug = debug, writes = 0, sinceRangeCheck = 0 }
end

--[=[
	The rig's HumanoidRootPart, or nil.
	@param rig Model?
	@return BasePart?
]=]
function CollisionBlockerSystem.rootOf(rig: Model?): BasePart?
	local root = if rig ~= nil then rig:FindFirstChild(ROOT_NAME) else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

--[=[
	Removes the capsule of a puppet or of the own rig. Unknown rigs are a no-op.
	@param state State
	@param rig Model
]=]
function CollisionBlockerSystem.remove(state: State, rig: Model)
	local capsule = state.puppets[rig]
	if capsule ~= nil then
		destroy(capsule)
		state.puppets[rig] = nil
		state.solid[rig] = nil
	end
	local own = state.own
	if own ~= nil and own.rig == rig then
		destroy(own)
		state.own = nil
	end
end

--[=[
	Gives another player's puppet a capsule, not solid until the next range check. Replaces an existing one.
	@param state State
	@param rig Model
	@return boolean -- false when the rig has no root
]=]
function CollisionBlockerSystem.addPuppet(state: State, rig: Model): boolean
	CollisionBlockerSystem.remove(state, rig)
	local root = CollisionBlockerSystem.rootOf(rig)
	if root == nil then
		return false
	end
	state.puppets[rig] = build(rig, root, false, state.debug)
	return true
end

--[=[
	Gives the local rig its self-collider, replacing the previous rig's.
	@param state State
	@param rig Model
	@return boolean -- false when the rig has no root
]=]
function CollisionBlockerSystem.addSelf(state: State, rig: Model): boolean
	local root = CollisionBlockerSystem.rootOf(rig)
	if root == nil then
		return false
	end
	local own = state.own
	if own ~= nil then
		destroy(own)
	end
	state.own = build(rig, root, true, state.debug)
	return true
end

--[=[
	Flips each puppet's capsule solid or not by the range band, writing CanCollide only on a flip.
	@param state State
	@param origin Vector3 -- the local root's position
]=]
function CollisionBlockerSystem.updateRange(state: State, origin: Vector3)
	for rig, capsule in state.puppets do
		local offset = capsule.root.Position - origin
		local solid = CollisionShapeUtils.nextSolid(capsule.solid, offset:Dot(offset))
		if solid ~= capsule.solid then
			capsule.solid = solid
			for _, part in capsule.parts do
				part.CanCollide = solid
			end
			state.writes += 1
			if solid then
				state.solid[rig] = capsule
			else
				state.solid[rig] = nil
			end
		end
	end
end

--[=[
	One frame: the range check when its interval has passed.
	@param state State
	@param dt number
	@param origin Vector3 -- the local root's position
]=]
function CollisionBlockerSystem.step(state: State, dt: number, origin: Vector3)
	state.sinceRangeCheck += dt
	if state.sinceRangeCheck >= RANGE_INTERVAL then
		state.sinceRangeCheck = 0
		CollisionBlockerSystem.updateRange(state, origin)
	end
end

--[=[
	Shows or hides every capsule (debug view). Capsules built later follow `state.debug`.
	@param state State
	@param on boolean
]=]
function CollisionBlockerSystem.setDebug(state: State, on: boolean)
	state.debug = on
	local value = transparency(on)
	for _, capsule in state.puppets do
		for _, part in capsule.parts do
			part.Transparency = value
		end
	end
	local own = state.own
	if own ~= nil then
		for _, part in own.parts do
			part.Transparency = value
		end
	end
end

--[=[
	Removes every capsule.
	@param state State
]=]
function CollisionBlockerSystem.clear(state: State)
	for _, capsule in state.puppets do
		destroy(capsule)
	end
	table.clear(state.puppets)
	table.clear(state.solid)
	local own = state.own
	if own ~= nil then
		destroy(own)
		state.own = nil
	end
end

--[=[
	@param state State
	@return { puppets: number, solid: number }
]=]
function CollisionBlockerSystem.counts(state: State): { puppets: number, solid: number }
	local puppets, solid = 0, 0
	for _ in state.puppets do
		puppets += 1
	end
	for _ in state.solid do
		solid += 1
	end
	return { puppets = puppets, solid = solid }
end

return CollisionBlockerSystem
