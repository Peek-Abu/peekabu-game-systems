--!strict
--[=[
	VacuumVisualSystem: the backpack vacuum's visuals, from the approved template
	(ReplicatedStorage.Assets.CleanupCrew.Vacuum: `Backpack` pivoted at its mount, `Straps` pivoted at the torso
	they were modelled round, `Wand` pieces) or, when it is missing, VacuumVisualConstants' graybox pieces.

	The grip contract (characters/vacuum/README.md): a wand skin is complete only with two Attachments that say
	where the hands go: `GripUpper` on `WandGrip` (the right hand, on the upper grip by the hose joint) and
	`GripLower` on `WandTube` (the left hand, lower down the wand), each with +Y up the wand. GripUpper's offset
	is in the grip's studs; the tube is modelled one stud long and telescoped per holder, so GripLower's distance
	below the tube's top is kept (in studs as modelled) and the attachment is moved with the tube. The hold reads
	both (VacuumHoldFormulas: `upper` / `lower`), and the built wand carries them where the hands are.

	- `wear` puts the canister backpack on a character: welded to the UpperTorso at the employee's registry fit
	  (EmployeeRegistry.backpack, at the employee's scale; anyone else is fitted from their torso's size), straps
	  over the vest, the wand clipped upright to the pack's right side (the same wand as in the hand, its tube as
  long), and a hose (a textured, camera-facing Beam) from the
	  pack's outlet to the wand. `setHeld` unclips the stowed wand and runs the hose to the wand in the hand. The
	  gauge's dust insert carries its full size and Weld offset as attributes and starts empty (hidden); each
	  client sizes it to the owner's canister (VacuumFeedbackSystem).
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
local VacuumAssets = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumAssets)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local Constants = require(ServerScriptService.Features.Vacuum.Data.VacuumVisualConstants)
local VacuumHoldFormulas = require(ServerScriptService.Features.Vacuum.Utils.VacuumHoldFormulas)

export type WornBackpack = {
	model: Model,
	-- The held wand's hose inlet, or nil to stow the wand on the pack.
	setHeld: (inlet: Attachment?) -> (),
	destroy: () -> (),
}

type Piece = Constants.Piece
type Kit = { pack: Model, straps: Model?, wand: { [string]: BasePart }, kind: string }

local WAND_PIECES = { "WandGrip", "WandInlet", "WandTube", "WandSwivel", "FloorHead", "FloorHeadLip" }
local GRIPS = { Constants.grips.upper, Constants.grips.lower }

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

local function fromPiece(source: Piece): BasePart
	local part = Instance.new("Part")
	part.Name = source.name
	part.Shape = source.shape
	part.Size = source.size
	part.CFrame = source.frame
	part.Color = source.color
	part.Material = source.material
	part.Transparency = source.transparency
	return part
end

local function template(): Model?
	local current: Instance? = ReplicatedStorage
	for _, name in Constants.TEMPLATE_PATH do
		current = if current ~= nil then current:FindFirstChild(name) else nil
	end
	return if current ~= nil
			and current:IsA("Model")
			and current:GetAttribute("RuntimeApproved") == true
		then current
		else nil
end

-- A fresh copy of the art: the template's, or the graybox fallback (the pack pivoted at its mount).
local function kit(): Kit
	local source = template()
	if source ~= nil then
		local copy = source:Clone()
		local pack = copy:FindFirstChild("Backpack")
		local straps = copy:FindFirstChild("Straps")
		local wandFolder = copy:FindFirstChild("Wand")
		local wand: { [string]: BasePart } = {}
		if wandFolder ~= nil then
			for _, name in WAND_PIECES do
				local part = partOf(wandFolder, name)
				if part ~= nil then
					wand[name] = part
				end
			end
		end
		local complete = true
		for _, name in WAND_PIECES do
			local found: BasePart? = wand[name]
			complete = complete and found ~= nil
		end
		-- The grip contract: a wand without both grips is not a complete skin.
		for _, grip in GRIPS do
			local holder: BasePart? = wand[grip.piece]
			local found = if holder ~= nil then holder:FindFirstChild(grip.name) else nil
			complete = complete and found ~= nil and found:IsA("Attachment")
		end
		if pack ~= nil and pack:IsA("Model") and complete then
			pack.Parent = nil
			local strapModel = if straps ~= nil and straps:IsA("Model") then straps else nil
			if strapModel ~= nil then
				strapModel.Parent = nil
			end
			for _, part in wand do
				part.Parent = nil
			end
			copy:Destroy()
			return { pack = pack, straps = strapModel, wand = wand, kind = "approved-mesh" }
		end
		copy:Destroy()
	end
	local pack = Instance.new("Model")
	pack.Name = "Backpack"
	for _, piece in Constants.backpack do
		fromPiece(piece).Parent = pack
	end
	pack.WorldPivot = CFrame.identity
	local wand: { [string]: BasePart } = {}
	for _, piece in Constants.wand do
		wand[piece.name] = fromPiece(piece)
	end
	for _, grip in GRIPS do
		local attachment = Instance.new("Attachment")
		attachment.Name = grip.name
		attachment.Position = grip.position
		attachment.Parent = wand[grip.piece]
	end
	return { pack = pack, straps = nil, wand = wand, kind = "native-source" }
end

-- A grip Attachment of a complete kit (see `kit`).
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

--[=[
	`side` ("Left"/"Right") arm of `character` in HumanoidRootPart space, from its rig attachments (so it does not
	depend on the pose); nil when the rig lacks them.
]=]
function Visual.arm(character: Model, side: string): VacuumHoldFormulas.Arm?
	local root = character:FindFirstChild("HumanoidRootPart")
	local shoulder = attachmentOf(character, "UpperTorso", side .. "ShoulderRigAttachment")
	local upper = span(character, side .. "UpperArm", side .. "ShoulderRigAttachment", side .. "ElbowRigAttachment")
	local lower = span(character, side .. "LowerArm", side .. "ElbowRigAttachment", side .. "WristRigAttachment")
	local hand = span(character, side .. "Hand", side .. "WristRigAttachment", side .. "GripAttachment")
	if root == nil or not root:IsA("BasePart") or shoulder == nil or upper == nil or lower == nil or hand == nil then
		return nil
	end
	return {
		shoulder = root.CFrame:PointToObjectSpace(shoulder.WorldPosition),
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
	Builds the hand wand into `tool`, fitted to `holder` when given and measurable, and returns its handle and
	the hold (nil: unmeasured, held as a hanging hand holds it). Records `VacuumVisualKind` and `VacuumTube`.
]=]
function Visual.build(tool: Tool, holder: Model?): (BasePart, VacuumHoldFormulas.Hold?)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CFrame = CFrame.identity
	prepare(handle)
	handle.Parent = tool
	local fit, scale = Visual.fitOf(holder)
	local size = fit.size * scale
	local art = kit()
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
	Puts the canister backpack on `character` (see the class notes). Nil when it has no UpperTorso.
]=]
function Visual.wear(character: Model): WornBackpack?
	local torso = character:FindFirstChild("UpperTorso")
	if torso == nil or not torso:IsA("BasePart") then
		return nil
	end
	local fit, scale = Visual.fitOf(character)
	local size = fit.size * scale
	local art = kit()
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
	-- The wand on its holster: the same wand as in the hand (as big, its tube as long as this wearer's hold
	-- telescopes it), hanging upright down the pack's right side, its head turned along the side.
	local stowed = Instance.new("Model")
	stowed.Name = "StowedWand"
	local parts, dims, lipOffset = wandAt(art, size)
	-- The grip's lower end sits in the holster clip, so the long wand hangs as high as it can: its floor head
	-- stays off the floor and clear of the feet.
	local holster = mount * scaled(Constants.holster, size) * CFrame.new(0, dims.gripHalf, 0)
	local stowHold = holdFor(character, dims, size)
	local stowTube = if stowHold ~= nil then stowHold.tube else Constants.DEFAULT_TUBE * size
	local frames = VacuumHoldFormulas.wand(dims, stowTube, 0, math.pi / 2)
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
	local beam = hose(VacuumAssets.HOSE_TEXTURE, size)
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
		-- Empty until a client draws its owner's fill (no dust in a fresh canister, in the depot or before the
		-- first pile).
		fill.Transparency = 1
		fill:SetAttribute("GaugeFullSize", fill.Size)
		local weld = fill:FindFirstChild(VacuumConstants.GAUGE_WELD_NAME)
		if weld ~= nil and weld:IsA("Weld") then
			weld:SetAttribute("GaugeFullC0", weld.C0)
		end
	end
	model:SetAttribute("VacuumVisualKind", art.kind)
	model.Parent = character
	local destroyed = false
	return {
		model = model,
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
