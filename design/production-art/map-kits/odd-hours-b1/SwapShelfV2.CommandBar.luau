--[[
	c_bookshelf v2 swap (owner OK 2026-11-12; KIT_MAP.md "c_bookshelf v2"). Run in Studio Edit in each place: it swaps
	every v1 bookshelf MeshPart in the place (the art kit's `shelf` template, the hub's shelves, the training island) to
	v2 in place. Idempotent: only meshes still on the v1 mesh id are touched.

	v1's bounds were 5.54 wide because its bottom-right book stack ran 0.38 through the side panel; v2 is 5.16. A
	placed v1 part of Size.X = 5.54 x s gets Size.X = 5.16 x s and moves 0.19 x s along its own +X (v1's bounds centre
	sat 0.19 off the shelf's middle, toward the stack), so its panels stay where they were.

	Pair with OfficeConstants.ART_SIZES.shelf = 5.16 x 8 x 2.08 (the Office proxy follows the kit art's size).
]]

local InsertService = game:GetService("InsertService")

local V1_MODEL = 82298001439367
local V2 = { model = 126189823139386, color = 77467087166620, normal = 114066087139539, rough = 137947715230076 }

local function image(decalId: number): string
	local m = InsertService:LoadAsset(decalId)
	local d = m:FindFirstChildWhichIsA("Decal", true)
	local texture = if d then d.Texture else "rbxassetid://" .. decalId
	m:Destroy()
	return texture
end

local v1 = InsertService:LoadAsset(V1_MODEL)
local oldMesh = (v1:FindFirstChildWhichIsA("MeshPart", true) :: MeshPart).MeshId
v1:Destroy()
local v2 = InsertService:LoadAsset(V2.model)
local source = v2:FindFirstChildWhichIsA("MeshPart", true) :: MeshPart
local color, normal, rough = image(V2.color), image(V2.normal), image(V2.rough)

local swapped = {}
for _, d in game:GetDescendants() do
	local ok, isMesh = pcall(function()
		return d:IsA("MeshPart")
	end)
	if ok and isMesh and d ~= source and (d :: MeshPart).MeshId == oldMesh then
		local part = d :: MeshPart
		local s = part.Size.X / 5.54
		-- An art kit template (a Model with BaseSize) keeps its mesh centred on the template's pivot and records the
		-- new size; a placed shelf keeps its panels where they were.
		local template = part.Parent
		local isTemplate = template ~= nil and template:IsA("Model") and template:GetAttribute("BaseSize") ~= nil
		local frame = if isTemplate then part.CFrame else part.CFrame * CFrame.new(0.19 * s, 0, 0)
		if isTemplate then
			local base = template:GetAttribute("BaseSize") :: Vector3
			template:SetAttribute("BaseSize", Vector3.new(base.X * 5.16 / 5.54, base.Y, base.Z))
		end
		local size = Vector3.new(5.16 * s, part.Size.Y, part.Size.Z)
		part:ApplyMesh(source)
		part.Size = size
		part.CFrame = frame
		local sa = part:FindFirstChildWhichIsA("SurfaceAppearance") or Instance.new("SurfaceAppearance")
		sa.ColorMap = color
		sa.NormalMap = normal
		sa.RoughnessMap = rough
		sa.Parent = part
		table.insert(swapped, part:GetFullName())
	end
end
v2:Destroy()
return #swapped .. " swapped:\n" .. table.concat(swapped, "\n")
