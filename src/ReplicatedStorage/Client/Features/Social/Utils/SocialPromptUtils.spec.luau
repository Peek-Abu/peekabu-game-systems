local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SocialPromptUtils = require(ReplicatedStorage.Client.Features.Social.Utils.SocialPromptUtils)

return function()
	it("asks to RSVP to an upcoming event the player has not answered", function()
		expect(SocialPromptUtils.pick({ rsvp = "None", canOptIn = true, asked = {} })).to.equal("rsvp")
	end)

	it("never asks again about an event the player already answered", function()
		expect(SocialPromptUtils.pick({ rsvp = "Going", canOptIn = false, asked = {} })).to.equal(nil)
		expect(SocialPromptUtils.pick({ rsvp = "NotGoing", canOptIn = false, asked = {} })).to.equal(nil)
	end)

	it("asks for notifications when there is no event to answer and Roblox allows the prompt", function()
		expect(SocialPromptUtils.pick({ rsvp = nil, canOptIn = true, asked = {} })).to.equal("notifications")
		expect(SocialPromptUtils.pick({ rsvp = "Going", canOptIn = true, asked = {} })).to.equal("notifications")
		expect(SocialPromptUtils.pick({ rsvp = nil, canOptIn = false, asked = {} })).to.equal(nil)
	end)

	it("asks each thing at most once a session", function()
		expect(SocialPromptUtils.pick({ rsvp = "None", canOptIn = true, asked = { rsvp = true } })).to.equal(
			"notifications"
		)
		expect(
			SocialPromptUtils.pick({ rsvp = "None", canOptIn = true, asked = { rsvp = true, notifications = true } })
		).to.equal(nil)
	end)
end
