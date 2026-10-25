local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmoteRules = require(script.Parent.EmoteRules)
local EmoteConstants = require(ReplicatedStorage.Shared.Features.Emote.Data.EmoteConstants)

return function()
	local function state(patch)
		local value = {
			emote = "Pippa.Wave",
			hasClip = true,
			alive = true,
			knocked = false,
			hiding = false,
			carrying = false,
			now = 100,
			last = nil,
		}
		for key, v in patch or {} do
			value[key] = v
		end
		return value
	end

	it("keys a clip by its emote id", function()
		expect(EmoteRules.clipKey("Pippa.Wave")).to.equal("emote:Pippa.Wave")
	end)

	it("reads a wheel slot, empty as nil", function()
		local look = { skin = "Pippa.Default", style = 1, idle = "Pippa.Classic", wheel = { "Pippa.Wave", "", "", "" } }
		expect(EmoteRules.inSlot(look, 1)).to.equal("Pippa.Wave")
		expect(EmoteRules.inSlot(look, 2)).never.to.be.ok()
	end)

	it("lets a free, standing body emote", function()
		expect(EmoteRules.check(state())).to.equal(true)
		expect(EmoteRules.check(state({ last = 100 - EmoteConstants.COOLDOWN }))).to.equal(true)
	end)

	it("refuses with the reason", function()
		local function reason(patch)
			local ok, why = EmoteRules.check(state(patch))
			expect(ok).to.equal(false)
			return why
		end
		local empty = state()
		empty.emote = nil
		expect(select(2, EmoteRules.check(empty))).to.equal("empty slot")
		expect(reason({ hasClip = false })).to.equal("no clip yet")
		expect(reason({ alive = false })).to.equal("down")
		expect(reason({ knocked = true })).to.equal("down")
		expect(reason({ hiding = true })).to.equal("hiding")
		expect(reason({ carrying = true })).to.equal("carrying")
		expect(reason({ last = 99.5 })).to.equal("too soon")
	end)
end
