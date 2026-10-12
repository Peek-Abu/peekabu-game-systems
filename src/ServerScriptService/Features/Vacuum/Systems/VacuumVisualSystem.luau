--!strict
-- Composes original native source shapes; a validated artist-owned template takes precedence after import.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(script.Parent.Parent.Data.VacuumVisualConstants)
local Visual = {}
local function weldToGrip(part: BasePart, handle: BasePart)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
end
function Visual.build(tool: Tool): BasePart
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.24, 0.24, 0.24)
	handle.Transparency = 1
	handle.Massless = true
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Parent = tool
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local company = if assets ~= nil then assets:FindFirstChild("CleanupCrew") else nil
	local template = if company ~= nil then company:FindFirstChild("Vacuum") else nil
	if template ~= nil and template:IsA("Model") and template:GetAttribute("RuntimeApproved") == true then
		local model = template:Clone()
		model:PivotTo(CFrame.new())
		model.Parent = tool
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				weldToGrip(part, handle)
			end
		end
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
			part.Parent = tool
			weldToGrip(part, handle)
		end
		tool:SetAttribute("VacuumVisualKind", "native-source")
	end
	local mark = Instance.new("Attachment")
	mark.Name = "GripReference"
	mark.Parent = handle
	tool.Grip = Constants.grip
	return handle
end
return Visual
