--!strict
--[=[
	VacuumVisualSystem: composes the vacuum Tool's visual (the original native source shapes, or a validated
	artist-owned template once imported) around one invisible grip handle.

	The vacuum is an upright canister carried by its top handle: at full size its floor head hangs about two studs
	below the grip, which is where a stock R15 avatar's hanging hand holds it. A shorter holder (a chibi employee)
	would bury it in the floor, so `build` fits it to the holder: `hangHeight` measures how high the holder's
	hanging right arm holds the grip above the floor (from its rig attachments, so it does not depend on the pose
	it happens to be in), and `holdScale` shrinks the vacuum about the grip just enough to clear the floor
	(never enlarged; a stock avatar keeps it at full size).

	@class VacuumVisualSystem
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(script.Parent.Parent.Data.VacuumVisualConstants)
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

-- How far (studs) the lowest corner of `parts` sits below the grip origin (the handle is at the origin, +Y up).
local function dropBelowGrip(parts: { BasePart }): number
	local low = 0
	for _, part in parts do
		local half = part.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					low = math.min(low, (part.CFrame * Vector3.new(x * half.X, y * half.Y, z * half.Z)).Y)
				end
			end
		end
	end
	return -low
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
	The scale the vacuum is built at for a holder whose grip hangs `hang` studs above the floor, when at full size
	its lowest point is `drop` studs below the grip: 1 when it already clears the floor (or nothing is known),
	otherwise just small enough to clear it by `holdClearance`, floored at `minHoldScale`.
]=]
function Visual.holdScale(hang: number?, drop: number): number
	if hang == nil or drop <= 0 then
		return 1
	end
	return math.clamp((hang - Constants.holdClearance) / drop, Constants.minHoldScale, 1)
end

--[=[
	Builds the vacuum visual into `tool`, fitted to `holder` when given (see `holdScale`), and returns its handle.
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
	local scale = 1
	if template ~= nil and template:IsA("Model") and template:GetAttribute("RuntimeApproved") == true then
		local model = template:Clone()
		model:PivotTo(CFrame.new())
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
		scale = Visual.holdScale(hang, dropBelowGrip(parts))
		if scale < 1 then
			-- Scales about the pivot, which is the grip.
			model:ScaleTo(model:GetScale() * scale)
		end
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
		scale = Visual.holdScale(hang, dropBelowGrip(parts))
		for _, part in parts do
			if scale < 1 then
				part.Size *= scale
				part.CFrame = CFrame.new(part.CFrame.Position * scale) * part.CFrame.Rotation
			end
			part.Parent = tool
		end
		tool:SetAttribute("VacuumVisualKind", "native-source")
	end
	for _, part in parts do
		prepare(part)
		weldToGrip(part, handle)
	end
	tool:SetAttribute("VacuumHoldScale", scale)
	local mark = Instance.new("Attachment")
	mark.Name = "GripReference"
	mark.Parent = handle
	tool.Grip = Constants.grip
	return handle
end
return Visual
