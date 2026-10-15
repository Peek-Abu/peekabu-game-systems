--!strict
-- Server-created native IK targets replicate; each Animator evaluates only arm chains.
-- Native AnimationConstraint support verified in Studio: 2-chain,1.643stud span,
-- hand target error .000127stud. No rig C0/C1/RigAttachment/Transform writes occur here; `mount` only computes
-- the frame the carry weld (made by CarryServiceServer) holds the item at on a body part.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationCarryRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationCarryRegistry)
local AnimationCarryContactUtils = require(ReplicatedStorage.Shared.Features.Animation.Utils.AnimationCarryContactUtils)
export type Controller = { destroy: () -> () }
-- `box` is the visible box relative to the item's pivot; `layout`'s contacts are relative to it.
export type Prepared = { pivot: CFrame, box: CFrame, layout: AnimationCarryContactUtils.Layout }
export type Layout = AnimationCarryContactUtils.Layout
local AnimationCarrySystem = {}
-- Where an under-the-item hold bends each elbow toward, from its shoulder in root space, in upper arms (X is
-- outward): down, a little out and behind. On a round body that would run the arm through the torso, the elbow
-- swings out instead (AnimationCarryContactUtils.elbow, round bodies only), clear of the torso grown by BODY_PAD (the
-- uniform vest).
local POLE = Vector3.new(0.4, -2, 1)
local BODY_PAD = 0.08
local function part(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end
local function attachment(bodyPart: BasePart, name: string): Attachment?
	local found = bodyPart:FindFirstChild(name)
	return if found ~= nil and found:IsA("Attachment") then found else nil
end
-- The part's rest frame relative to the root: its Motor6D chain (C0 * C1:Inverse()) without the animation's
-- Transforms. Nil when the chain does not reach the root.
local function restFrameOf(bodyPart: BasePart, root: BasePart): CFrame?
	local rest = CFrame.identity
	local current = bodyPart
	for _ = 1, 8 do
		if current == root then
			return rest
		end
		local motor: Motor6D? = nil
		for _, child in current:GetChildren() do
			if child:IsA("Motor6D") and child.Part1 == current then
				motor = child
				break
			end
		end
		if motor == nil or motor.Part0 == nil then
			return nil
		end
		rest = motor.C0 * motor.C1:Inverse() * rest
		current = motor.Part0
	end
	return nil
end
-- The part's rest orientation relative to the root; identity when the chain does not reach the root.
local function restOf(bodyPart: BasePart, root: BasePart): CFrame
	local rest = restFrameOf(bodyPart, root)
	return if rest ~= nil then rest.Rotation else CFrame.identity
end
-- Where the part sits relative to the root at rest, or where it is now when it has no joint chain to the root.
-- The torso and head are measured at rest: an idle that nods the head or leans the torso would otherwise move
-- the hold with whatever frame the pick-up landed on.
local function frameOf(bodyPart: BasePart, root: BasePart): CFrame
	return restFrameOf(bodyPart, root) or root.CFrame:ToObjectSpace(bodyPart.CFrame)
end
--[=[
	`side`'s palm frame in its hand's space (AnimationCarryContactUtils.palmFrame): the fingers point from the
	wrist to the hand's grip (or its middle), the palm is the side facing the body at rest. Nil without the arm.
]=]
function AnimationCarrySystem.palmOf(character: Model, side: string): CFrame?
	local root = part(character, "HumanoidRootPart")
	local hand = part(character, side .. "Hand")
	if root == nil or hand == nil then
		return nil
	end
	local wrist = attachment(hand, side .. "WristRigAttachment")
	if wrist == nil then
		return nil
	end
	local grip = attachment(hand, side .. "GripAttachment")
	local fingers = (if grip ~= nil then grip.Position else Vector3.zero) - wrist.Position
	if fingers.Magnitude < 1e-3 then
		return nil
	end
	return AnimationCarryContactUtils.palmFrame(
		fingers,
		restOf(hand, root),
		if side == "Right" then 1 else -1,
		hand.Size
	)
end
--[=[
	`side`'s palm frame (`palmOf`) in its LowerArm's space with the wrist at rest: through the wrist joint's C0 / C1
	(its rest pose, never an animated Transform), or the lower arm's and hand's WristRigAttachments without one. The
	carry IK ends at the lower arm with this offset, so the wrist is never bent to aim the hand. Nil without the arm.
]=]
function AnimationCarrySystem.palmInLowerOf(character: Model, side: string): CFrame?
	local lower = part(character, side .. "LowerArm")
	local hand = part(character, side .. "Hand")
	local palm = AnimationCarrySystem.palmOf(character, side)
	if lower == nil or hand == nil or palm == nil then
		return nil
	end
	for _, child in hand:GetChildren() do
		if child:IsA("Motor6D") and child.Part0 == lower and child.Part1 == hand then
			return child.C0 * child.C1:Inverse() * palm
		end
	end
	local lowerWrist = attachment(lower, side .. "WristRigAttachment")
	local handWrist = attachment(hand, side .. "WristRigAttachment")
	if lowerWrist == nil or handWrist == nil then
		return nil
	end
	return lowerWrist.CFrame * handWrist.CFrame:Inverse() * palm
end
-- Shoulder (root space, at the rig's rest pose: the hold rides the rest-posed torso), reach from the shoulder to the
-- hand's end (the arm's two spans plus wrist to the end), to the palm's centre, the hand's length along its fingers,
-- and the wrist in the palm's frame, read from the rig so any scale or proportion is measured.
local function arm(character: Model, side: string, root: BasePart): (Vector3?, number?, number?, number?, Vector3?)
	local upper = part(character, side .. "UpperArm")
	local lower = part(character, side .. "LowerArm")
	local hand = part(character, side .. "Hand")
	if upper == nil or lower == nil or hand == nil then
		return nil, nil, nil, nil, nil
	end
	local shoulder = attachment(upper, side .. "ShoulderRigAttachment")
	local elbow = attachment(upper, side .. "ElbowRigAttachment")
	local lowerElbow = attachment(lower, side .. "ElbowRigAttachment")
	local wrist = attachment(lower, side .. "WristRigAttachment")
	local handWrist = attachment(hand, side .. "WristRigAttachment")
	local palmFrame = AnimationCarrySystem.palmOf(character, side)
	if shoulder == nil or elbow == nil or lowerElbow == nil or wrist == nil or handWrist == nil or palmFrame == nil then
		return nil, nil, nil, nil, nil
	end
	local spans = (shoulder.WorldPosition - elbow.WorldPosition).Magnitude
		+ (lowerElbow.WorldPosition - wrist.WorldPosition).Magnitude
	local along = palmFrame.LookVector
	local rest = restFrameOf(upper, root)
	return if rest ~= nil then rest * shoulder.Position else root.CFrame:PointToObjectSpace(shoulder.WorldPosition),
		spans + (Vector3.new(0, -hand.Size.Y / 2, 0) - handWrist.Position).Magnitude,
		spans + (palmFrame.Position - handWrist.Position).Magnitude,
		math.abs(along.X) * hand.Size.X + math.abs(along.Y) * hand.Size.Y + math.abs(along.Z) * hand.Size.Z,
		palmFrame:PointToObjectSpace(handWrist.Position)
end
-- The most extreme corner of `bodyPart` (at rest) along root-space `axis` (min when `sign` is -1).
local function extreme(root: BasePart, bodyPart: BasePart, axis: Vector3, sign: number): number
	local frame = frameOf(bodyPart, root)
	local half = bodyPart.Size / 2
	local best = -sign * math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local along = (frame * Vector3.new(x * half.X, y * half.Y, z * half.Z)):Dot(axis)
				best = if sign < 0 then math.min(best, along) else math.max(best, along)
			end
		end
	end
	return best
end
--[=[
	The carrier as AnimationCarryContactUtils sees it, in HumanoidRootPart space: shoulders and reaches, the
	torso front, the head's front and bottom, and the floor. Nil for a rig without native R15 arms, torso and head.
]=]
function AnimationCarrySystem.measure(character: Model): AnimationCarryContactUtils.Rig?
	local root = part(character, "HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local upperTorso = part(character, "UpperTorso")
	local head = part(character, "Head")
	if root == nil or humanoid == nil or upperTorso == nil or head == nil then
		return nil
	end
	local left, leftReach, leftPalm, leftHand, leftWrist = arm(character, "Left", root)
	local right, rightReach, rightPalm, rightHand, rightWrist = arm(character, "Right", root)
	if
		left == nil
		or leftReach == nil
		or leftPalm == nil
		or leftHand == nil
		or right == nil
		or rightReach == nil
		or rightPalm == nil
		or rightHand == nil
	then
		return nil
	end
	local front = extreme(root, upperTorso, Vector3.zAxis, -1)
	local halfWidth =
		math.max(-extreme(root, upperTorso, Vector3.xAxis, -1), extreme(root, upperTorso, Vector3.xAxis, 1))
	local lowerTorso = part(character, "LowerTorso")
	if lowerTorso ~= nil then
		front = math.min(front, extreme(root, lowerTorso, Vector3.zAxis, -1))
		halfWidth = math.max(
			halfWidth,
			-extreme(root, lowerTorso, Vector3.xAxis, -1),
			extreme(root, lowerTorso, Vector3.xAxis, 1)
		)
	end
	return {
		leftShoulder = left,
		rightShoulder = right,
		leftReach = leftReach,
		rightReach = rightReach,
		front = front,
		headFront = extreme(root, head, Vector3.zAxis, -1),
		headBottom = extreme(root, head, Vector3.yAxis, -1),
		floor = -root.Size.Y / 2 - humanoid.HipHeight,
		leftPalmReach = leftPalm,
		rightPalmReach = rightPalm,
		handLength = math.min(leftHand, rightHand),
		torsoHalfWidth = halfWidth,
		rightWristInPalm = rightWrist,
		leftWristInPalm = leftWrist,
	}
end
-- The torso (UpperTorso, LowerTorso) at rest as ellipsoids in root space, from each part's box.
local function bodyOf(character: Model, root: BasePart): { AnimationCarryContactUtils.Body }
	local body: { AnimationCarryContactUtils.Body } = {}
	for _, name in { "UpperTorso", "LowerTorso" } do
		local bodyPart = part(character, name)
		if bodyPart ~= nil then
			local low = Vector3.new(
				extreme(root, bodyPart, Vector3.xAxis, -1),
				extreme(root, bodyPart, Vector3.yAxis, -1),
				extreme(root, bodyPart, Vector3.zAxis, -1)
			)
			local high = Vector3.new(
				extreme(root, bodyPart, Vector3.xAxis, 1),
				extreme(root, bodyPart, Vector3.yAxis, 1),
				extreme(root, bodyPart, Vector3.zAxis, 1)
			)
			table.insert(body, { centre = (low + high) / 2, radii = (high - low) / 2 })
		end
	end
	return body
end
-- The box around `parts`, axis-aligned in `frame`: its centre (in `frame`) and size. Nil for no parts.
local function boundsIn(frame: CFrame, parts: { BasePart }): (Vector3?, Vector3?)
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
	if #parts == 0 then
		return nil, nil
	end
	return (low + high) / 2, high - low
end
--[=[
	The box a carrier's hands go around: the item's VISIBLE parts (Transparency below 1), axis-aligned in the
	item's pivot frame, as (box relative to the pivot, size). Cargo is an invisible size-class proxy with its art
	(ArtVisualSystem's `ArtVisual`) uniformly fitted inside it and standing on its floor, so the art is up to
	1.5 studs shorter and 0.9 shallower than the proxy; planning on the proxy put the hands in empty air and the
	art out of reach of the belly. With nothing visible (a hidden item), the whole item.
]=]
function AnimationCarrySystem.visibleBox(target: PVInstance): (CFrame, Vector3)
	local pivot = target:GetPivot()
	local all: { BasePart } = {}
	local visible: { BasePart } = {}
	local candidates: { Instance } = target:GetDescendants()
	table.insert(candidates, target)
	for _, candidate in candidates do
		if candidate:IsA("BasePart") then
			table.insert(all, candidate)
			if candidate.Transparency < 1 then
				table.insert(visible, candidate)
			end
		end
	end
	local centre, size = boundsIn(pivot, if #visible > 0 then visible else all)
	if centre == nil or size == nil then
		return CFrame.identity, Vector3.zero
	end
	return CFrame.new(centre), size
end
function AnimationCarrySystem.prepare(
	character: Model,
	target: PVInstance,
	kind: string,
	requestedOffset: CFrame?
): Prepared?
	local root = part(character, "HumanoidRootPart")
	local rig = AnimationCarrySystem.measure(character)
	if root == nil or rig == nil then
		return nil
	end
	local boxFromPivot, size = AnimationCarrySystem.visibleBox(target)
	local boxFrame = target:GetPivot() * boxFromPivot
	local requestedBox = if requestedOffset ~= nil then requestedOffset * boxFromPivot else nil
	-- Authored on the art: the point held against the body (CarryBodyFront: a pot's front under leaves wider
	-- than it), in place of the box's near face. CarryGripRight / CarryGripLeft (handles on a pot's rim) are no
	-- longer read: the hands go under the item's bottom instead.
	local bodyFront = target:FindFirstChild("CarryBodyFront", true)
	-- Authored on a bag's art: the point its tie or handle is held by (CarryHandle), for a one-hand hang.
	local handle = target:FindFirstChild("CarryHandle", true)
	local authored: AnimationCarryContactUtils.Authored = {
		bodyZ = if bodyFront ~= nil and bodyFront:IsA("Attachment")
			then boxFrame:PointToObjectSpace(bodyFront.WorldPosition).Z
			else nil,
		handle = if handle ~= nil and handle:IsA("Attachment")
			then boxFrame:PointToObjectSpace(handle.WorldPosition)
			else nil,
	}
	local style: AnimationCarryRegistry.Style = AnimationCarryRegistry.get(kind)
	local plan = AnimationCarryContactUtils.plan(size, rig, style, requestedBox, authored)
	if plan == nil then
		return nil
	end
	local pivot = root.CFrame * plan.offset * boxFromPivot:Inverse()
	return { pivot = pivot, box = boxFromPivot, layout = plan }
end
-- Where `bodyPart` is in world space with the rig at rest (its live frame when it has no joint chain to the root).
local function restWorldOf(bodyPart: BasePart, root: BasePart): CFrame
	return root.CFrame * frameOf(bodyPart, root)
end
--[=[
	The joint holding a held item to the carrier's body for `layout` (its contacts relative to `cargoRoot`, which has
	been moved to its planned place): `part` is the Part0, `c0` / `c1` the joint's frames on it and on the item. The
	root for a cart; the UpperTorso for an item on the forearms (from the torso's REST frame, so the item sits where it
	was planned and then bobs, leans and turns with the torso's animation; the IK'd hands follow it); the RightHand for
	a hanging bag, jointed at its handle (the palm's frame on the hand, the handle contact on the bag) so it goes
	wherever the hand goes and `swings` from it (CarrySwaySystem). Falls back to the root when the body part is
	missing. Nil without a HumanoidRootPart.
]=]
export type Mount = { part: BasePart, c0: CFrame, c1: CFrame, swings: boolean }
function AnimationCarrySystem.mount(
	character: Model,
	cargoRoot: BasePart,
	layout: AnimationCarryContactUtils.Layout
): Mount?
	local root = part(character, "HumanoidRootPart")
	if root == nil then
		return nil
	end
	local hand = part(character, "RightHand")
	local palm = AnimationCarrySystem.palmOf(character, "Right")
	if layout.mount == "rightHand" and hand ~= nil and palm ~= nil then
		return { part = hand, c0 = palm, c1 = layout.right, swings = true }
	end
	local torso = part(character, "UpperTorso")
	if layout.mount ~= "root" and torso ~= nil then
		return {
			part = torso,
			c0 = restWorldOf(torso, root):ToObjectSpace(cargoRoot.CFrame),
			c1 = CFrame.identity,
			swings = false,
		}
	end
	return { part = root, c0 = root.CFrame:ToObjectSpace(cargoRoot.CFrame), c1 = CFrame.identity, swings = false }
end
-- layout contacts are relative to the visible box (`Prepared.box`, from the item's pivot). Caller converts
-- them to cargo-root coordinates after PivotTo; the physics weld remains server-owned. A hanging bag's target (and
-- pole) go on the UpperTorso, at their rest-pose place: the bag is welded to the hand, so a target on it would chase
-- itself.
function AnimationCarrySystem.bind(
	character: Model,
	cargoRoot: BasePart,
	layout: AnimationCarryContactUtils.Layout
): Controller?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rightUpper, rightHand = part(character, "RightUpperArm"), part(character, "RightHand")
	local leftUpper, leftHand = part(character, "LeftUpperArm"), part(character, "LeftHand")
	if
		humanoid == nil
		or humanoid.Health <= 0
		or rightUpper == nil
		or rightHand == nil
		or (layout.left ~= nil and (leftUpper == nil or leftHand == nil))
	then
		return nil
	end
	local controls: { IKControl } = {}
	local targets: { Attachment } = {}
	local connections: { RBXScriptConnection } = {}
	local destroyed = false
	local root = part(character, "HumanoidRootPart")
	-- Only a round body's elbows are bent out (AnimationCarryContactUtils.elbow); a stock R15 keeps the default pole.
	local measured = if layout.under or layout.hug then AnimationCarrySystem.measure(character) else nil
	local roundBody = measured ~= nil and AnimationCarryContactUtils.roundBody(measured)
	local body = if roundBody and root ~= nil then bodyOf(character, root) else {}
	-- What the targets ride: the item, or for a hanging bag the UpperTorso (its rest frame).
	local torso = part(character, "UpperTorso")
	local on = if layout.hang and torso ~= nil and root ~= nil then torso else cargoRoot
	local onFrame = if on ~= cargoRoot and root ~= nil then restWorldOf(on, root) else cargoRoot.CFrame
	local palms = layout.under or layout.hang or layout.hug
	local function add(side: string, upper: BasePart, hand: BasePart, contact: CFrame)
		local target = Instance.new("Attachment")
		target.Name = "CleanupCarryGrip" .. side
		target.Parent = on
		table.insert(targets, target)
		local control = Instance.new("IKControl")
		control.Name = "CleanupCarryIK" .. side
		control.Type = Enum.IKControlType.Transform
		control.ChainRoot = upper
		local sign = if side == "Right" then 1 else -1
		-- Wrists stay neutral: the chain is the shoulder and elbow only, ending at the lower arm with the palm carried
		-- on it at the wrist's rest angle. The hand is never bent to aim it.
		local lower = part(character, side .. "LowerArm")
		control.EndEffector = lower or hand
		local palmInLower = AnimationCarrySystem.palmInLowerOf(character, side)
		local shoulder = attachment(upper, side .. "ShoulderRigAttachment")
		local upperElbow = attachment(upper, side .. "ElbowRigAttachment")
		local lowerElbow = if lower ~= nil then attachment(lower, side .. "ElbowRigAttachment") else nil
		local contactWorld = cargoRoot.CFrame * contact
		local targetWorld = contactWorld
		if
			root ~= nil
			and lower ~= nil
			and palmInLower ~= nil
			and shoulder ~= nil
			and upperElbow ~= nil
			and lowerElbow ~= nil
		then
			control.EndEffectorOffset = palmInLower
			-- The contact as a palm frame: the palm faces its UpVector (`palms` layouts); on the cart the hand's -Y
			-- pointed into the item, so the palm faces that way.
			local facing = if palms then contactWorld.UpVector else -contactWorld.UpVector
			local upperArm = (shoulder.WorldPosition - upperElbow.WorldPosition).Magnitude
			local forearm = (palmInLower.Position - lowerElbow.Position).Magnitude
			-- The shoulder where the hold was planned: at rest on the torso (the hanging bag's targets ride it), else
			-- where it is.
			local upperRest = restFrameOf(upper, root)
			local from = if upperRest ~= nil
				then upperRest * shoulder.Position
				else root.CFrame:PointToObjectSpace(shoulder.WorldPosition)
			local palmAt = root.CFrame:PointToObjectSpace(contactWorld.Position)
			-- The elbows bend down and back by the sides, not out like wings, unless that runs the arm through a round
			-- body: then out to the side, the forearm coming back in to the item.
			local bend = AnimationCarryContactUtils.elbow(from, palmAt, upperArm, forearm, sign, POLE, body, BODY_PAD)
			local palmFrame = AnimationCarryContactUtils.neutralPalm(
				bend,
				palmAt,
				root.CFrame:VectorToObjectSpace(facing),
				lowerElbow.Position,
				palmInLower
			)
			targetWorld = root.CFrame * palmFrame
			-- The pole goes on past the elbow, square off the shoulder-palm line, so the engine bends it the same way;
			-- an arm stretched straight has no bend to point, so it keeps the default.
			local reach = palmAt - from
			local offAxis = bend - from
			if reach.Magnitude > 1e-3 then
				offAxis -= reach.Unit * offAxis:Dot(reach.Unit)
			end
			local poleAt = if offAxis.Magnitude > 0.02
				then bend + offAxis.Unit * upperArm
				else from + POLE * Vector3.new(sign, 1, 1) * upperArm
			local pole = Instance.new("Attachment")
			pole.Name = "CleanupCarryPole" .. side
			pole.Position = onFrame:PointToObjectSpace(root.CFrame:PointToWorldSpace(poleAt))
			pole.Parent = on
			table.insert(targets, pole)
			control.Pole = pole
		end
		target.CFrame = onFrame:ToObjectSpace(targetWorld)
		control.Target = target
		control.SmoothTime = 0.08
		control.Weight = 1
		control.Priority = 20
		control.Parent = humanoid
		table.insert(controls, control)
	end
	add("Right", rightUpper, rightHand, layout.right)
	if layout.left ~= nil then
		add("Left", leftUpper, leftHand, layout.left)
	end
	local controller: Controller = {
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			for _, control in controls do
				control:Destroy()
			end
			for _, target in targets do
				target:Destroy()
			end
			table.clear(controls)
			table.clear(targets)
		end,
	}
	table.insert(connections, cargoRoot.Destroying:Connect(controller.destroy))
	table.insert(connections, character.Destroying:Connect(controller.destroy))
	table.insert(connections, humanoid.Died:Connect(controller.destroy))
	table.insert(connections, humanoid.Destroying:Connect(controller.destroy))
	return controller
end
return AnimationCarrySystem
