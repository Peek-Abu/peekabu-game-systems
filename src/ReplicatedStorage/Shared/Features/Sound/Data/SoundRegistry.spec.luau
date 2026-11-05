--[=[
	The registry is a module singleton that persists across a Studio test session: ids are "spec-*",
	registered behind `has` guards; refusal tests use fresh ids and assert nothing landed.
]=]

local SoundRegistry = require(script.Parent.SoundRegistry)

local function def(overrides)
	local base = { assetId = "rbxassetid://123", group = "SFX", volume = 1 }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function ensure(id, value)
	if not SoundRegistry.has(id) then
		SoundRegistry.register(id, value)
	end
end

return function()
	-- Inside the returned function: TestEZ injects `expect` only into this scope.
	local function refuses(id, value)
		expect(function()
			SoundRegistry.register(id, value)
		end).to.throw()
		expect(SoundRegistry.has(id)).to.equal(false)
	end

	it("registers and returns a sound", function()
		ensure("spec-click", def({ group = "UI" }))
		expect(SoundRegistry.get("spec-click").group).to.equal("UI")
		expect(table.find(SoundRegistry.ids(), "spec-click")).to.be.ok()
	end)

	it("accepts the optional fields", function()
		ensure(
			"spec-step",
			def({ pitch = { min = 0.9, max = 1.1 }, maxConcurrent = 3, rollOffMaxDistance = 80, looped = false })
		)
		expect(SoundRegistry.get("spec-step").maxConcurrent).to.equal(3)
	end)

	it("accepts heardEverywhere", function()
		ensure("spec-horn", def({ heardEverywhere = true }))
		expect(SoundRegistry.get("spec-horn").heardEverywhere).to.equal(true)
	end)

	it("rejects a heardEverywhere that is not a boolean", function()
		refuses("spec-everywhere-string", def({ heardEverywhere = "yes" }))
	end)

	it("accepts a pinned place", function()
		ensure("spec-yard-bed", def({ group = "Ambient", place = "Outside", looped = true }))
		expect(SoundRegistry.get("spec-yard-bed").place).to.equal("Outside")
		ensure("spec-office-bed", def({ group = "Ambient", place = "Building", looped = true }))
		expect(SoundRegistry.get("spec-office-bed").place).to.equal("Building")
	end)

	it("rejects an unknown place", function()
		refuses("spec-place-roof", def({ place = "Roof" }))
	end)

	it("rejects a place on a heardEverywhere sound (it is in no place)", function()
		refuses("spec-place-everywhere", def({ place = "Outside", heardEverywhere = true }))
	end)

	it("returns nil for an unknown id", function()
		expect(SoundRegistry.get("spec-none")).to.equal(nil)
	end)

	it("rejects a duplicate id", function()
		ensure("spec-dup", def())
		expect(function()
			SoundRegistry.register("spec-dup", def())
		end).to.throw()
	end)

	it("rejects a non-canonical asset id", function()
		refuses("spec-bad-asset", def({ assetId = "http://www.roblox.com/asset/?id=123" }))
	end)

	it("rejects an unknown group", function()
		refuses("spec-bad-group", def({ group = "Voices" }))
	end)

	it("rejects a volume outside 0..10", function()
		refuses("spec-loud", def({ volume = 11 }))
		refuses("spec-negative", def({ volume = -1 }))
	end)

	it("rejects a pitch range that is inverted or not positive", function()
		refuses("spec-pitch-inverted", def({ pitch = { min = 1.2, max = 0.8 } }))
		refuses("spec-pitch-zero", def({ pitch = { min = 0, max = 1 } }))
	end)

	it("rejects a maxConcurrent that is not a positive integer", function()
		refuses("spec-concurrent-zero", def({ maxConcurrent = 0 }))
		refuses("spec-concurrent-fraction", def({ maxConcurrent = 1.5 }))
	end)

	it("accepts a rollOffMinDistance under the max", function()
		ensure("spec-owl", def({ rollOffMinDistance = 20, rollOffMaxDistance = 200 }))
		expect(SoundRegistry.get("spec-owl").rollOffMinDistance).to.equal(20)
		ensure("spec-near", def({ rollOffMinDistance = 4 }))
		expect(SoundRegistry.get("spec-near").rollOffMinDistance).to.equal(4)
	end)

	it("rejects a rollOffMinDistance that is not positive or not under the max", function()
		refuses("spec-min-zero", def({ rollOffMinDistance = 0 }))
		refuses("spec-min-over", def({ rollOffMinDistance = 90, rollOffMaxDistance = 80 }))
		refuses("spec-min-equal", def({ rollOffMinDistance = 80, rollOffMaxDistance = 80 }))
	end)

	it("rejects a non-positive rollOffMaxDistance", function()
		refuses("spec-rolloff", def({ rollOffMaxDistance = 0 }))
	end)
end
