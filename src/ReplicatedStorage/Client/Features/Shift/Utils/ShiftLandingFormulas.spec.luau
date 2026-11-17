local ShiftLandingFormulas = require(script.Parent.ShiftLandingFormulas)

local SEEDS = { 1, 2, 3, 42, 777, 123456, 987654321, 1000000000 }

return function()
	describe("night", function()
		it("gives the same night for the same seed (the whole crew sees one night)", function()
			for _, seed in SEEDS do
				local a = ShiftLandingFormulas.night(seed)
				local b = ShiftLandingFormulas.night(seed)
				expect(a.temperature).to.equal(b.temperature)
				expect(a.minutes).to.equal(b.minutes)
				expect(a.weather).to.equal(b.weather)
			end
		end)

		it("keeps the temperature a whole number from 30 to 48 °F", function()
			for seed = 1, 400 do
				local night = ShiftLandingFormulas.night(seed)
				expect(night.temperature % 1).to.equal(0)
				expect(night.temperature >= ShiftLandingFormulas.TEMPERATURE.min).to.equal(true)
				expect(night.temperature <= ShiftLandingFormulas.TEMPERATURE.max).to.equal(true)
			end
			expect(ShiftLandingFormulas.TEMPERATURE.min).to.equal(30)
			expect(ShiftLandingFormulas.TEMPERATURE.max).to.equal(48)
		end)

		it("is always night: 11:00 PM to 3:59 AM", function()
			for seed = 1, 400 do
				local minutes = ShiftLandingFormulas.night(seed).minutes
				expect(minutes % 1).to.equal(0)
				local late = minutes >= 23 * 60 and minutes < 24 * 60
				local early = minutes >= 0 and minutes <= 3 * 60 + 59
				expect(late or early).to.equal(true)
			end
		end)

		it("only picks calm weather with nothing the scene would contradict", function()
			local seen = {}
			for seed = 1, 400 do
				local weather = ShiftLandingFormulas.night(seed).weather
				expect(table.find(ShiftLandingFormulas.WEATHER, weather)).to.be.ok()
				seen[weather] = true
			end
			expect(#ShiftLandingFormulas.WEATHER).to.equal(3)
			for _, weather in { "Clear", "Cloudy", "Windy" } do
				expect(table.find(ShiftLandingFormulas.WEATHER, weather)).to.be.ok()
				expect(seen[weather]).to.equal(true)
			end
		end)

		it("varies from shift to shift", function()
			local temperatures, times = {}, {}
			for seed = 1, 200 do
				local night = ShiftLandingFormulas.night(seed)
				temperatures[night.temperature] = true
				times[night.minutes] = true
			end
			local count = 0
			for _ in temperatures do
				count += 1
			end
			expect(count > 10).to.equal(true)
			count = 0
			for _ in times do
				count += 1
			end
			expect(count > 50).to.equal(true)
		end)

		it("reads a fractional or negative seed without erroring", function()
			local night = ShiftLandingFormulas.night(-12.5)
			expect(night.temperature >= 30 and night.temperature <= 48).to.equal(true)
		end)
	end)
end
