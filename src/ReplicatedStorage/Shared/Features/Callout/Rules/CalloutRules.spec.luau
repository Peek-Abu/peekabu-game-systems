local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalloutRules = require(script.Parent.CalloutRules)
local CalloutConstants = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutConstants)

return function()
	describe("rate", function()
		it("allows one a second and a burst per window", function()
			local times = {}
			expect(CalloutRules.allowed(times, 0)).to.equal(true)
			CalloutRules.remember(times, 0)
			expect(CalloutRules.allowed(times, 0.5)).to.equal(false)
			for t = 1, CalloutConstants.BURST - 1 do
				expect(CalloutRules.allowed(times, t)).to.equal(true)
				CalloutRules.remember(times, t)
			end
			expect(CalloutRules.allowed(times, CalloutConstants.BURST)).to.equal(false)
			expect(CalloutRules.allowed(times, CalloutConstants.WINDOW + 1)).to.equal(true)
		end)

		it("forgets times past the window", function()
			local times = { 0, 1 }
			CalloutRules.remember(times, CalloutConstants.WINDOW + 5)
			expect(#times).to.equal(1)
		end)
	end)

	describe("sticker", function()
		it("gives an owned sticker in a slot, and refuses an empty or unowned one", function()
			local stickers = { "CozyPack.Cocoa", "", "Nope", "" }
			local owns = function(id)
				return id == "CozyPack.Cocoa"
			end
			expect(CalloutRules.sticker(stickers, 1, owns)).to.equal("CozyPack.Cocoa")
			expect(select(2, CalloutRules.sticker(stickers, 2, owns))).to.equal("empty slot")
			expect(select(2, CalloutRules.sticker(stickers, 3, owns))).to.equal("empty slot")
			expect(select(2, CalloutRules.sticker({ "BubblePack.Ducky", "", "", "" }, 1, owns))).to.equal("not owned")
		end)
	end)

	describe("ping", function()
		it("lets a known ping go near you only", function()
			local body = Vector3.new(0, 0, 0)
			expect(CalloutRules.ping("gloom", Vector3.new(10, 0, 0), body)).to.equal(true)
			expect(select(2, CalloutRules.ping("nope", Vector3.zero, body))).to.equal("unknown ping")
			expect(select(2, CalloutRules.ping("gloom", Vector3.new(1000, 0, 0), body))).to.equal("too far")
			expect(select(2, CalloutRules.ping("gloom", Vector3.zero, nil))).to.equal("no body")
		end)
	end)
end
