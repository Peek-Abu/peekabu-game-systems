local LockerStore = require(script.Parent.LockerStore)

return function()
	afterEach(function()
		LockerStore.reset()
	end)

	it("starts restricted (fail-closed) until the server sends Status", function()
		expect(LockerStore.restricted()).to.equal(true)
		LockerStore.setRestricted(false)
		expect(LockerStore.restricted()).to.equal(false)
	end)

	it("tracks the selected Locker, the odds sheet, the opening in progress and the last refusal", function()
		expect(LockerStore.selected()).to.equal("gloom")
		LockerStore.select("gleam")
		expect(LockerStore.selected()).to.equal("gleam")

		LockerStore.openOdds("gloom")
		expect(LockerStore.oddsFor()).to.equal("gloom")
		LockerStore.closeOdds()
		expect(LockerStore.oddsFor()).to.equal(nil)

		local outcome = {
			locker = "gloom",
			item = "Pippa.GloomTouched",
			rarity = "uncommon",
			duplicate = false,
			refund = 0,
			guaranteed = false,
			pity = 1,
		}
		LockerStore.startOpening(outcome)
		expect(LockerStore.opening().item).to.equal("Pippa.GloomTouched")
		local finished = LockerStore.finishOpening()
		expect(finished.item).to.equal("Pippa.GloomTouched")
		expect(LockerStore.opening()).to.equal(nil)

		LockerStore.setResult({ locker = "gloom", reason = "short" })
		expect(LockerStore.result().reason).to.equal("short")
	end)

	it("views one item's page and closes it; switching Lockers and reset close it too", function()
		LockerStore.reset()
		expect(LockerStore.viewing()).to.equal(nil)
		LockerStore.view("Pippa.GloomTouched")
		expect(LockerStore.viewing()).to.equal("Pippa.GloomTouched")
		LockerStore.view(nil)
		expect(LockerStore.viewing()).to.equal(nil)
		LockerStore.view("Pippa.GloomTouched")
		LockerStore.select("gleam")
		expect(LockerStore.viewing()).to.equal(nil)
		LockerStore.view("Pippa.GloomTouched")
		LockerStore.reset()
		expect(LockerStore.viewing()).to.equal(nil)
	end)
end
