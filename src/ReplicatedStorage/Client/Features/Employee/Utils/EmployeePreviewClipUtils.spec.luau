local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeePreviewClipUtils = require(script.Parent.EmployeePreviewClipUtils)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

return function()
	it(
		"names the idle clip a live preview plays: a skin's own showcase idle when it has one, else the employee's",
		function()
			expect(EmployeePreviewClipUtils.idleOf("Pippa")).to.equal("pippaidle")
			expect(EmployeePreviewClipUtils.idleOf("Pippa", "BubbleBuddy")).to.equal("pippabubblebuddyidle")
			expect(EmployeePreviewClipUtils.idleOf("Pippa", "NoSuchSkin")).to.equal("pippaidle")
			expect(EmployeePreviewClipUtils.idleOf("Nobody")).never.to.be.ok()
		end
	)

	it("names how far the clip a preview plays reaches", function()
		local pippa = EmployeeRegistry.get("Pippa")
		expect(EmployeePreviewClipUtils.reachOf("Pippa", "BubbleBuddy")).to.equal(pippa.skins.BubbleBuddy.showcaseReach)
		expect(EmployeePreviewClipUtils.reachOf("Pippa", "Default")).to.equal(pippa.previewReach)
		expect(EmployeePreviewClipUtils.reachOf("Nobody")).never.to.be.ok()
	end)

	it("names the fidget, the reveal and the menu reaction", function()
		expect(EmployeePreviewClipUtils.fidgetOf("Pippa", nil)).to.equal("pippafidget")
		expect(EmployeePreviewClipUtils.fidgetOf("Pippa", "BubbleBuddy")).to.equal("pippabubblebuddyfidget")
		expect(EmployeePreviewClipUtils.fidgetOf("Nobody", nil)).never.to.be.ok()
		expect(EmployeePreviewClipUtils.revealOf("Pippa", "BubbleBuddy")).to.equal("pippahirereveal")
		expect(EmployeePreviewClipUtils.revealOf("Prickles", nil)).to.equal("prickleshirereveal")
		expect(EmployeePreviewClipUtils.revealOf("Nobody", nil)).never.to.be.ok()
		expect(EmployeePreviewClipUtils.reactionOf("Pippa")).to.equal("pippaselect")
		expect(EmployeePreviewClipUtils.reactionOf("Nobody")).never.to.be.ok()
	end)

	it("names the clip an emote item loops, only for an emote with a clip", function()
		expect(EmployeePreviewClipUtils.emoteOf("Pippa.Bubbles")).to.equal("emote:Pippa.Bubbles")
		expect(EmployeePreviewClipUtils.emoteOf("Pippa.BubbleBuddy")).never.to.be.ok()
		expect(EmployeePreviewClipUtils.emoteOf("Nobody.Nothing")).never.to.be.ok()
	end)
end
