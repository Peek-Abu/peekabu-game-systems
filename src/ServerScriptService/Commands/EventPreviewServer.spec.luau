local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EventConstants = require(ReplicatedStorage.Shared.Features.Event.Data.EventConstants)
local eventPreviewCommand = require(ServerScriptService.Commands.EventPreviewServer)

return function()
	describe("EventPreviewServer", function()
		local before

		beforeEach(function()
			before = workspace:GetAttribute(EventConstants.PREVIEW_ATTRIBUTE)
		end)

		afterEach(function()
			workspace:SetAttribute(EventConstants.PREVIEW_ATTRIBUTE, before)
		end)

		it("previews a registered event on this server", function()
			local reply = eventPreviewCommand({}, "harvest")
			expect(workspace:GetAttribute(EventConstants.PREVIEW_ATTRIBUTE)).to.equal("harvest")
			expect(string.find(reply, "harvest", 1, true) ~= nil).to.equal(true)
		end)

		it("turns the preview off", function()
			eventPreviewCommand({}, "harvest")
			eventPreviewCommand({}, "off")
			expect(workspace:GetAttribute(EventConstants.PREVIEW_ATTRIBUTE)).to.equal("")
		end)

		it("refuses an unknown event and leaves the preview as it was", function()
			eventPreviewCommand({}, "harvest")
			local reply = eventPreviewCommand({}, "attic")
			expect(workspace:GetAttribute(EventConstants.PREVIEW_ATTRIBUTE)).to.equal("harvest")
			expect(string.find(reply, "No event", 1, true) ~= nil).to.equal(true)
		end)
	end)
end
