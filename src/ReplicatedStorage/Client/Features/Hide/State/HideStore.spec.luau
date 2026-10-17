local HideStore = require(script.Parent.HideStore)

local function view(id)
	return { id = id, action = "Hide under", noun = "desk", key = "C", hold = 0.6 }
end

return function()
	afterEach(function()
		HideStore.clear()
	end)

	it("shows a prompt and hides only that one", function()
		HideStore.showPrompt(view(1))
		HideStore.hidePrompt(2)
		expect(HideStore.prompt().id).to.equal(1)
		HideStore.hidePrompt(1)
		expect(HideStore.prompt()).to.equal(nil)
	end)

	it("marks and clears the hold on the prompt shown only", function()
		HideStore.showPrompt(view(1))
		HideStore.holdBegan(2, 10)
		expect(HideStore.prompt().holdStartedAt).to.equal(nil)
		HideStore.holdBegan(1, 10)
		expect(HideStore.prompt().holdStartedAt).to.equal(10)
		HideStore.holdEnded(1)
		expect(HideStore.prompt().holdStartedAt).to.equal(nil)
	end)

	it("marks the hiding spot's door open or shut, and nothing while not hiding", function()
		HideStore.setDoorOpen(true)
		expect(HideStore.hidden()).to.equal(nil)
		HideStore.setHidden({ spotId = "cabinet.a", kind = "inside", noun = "cabinet", since = 5 })
		HideStore.setDoorOpen(true)
		expect(HideStore.hidden().doorOpen).to.equal(true)
		HideStore.setDoorOpen(false)
		expect(HideStore.hidden().doorOpen).to.equal(false)
	end)

	it("keeps a copy of the spot the player hides in", function()
		local hidden = { spotId = "desk.a", kind = "under", noun = "desk", since = 5 }
		HideStore.setHidden(hidden)
		hidden.noun = "changed"
		expect(HideStore.hidden().noun).to.equal("desk")
		HideStore.setHidden(nil)
		expect(HideStore.hidden()).to.equal(nil)
	end)
end
