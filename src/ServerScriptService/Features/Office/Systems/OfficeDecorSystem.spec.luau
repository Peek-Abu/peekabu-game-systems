local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Features.Office
local CollectionService = game:GetService("CollectionService")
local Decor = require(script.Parent.OfficeDecorSystem)
local Build = require(Server.Systems.OfficeBuildSystem)
local Layout = require(Server.Data.OfficeLayoutConstants).LAYOUT
local OfficeConstants = require(Server.Data.OfficeConstants)
local Constants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local Visuals = require(game:GetService("ServerScriptService").Features.Art.Systems.ArtVisualSystem)
return function()
	local built
	local assets
	local art
	beforeEach(function()
		assets = Instance.new("Folder")
		art = Visuals.new(assets)
	end)
	afterEach(function()
		if built then
			built.model:Destroy()
		end
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
		local body = Instance.new("Part")
		body.Size = Vector3.new(1, 1, 1)
		body.CFrame = CFrame.new(0, 0.5, 0)
		body.Parent = model
		model.WorldPivot = CFrame.identity
		model.Parent = group
	end
	it("uses this map kit for exit, elevator and desktop visuals with fallback illumination retained", function()
		template("building", "exitSign")
		template("furniture", "elevatorFront")
		template("cargo", "monitor")
		template("props", "keyboard")
		template("props", "mouse")
		local layout = table.clone(Layout)
		layout.artKit = "test-map-a"
		built = Build.build(layout, CFrame.new(60000, 0, 0), art)
		local decor = Decor.build(layout, CFrame.new(60000, 0, 0), built.model, art)
		for _, name in { "ExitSign", "ElevatorFront", "Monitor" } do
			local proxy = decor:FindFirstChild(name, true)
			expect(proxy:FindFirstChild("ArtVisual") ~= nil).to.equal(true)
			expect(proxy:FindFirstChild("ArtVisual"):GetAttribute("ArtKitId")).to.equal("test-map-a")
			expect(proxy.CanCollide).to.equal(false)
			expect(proxy.CanQuery).to.equal(false)
		end
		local keyboard = built.model:FindFirstChild("Keyboard", true)
		expect(keyboard:FindFirstChild("ArtVisual") ~= nil).to.equal(true)
		expect(built.model:FindFirstChild("Keycap", true)).to.equal(nil)
		expect(decor:FindFirstChild("Screen", true).Transparency).to.equal(1)
		expect(decor:FindFirstChild("Screen", true):FindFirstChildOfClass("PointLight") ~= nil).to.equal(true)
	end)
	it("dresses desks with the complete eight-prop kit and chairs without gameplay tags or desktop overflow", function()
		for _, key in
			{
				"keyboard",
				"mouse",
				"mug",
				"paperTray",
				"folder",
				"paperStack",
				"bookStack",
				"stationeryCup",
			}
		do
			template("props", key)
		end
		-- A desk calendar left over in a place's kit (it was removed from the art kit) is never placed.
		template("props", "deskCalendar")
		template("furniture", "officeChair")
		template("cargo", "filingCabinet")
		template("furniture", "breakTable")
		local layout = table.clone(Layout)
		layout.artKit = "test-map-a"
		built = Build.build(layout, CFrame.new(60000, 0, 0), art)
		local decor = Decor.build(layout, CFrame.new(60000, 0, 0), built.model, art)
		local found = {}
		local chairs = 0
		local desks = 0
		for _, marker in layout.markers do
			if marker.kind == "desk" then
				desks += 1
			end
		end
		for _, root in decor:GetChildren() do
			local key = root:GetAttribute("OfficeArtKey")
			if key then
				found[key] = true
				expect(root.Transparency).to.equal(1)
				expect(root.CanCollide).to.equal(key == "filingCabinet" or key == "breakTable")
				expect(root.CanQuery).to.equal(root.CanCollide)
				expect(root.CanTouch).to.equal(false)
				-- Only the table is tagged, as a hiding spot (Hide); the cabinet is not. A chair carries only the chair
				-- tag, so clients and the Manager's senses find chairs without scanning the workspace.
				local hideable = key == "breakTable"
				local chair = key == "officeChair"
				expect(#CollectionService:GetTags(root)).to.equal(if hideable or chair then 1 else 0)
				expect(root:HasTag(Constants.CHAIR_TAG)).to.equal(chair)
				expect(root:HasTag("HideFurniture")).to.equal(hideable)
				expect(root:GetAttribute("HideFurnitureKind")).to.equal(if key == "breakTable" then "table" else nil)
				expect(root:FindFirstChild("ArtVisual") ~= nil).to.equal(true)
				if key == "officeChair" then
					chairs += 1
				elseif key == "filingCabinet" or key == "breakTable" then
					-- Surface furniture stands on its marker, sized to its top, never on a desk.
					local markerId = root:GetAttribute("OfficeDeskMarker")
					expect(markerId ~= nil).to.equal(true)
				else
					local desk = built.searchables[root:GetAttribute("OfficeDeskMarker")]
					local relative = desk.CFrame:PointToObjectSpace(root.Position)
					expect(math.abs(relative.X) + root.Size.X / 2 <= desk.Size.X / 2 + 0.01).to.equal(true)
					expect(math.abs(relative.Z) + root.Size.Z / 2 <= desk.Size.Z / 2 + 0.01).to.equal(true)
					expect(math.abs(root.Position.Y - root.Size.Y / 2 - (desk.Position.Y + desk.Size.Y / 2)) < 0.01).to.equal(
						true
					)
				end
			end
		end
		expect(chairs).to.equal(desks)
		for _, key in { "mug", "paperTray", "folder", "paperStack", "bookStack", "stationeryCup" } do
			expect(found[key]).to.equal(true)
		end
		-- The desk calendar left the art kit: no desk asks for it.
		expect(found.deskCalendar).to.equal(nil)
		for _, desk in built.searchables do
			if desk.Name == "Desk" then
				expect(desk:FindFirstChild("Keyboard"):FindFirstChild("ArtVisual") ~= nil).to.equal(true)
				expect(desk:FindFirstChild("Mouse"):FindFirstChild("ArtVisual") ~= nil).to.equal(true)
				expect(desk.CanCollide).to.equal(true)
			end
		end
	end)
	it("seats every chair facing its desk", function()
		template("furniture", "officeChair")
		local layout = table.clone(Layout)
		layout.artKit = "test-map-a"
		built = Build.build(layout, CFrame.new(60000, 0, 0), art)
		local decor = Decor.build(layout, CFrame.new(60000, 0, 0), built.model, art)
		local chairs = 0
		for _, root in decor:GetChildren() do
			if root:GetAttribute("OfficeArtKey") == "officeChair" then
				chairs += 1
				local desk = built.searchables[root:GetAttribute("OfficeDeskMarker")]
				expect(desk ~= nil).to.equal(true)
				-- Production officeChair art seats toward its CFrame LookVector (live Studio
				-- screenshot 2026-10-13: at turn 0 the backrest sits desk-side, facing away).
				local toDesk = (desk.Position - root.Position) * Vector3.new(1, 0, 1)
				expect(toDesk.Magnitude > 0.01).to.equal(true)
				expect(root.CFrame.LookVector:Dot(toDesk.Unit) > 0.99).to.equal(true)
			end
		end
		expect(chairs > 0).to.equal(true)
	end)
	it("faces every monitor screen toward its sitter", function()
		template("cargo", "monitor")
		local layout = table.clone(Layout)
		layout.artKit = "test-map-a"
		built = Build.build(layout, CFrame.new(60000, 0, 0), art)
		local decor = Decor.build(layout, CFrame.new(60000, 0, 0), built.model, art)
		local monitors = 0
		for _, child in decor:GetChildren() do
			if child.Name == "Monitor" and child:IsA("BasePart") then
				monitors += 1
				-- Production monitor art carries its display face on art-local -Z (live Studio
				-- screenshots 2026-10-13: the +Z face shows rear vents, the -Z face a clean
				-- display). The proxy stays unrotated so the screen faces the -Z sitter.
				expect(child.CFrame.LookVector:Dot(Vector3.new(0, 0, -1)) > 0.99).to.equal(true)
			end
		end
		expect(monitors > 0).to.equal(true)
	end)
	it("builds cabinet and table furniture on their markers", function()
		template("cargo", "filingCabinet")
		template("furniture", "breakTable")
		local layout = table.clone(Layout)
		layout.artKit = "test-map-a"
		built = Build.build(layout, CFrame.new(60000, 0, 0), art)
		local decor = Decor.build(layout, CFrame.new(60000, 0, 0), built.model, art)
		local byMarker: { [string]: BasePart } = {}
		for _, root in decor:GetChildren() do
			local key = root:GetAttribute("OfficeArtKey")
			if key == "filingCabinet" or key == "breakTable" then
				byMarker[root:GetAttribute("OfficeDeskMarker")] = root
			end
		end
		local count = 0
		for _, marker in layout.markers do
			if marker.kind == "cabinet" or marker.kind == "table" then
				count += 1
				local root = byMarker[marker.id]
				expect(root ~= nil).to.equal(true)
				local size = if marker.kind == "cabinet"
					then OfficeConstants.CABINET_SIZE
					else OfficeConstants.TABLE_SIZE
				expect(root.Size).to.equal(size)
				expect(root.Position.X).to.equal(60000 + marker.x)
				expect(root.Position.Y).to.equal(size.Y / 2)
				expect(root.Position.Z).to.equal(marker.z)
			end
		end
		expect(count).to.equal(6)
	end)
	it("creates no chair or extra prop roots when the selected kit is missing", function()
		local layout = table.clone(Layout)
		layout.artKit = "missing-test-kit"
		built = Build.build(layout, CFrame.new(60000, 0, 0), art)
		local decor = Decor.build(layout, CFrame.new(60000, 0, 0), built.model, art)
		for _, root in decor:GetChildren() do
			expect(root:GetAttribute("OfficeArtKey")).to.equal(nil)
		end
	end)
	it("preserves emitters and illumination with a single monitor per desk", function()
		local layout = table.clone(Layout)
		layout.artKit = "missing-test-kit"
		built = Build.build(layout, CFrame.new(60000, 0, 0), art)
		local decor = Decor.build(layout, CFrame.new(60000, 0, 0), built.model, art)
		local desks = 0
		local monitors = 0
		for _, marker in layout.markers do
			if marker.kind == "desk" then
				desks += 1
			end
		end
		for _, child in built.model:GetDescendants() do
			if child.Name == "Monitor" and child:IsA("BasePart") then
				monitors += 1
			end
		end
		expect(monitors).to.equal(desks)
		local sign = decor:FindFirstChild("ExitSign", true)
		expect(sign:FindFirstChildOfClass("PointLight") ~= nil).to.equal(true)
		local phone = decor:FindFirstChild("Ambient (phone)", true)
		expect(CollectionService:HasTag(phone, Constants.AMBIENT_TAG)).to.equal(true)
		expect(phone.Transparency).to.equal(1)
		expect(phone.CanQuery).to.equal(false)
		local elevator = decor:FindFirstChild("Ambient (elevator)", true)
		expect(CollectionService:HasTag(elevator, Constants.AMBIENT_TAG)).to.equal(true)
	end)
	it("rotates all desktop dressing with a rotated desk and turns the paper tray another half-turn", function()
		for _, key in { "mug", "stationeryCup", "folder", "paperTray" } do
			template("props", key)
		end
		local layout = table.clone(Layout)
		layout.artKit = "test-map-a"
		layout.markers =
			{ { id = "yaw.desk", kind = "desk", room = layout.startRoom, x = 9, z = 9, rotation = math.pi / 2 } }
		-- At60000studs float32 position precision is0.00390625, larger than the asserted desk offset tolerance.
		local origin = CFrame.new(6000, 0, 0)
		built = Build.build(layout, origin, art)
		local decor = Decor.build(layout, origin, built.model, art)
		local desk = built.searchables["yaw.desk"]
		local tray = decor:FindFirstChild("paperTray")
		expect(tray.CFrame.LookVector:Dot(desk.CFrame.LookVector) > 0.99).to.equal(true)
		local relative = desk.CFrame:PointToObjectSpace(tray.Position)
		-- Dressed at (1.85, 0.65) on a 5x3 top; the spot moves with the bigger top.
		local spread = OfficeConstants.DESK_SIZE / Vector3.new(5, 3, 3)
		expect(math.abs(relative.X - 1.85 * spread.X) < 0.001).to.equal(true)
		expect(math.abs(relative.Z - 0.65 * spread.Z) < 0.001).to.equal(true)
		local monitor = decor:FindFirstChild("Monitor")
		expect(monitor.CFrame.LookVector:Dot(desk.CFrame.LookVector) > 0.99).to.equal(true)
	end)
	it("omits chairs when furniture blocks every approach", function()
		template("furniture", "officeChair")
		local layout = table.clone(Layout)
		layout.artKit = "test-map-a"
		-- Each blocker stands where a chair would: beside the desk edge, the chair's depth and the gap away.
		local deskSize, chairSize = OfficeConstants.DESK_SIZE, OfficeConstants.OFFICE_CHAIR_SIZE
		local alongZ = deskSize.Z / 2 + chairSize.Z / 2 + OfficeConstants.OFFICE_CHAIR_GAP
		local alongX = deskSize.X / 2 + chairSize.Z / 2 + OfficeConstants.OFFICE_CHAIR_GAP
		layout.markers = {
			{ id = "test.desk", kind = "desk", room = layout.startRoom, x = 12, z = 12 },
			{ id = "test.counter.front", kind = "counter", room = layout.startRoom, x = 12, z = 12 - alongZ },
			{ id = "test.shelf.back", kind = "shelf", room = layout.startRoom, x = 12, z = 12 + alongZ },
			{ id = "test.table.left", kind = "table", room = layout.startRoom, x = 12 - alongX, z = 12 },
			{ id = "test.cabinet.right", kind = "cabinet", room = layout.startRoom, x = 12 + alongX, z = 12 },
		}
		local origin = CFrame.new(60000, 0, 0)
		built = Build.build(layout, origin, art)
		local decor = Decor.build(layout, origin, built.model, art)
		expect(decor:FindFirstChild("officeChair")).to.equal(nil)
	end)

	describe("prop markers and art keys", function()
		local function propLayout(markers)
			return {
				artKit = "test-map-a",
				startRoom = "a",
				rooms = { { id = "a", name = "A", minX = 0, minZ = 0, maxX = 40, maxZ = 40 } },
				doors = {},
				markers = markers,
				truck = Layout.truck,
			}
		end
		local function decorOf(layout)
			built = Build.build(layout, CFrame.new(60000, 0, 0), art)
			return Decor.build(layout, CFrame.new(60000, 0, 0), built.model, art)
		end

		it("builds a prop marker with a template as an art-only root of its PROP_SIZES size", function()
			template("furniture", "sofa")
			local decor = decorOf(propLayout({
				{ id = "a.prop.1", room = "a", kind = "prop", art = "sofa", x = 20, z = 20 },
			}))
			local root = decor:FindFirstChild("sofa")
			expect(root ~= nil).to.equal(true)
			expect(root:FindFirstChild("ArtVisual") ~= nil).to.equal(true)
			expect(root.Size).to.equal(OfficeConstants.PROP_SIZES.sofa)
			expect(root.Transparency).to.equal(1)
			expect(root.CanCollide).to.equal(true)
			expect(root.CanQuery).to.equal(true)
			expect(root.Position.Y).to.equal(OfficeConstants.PROP_SIZES.sofa.Y / 2)
			expect(root:GetAttribute("ArtWallMounted")).to.equal(nil)
		end)

		it("leaves no root for a prop marker without a template", function()
			local decor = decorOf(propLayout({
				{ id = "a.prop.1", room = "a", kind = "prop", art = "sofa", x = 20, z = 20 },
			}))
			expect(decor:FindFirstChild("sofa")).to.equal(nil)
		end)

		it("hangs a wall prop at its mounting height without collision", function()
			template("furniture", "artFrame")
			local decor = decorOf(propLayout({
				{ id = "a.prop.1", room = "a", kind = "prop", art = "artFrame", x = 20, z = 39.375 },
			}))
			local root = decor:FindFirstChild("artFrame")
			expect(root ~= nil).to.equal(true)
			expect(root:GetAttribute("ArtWallMounted")).to.equal(true)
			expect(root.Position.Y).to.equal(OfficeConstants.PROP_WALL_HEIGHT.artFrame)
			expect(root.CanCollide).to.equal(false)
		end)

		it("errors clearly on a prop marker with no art or an unsized one", function()
			local noArt = propLayout({ { id = "a.prop.1", room = "a", kind = "prop", x = 20, z = 20 } })
			expect(function()
				decorOf(noArt)
			end).to.throw("no art key")
			local unsized =
				propLayout({ { id = "a.prop.2", room = "a", kind = "prop", art = "nonsense", x = 20, z = 20 } })
			expect(function()
				decorOf(unsized)
			end).to.throw("PROP_SIZES")
		end)

		it("lets a table marker's art key win while keeping the table's hiding", function()
			template("furniture", "breakTable")
			template("furniture", "conferenceTable")
			assets["test-map-a"].furniture.conferenceTable:FindFirstChildOfClass("Part").Name = "Conference"
			local decor = decorOf(propLayout({
				{ id = "a.table.1", room = "a", kind = "table", art = "conferenceTable", x = 20, z = 20 },
				{ id = "a.table.2", room = "a", kind = "table", x = 30, z = 30 },
			}))
			local conference, plain = 0, 0
			for _, root in decor:GetChildren() do
				if root:GetAttribute("OfficeArtKey") == "breakTable" then
					expect(root:GetAttribute("HideFurnitureKind")).to.equal("table")
					if root:FindFirstChild("ArtVisual"):FindFirstChild("Conference") then
						conference += 1
					else
						plain += 1
					end
				end
			end
			expect(conference).to.equal(1)
			expect(plain).to.equal(1)
		end)
	end)
end
