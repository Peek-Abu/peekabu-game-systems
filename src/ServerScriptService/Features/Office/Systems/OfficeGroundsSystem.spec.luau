local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Server = ServerScriptService.Features.Office
local Grounds = require(script.Parent.OfficeGroundsSystem)
local Shell = require(script.Parent.OfficeShellVisualSystem)
local Constants = require(Server.Data.OfficeConstants)
local LayoutConstants = require(Server.Data.OfficeLayoutConstants)
local Generation = require(Server.Utils.OfficeLayoutGenerationUtils)
local LayoutUtils = require(Server.Utils.OfficeLayoutUtils)
local Visuals = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)
local Occupant = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local Interaction = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)

local ORIGIN = CFrame.new(70000, 0, 0)

-- A part's world bounding box (min, max); every part here is turned by a multiple of a quarter turn.
local function box(part)
	local half = part.CFrame:VectorToWorldSpace(part.Size / 2)
	half = Vector3.new(math.abs(half.X), math.abs(half.Y), math.abs(half.Z))
	return part.Position - half, part.Position + half
end

-- Whether two parts' boxes overlap by more than `slack` on every axis.
local function crosses(a, b, slack)
	local aMin, aMax = box(a)
	local bMin, bMax = box(b)
	return aMin.X < bMax.X - slack
		and bMin.X < aMax.X - slack
		and aMin.Y < bMax.Y - slack
		and bMin.Y < aMax.Y - slack
		and aMin.Z < bMax.Z - slack
		and bMin.Z < aMax.Z - slack
end

return function()
	local generated
	local function layout()
		if generated == nil then
			generated = Generation.generate(LayoutConstants.LAYOUT, 3)
		end
		return generated
	end

	local assets, art, model
	beforeEach(function()
		assets = Instance.new("Folder")
		art = Visuals.new(assets)
		model = Instance.new("Model")
	end)
	afterEach(function()
		model:Destroy()
		assets:Destroy()
	end)

	local function entranceOf(id)
		for _, entrance in layout().entrances do
			if entrance.id == id then
				return entrance
			end
		end
		return nil
	end

	describe("OfficeGroundsSystem", function()
		it("builds an invisible Outdoors safe volume per ground, floor to VOLUME_HEIGHT", function()
			Grounds.build(layout(), ORIGIN, model, art)
			local outdoors = model:FindFirstChild("Outdoors")
			expect(outdoors).to.be.ok()
			expect(#outdoors:GetChildren()).to.equal(2)
			for _, ground in layout().grounds do
				local volume = outdoors:FindFirstChild(ground.id)
				expect(volume).to.be.ok()
				expect(volume.CanQuery).to.equal(true)
				expect(volume.CanCollide).to.equal(false)
				expect(volume.CanTouch).to.equal(false)
				expect(volume.CastShadow).to.equal(false)
				expect(volume.Transparency).to.equal(1)
				local modifier = volume:FindFirstChildOfClass("PathfindingModifier")
				expect(modifier).to.be.ok()
				expect(modifier.Label).to.equal(Occupant.SAFE_ZONE_LABEL)
				expect(modifier.PassThrough).to.equal(false)
				local min, max = box(volume)
				local wantMin = ORIGIN:PointToWorldSpace(Vector3.new(ground.minX, 0, ground.minZ))
				local wantMax =
					ORIGIN:PointToWorldSpace(Vector3.new(ground.maxX, Constants.OUTSIDE.VOLUME_HEIGHT, ground.maxZ))
				expect((min - wantMin).Magnitude < 0.05).to.equal(true)
				expect((max - wantMax).Magnitude < 0.05).to.equal(true)
			end
		end)

		it("builds an invisible enter hit box at each outside door, tagged OfficeEnter with its EntranceId", function()
			local result = Grounds.build(layout(), ORIGIN, model, art)
			local entrances = model:FindFirstChild("Entrances")
			expect(entrances).to.be.ok()
			local ids = {}
			for _, part in entrances:GetChildren() do
				local id = part:GetAttribute("EntranceId")
				ids[id] = true
				local entrance = entranceOf(id)
				expect(entrance).to.be.ok()
				expect(part.Size).to.equal(Vector3.new(8, 10, 1))
				expect(part.CanCollide).to.equal(false)
				expect(part.CanQuery).to.equal(true)
				expect(part.Transparency).to.equal(1)
				expect(part:GetAttribute(Interaction.KIND_ATTRIBUTE)).to.equal(Constants.ENTER_KIND)
				expect(CollectionService:HasTag(part, Interaction.TAG)).to.equal(true)
				local at = ORIGIN:PointToObjectSpace(part.Position)
				expect(math.abs(at.X - entrance.outside.x) < 0.05).to.equal(true)
				expect(math.abs(at.Z - entrance.outside.z) < 0.05).to.equal(true)
				expect(math.abs(at.Y - 5) < 0.05).to.equal(true)
				expect(result.doors[id]).to.equal(part)
			end
			expect(#entrances:GetChildren()).to.equal(2)
			expect(ids.dock).to.equal(true)
			expect(ids.lobby).to.equal(true)
			expect(Constants.ENTER_KIND).to.equal("OfficeEnter")
			expect(Constants.LEAVE_KIND).to.equal("OfficeLeave")
		end)

		for _, case in
			{
				{ id = "dock", leaves = 1, material = Enum.Material.WoodPlanks },
				{ id = "lobby", leaves = 2, material = Enum.Material.Glass },
			}
		do
			it(
				`builds the {case.id} exit as a closed leaf flush on its room's wall, cased, signed, and clear of trim`,
				function()
					Shell.build(layout(), ORIGIN, model, art)
					local result = Grounds.build(layout(), ORIGIN, model, art)
					local entrance = entranceOf(case.id)
					local exit = entrance.exit
					local room = LayoutUtils.room(layout(), exit.a)
					local leaves = {}
					for _, part in model.Exits:GetChildren() do
						if part:GetAttribute("EntranceId") == case.id and part.Name ~= "ExitSign" then
							table.insert(leaves, part)
						end
					end
					expect(#leaves).to.equal(case.leaves)
					expect(result.exits[case.id]).to.equal(leaves[1])
					local inset = Constants.WALL_THICKNESS / 2 + Constants.DOOR_LEAF_THICKNESS / 2
					local horizontal = exit.z == room.minZ or exit.z == room.maxZ
					for _, leaf in leaves do
						expect(leaf:GetAttribute(Interaction.KIND_ATTRIBUTE)).to.equal(Constants.LEAVE_KIND)
						expect(CollectionService:HasTag(leaf, Interaction.TAG)).to.equal(true)
						expect(leaf:GetAttribute("OfficeDoorId")).to.equal(nil)
						expect(leaf:GetAttribute("OfficeFacade")).to.equal(nil)
						expect(leaf.CanCollide).to.equal(true)
						expect(leaf.Material).to.equal(case.material)
						local at = ORIGIN:PointToObjectSpace(leaf.Position)
						-- On the room side of the wall line, within the exit's span along it.
						if horizontal then
							local into = if exit.z == room.minZ then 1 else -1
							expect(math.abs(at.Z - (exit.z + into * inset)) < 0.05).to.equal(true)
							expect(math.abs(at.X - exit.x) < exit.width / 2).to.equal(true)
						else
							local into = if exit.x == room.minX then 1 else -1
							expect(math.abs(at.X - (exit.x + into * inset)) < 0.05).to.equal(true)
							expect(math.abs(at.Z - exit.z) < exit.width / 2).to.equal(true)
						end
						-- No wall slab or trim crosses the leaf.
						for _, part in model.Shell:GetChildren() do
							if
								part.Name == "Plaster"
								or part.Name == "Wainscot"
								or part.Name == "Rail"
								or part.Name == "Skirt"
							then
								expect(crosses(part, leaf, 0.02)).to.equal(false)
							end
						end
					end
					-- Cased like a facade: two jambs within the exit's span on its wall line.
					local jambs = 0
					for _, part in model.Shell:GetChildren() do
						if part.Name == "Jamb" then
							local at = ORIGIN:PointToObjectSpace(part.Position)
							local along = if horizontal then at.X - exit.x else at.Z - exit.z
							local across = if horizontal then at.Z - exit.z else at.X - exit.x
							if math.abs(along) <= exit.width / 2 + 0.01 and math.abs(across) < 1.5 then
								jambs += 1
							end
						end
					end
					expect(jambs).to.equal(2)
					-- An EXIT sign above it, on the room side.
					local signs = 0
					for _, part in model.Exits:GetChildren() do
						if part.Name == "ExitSign" and part:GetAttribute("EntranceId") == case.id then
							signs += 1
							local at = ORIGIN:PointToObjectSpace(part.Position)
							expect(at.Y - part.Size.Y / 2 >= Constants.DOOR_HEIGHT - 0.01).to.equal(true)
							expect(math.abs(at.X - exit.x) < 1).to.equal(true)
							expect(math.abs(at.Z - exit.z) < 1).to.equal(true)
						end
					end
					expect(signs).to.equal(1)
				end
			)
		end

		it("builds nothing for a layout without grounds (the authored LAYOUT)", function()
			local result = Grounds.build(LayoutConstants.LAYOUT, ORIGIN, model, art)
			expect(next(result.exits)).to.equal(nil)
			expect(next(result.doors)).to.equal(nil)
			expect(model:FindFirstChild("Outdoors")).to.equal(nil)
			expect(model:FindFirstChild("Entrances")).to.equal(nil)
			expect(model:FindFirstChild("Exits")).to.equal(nil)
		end)
	end)
end
