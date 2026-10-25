--[[
	Unit tests for EmoteServiceServer through its `deps` seam: a fake outfit, body, animation calls and clock.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local EmoteService = require(ServerScriptService.Features.Emote.EmoteServiceServer)

return function()
	local player = { Name = "TestPlayer", UserId = 1 }
	local played, stopped, clock, body

	local function outfit(wheel)
		return {
			employee = "Pippa",
			look = { skin = "Pippa.Default", style = 1, idle = "Pippa.Classic", wheel = wheel },
			vacuum = "Vacuum.StandardIssue",
			stickers = { "", "", "", "" },
		}
	end

	local function install(wheel, clips)
		played, stopped, clock = {}, {}, 100
		body = { alive = true, knocked = false, hiding = false, carrying = false }
		EmoteService._setDeps({
			outfitOf = function()
				return outfit(wheel)
			end,
			bodyOf = function()
				return body
			end,
			play = function(_, key)
				table.insert(played, key)
				return true, nil
			end,
			stop = function(_, key)
				table.insert(stopped, key)
			end,
			hasClip = function(key)
				return clips[key] == true
			end,
			now = function()
				return clock
			end,
		})
	end

	afterEach(function()
		EmoteService._setDeps(nil)
	end)

	it("plays the clip of the emote in the slot, for everyone (a replicated grant)", function()
		install({ "Pippa.Wave", "", "", "" }, { ["emote:Pippa.Wave"] = true })
		expect(EmoteService:play(player, 1)).to.equal(true)
		expect(played[1]).to.equal("emote:Pippa.Wave")
	end)

	it("refuses an empty slot, a clip not made yet and a second emote too soon", function()
		install({ "Pippa.Wave", "", "", "Pippa.Bubbles" }, { ["emote:Pippa.Wave"] = true })
		expect(select(2, EmoteService:play(player, 2))).to.equal("empty slot")
		expect(select(2, EmoteService:play(player, 4))).to.equal("no clip yet")
		expect(EmoteService:play(player, 1)).to.equal(true)
		clock += 0.5
		expect(select(2, EmoteService:play(player, 1))).to.equal("too soon")
		clock += 2
		expect(EmoteService:play(player, 1)).to.equal(true)
		expect(#played).to.equal(2)
	end)

	it("refuses a body that is down, hiding or carrying", function()
		install({ "Pippa.Wave", "", "", "" }, { ["emote:Pippa.Wave"] = true })
		body.carrying = true
		expect(select(2, EmoteService:play(player, 1))).to.equal("carrying")
		body.carrying, body.knocked = false, true
		expect(select(2, EmoteService:play(player, 1))).to.equal("down")
		expect(#played).to.equal(0)
	end)

	it("stops the playing emote once, on request", function()
		install({ "Pippa.Wave", "", "", "" }, { ["emote:Pippa.Wave"] = true })
		EmoteService:play(player, 1)
		EmoteService:stopEmote(player)
		EmoteService:stopEmote(player)
		expect(#stopped).to.equal(1)
		expect(stopped[1]).to.equal("emote:Pippa.Wave")
	end)

	it("drops a malformed request without throwing", function()
		install({ "Pippa.Wave", "", "", "" }, { ["emote:Pippa.Wave"] = true })
		expect(function()
			EmoteService._onPlayRequest({ slot = 9 }, player)
			EmoteService._onPlayRequest("x", player)
		end).never.to.throw()
		expect(#played).to.equal(0)
	end)
end
