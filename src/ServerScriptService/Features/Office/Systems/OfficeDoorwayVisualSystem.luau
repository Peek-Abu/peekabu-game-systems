--!strict
-- Imported wallDoorway contains full wall panels; fitting its opening scales those into neighbouring walls.
-- Narrow native trim covers both existing wall faces instead, preserving the gameplay aperture.
local Server = game:GetService("ServerScriptService").Features.Office
local Constants = require(Server.Data.OfficeConstants)
local System = {}
local JAMB_WIDTH = 0.18
local TRIM_DEPTH = 0.12
local HEADER_HEIGHT = 0.2
local function trim(root: BasePart, name: string, size: Vector3, position: Vector3)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = root.CFrame * CFrame.new(position)
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Constants.DESK_COLOR
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.Parent = root
end
function System.build(root: BasePart)
	local width, height, depth = root.Size.X, root.Size.Y, root.Size.Z
	for _, face in { -1, 1 } do
		local z = face * (depth / 2 + TRIM_DEPTH / 2)
		for _, side in { -1, 1 } do
			trim(
				root,
				"Jamb",
				Vector3.new(JAMB_WIDTH, height, TRIM_DEPTH),
				Vector3.new(side * (width / 2 + JAMB_WIDTH / 2), 0, z)
			)
		end
		-- A thin visible header stays below the ceiling; it does not add a physical lintel or door.
		trim(
			root,
			"Header",
			Vector3.new(width + JAMB_WIDTH * 2, HEADER_HEIGHT, TRIM_DEPTH),
			Vector3.new(0, height / 2 - HEADER_HEIGHT / 2, z)
		)
	end
end
return System
