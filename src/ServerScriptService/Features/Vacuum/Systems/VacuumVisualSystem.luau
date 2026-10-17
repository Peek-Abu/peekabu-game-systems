--!strict
--[=[
	VacuumVisualSystem: the backpack vacuum's visuals in the wearer's skin (VacuumSkinRegistry): the art is a fresh
	copy of the skin's approved template, or the graybox (VacuumKitUtils.kit). Every skin is built on the same
	geometry (characters/vacuum), so only its art and its hose texture differ.

	The grip contract (characters/vacuum/README.md): a wand skin is complete only with two Attachments that say
	where the hands go: `GripUpper` on `WandGrip` (the right hand, on the upper grip by the hose joint) and
	`GripLower` on `WandTube` (the left hand, lower down the wand), each with +Y up the wand. GripUpper's offset
	is in the grip's studs; the tube is modelled one stud long and telescoped per holder, so GripLower's distance
	below the tube's top is kept (in studs as modelled) and the attachment is moved with the tube. The hold reads
	both (VacuumHoldFormulas: `upper` / `lower`), and the built wand carries them where the hands are.

	- `wear` puts the canister backpack on a character: welded to the UpperTorso at the employee's registry fit
	  (EmployeeRegistry.backpack, at the employee's scale; anyone else is fitted from their torso's size), straps
	  over the vest, the wand clipped to the pack's right side (the same wand as in the hand, its tube telescoped
	  in, leaning out and back so its floor head hangs at hip height: VacuumVisualConstants.stow), and a hose (a
	  textured, camera-facing Beam) from the pack's outlet to the wand. `setHeld` unclips the stowed wand and runs the hose to the wand in the hand. The
	  gauge's dust insert carries its full size and Weld offset as attributes and starts empty (hidden); each
	  client sizes it to the crew's Gloom against the contract (VacuumFeedbackSystem).
	- `build` makes the hand wand inside the Tool: the grip at the handle, the wand leaning forward and its tube
	  telescoped so the floor head rests flat on the floor from the holder's grip (VacuumHoldFormulas.hold, read
	  from the holder's rig attachments). The hold it returns drives the arms (AnimationVacuumHoldSystem).

	Every employee wears the backpack as part of their look, in the depot as on a shift (VacuumServiceServer
	puts it on each character as it spawns); the shift's Tool only takes the wand off it and puts it back.

	@class VacuumVisualSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumSkinRegistry = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)
local VacuumSkinRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumSkinRules)
local Constants = require(ServerScriptService.Features.Vacuum.Data.VacuumVisualConstants)
local VacuumHoldFormulas = require(ServerScriptService.Features.Vacuum.Utils.VacuumHoldFormulas)
local VacuumKitUtils = require(ServerScriptService.Features.Vacuum.Utils.VacuumKitUtils)
local AnimationCarryMeasureSystem = require(ServerScriptService.Features.Animation.Systems.AnimationCarryMeasureSystem)

export type WornBackpack = {
	model: Model,
	-- The skin it wears (the Tool builds its hand wand in the same one).
	skin: VacuumSkinRegistry.SkinDef,
	-- The held wand's hose inlet, or nil to stow the wand on the pack.
	setHeld: (inlet: Attachment?) -> (),
	destroy: () -> (),
}

type Kit = VacuumKitUtils.Kit

local Visual = {}

local function prepare(part: BasePart)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function partOf(container: Instance, name: string): BasePart?
	local found = container:FindFirstChild(name, true)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

local function attachmentOf(model: Model, partName: string, name: string): Attachment?
	local part = model:FindFirstChild(partName)
	local found = if part ~= nil then part:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Attachment") then found else nil
end

local function span(model: Model, partName: string, from: string, to: string): number?
	local a, b = attachmentOf(model, partName, from), attachmentOf(model, partName, to)
	return if a ~= nil and b ~= nil then (a.Position - b.Position).Magnitude else nil
end

-- A grip Attachment of a complete kit (VacuumKitUtils.kit).
local function gripOf(parts: { [string]: BasePart }, grip: { piece: string, name: string }): Attachment
	local found = parts[grip.piece]:FindFirstChild(grip.name)
	assert(found ~= nil and found:IsA("Attachment"), `wand has no {grip.name}`)
	return found
end

-- The wand's pieces scaled to `size` (their grips with them), and their measurements. The lip keeps its place
-- on the floor head.
local function wandAt(kit_: Kit, size: number): ({ [string]: BasePart }, VacuumHoldFormulas.WandDims, CFrame)
	local parts = kit_.wand
	local head, lip = parts.FloorHead, parts.FloorHeadLip
	local rel = head.CFrame:ToObjectSpace(lip.CFrame)
	local upper, lower = gripOf(parts, Constants.grips.upper), gripOf(parts, Constants.grips.lower)
	-- GripLower's distance below the tube's top, as modelled.
	local belowTop = parts.WandTube.Size.Y / 2 - lower.Position.Y
	for _, part in parts do
		part.Size *= size
	end
	upper.Position *= size
	lower.Position *= size
	local dims: VacuumHoldFormulas.WandDims = {
		gripHalf = parts.WandGrip.Size.Y / 2,
		inlet = parts.WandInlet.Size.Y,
		swivel = parts.WandSwivel.Size.Y / 2,
		head = head.Size.Y,
		upper = upper.Position.Y,
		lower = belowTop * size,
	}
	return parts, dims, CFrame.new(rel.Position * size) * rel.Rotation
end

-- Lays the wand's pieces out from `origin` (the grip) with a `tube` this long; GripLower stays `dims.lower` below
-- the tube's top (at most the whole tube).
local function layWand(
	parts: { [string]: BasePart },
	frames: VacuumHoldFormulas.WandFrames,
	lipOffset: CFrame,
	origin: CFrame,
	tube: number,
	dims: VacuumHoldFormulas.WandDims
)
	parts.WandGrip.CFrame = origin * frames.grip
	parts.WandInlet.CFrame = origin * frames.inlet
	local tubePart = parts.WandTube
	tubePart.Size = Vector3.new(tubePart.Size.X, tube, tubePart.Size.Z)
	tubePart.CFrame = origin * frames.tube
	local lower = gripOf(parts, Constants.grips.lower)
	lower.Position = Vector3.new(lower.Position.X, tube / 2 - math.min(dims.lower, tube), lower.Position.Z)
	parts.WandSwivel.CFrame = origin * frames.swivel
	parts.FloorHead.CFrame = origin * frames.head
	parts.FloorHeadLip.CFrame = parts.FloorHead.CFrame * lipOffset
end

local function weldTo(part: BasePart, torso: BasePart, name: string)
	prepare(part)
	local weld = Instance.new("Weld")
	weld.Name = name
	weld.Part0 = torso
	weld.Part1 = part
	weld.C0 = torso.CFrame:ToObjectSpace(part.CFrame)
	weld.Parent = part
end

local function scaled(frame: CFrame, scale: number): CFrame
	return CFrame.new(frame.Position * scale) * frame.Rotation
end

-- The right hip joint in `torso`'s space at the rig's rest pose (the Waist joint's C0 / C1, not an animated frame),
-- or the root's centre (live) on a rig without one, else the torso's bottom.
local function hipInTorso(character: Model, torso: BasePart): Vector3
	local waist: Motor6D? = nil
	for _, child in torso:GetChildren() do
		if child:IsA("Motor6D") and child.Part1 == torso and child.Part0 ~= nil then
			waist = child
			break
		end
	end
	if waist ~= nil and waist.Part0 ~= nil then
		local hip = waist.Part0:FindFirstChild("RightHipRigAttachment")
		if hip ~= nil and hip:IsA("Attachment") then
			-- torso = lower * C0 * C1:Inverse(), so lower in torso space is C1 * C0:Inverse().
			return (waist.C1 * waist.C0:Inverse()) * hip.Position
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return torso.CFrame:PointToObjectSpace(root.Position)
	end
	return Vector3.new(0, -torso.Size.Y / 2, 0)
end

--[=[
	`side` ("Left"/"Right") arm of `character` in HumanoidRootPart space, from its rig attachments, with the shoulder
	where it is at the rig's REST pose (its joint chain without the animation's Transforms,
	AnimationCarryMeasureSystem.restFrame), so the hold never depends on the pose of the moment it is planned in. The
	Tool is made as a shift starts, mid-stride or while the crew is placed in the truck: read live, Pippa's shoulders
	were once measured 0.43 stud forward of rest, the left hand's target lay out of her reach, and that arm hung at
	full stretch, swaying with the idle, 0.21-0.30 stud off the wand. Nil when the rig lacks the attachments.
]=]
function Visual.arm(character: Model, side: string): VacuumHoldFormulas.Arm?
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("UpperTorso")
	local shoulder = attachmentOf(character, "UpperTorso", side .. "ShoulderRigAttachment")
	local upper = span(character, side .. "UpperArm", side .. "ShoulderRigAttachment", side .. "ElbowRigAttachment")
	local lower = span(character, side .. "LowerArm", side .. "ElbowRigAttachment", side .. "WristRigAttachment")
	local hand = span(character, side .. "Hand", side .. "WristRigAttachment", side .. "GripAttachment")
	if
		root == nil
		or not root:IsA("BasePart")
		or torso == nil
		or not torso:IsA("BasePart")
		or shoulder == nil
		or upper == nil
		or lower == nil
		or hand == nil
	then
		return nil
	end
	return {
		shoulder = AnimationCarryMeasureSystem.restFrame(torso, root):PointToWorldSpace(shoulder.Position),
		upper = upper,
		lower = lower + hand,
	}
end

--[=[
	Where `character`'s backpack sits and the scale its fit is in: the employee's registry fit at the
	employee's scale, else one fitted from its UpperTorso's size (scale 1).
]=]
function Visual.fitOf(character: Model?): (EmployeeRegistry.BackpackFit, number)
	local name = if character ~= nil then character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) else nil
	local def = if type(name) == "string" then EmployeeRegistry.get(name) else nil
	if def ~= nil and def.backpack ~= nil then
		return def.backpack, def.scale
	end
	local torso = if character ~= nil then character:FindFirstChild("UpperTorso") else nil
	local size = if torso ~= nil and torso:IsA("BasePart")
		then torso.Size
		else Constants.REFERENCE_TORSO * Constants.GENERIC_SIZE
	return VacuumHoldFormulas.genericFit(size, Constants.REFERENCE_TORSO, Constants.STRAP_DEPTH, Constants.GENERIC_SIZE),
		1
end

-- The hold for `holder` with a wand this big, or nil when its arms cannot be measured.
local function holdFor(holder: Model, dims: VacuumHoldFormulas.WandDims, size: number): VacuumHoldFormulas.Hold?
	local humanoid = holder:FindFirstChildOfClass("Humanoid")
	local root = holder:FindFirstChild("HumanoidRootPart")
	local right = Visual.arm(holder, "Right")
	if humanoid == nil or root == nil or not root:IsA("BasePart") or right == nil then
		return nil
	end
	local tuning = Constants.hold
	return VacuumHoldFormulas.hold(right, Visual.arm(holder, "Left"), -(root.Size.Y / 2 + humanoid.HipHeight), dims, {
		down = tuning.down,
		forward = tuning.forward,
		out = tuning.out,
		angle = tuning.angle,
		yaw = tuning.yaw,
		clearance = tuning.clearance * size,
		minTube = tuning.minTube * size,
	})
end

--[=[
	Builds the hand wand into `tool` in `skin` (Standard Issue when nil), fitted to `holder` when given and
	measurable, and returns its handle and the hold (nil: unmeasured, held as a hanging hand holds it). Records
	`VacuumVisualKind`, `VacuumSkin` and `VacuumTube`.
]=]
function Visual.build(
	tool: Tool,
	holder: Model?,
	skin: VacuumSkinRegistry.SkinDef?
): (BasePart, VacuumHoldFormulas.Hold?)
	local worn = skin or VacuumSkinRules.select(nil)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CFrame = CFrame.identity
	prepare(handle)
	handle.Parent = tool
	local fit, scale = Visual.fitOf(holder)
	local size = fit.size * scale
	local art = VacuumKitUtils.kit(worn)
	local parts, dims, lipOffset = wandAt(art, size)
	local hold = if holder ~= nil then holdFor(holder, dims, size) else nil
	local tube = if hold ~= nil then hold.tube else Constants.DEFAULT_TUBE * size
	local frames = VacuumHoldFormulas.wand(dims, tube, Constants.hold.angle, nil, Constants.hold.yaw)
	layWand(parts, frames, lipOffset, CFrame.identity, tube, dims)
	for _, part in parts do
		prepare(part)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Parent = tool
	end
	local inlet = Instance.new("Attachment")
	inlet.Name = "HoseInlet"
	inlet.CFrame = frames.hose
	inlet.Parent = handle
	art.pack:Destroy()
	if art.straps ~= nil then
		art.straps:Destroy()
	end
	tool.Grip = if hold ~= nil then hold.toolGrip else Constants.DEFAULT_GRIP
	tool:SetAttribute("VacuumVisualKind", art.kind)
	tool:SetAttribute("VacuumSkin", worn.name)
	tool:SetAttribute("VacuumTube", tube)
	return handle, hold
end

-- Stretches a model's parts about its pivot (x across, y up, z through), for straps on another torso.
local function stretch(model: Model, by: Vector3)
	if by == Vector3.one then
		return
	end
	local pivot = model:GetPivot()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(part.CFrame)
			part.Size *= by
			part.CFrame = pivot * CFrame.new(rel.Position * by) * rel.Rotation
		end
	end
end

local function hose(texture: string, size: number): Beam
	local tuning = Constants.hose
	local beam = Instance.new("Beam")
	beam.Name = "VacuumHose"
	beam.Texture = texture
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = tuning.tile * size
	beam.TextureSpeed = 0
	beam.Width0 = tuning.width * size
	beam.Width1 = tuning.width * size
	beam.CurveSize0 = tuning.curveStowed * size
	beam.CurveSize1 = tuning.curve1 * size
	beam.Segments = tuning.segments
	beam.FaceCamera = true
	beam.LightInfluence = 1
	beam.Color = ColorSequence.new(if texture == "" then Color3.fromRGB(46, 53, 54) else Color3.new(1, 1, 1))
	return beam
end

--[=[
	Puts the canister backpack on `character` in `skin` (Standard Issue when nil; see the class notes). Nil when it
	has no UpperTorso. Records `VacuumVisualKind` and `VacuumSkin` on the pack.
]=]
function Visual.wear(character: Model, skin: VacuumSkinRegistry.SkinDef?): WornBackpack?
	local worn = skin or VacuumSkinRules.select(nil)
	local torso = character:FindFirstChild("UpperTorso")
	if torso == nil or not torso:IsA("BasePart") then
		return nil
	end
	local fit, scale = Visual.fitOf(character)
	local size = fit.size * scale
	local art = VacuumKitUtils.kit(worn)
	local model = Instance.new("Model")
	model.Name = VacuumConstants.BACKPACK_NAME
	local mount = torso.CFrame * scaled(fit.mount, scale)
	local pack = art.pack
	pack.Name = "Pack"
	pack:ScaleTo(size)
	pack:PivotTo(mount)
	pack.Parent = model
	local straps = art.straps
	if straps ~= nil then
		straps:ScaleTo(scale)
		stretch(straps, fit.strapStretch)
		straps:PivotTo(torso.CFrame * scaled(fit.strapOffset, scale))
		straps.Parent = model
	end
	-- The wand on its holster: the same wand as in the hand (as big), its tube telescoped in, leaning out and
	-- back along the pack's right side with its floor head at hip height (Constants.stow).
	local stowed = Instance.new("Model")
	stowed.Name = "StowedWand"
	local parts, dims, lipOffset = wandAt(art, size)
	-- The grip's lower end sits in the holster clip.
	local holster = mount * scaled(Constants.holster, size) * CFrame.new(0, dims.gripHalf, 0)
	local stowHold = holdFor(character, dims, size)
	local heldTube = if stowHold ~= nil then stowHold.tube else Constants.DEFAULT_TUBE * size
	local stow = Constants.stow
	local stowTube = VacuumHoldFormulas.stowTube(
		(torso.CFrame:ToObjectSpace(holster).Position - hipInTorso(character, torso)).Y,
		dims,
		stow.lean,
		Constants.hold.minTube * size,
		heldTube
	)
	local frames = VacuumHoldFormulas.wand(dims, stowTube, stow.lean, stow.turn, stow.turn)
	layWand(parts, frames, lipOffset, holster, stowTube, dims)
	for _, part in parts do
		part.Parent = stowed
	end
	local stowedInlet = Instance.new("Attachment")
	stowedInlet.Name = "HoseInlet"
	stowedInlet.CFrame = parts.WandGrip.CFrame:ToObjectSpace(holster * frames.hose)
	stowedInlet.Parent = parts.WandGrip
	stowed.Parent = model
	-- The hose, from the outlet.
	local outletPart = partOf(pack, "HoseOutlet") or torso
	local outlet = Instance.new("Attachment")
	outlet.Name = "HoseMount"
	outlet.CFrame = outletPart.CFrame:ToObjectSpace(mount * scaled(Constants.outlet, size))
	outlet.Parent = outletPart
	local beam = hose(worn.hoseTexture, size)
	beam.Attachment0 = outlet
	beam.Attachment1 = stowedInlet
	beam.Parent = model
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			weldTo(
				part,
				torso,
				if part.Name == VacuumConstants.GAUGE_FILL_NAME then VacuumConstants.GAUGE_WELD_NAME else "VacuumWeld"
			)
		end
	end
	local fill = partOf(pack, VacuumConstants.GAUGE_FILL_NAME)
	if fill ~= nil then
		-- Empty until a client draws the contract's fill (no dust in a fresh canister, in the depot or before the
		-- first pile).
		fill.Transparency = 1
		fill:SetAttribute("GaugeFullSize", fill.Size)
		local weld = fill:FindFirstChild(VacuumConstants.GAUGE_WELD_NAME)
		if weld ~= nil and weld:IsA("Weld") then
			weld:SetAttribute("GaugeFullC0", weld.C0)
		end
	end
	model:SetAttribute("VacuumVisualKind", art.kind)
	model:SetAttribute("VacuumSkin", worn.name)
	model.Parent = character
	local destroyed = false
	return {
		model = model,
		skin = worn,
		setHeld = function(inlet)
			if destroyed then
				return
			end
			if inlet ~= nil then
				stowed.Parent = nil
				beam.Attachment1 = inlet
				beam.CurveSize0 = Constants.hose.curveHeld * size
			else
				stowed.Parent = model
				beam.Attachment1 = stowedInlet
				beam.CurveSize0 = Constants.hose.curveStowed * size
			end
		end,
		destroy = function()
			destroyed = true
			stowed:Destroy()
			model:Destroy()
		end,
	}
end

return Visual
