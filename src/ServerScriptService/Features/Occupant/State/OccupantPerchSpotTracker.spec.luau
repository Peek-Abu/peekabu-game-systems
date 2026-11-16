local Workspace = game:GetService("Workspace")

local OccupantPerchSpotTracker = require(script.Parent.OccupantPerchSpotTracker)

-- A perch high over empty space (nothing above or below it): a proxy prop with a PERCH_TAG part as its child.
local function perch(at)
	local folder = Instance.new("Folder")
	folder.Name = "PerchSpotTrackerSpec"
	local proxy = Instance.new("Part")
	proxy.Anchored = true
	proxy.Size = Vector3.new(4, 6, 4)
	proxy.Position = at
	proxy.Parent = folder
	local spot = Instance.new("Part")
	spot.Anchored = true
	spot.Size = Vector3.new(1, 1, 1)
	spot.Position = at
	spot.Parent = proxy
	folder.Parent = Workspace
	return folder, proxy, spot
end

local function rig()
	return { model = Instance.new("Model") }
end

return function()
	describe("measure", function()
		it("sits on the proxy's top, its body 2 studs over it, named by the part's full name", function()
			local folder, _, spot = perch(Vector3.new(0, 20000, 0))
			local measured = OccupantPerchSpotTracker.measure(spot, rig())
			expect(measured.id).to.equal(spot:GetFullName())
			expect((measured.top - Vector3.new(0, 20003, 0)).Magnitude).to.be.near(0, 1e-3)
			expect((measured.at - measured.top - Vector3.new(0, 2, 0)).Magnitude).to.be.near(0, 1e-3)
			folder:Destroy()
		end)

		it("has endless headroom and no landing with nothing over or under it", function()
			local folder, _, spot = perch(Vector3.new(500, 20000, 0))
			local measured = OccupantPerchSpotTracker.measure(spot, rig())
			expect(measured.headroom).to.equal(math.huge)
			expect(#measured.landings).to.equal(0)
			folder:Destroy()
		end)

		it("takes the visible top from the prop's ArtVisual when it has one", function()
			local folder, proxy, spot = perch(Vector3.new(1000, 20000, 0))
			local visual = Instance.new("Model")
			visual.Name = "ArtVisual"
			local mesh = Instance.new("Part")
			mesh.Anchored = true
			mesh.Size = Vector3.new(4, 10, 4)
			mesh.Position = Vector3.new(1000, 20000, 0)
			mesh.Parent = visual
			visual.Parent = proxy
			local measured = OccupantPerchSpotTracker.measure(spot, rig())
			expect((measured.top - Vector3.new(1000, 20005, 0)).Magnitude).to.be.near(0, 1e-3)
			folder:Destroy()
		end)

		it("measures each part once: the same spot comes back", function()
			local folder, _, spot = perch(Vector3.new(1500, 20000, 0))
			local first = OccupantPerchSpotTracker.measure(spot, rig())
			local second = OccupantPerchSpotTracker.measure(spot, rig())
			expect(second).to.equal(first)
			folder:Destroy()
		end)
	end)
end
