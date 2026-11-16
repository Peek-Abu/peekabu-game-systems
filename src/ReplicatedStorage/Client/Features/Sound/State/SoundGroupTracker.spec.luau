local SoundService = game:GetService("SoundService")

local SoundGroupTracker = require(script.Parent.SoundGroupTracker)

return function()
	local OUTDOOR = { { min = Vector3.new(0, 0, 0), max = Vector3.new(10, 10, 10) } }

	afterEach(function()
		SoundGroupTracker.setPlaces({}, nil, 0)
	end)

	describe("pointOf", function()
		it("is the point itself for a Vector3", function()
			expect(SoundGroupTracker.pointOf(Vector3.new(1, 2, 3))).to.equal(Vector3.new(1, 2, 3))
		end)

		it("is nil for a 2D play", function()
			expect(SoundGroupTracker.pointOf(nil)).to.equal(nil)
		end)

		it("is a part's position", function()
			local part = Instance.new("Part")
			part.Position = Vector3.new(4, 5, 6)
			expect(SoundGroupTracker.pointOf(part)).to.equal(Vector3.new(4, 5, 6))
			part:Destroy()
		end)
	end)

	describe("setPlaces", function()
		it("remembers the boxes and the listener's place", function()
			SoundGroupTracker.setPlaces(OUTDOOR, "Outside", 0)
			expect(SoundGroupTracker.listener()).to.equal("Outside")
			expect(SoundGroupTracker.boxes()).to.equal(OUTDOOR)
		end)
	end)

	describe("placeFor", function()
		it("is placeless without boxes", function()
			local def = { assetId = "rbxassetid://1", group = "SFX", volume = 1 }
			expect(SoundGroupTracker.placeFor(def, Vector3.new(5, 5, 5))).to.equal(nil)
		end)

		it("places a positional play by the outdoor boxes", function()
			SoundGroupTracker.setPlaces(OUTDOOR, "Outside", 0)
			local def = { assetId = "rbxassetid://1", group = "SFX", volume = 1 }
			expect(SoundGroupTracker.placeFor(def, Vector3.new(5, 5, 5))).to.equal("Outside")
			expect(SoundGroupTracker.placeFor(def, Vector3.new(50, 5, 5))).to.equal("Building")
		end)

		it("never places a heardEverywhere sound, and always places a pinned one", function()
			SoundGroupTracker.setPlaces(OUTDOOR, "Outside", 0)
			local everywhere = { assetId = "rbxassetid://1", group = "SFX", volume = 1, heardEverywhere = true }
			local pinned = { assetId = "rbxassetid://1", group = "SFX", volume = 1, place = "Building" }
			expect(SoundGroupTracker.placeFor(everywhere, Vector3.new(5, 5, 5))).to.equal(nil)
			expect(SoundGroupTracker.placeFor(pinned, nil)).to.equal("Building")
		end)
	end)

	describe("groups", function()
		it("makes each volume group once, in SoundService", function()
			local group = SoundGroupTracker.groupFor("SFX")
			expect(group).to.equal(SoundGroupTracker.groupFor("SFX"))
			expect(group.Parent).to.equal(SoundService)
			expect(group.Name).to.equal("SFX")
		end)

		it("is the volume group itself with no bus and no place", function()
			expect(SoundGroupTracker.busGroupFor("SFX", nil)).to.equal(SoundGroupTracker.groupFor("SFX"))
			expect(SoundGroupTracker.placeGroupFor("SFX", nil, nil)).to.equal(SoundGroupTracker.groupFor("SFX"))
		end)

		it("nests a place group in its volume group", function()
			local place = SoundGroupTracker.placeGroupFor("SFX", nil, "Building")
			expect(place.Name).to.equal("Building")
			expect(place.Parent).to.equal(SoundGroupTracker.groupFor("SFX"))
			expect(SoundGroupTracker.placeGroupFor("SFX", nil, "Building")).to.equal(place)
		end)

		it("fades the other place's groups out when the listener moves (at once with no fade)", function()
			local outside = SoundGroupTracker.placeGroupFor("SFX", nil, "Outside")
			SoundGroupTracker.setPlaces(OUTDOOR, "Building", 0)
			expect(outside.Volume).to.equal(0)
			SoundGroupTracker.setPlaces(OUTDOOR, "Outside", 0)
			expect(outside.Volume).to.equal(1)
		end)
	end)
end
