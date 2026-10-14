--!strict
--[=[
	VacuumVisualSystem: composes the vacuum Tool's visual (the original native source shapes, or a validated
	artist-owned template once imported) around one invisible grip handle.

	The vacuum is an upright canister carried by its top handle: its floor head hangs about two studs below the
	grip, which is where a stock R15 avatar's hanging hand holds it. It is the same size for everyone. A shorter
	holder (a chibi employee) would bury it in the floor, so `build` fits the hold, not the vacuum: `hangHeight`
	measures how high the holder's hanging right arm holds the grip above the floor (from its rig attachments, so
	it does not depend on the pose it happens to be in), and VacuumHoldFormulas.fit gives the tilt about the grip
	(front up, applied here) and the hand lift (applied by AnimationVacuumHoldSystem while it is equipped) that
	rest the floor head on the floor. A stock avatar gets neither.

	@class VacuumVisualSystem
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(script.Parent.Parent.Data.VacuumVisualConstants)
local VacuumHoldFormulas = require(script.Parent.Parent.Utils.VacuumHoldFormulas)
local Visual = {}

local function prepare(part: BasePart)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function weldToGrip(part: BasePart, handle: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
end

-- Every corner of `parts`, in grip space (the handle is at the origin, +Y up, -Z front).
local function cornersOf(parts: { BasePart }): { Vector3 }
	local corners: { Vector3 } = {}
	for _, part in parts do
		local half = part.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					table.insert(corners, part.CFrame * Vector3.new(x * half.X, y * half.Y, z * half.Z))
				end
			end
		end
	end
	return corners
end

local function attachment(model: Model, partName: string, name: string): Attachment?
	local part = model:FindFirstChild(partName)
	local found = if part ~= nil then part:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Attachment") then found else nil
end

local function span(model: Model, partName: string, from: string, to: string): number?
	local a, b = attachment(model, partName, from), attachment(model, partName, to)
	return if a ~= nil and b ~= nil then (a.Position - b.Position).Magnitude else nil
end

--[=[
	How high (studs above the floor) `character`'s right arm, hanging straight down, holds its grip: the shoulder's
	height less the arm's length from shoulder to grip, read along the rig attachments. nil when the rig lacks them.
]=]
function Visual.hangHeight(character: Model): number?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local shoulder = attachment(character, "UpperTorso", "RightShoulderRigAttachment")
	local upper = span(character, "RightUpperArm", "RightShoulderRigAttachment", "RightElbowRigAttachment")
	local lower = span(character, "RightLowerArm", "RightElbowRigAttachment", "RightWristRigAttachment")
	local hand = span(character, "RightHand", "RightWristRigAttachment", "RightGripAttachment")
	if
		humanoid == nil
		or root == nil
		or not root:IsA("BasePart")
		or shoulder == nil
		or upper == nil
		or lower == nil
		or hand == nil
	then
		return nil
	end
	local floor = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	return shoulder.WorldPosition.Y - floor - (upper + lower + hand)
end

--[=[
	Builds the full-size vacuum visual into `tool`, its hold fitted to `holder` when given, and returns its handle.
	Records the fit on the tool: `VacuumHoldTilt` (degrees, front up), `VacuumHoldLift` (studs the hand is lifted)
	and `VacuumHoldHalfWidth` (studs, for keeping a lifted vacuum clear of the holder's body).
]=]
function Visual.build(tool: Tool, holder: Model?): BasePart
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.24, 0.24, 0.24)
	handle.Transparency = 1
	handle.Massless = true
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Parent = tool
	local hang = if holder ~= nil then Visual.hangHeight(holder) else nil
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local company = if assets ~= nil then assets:FindFirstChild("CleanupCrew") else nil
	local template = if company ~= nil then company:FindFirstChild("Vacuum") else nil
	local parts: { BasePart } = {}
	local tilt, lift, halfWidth = 0, 0, 0
	local function fit()
		local corners = cornersOf(parts)
		tilt, lift = VacuumHoldFormulas.fit(corners, hang, Constants.holdClearance, Constants.maxHoldTilt)
		for _, corner in corners do
			halfWidth = math.max(halfWidth, math.abs(corner.X))
		end
	end
	if template ~= nil and template:IsA("Model") and template:GetAttribute("RuntimeApproved") == true then
		local model = template:Clone()
		model:PivotTo(CFrame.new())
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
		fit()
		-- Turns about the pivot, which is the grip.
		model:PivotTo(CFrame.Angles(tilt, 0, 0))
		model.Parent = tool
		tool:SetAttribute("VacuumVisualKind", "approved-mesh")
	else
		for _, source in Constants.parts do
			local part = Instance.new("Part")
			part.Name = source.name
			part.Shape = source.shape
			part.Size = source.size
			part.CFrame = source.frame
			part.Color = source.color
			part.Material = if source.metal then Enum.Material.Metal else Enum.Material.SmoothPlastic
			table.insert(parts, part)
		end
		fit()
		local turn = CFrame.Angles(tilt, 0, 0)
		for _, part in parts do
			part.CFrame = turn * part.CFrame
			part.Parent = tool
		end
		tool:SetAttribute("VacuumVisualKind", "native-source")
	end
	for _, part in parts do
		prepare(part)
		weldToGrip(part, handle)
	end
	tool:SetAttribute("VacuumHoldTilt", math.deg(tilt))
	tool:SetAttribute("VacuumHoldLift", lift)
	tool:SetAttribute("VacuumHoldHalfWidth", halfWidth)
	local mark = Instance.new("Attachment")
	mark.Name = "GripReference"
	mark.Parent = handle
	tool.Grip = Constants.grip
	return handle
end
return Visual
