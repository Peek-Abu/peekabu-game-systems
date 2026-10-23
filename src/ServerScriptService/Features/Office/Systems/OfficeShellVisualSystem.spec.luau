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

		it("gives a lit panel a bottom SurfaceLight with the recipe values and fills shadowed PointLights", function()
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
						expect(light.Shadows).to.equal(true)
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
