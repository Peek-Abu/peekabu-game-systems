local Server = game:GetService("ServerScriptService").Features.Office
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shell = require(script.Parent.OfficeShellVisualSystem)
local Constants = require(Server.Data.OfficeConstants)
local LayoutUtils = require(Server.Utils.OfficeLayoutUtils)
local LightingUtils = require(Server.Utils.OfficeLightingUtils)
local ArtKeyUtils = require(Server.Utils.OfficeArtKeyUtils)
local Visuals = require(game:GetService("ServerScriptService").Features.Art.Systems.ArtVisualSystem)
local Occupant = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local ORIGIN = CFrame.new(60000, 0, 0)

-- Two rooms side by side (a pane between them), a corridor above, a bay below (an authored room: no type).
local function layout()
	return {
		startRoom = "bay",
		rooms = {
			{ id = "a", name = "A", minX = 0, maxX = 20, minZ = 0, maxZ = 20, roomType = "pods" },
			{ id = "b", name = "B", minX = 20, maxX = 40, minZ = 0, maxZ = 20, roomType = "server" },
			{ id = "hall", name = "Hall", minX = 0, maxX = 40, minZ = 20, maxZ = 26, zone = "hallway" },
			{ id = "bay", name = "Bay", minX = 0, maxX = 40, minZ = -20, maxZ = 0 },
		},
		doors = {
			{ a = "a", b = "hall", x = 10, z = 20, width = 6, kind = "solid" },
			{ a = "b", b = "hall", x = 30, z = 20, width = 6, kind = "open" },
			{ a = "a", b = "bay", x = 10, z = 0, width = 6, kind = "open" },
		},
		markers = {},
		truck = { minX = 1, maxX = 3, minZ = -3, maxZ = -1, clockX = 4, clockZ = -3 },
		panes = { { x1 = 20, z1 = 4, x2 = 20, z2 = 14 } },
	}
end

local function countNamed(model, name)
	local count = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name == name then
			count += 1
		end
	end
	return count
end

return function()
	local assets, art, model
	local function build(hasVariant)
		model = Instance.new("Model")
		local plan = layout()
		Shell.build(plan, ORIGIN, model, art, hasVariant)
		return plan
	end
	local function never()
		return false
	end
	beforeEach(function()
		assets = Instance.new("Folder")
		art = Visuals.new(assets)
	end)
	afterEach(function()
		if model ~= nil then
			model:Destroy()
			model = nil
		end
		assets:Destroy()
	end)

	describe("OfficeShellVisualSystem", function()
		it("builds every wall as slabs and trim", function()
			local plan = build(never)
			local segments = LayoutUtils.mergedWallSegments(plan)
			expect(countNamed(model, "Plaster")).to.equal(2 * #segments)
			expect(countNamed(model, "Wainscot")).to.equal(2 * #segments)
			expect(countNamed(model, "Rail")).to.equal(2 * #segments)
			expect(countNamed(model, "Skirt")).to.equal(2 * #segments)
			for _, part in model.Shell:GetChildren() do
				if part.Name == "Plaster" then
					expect(part.CanCollide).to.equal(true)
				elseif
					part.Name == "Wainscot"
					or part.Name == "Rail"
					or part.Name == "Skirt"
					or part.Name == "Grid"
				then
					expect(part.CanCollide).to.equal(false)
					expect(part.CanQuery).to.equal(false)
				end
			end
		end)

		it("builds a ceiling slab per room that collides, and a casing per solid door", function()
			build(never)
			expect(countNamed(model, "Ceiling")).to.equal(4)
			for _, part in model.Shell:GetChildren() do
				if part.Name == "Ceiling" or part.Name == "Jamb" or part.Name == "Head" then
					expect(part.CanCollide).to.equal(true)
				end
			end
			expect(countNamed(model, "Jamb")).to.equal(2)
			expect(countNamed(model, "Head")).to.equal(1)
		end)

		it("closes the wall above a solid door with a colliding lintel, and leaves an open doorway alone", function()
			build(never)
			expect(countNamed(model, "DoorHeader")).to.equal(1)
			local header = model.Shell:FindFirstChild("DoorHeader")
			expect(header.Size.X).to.be.near(6, 0.001)
			expect(header.Size.Z).to.be.near(Constants.WALL_THICKNESS, 0.001)
			expect(header.Position.Y - header.Size.Y / 2).to.be.near(Constants.DOOR_HEIGHT, 0.001)
			expect(header.Position.Y + header.Size.Y / 2).to.be.near(Constants.WALL_HEIGHT + 1, 0.001)
			expect(header.CanCollide).to.equal(true)
			expect(header.CanQuery).to.equal(true)
		end)

		it("breaks the trim at a facade, gives it a casing, and closes an outer corner", function()
			model = Instance.new("Model")
			local plan = layout()
			plan.facades = { { room = "a", x = 0, z = 10, width = 6, kind = "stairwell" } }
			Shell.build(plan, ORIGIN, model, art, never)
			-- The facade stands on room A's minX wall (x = 0), face +X: no trim overlaps z 7..13 there, trim stays on -X.
			local onFace, onOther = 0, 0
			for _, part in model.Shell:GetChildren() do
				if
					(part.Name == "Wainscot" or part.Name == "Rail" or part.Name == "Skirt")
					and math.abs(part.Position.X - ORIGIN.X) < 2
					and part.Size.Z > part.Size.X
				then
					local localX = part.Position.X - ORIGIN.X
					local z0, z1 = part.Position.Z - part.Size.Z / 2, part.Position.Z + part.Size.Z / 2
					if localX > 0 and z0 < 13 - 1e-3 and z1 > 7 + 1e-3 then
						onFace += 1
					elseif localX < 0 and z0 < 7 and z1 > 13 then
						onOther += 1
					end
				end
			end
			expect(onFace).to.equal(0)
			expect(onOther).to.equal(3)
			-- The solid door's casing plus the facade's.
			expect(countNamed(model, "Jamb")).to.equal(4)
			expect(countNamed(model, "Head")).to.equal(2)
			-- The bay's outer corner at (0, -20): the outer (-Z) face of its z = -20 wall reaches 0.5 + 0.3 past it, the
			-- inner face only 0.3.
			local outerMin, innerMin = math.huge, math.huge
			for _, part in model.Shell:GetChildren() do
				if part.Name == "Wainscot" and part.Size.X > part.Size.Z then
					local z = part.Position.Z
					local minX = part.Position.X - ORIGIN.X - part.Size.X / 2
					if math.abs(z + 20.65) < 0.01 then
						outerMin = math.min(outerMin, minX)
					elseif math.abs(z + 19.35) < 0.01 then
						innerMin = math.min(innerMin, minX)
					end
				end
			end
			expect(outerMin).to.be.near(-0.8, 1e-3)
			expect(innerMin).to.be.near(-0.3, 1e-3)
		end)

		it("breaks the trim at an entrance's exit and cases it, like a facade", function()
			model = Instance.new("Model")
			local plan = layout()
			plan.entrances = {
				{
					id = "dock",
					ground = "yard",
					outside = { x = 0, z = -100, yaw = 0 },
					exit = { a = "a", b = "dock", x = 0, z = 10, width = 6, kind = "solid" },
				},
			}
			Shell.build(plan, ORIGIN, model, art, never)
			local onFace = 0
			for _, part in model.Shell:GetChildren() do
				if
					(part.Name == "Wainscot" or part.Name == "Rail" or part.Name == "Skirt")
					and math.abs(part.Position.X - ORIGIN.X) < 2
					and part.Size.Z > part.Size.X
				then
					local localX = part.Position.X - ORIGIN.X
					local z0, z1 = part.Position.Z - part.Size.Z / 2, part.Position.Z + part.Size.Z / 2
					if localX > 0 and z0 < 13 - 1e-3 and z1 > 7 + 1e-3 then
						onFace += 1
					end
				end
			end
			expect(onFace).to.equal(0)
			-- The solid door's casing plus the exit's.
			expect(countNamed(model, "Jamb")).to.equal(4)
			expect(countNamed(model, "Head")).to.equal(2)
		end)

		describe("a corner whose other side is a doorway", function()
			-- The z = 0 wall between A and B ends at x = 0. On the x = 0 line a wall runs down (B | W) and a doorway from A
			-- to W runs up from the junction (z 0..6), with no merged segment there: an archway's mouth corner (seed 9's
			-- hallJ2_1 | hallS5), or a real door's.
			-- No trim face shares a plane and an overlapping area (facing the same way) with a casing or pilaster face:
			-- that z-fights. Back-to-back faces (a trim end butting a jamb's side) face each other and never show.
			local function coplanarWithCasing()
				local trims, casings = {}, {}
				for _, part in model.Shell:GetChildren() do
					if part.Name == "Wainscot" or part.Name == "Rail" or part.Name == "Skirt" then
						table.insert(trims, part)
					elseif part.Name == "Jamb" or part.Name == "Head" or part.Name == "Pilaster" then
						table.insert(casings, part)
					end
				end
				local axes = { "X", "Y", "Z" }
				local found = 0
				for _, trim in trims do
					for _, casing in casings do
						for index, axis in axes do
							for _, sign in { -1, 1 } do
								local a = trim.Position[axis] + sign * trim.Size[axis] / 2
								local b = casing.Position[axis] + sign * casing.Size[axis] / 2
								if math.abs(a - b) < 1e-3 then
									local area = true
									for other, name in axes do
										if other ~= index then
											local lo = math.max(
												trim.Position[name] - trim.Size[name] / 2,
												casing.Position[name] - casing.Size[name] / 2
											)
											local hi = math.min(
												trim.Position[name] + trim.Size[name] / 2,
												casing.Position[name] + casing.Size[name] / 2
											)
											area = area and hi - lo > 1e-3
										end
									end
									if area then
										found += 1
									end
								end
							end
						end
					end
				end
				return found
			end

			local function corner(kind, width)
				model = Instance.new("Model")
				local span = width or 6
				local plan = {
					startRoom = "a",
					rooms = {
						{ id = "a", name = "A", minX = 0, maxX = 20, minZ = 0, maxZ = 20, roomType = "pods" },
						{ id = "b", name = "B", minX = 0, maxX = 20, minZ = -20, maxZ = 0, roomType = "pods" },
						{ id = "w", name = "W", minX = -10, maxX = 0, minZ = -6, maxZ = 12, zone = "hallway" },
					},
					doors = { { a = "a", b = "w", x = 0, z = span / 2, width = span, kind = kind } },
					markers = {},
					truck = { minX = 1, maxX = 3, minZ = -3, maxZ = -1, clockX = 4, clockZ = -3 },
				}
				Shell.build(plan, ORIGIN, model, art, never)
				-- The A-side (+Z) wainscot of the z = 0 wall: its face is z 0.5 .. 0.8.
				local face, others = nil, {}
				for _, part in model.Shell:GetChildren() do
					if part.Name == "Wainscot" then
						if math.abs(part.Position.Z - 0.65) < 0.01 and part.Size.X > part.Size.Z then
							face = part
						else
							table.insert(others, part)
						end
					end
				end
				-- No trim along the doorway's own wall in the middle of it: the opening less the walls bounding its mouth
				-- (half a wall each side) and a trim depth, 1.9 deep at x = 0.
				for _, part in model.Shell:GetChildren() do
					if part.Name == "Wainscot" or part.Name == "Rail" or part.Name == "Skirt" then
						local x, z = part.Position.X - ORIGIN.X, part.Position.Z
						local hx, hz = part.Size.X / 2, part.Size.Z / 2
						local along = part.Size.Z > part.Size.X and z - hz < span - 1 and z + hz > 1
						expect(along and x - hx < 0.95 and x + hx > -0.95).to.equal(false)
					end
				end
				return face, others
			end

			it("closes an archway's mouth corner: no slab end face is left without trim", function()
				local face, others = corner("open")
				local proud = Constants.SHELL.wainscotProud
				-- The z = 0 wall's A-side face wraps to its slab end plus its depth (x -0.8)...
				local minX = face.Position.X - ORIGIN.X - face.Size.X / 2
				expect(minX).to.be.near(-0.5 - proud, 1e-3)
				-- ...and the x = 0 wall below the mouth is a corner there, not a door end, though its end is the opening's
				-- edge: its slab runs on to the z = 0 wall's face (z 0.5) and its W-side trim (x -0.8 .. -0.5) meets the
				-- wrap there, so together they cover the band at the corner with no gap.
				local stub
				for _, other in others do
					local x = other.Position.X - ORIGIN.X
					if
						other.Size.Z > other.Size.X
						and math.abs(x + 0.5 + proud / 2) < 0.01
						and other.Position.Z < 1
					then
						stub = other
					end
				end
				expect(stub ~= nil).to.equal(true)
				expect(stub.Position.Z + stub.Size.Z / 2).to.be.near(0.5, 1e-3)
				local slabTop = -math.huge
				for _, part in model.Shell:GetChildren() do
					local x = part.Position.X - ORIGIN.X
					if
						part.Name == "Plaster"
						and part.Size.Z > part.Size.X
						and math.abs(x + 0.25) < 0.01
						and part.Position.Z < 1
					then
						slabTop = math.max(slabTop, part.Position.Z + part.Size.Z / 2)
					end
				end
				expect(slabTop).to.be.near(0.5, 1e-3)
				-- No coplanar overlap: no parallel wainscot (the same outer face plane) shares volume with the wrap.
				-- Perpendicular pieces meeting at a corner may overlap: they never share an outer face.
				for _, other in others do
					if other.Size.X > other.Size.Z then
						local dx = math.abs(face.Position.X - other.Position.X) - (face.Size.X + other.Size.X) / 2
						local dz = math.abs(face.Position.Z - other.Position.Z) - (face.Size.Z + other.Size.Z) / 2
						expect(dx >= -1e-3 or dz >= -1e-3).to.equal(true)
					end
				end
				-- And the stub's trim stops where the wrap starts: they touch, never overlap.
				expect(stub.Position.Z + stub.Size.Z / 2 <= face.Position.Z - face.Size.Z / 2 + 1e-3).to.equal(true)
			end)

			it("stands a wide archway's pilaster proud of the trim, and stops the trim at its side", function()
				local face, others = corner("open", 10)
				expect(coplanarWithCasing()).to.equal(0)
				local shell = Constants.SHELL
				local pilaster
				for _, part in model.Shell:GetChildren() do
					if part.Name == "Pilaster" and part.Position.Z < 5 then
						pilaster = part
					end
				end
				-- Its front faces stand proud of the rail on both sides of the wall.
				local x = pilaster.Position.X - ORIGIN.X
				expect(x - pilaster.Size.X / 2 < -(0.5 + shell.railDepth) - 1e-3).to.equal(true)
				expect(x + pilaster.Size.X / 2 > 0.5 + shell.railDepth + 1e-3).to.equal(true)
				-- The wall below the mouth is a door end there: its trim stops at the pilaster's side (z = 0).
				for _, other in others do
					local ox = other.Position.X - ORIGIN.X
					if
						other.Size.Z > other.Size.X
						and math.abs(math.abs(ox) - 0.65) < 0.01
						and other.Position.Z < 0
					then
						expect(other.Position.Z + other.Size.Z / 2).to.be.near(0, 1e-3)
					end
				end
				-- The z = 0 wall does not wrap round it: its A-side trim stays within the slab end.
				expect(face.Position.X - ORIGIN.X - face.Size.X / 2 >= -0.5 - 1e-3).to.equal(true)
			end)

			it("leaves no trim face coplanar with a real door's casing", function()
				for _, kind in { "solid", "glass" } do
					corner(kind)
					expect(coplanarWithCasing()).to.equal(0)
					model:Destroy()
					model = nil
				end
			end)

			it("stops a real door's corner at the slab end: the casing covers it, no wrap into it", function()
				for _, kind in { "solid", "glass" } do
					local face, others = corner(kind)
					local minX = face.Position.X - ORIGIN.X - face.Size.X / 2
					expect(minX >= -0.5 - 1e-3).to.equal(true)
					-- The wall continuing into the jamb is still a door end: its W-side trim stops flush at z = 0.
					for _, other in others do
						local x = other.Position.X - ORIGIN.X
						if other.Size.Z > other.Size.X and math.abs(x + 0.65) < 0.01 and other.Position.Z < 1 then
							expect(other.Position.Z + other.Size.Z / 2).to.be.near(0, 1e-3)
						end
					end
					model:Destroy()
					model = nil
				end
			end)
		end)

		it("frames a glass pane and tags only its sheet SightThrough, collidable and queryable", function()
			build(never)
			local sheets = 0
			for _, part in model.Shell:GetChildren() do
				local tagged = CollectionService:HasTag(part, Occupant.SIGHT_THROUGH_TAG)
				expect(tagged).to.equal(part.Name == "Glass")
				if part.Name == "Glass" then
					sheets += 1
					expect(part.CanCollide).to.equal(true)
					expect(part.CanQuery).to.equal(true)
					expect(part.Material).to.equal(Enum.Material.Glass)
				end
			end
			expect(sheets).to.equal(1)
			expect(countNamed(model, "Mullion") >= 1).to.equal(true)
		end)

		it("falls back to plain material without the MaterialVariants", function()
			build(never)
			local checked = 0
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and part.Parent == model.Shell then
					expect(part.MaterialVariant).to.equal("")
					checked += 1
				end
			end
			expect(checked > 0).to.equal(true)
			local plaster = model.Shell:FindFirstChild("Plaster")
			expect(plaster.Material).to.equal(Constants.SHELL_MATERIALS.plaster.material)
			expect(plaster.Color).to.equal(Constants.SHELL_MATERIALS.plaster.color)
		end)

		it("sets the MaterialVariant when the place has one", function()
			build(function()
				return true
			end)
			expect(model.Shell:FindFirstChild("Plaster").MaterialVariant).to.equal("OH_Plaster")
			expect(model.Shell:FindFirstChild("Wainscot").MaterialVariant).to.equal("OH_Oak")
			expect(model.Shell:FindFirstChild("Rail").MaterialVariant).to.equal("")
		end)

		it("tags every lit panel and every fill, never an unlit panel", function()
			local plan = build(never)
			local expected = 0
			local unlit = 0
			for _, room in plan.rooms do
				local lights = LightingUtils.roomLights(room, ArtKeyUtils.roomType(room))
				expected += #lights.fills
				for _, panel in lights.panels do
					if panel.lit then
						expected += 1
					else
						unlit += 1
					end
				end
			end
			local tagged = 0
			local unlitSeen = 0
			for _, part in model.Lights:GetDescendants() do
				if part:IsA("BasePart") and part.Parent.Parent == model.Lights then
					if CollectionService:HasTag(part, Occupant.LIGHT_TAG) then
						tagged += 1
					elseif part.Name == "Panel" then
						unlitSeen += 1
					end
				end
			end
			expect(tagged).to.equal(expected)
			expect(unlitSeen).to.equal(unlit)
			expect(unlit > 0).to.equal(true)
		end)

		it("gives a lit panel a bottom SurfaceLight with the recipe values and fills unshadowed PointLights", function()
			build(never)
			local panels, fills = 0, 0
			for _, part in model.Lights:GetDescendants() do
				if part:IsA("BasePart") and CollectionService:HasTag(part, Occupant.LIGHT_TAG) then
					if part.Name == "Panel" then
						panels += 1
						local light = part:FindFirstChildWhichIsA("SurfaceLight")
						expect(light ~= nil).to.equal(true)
						expect(light.Face).to.equal(Enum.NormalId.Bottom)
						expect(light.Color).to.equal(Constants.PANEL_COLOR)
						expect(light.Shadows).to.equal(false)
						expect(light.Range).to.equal(14)
						expect(part.Material).to.equal(Enum.Material.Neon)
						expect(part.Size).to.equal(Vector3.new(4, 0.2, 2))
						expect(part.Position.Y + 0.1).to.be.near(Constants.WALL_HEIGHT, 0.001)
						expect(part.CanCollide).to.equal(false)
					else
						fills += 1
						local light = part:FindFirstChildWhichIsA("PointLight")
						expect(light ~= nil).to.equal(true)
						expect(light.Shadows).to.equal(false)
						expect(light.Color).to.equal(Constants.FILL_COLOR)
						expect(part.Transparency).to.equal(1)
						expect(part:GetAttribute("OfficeLightFill")).to.equal(true)
						expect(part.CanCollide).to.equal(false)
						expect(part.CanQuery).to.equal(false)
						expect(part.CanTouch).to.equal(false)
					end
				end
			end
			expect(panels > 0).to.equal(true)
			expect(fills > 0).to.equal(true)
		end)

		it("leaves an unlit panel a plain, lightless, non-neon box", function()
			build(never)
			local found = 0
			for _, part in model.Lights:GetDescendants() do
				if
					part:IsA("BasePart")
					and part.Name == "Panel"
					and not CollectionService:HasTag(part, Occupant.LIGHT_TAG)
				then
					found += 1
					expect(part:FindFirstChildWhichIsA("Light")).to.equal(nil)
					expect(part.Material).to.never.equal(Enum.Material.Neon)
				end
			end
			expect(found > 0).to.equal(true)
		end)

		it("gives the bay the shell: slabs, a ceiling and panels", function()
			build(never)
			local bay = model.Lights:FindFirstChild("Bay")
			expect(bay ~= nil).to.equal(true)
			local panels = 0
			for _, part in bay:GetChildren() do
				if part.Name == "Panel" then
					panels += 1
				end
			end
			expect(panels > 0).to.equal(true)
			local ceilings, slabs = 0, 0
			for _, part in model.Shell:GetChildren() do
				if part.Name == "Ceiling" and part.Position.Z - ORIGIN.Z < 0 then
					ceilings += 1
				elseif part.Name == "Plaster" and part.Position.Z < 0 then
					slabs += 1
				end
			end
			expect(ceilings).to.equal(1)
			expect(slabs > 0).to.equal(true)
		end)

		it("picks a floor material by room type", function()
			expect(Shell.floorMaterial("hallway")).to.equal("hallcarpet")
			expect(Shell.floorMaterial("breakout")).to.equal("lino")
			expect(Shell.floorMaterial("server")).to.equal("vinyl")
			expect(Shell.floorMaterial("storage")).to.equal("vinyl")
			expect(Shell.floorMaterial("bay")).to.equal("vinyl")
			expect(Shell.floorMaterial(nil)).to.equal("carpet")
			expect(Shell.floorMaterial("pods")).to.equal("carpet")
			expect(Shell.floorMaterial("conference")).to.equal("carpet")
			expect(Shell.floorMaterial("reception")).to.equal("carpet")
		end)
	end)
end
