local OfficeAnomalyLookSystem = require(script.Parent.OfficeAnomalyLookSystem)

local function part(name, parent, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- A fresh state for anomaly `id`, as OfficeAnomalySystem.applySlot builds it.
local function newState(id)
	return {
		id = id,
		seed = 7,
		parts = {},
		labels = {},
		guis = {},
		added = {},
		sound = nil,
		leaves = {},
		door = { cycle = 0 },
		lastOpen = 0,
		wrong = "",
		label = nil,
		light = nil,
		emitter = nil,
		nextTailLook = 0,
		silhouette = { phase = "hidden" },
		shown = nil,
	}
end

return function()
	local root, slot
	local loops
	local function loop(id, at)
		table.insert(loops, { id = id, at = at })
		return nil
	end
	beforeEach(function()
		loops = {}
		root = Instance.new("Folder")
		root.Name = "OfficeExterior"
		slot = Instance.new("Model")
		slot.Parent = root
	end)
	afterEach(function()
		root:Destroy()
	end)

	describe("dress / restore", function()
		it("shows the wet floor sign and puts it back hidden", function()
			local sign = part("SignFront", slot, { Transparency = 1 })
			local state = newState("wetFloor")
			OfficeAnomalyLookSystem.dress(slot, state, 0, nil, nil, loop)
			expect(sign.Transparency).to.equal(0)
			OfficeAnomalyLookSystem.restore(state)
			expect(sign.Transparency).to.equal(1)
		end)

		it("lights the booth tv with a glow, plays its loop, and removes the glow on restore", function()
			local color = Color3.fromRGB(24, 24, 26)
			local tv = part("BoothTV", slot, { Color = color, Material = Enum.Material.SmoothPlastic })
			local state = newState("boothTv")
			OfficeAnomalyLookSystem.dress(slot, state, 0, nil, nil, loop)
			expect(tv.Material).to.equal(Enum.Material.Neon)
			expect(tv:FindFirstChild("AnomalyTvGlow")).to.be.ok()
			expect(state.light).to.be.ok()
			expect(#loops).to.equal(1)
			expect(loops[1].at).to.equal(tv)
			OfficeAnomalyLookSystem.restore(state)
			expect(tv.Material).to.equal(Enum.Material.SmoothPlastic)
			expect(tv.Color).to.equal(color)
			expect(tv:FindFirstChild("AnomalyTvGlow")).to.equal(nil)
		end)

		it("keeps a gone silhouette gone for its run, and hides its parts", function()
			local body = part("FigureBody", slot, { Transparency = 1 })
			local state = newState("silhouette")
			OfficeAnomalyLookSystem.dress(slot, state, 0, nil, 7, loop)
			expect(state.silhouette.phase).to.equal("gone")
			expect(body.Transparency).to.equal(1)
		end)

		it("shows a fresh silhouette", function()
			local body = part("FigureBody", slot, { Transparency = 1 })
			local state = newState("silhouette")
			OfficeAnomalyLookSystem.dress(slot, state, 0, nil, nil, loop)
			expect(state.silhouette.phase).to.equal("visible")
			expect(body.Transparency).to.equal(0)
			OfficeAnomalyLookSystem.restore(state)
			expect(body.Transparency).to.equal(1)
		end)

		it("reads each door leaf's side and slide, with defaults", function()
			local a = part("LobbyDoorLeaf", slot)
			a:SetAttribute("Side", -1)
			a:SetAttribute("SlideStuds", 3)
			part("LobbyDoorLeaf", slot)
			local state = newState("autoDoors")
			OfficeAnomalyLookSystem.dress(slot, state, 0, nil, nil, loop)
			expect(#state.leaves).to.equal(2)
			for _, leaf in state.leaves do
				if leaf.part == a then
					expect(leaf.side).to.equal(-1)
					expect(leaf.slide).to.equal(3)
				else
					expect(leaf.side).to.equal(1)
					expect(leaf.slide).to.equal(2.2)
				end
			end
		end)
	end)

	describe("setSilhouette", function()
		it("draws or hides every part, and records it", function()
			local body = part("FigureBody", slot, { Transparency = 1 })
			local state = newState("silhouette")
			OfficeAnomalyLookSystem.setSilhouette(slot, state, true)
			expect(body.Transparency).to.equal(0)
			expect(state.shown).to.equal(true)
			OfficeAnomalyLookSystem.setSilhouette(slot, state, false)
			expect(body.Transparency).to.equal(1)
			expect(state.shown).to.equal(false)
		end)
	end)

	describe("lightTails", function()
		it("lights the tail lights near the emitter once, and restore dims them back", function()
			local cars = Instance.new("Folder")
			cars.Parent = root
			local near = part("TailLight", cars, { Position = Vector3.new(4, 0, 0), Material = Enum.Material.Plastic })
			local far = part("TailLight", cars, { Position = Vector3.new(500, 0, 0), Material = Enum.Material.Plastic })
			local emitter = part("Emitter", slot, { Position = Vector3.new(0, 0, 0) })
			local state = newState("carTicking")
			OfficeAnomalyLookSystem.lightTails(slot, state, emitter)
			OfficeAnomalyLookSystem.lightTails(slot, state, emitter)
			expect(near.Material).to.equal(Enum.Material.Neon)
			expect(far.Material).to.equal(Enum.Material.Plastic)
			expect(#state.added).to.equal(1)
			OfficeAnomalyLookSystem.restore(state)
			expect(near.Material).to.equal(Enum.Material.Plastic)
			expect(near:FindFirstChild("AnomalyTailGlow")).to.equal(nil)
		end)
	end)
end
