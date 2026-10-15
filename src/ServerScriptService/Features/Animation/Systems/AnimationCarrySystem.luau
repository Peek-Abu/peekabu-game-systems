--!strict
--[=[
	AnimationCarrySystem: plans how a carrier holds an item and drives its arms there.

	- `measure` (AnimationCarryMeasureSystem) reads the carrier's rig at rest: both arms bone by bone, the torso and
	  head from their real surface, the floor.
	- `prepare` picks the hold (AnimationCarryHoldRules, from the item's visible size, weight, handle and the art's
	  `CarryHold` override) and plans it on the item's real visible surface (AnimationCarrySurfaceSystem probes it;
	  AnimationCarryContactUtils places the item and the palms; AnimationCarryPoseRules judges every candidate).
	- `mount` is the joint CarryServiceServer holds the item by: the UpperTorso (under), the RightHand (hand, a
	  swinging Motor6D at the handle) or the root (push, a Motor6D clients slide after the torso).
	- `bind` drives each arm to its planned pose with three single-joint native IKControls (shoulder, elbow, wrist),
	  each a full 6-DoF target the joint reaches exactly, riding the UpperTorso at their rest-pose place (a pushed
	  item's ride the item, with a two-bone re-reach onto it). The engine's solver has no roll or bend left to choose
	  (a two-bone 6-DoF solve kept the animation's upper-arm roll and bent the elbows ~50 degrees sideways), no target
	  rides what it moves (no chasing itself), and there is no smoothing: a 0.08 s SmoothTime trailed the hands behind
	  a walking torso.
	No rig C0/C1/RigAttachment/Transform is written here; server-made IKControls replicate and every client's
	Animator solves them over whatever locomotion plays.

	@class AnimationCarrySystem
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Animation = ReplicatedStorage.Shared.Features.Animation
local AnimationTypes = require(Animation.Data.AnimationTypes)
local AnimationCarryRegistry = require(Animation.Data.AnimationCarryRegistry)
local AnimationCarryContactUtils = require(Animation.Utils.AnimationCarryContactUtils)
local AnimationCarryHoldRules = require(Animation.Rules.AnimationCarryHoldRules)
local AnimationCarryPoseRules = require(Animation.Rules.AnimationCarryPoseRules)
local AnimationCarrySurfaceSystem = require(ServerScriptService.Features.Animation.Systems.AnimationCarrySurfaceSystem)
local AnimationCarryMeasureSystem = require(ServerScriptService.Features.Animation.Systems.AnimationCarryMeasureSystem)

export type Controller = { destroy: () -> () }
export type Hold = AnimationTypes.CarryHold
-- `box` is the visible box relative to the item's pivot; the hold's contacts are relative to it.
export type Prepared = { pivot: CFrame, box: CFrame, hold: Hold, report: AnimationCarryPoseRules.Report }
--[=[
	The joint holding a held item to the carrier's body: `part` is the Part0, `c0` / `c1` the joint's frames on it and
	on the item's root. `joint` is "weld" (rigid), "swing" (a hanging item: a Motor6D CarrySwaySystem swings on
	clients) or "follow" (a pushed item: a Motor6D CarryPushSystem slides on clients after the torso, from `torsoRest`,
	where the UpperTorso is at rest in root space).
]=]
export type Mount = {
	part: BasePart,
	c0: CFrame,
	c1: CFrame,
	joint: "weld" | "swing" | "follow",
	torsoRest: Vector3?,
}

local AnimationCarrySystem = {}

-- The carrier, read from its rig (AnimationCarryMeasureSystem).
AnimationCarrySystem.measure = AnimationCarryMeasureSystem.measure
AnimationCarrySystem.armOf = AnimationCarryMeasureSystem.armOf
AnimationCarrySystem.palmOf = AnimationCarryMeasureSystem.palmOf

-- The art's override of the hold (AnimationCarryHoldRules), and the attachments it may author.
local HOLD_ATTRIBUTE = "CarryHold"
local HANDLE = "CarryHandle"
local BODY_FRONT = "CarryBodyFront"
-- The IKControls' priorities: the shoulder first, then the elbow, then the wrist (higher resolves later).
local PRIORITY = 20

local function part(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end
local function attachment(bodyPart: BasePart, name: string): Attachment?
	local found = bodyPart:FindFirstChild(name)
	return if found ~= nil and found:IsA("Attachment") then found else nil
end
local frameOf = AnimationCarryMeasureSystem.restFrame
-- Where `bodyPart` is in world space with the rig at rest.
local function restWorldOf(bodyPart: BasePart, root: BasePart): CFrame
	return root.CFrame * frameOf(bodyPart, root)
end

-- The box round `parts`, axis-aligned in `frame`: its centre (in `frame`) and size. Nil for no parts.
local function boundsIn(frame: CFrame, parts: { BasePart }): (Vector3?, Vector3?)
	if #parts == 0 then
		return nil, nil
	end
	local low = Vector3.one * math.huge
	local high = -Vector3.one * math.huge
	for _, bodyPart in parts do
		local relative = frame:ToObjectSpace(bodyPart.CFrame)
		local half = bodyPart.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local corner = relative * Vector3.new(x * half.X, y * half.Y, z * half.Z)
					low = low:Min(corner)
					high = high:Max(corner)
				end
			end
		end
	end
	return (low + high) / 2, high - low
end

--[=[
	The box round an item's VISIBLE parts (Transparency below 1), axis-aligned in its pivot frame, as (box relative to
	the pivot, size). Cargo is an invisible size-class proxy with its art fitted inside; the hold is planned on the
	art. With nothing visible (a hidden item), the whole item.
]=]
function AnimationCarrySystem.visibleBox(target: PVInstance): (CFrame, Vector3)
	local centre, size = boundsIn(target:GetPivot(), AnimationCarrySurfaceSystem.visibleParts(target))
	if centre == nil or size == nil then
		return CFrame.identity, Vector3.zero
	end
	return CFrame.new(centre), size
end

-- The art's `CarryHold` override, on the item or any model inside it (the art clone keeps its template's attributes).
local function override(target: Instance): AnimationTypes.CarryStyle?
	local found: AnimationTypes.CarryStyle? = AnimationCarryHoldRules.style(target:GetAttribute(HOLD_ATTRIBUTE))
	for _, descendant in target:GetDescendants() do
		if found == nil and descendant:IsA("Model") then
			found = AnimationCarryHoldRules.style(descendant:GetAttribute(HOLD_ATTRIBUTE))
		end
	end
	return found
end

--[=[
	Plans how `character` holds `target` (`kind` a CarryRegistry kind, `weight` its carry weight): the item's pivot
	to place it at, its visible box relative to that pivot, the hold and its AnimationCarryPoseRules report. Nil
	without a measurable carrier or anything visible to hold.
]=]
function AnimationCarrySystem.prepare(character: Model, target: PVInstance, kind: string, weight: number): Prepared?
	local root = part(character, "HumanoidRootPart")
	local rig = AnimationCarryMeasureSystem.measure(character)
	if root == nil or rig == nil then
		return nil
	end
	local boxFromPivot, size = AnimationCarrySystem.visibleBox(target)
	local boxWorld = target:GetPivot() * boxFromPivot
	local handle = target:FindFirstChild(HANDLE, true)
	local bodyFront = target:FindFirstChild(BODY_FRONT, true)
	local surface = AnimationCarrySurfaceSystem.open(target, boxWorld)
	local item: AnimationTypes.CarryItem = {
		size = size,
		probe = surface.probe,
		handle = if handle ~= nil and handle:IsA("Attachment")
			then boxWorld:PointToObjectSpace(handle.WorldPosition)
			else nil,
		bodyZ = if bodyFront ~= nil and bodyFront:IsA("Attachment")
			then boxWorld:PointToObjectSpace(bodyFront.WorldPosition).Z
			else nil,
	}
	local described: AnimationCarryHoldRules.Item = {
		size = size,
		weight = weight,
		handle = item.handle ~= nil,
		override = override(target) or AnimationCarryRegistry.get(kind),
	}
	local hold, report = AnimationCarryContactUtils.plan(item, rig, AnimationCarryHoldRules.choose(described, rig))
	local instead: AnimationTypes.CarryStyle? = nil
	if hold ~= nil and report ~= nil then
		local planned: AnimationTypes.CarryStyle = hold.style
		instead = AnimationCarryHoldRules.instead(described, planned, report.overChin, rig)
	end
	if instead ~= nil then
		local other, otherReport = AnimationCarryContactUtils.plan(item, rig, { instead })
		if other ~= nil and otherReport ~= nil and otherReport.ok then
			hold, report = other, otherReport
		end
	end
	surface.release()
	if hold == nil or report == nil then
		return nil
	end
	return {
		pivot = root.CFrame * hold.offset * boxFromPivot:Inverse(),
		box = boxFromPivot,
		hold = hold,
		report = report,
	}
end

--[=[
	The joint holding a held item (already moved to its planned pivot) to the carrier for `hold`; `boxInRoot` is the
	item's visible box in its root part's space. The UpperTorso for `under` (from the torso's REST frame, so the item
	sits where it was planned and then bobs, leans and turns with it), the RightHand for `hand` (jointed at the handle:
	the fist's grip on the hand, the contact on the item), the root for `push` (sliding after the torso, see `Mount`). Falls back to the root when the body
	part is missing. Nil without a HumanoidRootPart.
]=]
function AnimationCarrySystem.mount(character: Model, cargoRoot: BasePart, hold: Hold, boxInRoot: CFrame): Mount?
	local root = part(character, "HumanoidRootPart")
	if root == nil then
		return nil
	end
	local hand = part(character, "RightHand")
	local arm = AnimationCarryMeasureSystem.armOf(character, "Right")
	if hold.mount == "rightHand" and hand ~= nil and arm ~= nil then
		return { part = hand, c0 = arm.gripInHand, c1 = boxInRoot * hold.right, joint = "swing" }
	end
	local torso = part(character, "UpperTorso")
	if hold.mount == "torso" and torso ~= nil then
		return {
			part = torso,
			c0 = restWorldOf(torso, root):ToObjectSpace(cargoRoot.CFrame),
			c1 = CFrame.identity,
			joint = "weld",
		}
	end
	return {
		part = root,
		c0 = root.CFrame:ToObjectSpace(cargoRoot.CFrame),
		c1 = CFrame.identity,
		joint = if hold.mount == "root" and torso ~= nil then "follow" else "weld",
		torsoRest = if torso ~= nil then frameOf(torso, root).Position else nil,
	}
end

--[=[
	Drives `character`'s arms to `hold`'s planned poses (see the class). Nil when the carrier is dead or lacks the
	arm parts and joints. The controller's `destroy` removes every control and target; it also runs when the
	character, its Humanoid or `cargoRoot` goes, or the Humanoid dies.
]=]
function AnimationCarrySystem.bind(character: Model, cargoRoot: BasePart, hold: Hold): Controller?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = part(character, "HumanoidRootPart")
	local torso = part(character, "UpperTorso")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or torso == nil then
		return nil
	end
	local torsoRest = frameOf(torso, root)
	local made: { Instance } = {}
	local connections: { RBXScriptConnection } = {}
	local destroyed = false
	-- A pushed item rides the root while the arms ride the torso, which the walk bobs and leans: the hands are
	-- re-reached onto it (see `arm`).
	local pushed = hold.mount == "root"
	-- A target at `frame` (root space, at rest) held on `on`: the torso, or the item (whose place on the root is
	-- fixed, so its frame at rest is where it is now).
	local function targetAt(name: string, frame: CFrame, on: BasePart): Attachment
		local target = Instance.new("Attachment")
		target.Name = name
		target.CFrame = if on == torso
			then torsoRest:ToObjectSpace(frame)
			else on.CFrame:ToObjectSpace(root.CFrame * frame)
		target.Parent = on
		table.insert(made, target)
		return target
	end
	-- One control from `chainRoot` to `effector` (an attachment on the chain's last part) meeting `target`.
	local function control(
		name: string,
		chainRoot: BasePart,
		effector: Attachment,
		target: Attachment,
		order: number
	): IKControl
		local ik = Instance.new("IKControl")
		ik.Name = name
		ik.Type = Enum.IKControlType.Transform
		ik.ChainRoot = chainRoot
		ik.EndEffector = effector
		ik.Target = target
		ik.SmoothTime = 0
		ik.Weight = 1
		ik.Priority = PRIORITY + order
		ik.Parent = humanoid
		table.insert(made, ik)
		return ik
	end
	-- One single-joint control: `chainRoot` turns its joint so `effector` (an attachment on it) meets `frame`, held on
	-- `on`. The effector is never AT the joint's pivot: with no lever the solver returns NaN (a stock R15 hand's
	-- WristRigAttachment is its wrist pivot), so the hand is driven by its grip.
	local function drive(
		name: string,
		chainRoot: BasePart,
		effector: Attachment,
		frame: CFrame,
		order: number,
		on: BasePart
	)
		control(name, chainRoot, effector, targetAt(name .. "Target", frame, on), order)
	end
	-- The upgraded avatar joints' BallSocketConstraints (shoulder, elbow, wrist) limit an IKControl too, and a
	-- single-joint 6-DoF control against them returns NaN (measured on a stock R15, 2026-10-15). The planned pose is
	-- already inside AnimationCarryArmUtils' anatomical limits, so they are switched off while the arm is driven and
	-- put back on release (a ragdoll needs them).
	local sockets: { BallSocketConstraint } = {}
	local function arm(side: string, pose: AnimationTypes.CarryPose): boolean
		local upper = part(character, side .. "UpperArm")
		local lower = part(character, side .. "LowerArm")
		local hand = part(character, side .. "Hand")
		if upper == nil or lower == nil or hand == nil then
			return false
		end
		for _, bodyPart in { upper, lower, hand } do
			for _, child in bodyPart:GetChildren() do
				if child:IsA("BallSocketConstraint") and child.Enabled then
					child.Enabled = false
					table.insert(sockets, child)
				end
			end
		end
		local elbow = attachment(upper, side .. "ElbowRigAttachment")
		local wrist = attachment(lower, side .. "WristRigAttachment")
		local grip = attachment(hand, side .. "GripAttachment")
		if elbow == nil or wrist == nil or grip == nil then
			return false
		end
		-- A pushed item's targets all ride it: the arms keep their planned pose in the world, against the item, while
		-- the walk leans the torso (CarryPushSystem slides the item after the torso, so the shoulders stay as far from it).
		local on = if pushed then cargoRoot else torso
		drive(`CleanupCarryShoulder{side}`, upper, elbow, pose.upper * elbow.CFrame, 0, on)
		drive(`CleanupCarryElbow{side}`, lower, wrist, pose.lower * wrist.CFrame, 1, on)
		if pushed then
			-- Then the shoulder and elbow together re-reach the wrist onto the item from wherever the walk has taken
			-- the shoulder (its bob): a small correction from the planned pose (resolved after it), the elbow kept toward
			-- its planned side by a pole past it.
			local wristAt = pose.lower * wrist.CFrame
			local reach = control(
				`CleanupCarryReach{side}`,
				upper,
				wrist,
				targetAt(`CleanupCarryReach{side}Target`, wristAt, cargoRoot),
				2
			)
			local shoulder = attachment(upper, side .. "ShoulderRigAttachment")
			local elbowAt = pose.upper:PointToWorldSpace(elbow.Position)
			local mid = (
				(if shoulder ~= nil then pose.upper:PointToWorldSpace(shoulder.Position) else elbowAt)
				+ wristAt.Position
			) / 2
			local out = elbowAt - mid
			reach.Pole = targetAt(
				`CleanupCarryReach{side}Pole`,
				CFrame.new(elbowAt + (if out.Magnitude > 1e-3 then out.Unit else -Vector3.yAxis)),
				cargoRoot
			)
		end
		drive(`CleanupCarryWrist{side}`, hand, grip, pose.hand * grip.CFrame, 3, on)
		return true
	end
	local controller: Controller
	controller = {
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			for _, instance in made do
				instance:Destroy()
			end
			table.clear(made)
			for _, socket in sockets do
				if socket.Parent ~= nil then
					socket.Enabled = true
				end
			end
			table.clear(sockets)
		end,
	}
	local leftPose = hold.leftPose
	if not arm("Right", hold.rightPose) or (leftPose ~= nil and not arm("Left", leftPose)) then
		controller.destroy()
		return nil
	end
	table.insert(connections, cargoRoot.Destroying:Connect(controller.destroy))
	table.insert(connections, character.Destroying:Connect(controller.destroy))
	table.insert(connections, humanoid.Died:Connect(controller.destroy))
	table.insert(connections, humanoid.Destroying:Connect(controller.destroy))
	return controller
end

--[=[
	Where the engine shows things now, mapped into the space `hold` was planned in (root space at rest), for the
	validator: `world` CFrame -> planned space. An item ridden on the body (`under`, `hand`) is judged with the torso
	carried back to its rest frame, since the whole hold rides it; a pushed item rides the root.
]=]
function AnimationCarrySystem.liveSpace(character: Model, hold: Hold): ((CFrame) -> CFrame)?
	local root = part(character, "HumanoidRootPart")
	local torso = part(character, "UpperTorso")
	if root == nil then
		return nil
	end
	local rootFrame = root.CFrame
	local toRest = if hold.mount ~= "root" and torso ~= nil
		then rootFrame * frameOf(torso, root) * torso.CFrame:Inverse()
		else CFrame.identity
	return function(world: CFrame): CFrame
		return rootFrame:ToObjectSpace(toRest * world)
	end
end

--[=[
	How the carrier's torso is turned now from its rest pose, in the planned space (`liveSpace`): identity for a hold
	ridden on the body (carried back onto the rest-posed torso).
]=]
function AnimationCarrySystem.liveTorsoTurn(character: Model, space: (CFrame) -> CFrame): CFrame
	local root = part(character, "HumanoidRootPart")
	local torso = part(character, "UpperTorso")
	if root == nil or torso == nil then
		return CFrame.identity
	end
	return space(torso.CFrame).Rotation * frameOf(torso, root).Rotation:Inverse()
end

--[=[
	`side`'s arm as the engine shows it now, in the planned space (`liveSpace`).
]=]
function AnimationCarrySystem.livePose(
	character: Model,
	side: string,
	space: (CFrame) -> CFrame
): AnimationTypes.CarryPose?
	local upper = part(character, side .. "UpperArm")
	local lower = part(character, side .. "LowerArm")
	local hand = part(character, side .. "Hand")
	if upper == nil or lower == nil or hand == nil then
		return nil
	end
	return { upper = space(upper.CFrame), lower = space(lower.CFrame), hand = space(hand.CFrame) }
end

return AnimationCarrySystem
