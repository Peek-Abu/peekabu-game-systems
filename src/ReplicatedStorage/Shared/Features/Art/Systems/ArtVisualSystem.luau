--!strict
-- Approved artist geometry decorates existing authoritative roots. No global active map/kit.
-- Proxy dimensions are fixed per attachment; reattach after a deliberate root Size change.
-- A solid (colliding) building or furniture proxy is flagged CameraOccluderConstants.ATTRIBUTE while its art shows:
-- the proxy is invisible, so the engine's Poppercam looks straight through it, and the camera's own occlusion pass
-- (CameraOcclusionSystem) needs the flag to stop at the art's outer face instead of inside the wall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraOccluderConstants = require(ReplicatedStorage.Shared.Features.Camera.Data.CameraOccluderConstants)
local ArtShared = ReplicatedStorage.Shared.Features.Art
local ArtTypes = require(ArtShared.Data.ArtTypes)
local ArtKitRegistry = require(ArtShared.Data.ArtKitRegistry)
local ArtKitRules = require(ArtShared.Rules.ArtKitRules)

type VisualRecord = {
	model: Model,
	originalRootTransparency: number,
	transparency: { [BasePart]: number },
	connections: { RBXScriptConnection },
	-- Whether the proxy stands in for solid art the camera must not pass (CameraOccluderConstants).
	occludes: boolean,
}
export type Controller = {
	resolveKit: (instance: Instance) -> string,
	attach: (root: BasePart, family: ArtTypes.Family, assetKey: string, kitId: string?, hidden: boolean?) -> Model?,
	setHidden: (root: BasePart, hidden: boolean) -> (),
	detach: (root: BasePart) -> (),
}

local function create(assetRoot: Instance?): Controller
	local records: { [BasePart]: VisualRecord } = {}
	local ArtVisualSystem = {}

	function ArtVisualSystem.resolveKit(instance: Instance): string
		local current: Instance? = instance
		while current ~= nil do
			local id = current:GetAttribute("ArtKitId")
			if type(id) == "string" and ArtKitRules.validKitId(id) then
				return id
			end
			current = current.Parent
		end
		return ArtKitRegistry.DEFAULT_KIT
	end

	local function templateFor(kitId: string, family: ArtTypes.Family, key: string): Model?
		if not ArtKitRules.validKitId(kitId) or not ArtKitRules.validKitId(key) then
			return nil
		end
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local crew = if assets then assets:FindFirstChild("CleanupCrew") else nil
		local kits = assetRoot or (if crew then crew:FindFirstChild("ArtKits") else nil)
		local kit = if kits then kits:FindFirstChild(kitId) else nil
		local group = if kit then kit:FindFirstChild(family) else nil
		local model = if group then group:FindFirstChild(key) else nil
		if model ~= nil and model:IsA("Model") and ArtKitRules.validateTemplate(model, family) then
			return model
		end
		return nil
	end

	function ArtVisualSystem.detach(root: BasePart)
		local record = records[root]
		if record == nil then
			return
		end
		records[root] = nil
		root:SetAttribute("ArtSupportSurfaceY", nil)
		root:SetAttribute(CameraOccluderConstants.ATTRIBUTE, nil)
		for _, connection in record.connections do
			connection:Disconnect()
		end
		record.model:Destroy()
		root.Transparency = record.originalRootTransparency
	end

	function ArtVisualSystem.setHidden(root: BasePart, hidden: boolean)
		local record = records[root]
		if record == nil then
			return
		end
		root.Transparency = 1
		for part, transparency in record.transparency do
			part.Transparency = if hidden then 1 else transparency
		end
		root:SetAttribute(CameraOccluderConstants.ATTRIBUTE, if record.occludes and not hidden then true else nil)
	end

	function ArtVisualSystem.attach(
		root: BasePart,
		family: ArtTypes.Family,
		assetKey: string,
		kitId: string?,
		hidden: boolean?
	): Model?
		local selectedKit = kitId or ArtVisualSystem.resolveKit(root)
		local template = templateFor(selectedKit, family, assetKey)
		if template == nil then
			return nil
		end
		local baseSize = template:GetAttribute("BaseSize")
		if typeof(baseSize) ~= "Vector3" then
			return nil
		end
		local targetSize = root.Size
		local desiredOpening = root:GetAttribute("ArtOpeningWidth")
		if family == "building" and desiredOpening ~= nil then
			local authoredOpening = template:GetAttribute("OpeningWidth")
			if
				type(desiredOpening) ~= "number"
				or desiredOpening <= 0
				or desiredOpening >= math.huge
				or desiredOpening ~= desiredOpening
				or type(authoredOpening) ~= "number"
				or authoredOpening <= 0
				or authoredOpening > baseSize.X
			then
				return nil
			end
			-- Doorframe outer bounds may exceed its noncolliding proxy; the clear opening must
			-- match gameplay width. Ordinary walls/floors still fit the full proxy dimensions.
			local width = desiredOpening * baseSize.X / authoredOpening
			if width >= math.huge then
				return nil
			end
			targetSize = Vector3.new(width, root.Size.Y, root.Size.Z)
		end
		local scale = targetSize / baseSize
		if ArtKitRules.fitMode(template, family) == "Uniform" then
			local minimum = math.min(scale.X, scale.Y, scale.Z)
			scale = Vector3.new(minimum, minimum, minimum)
		end
		local pivot = template:GetPivot()
		-- Anisotropic fit is exact for a single aligned MeshPart export. Rotated piece assemblies
		-- cannot be stretched by changing local Size alone; reject those rather than distort coverage.
		if math.abs(scale.X - scale.Y) > 0.001 or math.abs(scale.Y - scale.Z) > 0.001 then
			for _, child in template:GetDescendants() do
				if child:IsA("BasePart") then
					local relative = pivot:ToObjectSpace(child.CFrame)
					if
						(relative.RightVector - Vector3.xAxis).Magnitude > 0.001
						or (relative.UpVector - Vector3.yAxis).Magnitude > 0.001
					then
						return nil
					end
				end
			end
		end
		local clone = template:Clone()
		clone.Name = "ArtVisual"
		clone:SetAttribute("ArtKitId", selectedKit)
		local transparency: { [BasePart]: number } = {}
		local authoredPivot = clone:GetPivot()
		clone.PrimaryPart = nil
		clone.WorldPivot = authoredPivot
		for _, child in clone:GetDescendants() do
			if child:IsA("BasePart") then
				local relative = authoredPivot:ToObjectSpace(child.CFrame)
				child.Size *= scale
				child.CFrame = authoredPivot * CFrame.new(relative.Position * scale) * relative.Rotation
				child.CanCollide = false
				child.CanQuery = false
				child.CanTouch = false
				child.Massless = true
				child.Anchored = root.Anchored
				transparency[child] = child.Transparency
			elseif child:IsA("Attachment") then
				child.Position *= scale
			end
		end
		-- Cache root-local frames before welding. A Model without PrimaryPart has a stored
		-- WorldPivot that does not follow physics; repeatedly PivotTo-ing that stale pivot
		-- would move already-welded geometry twice when its root moves.
		local frames: { [BasePart]: CFrame } = {}
		-- Runtime roots face -Z. Imported glTF furniture may face +Z; normalize the visual only.
		local front = if (family == "furniture" or family == "cargo")
				and template:GetAttribute("FrontAxis") == "PositiveZ"
			then CFrame.Angles(0, math.pi, 0)
			else CFrame.identity
		local rearOffset = if root:GetAttribute("ArtWallMounted") == true
			then (root.Size.Z - baseSize.Z * scale.Z) / 2
			else 0
		for part in transparency do
			frames[part] = CFrame.new(0, -root.Size.Y / 2, rearOffset)
				* front
				* authoredPivot:ToObjectSpace(part.CFrame)
		end
		local function align()
			for part, frame in frames do
				part.CFrame = root.CFrame * frame
			end
			clone.WorldPivot = root.CFrame * CFrame.new(0, -root.Size.Y / 2, 0)
		end
		align()
		for part in transparency do
			local weld = Instance.new("WeldConstraint")
			weld.Name = "ArtRootWeld"
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
		local originalTransparency = root.Transparency
		local existing = records[root]
		if existing then
			originalTransparency = existing.originalRootTransparency
		end
		ArtVisualSystem.detach(root)
		local record: VisualRecord = {
			model = clone,
			originalRootTransparency = originalTransparency,
			transparency = transparency,
			connections = {},
			occludes = (family == "building" or family == "furniture") and root.CanCollide,
		}
		records[root] = record
		local support = template:GetAttribute("SupportSurfaceY")
		if type(support) == "number" and support == support and support > 0 and support <= baseSize.Y then
			root:SetAttribute("ArtSupportSurfaceY", support * scale.Y)
		end
		clone.Parent = root
		table.insert(record.connections, root:GetPropertyChangedSignal("CFrame"):Connect(align))
		table.insert(
			record.connections,
			root:GetPropertyChangedSignal("Anchored"):Connect(function()
				for part in transparency do
					part.Anchored = root.Anchored
				end
			end)
		)
		table.insert(
			record.connections,
			root.Destroying:Connect(function()
				ArtVisualSystem.detach(root)
			end)
		)
		table.insert(
			record.connections,
			clone.Destroying:Connect(function()
				if records[root] ~= record then
					return
				end
				records[root] = nil
				root:SetAttribute("ArtSupportSurfaceY", nil)
				root:SetAttribute(CameraOccluderConstants.ATTRIBUTE, nil)
				for _, connection in record.connections do
					connection:Disconnect()
				end
				root.Transparency = record.originalRootTransparency
			end)
		)
		ArtVisualSystem.setHidden(root, hidden == true)
		return clone
	end
	return ArtVisualSystem
end

local ArtVisualSystem = create(nil)
return {
	resolveKit = ArtVisualSystem.resolveKit,
	attach = ArtVisualSystem.attach,
	setHidden = ArtVisualSystem.setHidden,
	detach = ArtVisualSystem.detach,
	new = create,
}
