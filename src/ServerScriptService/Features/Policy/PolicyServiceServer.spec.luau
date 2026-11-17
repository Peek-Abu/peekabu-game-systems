--[[
	Unit tests for PolicyServiceServer with a stub fetcher: caches per player and fails closed when PolicyService throws
	or returns a bad table.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local PolicyServiceServer = require(ServerScriptService.Features.Policy.PolicyServiceServer)

return function()
	local player = { UserId = 42, Name = "TestPlayer" }

	local DEV = PolicyServiceServer.DEV_RESTRICTED_ATTRIBUTE

	afterEach(function()
		PolicyServiceServer._setFetcher(nil)
		PolicyServiceServer._setStudio(nil)
		workspace:SetAttribute(DEV, nil)
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

	it("names the Studio switch DevPaidRandomRestricted", function()
		expect(DEV).to.equal("DevPaidRandomRestricted")
	end)

	it("in Studio, the Workspace switch plays a restricted (or unrestricted) country over PolicyService", function()
		PolicyServiceServer._setFetcher(function()
			return { ArePaidRandomItemsRestricted = false }
		end)
		PolicyServiceServer._setStudio(true)
		workspace:SetAttribute(DEV, true)
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(true)

		PolicyServiceServer._setFetcher(function()
			return { ArePaidRandomItemsRestricted = true }
		end)
		workspace:SetAttribute(DEV, false)
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(false)
	end)

	it("in Studio with the switch unset, PolicyService decides", function()
		PolicyServiceServer._setFetcher(function()
			return { ArePaidRandomItemsRestricted = true }
		end)
		PolicyServiceServer._setStudio(true)
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(true)
	end)

	it("outside Studio, the Workspace switch is ignored", function()
		PolicyServiceServer._setFetcher(function()
			return { ArePaidRandomItemsRestricted = false }
		end)
		PolicyServiceServer._setStudio(false)
		workspace:SetAttribute(DEV, true)
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(false)
	end)

	it("ignores a switch that is not true or false", function()
		PolicyServiceServer._setFetcher(function()
			return { ArePaidRandomItemsRestricted = false }
		end)
		PolicyServiceServer._setStudio(true)
		workspace:SetAttribute(DEV, "yes")
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(false)
	end)

	it("a per-user override still wins over the Studio switch", function()
		PolicyServiceServer._setStudio(true)
		workspace:SetAttribute(DEV, true)
		PolicyServiceServer:setRestricted(player.UserId, false)
		expect(PolicyServiceServer:paidRandomItemsRestricted(player)).to.equal(false)
	end)
end
