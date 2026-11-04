--[[
	Unit tests for CalloutServiceServer through its `deps` seam.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local CalloutService = require(ServerScriptService.Features.Callout.CalloutServiceServer)

return function()
	local player = { Name = "TestPlayer", UserId = 7 }
	local sent, clock, owned, body

	local function install(stickers)
		sent, clock, owned, body = {}, 100, { ["CozyPack.CocoaBreak"] = true }, Vector3.new(0, 0, 0)
		CalloutService._setDeps({
			outfitOf = function()
				return {
					employee = "Pippa",
					look = { skin = "Pippa.Default", style = 1, idle = "Pippa.Classic", wheel = { "", "", "", "" } },
					vacuum = "Vacuum.StandardIssue",
					stickers = stickers,
				}
			end,
			owns = function(_, id)
				return owned[id] == true
			end,
			bodyAt = function()
				return body
			end,
			now = function()
				return clock
			end,
			broadcast = function(shown)
				table.insert(sent, shown)
			end,
		})
	end

	afterEach(function()
		CalloutService._setDeps(nil)
	end)

	it("tells everyone an owned sticker from a slot", function()
		install({ "", "CozyPack.CocoaBreak", "", "" })
		expect(CalloutService:callout(player, { kind = "sticker", slot = 2 })).to.equal(true)
		expect(sent[1].kind).to.equal("sticker")
		expect(sent[1].id).to.equal("CozyPack.CocoaBreak")
		expect(sent[1].userId).to.equal(7)
	end)

	it("refuses an empty slot and an unowned sticker", function()
		install({ "", "BubblePack.Yay", "", "" })
		expect(select(2, CalloutService:callout(player, { kind = "sticker", slot = 1 }))).to.equal("empty slot")
		expect(select(2, CalloutService:callout(player, { kind = "sticker", slot = 2 }))).to.equal("not owned")
		expect(#sent).to.equal(0)
	end)

	it("tells everyone a ping near you, and refuses one too far or too soon", function()
		install({ "", "", "", "" })
		local near = { kind = "ping", id = "gloom", at = Vector3.new(20, 0, 0) }
		expect(CalloutService:callout(player, near)).to.equal(true)
		expect(sent[1].at).to.equal(Vector3.new(20, 0, 0))
		clock += 0.3
		local again = CalloutService:callout(player, { kind = "ping", id = "help", at = Vector3.zero })
		expect(again).to.equal(false)
		clock += 2
		local far = { kind = "ping", id = "help", at = Vector3.new(999, 0, 0) }
		expect(select(2, CalloutService:callout(player, far))).to.equal("too far")
		expect(#sent).to.equal(1)
	end)

	it("drops a malformed request without throwing", function()
		install({ "", "", "", "" })
		expect(function()
			CalloutService._onRequest({ kind = "ping" }, player)
			CalloutService._onRequest(5, player)
		end).never.to.throw()
		expect(#sent).to.equal(0)
	end)
end
