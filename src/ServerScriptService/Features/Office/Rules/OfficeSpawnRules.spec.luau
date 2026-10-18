local ServerScriptService = game:GetService("ServerScriptService")

local OfficeSpawnRules = require(script.Parent.OfficeSpawnRules)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)

local LAYOUT = OfficeLayoutConstants.LAYOUT

-- Three piles make one dust bag (15); quota 20 needs 30 trash.
local function plan()
	return {
		piles = {
			{ marker = "lobby.pile.1", kind = "paper" },
			{ marker = "lobby.pile.2", kind = "debris" },
			{ marker = "lobby.pile.3", kind = "cables" },
		},
		items = {
			{ marker = "lobby.item.1", kind = "rubbishBag" },
			{ marker = "lobby.item.2", kind = "rubbishBag" },
			{ marker = "archive.item.1", kind = "fishTank" },
		},
		searchables = {},
		greed = { marker = "archive.item.1", kind = "fishTank" },
		trashValue = 35,
	}
end

return function()
	it("accepts a plan that meets the guarantees", function()
		local ok, reason = OfficeSpawnRules.check(plan(), LAYOUT, 20)
		expect(reason).to.equal(nil)
		expect(ok).to.equal(true)
	end)

	it("counts the dust bags the piles make", function()
		expect(OfficeSpawnRules.trashValue(plan())).to.equal(35)
	end)

	it("makes one dust bag per full canister of piles", function()
		expect(OfficeSpawnRules.pileTrash(2)).to.equal(0)
		expect(OfficeSpawnRules.pileTrash(3)).to.equal(15)
		expect(OfficeSpawnRules.pileTrash(7)).to.equal(30)
	end)

	it("refuses too little trash", function()
		local short = plan()
		table.remove(short.items, 2)
		local ok, reason = OfficeSpawnRules.check(short, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal("only 25 trash for a quota of 20")
	end)

	it("refuses a missing greed target", function()
		local noGreed = plan()
		noGreed.greed = nil
		local ok, reason = OfficeSpawnRules.check(noGreed, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal("no greed target")
	end)

	it("refuses a greed target placed shallow", function()
		local shallow = plan()
		shallow.items[3].marker = "lobby.item.3"
		shallow.greed.marker = "lobby.item.3"
		local ok, reason = OfficeSpawnRules.check(shallow, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal("the greed target is not placed deep")
	end)

	it("refuses a greed record naming a non-greed item", function()
		local wrong = plan()
		wrong.greed.kind = "printer"
		local ok, reason = OfficeSpawnRules.check(wrong, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal('"printer" is not a greed target')
	end)

	it("refuses a marker used twice", function()
		local twice = plan()
		twice.items[2].marker = "lobby.item.1"
		local ok, reason = OfficeSpawnRules.check(twice, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal('marker "lobby.item.1" is used twice')
	end)
end
