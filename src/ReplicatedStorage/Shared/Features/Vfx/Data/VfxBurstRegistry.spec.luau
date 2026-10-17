local VfxBurstRegistry = require(script.Parent.VfxBurstRegistry)

local function layer(overrides)
	local base = {
		texture = "rbxassetid://1",
		color = ColorSequence.new(Color3.new(1, 1, 1)),
		size = NumberSequence.new(1, 0),
		transparency = NumberSequence.new(0, 1),
		lifetime = NumberRange.new(0.4, 0.6),
		speed = NumberRange.new(2, 4),
		count = 6,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function burst(overrides, layers)
	local base = { layers = layers or { layer() } }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function ensure(id, value)
	if not VfxBurstRegistry.has(id) then
		VfxBurstRegistry.register(id, value)
	end
end

return function()
	local function refuses(id, value)
		expect(function()
			VfxBurstRegistry.register(id, value)
		end).to.throw()
		expect(VfxBurstRegistry.has(id)).to.equal(false)
	end

	it("registers and returns a burst", function()
		ensure("spec-burst", burst())
		expect(#VfxBurstRegistry.get("spec-burst").layers).to.equal(1)
		expect(table.find(VfxBurstRegistry.ids(), "spec-burst")).to.be.ok()
	end)

	it("rejects a duplicate id", function()
		ensure("spec-burst-dup", burst())
		expect(function()
			VfxBurstRegistry.register("spec-burst-dup", burst())
		end).to.throw()
	end)

	it("rejects no layers and more than six", function()
		refuses("spec-burst-empty", burst(nil, {}))
		local seven = {}
		for _ = 1, 7 do
			table.insert(seven, layer())
		end
		refuses("spec-burst-seven", burst(nil, seven))
	end)

	it("rejects a layer with neither or both of count and rate", function()
		refuses("spec-burst-neither", burst(nil, { layer({ count = false }) }))
		refuses("spec-burst-both", burst(nil, { layer({ rate = 10 }) }))
	end)

	it("accepts a stream layer with only a rate", function()
		ensure("spec-burst-stream", burst(nil, { layer({ count = false, rate = 12 }) }))
		expect(VfxBurstRegistry.get("spec-burst-stream").layers[1].rate).to.equal(12)
	end)

	it("rejects an empty texture and a non-positive lifetime", function()
		refuses("spec-burst-texture", burst(nil, { layer({ texture = "" }) }))
		refuses("spec-burst-life", burst(nil, { layer({ lifetime = NumberRange.new(0) }) }))
	end)

	it("rejects more than the per-burst particle budget", function()
		refuses("spec-burst-budget", burst(nil, { layer({ count = 100 }), layer({ count = 60 }) }))
	end)

	it("rejects a light that is too bright or lasts too long", function()
		local light = { color = Color3.new(1, 0.8, 0.4), brightness = 3, range = 12, seconds = 0.4 }
		ensure("spec-burst-light", burst({ light = light }))
		refuses(
			"spec-burst-bright",
			burst({ light = { color = light.color, brightness = 9, range = 12, seconds = 0.4 } })
		)
		refuses("spec-burst-long", burst({ light = { color = light.color, brightness = 3, range = 12, seconds = 2 } }))
	end)

	it("rejects a negative delay", function()
		refuses("spec-burst-delay", burst(nil, { layer({ delay = -0.1 }) }))
	end)

	it("reports the tail: the last particle's death", function()
		ensure(
			"spec-burst-tail",
			burst(nil, {
				layer({ lifetime = NumberRange.new(0.2, 0.5) }),
				layer({ lifetime = NumberRange.new(0.3, 0.4), delay = 0.3 }),
			})
		)
		expect(math.abs(VfxBurstRegistry.tail(VfxBurstRegistry.get("spec-burst-tail")) - 0.7) < 1e-6).to.equal(true)
	end)
end
