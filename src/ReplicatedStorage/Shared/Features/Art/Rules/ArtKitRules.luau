--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtTypes = require(ReplicatedStorage.Shared.Features.Art.Data.ArtTypes)

local ArtKitRules = {}
function ArtKitRules.validKitId(id: string): boolean
	return #id > 0 and #id <= 80 and string.match(id, "^[%w_%-]+$") ~= nil
end
function ArtKitRules.fitMode(template: Model, family: ArtTypes.Family): ArtTypes.FitMode
	local mode = template:GetAttribute("FitMode")
	if mode == "Stretch" or family == "building" then
		return "Stretch"
	end
	return "Uniform"
end
local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end
local function finiteVector(v: Vector3): boolean
	return finite(v.X) and finite(v.Y) and finite(v.Z)
end
local function positive(n: number): boolean
	return n > 0 and n < math.huge
end
function ArtKitRules.validateTemplate(template: Model, family: ArtTypes.Family): boolean
	local size = template:GetAttribute("BaseSize")
	if
		template:GetAttribute("RuntimeApproved") ~= true
		or not template.Archivable
		or typeof(size) ~= "Vector3"
		or not positive(size.X)
		or not positive(size.Y)
		or not positive(size.Z)
	then
		return false
	end
	local opening = template:GetAttribute("OpeningWidth")
	if opening ~= nil and (type(opening) ~= "number" or not positive(opening) or opening > size.X) then
		return false
	end
	local mode = template:GetAttribute("FitMode")
	if mode ~= nil and mode ~= "Stretch" and mode ~= "Uniform" then
		return false
	end
	if family == "building" and mode == "Uniform" then
		return false
	end
	if #CollectionService:GetTags(template) > 0 then
		return false
	end
	local count = 0
	for _, child in template:GetDescendants() do
		if not child.Archivable or #CollectionService:GetTags(child) > 0 then
			return false
		end
		if child:IsA("Part") or child:IsA("MeshPart") then
			count += 1
		elseif
			not (
				child:IsA("Model")
				or child:IsA("Folder")
				or child:IsA("Attachment")
				or child:IsA("SurfaceAppearance")
				or child:IsA("Decal")
				or child:IsA("Texture")
			)
		then
			-- Reject code, humanoids, joints, prompts and other gameplay-bearing objects before cloning.
			return false
		end
	end
	if count == 0 then
		return false
	end
	local pivot = template:GetPivot()
	local bounds, boundsSize = template:GetBoundingBox()
	local centre = pivot:PointToObjectSpace(bounds.Position)
	if not finiteVector(centre) or not finiteVector(boundsSize) then
		return false
	end
	-- Author metadata must match the geometry; this also enforces a bottom-centred authored pivot.
	local tolerance = math.max(size.X, size.Y, size.Z) * 0.01 + 0.01
	if (boundsSize - size).Magnitude > tolerance or (centre - Vector3.new(0, size.Y / 2, 0)).Magnitude > tolerance then
		return false
	end
	return true
end
return ArtKitRules
