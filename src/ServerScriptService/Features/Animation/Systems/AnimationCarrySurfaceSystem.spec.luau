local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Surface = require(ServerScriptService.Features.Animation.Systems.AnimationCarrySurfaceSystem)
return function()
	local ORIGIN = CFrame.new(0, 3000, -300)
	local item, art, hidden, other
	beforeEach(function()
		-- An invisible proxy with a visible, non-queryable art part inside (as ArtVisualSystem leaves it), and an
		-- unrelated part in the way.
		item = Instance.new("Part")
		item.Anchored = true
		item.Size = Vector3.new(2, 2, 2)
		item.Transparency = 1
		item.CFrame = ORIGIN
		art = Instance.new("Part")
		art.Anchored = true
		art.Size = Vector3.new(1, 1, 1)
		art.CFrame = ORIGIN * CFrame.new(0, -0.5, 0)
		art.CanQuery = false
		art.Parent = item
		hidden = Instance.new("Part")
		hidden.Anchored = true
		hidden.Size = Vector3.new(0.2, 0.2, 0.2)
		hidden.Transparency = 1
		hidden.CFrame = ORIGIN * CFrame.new(0, 0.8, 0)
		hidden.Parent = item
		item.Parent = Workspace
		other = Instance.new("Part")
		other.Anchored = true
		other.Size = Vector3.new(4, 0.2, 4)
		other.CFrame = ORIGIN * CFrame.new(0, -1.5, 0)
		other.Parent = Workspace
	end)
	afterEach(function()
		item:Destroy()
		other:Destroy()
	end)

	it("lists what can be seen, or everything when nothing can", function()
		local parts = Surface.visibleParts(item)
		expect(#parts).to.equal(1)
		expect(parts[1]).to.equal(art)
		art.Transparency = 1
		expect(#Surface.visibleParts(item)).to.equal(3)
	end)

	it("hits only the visible art, in the box's space, with its outward normal", function()
		local box = ORIGIN * CFrame.new(0, -0.5, 0)
		local surface = Surface.open(item, box)
		-- From below, through the unrelated part: the art's bottom.
		local hit, normal = surface.probe(Vector3.new(0.2, -3, 0.1), Vector3.new(0, 4, 0))
		expect(hit).to.be.ok()
		expect(hit:FuzzyEq(Vector3.new(0.2, -0.5, 0.1), 1e-3)).to.equal(true)
		expect(normal:FuzzyEq(-Vector3.yAxis, 1e-3)).to.equal(true)
		-- The invisible parts are not the surface.
		expect(surface.probe(Vector3.new(0, 3, 0), Vector3.new(0, -2.2, 0))).to.equal(nil)
		surface.release()
	end)

	it("puts every part's CanQuery back on release, after which the probe finds nothing", function()
		local surface = Surface.open(item, ORIGIN)
		expect(art.CanQuery).to.equal(true)
		surface.release()
		expect(art.CanQuery).to.equal(false)
		expect(surface.probe(Vector3.new(0, -3, 0), Vector3.new(0, 4, 0))).to.equal(nil)
		surface.release()
		expect(art.CanQuery).to.equal(false)
	end)
end
