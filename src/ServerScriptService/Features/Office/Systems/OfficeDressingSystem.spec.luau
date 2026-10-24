local Server = game:GetService("ServerScriptService").Features.Office
local Dressing = require(script.Parent.OfficeDressingSystem)
local Build = require(script.Parent.OfficeBuildSystem)
local Rules = require(Server.Rules.OfficeVariationRules)
local Layout = require(Server.Data.OfficeLayoutConstants).LAYOUT
local Generate = require(Server.Utils.OfficeLayoutGenerationUtils)
local Visuals = require(game:GetService("ServerScriptService").Features.Art.Systems.ArtVisualSystem)

local ORIGIN = CFrame.new(70000, 0, 0)

local function emptyPlan()
	return { piles = {}, items = {}, searchables = {}, value = 0 }
end

local function pileMarkers()
	local list = {}
	for _, marker in Layout.markers do
		if marker.kind == "pile" then
			table.insert(list, marker)
		end
	end
	return list
end

return function()
	local parent
	local assets
	beforeEach(function()
		parent = Instance.new("Model")
		assets = Instance.new("Folder")
	end)
	afterEach(function()
		parent:Destroy()
		assets:Destroy()
	end)

	describe("OfficeDressingSystem.build", function()
		it("builds nothing for a nil seed", function()
			expect(Dressing.build(Layout, emptyPlan(), nil, ORIGIN, parent)).to.equal(nil)
			expect(#parent:GetChildren()).to.equal(0)
		end)

		it("dresses some free spots for a seed, under the parent", function()
			local found
			for seed = 1, 20 do
				local folder = Dressing.build(Layout, emptyPlan(), seed, ORIGIN, parent)
				if folder then
					found = folder
					expect(folder.Parent).to.equal(parent)
					break
				end
			end
			expect(found ~= nil).to.equal(true)
		end)

		it("never dresses a marker the plan used for a pile or an item", function()
			local markers = pileMarkers()
			local plan = emptyPlan()
			for _, marker in markers do
				table.insert(plan.piles, { marker = marker.id, kind = "dust" })
			end
			for seed = 1, 30 do
				expect(Dressing.build(Layout, plan, seed, ORIGIN, parent)).to.equal(nil)
			end
			-- Every other pile marker used (alternately as a pile and an item): each part sits nearest a free marker.
			local used = {}
			local half = emptyPlan()
			for index, marker in markers do
				if index % 2 == 0 then
					used[marker.id] = true
					if index % 4 == 0 then
						table.insert(half.items, { marker = marker.id, kind = "coin" })
					else
						table.insert(half.piles, { marker = marker.id, kind = "dust" })
					end
				end
			end
			local seen = 0
			for seed = 1, 30 do
				local folder = Dressing.build(Layout, half, seed, ORIGIN, parent)
				if folder then
					for _, part in folder:GetChildren() do
						local flat = Vector3.new(part.Position.X, 0, part.Position.Z)
						local nearest, best = nil, math.huge
						for _, marker in markers do
							local distance = (flat - ORIGIN:PointToWorldSpace(Vector3.new(marker.x, 0, marker.z))).Magnitude
							if distance < best then
								nearest, best = marker, distance
							end
						end
						expect(used[nearest.id]).to.equal(nil)
						seen += 1
					end
					folder:Destroy()
				end
			end
			expect(seen > 0).to.equal(true)
		end)

		it("makes every dressing part non-collide, non-query and non-touch", function()
			local checked = 0
			for seed = 1, 20 do
				local folder = Dressing.build(Layout, emptyPlan(), seed, ORIGIN, parent)
				if folder then
					for _, part in folder:GetChildren() do
						expect(part.CanCollide).to.equal(false)
						expect(part.CanQuery).to.equal(false)
						expect(part.CanTouch).to.equal(false)
						checked += 1
					end
					folder:Destroy()
				end
			end
			expect(checked > 0).to.equal(true)
		end)

		it("is deterministic for a seed", function()
			local a = Dressing.build(Layout, emptyPlan(), 7, ORIGIN, parent)
			local b = Dressing.build(Layout, emptyPlan(), 7, ORIGIN, parent)
			expect(a == nil).to.equal(b == nil)
			if a and b then
				expect(#a:GetChildren()).to.equal(#b:GetChildren())
			end
		end)
	end)

	describe("doors that start open", function()
		local built
		local function discard()
			if built then
				built.doors.destroy()
				built.model:Destroy()
				built = nil
			end
		end
		afterEach(discard)

		local function open(seed)
			discard()
			built = Build.build(Generate.generate(Layout, seed or 1), CFrame.new(71000, 0, 0), Visuals.new(assets))
			return built.doors.openAtStart(seed)
		end

		it("opens exactly the doors doorStartsOpen picks, instantly", function()
			local opened = open(3)
			local set = {}
			for _, id in opened do
				set[id] = true
			end
			for _, state in built.doors.states() do
				expect(state.open).to.equal(Rules.doorStartsOpen(3, state.id))
				expect(set[state.id] == true).to.equal(state.open)
			end
			for _, leaf in built.model.Doors:GetChildren() do
				local id = leaf:GetAttribute("OfficeDoorId")
				if id then
					expect(leaf.CanCollide).to.equal(not leaf:GetAttribute("OfficeDoorOpen"))
				end
			end
		end)

		it("opens some door for some seed in 1..20", function()
			local any = false
			for seed = 1, 20 do
				any = any or #open(seed) > 0
			end
			expect(any).to.equal(true)
		end)

		it("never opens a facade", function()
			for seed = 1, 20 do
				open(seed)
				for _, leaf in built.model.Doors:GetChildren() do
					if leaf:GetAttribute("OfficeFacade") then
						expect(leaf:GetAttribute("OfficeDoorOpen")).to.equal(nil)
						expect(leaf.CanCollide).to.equal(true)
					end
				end
			end
		end)

		it("opens nothing for a nil seed", function()
			expect(#open(nil)).to.equal(0)
			for _, state in built.doors.states() do
				expect(state.open).to.equal(false)
			end
		end)

		it("an opened door still closes on a toggle", function()
			for seed = 1, 20 do
				local opened = open(seed)
				if #opened > 0 then
					expect(built.doors.toggle(opened[1], nil)).to.equal(true)
					return
				end
			end
			expect(false).to.equal(true)
		end)
	end)
end
