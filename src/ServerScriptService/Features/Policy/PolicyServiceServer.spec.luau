--[[
	Unit tests for PolicyServiceServer with a stub fetcher: caches per player and fails closed when PolicyService throws
	or returns a bad table.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local PolicyServiceServer = require(ServerScriptService.Features.Policy.PolicyServiceServer)

return function()
	local player = { UserId = 42, Name = "TestPlayer" }

	afterEach(function()
		PolicyServiceServer._setFetcher(nil)
	end)

	it("reads ArePaidRandomItemsRestricted once and caches it for the session", function()
		local calls = 0
		PolicyServiceServer._setFetcher(function(who)
			calls += 1
			expect(who).to.equal(player)
			return { ArePaidRandomItemsRestricted = false }
		end)
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(false)
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(false)
		expect(calls).to.equal(1)
	end)

	it("returns true when PolicyService says paid random items are restricted", function()
		PolicyServiceServer._setFetcher(function()
			return { ArePaidRandomItemsRestricted = true }
		end)
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(true)
	end)

	it("fails closed (restricted = true) when PolicyService errors or returns a malformed table", function()
		PolicyServiceServer._setFetcher(function()
			error("network down")
		end)
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(true)

		PolicyServiceServer._setFetcher(function()
			return {}
		end)
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(true)
	end)

	it("lets a test or debug flag force the restricted state for a user", function()
		PolicyServiceServer._setFetcher(function()
			return { ArePaidRandomItemsRestricted = false }
		end)
		PolicyServiceServer:setRestricted(player.UserId, true)
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(true)
		PolicyServiceServer:setRestricted(player.UserId, nil)
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(false)
	end)
end
