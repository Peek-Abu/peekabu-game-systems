local Server = game:GetService("ServerScriptService").Features.Office
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(script.Parent.OfficeBuildSystem)
local Layout = require(Server.Data.OfficeLayoutConstants).LAYOUT
local Constants = require(Server.Data.OfficeConstants)
local Visuals = require(game:GetService("ServerScriptService").Features.Art.Systems.ArtVisualSystem)
local Occupant = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local Interaction = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local Shift = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
return function()
	local models = {}
	local assets
	local art
	beforeEach(function()
		assets = Instance.new("Folder")
		art = Visuals.new(assets)
	end)
	local function build(layout)
		local built = Build.build(layout, CFrame.new(50000, 0, 0), art)
		table.insert(models, built.model)
		return built
	end
	afterEach(function()
		for _, model in models do
			model:Destroy()
		end
		table.clear(models)
		assets:Destroy()
	end)
	local function template(family, key)
		local kit = assets:FindFirstChild("test-map-a")
		if not kit then
			kit = Instance.new("Folder")
			kit.Name = "test-map-a"
			kit.Parent = assets
		end
		local group = kit:FindFirstChild(family)
		if not group then
			group = Instance.new("Folder")
			group.Name = family
			group.Parent = kit
		end
		local model = Instance.new("Model")
		model.Name = key
		model:SetAttribute("RuntimeApproved", true)
		model:SetAttribute("BaseSize", Vector3.new(1, 1, 1))
		if key == "wallDoorway" then
			model:SetAttribute("OpeningWidth", 1)
		end
		local body = Instance.new("Part")
		body.Size = Vector3.new(1, 1, 1)
		body.CFrame = CFrame.new(0, 0.5, 0)
		body.Parent = model
		model.WorldPivot = CFrame.identity
		model.Parent = group
	end
	describe("native camera occlusion", function()
		it("retains opaque collidable backing behind imported walls and ceilings", function()
			for _, key in { "wallSolid", "ceilingTile" } do
				template("building", key)
			end
			local selected = table.clone(Layout)
			selected.artKit = "test-map-a"
			local built = build(selected)
			local checked = 0
			for _, root in built.model:GetDescendants() do
				if root:IsA("BasePart") and (root.Name == "Wall" or root.Name == "Ceiling") then
					local backing
					for _, candidate in built.model.OpaqueStructure:GetChildren() do
						if candidate.CFrame == root.CFrame then
							backing = candidate
							break
						end
					end
					expect(backing and not backing:IsDescendantOf(root)).to.equal(true)
					expect(backing ~= nil).to.equal(true)
					expect(backing.Transparency).to.equal(0)
					expect(backing.CanQuery and backing.CanCollide).to.equal(true)
					expect(backing.CFrame).to.equal(root.CFrame)
					if root.Name == "Wall" then
						expect(backing.Size.Z <= root.Size.Z * 0.5).to.equal(true)
					end
					expect(
						backing.Size.X < root.Size.X and backing.Size.Y < root.Size.Y and backing.Size.Z < root.Size.Z
					).to.equal(true)
					checked += 1
				end
			end
			expect(checked > 2).to.equal(true)
		end)
	end)
	describe("ceiling lamp coverage", function()
		it("reaches floor corners between neighbouring fixtures with falloff reserve", function()
			local built = build(Layout)
			local fixture = built.model:FindFirstChild("Light", true)
			local lamp = fixture:FindFirstChildOfClass("PointLight")
			local floorDistance = math.sqrt(Constants.WALL_HEIGHT ^ 2 + 2 * (Constants.LIGHT_SPACING / 2) ^ 2)
			expect(lamp.Range >= floorDistance * 1.25).to.equal(true)
		end)
	end)
	describe("floor backing", function()
		it("backs imported carpet below its recessed face without coplanar overlap", function()
			template("building", "floorTile")
			local selected = table.clone(Layout)
			selected.artKit = "test-map-a"
			local built = build(selected)
			local floor = built.model:FindFirstChild("Floor", true)
			local skin = floor.Parent:FindFirstChild("FloorUnderlay")
			expect(skin.Transparency).to.equal(0)
			expect(skin.Position.Y + skin.Size.Y / 2 < floor.Position.Y + floor.Size.Y / 2 - 0.08).to.equal(true)
			expect(skin.CanCollide).to.equal(true)
			expect(skin.CanQuery).to.equal(true)
		end)
	end)
	describe("imported lamp emission", function()
		it("gives the imported housing a distinct visible emitting panel", function()
			template("building", "fluorescent")
			local selected = table.clone(Layout)
			selected.artKit = "test-map-a"
			local built = build(selected)
			local fixture = built.model:FindFirstChild("Light", true)
			local panel = fixture:FindFirstChild("LightPanel")
			expect(panel:GetAttribute("OfficeLightEmitter")).to.equal(true)
			expect(panel.Material).to.equal(Enum.Material.Neon)
			expect(panel.CanCollide).to.equal(false)
			-- Flush under the ceiling, a lamp's shadow falls inside the ceiling's own: no shadow-pass cost for nothing.
			expect(panel.CastShadow).to.equal(false)
			expect(fixture.CastShadow).to.equal(false)
		end)
	end)
	describe("actual worktop support", function()
		it("keeps a tall fixture's faucet outside the collision support height", function()
			template("furniture", "kitchenCounter")
			assets["test-map-a"].furniture.kitchenCounter:SetAttribute("SupportSurfaceY", 0.75)
			local selected = table.clone(Layout)
			selected.artKit = "test-map-a"
			selected.markers = { { id = "counter.support", room = selected.startRoom, kind = "counter", x = 3, z = 3 } }
			local built = build(selected)
			local counter = built.model.Furniture.KitchenCounter
			expect(counter.CanCollide).to.equal(false)
			local support = counter.WorktopSupport
			expect(support.CanCollide).to.equal(true)
			expect(
				math.abs(support.Position.Y + support.Size.Y / 2 - counter:GetAttribute("ArtSupportSurfaceY")) < 0.001
			).to.equal(true)
		end)
	end)
	describe("map-local art selection and fallback", function()
		it("attaches building and furniture visuals without changing gameplay roots", function()
			for _, key in { "floorTile", "ceilingTile", "wallSolid", "wallDoorway", "fluorescent" } do
				template("building", key)
			end
			for _, key in { "desk", "locker", "shelf", "kitchenCounter", "corkboard" } do
				template("furniture", key)
			end
			template("cargo", "officePlant")
			local selected = table.clone(Layout)
			selected.artKit = "test-map-a"
			selected.markers = table.clone(Layout.markers)
			for _, kind in { "shelf", "counter", "plant", "board" } do
				table.insert(
					selected.markers,
					{ id = "art." .. kind, room = selected.startRoom, kind = kind, x = 3, z = 3 }
				)
			end
			local built = build(selected)
			for _, name in
				{
					"Floor",
					"Ceiling",
					"Wall",
					"Light",
					"Shelf",
					"KitchenCounter",
					"OfficePlant",
					"Corkboard",
				}
			do
				local proxy = built.model:FindFirstChild(name, true)
				expect(proxy:FindFirstChild("ArtVisual") ~= nil).to.equal(true)
				expect(proxy:FindFirstChild("ArtVisual"):GetAttribute("ArtKitId")).to.equal("test-map-a")
			end
			for _, proxy in built.searchables do
				expect(proxy:FindFirstChild("ArtVisual") ~= nil).to.equal(true)
				expect(proxy.Size).to.equal(if proxy.Name == "Desk" then Constants.DESK_SIZE else Constants.LOCKER_SIZE)
				expect(proxy.CanCollide).to.equal(true)
				expect(CollectionService:HasTag(proxy, Interaction.TAG)).to.equal(true)
			end
			local frame = built.model:FindFirstChild("DoorFrame", true)
			expect(frame.CanCollide).to.equal(false)
			expect(frame.CanQuery).to.equal(false)
		end)
		it("selects a kit per map and retains the default independently", function()
			local selected = table.clone(Layout)
			selected.artKit = "missing-test-kit"
			local first = build(selected)
			local second = build(Layout)
			expect(first.model:GetAttribute("ArtKitId")).to.equal("missing-test-kit")
			expect(second.model:GetAttribute("ArtKitId")).to.equal(Constants.ART_KIT_ID)
		end)
		it("preserves collidable ceilings, searchable proxies and tagged light fallback", function()
			local selected = table.clone(Layout)
			selected.artKit = "missing-test-kit"
			local built = build(selected)
			local ceiling = built.model:FindFirstChild("Ceiling", true)
			expect(ceiling ~= nil).to.equal(true)
			expect(ceiling.CanCollide).to.equal(true)
			expect(ceiling.Transparency).to.equal(0)
			for _, part in built.searchables do
				expect(CollectionService:HasTag(part, Interaction.TAG)).to.equal(true)
				expect(part:GetAttribute(Interaction.ENABLED_ATTRIBUTE)).to.equal(false)
				expect(part.CanCollide).to.equal(true)
			end
			local light = built.model:FindFirstChild("Light", true)
			expect(CollectionService:HasTag(light, Occupant.LIGHT_TAG)).to.equal(true)
			expect(light:FindFirstChildOfClass("PointLight") ~= nil).to.equal(true)
			expect(light.CastShadow).to.equal(false)
			expect(light.CanTouch).to.equal(false)
		end)
		it("uses existing zone markers once without making them searchable", function()
			local selected = table.clone(Layout)
			selected.artKit = "missing-test-kit"
			selected.markers = table.clone(Layout.markers)
			for _, kind in { "shelf", "counter", "plant", "board" } do
				table.insert(
					selected.markers,
					{ id = "art." .. kind, room = selected.startRoom, kind = kind, x = 3, z = 3 }
				)
			end
			local built = build(selected)
			local furniture = built.model:FindFirstChild("Furniture")
			for _, name in { "Shelf", "KitchenCounter", "OfficePlant", "Corkboard" } do
				local part = furniture:FindFirstChild(name)
				expect(part ~= nil).to.equal(true)
				expect(part.CanCollide).to.equal(name == "Shelf" or name == "KitchenCounter")
				expect(part.CanQuery).to.equal(name == "Shelf" or name == "KitchenCounter")
				expect(CollectionService:HasTag(part, Interaction.TAG)).to.equal(false)
			end
		end)
	end)
	it("honors marker yaw and raises boards to wall height", function()
		local selected = table.clone(Layout)
		selected.markers = {
			{ id = "rotated.desk", room = selected.startRoom, kind = "desk", x = 7, z = 7, rotation = math.pi / 2 },
			{ id = "rotated.board", room = selected.startRoom, kind = "board", x = 8, z = 8, rotation = math.pi },
		}
		local built = build(selected)
		expect(built.searchables["rotated.desk"].CFrame.LookVector:Dot(Vector3.new(-1, 0, 0)) > 0.99).to.equal(true)
		local board = built.model:FindFirstChild("Corkboard", true)
		expect(board.Position.Y - board.Size.Y / 2 >= 3).to.equal(true)
		expect(board.CFrame.LookVector.Z > 0.99).to.equal(true)
	end)
	it("keeps floor coverage opaque beneath attached art", function()
		template("building", "floorTile")
		local selected = table.clone(Layout)
		selected.artKit = "test-map-a"
		local built = build(selected)
		for _, root in built.model:GetDescendants() do
			if root.Name == "Floor" and root:IsA("BasePart") then
				expect(root.CanCollide).to.equal(true)
				local skin = root.Parent:FindFirstChild("FloorUnderlay")
				expect(skin.Transparency).to.equal(0)
				expect(skin.Position.Y + skin.Size.Y / 2 < root.Position.Y + root.Size.Y / 2).to.equal(true)
			end
		end
	end)
	describe("truck paperwork", function()
		local Truck = require(game:GetService("ServerScriptService").Features.Depot.Data.DepotTruckVisualConstants)

		-- Studs from the deck; the build sits 50000 studs out, so float32 positions are good to ~0.005.
		local function deckPoint(bed, point)
			return (bed.CFrame * CFrame.new(0, bed.Size.Y / 2, 0)):PointToObjectSpace(point)
		end

		it("hangs the time clock's invisible hit box inside the truck box, on its front wall", function()
			local built = build(Layout)
			local clock = built.clock
			expect(clock:GetAttribute(Interaction.KIND_ATTRIBUTE)).to.equal(Shift.CLOCK_OUT_KIND)
			expect(CollectionService:HasTag(clock, Interaction.TAG)).to.equal(true)
			expect(clock.Transparency).to.equal(1)
			expect(clock.CanCollide).to.equal(false)
			expect(clock.CanQuery).to.equal(true)
			expect((deckPoint(built.bed, clock.Position) - Truck.PAPERWORK.clock.centre).Magnitude < 0.01).to.equal(
				true
			)
		end)

		it("hangs the overtime sheet beside it, its Start overtime prompt off until Shift opens it", function()
			local built = build(Layout)
			local sheet = built.overtime
			expect(sheet.Parent).to.equal(built.clock.Parent)
			expect(sheet:GetAttribute(Interaction.KIND_ATTRIBUTE)).to.equal(Shift.OVERTIME_KIND)
			expect(sheet:GetAttribute(Interaction.ENABLED_ATTRIBUTE)).to.equal(false)
			expect(CollectionService:HasTag(sheet, Interaction.TAG)).to.equal(true)
			expect(sheet.CanCollide).to.equal(false)
			expect((deckPoint(built.bed, sheet.Position) - Truck.PAPERWORK.sheet.centre).Magnitude < 0.01).to.equal(
				true
			)
		end)
	end)
	describe("narrow doorway trim", function()
		local function connectedRooms(vertical)
			if vertical then
				return {
					startRoom = "a",
					rooms = {
						{ id = "a", name = "A", minX = 0, maxX = 20, minZ = 0, maxZ = 20 },
						{ id = "b", name = "B", minX = 20, maxX = 40, minZ = 0, maxZ = 20 },
					},
					doors = { { a = "a", b = "b", x = 20, z = 10, width = 10 } },
					markers = {},
					truck = { minX = 1, maxX = 3, minZ = 1, maxZ = 3, clockX = 4, clockZ = 3 },
					route = {},
					rest = "",
				}
			end
			return {
				startRoom = "a",
				rooms = {
					{ id = "a", name = "A", minX = 0, maxX = 20, minZ = 0, maxZ = 20 },
					{ id = "b", name = "B", minX = 0, maxX = 20, minZ = 20, maxZ = 40 },
				},
				doors = { { a = "a", b = "b", x = 10, z = 20, width = 10 } },
				markers = {},
				truck = { minX = 1, maxX = 3, minZ = 1, maxZ = 3, clockX = 4, clockZ = 3 },
				route = {},
				rest = "",
			}
		end
		it("preserves the complete aperture between actual colliding wall bounds in both directions", function()
			for _, vertical in { false, true } do
				local built = build(connectedRooms(vertical))
				local left, right
				for _, wall in built.model.Walls:GetChildren() do
					local line = if vertical then wall.Position.X - 50000 else wall.Position.Z
					local tangent = if vertical then Vector3.zAxis else Vector3.xAxis
					if
						wall:IsA("BasePart")
						and math.abs(line - 20) < 0.001
						and math.abs(wall.CFrame.RightVector:Dot(tangent)) > 0.99
					then
						local centre = if vertical then wall.Position.Z else wall.Position.X - 50000
						if centre < 10 then
							left = centre + wall.Size.X / 2
						else
							right = centre - wall.Size.X / 2
						end
					end
				end
				expect(left ~= nil and right ~= nil).to.equal(true)
				expect(right - left).to.be.near(10, 0.001)
			end
		end)
		it("replaces the monolithic wall skin with narrow trim outside the aperture on both faces", function()
			template("building", "wallDoorway")
			local selected = connectedRooms()
			selected.artKit = "test-map-a"
			local built = build(selected)
			local frame = built.model.DoorFrames:FindFirstChild("DoorFrame")
			expect(frame:FindFirstChild("ArtVisual")).to.equal(nil)
			local faces = { [1] = 0, [-1] = 0 }
			for _, trim in frame:GetChildren() do
				if trim:IsA("BasePart") then
					local localPosition = frame.CFrame:PointToObjectSpace(trim.Position)
					local side = if localPosition.Z > 0 then 1 else -1
					faces[side] += 1
					expect(trim.CanCollide).to.equal(false)
					expect(trim.CanQuery).to.equal(false)
					expect(trim.CanTouch).to.equal(false)
					if trim.Name == "Jamb" then
						expect(math.abs(localPosition.X) - trim.Size.X / 2 >= 5 - 0.001).to.equal(true)
						expect(trim.Size.X <= 0.2).to.equal(true)
					else
						expect(
							localPosition.Y + trim.Size.Y / 2 <= Constants.WALL_HEIGHT / 2 + 0.001
								and localPosition.Y - trim.Size.Y / 2 >= Constants.WALL_HEIGHT / 2 - 0.25
						).to.equal(true)
					end
				end
			end
			expect(faces[1]).to.equal(3)
			expect(faces[-1]).to.equal(3)
		end)
	end)

	describe("door headers", function()
		local function doorLayout(kind)
			return {
				startRoom = "a",
				rooms = {
					{ id = "a", name = "A", minX = 0, minZ = 0, maxX = 20, maxZ = 10 },
					{ id = "b", name = "B", minX = 0, minZ = 10, maxX = 20, maxZ = 20 },
				},
				doors = { { a = "a", b = "b", x = 10, z = 10, width = 6, kind = kind } },
				markers = {},
				truck = Layout.truck,
			}
		end
		it("closes the wall above a solid or glass door so nothing shows over the leaf", function()
			for _, kind in { "solid", "glass" } do
				local built = build(doorLayout(kind))
				local header = built.model.DoorFrames:FindFirstChild("DoorHeader")
				expect(header ~= nil).to.equal(true)
				expect(header.Size.X).to.be.near(6, 0.001)
				expect(header.Position.Y - header.Size.Y / 2).to.be.near(Constants.DOOR_HEIGHT, 0.001)
				expect(header.Position.Y + header.Size.Y / 2).to.be.near(Constants.WALL_HEIGHT, 0.001)
				expect(header.CanCollide).to.equal(true)
				expect(header.CanQuery).to.equal(true)
				built.doors.destroy()
			end
		end)
		it("leaves an open doorway full height", function()
			local built = build(doorLayout("open"))
			expect(built.model.DoorFrames:FindFirstChild("DoorHeader")).to.equal(nil)
			built.doors.destroy()
		end)
	end)

	describe("glass panes", function()
		it("builds one collidable, queryable GlassWall tagged SightThrough per pane", function()
			local layout = {
				startRoom = "a",
				rooms = {
					{ id = "a", name = "A", minX = 0, minZ = 0, maxX = 20, maxZ = 10 },
					{ id = "b", name = "B", minX = 0, minZ = 10, maxX = 20, maxZ = 20 },
				},
				doors = {},
				markers = {},
				truck = Layout.truck,
				panes = { { x1 = 10, z1 = 10, x2 = 16, z2 = 10 } },
			}
			local built = build(layout)
			local glass = {}
			for _, part in built.model.Walls:GetChildren() do
				if part.Name == "GlassWall" then
					table.insert(glass, part)
				end
			end
			expect(#glass).to.equal(1)
			expect(glass[1].Material).to.equal(Enum.Material.Glass)
			expect(math.abs(glass[1].Transparency - 0.55) < 1e-4).to.equal(true)
			expect(glass[1].CanCollide).to.equal(true)
			expect(glass[1].CanQuery).to.equal(true)
			expect(glass[1].Size.X).to.equal(6)
			expect(CollectionService:HasTag(glass[1], Occupant.SIGHT_THROUGH_TAG)).to.equal(true)
			expect(glass[1]:FindFirstChild("ArtVisual")).to.equal(nil)
		end)
	end)
end
