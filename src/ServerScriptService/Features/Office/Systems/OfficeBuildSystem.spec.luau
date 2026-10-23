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
			local ceiling = built.model.Shell:FindFirstChild("Ceiling")
			expect(ceiling ~= nil).to.equal(true)
			expect(ceiling.CanCollide).to.equal(true)
			expect(ceiling.Transparency).to.equal(0)
			for _, part in built.searchables do
				expect(CollectionService:HasTag(part, Interaction.TAG)).to.equal(true)
				expect(part:GetAttribute(Interaction.ENABLED_ATTRIBUTE)).to.equal(false)
				expect(part.CanCollide).to.equal(true)
			end
			local light
			for _, descendant in built.model.Lights:GetDescendants() do
				if descendant:IsA("BasePart") and CollectionService:HasTag(descendant, Occupant.LIGHT_TAG) then
					light = descendant
					break
				end
			end
			expect(light ~= nil).to.equal(true)
			expect(light:FindFirstChildWhichIsA("Light") ~= nil).to.equal(true)
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
				-- A standing board is solid and queryable like a shelf; only the plant is not.
				expect(part.CanCollide).to.equal(name ~= "OfficePlant")
				expect(part.CanQuery).to.equal(name ~= "OfficePlant")
				-- Only wall-backed pieces push their art to the proxy's back face; a standing board stays centred.
				expect(part:GetAttribute("ArtWallMounted")).to.equal(
					if name == "Shelf" or name == "KitchenCounter" then true else nil
				)
				expect(CollectionService:HasTag(part, Interaction.TAG)).to.equal(false)
			end
		end)
	end)
	it("honors marker yaw and stands a board on the floor", function()
		local selected = table.clone(Layout)
		selected.markers = {
			{ id = "rotated.desk", room = selected.startRoom, kind = "desk", x = 7, z = 7, rotation = math.pi / 2 },
			{ id = "rotated.board", room = selected.startRoom, kind = "board", x = 8, z = 8, rotation = math.pi },
		}
		local built = build(selected)
		expect(built.searchables["rotated.desk"].CFrame.LookVector:Dot(Vector3.new(-1, 0, 0)) > 0.99).to.equal(true)
		local board = built.model:FindFirstChild("Corkboard", true)
		-- The build origin is at Y 0: a standing board's bottom is on the floor top.
		expect(math.abs(board.Position.Y - board.Size.Y / 2) < 1e-4).to.equal(true)
		expect(board.CFrame.LookVector.Z > 0.99).to.equal(true)
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
				-- The plaster slabs of the wall line at 20 (one per face): the aperture lies between their ends.
				for _, wall in built.model.Shell:GetChildren() do
					local line = if vertical then wall.Position.X - 50000 else wall.Position.Z
					-- Only slabs running along the wall line: the rooms' perpendicular side walls (merged across
					-- the line, so their centre also reads 20) are longer across than along it.
					local along = if vertical then wall.Size.Z > wall.Size.X else wall.Size.X > wall.Size.Z
					if wall.Name == "Plaster" and along and math.abs(line - 20) < 0.3 then
						local centre = if vertical then wall.Position.Z else wall.Position.X - 50000
						local half = if vertical then wall.Size.Z / 2 else wall.Size.X / 2
						if centre < 10 then
							left = centre + half
						else
							right = centre - half
						end
					end
				end
				expect(left ~= nil and right ~= nil).to.equal(true)
				expect(right - left).to.be.near(10, 0.001)
			end
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
				local header = built.model.Shell:FindFirstChild("DoorHeader")
				expect(header ~= nil).to.equal(true)
				expect(header.Size.X).to.be.near(6, 0.001)
				expect(header.Position.Y - header.Size.Y / 2).to.be.near(Constants.DOOR_HEIGHT, 0.001)
				expect(header.Position.Y + header.Size.Y / 2).to.be.near(Constants.WALL_HEIGHT + 1, 0.001)
				expect(header.CanCollide).to.equal(true)
				expect(header.CanQuery).to.equal(true)
				built.doors.destroy()
			end
		end)
		it("leaves an open doorway full height", function()
			local built = build(doorLayout("open"))
			expect(built.model.Shell:FindFirstChild("DoorHeader")).to.equal(nil)
			built.doors.destroy()
		end)
	end)

	describe("glass panes", function()
		it("builds one collidable, queryable Glass sheet tagged SightThrough per pane", function()
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
			for _, part in built.model.Shell:GetChildren() do
				if part.Name == "Glass" then
					table.insert(glass, part)
				end
			end
			expect(#glass).to.equal(1)
			expect(glass[1].Material).to.equal(Enum.Material.Glass)
			expect(glass[1].CanCollide).to.equal(true)
			expect(glass[1].CanQuery).to.equal(true)
			expect(CollectionService:HasTag(glass[1], Occupant.SIGHT_THROUGH_TAG)).to.equal(true)
			expect(glass[1]:FindFirstChild("ArtVisual")).to.equal(nil)
		end)
	end)

	describe("stray offices", function()
		it("clearStrays removes every office model in its container but the one kept, and counts them", function()
			-- Its own container: whatever else stands in Workspace (another spec's office, the boot's) is not counted.
			local container = Instance.new("Folder")
			container.Name = "StrayOfficeSpec"
			container.Parent = workspace
			table.insert(models, container)
			local function office(name)
				local model = Instance.new("Model")
				model.Name = name
				model.Parent = container
				return model
			end
			local kept = office(Constants.MODEL_NAME)
			local strayA = office(Constants.MODEL_NAME)
			local strayB = office(Constants.MODEL_NAME)
			local other = office("NotTheOffice")
			expect(Build.clearStrays(kept, container)).to.equal(2)
			expect(strayA.Parent).to.equal(nil)
			expect(strayB.Parent).to.equal(nil)
			expect(kept.Parent).to.equal(container)
			expect(other.Parent).to.equal(container)
			expect(Build.clearStrays(kept, container)).to.equal(0)
			expect(Build.clearStrays(nil, container)).to.equal(1)
			expect(kept.Parent).to.equal(nil)
		end)
	end)

	describe("art keys", function()
		local function twoRooms(kind, roomTypeA)
			return {
				artKit = "test-map-a",
				startRoom = "a",
				rooms = {
					{ id = "a", name = "A", minX = 0, minZ = 0, maxX = 20, maxZ = 10, roomType = roomTypeA },
					{ id = "b", name = "B", minX = 0, minZ = 10, maxX = 20, maxZ = 20 },
				},
				doors = { { a = "a", b = "b", x = 10, z = 10, width = 6, kind = kind } },
				markers = {},
				truck = Layout.truck,
			}
		end
		local function floorOf(built, roomName)
			return built.model[roomName].Floor
		end
		-- Marks a template's body so a test can tell which key's template was attached.
		local function mark(family, key)
			assets["test-map-a"][family][key]:FindFirstChildOfClass("Part").Name = key
		end

		it("overrides a shelf marker's art key", function()
			template("furniture", "shelf")
			template("furniture", "serverRack")
			mark("furniture", "serverRack")
			local layout = twoRooms("open", nil)
			layout.markers = {
				{ id = "a.shelf.1", room = "a", kind = "shelf", x = 5, z = 5, art = "serverRack" },
				{ id = "a.shelf.2", room = "a", kind = "shelf", x = 12, z = 5 },
			}
			local built = build(layout)
			local racks = 0
			for _, part in built.model.Furniture:GetChildren() do
				local visual = part:FindFirstChild("ArtVisual")
				expect(visual ~= nil).to.equal(true)
				if visual:FindFirstChild("serverRack") then
					racks += 1
				end
			end
			expect(racks).to.equal(1)
		end)

		it("sizes a restyled marker's proxy by its art's ART_SIZES entry", function()
			for _, key in { "serverRack", "kitchenCounter", "corkboard", "shelf" } do
				template("furniture", key)
			end
			local layout = twoRooms("open", nil)
			layout.markers = {
				{ id = "a.shelf.1", room = "a", kind = "shelf", x = 5, z = 5, art = "serverRack" },
				{ id = "a.counter.1", room = "a", kind = "counter", x = 12, z = 5, art = "kitchenCounter" },
				{ id = "a.board.1", room = "a", kind = "board", x = 5, z = 12, art = "corkboard" },
				{ id = "a.shelf.2", room = "a", kind = "shelf", x = 12, z = 12 },
			}
			local built = build(layout)
			local furniture = built.model.Furniture
			local sizes = {}
			for _, part in furniture:GetChildren() do
				local id = part:GetAttribute("OfficeMarkerId")
				if id ~= nil then
					sizes[id] = part.Size
				end
			end
			expect(sizes["a.shelf.1"]).to.equal(Vector3.new(2, 7, 3.5))
			expect(sizes["a.counter.1"]).to.equal(Vector3.new(8, 6.35, 3.08))
			expect(sizes["a.board.1"]).to.equal(Vector3.new(6.4, 6.1, 1.9))
			expect(sizes["a.shelf.2"]).to.equal(Constants.SHELF_SIZE)
		end)

		it("hangs one blue point light on a server rack's LedLight attachment", function()
			template("furniture", "serverRack")
			local part = assets["test-map-a"].furniture.serverRack:FindFirstChildOfClass("Part")
			local attachment = Instance.new("Attachment")
			attachment.Name = "LedLight"
			attachment.Parent = part
			local layout = twoRooms("open", nil)
			layout.markers = { { id = "a.shelf.1", room = "a", kind = "shelf", x = 5, z = 5, art = "serverRack" } }
			local built = build(layout)
			local lights = {}
			for _, descendant in built.model.Furniture:GetDescendants() do
				if descendant:IsA("PointLight") then
					table.insert(lights, descendant)
				end
			end
			expect(#lights).to.equal(1)
			expect(lights[1].Parent.Name).to.equal("LedLight")
			expect(lights[1].Color).to.equal(Color3.fromRGB(120, 170, 255))
			expect(lights[1].Range).to.equal(6)
			expect(math.abs(lights[1].Brightness - 0.4) < 1e-4).to.equal(true)
			expect(lights[1].Shadows).to.equal(false)
		end)

		it("hangs the LED light on any attached template with a LedLight attachment, not only a server rack", function()
			template("furniture", "shelf")
			local part = assets["test-map-a"].furniture.shelf:FindFirstChildOfClass("Part")
			local attachment = Instance.new("Attachment")
			attachment.Name = "LedLight"
			attachment.Parent = part
			local layout = twoRooms("open", nil)
			layout.markers = { { id = "a.shelf.1", room = "a", kind = "shelf", x = 5, z = 5 } }
			local built = build(layout)
			local lights = {}
			for _, descendant in built.model.Furniture:GetDescendants() do
				if descendant:IsA("PointLight") then
					table.insert(lights, descendant)
				end
			end
			expect(#lights).to.equal(1)
			expect(lights[1].Parent.Name).to.equal("LedLight")
		end)

		it("hangs every ACCENT_LIGHTS attachment's light on furniture, and none on other attachments", function()
			template("furniture", "shelf")
			template("furniture", "desk")
			local shelfBody = assets["test-map-a"].furniture.shelf:FindFirstChildOfClass("Part")
			local screen = Instance.new("Attachment")
			screen.Name = "ScreenLight"
			screen.Parent = shelfBody
			local other = Instance.new("Attachment")
			other.Name = "NotALight"
			other.Parent = shelfBody
			local lamp = Instance.new("Attachment")
			lamp.Name = "LampLight"
			lamp.Parent = assets["test-map-a"].furniture.desk:FindFirstChildOfClass("Part")
			local layout = twoRooms("open", nil)
			layout.markers = {
				{ id = "a.shelf.1", room = "a", kind = "shelf", x = 5, z = 5 },
				{ id = "a.desk.1", room = "a", kind = "desk", x = 14, z = 5 },
			}
			local built = build(layout)
			local lights = {}
			for _, descendant in built.model.Furniture:GetDescendants() do
				if descendant:IsA("PointLight") then
					lights[descendant.Parent.Name] = descendant
					expect(descendant.Parent.Name ~= "NotALight").to.equal(true)
				end
			end
			local screenLight = lights.ScreenLight
			expect(screenLight ~= nil).to.equal(true)
			expect(math.abs(screenLight.Brightness - 0.7) < 1e-4).to.equal(true)
			expect(screenLight.Range).to.equal(6)
			expect(screenLight.Color).to.equal(Color3.fromRGB(190, 215, 255))
			expect(screenLight.Shadows).to.equal(false)
			local lampLight = lights.LampLight
			expect(lampLight ~= nil).to.equal(true)
			expect(math.abs(lampLight.Brightness - 1.6) < 1e-4).to.equal(true)
			expect(lampLight.Range).to.equal(11)
			expect(lampLight.Shadows).to.equal(false)
		end)

		it("hangs no LED light on a template without the attachment, even a server rack", function()
			template("furniture", "serverRack")
			local layout = twoRooms("open", nil)
			layout.markers = { { id = "a.shelf.1", room = "a", kind = "shelf", x = 5, z = 5, art = "serverRack" } }
			local built = build(layout)
			for _, descendant in built.model.Furniture:GetDescendants() do
				expect(descendant:IsA("PointLight")).to.equal(false)
			end
		end)

		it("gives a solid door's leaf the doorLeaf template and a glass door's the doorLeafGlass one", function()
			template("building", "doorLeaf")
			template("building", "doorLeafGlass")
			mark("building", "doorLeaf")
			mark("building", "doorLeafGlass")
			for kind, key in { solid = "doorLeaf", glass = "doorLeafGlass" } do
				local built = build(twoRooms(kind, nil))
				local leaf = built.model.Doors.DoorLeaf
				local visual = leaf:FindFirstChild("ArtVisual")
				expect(visual ~= nil).to.equal(true)
				expect(visual:FindFirstChild(key) ~= nil).to.equal(true)
				-- The leaf keeps its collision; the visual never collides and is welded to the leaf.
				expect(leaf.CanCollide).to.equal(true)
				expect(leaf.CanQuery).to.equal(true)
				for _, part in visual:GetDescendants() do
					if part:IsA("BasePart") then
						expect(part.CanCollide).to.equal(false)
						expect(part:FindFirstChild("ArtRootWeld").Part0).to.equal(leaf)
					end
				end
				built.doors.destroy()
				built.model:Destroy()
			end
		end)

		it("builds one leaf for a door id the layout repeats", function()
			local layout = twoRooms("solid", nil)
			table.insert(layout.doors, { a = "a", b = "b", x = 10, z = 10, width = 6, kind = "solid" })
			local built = build(layout)
			local leaves = 0
			for _, child in built.model.Doors:GetChildren() do
				if child.Name == "DoorLeaf" then
					leaves += 1
				end
			end
			expect(leaves).to.equal(1)
			expect(#built.doors.states()).to.equal(1)
			built.doors.destroy()
			built.model:Destroy()
		end)

		it("builds an entrance facade as two glass leaves sharing its casing, hinged at their outer edges", function()
			template("building", "doorLeafGlass")
			local layout = twoRooms("open", nil)
			layout.facades = { { room = "a", x = 0, z = 5, width = 12, kind = "entrance" } }
			local built = build(layout)
			local leaves = {}
			for _, leaf in built.model.Doors:GetChildren() do
				if leaf:GetAttribute("OfficeFacade") == "entrance" then
					table.insert(leaves, leaf)
				end
			end
			expect(#leaves).to.equal(2)
			local sides = 0
			-- Each leaf is half the clear opening inside the casing: (12 - 2 x casing) / 2.
			local width = (12 - 2 * Constants.SHELL.casing) / 2
			for _, leaf in leaves do
				expect(math.abs(leaf.Size.X - width) < 1e-3).to.equal(true)
				expect(leaf.Material).to.equal(Enum.Material.Glass)
				expect(leaf:FindFirstChild("ArtVisual") ~= nil).to.equal(true)
				-- Side by side, flush on the wall, meeting at the facade's centre: each centred half a leaf either side.
				expect(math.abs(math.abs(leaf.Position.Z - 5) - width / 2) < 1e-3).to.equal(true)
				-- The hinge is the leaf's local +X: it lies toward the outer edge, away from the centre.
				expect((leaf.Position.Z - 5) * leaf.CFrame.RightVector.Z > 0).to.equal(true)
				sides += if leaf.Position.Z > 5 then 1 else 0
			end
			expect(sides).to.equal(1)
			built.doors.destroy()
		end)

		it("builds a stairwell facade as one solid leaf filling its casing", function()
			local layout = twoRooms("open", nil)
			layout.facades = { { room = "a", x = 0, z = 5, width = 6, kind = "stairwell" } }
			local built = build(layout)
			local count = 0
			for _, leaf in built.model.Doors:GetChildren() do
				if leaf:GetAttribute("OfficeFacade") == "stairwell" then
					count += 1
					-- The clear opening inside the casing, centred on the facade.
					expect(math.abs(leaf.Size.X - (6 - 2 * Constants.SHELL.casing)) < 1e-3).to.equal(true)
					expect(math.abs(leaf.Position.Z - 5) < 1e-3).to.equal(true)
					expect(leaf.Material).to.equal(Enum.Material.WoodPlanks)
				end
			end
			expect(count).to.equal(1)
			built.doors.destroy()
		end)

		it("gives an elevator facade no leaf and no prompt: the elevator art is its own front", function()
			local layout = twoRooms("open", nil)
			layout.facades = { { room = "a", x = 0, z = 5, width = 6, kind = "elevator" } }
			local built = build(layout)
			for _, leaf in built.model.Doors:GetChildren() do
				expect(leaf:GetAttribute("OfficeFacade")).to.equal(nil)
			end
			built.doors.destroy()
		end)

		it("tags every facade leaf for Interaction as the locked-door kind, and real leaves as doors", function()
			local layout = twoRooms("solid", nil)
			layout.facades = {
				{ room = "a", x = 0, z = 5, width = 12, kind = "entrance" },
				{ room = "a", x = 20, z = 5, width = 6, kind = "stairwell" },
			}
			local built = build(layout)
			local facades, doors = 0, 0
			for _, leaf in built.model.Doors:GetChildren() do
				expect(CollectionService:HasTag(leaf, Interaction.TAG)).to.equal(true)
				if leaf:GetAttribute("OfficeFacade") ~= nil then
					facades += 1
					expect(leaf:GetAttribute(Interaction.KIND_ATTRIBUTE)).to.equal(Constants.FACADE_KIND)
				else
					doors += 1
					expect(leaf:GetAttribute(Interaction.KIND_ATTRIBUTE)).to.equal(Constants.DOOR_KIND)
				end
			end
			expect(facades).to.equal(3)
			expect(doors).to.equal(1)
			built.doors.destroy()
		end)

		it("rattles a facade leaf and returns it exactly to its frame, ignoring interacts mid-rattle", function()
			local layout = twoRooms("open", nil)
			layout.facades = { { room = "a", x = 0, z = 5, width = 6, kind = "stairwell" } }
			local built = build(layout)
			local leaf
			for _, child in built.model.Doors:GetChildren() do
				if child:GetAttribute("OfficeFacade") ~= nil then
					leaf = child
				end
			end
			local frame = leaf.CFrame
			expect(built.doors.rattle(leaf)).to.equal(true)
			expect(built.doors.rattle(leaf)).to.equal(false)
			task.wait(Constants.DOOR_RATTLE_SECONDS + 0.3)
			expect(leaf.CFrame).to.equal(frame)
			expect(built.doors.rattle(leaf)).to.equal(true)
			built.doors.destroy()
		end)

		describe("Harlow's door reach", function()
			local npcs = {}
			afterEach(function()
				for _, npc in npcs do
					npc:Destroy()
				end
				table.clear(npcs)
			end)
			-- The door of twoRooms stands at (50010, 4.7, 10): a point `dz` studs from it along Z.
			local function at(dz)
				return Vector3.new(50010, 3, 10 + dz)
			end
			local function npcAt(position)
				local model = Instance.new("Model")
				model.Name = "TestNpc"
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Anchored = true
				root.CanCollide = false
				root.Position = position
				root.Parent = model
				Instance.new("Humanoid").Parent = model
				model.Parent = workspace
				table.insert(npcs, model)
			end

			it("does not open a door 9 studs away", function()
				local built = build(twoRooms("solid", nil))
				expect(built.doors.openNear(at(-9), Vector3.new(0, 0, 1))).to.equal(false)
				expect(built.model.Doors.DoorLeaf:GetAttribute("OfficeDoorOpen")).to.equal(false)
				built.doors.destroy()
			end)

			it("does not open a door 6 studs behind him", function()
				local built = build(twoRooms("solid", nil))
				expect(built.doors.openNear(at(6), Vector3.new(0, 0, 1))).to.equal(false)
				expect(built.model.Doors.DoorLeaf:GetAttribute("OfficeDoorOpen")).to.equal(false)
				built.doors.destroy()
			end)

			it("opens nothing for a man with no heading, even a door 6 studs off", function()
				local built = build(twoRooms("solid", nil))
				expect(built.doors.openNear(at(-6), nil)).to.equal(false)
				expect(built.model.Doors.DoorLeaf:GetAttribute("OfficeDoorOpen")).to.equal(false)
				built.doors.destroy()
			end)

			it("does not open a side door he walks past: 5 to the side and 3 ahead", function()
				local built = build(twoRooms("solid", nil))
				-- Walking along +X past the door (its centre 3 ahead of him and 5 to his side).
				local point = Vector3.new(50010 - 3, 3, 10 - 5)
				expect(built.doors.openNear(point, Vector3.new(1, 0, 0))).to.equal(false)
				expect(built.model.Doors.DoorLeaf:GetAttribute("OfficeDoorOpen")).to.equal(false)
				built.doors.destroy()
			end)

			it("opens a door 2.5 studs to his side whatever his heading, without a beat", function()
				local built = build(twoRooms("solid", nil))
				-- Beside the door, walking along +Z (the door is level with him, 2.5 to his side).
				local beside = Vector3.new(50010 - 2.5, 3, 10)
				expect(built.doors.openNear(beside, Vector3.new(0, 0, 1))).to.equal(false)
				expect(built.model.Doors.DoorLeaf:GetAttribute("OfficeDoorOpen")).to.equal(true)
				built.doors.destroy()
			end)

			it("opens a door 2.5 studs away with no heading", function()
				local built = build(twoRooms("solid", nil))
				expect(built.doors.openNear(at(-2.5), nil)).to.equal(false)
				expect(built.model.Doors.DoorLeaf:GetAttribute("OfficeDoorOpen")).to.equal(true)
				built.doors.destroy()
			end)

			it("keeps a door 4 studs to his side shut", function()
				local built = build(twoRooms("solid", nil))
				local beside = Vector3.new(50010 - 4, 3, 10)
				expect(built.doors.openNear(beside, Vector3.new(0, 0, 1))).to.equal(false)
				expect(built.doors.openNear(beside, nil)).to.equal(false)
				expect(built.model.Doors.DoorLeaf:GetAttribute("OfficeDoorOpen")).to.equal(false)
				built.doors.destroy()
			end)

			it("opens a door 6 studs ahead", function()
				local built = build(twoRooms("solid", nil))
				expect(built.doors.openNear(at(-6), Vector3.new(0, 0, 1))).to.equal(true)
				expect(built.model.Doors.DoorLeaf:GetAttribute("OfficeDoorOpen")).to.equal(true)
				built.doors.destroy()
			end)

			it("lets a player close a door with an NPC 9 studs away, and refuses it at 6", function()
				local built = build(twoRooms("solid", nil))
				local player = {}
				for _, dz in { -9, -6 } do
					built.doors.closeAll()
					expect(built.doors.toggle("a|b", nil)).to.equal(true)
					task.wait(Constants.DOOR_SWING_SECONDS + 0.3)
					npcAt(at(dz))
					expect(built.doors.toggle("a|b", player)).to.equal(dz == -9)
					for _, npc in npcs do
						npc:Destroy()
					end
					table.clear(npcs)
					task.wait(Constants.DOOR_SWING_SECONDS + 0.3)
				end
				built.doors.destroy()
			end)
		end)

		it("flags only a closed solid art leaf as a camera occluder", function()
			template("building", "doorLeaf")
			template("building", "doorLeafGlass")
			local solid = build(twoRooms("solid", nil))
			local leaf = solid.model.Doors.DoorLeaf
			expect(leaf:GetAttribute("CameraOccluder")).to.equal(true)
			expect(solid.doors.toggle("a|b", nil)).to.equal(true)
			expect(leaf:GetAttribute("CameraOccluder")).to.equal(nil)
			solid.doors.closeAll()
			expect(leaf:GetAttribute("CameraOccluder")).to.equal(true)
			solid.doors.destroy()
			local glass = build(twoRooms("glass", nil))
			expect(glass.model.Doors.DoorLeaf:GetAttribute("CameraOccluder")).to.equal(nil)
			glass.doors.destroy()
		end)

		it("keeps the glass leaf's greybox look when no door art exists", function()
			local built = build(twoRooms("glass", nil))
			local leaf = built.model.Doors.DoorLeaf
			expect(leaf:FindFirstChild("ArtVisual")).to.equal(nil)
			expect(leaf.Material).to.equal(Enum.Material.Glass)
			expect(leaf.Transparency).to.equal(0.5)
			built.doors.destroy()
		end)

		it(
			"fills the clear opening with a leaf: the door minus a casing each side, a casing short of the top",
			function()
				local built = build(twoRooms("solid", nil))
				local leaf = built.model.Doors.DoorLeaf
				expect(leaf.Size.X).to.be.near(6 - 2 * Constants.SHELL.casing, 0.001)
				expect(leaf.Size.Y).to.be.near(Constants.DOOR_HEIGHT - Constants.SHELL.casing, 0.001)
				expect(leaf.Size.Z).to.be.near(Constants.DOOR_LEAF_THICKNESS, 0.001)
				built.doors.destroy()
			end
		)

		it("floors each room in its type's material, with no art tile or underlay", function()
			local layout = twoRooms("open", "server")
			layout.rooms[2].zone = "hallway"
			local built = build(layout)
			expect(floorOf(built, "A").Material).to.equal(Enum.Material.Plastic)
			expect(floorOf(built, "B").Material).to.equal(Enum.Material.Fabric)
			expect(floorOf(built, "B").Color).to.equal(Constants.SHELL_MATERIALS.hallcarpet.color)
			expect(floorOf(built, "A"):FindFirstChild("ArtVisual")).to.equal(nil)
			expect(built.model.A:FindFirstChild("FloorUnderlay")).to.equal(nil)
		end)

		it("floors the start room (the bay) in vinyl and other untyped rooms in carpet", function()
			local built = build(twoRooms("open", nil))
			expect(floorOf(built, "A").Material).to.equal(Enum.Material.Plastic)
			expect(floorOf(built, "B").Material).to.equal(Enum.Material.Fabric)
		end)
	end)
end
