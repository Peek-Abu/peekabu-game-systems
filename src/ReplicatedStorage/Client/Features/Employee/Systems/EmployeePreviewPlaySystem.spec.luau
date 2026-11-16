local EmployeePreviewPlaySystem = require(script.Parent.EmployeePreviewPlaySystem)

return function()
	-- A model with no Humanoid, so no Animator: nothing can be loaded on it.
	local function bare()
		return Instance.new("Model")
	end

	it("crossfades a reveal into the idle over half a second and rests between emote plays", function()
		expect(EmployeePreviewPlaySystem.REVEAL_FADE).to.equal(0.5)
		expect(EmployeePreviewPlaySystem.EMOTE_PAUSE > 0).to.equal(true)
	end)

	it("plays nothing on a model without an Animator", function()
		local model = bare()
		expect(EmployeePreviewPlaySystem.playIdle(model, "Pippa", nil)).never.to.be.ok()
		expect(EmployeePreviewPlaySystem.playReveal(model, "Pippa", nil)).never.to.be.ok()
		expect(EmployeePreviewPlaySystem.playReaction(model, "Pippa", nil)).never.to.be.ok()
		expect(EmployeePreviewPlaySystem.playFidgets(model, "Pippa", nil)).never.to.be.ok()
		expect(EmployeePreviewPlaySystem.playEmote(model, "Pippa", nil, "Pippa.Bubbles")).never.to.be.ok()
		model:Destroy()
	end)

	it("plays nothing for an employee or emote with no clip", function()
		local model = bare()
		expect(EmployeePreviewPlaySystem.playIdle(model, "Nobody", nil)).never.to.be.ok()
		expect(EmployeePreviewPlaySystem.playEmote(model, "Pippa", nil, "Nobody.Nothing")).never.to.be.ok()
		model:Destroy()
	end)
end
