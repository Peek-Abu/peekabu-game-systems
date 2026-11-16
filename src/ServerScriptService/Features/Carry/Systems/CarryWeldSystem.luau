--!strict
--[=[
	CarryWeldSystem: joins a picked-up object to its carrier's body and takes it off again. `attach` makes every part
	massless and non-colliding (remembering how each was), poses the object where its hold puts it
	(AnimationCarrySystem.prepare, or the plain hold offset from the HumanoidRootPart), binds the hand contacts and
	welds it to the body part its hold rides (AnimationCarrySystem.mount); a hanging bag or a pushed item gets a tagged
	Motor6D its clients move. `detach` undoes it. Split out of CarryServiceServer, which owns the hold and calls it.

	@class CarryWeldSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CarryShared = ReplicatedStorage.Shared.Features.Carry
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CarryConstants = require(CarryShared.Data.CarryConstants)
local CarryTypes = require(CarryShared.Data.CarryTypes)
local AnimationCarrySystem = require(ServerScriptService.Features.Animation.Systems.AnimationCarrySystem)

export type SavedPart = { part: BasePart, massless: boolean, canCollide: boolean }

-- The tag each moving joint gets, for the client that moves it (CarrySwaySystem, CarryPushSystem).
local JOINT_TAGS: { [string]: string } = { swing = CarryConstants.HANG_TAG, follow = CarryConstants.PUSH_TAG }

local log = Logger.new("CarryServiceServer")

local CarryWeldSystem = {}

local function partsOf(target: Instance): { BasePart }
	local parts: { BasePart } = {}
	if target:IsA("BasePart") then
		table.insert(parts, target)
	end
	for _, descendant in target:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

--[=[
	Joins `target` (its root part `root`, a `kind` with `def`) to `player`'s body (`character`, its HumanoidRootPart
	`playerRoot`). Returns the joint, the hand contacts (nil without a measured rig) and each part's saved physics.
]=]
function CarryWeldSystem.attach(
	player: Player,
	target: PVInstance,
	root: BasePart,
	kind: string,
	def: CarryTypes.CarryDef,
	character: Model?,
	playerRoot: BasePart
): (JointInstance, AnimationCarrySystem.Controller?, { SavedPart })
	local saved: { SavedPart } = {}
	for _, part in partsOf(target) do
		table.insert(saved, { part = part, massless = part.Massless, canCollide = part.CanCollide })
		part.Massless = true
		part.CanCollide = false
	end
	root.Anchored = false
	local prepared = if character ~= nil then AnimationCarrySystem.prepare(character, target, kind, def.weight) else nil
	target:PivotTo(
		if prepared ~= nil
			then prepared.pivot
			else playerRoot.CFrame * (def.holdOffset or CarryConstants.DEFAULT_HOLD_OFFSET)
	)
	local contact: AnimationCarrySystem.Controller? = nil
	local joint: AnimationCarrySystem.Mount = {
		part = playerRoot,
		c0 = playerRoot.CFrame:ToObjectSpace(root.CFrame),
		c1 = CFrame.identity,
		joint = "weld",
	}
	if prepared ~= nil and character ~= nil then
		local broken = table.concat(prepared.report.violations, "; ")
		if broken ~= "" then
			log:warn(`{kind} held by {player.Name} breaks the carry rules: {broken}`)
		end
		-- The contacts are on the item's visible art, not its invisible proxy (AnimationCarrySystem.visibleBox).
		local boxInRoot = root.CFrame:ToObjectSpace(target:GetPivot() * prepared.box)
		contact = AnimationCarrySystem.bind(character, root, prepared.hold)
		joint = AnimationCarrySystem.mount(character, root, prepared.hold, boxInRoot) or joint
	end
	-- Part of the character's assembly while held, on the body part its hold rides (so it inherits the animation).
	-- A hanging bag's joint is a Motor6D at its handle: every client swings it there (CarrySwaySystem); a pushed
	-- item's is a Motor6D every client slides after the torso (CarryPushSystem). The server never moves either, so
	-- their physics stay those of a weld.
	local weld: JointInstance = if joint.joint ~= "weld" then Instance.new("Motor6D") else Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = joint.part
	weld.Part1 = root
	weld.C0 = joint.c0
	weld.C1 = joint.c1
	weld:SetAttribute(CarryConstants.TORSO_REST_ATTRIBUTE, joint.torsoRest)
	weld.Parent = root
	local tag = JOINT_TAGS[joint.joint]
	if tag ~= nil then
		CollectionService:AddTag(weld, tag)
	end
	return weld, contact, saved
end

--[=[
	Takes a held object off its carrier: the hand contacts go, the joint goes, and every part gets its own mass and
	collision back (`savedParts`, from attach).
]=]
function CarryWeldSystem.detach(
	contact: AnimationCarrySystem.Controller?,
	weld: JointInstance,
	savedParts: { SavedPart }
)
	if contact ~= nil then
		contact.destroy()
	end
	weld:Destroy()
	for _, saved in savedParts do
		saved.part.Massless = saved.massless
		saved.part.CanCollide = saved.canCollide
	end
end

return CarryWeldSystem
